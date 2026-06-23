extends GutTest
## Regressionsvakt för loot-bredd: varje item som droppas av något monster
## måste finnas i items.json OCH ha en sprite-fil (annars osynligt/krasch).

func test_alla_loot_items_finns_i_itemdb() -> void:
	var saknas: Array = []
	for mname in MonsterDB.monsters:
		for entry in MonsterDB.monsters[mname].get("loot", []):
			var id := String(entry.get("item", ""))
			if id != "" and not ItemDB.items.has(id):
				saknas.append("%s (loot hos %s)" % [id, mname])
	assert_eq(saknas, [], "alla loot-items ska finnas i items.json")

func test_alla_loot_items_har_sprite() -> void:
	var saknas: Array = []
	var sett := {}
	for mname in MonsterDB.monsters:
		for entry in MonsterDB.monsters[mname].get("loot", []):
			var id := String(entry.get("item", ""))
			if id == "" or sett.has(id) or not ItemDB.items.has(id):
				continue
			sett[id] = true
			var sp := String(ItemDB.items[id].get("sprite", ""))
			if sp != "" and not ResourceLoader.exists(sp):
				saknas.append("%s (%s)" % [id, sp])
	assert_eq(saknas, [], "alla loot-items ska ha en existerande sprite")

func test_loot_breddad_minst_5_drops_i_snitt() -> void:
	var total := 0
	var n := 0
	for mname in MonsterDB.monsters:
		total += MonsterDB.monsters[mname].get("loot", []).size()
		n += 1
	var snitt := float(total) / float(maxi(n, 1))
	assert_gt(snitt, 5.0, "loot-tabellerna ska vara breddade (>5 drops/monster i snitt)")
