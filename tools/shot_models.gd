extends SceneTree
## Engångsverktyg: kontaktkarta över karaktärsmodellerna (visuell QA efter
## ombakning). Kör: godot --path . -s res://tools/shot_models.gd

const MODELS := [
	"middle_aged_man", "young_woman", "boy", "king", "toddler", "orc",
	"zombie", "skeleton", "wolf", "bear", "rat", "rabbit",
]

func _init() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.2, 7.5)
	cam.rotation_degrees.x = -12.0
	cam.fov = 50.0
	root.add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var floor_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14, 0.1, 8)
	floor_mi.mesh = box
	floor_mi.position.y = -0.05
	root.add_child(floor_mi)

	# Två rader à sex modeller, ansiktena mot kameran (glTF-framåt = +Z).
	for i in MODELS.size():
		var inst: Node3D = (load("res://assets/models3d/%s.glb" % MODELS[i]) as PackedScene).instantiate()
		inst.scale = Vector3.ONE * 1.5
		@warning_ignore("integer_division")
		var row: int = i / 6
		var col: int = i % 6
		inst.position = Vector3(float(col - 2) * 1.9 - 0.95, 0, float(row) * 2.4 - 1.2)
		root.add_child(inst)

	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("user://shot_models.png")
	print("SPARAT: ", OS.get_user_data_dir(), "/shot_models.png")
	quit()
