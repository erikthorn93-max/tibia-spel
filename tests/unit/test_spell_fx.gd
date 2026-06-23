extends GutTest
## Tester för SpellFx — besvärjelse-effekternas färgmappning & projektil-rörelse.

const SFX = preload("res://entities/spell_fx.gd")

func test_element_color_distinkt_per_element() -> void:
	var elems := ["fire", "ice", "energy", "death", "holy", "physical"]
	var seen: Array = []
	for e in elems:
		var c: Color = SFX.element_color(e)
		assert_false(seen.has(c), "varje element ska ha en egen färg (%s)" % e)
		seen.append(c)

func test_element_color_fallback_for_okant() -> void:
	var c: Color = SFX.element_color("none")
	assert_true(c is Color, "okänt element ska ge en giltig fallback-färg")

func test_fire_ar_varm_ice_ar_kall() -> void:
	var fire: Color = SFX.element_color("fire")
	var ice: Color = SFX.element_color("ice")
	assert_gt(fire.r, fire.b, "eld ska luta mot rött")
	assert_gt(ice.b, ice.r, "is ska luta mot blått")

func test_projektil_ror_sig_mot_malet() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	SFX.projectile(root, Vector2(0, 0), Vector2(100, 0), Color.WHITE)
	# Hitta den spawnade projektilen
	var proj: Node2D = null
	for c in root.get_children():
		if c is SFX:
			proj = c
	assert_not_null(proj, "en projektil-nod ska spawnas")
	var x0 := proj.global_position.x
	proj._process(0.05)
	assert_gt(proj.global_position.x, x0, "projektilen ska röra sig mot målet")
