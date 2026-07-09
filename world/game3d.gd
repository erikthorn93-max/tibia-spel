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
var hud: Hud3D              # HUD-bryggan: 2D-panelerna + basraden
var _monsters_root: Node3D
var _npcs_root: Node3D
var _zone_epoch := 0        # ogiltigförklarar respawn-timers vid zonbyte
var _sun: DirectionalLight3D
var _env: Environment
var _sky_cap := 1.0         # himmelstak per biom (grottor ser aldrig dagsljus)
var _biome_fog: Dictionary = {}   # zonens biomdimma (vädret har företräde)
var _ambient: AmbientParticles3D
var _weather_fx: WeatherParticles3D
# Blixt & dunder (åska) — samma tillstånd som 2D:s game_root.
var _storm := false
var _strike_in := 0.0        # sekunder till nästa blixt
var _flash_t := 99.0         # sekunder sedan senaste blixt (>= FLASH_DUR = inget sken)
var _thunder_in := -1.0      # sekunder kvar tills dundret (<0 = inget väntar)
var _rng := RandomNumberGenerator.new()
var _last_surface_zone := ""   # för dungeonexit tillbaka till ytan
var _last_surface_tile := Vector2i(-1, -1)
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
	_ambient = AmbientParticles3D.new()
	add_child(_ambient)
	_weather_fx = WeatherParticles3D.new()
	add_child(_weather_fx)
	hud = Hud3D.new()
	add_child(hud)
	hud.attach_minimap(_map_monster_tiles, _map_npc_list, _map_loot_tiles)
	hud.hotkey_bar.caster = player           # hotbaren kastar via Player3D
	SpellSystem.monster_source = _live_monster_sims
	player.sim.message.connect(_show_msg)
	ArenaSystem.wave_started.connect(_on_arena_wave_started)
	ArenaSystem.arena_won.connect(_on_arena_won)
	ArenaSystem.arena_failed.connect(_on_arena_failed)
	load_zone(START_ZONE)

## Autoloads överlever scenen — lämna ingen monsterkälla mot en fri-ad nod.
func _exit_tree() -> void:
	if SpellSystem.monster_source.is_valid() \
			and SpellSystem.monster_source.get_object() == self:
		SpellSystem.monster_source = Callable()

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
	# Lämnar man arenan mitt i en omgång räknas det som uppgivet (som 2D).
	if ArenaSystem.is_active() and zone_id != ArenaSystem.ARENA_ZONE:
		ArenaSystem.abort()
	_zone_epoch += 1
	if zone_view != null:
		zone_view.queue_free()
	if _monsters_root != null:
		_monsters_root.queue_free()
	if _npcs_root != null:
		_npcs_root.queue_free()
	model = ZoneModel.new()
	model.parse(data, zone_id)
	World.zone_model = model   # minimapen m.fl. läser zondata härifrån (som 2D)
	GameState.current_zone = zone_id
	QuestSystem.record_explore(zone_id)
	zone_view = Zone3D.new()
	add_child(zone_view)
	zone_view.build(model)
	_monsters_root = Node3D.new()
	add_child(_monsters_root)
	_npcs_root = Node3D.new()
	add_child(_npcs_root)
	player.sim.zone = model
	player.sim.target = null   # målet hörde till förra zonen
	player.gather_target = null
	_target_view = null
	player.snap_to(at_tile if at_tile.x >= 0 else model.player_start)
	_apply_biome_mood(zone_id)
	_spawn_monsters()
	_spawn_npcs()
	_spawn_grave_if_here()
	hud.close_all()   # öppna paneler/dialoger hör till förra zonen

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

# ── Tangenter: kraftslag (F) och hälsodryck — samma actions som 2D. ──────────
# Panel-toggles (I/K/B/J/P/C) ägs av HUD-bryggan (Hud3D).
func _process(delta: float) -> void:
	_update_daylight(delta)
	_ambient.position = player.position   # partikellådorna följer spelaren
	_weather_fx.position = player.position
	if Input.is_action_just_pressed("weapon_spec"):
		_try_special()
	if Input.is_action_just_pressed("use_potion"):
		if not GameState.use_item("health_potion"):
			_show_msg("Ingen hälsodryck.")

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

