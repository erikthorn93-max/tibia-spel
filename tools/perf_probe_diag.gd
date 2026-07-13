extends Node
## Diagnosprobe (engångs): bygger town i game3d och mäter FPS med olika
## delar avstängda för att attribuera kostnaden.
## Kör: godot --path . res://tools/perf_probe_diag.tscn

const MEASURE_FRAMES := 120

var game: Node3D

func _measure(label: String) -> void:
	for i in 20:
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		await get_tree().process_frame
	var fps := float(MEASURE_FRAMES) / (float(Time.get_ticks_usec() - t1) / 1e6)
	print("DIAG %-28s %6.0f FPS | %5d dc | %.2fM tris" % [label, fps,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6])

func _set_group(prefix: String, vis: bool) -> void:
	var zv: Node = game.get("zone_view")
	for c in zv.get_children():
		if String(c.name).begins_with(prefix):
			c.visible = vis

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = (load("res://world/game3d.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 5:
		await get_tree().process_frame
	game.load_zone("town")

	await _measure("baslinje")
	var sun: DirectionalLight3D = game.get("_sun")
	sun.shadow_enabled = false
	await _measure("utan skuggor")
	sun.shadow_enabled = true

	_set_group("Scatter_mossy_rock", false)
	await _measure("utan klippscatter")
	_set_group("Scatter_", false)
	await _measure("utan all scatter")
	sun.shadow_enabled = false
	await _measure("utan scatter+skuggor")
	_set_group("Terrain_", false)
	await _measure("utan terräng+scatter+skuggor")
	get_tree().quit()
