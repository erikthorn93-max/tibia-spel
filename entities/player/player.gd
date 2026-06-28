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
var _status_aura: CPUParticles2D = null

@onready var visual: CharacterVisual = $CharacterVisual

const Atmosphere = preload("res://ui/atmosphere.gd")
const Lighting = preload("res://world/lighting.gd")

var _light: PointLight2D = null   # spelarens eget sken (starkare med fackla)
var _light_t := 0.0               # tidsackumulator för fackelflimmer

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)
	GameState.appearance_changed.connect(func(): visual.apply_appearance(GameState.appearance))
	GameState.player_hit.connect(_on_player_hit)
	_build_status_aura()
	GameState.status_changed.connect(_update_status_aura)
	_build_player_light()

## Spelarens följeljus: ett svagt närvarosken alltid, kraftigt fackelsken när en
## ljuskälla är utrustad. Tänds bara i mörker (energy skalas av dygnet) så det
## inte överexponerar dagsljus.
func _build_player_light() -> void:
	_light = Lighting.make_light(Color(1.0, 0.82, 0.52), 0.0, 96.0)
	add_child(_light)

func _update_player_light(delta: float) -> void:
	if _light == null:
		return
	_light_t += delta
	var dark := Atmosphere.light_energy(TimeOfDay.day_fraction)
	# Bär man fackla/lykta lyser man både starkare och längre.
	var carry := GameState.light_level()           # 0..1
	var reach := 80.0 + carry * 120.0              # närvaro → fackla
	var base := 0.45 + carry * 1.05
	_light.texture_scale = reach / (Lighting.TEX_SIZE * 0.5)
	_light.energy = base * dark * Atmosphere.flicker(_light_t)

## Bygger en partikel-aura som visar pågående status (gift/brand) runt spelaren.
func _build_status_aura() -> void:
	_status_aura = CPUParticles2D.new()
	_status_aura.emitting = false
	_status_aura.amount = 10
	_status_aura.lifetime = 0.8
	_status_aura.direction = Vector2(0, -1)
	_status_aura.spread = 25.0
	_status_aura.initial_velocity_min = 12.0
	_status_aura.initial_velocity_max = 26.0
	_status_aura.gravity = Vector2(0, -12)
	_status_aura.scale_amount_min = 1.5
	_status_aura.scale_amount_max = 2.5
	_status_aura.position = Vector2(0, -6)
	add_child(_status_aura)

## Slår på/av auran utifrån aktiv status (gift = grön, brand = orange).
func _update_status_aura(_id := "") -> void:
	if _status_aura == null:
		return
	if GameState.has_status("poison"):
		_status_aura.color = Color(0.40, 0.95, 0.35)
		_status_aura.emitting = true
	elif GameState.has_status("burn"):
		_status_aura.color = Color(1.0, 0.50, 0.12)
		_status_aura.emitting = true
	else:
		_status_aura.emitting = false

func _on_player_hit(dmg: float, dmg_type: String) -> void:
	if dmg <= 0:
		return
	var color: Color
	match dmg_type:
		"poison": color = Color(0.35, 0.95, 0.35)   # grön
		"burn":   color = Color(1.00, 0.50, 0.10)   # orange
		_:
			color = Color(1.00, 0.22, 0.22)   # röd (fysisk)
			visual.play_hurt()   # träff-blink bara på fysiska slag (ej DoT-tick)
	var dn: Node2D = preload("res://entities/damage_number.gd").new()
	add_child(dn)
	dn.setup(dmg, false, color)
	dn.position = Vector2(0, -20)   # lite ovanför spelarens mittpunkt

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

## Klick-för-att-gå: pathfinda till en ruta och auto-walka dit.
## Går ända fram till rutan (portaler/dörrar utlöses när spelaren kliver på).
func walk_to(t: Vector2i) -> void:
	set_target(null)
	gather_target = null
	_auto_path = []
	if t == tile:
		return
	if not zone.is_walkable(t):
		# Låst gate/genväg intill? ge hint istället för tyst avbrott.
		if zone.lock_at(t) != "":
			_try_bump_unlock(t)
		else:
			World.hud.show_message("Kan inte nå dit.")
		return
	var path: Array = zone.find_path(tile, t)
	if path.is_empty():
		World.hud.show_message("Kan inte nå dit.")
		return
	_auto_path = path

