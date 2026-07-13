extends Node
## Prestandaprobe för 3D-slicen: kör game3d i värsta zonerna och rapporterar
## zonbygge-tid, FPS (snitt + värsta frame) och renderingsstatistik.
## Kör: godot --path . res://tools/perf_probe.tscn
##
## Zonval: town är geometri-stressen (störst, ~56k tiles), ice är
## entitets-stressen (flest spawn-punkter). Vsync stängs av så FPS-taket
## inte maskerar kostnaden.

const ZONES := ["town", "ice"]
const WARMUP_FRAMES := 30
const MEASURE_FRAMES := 300

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node3D = (load("res://world/game3d.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 5:
		await get_tree().process_frame

	for zone in ZONES:
		var t0 := Time.get_ticks_usec()
		game.load_zone(zone)
		var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
		var worst_us := 0
		var prev := Time.get_ticks_usec()
		var t1 := prev
		for i in MEASURE_FRAMES:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst_us = maxi(worst_us, now - prev)
			prev = now
		var total_s := float(Time.get_ticks_usec() - t1) / 1e6
		print("PERF %s: bygge %.0f ms | %.0f FPS snitt | värsta frame %.1f ms | %d draw calls | %.2fM tris | %d objekt | %d monster" % [
			zone, build_ms, float(MEASURE_FRAMES) / total_s,
			float(worst_us) / 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			game.get("_monsters_root").get_child_count(),
		])
	get_tree().quit()
