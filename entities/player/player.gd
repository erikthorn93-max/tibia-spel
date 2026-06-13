class_name Player
extends Node2D
## Tile-baserad rörelse + targeting + auto-attack + gathering (Tibia/OSRS-stil).

const TILE := 32
const ATTACK_COOLDOWN := 1.0
const GATHER_INTERVAL := 2.0
const MAGIC_RANGE := 4   # Chebyshev-avstånd för runkastning

var zone: Node2D                      # sätts av World vid zonladdning
var tile := Vector2i.ZERO
var _move_t := 1.0                    # 0..1 under pågående steg
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var move_speed := 4.0                 # tiles/sek
var facing := Vector2i.DOWN
var target: Node2D = null
var _attack_timer := 0.0
var gather_target: Node2D = null
var _gather_timer := 0.0
var _auto_path: Array = []

@onready var visual: CharacterVisual = $CharacterVisual

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)
	GameState.appearance_changed.connect(func(): visual.apply_appearance(GameState.appearance))

func snap_to(t: Vector2i) -> void:
	tile = t
	position = zone.tile_to_world(t)
	_move_t = 1.0
	GameState.player_tile = t
	QuestSystem.record_position(GameState.current_zone, t)

func set_target(m: Node2D) -> void:
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	target = m
	gather_target = null
	_auto_path = []
	if target:
		target.modulate = Color(1.4, 0.9, 0.9)   # röd markering som Tibia

func set_gather_target(n: Node2D) -> void:
	set_target(null)
	gather_target = n
	_gather_timer = 0.0
	if n:
		_auto_path = zone.find_path_adjacent(tile, n.tile)
		if _auto_path.is_empty() and _chebyshev(n.tile) > 1:
			World.hud.show_message("Kan inte nå dit.")
			gather_target = null

func _chebyshev(t: Vector2i) -> int:
	return maxi(absi(t.x - tile.x), absi(t.y - tile.y))

func _process(delta: float) -> void:
	_update_movement(delta)
	_update_attack(delta)
	_update_gather(delta)
	_update_spells()

func _update_movement(delta: float) -> void:
	if GameState.has_status("stun"):
		return   # stun-status: spelaren kan inte röra sig
	var effective_speed := move_speed * (0.5 if GameState.has_status("slow") else 1.0)
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta * effective_speed, 1.0)
		position = _from.lerp(_to, _move_t)
		if _move_t >= 1.0:
			GameState.player_tile = tile
			QuestSystem.record_position(GameState.current_zone, tile)
			_check_portal()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		_auto_path = []          # manuell rörelse avbryter auto-walk
		gather_target = null
		_step(dir)
		return
	if _auto_path.size() > 1:    # auto-walk mot gather-mål
		var next: Vector2i = _auto_path[1]
		_auto_path.remove_at(0)
		var d := next - tile
		if d != Vector2i.ZERO and zone.is_walkable(next):
			_step(d)

func _step(dir: Vector2i) -> void:
	facing = dir
	visual.face(dir)
	var next := tile + dir
	if not zone.is_walkable(next):
		_try_bump_unlock(next)
		return
	_from = position
	_to = zone.tile_to_world(next)
	tile = next
	_move_t = 0.0
	GameState.gain_skill_xp("agility", 1)   # gång tränar agility (genvägskrav)

## Gå mot låst gate/genväg: lås upp om kraven är uppfyllda, annars visa hint.
func _try_bump_unlock(t: Vector2i) -> void:
	var uid: String = zone.lock_at(t)
	if uid == "":
		return
	if not UnlockSystem.try_unlock(uid):
		World.hud.show_message(UnlockSystem.hint_for(uid))