func _chebyshev(t: Vector2i) -> int:
	return maxi(absi(t.x - tile.x), absi(t.y - tile.y))

func _process(delta: float) -> void:
	_update_movement(delta)
	visual.set_walk(_move_t < 1.0, _move_t)   # gång-studs under steg, annars andning
	_update_attack(delta)
	_update_gather(delta)
	_update_spells()
	_update_player_light(delta)

func _update_movement(delta: float) -> void:
	if GameState.has_status("stun"):
		return   # stun-status: spelaren kan inte röra sig
	var effective_speed := move_speed * (0.5 if GameState.has_status("slow") else 1.0)
	# Förbruka hela frame-budgeten: avsluta pågående steg och fortsätt sömlöst in
	# i nästa (carry-over) så det inte uppstår en stillastående frame vid varje
	# tile-gräns — det är det som ger den synliga hackningen.
	var budget := delta
	while budget > 0.0:
		if _move_t < 1.0:
			var need := (1.0 - _move_t) / effective_speed   # tid kvar för steget
			if budget < need:
				_move_t += budget * effective_speed
				position = _from.lerp(_to, _move_t)
				return
			# Steget hinner bli klart denna frame — förbruka exakt så mycket tid.
			budget -= need
			_move_t = 1.0
			position = _to
			var prev_zone := zone
			GameState.player_tile = tile
			QuestSystem.record_position(GameState.current_zone, tile)
			_check_portal()
			if zone != prev_zone:
				return   # zonbyte skedde — ny zon/position hanterar resten
		elif not _begin_next_step():
			return        # ingen input/auto-path — stå stilla

## Väljer nästa rörelseriktning (manuell input > auto-walk). Returnerar true
## om ett steg faktiskt startades.
func _begin_next_step() -> bool:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		_auto_path = []          # manuell rörelse avbryter auto-walk
		gather_target = null
		return _step(dir)
	if _auto_path.size() > 1:    # auto-walk mot gather-mål
		var next: Vector2i = _auto_path[1]
		_auto_path.remove_at(0)
		var d := next - tile
		if d != Vector2i.ZERO and zone.is_walkable(next):
			return _step(d)
	return false

func _step(dir: Vector2i) -> bool:
	facing = dir
	visual.face(dir)
	var next := tile + dir
	if not zone.is_walkable(next):
		_try_bump_unlock(next)
		return false
	_from = position
	_to = zone.tile_to_world(next)
	tile = next
	_move_t = 0.0
	GameState.gain_skill_xp("agility", 1)   # gång tränar agility
	# Agility-bonus: rörelsehastighetsmultiplikator baserad på agility-nivå
	var ag := GameState.effective_skill_level("agility")
	if ag >= 60:
		move_speed = 5.2
	elif ag >= 40:
		move_speed = 4.8
	elif ag >= 20:
		move_speed = 4.4
	else:
		move_speed = 4.0
	return true

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
		_attack_timer = ATTACK_COOLDOWN / (1.0 + GameState.total_speed_bonus())
		# Vänd dig mot målet inför slaget (gäller både närstrid och bågskytte)
		var to_dir := Vector2i(signi(target.tile.x - tile.x), signi(target.tile.y - tile.y))
		if to_dir != Vector2i.ZERO:
			facing = to_dir
			visual.face(facing)
		var dmg: float
		if weapon_range > 1:
			# Bågskjutning: kräver ammunition i inventory
			var ammo_id := String(weapon.get("ammo", ""))
			if ammo_id != "" and not GameState.has_ammo(ammo_id):
				World.hud.show_message("Inga pilar kvar!")
				return
			if ammo_id != "":
				GameState.consume_ammo(ammo_id)
			if not _rolls_hit(wskill):
				_on_attack_miss(wskill)
				return
			dmg = CombatFormulas.roll_ranged(
				GameState.effective_skill_level(wskill),
				int(weapon.get("atk", 5)) + GameState.total_atk_bonus()) \
				* TaskSystem.damage_multiplier(target.monster_name) \
				* CombatStance.damage_mult(GameState.combat_stance)
			var crit := CombatFormulas.roll_crit(
				GameState.effective_skill_level(wskill), GameState.total_crit_bonus())
			if crit:
				dmg *= CombatFormulas.CRIT_MULTIPLIER
			target.take_damage(dmg, crit)
			_apply_offense_charm(target)
			GameState.gain_skill_xp(wskill, 1)
			GameState.add_spec(CombatFormulas.SPEC_GAIN)   # ladda kraftslaget
			visual.play_attack(facing)
		else:
			# Närstrid
			if dist > 1:
				return
			if not _rolls_hit(wskill):
				_on_attack_miss(wskill)
				return
			dmg = CombatFormulas.roll_melee(GameState.level,
				GameState.effective_skill_level(wskill),
				int(weapon.get("atk", 5)) + GameState.total_atk_bonus()) \
				* TaskSystem.damage_multiplier(target.monster_name) \
				* CombatStance.damage_mult(GameState.combat_stance)   # bestiary-tier + ställning
			var crit := CombatFormulas.roll_crit(
				GameState.effective_skill_level(wskill), GameState.total_crit_bonus())
			if crit:
				dmg *= CombatFormulas.CRIT_MULTIPLIER
			target.take_damage(dmg, crit)
			_apply_offense_charm(target)
			GameState.gain_skill_xp(wskill, 1)
			GameState.add_spec(CombatFormulas.SPEC_GAIN)   # ladda kraftslaget
			visual.play_attack(facing)   # närstrids-stöt mot målet

