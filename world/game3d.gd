extends Node3D
## Startscen för 3D-slicen (steg 4): kör zoner som ZoneModel genom Zone3D +
## Player3D + Monster3D — exakt samma simlager som 2D-spelet. Kör scenen
## direkt (F6 på game3d.tscn, eller spela_tibia3d.bat) och gå runt med
## piltangenter/WASD. Portaler, trappor, husdörrar och dungeon-nedgångar
## fungerar; monster jagar och slår via MonsterSim.
##
## Prestandaramar: ingen SSIL/post-processing, MultiMesh för terräng,
## material skapas vid spawn — aldrig per träff.

const DungeonGen = preload("res://world/dungeon_generator.gd")

const START_ZONE := "thais_fields"

var model: ZoneModel
var zone_view: Zone3D
var player: Player3D
var _monsters_root: Node3D
var _zone_epoch := 0        # ogiltigförklarar respawn-timers vid zonbyte
var _last_surface_zone := ""   # för dungeonexit tillbaka till ytan
var _last_surface_tile := Vector2i(-1, -1)
var _hud_hp: Label
var _hud_spec: Label
var _hud_msg: Label
var _hud_panel: Label      # togglebar informationspanel (skills/quests)
var _panel_mode := ""      # "" | "skills" | "quests"
var _msg_tw: Tween
var _target_view: Monster3D = null   # vyn för spelarens auto-attack-mål
var _fx: FloatingText3D              # delad flyttext-pool (skada/läkning/taggar)

func _ready() -> void:
	_fx = FloatingText3D.new()
	add_child(_fx)
	player = Player3D.new()
	add_child(player)
	player.fx = _fx
	player.sim.step_completed.connect(_on_player_step_completed)
	player.sim.spec_flash.connect(_on_spec_flash)
	GameState.player_died.connect(_on_player_died)
	_setup_camera()
	_setup_light()
	_setup_hud()
	load_zone(START_ZONE)

