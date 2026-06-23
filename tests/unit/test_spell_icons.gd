extends GutTest
## Regressionsvakt: varje besvärjelse får en giltig 16×16-ikon utan att rit-koden
## kraschar, alla element-glyfer går att rita, och cachen återanvänder texturen.

func test_alla_spells_far_giltig_ikon() -> void:
	var trasiga: Array = []
	for id in SpellSystem.spells:
		var tex := SpellIcons.texture(id, SpellSystem.spells[id])
		if tex == null or tex.get_width() != SpellIcons.SIZE or tex.get_height() != SpellIcons.SIZE:
			trasiga.append(id)
	assert_eq(trasiga, [], "alla spells ska ge en %d×%d-ikon" % [SpellIcons.SIZE, SpellIcons.SIZE])

func test_varje_element_ger_synliga_pixlar() -> void:
	for el in ["fire", "ice", "energy", "death", "holy", "physical", "none"]:
		var tex := SpellIcons.texture("__el_%s__" % el, {"type": "attack", "element": el})
		var img := tex.get_image()
		var fyllda := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					fyllda += 1
		assert_gt(fyllda, 8, "element %s ska rita synliga pixlar" % el)

func test_conjure_far_run_ram() -> void:
	# Run-ramen ritar hörn-pixlar — en conjure-ikon ska ha fler kantpixlar
	# i hörnen än en vanlig attack-ikon med samma element.
	var conj := SpellIcons.texture("__c__", {"type": "conjure", "element": "energy"}).get_image()
	assert_gt(conj.get_pixel(0, 0).a, 0.0, "conjure ska måla övre-vänstra hörnet (run-ram)")

func test_cache_aterananvander_textur() -> void:
	var def := {"type": "heal", "element": "holy"}
	var a := SpellIcons.texture("light_heal_cache", def)
	var b := SpellIcons.texture("light_heal_cache", def)
	assert_eq(a, b, "samma id ska ge samma cachade textur-instans")