## Monster på rutan → auto-attack-mål; gather-nod → gather-mål (spelaren
## auto-walkar intill och tickar); NPC/station → interaktion (dialog/panel);
## annars klick-för-att-gå. Målet behålls medan man går (Tibia-stil).
func _click_tile(t: Vector2i) -> void:
	var m := _monster_at(t)
	if m != null:
		_set_target(m)
		return
	var g := _gather_at(t)
	if g != null:
		_clear_target()
		player.set_gather_target(g)
		return
	var n := _interactable_at(t)
	if n != null:
		n.interact()
		return
	player.walk_to(t)

func _monster_at(t: Vector2i) -> Monster3D:
	if _monsters_root == null:
		return null
	for m in _monsters_root.get_children():
		if m is Monster3D and not m.sim.dead and m.sim.tile == t:
			return m
	return null

## Klickbar entitet (Npc3D/Station3D) på rutan — allt i _npcs_root har
## tile + interact() med egna räckviddsregler.
func _interactable_at(t: Vector2i) -> Node3D:
	if _npcs_root == null:
		return null
	for n in _npcs_root.get_children():
		if n.has_method("interact") and n.get("tile") == t:
			return n
	return null

func _gather_at(t: Vector2i) -> GatherNode3D:
	if _npcs_root == null:
		return null
	for n in _npcs_root.get_children():
		if n is GatherNode3D and n.tile == t:
			return n
	return null

## Släpper auto-attack-målet (röd ring + sim-mål).
func _clear_target() -> void:
	if _target_view != null and is_instance_valid(_target_view):
		_target_view.set_targeted(false)
	_target_view = null
	player.sim.target = null

func _set_target(m: Monster3D) -> void:
	_clear_target()
	player.gather_target = null   # strid ersätter gather (som 2D:s set_target)
	_target_view = m
	m.set_targeted(true)
	player.sim.target = m.sim

# ── NPC:er + stationer (samma urval som world.gd:s _spawn_world_objects) ──────
func _spawn_npcs() -> void:
	for t in model.shop_points:
		_spawn_npc3d("shop", t)
	for t in model.bank_points:
		_spawn_npc3d("bank", t)
	for t in model.taskmaster_points:
		_spawn_npc3d("taskmaster", t)
	for t in model.spell_teacher_points:
		_spawn_npc3d("spell_teacher", t)
	for id in DialogueDB.npcs:
		var nd: Dictionary = DialogueDB.npcs[id]
		if String(nd["zone"]) == model.zone_id:
			_spawn_npc3d("dialogue",
				Vector2i(int(nd["position"][0]), int(nd["position"][1])), id)
	for sp in model.station_points:
		var s := Station3D.new()
		_npcs_root.add_child(s)
		s.setup(String(sp["station"]), sp["tile"])
	for np in model.node_points:
		var gn := GatherNode3D.new()
		_npcs_root.add_child(gn)
		gn.fx = _fx
		gn.setup(String(np["node"]), np["tile"])
	for t in model.chest_points:
		var c := Chest3D.new()
		_npcs_root.add_child(c)
		c.setup(t, model.dungeon_theme)

func _spawn_npc3d(kind: String, t: Vector2i, id := "") -> void:
	var n := Npc3D.new()
	_npcs_root.add_child(n)
	n.setup(kind, t, id)

## Attack-spells träffar via SpellSystem — mata den med levande simmar.
## (Sim-signalerna driver Monster3D-vyns träff-feedback som vanligt.)
func _live_monster_sims() -> Array:
	var out: Array = []
	if _monsters_root != null:
		for m in _monsters_root.get_children():
			if m is Monster3D and not m.sim.dead:
				out.append(m.sim)
	return out

