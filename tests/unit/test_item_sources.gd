extends GutTest
## Regressionsvakt: varje item i items.json måste vara åtkomligt via minst en
## källa — loot, nod, recept, butik, dungeon-kista, quest-belöning eller dialog.
## Förhindrar "föräldralösa" items, samma sorts lucka som onåbara bossar en gång var.

const ShopPanel = preload("res://ui/shop_panel.gd")

func _json(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null

func _obtainable() -> Dictionary:
	var src := {}
	# Monster-loot
	for m in MonsterDB.monsters:
		for l in MonsterDB.monsters[m].get("loot", []):
			src[String(l.get("item", ""))] = true
	# Skördenoder
	var nodes = _json("res://data/nodes.json")
	for n in nodes:
		var y := String(nodes[n].get("yields", ""))
		if y != "":
			src[y] = true
	# Recept-output (alla stationer)
	var rec = _json("res://data/recipes.json")
	for station in rec:
		for r in rec[station]:
			src[String(r.get("id", ""))] = true
	# Butikssortiment
	for id in ShopPanel.STOCK:
		src[String(id)] = true
	# Dungeon-kistor: format [item, chans, antal]
	var dt = _json("res://data/dungeon_themes.json")
	for th in dt:
		for ci in dt[th].get("chest_items", []):
			if ci is Array and ci.size() > 0:
				src[String(ci[0])] = true
	# Quest-belöningar
	var q = _json("res://data/quests.json")
	for id in q:
		for item_id in q[id].get("rewards", {}).get("items", {}):
			src[String(item_id)] = true
	# Arena-belöning (vågbaserad gladiatorarena)
	var arena = _json("res://data/arena.json")
	if arena is Dictionary:
		for item_id in arena.get("reward", {}).get("items", {}):
			src[String(item_id)] = true
	# Dialog give_item
	var dlg = _json("res://data/dialogue.json")
	for nid in dlg:
		for c in dlg[nid].get("choices", []):
			for a in c.get("actions", []):
				if String(a.get("type", "")) == "give_item":
					src[String(a.get("item", ""))] = true
	return src

func test_inga_foraldralosa_items():
	var src := _obtainable()
	var orphans := []
	for id in ItemDB.items:
		if not src.has(id):
			orphans.append(id)
	assert_eq(orphans, [], "items utan källa (onåbara): %s" % str(orphans))

func test_guldrustning_droppar_fran_farao():
	var loot: Array = MonsterDB.monsters["Farao Khem-Ra"].get("loot", [])
	var ids := loot.map(func(l): return String(l["item"]))
	for piece in ["golden_platebody", "golden_helmet", "golden_legs"]:
		assert_true(ids.has(piece), "Farao Khem-Ra ska droppa %s" % piece)

func test_butik_sortiment_utokat():
	for id in ["great_mana_potion", "steel_amulet", "ring_of_vigor", "lantern", "explorer_backpack", "hunting_bow", "steel_bow"]:
		assert_true(ShopPanel.STOCK.has(id), "butiken ska sälja %s" % id)
		assert_true(ItemDB.items.has(id), "%s saknas i items.json" % id)

func test_butiksvaror_har_varde():
	# shop_panel prissätter via item-värde; saknat värde kraschar köpraden
	for id in ShopPanel.STOCK:
		assert_true(ItemDB.items.has(id), "butiksvara %s saknas i items.json" % id)
		assert_gt(int(ItemDB.items[id].get("value", 0)), 0, "%s saknar värde (pris)" % id)
