extends Node3D
## Engångsverktyg: bygger en riktig zon med Zone3D (samma kamera/ljus som
## game3d) och tar skärmdumpar vid intressanta punkter — visuell QA av
## miljörenderingen. Kör: godot --path . res://tools/shot_zone.tscn
## Zon och punkter styrs av konstanterna nedan.

const ZONE_ID := "town"
## Namngivna vypunkter: label -> tile. Fylls i _ready ur legenddata när
## koordinaten inte är känd på förhand (player_start, bank, butik).
var _spots: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/zones/%s.json" % ZONE_ID, FileAccess.READ)
	var model := ZoneModel.new()
	model.parse(JSON.parse_string(f.get_as_text()), ZONE_ID)
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

	for label in _spots:
		var t: Vector2i = _spots[label]
		var focus := Zone3D.tile_to_world3(t)
		cam.position = focus + Vector3(0, 9.0, 6.0)
		for i in 8:
			await get_tree().process_frame
		var path := "user://shot_zone_%s_%s.png" % [ZONE_ID, label]
		get_viewport().get_texture().get_image().save_png(path)
		print("SPARAT: ", OS.get_user_data_dir(), "/shot_zone_%s_%s.png" % [ZONE_ID, label])
	get_tree().quit()
