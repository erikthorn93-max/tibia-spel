extends GutTest
## Tester för SpellFx3D — 3D-motsvarigheten till SpellFx: partikelskurar,
## dödsskurar per stil, fontän, ring, projektil och ljusblixt.

const FX3D = preload("res://entities/spell_fx3d.gd")

func _particles_in(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is CPUParticles3D:
			out.append(c)
	return out

func test_burst_spawnar_partiklar() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.burst(root, Vector3(1, 0, 1), Color.RED, 16, 3.0)
	var ps := _particles_in(root)
	assert_eq(ps.size(), 1, "burst ska spawna en CPUParticles3D")
	var p: CPUParticles3D = ps[0]
	assert_true(p.emitting, "skuren ska emittera direkt")
	assert_true(p.one_shot, "skuren ska vara en engångshändelse")
	assert_eq(p.amount, 16, "antal partiklar ska skickas vidare")
	assert_not_null(p.mesh, "partiklarna ska ha den delade billboard-meshen")

func test_burst_delar_mesh_mellan_skurar() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.burst(root, Vector3.ZERO, Color.RED)
	FX3D.burst(root, Vector3.ONE, Color.BLUE)
	var ps := _particles_in(root)
	assert_eq(ps.size(), 2)
	assert_same(ps[0].mesh, ps[1].mesh,
		"partikelmeshen ska delas statiskt mellan skurar (ingen ombyggnad)")

func test_fountain_pekar_uppat() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.fountain(root, Vector3.ZERO, Color.YELLOW, 8)
	var ps := _particles_in(root)
	assert_eq(ps.size(), 1, "fountain ska spawna en CPUParticles3D")
	var p: CPUParticles3D = ps[0]
	assert_gt(p.direction.y, 0.0, "fontänen ska peka uppåt")
	assert_gt(p.gravity.y, 0.0, "fontängnistorna ska driva uppåt (som 2D)")

func test_death_burst_spawnar_partiklar_for_varje_stil() -> void:
	for kind in ["bone", "ooze", "ember", "ice", "dust"]:
		var root := Node3D.new()
		add_child_autofree(root)
		FX3D.death_burst(root, Vector3.ZERO, Color.RED, kind)
		assert_gt(_particles_in(root).size(), 0,
			"stilen '%s' ska spawna minst en partikelnod" % kind)

func test_ember_har_glod_och_rok() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.death_burst(root, Vector3.ZERO, Color.RED, "ember")
	assert_eq(_particles_in(root).size(), 2, "glöd-stilen ska ha glöd + rök")

func test_ring_vaxer_och_tonar() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.ring(root, Vector3.ZERO, Color.CYAN, 1.0)
	var fx: Node3D = null
	for c in root.get_children():
		if c is FX3D:
			fx = c
	assert_not_null(fx, "ring ska spawna en SpellFx3D-nod")
	fx._process(0.1)
	var r1: float = fx._gfx.scale.x
	fx._process(0.1)
	assert_gt(fx._gfx.scale.x, r1, "ringen ska växa över tid")
	assert_lt(fx._mat.albedo_color.a, 1.0, "ringen ska tona ut medan den växer")
	fx._process(0.3)   # totalt > 0.35 s → klar
	assert_true(fx.is_queued_for_deletion(), "ringen ska städa sig själv")

func test_projektil_ror_sig_mot_malet() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.projectile(root, Vector3.ZERO, Vector3(10, 0, 0), Color.WHITE)
	var proj: Node3D = null
	for c in root.get_children():
		if c is FX3D:
			proj = c
	assert_not_null(proj, "en projektil-nod ska spawnas")
	assert_gt(proj.position.y, 0.0, "projektilen ska flyga i brösthöjd")
	var x0 := proj.position.x
	proj._process(0.05)
	assert_gt(proj.position.x, x0, "projektilen ska röra sig mot målet")

func test_projektil_anlander_och_kor_callback() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var arrived := [false]
	FX3D.projectile(root, Vector3.ZERO, Vector3(2, 0, 0), Color.WHITE,
		func(): arrived[0] = true)
	var proj: Node3D = null
	for c in root.get_children():
		if c is FX3D:
			proj = c
	proj._process(10.0)   # långt förbi flygtiden
	assert_true(arrived[0], "on_arrive ska köras vid framkomst")
	assert_true(proj.is_queued_for_deletion(), "projektilen ska städa sig själv")

func test_flash_spawnar_ljus() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	FX3D.flash(root, Vector3.ZERO, Color.ORANGE, 1.8, 4.0)
	var light: OmniLight3D = null
	for c in root.get_children():
		if c is OmniLight3D:
			light = c
	assert_not_null(light, "flash ska spawna en OmniLight3D")
	assert_eq(light.omni_range, 4.0, "räckvidden ska skickas vidare")
	assert_gt(light.position.y, 0.0, "blixten ska lyfta över marken")
