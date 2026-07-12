extends SceneTree
## Engångsverktyg: kontaktkarta över kreatursmodellerna (visuell QA efter
## procedural bygge). Kör: godot --path . -s res://tools/shot_creatures.gd

const CREATURES := [
	"spider_brown", "spider_dark", "spider_green", "snake_green",
	"snake_sand", "snake_blue", "snake_dark", "snake_ember",
	"bird_dark", "bird_white", "bird_brown", "toad_green",
	"crab_red", "crab_dark",
]

func _init() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.4, 7.0)
	cam.rotation_degrees.x = -16.0
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

	# Två rader à sju modeller, nosarna mot kameran (glTF-framåt = +Z).
	for i in CREATURES.size():
		var inst: Node3D = (load("res://assets/models3d/creature_%s.glb" % CREATURES[i]) as PackedScene).instantiate()
		@warning_ignore("integer_division")
		var row: int = i / 7
		var col: int = i % 7
		inst.position = Vector3(float(col - 3) * 1.7, 0, float(row) * 2.6 - 1.3)
		root.add_child(inst)

	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("user://shot_creatures.png")
	print("SPARAT: ", OS.get_user_data_dir(), "/shot_creatures.png")
	quit()
