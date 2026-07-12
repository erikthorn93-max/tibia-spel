extends SceneTree
## Engångsverktyg: kontaktkarta över stationsmodellerna (visuell QA efter
## procedural bygge). Kör: godot --path . -s res://tools/shot_stations.gd

const STATIONS := [
	"anvil", "stove", "alchemy_table", "rune_altar",
	"crafting_bench", "prayer_altar", "workbench",
]

func _init() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.8, 5.5)
	cam.rotation_degrees.x = -14.0
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
	box.size = Vector3(12, 0.1, 6)
	floor_mi.mesh = box
	floor_mi.position.y = -0.05
	root.add_child(floor_mi)

	for i in STATIONS.size():
		var inst: Node3D = (load("res://assets/models3d/station_%s.glb" % STATIONS[i]) as PackedScene).instantiate()
		inst.position = Vector3((float(i) - 3.0) * 1.5, 0, 0)
		root.add_child(inst)

	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("user://shot_stations.png")
	print("SPARAT: ", OS.get_user_data_dir(), "/shot_stations.png")
	quit()