## Slår om det aktuella slaget träffar målet (spelarens accuracy mot monstrets
## undvikande). Garanterar inget — högt golv håller tidig spelning förlåtande.
func _rolls_hit(wskill: String) -> bool:
	var acc := CombatFormulas.accuracy(GameState.level, GameState.effective_skill_level(wskill))
	var eva := CombatFormulas.monster_evasion(float(target.speed))
	return CombatFormulas.roll_hit(acc, eva)

## Ett bommat slag: svingen syns, "miss" visas och skickligheten tränas ändå
## (förlåtande), men ingen skada, charm-effekt eller spec-laddning sker.
func _on_attack_miss(wskill: String) -> void:
	visual.play_attack(facing)
	if is_instance_valid(target) and target.has_method("show_miss"):
		target.show_miss()
	GameState.gain_skill_xp(wskill, 1)

## Slår den bärna offensiva charmen mot målet och lägger på elementär bonusskada.
func _apply_offense_charm(target) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	var r := CharmSystem.roll_offense(float(target.max_hp))
	if r.get("triggered", false):
		var dealt: int = target.take_charm_damage(float(r["amount"]), String(r["element"]))
		var ls := CharmSystem.lifesteal(String(r["id"]))
		if ls > 0.0 and dealt > 0 and GameState.health < GameState.max_health:
			var healed := float(dealt) * ls
			GameState.heal(healed)
			_spawn_heal_float(healed)