# ── Zonladdning ───────────────────────────────────────────────────────────────
func load_zone(zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	_apply_model(JSON.parse_string(f.get_as_text()), zone_id, at_tile)

func enter_dungeon(theme: String) -> void:
	_last_surface_zone = GameState.current_zone
	_last_surface_tile = player.sim.tile
	_apply_model(DungeonGen.generate(theme, randi()), "dungeon:" + theme)

## Bygger om världen kring en ny ZoneModel: river gamla vyer/monster,
## bokför zonen (samma bokföring som world.gd) och placerar spelaren.
func _apply_model(data: Dictionary, zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	_zone_epoch += 1
	if zone_view != null:
		zone_view.queue_free()
	if _monsters_root != null:
		_monsters_root.queue_free()
	model = ZoneModel.new()
	model.parse(data, zone_id)
	GameState.current_zone = zone_id
	QuestSystem.record_explore(zone_id)
	zone_view = Zone3D.new()
	add_child(zone_view)
	zone_view.build(model)
	_monsters_root = Node3D.new()
	add_child(_monsters_root)
	player.sim.zone = model
	player.sim.target = null   # målet hörde till förra zonen
	_target_view = null
	player.snap_to(at_tile if at_tile.x >= 0 else model.player_start)
	_spawn_monsters()

# ── Portalsteg (samma regler som player.gd:s _check_portal) ───────────────────
func _on_player_step_completed(t: Vector2i) -> void:
	if model.dungeon_entrances.has(t):
		enter_dungeon.call_deferred(String(model.dungeon_entrances[t]))
		return
	if not model.portals.has(t):
		return
	if model.portal_locks.has(t):
		var uid: String = model.portal_locks[t]
		if not UnlockSystem.try_unlock(uid):
			_show_msg(UnlockSystem.hint_for(uid))
			return
	var dest := String(model.portals[t])
	# Dungeonexit: tillbaka till rutan man gick ner från.
	var dest_tile := Vector2i(-1, -1)
	if GameState.current_zone.begins_with("dungeon:") and dest == _last_surface_zone:
		dest_tile = _last_surface_tile
	load_zone.call_deferred(dest, dest_tile)

# ── Tangenter: kraftslag (F) och hälsodryck — samma actions som 2D ────────────
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("weapon_spec"):
		_try_special()
	if Input.is_action_just_pressed("use_potion"):
		if not GameState.use_item("health_potion"):
			_show_msg("Ingen hälsodryck.")
	if Input.is_action_just_pressed("toggle_skills"):
		_toggle_panel("skills")
	if Input.is_action_just_pressed("toggle_quest_log"):
		_toggle_panel("quests")

## Släpper kraftslaget mot nuvarande mål. Vyn samlar in MonsterSims inom
## 1 tile från målet (cleave-kandidater) — samma kontrakt som player.gd.
func _try_special() -> void:
	var target: MonsterSim = player.sim.target
	var nearby: Array = []
	if target != null and not target.dead and _monsters_root != null:
		for m in _monsters_root.get_children():
			if m is Monster3D and not m.sim.dead \
					and maxi(absi(m.sim.tile.x - target.tile.x),
						absi(m.sim.tile.y - target.tile.y)) <= 1:
				nearby.append(m.sim)
	player.sim.try_special(nearby)

## Kraftslags-nedslag: guldstjärna + kort ljuspuls vid den träffade tilen.
## (Sällsynt händelse — engångsljuset är OK trots allokeringen.)
func _on_spec_flash(t: Vector2i) -> void:
	_fx.show_text(Zone3D.tile_to_world3(t), "✦", Color(1.0, 0.85, 0.2))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.3)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.position = Zone3D.tile_to_world3(t) + Vector3(0, 0.8, 0)
	add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.tween_callback(light.queue_free)

# ── Klick: targeta monster eller gå-till (samma UX som 2D) ────────────────────
## Vänsterklick projiceras som stråle mot markplanet (y=0) → tile.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := cam.project_ray_origin(mb.position)
	var dir := cam.project_ray_normal(mb.position)
	if absf(dir.y) < 0.0001:
		return   # strålen parallell med marken — inget nedslag
	var hit := origin - dir * (origin.y / dir.y)
	_click_tile(Zone3D.world3_to_tile(hit))

## Monster på rutan → auto-attack-mål; annars klick-för-att-gå.
## Målet behålls medan man går (Tibia-stil: attacken följer med).
func _click_tile(t: Vector2i) -> void:
	var m := _monster_at(t)
	if m != null:
		_set_target(m)
		return
	player.sim.walk_to(t)

func _monster_at(t: Vector2i) -> Monster3D:
	if _monsters_root == null:
		return null
	for m in _monsters_root.get_children():
		if m is Monster3D and not m.sim.dead and m.sim.tile == t:
			return m
	return null

func _set_target(m: Monster3D) -> void:
	if _target_view != null and is_instance_valid(_target_view):
		_target_view.set_targeted(false)
	_target_view = m
	m.set_targeted(true)
	player.sim.target = m.sim

# ── Monster ───────────────────────────────────────────────────────────────────
func _spawn_monsters() -> void:
	for sp in model.spawn_points:
		_spawn_monster3d(sp)

func _spawn_monster3d(sp: Dictionary) -> void:
	var mname := String(sp["monster"])
	# Otillgängliga bossar väntar på sin task — boss-markern är 2D-UI, hoppas över.
	if bool(MonsterDB.monsters.get(mname, {}).get("boss", false)) \
			and not TaskSystem.boss_available(mname):
		return
	var m := Monster3D.new()
	_monsters_root.add_child(m)
	m.player_sim = player.sim
	m.fx = _fx
	m.setup(mname, sp["tile"], model)
	# Samma elite-regel som world.gd: 5 % dag, 15 % natt.
	if randf() < (0.15 if TimeOfDay.is_night else 0.05):
		m.make_elite()
	if float(sp["respawn"]) >= 0.0:
		m.sim.died.connect(_on_monster_died.bind(sp, _zone_epoch))

## Respawn efter dödsfall — om vi fortfarande är kvar i samma zon.
func _on_monster_died(_drops: Array, sp: Dictionary, epoch: int) -> void:
	await get_tree().create_timer(float(sp["respawn"])).timeout
	if _zone_epoch == epoch:
		_spawn_monster3d(sp)

# ── Spelardöd (Tibia-återkomst: hemzon, full HP, XP-straff) ───────────────────
func _on_player_died() -> void:
	_show_msg("Du är död.")
	await get_tree().create_timer(1.5).timeout
	GameState.respawn()
	load_zone(GameState.current_zone, GameState.player_tile)

# ── Kamera, ljus, HUD ─────────────────────────────────────────────────────────
## 3/4-kamera som barn av spelaren → följer med utan egen following-kod och
## överlever zonbyten (spelarnoden återanvänds).
func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9.0, 6.0)
	cam.rotation_degrees.x = -56.0
	cam.fov = 45.0
	player.add_child(cam)
	cam.make_current()

