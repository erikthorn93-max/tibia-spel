extends Node2D
## Spelets rotscen. Registrerar sig hos World och startar.

var _fps_log_timer := 0.0
var _perftest := false
var _perftest_elapsed := 0.0
var _fps_samples: Array = []

func _ready() -> void:
	World.game_root = self
	var hud := preload("res://ui/hud.tscn").instantiate()
	add_child(hud)
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
	_fps_log_timer += delta
	if _fps_log_timer >= 2.0:
		_fps_log_timer = 0.0
		print_debug("FPS: %d  Noder: %d" % [Engine.get_frames_per_second(), get_tree().get_node_count()])
		if _perftest:
			_fps_samples.append(Engine.get_frames_per_second())
	if _perftest:
		_perftest_elapsed += delta
		if _perftest_elapsed >= 14.0:
			# första samplet är uppstartsskevt — rapportera resten
			var rest: Array = _fps_samples.slice(1)
			print("PERFTEST: samples=%s min=%d" % [str(rest), rest.min() if rest else 0])
			get_tree().quit()
