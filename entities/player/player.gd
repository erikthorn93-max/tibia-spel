class_name Player
extends Node2D
## Tile-baserad rörelse + targeting + auto-attack + gathering (Tibia/OSRS-stil).

const TILE := 32
const ATTACK_COOLDOWN := 1.0
const GATHER_INTERVAL := 2.0

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

func _update_movement(delta: float) -> void:
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta * move_speed, 1.0)
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
	if zone.is_walkable(next):
		_from = position
		_to = zone.tile_to_world(next)
		tile = next
		_move_t = 0.0

func _update_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target and is_instance_valid(target) and not target.dead and _attack_timer <= 0.0:
		if _chebyshev(target.tile) <= 1:
			_attack_timer = ATTACK_COOLDOWN
			var wskill := GameState.weapon_skill()
			var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
			var dmg := CombatFormulas.roll_melee(GameState.level,
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

func _check_portal() -> void:
	if zone.portals.has(tile):
		World.change_zone(zone.portals[tile])