func _update_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target and is_instance_valid(target) and not target.dead and _attack_timer <= 0.0:
		var wskill := GameState.weapon_skill()
		var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
		var weapon_range := int(weapon.get("range", 1))
		var dist := _chebyshev(target.tile)
		if dist > weapon_range:
			return   # utom räckvidd
		_attack_timer = ATTACK_COOLDOWN
		var dmg: float
		if weapon_range > 1:
			# Bågskjutning: kräver ammunition i inventory
			var ammo_id := String(weapon.get("ammo", ""))
			if ammo_id != "" and int(GameState.inventory.get(ammo_id, 0)) < 1:
				World.hud.show_message("Inga pilar kvar!")
				return
			if ammo_id != "":
				GameState.remove_item(ammo_id, 1)
			dmg = CombatFormulas.roll_ranged(
				GameState.effective_skill_level(wskill), int(weapon.get("atk", 5))) \
				* TaskSystem.damage_multiplier(target.monster_name)
			target.take_damage(dmg)
			GameState.gain_skill_xp(wskill, 1)
		else:
			# Närstrid
			if dist > 1:
				return
			dmg = CombatFormulas.roll_melee(GameState.level,
				GameState.effective_skill_level(wskill), int(weapon.get("atk", 5))) \
				* TaskSystem.damage_multiplier(target.monster_name)   # bestiary-tierbonus
			target.take_damage(dmg)
			GameState.gain_skill_xp(wskill, 1)

func _update_gather(delta: float) -> void:
	if gather_target == null or not is_instance_valid(gather_target):
		return
	if _chebyshev(gather_target.tile) > 1:
		return                    # på väg dit via auto-walk
	_gather_timer -= delta
	if _gather_timer > 0.0:
		return
	_gather_timer = GATHER_INTERVAL
	match gather_target.attempt():
		"no_tool":
			World.hud.show_message("Du behöver: %s" % ItemDB.items[gather_target.def["tool"]]["name"])
			gather_target = null
		"low_level":
			World.hud.show_message("Kräver %s %d." % [gather_target.def["skill"], int(gather_target.def["level"])])
			gather_target = null
		"depleted":
			gather_target = null

func _update_spells() -> void:
	if Input.is_action_just_pressed("use_rune"):
		_cast_rune()
	if Input.is_action_just_pressed("use_potion"):
		if not GameState.use_item("health_potion"):
			World.hud.show_message("Ingen hälsodryck.")

## Kastar aktiv runa mot target (damage) eller sig själv (heal).
func _cast_rune() -> void:
	var rid := GameState.active_rune
	if rid.is_empty():
		World.hud.show_message("Ingen runa vald.")
		return
	if int(GameState.inventory.get(rid, 0)) < 1:
		World.hud.show_message("Du har inga runor av den typen.")
		return
	var d: Dictionary = ItemDB.items.get(rid, {})
	var rune_power := int(d.get("rune_power", 0))
	var mana_cost  := float(d.get("mana_cost", 0.0))
	var req_lvl    := int(d.get("magic_lvl", 1))
	var effect     := String(d.get("effect", "damage"))
	var magic_lvl  := GameState.effective_skill_level("magic")
	if magic_lvl < req_lvl:
		World.hud.show_message("Kräver magic %d." % req_lvl)
		return
	# Damage-runor kräver giltigt target — kontrollera INNAN mana/runa förbrukas
	if effect != "heal":
		if target == null or not is_instance_valid(target) or target.dead:
			World.hud.show_message("Inget mål att attackera.")
			return
		if _chebyshev(target.tile) > MAGIC_RANGE:
			World.hud.show_message("För långt bort.")
			return
	if not GameState.use_mana(mana_cost):
		World.hud.show_message("Inte tillräckligt med mana.")
		return
	GameState.remove_item(rid, 1)
	var dmg := CombatFormulas.roll_magic(magic_lvl, rune_power)
	if effect == "heal":
		GameState.heal(dmg)
		GameState.gain_skill_xp("magic", 2)
		World.hud.show_message("Du helar %.0f HP!" % dmg)
	else:
		target.take_damage(dmg)
		GameState.gain_skill_xp("magic", 3)
		# Eldrunor tänder eld på monstret
		if rid == "fire_rune" and target.has_method("apply_status"):
			target.apply_status("burn", 8.0, 4.0)

func _check_portal() -> void:
	if zone.dungeon_entrances.has(tile):
		World.enter_dungeon(zone.dungeon_entrances[tile])
		return
	if not zone.portals.has(tile):
		return
	if zone.portal_locks.has(tile):
		var uid: String = zone.portal_locks[tile]
		if not UnlockSystem.try_unlock(uid):
			World.hud.show_message(UnlockSystem.hint_for(uid))
			return
	World.change_zone(zone.portals[tile])
