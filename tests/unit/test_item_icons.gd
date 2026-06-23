extends GutTest
## Regressionsvakt: varje item i ItemDB får en icke-null ikon — antingen disk-
## sprite eller procedurell fallback. Inget item ska kunna bli osynligt.

func test_alla_items_far_ikon() -> void:
	var trasiga: Array = []
	for iid in ItemDB.items:
		var tex := ItemIcons.texture(iid)
		if tex == null:
			trasiga.append(iid)
	assert_eq(trasiga, [], "alla items ska få en ikon (sprite eller procedurell)")

func test_spritlosa_items_far_procedurell_ikon() -> void:
	# Plocka ett item som saknar disk-sprite och säkerställ ritade pixlar.
	var sample := ""
	for iid in ItemDB.items:
		if not ResourceLoader.exists("res://assets/sprites/items/%s.png" % iid):
			sample = iid
			break
	assert_ne(sample, "", "testet förutsätter minst ett spritlöst item")
	if sample == "":
		return
	var tex := ItemIcons.texture(sample)
	assert_eq(tex.get_width(), ItemIcons.SIZE, "procedurell ikon ska vara %d px" % ItemIcons.SIZE)
	var img := tex.get_image()
	var fyllda := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				fyllda += 1
	assert_gt(fyllda, 10, "%s ska ha ritade pixlar, inte tom ruta" % sample)

func test_varje_typ_ger_synlig_glyf() -> void:
	# En syntetisk def per typ ska rita något (inte krascha, inte tom).
	for t in ["weapon", "armor", "light", "container", "potion", "food", "material", "okänd"]:
		ItemDB.items["__test_%s__" % t] = {"type": t, "slot": "helmet", "color": "#aabbcc"}
		var tex := ItemIcons.texture("__test_%s__" % t)
		ItemDB.items.erase("__test_%s__" % t)
		ItemIcons._cache.erase("__test_%s__" % t)
		assert_not_null(tex, "typ %s ska ge en ikon" % t)

func test_cache_aterananvander() -> void:
	var a := ItemIcons.texture("gold_coin")
	var b := ItemIcons.texture("gold_coin")
	assert_eq(a, b, "samma item-id ska ge samma cachade textur")
