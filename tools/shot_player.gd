extends SceneTree
## Engångsverktyg: rendera spelarkaraktären till PNG för visuell felsökning.
## Vänster: rå GLB (middle_aged_man). Höger: Player3D (overlay + livs-anim).
## Kör: godot --path . -s res://tools/shot_player.gd  (kräver fönster/GPU)

func _init() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 3.2)
	cam.rotation_degrees.x = -10.0
	cam.fov = 45.0
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

	# Golvplatta som referens för fotpunkten.
	var floor_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.1, 6)
	floor_mi.mesh = box
	floor_mi.position.y = -0.05
	root.add_child(floor_mi)

	# Vänster: rå GLB, framifrån (som kameran ser spelaren i spel: -Z mot kameran).
	var raw: Node3D = (load("res://assets/models3d/middle_aged_man.glb") as PackedScene).instantiate()
	raw.scale = Vector3.ONE * 1.7
	raw.rotation.y = PI
	raw.position = Vector3(-0.8, 0, 0)
	root.add_child(raw)

	# Höger: samma GLB med spelets outfit-overlay (additiv, svart = osynlig)
	# — för att se om overlayen påverkar utseendet.
	var ov: Node3D = (load("res://assets/models3d/middle_aged_man.glb") as PackedScene).instantiate()
	ov.scale = Vector3.ONE * 1.7
	ov.rotation.y = PI
	ov.position = Vector3(0.8, 0, 0)
	root.add_child(ov)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color.BLACK
	_apply_overlay(ov, mat)

	for i in 12:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("user://shot_player_front.png")

	# Vy 2: bakifrån (vrid modellerna 180°).
	raw.rotation.y = 0.0
	ov.rotation.y = 0.0
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("user://shot_player_back.png")

	print("SPARAT: ", OS.get_user_data_dir(), "/shot_player_front.png + _back.png")
	quit()

func _apply_overlay(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		_apply_overlay(c, mat)
