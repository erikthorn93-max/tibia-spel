class_name Player
extends Node2D
## Vy för spelaren: targeting + auto-attack + gathering + spells + ljus/auror.
## Gridrörelsen (steg, auto-walk, facing, bump-unlock) bor i PlayerSim — vyn
## interpolerar position ur sim.move_progress och delegerar bakåtkompatibelt.

const TILE := 32
const GATHER_INTERVAL := 2.0

var sim: PlayerSim
var _zone_node: Node2D
var zone: Node2D:                     # sätts av World vid zonladdning
	get: return _zone_node
	set(z):
		_zone_node = z
		sim.zone = z.model if z != null else null
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var target: Node2D = null
var gather_target: Node2D = null
var _gather_timer := 0.0
var _status_aura: CPUParticles2D = null

# ── Delegation till simuleringen (bakåtkompatibelt API) ───────────────────────
var tile: Vector2i:
	get: return sim.tile
	set(v): sim.tile = v
var facing: Vector2i:
	get: return sim.facing
	set(v): sim.facing = v
var move_speed: float:                # tiles/sek
	get: return sim.move_speed
	set(v): sim.move_speed = v

func _init() -> void:
	sim = PlayerSim.new()
	sim.moved.connect(_on_sim_moved)
	sim.step_completed.connect(_on_sim_step_completed)
	sim.facing_changed.connect(_on_sim_facing_changed)
	sim.message.connect(_on_sim_message)
	sim.attack_swung.connect(_on_sim_attack_swung)
	sim.arrow_fired.connect(_on_sim_arrow_fired)
	sim.healed.connect(_on_sim_healed)
	sim.spec_flash.connect(_on_sim_spec_flash)
	sim.spec_denied.connect(func(): Sfx.denied())
	sim.spec_released.connect(func(): Sfx.crit())

@onready var visual: CharacterVisual = $CharacterVisual

const Lighting = preload("res://world/lighting.gd")

var _light: PointLight2D = null   # spelarens eget sken (starkare med fackla)
var _light_t := 0.0               # tidsackumulator för fackelflimmer

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)
	GameState.appearance_changed.connect(func(): visual.apply_appearance(GameState.appearance))
	GameState.player_hit.connect(_on_player_hit)
	GameState.charm_feedback.connect(_on_charm_feedback)
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

## Floating text ovanför spelaren när en defensiv charm parerat (signal från GameState).
func _on_charm_feedback(text: String, color: Color) -> void:
	if get_parent() == null:
		return
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector2(0, -20)
	ft.setup(text, color, 12)

func snap_to(t: Vector2i) -> void:
	sim.snap_to(t)
	position = zone.tile_to_world(t)
	_from = position
	_to = position

func set_target(m: Node2D) -> void:
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	target = m
	sim.target = m.sim if m != null else null
	gather_target = null
	sim.auto_path = []
	if target:
		target.modulate = Color(1.4, 0.9, 0.9)   # röd markering som Tibia

func set_gather_target(n: Node2D) -> void:
	set_target(null)
	gather_target = n
	_gather_timer = 0.0
	if n and not sim.walk_adjacent_to(n.tile):
		gather_target = null

## Klick-för-att-gå: pathfinda till en ruta och auto-walka dit.
## Går ända fram till rutan (portaler/dörrar utlöses när spelaren kliver på).
func walk_to(t: Vector2i) -> void:
	set_target(null)
	gather_target = null
	sim.walk_to(t)

func _chebyshev(t: Vector2i) -> int:
	return sim.chebyshev(t)

## Vyns tick: läs input-intent, mata simuleringen, interpolera positionen och
## driv anfall/gathering/spells/ljus (flyttas i senare migrationssteg).
func _process(delta: float) -> void:
	var intent := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): intent = Vector2i.UP
	elif Input.is_action_pressed("move_down"): intent = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): intent = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): intent = Vector2i.RIGHT
	if intent != Vector2i.ZERO:
		gather_target = null     # manuell rörelse avbryter gather
	sim.advance(delta, intent)
	position = _from.lerp(_to, sim.move_progress)
	visual.set_walk(sim.move_progress < 1.0, sim.move_progress)   # gång-studs/andning
	# Målnoden kan ha frigjorts (zonbyte/despawn) — nolla sim-målet i så fall.
	if target != null and not is_instance_valid(target):
		target = null
		sim.target = null
	sim.attack_tick(delta)
	_update_gather(delta)
	_update_spells()
	_update_player_light(delta)

# ── Reaktioner på simuleringens signaler ──────────────────────────────────────
## Steg påbörjat: sätt interpolationsmål (positionen läses ur move_progress).
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	_from = zone.tile_to_world(from)
	_to = zone.tile_to_world(to)

## Landade på en tile: portaler/dörrar/trappor utlöses av vyn (World-anrop).
func _on_sim_step_completed(_t: Vector2i) -> void:
	_check_portal()

func _on_sim_facing_changed(dir: Vector2i) -> void:
	visual.face(dir)

func _on_sim_message(text: String) -> void:
	World.hud.show_message(text)

## Sving utförd (träff eller miss): spela attack-stöten mot facing-riktningen.
func _on_sim_attack_swung(dir: Vector2i) -> void:
	visual.play_attack(dir)

## Pil avlossad: projektil till målets ruta i ammunitionens färg (annars
## bågens), liten träffskur vid nedslaget — spegelbilden av monstrens skott.
func _on_sim_arrow_fired(_from_t: Vector2i, to_t: Vector2i) -> void:
	var fx_parent := get_parent()
	if fx_parent == null or zone == null:
		return
	var to_pos: Vector2 = zone.tile_to_world(to_t)
	var col := PlayerSim.arrow_color()
	SpellFx.projectile(fx_parent, global_position, to_pos, col,
		func(): SpellFx.burst(fx_parent, to_pos, col, 6, 55.0))

## Leech-charm läkte: grön "+N" ovanför spelaren.
func _on_sim_healed(amount: float) -> void:
	_spawn_heal_float(amount)

## Kraftslags-nedslag: guldblixt vid den träffade tilen.
func _on_sim_spec_flash(t: Vector2i) -> void:
	var parent := get_parent()
	if parent != null and zone != null:
		_spawn_spell_flash(parent, zone.tile_to_world(t), Color(1.0, 0.85, 0.35), 1.9, 140.0)

## Släpper kraftslaget (specialattack) mot nuvarande mål. Anropas av HUD:en.
## Vyn samlar in MonsterSims nära målet (för cleave) och låter sim avgöra allt.
func try_special() -> void:
	if target != null and not is_instance_valid(target):
		target = null
		sim.target = null
	var nearby: Array = []
	if target != null:
		for m in _monsters_near(target.tile, 1):
			nearby.append(m.sim)
	sim.try_special(nearby)

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