func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

## Minimal overlay tills riktiga HUD:en bryggas in: HP-rad + meddelanderad.
func _setup_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud_hp = Label.new()
	_hud_hp.position = Vector2(12, 8)
	cl.add_child(_hud_hp)
	_hud_spec = Label.new()
	_hud_spec.position = Vector2(12, 34)
	cl.add_child(_hud_spec)
	_hud_msg = Label.new()
	_hud_msg.position = Vector2(12, 60)
	_hud_msg.modulate = Color(1.0, 0.9, 0.5)
	cl.add_child(_hud_msg)
	_hud_panel = Label.new()
	_hud_panel.position = Vector2(12, 96)
	_hud_panel.visible = false
	cl.add_child(_hud_panel)
	GameState.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.health, GameState.max_health)
	GameState.spec_changed.connect(_on_spec_changed)
	_on_spec_changed(GameState.spec_energy)
	# Panelen uppdateras live medan den är öppen.
	GameState.skill_changed.connect(func(_s): _refresh_panel())
	QuestSystem.quest_started.connect(func(_id): _refresh_panel())
	QuestSystem.step_advanced.connect(func(_id): _refresh_panel())
	QuestSystem.quest_completed.connect(func(_id): _refresh_panel())
	player.sim.message.connect(_show_msg)

func _on_hp_changed(h: float, mh: float) -> void:
	_hud_hp.text = "HP %d/%d" % [int(h), int(mh)]

## Spec-mätaren: procent under laddning, uppmaning när kraftslaget är redo.
func _on_spec_changed(energy: float) -> void:
	if CombatFormulas.spec_ready(energy):
		_hud_spec.text = "KRAFTSLAG (F)"
		_hud_spec.modulate = Color(1.0, 0.85, 0.2)
	else:
		_hud_spec.text = "Spec %d%%" % roundi(energy)
		_hud_spec.modulate = Color(0.8, 0.8, 0.8)

# ── Informationspanel: färdigheter (V) och uppdrag (L) — samma actions som 2D ─
func _toggle_panel(mode: String) -> void:
	_panel_mode = "" if _panel_mode == mode else mode
	_refresh_panel()

func _refresh_panel() -> void:
	if _hud_panel == null:
		return
	if _panel_mode == "":
		_hud_panel.visible = false
		return
	_hud_panel.visible = true
	_hud_panel.text = _skills_text() if _panel_mode == "skills" else _quests_text()

func _skills_text() -> String:
	var lines := ["— FÄRDIGHETER —", "Nivå %d" % GameState.level]
	var ids: Array = GameState.skills.keys()
	ids.sort()
	for id in ids:
		var namn := String(GameState.skill_defs.get(id, {}).get("name", id))
		lines.append("%s: %d" % [namn, int(GameState.skills[id]["level"])])
	return "\n".join(lines)

func _quests_text() -> String:
	var lines := ["— UPPDRAG —"]
	if QuestSystem.active.is_empty():
		lines.append("Inga aktiva uppdrag.")
	for id in QuestSystem.active:
		var q: Dictionary = QuestSystem.quests.get(id, {})
		var hint := QuestSystem.hint(id)
		lines.append("• %s%s" % [String(q.get("name", id)),
			(" — " + hint) if hint != "" else ""])
	if not QuestSystem.completed.is_empty():
		lines.append("Slutförda: %d" % QuestSystem.completed.size())
	return "\n".join(lines)

func _show_msg(text: String) -> void:
	_hud_msg.text = text
	_hud_msg.modulate.a = 1.0
	if _msg_tw != null and _msg_tw.is_valid():
		_msg_tw.kill()
	_msg_tw = create_tween()
	_msg_tw.tween_interval(2.0)
	_msg_tw.tween_property(_hud_msg, "modulate:a", 0.0, 0.8)
