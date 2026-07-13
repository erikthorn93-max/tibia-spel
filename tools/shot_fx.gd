extends SceneTree
## Engångsverktyg: kontaktkarta över SpellFx3D-effekterna (visuell QA).
## Spawnar alla effekttyper samtidigt och skjuter en bild mitt i förloppet.
## Kör: godot --path . -s res://tools/shot_fx.gd

func _init() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 9.5)
	cam.rotation_degrees.x = -14.0
	cam.fov = 55.0
	root.add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18)   # mörk fond så fx syns
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var floor_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18, 0.1, 8)
	floor_mi.mesh = box
	floor_mi.position.y = -0.05
	root.add_child(floor_mi)

	for i in 3:
		await process_frame

	# Bakre raden: skur + dödsskurar per stil. Främre: fontän, ring, projektil.
	SpellFx3D.burst(root, Vector3(-7, 0.6, -1.5), Color(1.0, 0.45, 0.12), 18, 3.4)
	var kinds := ["bone", "ooze", "ember", "ice", "dust"]
	for i in kinds.size():
		SpellFx3D.death_burst(root, Vector3(-4.5 + i * 2.0, 0.4, -1.5),
			Color(0.7, 0.3, 0.3), kinds[i])
	SpellFx3D.fountain(root, Vector3(-6, 0, 1.8), Color(1.0, 0.88, 0.3), 22)
	SpellFx3D.heal_sparkle(root, Vector3(-4, 0, 1.8))
	SpellFx3D.ring(root, Vector3(-1.5, 0, 1.8), Color(0.55, 0.85, 1.0), 1.2)
	SpellFx3D.projectile(root, Vector3(0.5, 0, 1.8), Vector3(7.5, 0, 1.8),
		Color(0.78, 0.55, 1.00))
	SpellFx3D.flash(root, Vector3(6.5, 0, -1.5), Color(1.0, 0.5, 0.15), 2.5, 4.0)

	await create_timer(0.16).timeout
	root.get_texture().get_image().save_png("user://shot_fx.png")
	print("SPARAT: ", OS.get_user_data_dir(), "/shot_fx.png")
	quit()