# ── Minimap-källor: entiteter per tile (terräng läses ur World.zone_model) ────
func _map_monster_tiles() -> Array:
	var out: Array = []
	if _monsters_root != null:
		for m in _monsters_root.get_children():
			if m is Monster3D and not m.sim.dead:
				out.append(m.sim.tile)
	return out

func _map_npc_list() -> Array:
	var out: Array = []
	if _npcs_root != null:
		for n in _npcs_root.get_children():
			if n is Npc3D and n.kind == "dialogue":
				out.append({"tile": n.tile, "npc_id": n.npc_id})
	return out

func _map_loot_tiles() -> Array:
	var out: Array = []
	if _npcs_root != null:
		for n in _npcs_root.get_children():
			if n is GroundItem3D:
				out.append(n.tile)
	return out

# ── Markloot (samma regler som 2D: monsterdrop, grav) ─────────────────────────
func _spawn_loot3d(drops: Array, t: Vector2i) -> GroundItem3D:
	var gi := GroundItem3D.new()
	_npcs_root.add_child(gi)
	gi.fx = _fx
	gi.setup(drops, t)
	return gi

## Monsterdöd: simmen har rullat looten — vyn lägger påsen på dödstilen.
func _on_monster_dropped(drops: Array, msim: MonsterSim) -> void:
	if not drops.is_empty() and _npcs_root != null:
		_spawn_loot3d(drops, msim.tile)

## Återskapar gravens lootpåse om spelaren är i grav-zonen (som world.gd:s
## _spawn_grave_if_here). Persistent: blinkar inte, rensar graven vid pickup.
func _spawn_grave_if_here() -> void:
	if not GameState.has_grave() or GameState.grave_zone != model.zone_id:
		return
	var gi := _spawn_loot3d(GameState.grave_drops, GameState.grave_tile)
	gi.persistent = true
	gi.is_grave = true

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
	m.sim.died.connect(_on_monster_dropped.bind(m.sim))
	if float(sp["respawn"]) >= 0.0:
		m.sim.died.connect(_on_monster_died.bind(sp, _zone_epoch))

## Respawn efter dödsfall — om vi fortfarande är kvar i samma zon.
func _on_monster_died(_drops: Array, sp: Dictionary, epoch: int) -> void:
	await get_tree().create_timer(float(sp["respawn"])).timeout
	if _zone_epoch == epoch:
		_spawn_monster3d(sp)

# ── Arena (samma orkestrering som world.gd, men med Monster3D) ────────────────
## Spawnar nästa arenavåg på lediga rutor minst 2 steg från spelaren.
## world.gd:s handler är gated på 2D-zonen — här gäller spegelbilden:
## bara när 3D-vyn faktiskt visar arenazonen.
func _on_arena_wave_started(index: int, spawns: Array) -> void:
	if model == null or model.zone_id != ArenaSystem.ARENA_ZONE:
		return
	var tiles := _arena_spawn_tiles()
	var ti := 0
	for s in spawns:
		for _i in range(int(s.get("count", 0))):
			if ti >= tiles.size():
				break
			_spawn_monster3d({"monster": String(s["monster"]),
				"tile": tiles[ti], "respawn": -1.0})
			ti += 1
	var label := String(ArenaSystem.waves[index].get("name", ""))
	_show_msg("Våg %d/%d%s" % [index + 1, ArenaSystem.wave_count(),
		(" — " + label) if label != "" else ""])

## Lediga, gångbara rutor minst 2 steg från spelaren, blandade (som world.gd).
func _arena_spawn_tiles() -> Array:
	var ptile: Vector2i = player.sim.tile
	var out: Array = []
	for y in range(model.grid_size.y):
		for x in range(model.grid_size.x):
			var t := Vector2i(x, y)
			if not model.is_walkable(t) or model.is_occupied(t):
				continue
			if maxi(absi(t.x - ptile.x), absi(t.y - ptile.y)) < 2:
				continue
			out.append(t)
	out.shuffle()
	return out

