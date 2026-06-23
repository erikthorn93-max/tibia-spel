extends GutTest
## Regressionsvakt: varje skill får en giltig 16×16 pixel-ikon utan att rit-koden
## kraschar, och cachen återanvänder samma textur vid upprepade anrop.

func test_alla_skills_far_giltig_ikon() -> void:
	var trasiga: Array = []
	for id in GameState.skill_defs:
		var tex := SkillIcons.texture(id, Color(0.8, 0.3, 0.2))
		if tex == null or tex.get_width() != SkillIcons.SIZE or tex.get_height() != SkillIcons.SIZE:
			trasiga.append(id)
	assert_eq(trasiga, [], "alla skills ska ge en %d×%d-ikon" % [SkillIcons.SIZE, SkillIcons.SIZE])

func test_okand_skill_ger_fallback_ikon() -> void:
	var tex := SkillIcons.texture("__finns_inte__", Color.WHITE)
	assert_not_null(tex, "okänd skill ska få fallback-ikon, inte null")
	assert_eq(tex.get_width(), SkillIcons.SIZE)

func test_cache_aterananvander_textur() -> void:
	var a := SkillIcons.texture("sword", Color.RED)
	var b := SkillIcons.texture("sword", Color.RED)
	assert_eq(a, b, "samma id ska ge samma cachade textur-instans")

func test_ikon_har_synliga_pixlar() -> void:
	var tex := SkillIcons.texture("mining", Color(0.5, 0.55, 0.55))
	var img := tex.get_image()
	var fyllda := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				fyllda += 1
	assert_gt(fyllda, 10, "ikonen ska ha ritade pixlar")
