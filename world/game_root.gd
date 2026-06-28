extends Node2D
## Spelets rotscen. Registrerar sig hos World och startar.

const Atmosphere = preload("res://ui/atmosphere.gd")
const Weather = preload("res://ui/weather.gd")

var _fps_log_timer := 0.0
var _perftest := false
var _perftest_elapsed := 0.0
var _fps_samples: Array = []
var _canvas_mod: CanvasModulate   # äkta dag/natt-mörkläggning av hela världen

# ── Åska: blixtnedslag lyser upp CanvasModulate, dundret följer efter ──
var _rng := RandomNumberGenerator.new()
var _storm := false          # visar aktuell zon åska just nu?
var _strike_in := 0.0        # sekunder till nästa blixt
var _flash_t := 99.0         # sekunder sedan senaste blixt (>= FLASH_DUR = inget sken)
var _thunder_in := -1.0      # sekunder kvar tills dundret efter blixten (<0 = inget väntar)

func _ready() -> void:
	World.game_root = self
	# CanvasModulate mörklägger world-lagret (sprites + tiles); PointLight2D-noder
	# på spelaren, portaler och spells lägger tillbaka ljus → ljusöar i mörkret.
	_canvas_mod = CanvasModulate.new()
	add_child(_canvas_mod)
	_rng.randomize()
	var hud := preload("res://ui/hud.tscn").instantiate()
	add_child(hud)
	var aim := Node2D.new()
	aim.set_script(preload("res://entities/aim_controller.gd"))
	add_child(aim)
	World.aim = aim
	World.start_game(GameState.current_zone,
		GameState.player_tile if SaveManager.has_save() and GameState.player_tile != Vector2i.ZERO else Vector2i(-1, -1))
	if "--perftest" in OS.get_cmdline_user_args():
		_perftest = true
		_debug_spawn_rats()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_debug_spawn_rats()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_world_click()

func _handle_world_click() -> void:
	if World.player == null or World.current_zone == null:
		return
	var world_pos := get_global_mouse_position()
	var clicked_tile: Vector2i = World.current_zone.world_to_tile(world_pos)
	for child in World.current_zone.get_children():
		if child.get("tile") == clicked_tile:
			if child.has_method("take_damage") and not child.get("dead"):
				World.player.set_target(child)
				return
			elif child.has_method("attempt"):
				World.player.set_gather_target(child)
				return
	# Klick på marken: gå dit (Tibia-stil klick-för-att-gå)
	World.player.walk_to(clicked_tile)

func _debug_spawn_rats() -> void:
	var origin: Vector2i = GameState.player_tile
	var spawned := 0
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			if spawned >= 50: break
			var t := origin + Vector2i(dx, dy)
			if World.current_zone.is_walkable(t) and t != origin:
				World.spawn_monster("Råtta", t)
				spawned += 1
	print_debug("DEBUG: spawnade %d råttor" % spawned)

func _process(delta: float) -> void:
	if _canvas_mod != null:
		var tint := Atmosphere.canvas_tint(TimeOfDay.day_fraction)
		_canvas_mod.color = _apply_lightning(tint, delta)
	_fps_log_timer += delta
	if _fps_log_timer >= 2.0:
		_fps_log_timer = 0.0
		print_debug("FPS: %d  Noder: %d" % [Engine.get_frames_per_second(), get_tree().get_node_count()])
		if _perftest:
			_fps_samples.append(Engine.get_frames_per_second())
	if _perftest:
		_perftest_elapsed += delta
		if _perftest_elapsed >= 14.0:
			var rest: Array = _fps_samples.slice(1)
			print("PERFTEST: samples=%s min=%d" % [str(rest), rest.min() if rest else 0])
			get_tree().quit()

## True om spelaren just nu står i en zon vars upplösta väder är åska.
func _storm_active() -> bool:
	var z := World.current_zone
	if z == null or not is_instance_valid(z) or not ("weather" in z):
		return false
	return Weather.resolve(z.weather, WeatherSystem.current) == Weather.STORM

## Driver blixt & dunder och returnerar dygnstonen ev. uppljust av en blixt.
## Under åska schemaläggs nedslag; varje blixt lyser upp världen (mot vitt) och
## triggar ett dunder en stund senare (ljudet hinner ikapp ljuset).
func _apply_lightning(tint: Color, delta: float) -> Color:
	var active := _storm_active()
	if active and not _storm:
		_strike_in = Weather.next_strike_delay(_rng.randf())   # första nedslaget
	_storm = active

	if active:
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

	# Själva uppljusningen av världen.
	if _flash_t < Weather.FLASH_DUR:
		_flash_t += delta
		var b := Weather.lightning_brightness(_flash_t)
		return tint.lerp(Color(1, 1, 1, tint.a), b * 0.9)
	return tint