func _on_arena_won() -> void:
	_show_msg("Du har besegrat arenan! Publiken ropar ditt namn.")

func _on_arena_failed(_at_wave: int) -> void:
	_show_msg("Du lämnade sanden. Arenan glömmer dig.")

# ── Spelardöd (Tibia-återkomst: hemzon, full HP, XP-straff, gravsten) ─────────
func _on_player_died() -> void:
	_show_msg("Du är död.")
	# Döds-droppen bokförs på dödstilen INNAN respawn flyttar spelaren.
	# (World._on_player_died är gated på 2D-zonen — bokföringen delas.)
	World.drop_death_loot()
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
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = Atmosphere3D.DAY_AMBIENT
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_update_daylight()

## Dygnsljus + väderstämning: sol/ambient/himmel följer TimeOfDay
## (Atmosphere3D:s rena kurvor), vädret dämpar ljuset och äger dimman när
## det pågår (annars biomdimman), och blixtar lyser upp världen under åska.
## Bara skalära parametersättningar, ingen allokering per frame.
func _update_daylight(delta := 0.0) -> void:
	if _sun == null or _env == null:
		return
	var f: float = TimeOfDay.day_fraction
	var wx := _resolved_weather()
	var ls := Atmosphere3D.weather_light_scale(wx)
	var flash := _tick_lightning(wx == Weather.STORM, delta)
	_sun.light_energy = lerpf(Atmosphere3D.sun_energy(f) * ls,
		Atmosphere3D.DAY_SUN * 1.5, flash)
	_sun.light_color = Atmosphere3D.sun_color(f).lerp(Color(1, 1, 1), flash)
	_env.ambient_light_energy = lerpf(Atmosphere3D.ambient_energy(f) * ls,
		Atmosphere3D.DAY_AMBIENT * 1.5, flash)
	_env.background_energy_multiplier = Atmosphere3D.sky_energy(f) * _sky_cap * ls
	var fog: Dictionary = Atmosphere3D.weather_fog(wx)
	if fog.is_empty():
		fog = _biome_fog
	_env.fog_enabled = not fog.is_empty()
	if not fog.is_empty():
		_env.fog_light_color = fog["color"]
		_env.fog_density = fog["density"]

## Zonens upplösta väder ("dynamic" → det globala omgivningsvädret).
func _resolved_weather() -> String:
	if model == null:
		return Weather.CLEAR
	return Weather.resolve(model.weather, WeatherSystem.current)

## Blixt & dunder under åska — samma rena Weather-kurvor och schemaläggning
## som 2D:s game_root. Returnerar blixtens ljusstyrka 0..1 just nu.
func _tick_lightning(storm_active: bool, delta: float) -> float:
	if storm_active and not _storm:
		_strike_in = Weather.next_strike_delay(_rng.randf())   # första nedslaget
	_storm = storm_active
	if storm_active:
		_strike_in -= delta
		if _strike_in <= 0.0:
			_flash_t = 0.0
			_thunder_in = Weather.thunder_delay(_rng.randf())
			_strike_in = Weather.next_strike_delay(_rng.randf())
	# Dundret efter blixten (löper även om man hinner lämna zonen mitt i).
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			Sfx.thunder()
	if _flash_t < Weather.FLASH_DUR:
		_flash_t += delta
		return Weather.lightning_brightness(_flash_t)
	return 0.0

## Biomstämning per zon: tematisk djupdimma (billig exponentiell — ingen
## volymetrik) och himmelstak (grottor ser aldrig dagsljus). Dimman läggs
## på i _update_daylight där vädret har företräde.
func _apply_biome_mood(zone_id: String) -> void:
	var biome := Biome.classify(zone_id)
	_sky_cap = Atmosphere3D.sky_cap(biome)
	_biome_fog = Atmosphere3D.fog_for(biome)
	_update_daylight()

func _show_msg(text: String) -> void:
	hud.show_message(text)