## Släpper kraftslaget (specialattack) mot nuvarande mål om mätaren är full.
## Ett enda hårt, garanterat kritiskt slag som tömmer mätaren. Anropas av HUD:en.
func try_special() -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		World.hud.show_message("Inget mål för kraftslag.")
		return
	var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
	var weapon_range := int(weapon.get("range", 1))
	if _chebyshev(target.tile) > weapon_range:
		World.hud.show_message("Målet är utom räckhåll.")
		return
	if not CombatFormulas.spec_ready(GameState.spec_energy):
		World.hud.show_message("Kraftslaget är inte laddat.")
		Sfx.denied()
		return
	var wskill := GameState.weapon_skill()
	var atk_total := int(weapon.get("atk", 5)) + GameState.total_atk_bonus()
	var ammo_id := String(weapon.get("ammo", ""))
	var base: float
	if weapon_range > 1:
		if ammo_id != "" and not GameState.has_ammo(ammo_id):
			World.hud.show_message("Inga pilar kvar!")
			return
		base = CombatFormulas.max_ranged(GameState.effective_skill_level(wskill), atk_total)
	else:
		base = CombatFormulas.max_melee(GameState.level,
			GameState.effective_skill_level(wskill), atk_total)
	# Allt klart — töm mätaren och slå utifrån vapentypens kraftslag.
	GameState.consume_spec()
	if weapon_range > 1 and ammo_id != "":
		GameState.consume_ammo(ammo_id)
	var to_dir := Vector2i(signi(target.tile.x - tile.x), signi(target.tile.y - tile.y))
	if to_dir != Vector2i.ZERO:
		facing = to_dir
		visual.face(facing)
	visual.play_attack(facing)
	var prof := CombatFormulas.spec_profile(wskill)
	var stance_mult := CombatStance.damage_mult(GameState.combat_stance)
	var mult := float(prof["mult"])
	var msg := "Kraftslag!"
	match String(prof["kind"]):
		"cleave":
			msg = "Klyv!"
			# Målet + alla levande fiender intill målet får var sin träff.
			for m in _monsters_near(target.tile, 1):
				_spec_hit(m, base, mult, stance_mult)
		"crush":
			msg = "Krossa!"
			_spec_hit(target, base, mult, stance_mult)
			if is_instance_valid(target) and not target.dead:
				target.apply_status("stun", float(prof["stun"]), 0.0)
				if target.has_method("_spawn_element_tag"):
					target._spawn_element_tag("bedövad", Color(1.0, 0.9, 0.4))
		"double":
			msg = "Dubbelskott!"
			_spec_hit(target, base, mult, stance_mult)
			if is_instance_valid(target) and not target.dead:
				_spec_hit(target, base, mult, stance_mult)
		_:  # power
			_spec_hit(target, base, mult, stance_mult)
	_apply_offense_charm(target)
	GameState.gain_skill_xp(wskill, 2)
	Sfx.crit()
	World.hud.show_message(msg)

