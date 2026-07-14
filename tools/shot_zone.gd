extends Node3D
## Engångsverktyg: bygger en riktig zon med Zone3D (samma kamera/ljus som
## game3d) och tar skärmdumpar vid intressanta punkter — visuell QA av
## miljörenderingen. Kör: godot --path . res://tools/shot_zone.tscn
## Zon väljs via cmdline: godot --path . res://tools/shot_zone.tscn -- forest
## (standard: town).

const ZONE_ID := "town"
## Namngivna vypunkter: label -> tile. Fylls i _ready ur legenddata när
## koordinaten inte är känd på förhand (player_start, bank, butik).
var _spots: Dictionary = {}

var _zone_id := ZONE_ID

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_zone_id = args[0]
	var f := FileAccess.open("res://data/zones/%s.json" % _zone_id, FileAccess.READ)
	var model := ZoneModel.new()
	model.parse(JSON.parse_string(f.get_as_text()), _zone_id)
	var zone := Zone3D.new()
	add_child(zone)
	zone.build(model)

	# Samma ljussättning som game3d (dagsläge).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = Atmosphere3D.DAY_AMBIENT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.rotation_degrees.x = -56.0
	cam.fov = 45.0
	add_child(cam)
	cam.make_current()

	_spots["start"] = model.player_start
	if not model.bank_points.is_empty():
		_spots["bank"] = model.bank_points[0]
	if not model.shop_points.is_empty():
		_spots["shop"] = model.shop_points[0]
	if not model.entrance_points.is_empty():
		_spots["door"] = model.entrance_points.keys()[0]
	for t: Vector2i in model.portals:
		if model.entrance_points.has(t) or model.stair_points.has(t):
			continue
		var key := "portal_locked" if model.portal_locks.has(t) else "portal"
		if not _spots.has(key):
			_spots[key] = t
	if not model.dungeon_entrances.is_empty():
		_spots["down"] = model.dungeon_entrances.keys()[0]
	for ch in ["t", "r"]:
		var best := Vector2i(-1, -1)
		var best_n := -1
		for t: Vector2i in model.terrain:
			if model.terrain[t] != ch:
				continue
			var n := 0
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					if model.terrain.get(t + Vector2i(dx, dy), "") == ch:
						n += 1
			if n > best_n:
				best_n = n
				best = t
		if best.x >= 0:
			_spots["trees" if ch == "t" else "rocks"] = best

	for label in _spots:
		var t: Vector2i = _spots[label]
		var focus := Zone3D.tile_to_world3(t)
		cam.position = focus + Vector3(0, 9.0, 6.0)
		for i in 8:
			await get_tree().process_frame
		var path := "user://shot_zone_%s_%s.png" % [_zone_id, label]
		get_viewport().get_texture().get_image().save_png(path)
		print("SPARAT: ", OS.get_user_data_dir(), "/shot_zone_%s_%s.png" % [_zone_id, label])
	get_tree().quit()