## Levande monster (med take_damage) inom Chebyshev-radie kring en ruta.
func _monsters_near(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	var parent := get_parent()
	if parent == null:
		return out
	for c in parent.get_children():
		if c == self or not is_instance_valid(c):
			continue
		if not c.has_method("take_damage") or c.get("dead"):
			continue
		var ct = c.get("tile")
		if ct == null:
			continue
		if maxi(absi(ct.x - center.x), absi(ct.y - center.y)) <= radius:
			out.append(c)
	return out

## En enskild kraftslags-träff på ett mål: skada (garanterad crit), charm-effekt
## hanteras av anroparen, plus en guldblixt vid nedslaget.
func _spec_hit(m, base: float, mult: float, stance_mult: float) -> void:
	if m == null or not is_instance_valid(m) or m.get("dead"):
		return
	var dmg := CombatFormulas.spec_damage(base, mult) \
		* TaskSystem.damage_multiplier(m.monster_name) * stance_mult
	m.take_damage(dmg, true)   # crit=true → guldsiffra + kritljud
	var parent := get_parent()
	if parent != null and is_instance_valid(m):
		_spawn_spell_flash(parent, m.global_position, Color(1.0, 0.85, 0.35), 1.9, 140.0)

## Flytande "väjer!" ovanför spelaren när ett monsterslag undviks.
func show_dodge() -> void:
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector2(0, -20)
	ft.setup("väjer!", Color(0.75, 0.9, 1.0), 12)

## Grön "+N" ovanför spelaren när en leech-charm läker.
func _spawn_heal_float(amount: float) -> void:
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector2(0, -20)
	ft.setup("+%d" % int(round(amount)), Color(0.5, 0.95, 0.5), 12)

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
		_:
			# Faktiskt sving-försök (ok/miss): vänd dig mot noden, svinga, ljud
			var gd := Vector2i(signi(gather_target.tile.x - tile.x),
				signi(gather_target.tile.y - tile.y))
			if gd != Vector2i.ZERO:
				facing = gd
				visual.face(facing)
			visual.play_attack(facing)
			Sfx.gather()

func _update_spells() -> void:
	if Input.is_action_just_pressed("use_potion"):
		if not GameState.use_item("health_potion"):
			World.hud.show_message("Ingen hälsodryck.")

## Casting-entrypoint: anropas av hotbaren för spell_id ELLER run-item-id.
## Instant-spells (self/area_self) löses direkt; target/area startar sikt-läget.
func cast_spell(id: String) -> void:
	var def := SpellSystem.cast_def(id)
	if def.is_empty():
		World.hud.show_message("Inget att kasta.")
		return
	var check := SpellSystem.can_cast(id)
	if not check["ok"]:
		World.hud.show_message(String(check["reason"]))
		Sfx.denied()
		return
	if SpellSystem.needs_aim(def):
		_begin_aim(id, def)
	else:
		var res := SpellSystem.resolve_cast(id, self, tile)
		_play_spell_fx(res)
		if String(res.get("message", "")) != "":
			World.hud.show_message(String(res["message"]))

## Startar sikt-cursorn; vid bekräftad ruta löser SpellSystem utfallet.
func _begin_aim(id: String, def: Dictionary) -> void:
	if World.aim == null or not is_instance_valid(World.aim):
		World.hud.show_message("Sikte ej tillgängligt.")
		return
	World.aim.begin(def, _on_aim_confirmed.bind(id))

## Callback från AimController när spelaren bekräftat en ruta.
func _on_aim_confirmed(picked: Vector2i, id: String) -> void:
	# Re-validera: tillstånd kan ha ändrats medan spelaren siktade.
	var recheck := SpellSystem.can_cast(id)
	if not recheck["ok"]:
		World.hud.show_message(String(recheck["reason"]))
		Sfx.denied()
		return
	var res := SpellSystem.resolve_cast(id, self, picked)
	_play_spell_fx(res)
	if String(res.get("message", "")) != "":
		World.hud.show_message(String(res["message"]))

## Spawnar besvärjelse-effekter utifrån metadatan i resolve_cast-resultatet.
func _play_spell_fx(res: Dictionary) -> void:
	var fx: Dictionary = res.get("fx", {})
	if fx.is_empty():
		return
	Sfx.cast(String(fx.get("ctype", "")))
	if zone == null:
		return
	var color := SpellFx.element_color(String(fx.get("element", "none")))
	var parent := get_parent()
	if parent == null:
		return
	var ctype := String(fx.get("ctype", ""))
	var center_tile: Vector2i = fx.get("center", tile)
	var center_pos: Vector2 = zone.tile_to_world(center_tile)
	match ctype:
		"heal":
			SpellFx.heal_sparkle(parent, global_position)
			_spawn_spell_flash(parent, global_position, color, 0.9, 90.0)
		"support":
			SpellFx.ring(parent, global_position, color, 24.0)
			SpellFx.burst(parent, global_position, color, 10, 70.0)
			_spawn_spell_flash(parent, global_position, color, 0.9, 90.0)
		"conjure":
			SpellFx.burst(parent, global_position, color, 10, 70.0)
			_spawn_spell_flash(parent, global_position, color, 0.7, 80.0)
		"attack":
			var target_type := String(fx.get("target_type", "target"))
			if target_type == "area_self" or center_tile == tile:
				SpellFx.burst(parent, center_pos, color, 18, 110.0)
				_spawn_spell_flash(parent, center_pos, color, 1.8, 150.0)
			else:
				# Projektil från spelaren → nedslag vid målet
				SpellFx.projectile(parent, global_position, center_pos, color,
					func():
						SpellFx.burst(parent, center_pos, color, 16, 110.0)
						_spawn_spell_flash(parent, center_pos, color, 1.6, 130.0))

## Kort ljusblixt vid en besvärjelses nedslag — "lyser upp rummet" ett ögonblick.
## Skalas inte av dygnet (till skillnad från ambient-ljus) så blixten alltid syns
## som tydlig träff-feedback, även i dagsljus. Tonar ut och städar sig själv.
func _spawn_spell_flash(parent: Node, pos: Vector2, color: Color, peak: float, radius: float) -> void:
	if parent == null:
		return
	var fl := Lighting.make_light(color, peak, radius)
	fl.global_position = pos
	parent.add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "energy", 0.0, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(fl.queue_free)

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
