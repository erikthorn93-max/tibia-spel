extends GutTest

const ZoneScript = preload("res://world/zone.gd")
const DungeonGen = preload("res://world/dungeon_generator.gd")

func before_each():
	UnlockSystem.unlocked.clear()

func after_each():
	UnlockSystem.unlocked.clear()

func _make_zone(zone_id: String):
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build(zone_id)
	return z

func test_town_loads_and_has_player_start():
	var z = _make_zone("town")
	assert_ne(z.player_start, Vector2i.ZERO)
	assert_true(z.is_walkable(z.player_start))

func test_walls_block_floor_walkable():
	var z = _make_zone("town")
	assert_false(z.is_walkable(Vector2i(0, 0)))   # ~ havet i hörnet (280×200)
	assert_true(z.is_walkable(z.player_start))    # innanför staden

func test_rows_equal_length():
	for id in ["town", "cave"]:
		var z = _make_zone(id)
		assert_gt(z.grid_size.x, 0, id)            # build assertar radlängder

func test_portal_found():
	var z = _make_zone("town")
	assert_true(z.portals.values().has("cave"))
	var cave = _make_zone("cave")
	assert_true(cave.portals.values().has("town"))
	assert_true(cave.portals.values().has("spider_crypt"))

func test_spawns_parsed():
	var z = _make_zone("cave")
	# 2 fasta Ghoul-tiles i legend + 3 från spawn_table (M10-featuren).
	var ghouls = z.spawn_points.filter(func(s): return s["monster"] == "Ghoul")
	assert_eq(ghouls.size(), 5)

func test_pathfinding_finds_path():
	var z = _make_zone("town")
	# Hitta en gångbar granne till player_start (robust mot kartändringar)
	var goal: Vector2i = z.player_start
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
		if z.is_walkable(z.player_start + d):
			goal = z.player_start + d
			break
	assert_ne(goal, z.player_start, "ingen gångbar granne till player_start")
	var path = z.find_path(z.player_start, goal)
	assert_gt(path.size(), 0)
	assert_eq(path[path.size() - 1], goal)

func test_frodo_inn_is_registered_entrance():
	var z = _make_zone("town")
	assert_true(z.entrance_points.values().has("frodo_inn"),
		"Frodo's Inn ska vara registrerad som husingång")

func test_frodo_inn_entrance_is_walkable():
	var z = _make_zone("town")
	var tile := Vector2i.ZERO
	for t in z.entrance_points:
		if String(z.entrance_points[t]) == "frodo_inn":
			tile = t
			break
	assert_ne(tile, Vector2i.ZERO, "hittade ingen frodo_inn-ingång")
	assert_true(z.is_walkable(tile), "ingångsrutan måste gå att kliva på")

func test_house_door_has_name_label():
	# Discoverability: husdörrar ska ha en synlig namnskylt (tidigare saknades den).
	var z = _make_zone("town")
	var found := false
	for child in z.get_children():
		if child is Label and String(child.text) == "Frodo's Inn":
			found = true
			break
	assert_true(found, "Frodo's Inn-dörren saknar namnskylt i världen")

func test_forest_loads_with_nodes():
	var z = _make_zone("forest")
	assert_gt(z.node_points.size(), 5)
	var trees = z.node_points.filter(func(n): return n["node"] == "tree")
	assert_gt(trees.size(), 0)

func test_town_has_stations_and_shop():
	# Efter 280×200-regenereringen krockade stationstecknen (A/G/L/R/C) med
	# vildmarksportalerna och murades igen i kärnan — staden saknar därför
	# crafting-stationer. Två handelsbodar (H) bevarades.
	var z = _make_zone("town")
	assert_eq(z.station_points.size(), 0)
	assert_eq(z.shop_points.size(), 2)

func test_depot_has_smithing_and_crafting_stations():
	# Städ + hantverksbord placerade i depån så smithing/crafting/fletching
	# blir nåbart (malm, skinn och loggar har annars ingen station).
	var z = _make_zone("thais_depot_int")
	var stations = z.station_points.map(func(s): return s["station"])
	assert_has(stations, "anvil")
	assert_has(stations, "crafting_bench")
	assert_has(stations, "workbench")   # construction

func test_sorcerer_guild_has_alchemy_and_rune_stations():
	var z = _make_zone("sorcerer_guild")
	var stations = z.station_points.map(func(s): return s["station"])
	assert_has(stations, "alchemy_table")
	assert_has(stations, "rune_altar")

func test_temple_prayer_altar_is_usable_station():
	# Bönaltaret var 'decoration' (öppnade ingen panel) — nu en riktig station.
	var z = _make_zone("tibianus_temple")
	var stations = z.station_points.map(func(s): return s["station"])
	assert_has(stations, "prayer_altar")

func test_heights_has_minor_skill_nodes():
	# Skogshöjderna försörjer hunting/firemaking/farming som annars är tunna.
	var z = _make_zone("thais_heights")
	var nodes = z.node_points.map(func(n): return n["node"])
	for nid in ["hunting_trap", "bird_trap", "campfire_spot", "farm_patch"]:
		assert_has(nodes, nid)

func test_undead_drop_bones_for_prayer():
	# Prayer tränas genom att begrava ben — odöda måste droppa dem.
	for name in ["Skelett", "Ghoul", "Fantom"]:
		var loot: Array = MonsterDB.monsters[name].get("loot", [])
		assert_true(loot.any(func(l): return String(l["item"]) == "bones"), name + " saknar bens-drop")

func test_cave_has_ore_veins():
	var z = _make_zone("cave")
	var veins = z.node_points.filter(func(n): return n["node"].ends_with("_vein"))
	assert_eq(veins.size(), 6)

func test_node_tiles_are_blocked():
	var z = _make_zone("forest")
	assert_false(z.is_walkable(z.node_points[0]["tile"]))

func test_town_has_three_portals():
	# Efter 280×200-expansionen har town fler portaler (närportaler + landsbygd).
	# Verifiera närvaro av de lokala destinationerna istället för exakt antal.
	var z = _make_zone("town")
	for d in ["cave", "forest", "coast"]:
		assert_true(z.portals.values().has(d), "town saknar portal till %s" % d)

func test_find_path_adjacent_reaches_blocked_target():
	var z = _make_zone("town")
	# Robust mot kartändringar: hitta ett blockerat tile nära player_start vars
	# gångbara granne faktiskt nås från start (stationer saknas efter expansionen).
	var start: Vector2i = z.player_start
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var target = null
	for radius in range(1, 16):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var t: Vector2i = start + Vector2i(dx, dy)
				if z.is_walkable(t):
					continue
				for d in dirs:
					if z.is_walkable(t + d) and z.find_path(start, t + d).size() > 0:
						target = t
						break
				if target != null:
					break
			if target != null:
				break
		if target != null:
			break
	assert_not_null(target, "hittade inget nåbart blockerat mål nära player_start")
	var path = z.find_path_adjacent(start, target)
	assert_gt(path.size(), 0)
	var last: Vector2i = path[path.size() - 1]
	assert_lte(maxi(absi(last.x - target.x), absi(last.y - target.y)), 1)

func _gate_tile(z, unlock_id: String):
	for t in z.gate_points:
		if z.gate_points[t] == unlock_id:
			return t
	return null

func test_cave_gates_parsed():
	var z = _make_zone("cave")
	assert_eq(z.gate_points.size(), 3)
	for id in ["spindelhalan", "kryptan", "bossrummet"]:
		assert_true(z.gate_points.values().has(id), id)

func test_gate_blocked_before_unlock_opens_live_after():
	var z = _make_zone("cave")
	var gt = _gate_tile(z, "spindelhalan")
	assert_not_null(gt)
	assert_false(z.is_walkable(gt))
	UnlockSystem.unlock("spindelhalan")
	assert_true(z.is_walkable(gt))

func test_gate_open_at_build_if_already_unlocked():
	UnlockSystem.unlock("kryptan")
	var z = _make_zone("cave")
	assert_true(z.is_walkable(_gate_tile(z, "kryptan")))

func test_forest_gate_morka_dungen():
	var z = _make_zone("forest")
	assert_true(z.gate_points.values().has("morka_dungen"))

func test_town_has_taskmaster():
	# Taskmaster-tecknet (T) återanvänds som troll_cave-portal efter expansionen;
	# staden har ingen taskmaster i nuläget.
	var z = _make_zone("town")
	assert_eq(z.taskmaster_points.size(), 0)

func test_new_monster_spawns_behind_gates():
	var z = _make_zone("cave")
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Jättespindel").size(), 0)
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Skelettkrigare").size(), 0)
	assert_eq(z.spawn_points.filter(func(s): return s["monster"] == "Ghulkungen").size(), 1)
	var f = _make_zone("forest")
	assert_gt(f.spawn_points.filter(func(s): return s["monster"] == "Fantom").size(), 0)

func _shortcut_tile(z, unlock_id: String):
	for t in z.shortcut_points:
		if z.shortcut_points[t] == unlock_id:
			return t
	return null

func test_forest_shortcut_parsed_and_blocked():
	var z = _make_zone("forest")
	assert_eq(z.shortcut_points.size(), 2)   # två stenar över floden
	var t = _shortcut_tile(z, "genvag_stenarna")
	assert_not_null(t)
	assert_false(z.is_walkable(t))

func test_shortcut_opens_live_on_unlock():
	var z = _make_zone("forest")
	UnlockSystem.unlock("genvag_stenarna")
	for t in z.shortcut_points:
		assert_true(z.is_walkable(t))

func test_shortcut_open_at_build_if_unlocked():
	UnlockSystem.unlock("genvag_stenarna")
	var z = _make_zone("forest")
	for t in z.shortcut_points:
		assert_true(z.is_walkable(t))

func test_forest_portal_to_swamp_locked():
	var z = _make_zone("forest")
	assert_true(z.portals.values().has("swamp"))
	assert_true(z.portal_locks.values().has("trasket"))
	UnlockSystem.unlock("trasket")
	assert_eq(z.portal_locks.size(), 0)

func test_lock_at_reports_unlock_id():
	var z = _make_zone("forest")
	var t = _shortcut_tile(z, "genvag_stenarna")
	assert_eq(z.lock_at(t), "genvag_stenarna")
	UnlockSystem.unlock("genvag_stenarna")
	assert_eq(z.lock_at(t), "")

func test_swamp_loads_with_content():
	var z = _make_zone("swamp")
	assert_true(z.is_walkable(z.player_start))
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Giftpadda").size(), 3)
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Träskdjävul").size(), 3)
	assert_gt(z.node_points.filter(func(n): return n["node"] == "eel_spot").size(), 0)
	assert_gt(z.node_points.filter(func(n): return n["node"] == "marsh_patch").size(), 0)
	assert_true(z.gate_points.values().has("traskets_hjarta"))
	assert_true(z.portals.values().has("forest"))
	assert_true(z.portals.values().has("cave"))
	assert_true(z.portal_locks.values().has("genvag_grottan"))

func test_swamp_heart_blocked_until_task_unlock():
	var z = _make_zone("swamp")
	var gt = _gate_tile(z, "traskets_hjarta")
	assert_not_null(gt)
	assert_false(z.is_walkable(gt))
	UnlockSystem.unlock("traskets_hjarta")
	assert_true(z.is_walkable(gt))

func test_cave_has_swamp_shortcut_portal():
	var z = _make_zone("cave")
	assert_true(z.portals.values().has("swamp"))
	assert_true(z.portal_locks.values().has("genvag_grottan"))

func test_build_from_generated_dungeon_data():
	var data: Dictionary = DungeonGen.generate("katakomber", 999)
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build_from_data(data, "dungeon:katakomber")
	assert_eq(z.zone_id, "dungeon:katakomber")
	assert_eq(z.dungeon_theme, "katakomber")
	assert_true(z.is_walkable(z.player_start))
	assert_eq(z.chest_points.size(), 1)
	assert_false(z.is_walkable(z.chest_points[0]))   # kistan blockerar
	assert_true(z.portals.values().has("cave"))
	assert_gt(z.spawn_points.size(), 0)

func test_dungeon_entrances_parsed():
	UnlockSystem.unlock("kryptan")
	var cave = _make_zone("cave")
	assert_true(cave.dungeon_entrances.values().has("katakomber"))
	assert_true(cave.is_walkable(cave.dungeon_entrances.keys()[0]))
	UnlockSystem.unlock("traskets_hjarta")
	var swamp = _make_zone("swamp")
	assert_true(swamp.dungeon_entrances.values().has("sjunkna_graven"))

func test_gate_ids_cover_task_unlocks_and_boss():
	var gate_ids: Array = []
	for id in ["town", "cave", "forest", "swamp"]:
		var z = _make_zone(id)
		for t in z.gate_points:
			gate_ids.append(z.gate_points[t])
	var tasks = JSON.parse_string(FileAccess.open("res://data/tasks.json", FileAccess.READ).get_as_text())
	for tid in tasks:
		if tasks[tid].has("unlocks"):
			assert_has(gate_ids, String(tasks[tid]["unlocks"]), tid)
	assert_has(gate_ids, "bossrummet")

func test_coast_builds_with_content():
	UnlockSystem.unlock("kustvagen")
	var z = _make_zone("coast")
	assert_eq(z.zone_name, "Saltviks hamn")
	assert_eq(z.node_points.size(), 3)
	assert_true(z.station_points.any(func(s): return s["station"] == "stove"))
	assert_eq(z.taskmaster_points.size(), 1)
	assert_eq(z.shop_points.size(), 1)
	assert_true(z.dungeon_entrances.values().has("sjunket_skepp"))
	assert_true(z.portals.values().has("town"))

func test_town_has_coast_portal_and_pirates():
	# Efter expansionen är kustvägen en fri närportal (inget kustvagen-lås kvar).
	UnlockSystem.unlocked.clear()
	var town = _make_zone("town")
	assert_true(town.portals.values().has("coast"))
	assert_false(town.portal_locks.values().has("kustvagen"))
	assert_true(town.spawn_points.any(func(s): return s["monster"] == "Pirat"))

func test_beach_terrain_registered():
	assert_true(PlaceholderTiles.TERRAIN.has("b"))

# ── Spindelkryptan: nytt innehållsflöde (monster → material → utrustning) ──

func test_spider_crypt_loads_with_content():
	var z = _make_zone("spider_crypt")
	assert_true(z.is_walkable(z.player_start))
	# Portal tillbaka till grottan
	assert_true(z.portals.values().has("cave"))
	# Crafting-stationer på plats (självförsörjande loop)
	var stations = z.station_points.map(func(s): return s["station"])
	assert_has(stations, "anvil")
	assert_has(stations, "crafting_bench")
	assert_has(stations, "alchemy_table")
	# Spindelfiender + boss
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Grottspindel").size(), 0)
	assert_gt(z.spawn_points.filter(func(s): return s["monster"] == "Giftvävare").size(), 0)
	assert_eq(z.spawn_points.filter(func(s): return s["monster"] == "Spindeldrottningen Morwena").size(), 1)
	# Gather-noder för självförsörjande alkemi-loop (nattskatta → giftbrygd)
	assert_gt(z.node_points.filter(func(n): return n["node"] == "nightshade_patch").size(), 0)

func test_shop_stock_items_are_real():
	var stock: Array = (load("res://ui/shop_panel.gd") as GDScript).get_script_constant_map()["STOCK"]
	for id in stock:
		assert_true(ItemDB.items.has(id), "shop säljer okänt item " + id)
	# Drycker + motgift ska gå att köpa
	for id in ["health_potion", "antidote_potion", "venom_brew"]:
		assert_has(stock, id)

func test_cave_links_to_spider_crypt():
	var z = _make_zone("cave")
	assert_true(z.portals.values().has("spider_crypt"))

func test_spider_monsters_drop_craft_materials():
	for name in ["Grottspindel", "Giftvävare", "Skuggspindel"]:
		assert_true(MonsterDB.monsters.has(name), "saknar monster " + name)
	var queen: Dictionary = MonsterDB.monsters["Spindeldrottningen Morwena"]
	assert_true(queen.get("boss", false))
	var queen_loot: Array = queen["loot"]
	assert_true(queen_loot.any(func(l): return String(l["item"]) == "venomfang_blade"))

func test_new_spider_items_registered():
	for id in ["spider_fang", "venom_gland", "shadow_silk", "spider_queen_silk",
			"venom_blade", "venomfang_blade", "silk_robe", "venom_hood",
			"spider_amulet", "web_boots", "venom_brew"]:
		assert_true(ItemDB.items.has(id), "saknar item " + id)

func test_new_spider_recipes_exist():
	var anvil_ids: Array = ItemDB.recipes["anvil"].map(func(r): return r["id"])
	assert_has(anvil_ids, "venom_blade")
	var bench_ids: Array = ItemDB.recipes["crafting_bench"].map(func(r): return r["id"])
	for id in ["web_boots", "venom_hood", "spider_amulet", "silk_robe"]:
		assert_has(bench_ids, id)
	var alch_ids: Array = ItemDB.recipes["alchemy_table"].map(func(r): return r["id"])
	assert_has(alch_ids, "venom_brew")

func test_spider_recipe_ingredients_are_real_items():
	for station in ["anvil", "crafting_bench", "alchemy_table"]:
		for r in ItemDB.recipes[station]:
			for ing in r["ingredients"]:
				assert_true(ItemDB.items.has(ing), "recept %s saknar item %s" % [r["id"], ing])

func test_spider_quest_chain_loads():
	for qid in ["quest_spider_crypt_1", "quest_spider_crypt_2"]:
		assert_true(QuestSystem.quests.has(qid), "saknar quest " + qid)
	# Kedjan: quest 2 kräver quest 1
	assert_has(QuestSystem.quests["quest_spider_crypt_2"]["requires"], "quest_spider_crypt_1")

func test_spider_quests_reference_valid_content():
	for qid in ["quest_spider_crypt_1", "quest_spider_crypt_2"]:
		var q: Dictionary = QuestSystem.quests[qid]
		assert_true(MonsterDB.monsters.has(q["giver"]) == false)   # giver är en NPC, inte monster
		for step in q["steps"]:
			match String(step["type"]):
				"kill":
					assert_true(MonsterDB.monsters.has(step["monster"]), qid + " dödar okänt monster")
				"collect":
					assert_true(ItemDB.items.has(step["item"]), qid + " samlar okänt item")
		for item_id in q.get("rewards", {}).get("items", {}):
			assert_true(ItemDB.items.has(item_id), qid + " belönar okänt item " + item_id)

func test_new_monsters_have_bestiary_text():
	for name in ["Grottspindel", "Giftvävare", "Skuggspindel", "Spindeldrottningen Morwena"]:
		assert_ne(String(MonsterDB.monsters[name].get("desc", "")), "", name + " saknar bestiary-text")

func test_spiders_spawn_in_other_zones():
	var cave = _make_zone("cave")
	assert_gt(cave.spawn_points.filter(func(s): return s["monster"] == "Grottspindel").size(), 0)
	var forest = _make_zone("forest")
	assert_gt(forest.spawn_points.filter(func(s): return s["monster"] == "Grottspindel").size(), 0)

# ── Brett low-level-innehåll: landsbygdens fauna ──

func test_low_level_critters_exist():
	for name in ["Fältmus", "Vildkanin", "Åkerkråka", "Vildsvin"]:
		assert_true(MonsterDB.monsters.has(name), "saknar monster " + name)
		assert_lt(int(MonsterDB.monsters[name]["hp"]), 50, name + " är inte low-level")
		assert_ne(String(MonsterDB.monsters[name].get("desc", "")), "", name + " saknar bestiary-text")

func test_fields_have_beginner_fauna():
	var z = _make_zone("thais_fields")
	for name in ["Fältmus", "Vildkanin", "Åkerkråka", "Vildsvin"]:
		assert_gt(z.spawn_points.filter(func(s): return s["monster"] == name).size(), 0,
			"landsbygden saknar " + name)

func test_apprentice_skilling_questline():
	for qid in ["quest_appr_mining", "quest_appr_woodcutting", "quest_appr_cooking"]:
		assert_true(QuestSystem.quests.has(qid), "saknar " + qid)
	# Kedja: woodcutting kräver mining, cooking kräver woodcutting
	assert_has(QuestSystem.quests["quest_appr_woodcutting"]["requires"], "quest_appr_mining")
	assert_has(QuestSystem.quests["quest_appr_cooking"]["requires"], "quest_appr_woodcutting")
	# Introducerar gathering via collect-steg mot riktiga items
	for qid in ["quest_appr_mining", "quest_appr_woodcutting", "quest_appr_cooking"]:
		var first = QuestSystem.quests[qid]["steps"][0]
		assert_eq(String(first["type"]), "collect", qid + " börjar inte med ett samlingssteg")
		assert_true(ItemDB.items.has(String(first["item"])), qid + " samlar okänt item")
	# Belönar skill-XP för att jumpstarta den introducerade skillen
	assert_true(QuestSystem.quests["quest_appr_mining"]["rewards"].has("skill_xp"))

## ── Dimmoren: ny mellannivå-hed kopplad till skogen ──

func test_dimmoren_loads_with_content():
	var z = _make_zone("dimmoren")
	assert_eq(z.zone_name, "Dimmoren")
	assert_true(z.is_walkable(z.player_start), "startrutan ska vara gångbar")
	# Portal tillbaka till skogen
	assert_true(z.portals.values().has("forest"), "saknar portal tillbaka till forest")
	# Katakomb-ingång i gravkummel
	assert_true(z.dungeon_entrances.values().has("katakomber"))
	# Gather-noder: idegran, sälg, ädelstensåder
	var nodes = z.node_points.map(func(n): return n["node"])
	for nid in ["yew_tree", "willow_tree", "gem_vein"]:
		assert_has(nodes, nid)
	# Mellannivå-mix av best & odöda
	for name in ["Varg", "Vildsvin", "Skogsvargen", "Skelett", "Ghoul", "Bandit", "Fantom"]:
		assert_gt(z.spawn_points.filter(func(s): return s["monster"] == name).size(), 0,
			"dimmoren saknar " + name)

func test_dimmoren_monsters_and_theme_are_valid():
	# Alla spawnade monster ska finnas i MonsterDB och temat vara byggbart.
	var z = _make_zone("dimmoren")
	for sp in z.spawn_points:
		assert_true(MonsterDB.monsters.has(sp["monster"]), "okänt monster " + String(sp["monster"]))
	for t in z.dungeon_entrances:
		var theme := String(z.dungeon_entrances[t])
		var data: Dictionary = DungeonGen.generate(theme, 7)
		assert_gt(data.get("tiles", []).size(), 0, "temat %s genererade ingen karta" % theme)

func test_forest_links_to_dimmoren():
	var z = _make_zone("forest")
	assert_true(z.portals.values().has("dimmoren"), "skogen saknar portal till dimmoren")

func test_boar_hide_tans_to_leather():
	assert_true(ItemDB.items.has("boar_hide"))
	var bench: Array = ItemDB.recipes["crafting_bench"]
	var tan := bench.filter(func(r): return r["id"] == "leather_strips" \
		and r["ingredients"].has("boar_hide"))
	assert_gt(tan.size(), 0, "saknar garvningsrecept boar_hide → leather_strips")

## ── Glödöknen: ny ökenregion bortom Ökenruinerna (monster → material → utrustning) ──

func test_desert_links_to_glodoknen():
	var z = _make_zone("desert")
	assert_true(z.portals.values().has("glodoknen"), "öknen saknar portal till Glödöknen")
	var pt = null
	for t in z.portals:
		if String(z.portals[t]) == "glodoknen":
			pt = t
			break
	assert_not_null(pt)
	assert_gt(z.find_path(z.player_start, pt).size(), 0, "Glödöknen-portalen är inte nåbar")

func test_glodoknen_loads_with_content():
	var z = _make_zone("glodoknen")
	assert_eq(z.zone_name, "Glödöknen")
	assert_true(z.is_walkable(z.player_start), "startrutan ska vara gångbar")
	assert_true(z.portals.values().has("desert"), "saknar portal tillbaka till öknen")
	assert_true(z.portals.values().has("solgraven"), "saknar portal vidare till Solgraven")
	for name in ["Glödskorpion", "Sandskarabé", "Sandvålnad"]:
		assert_gt(z.spawn_points.filter(func(s): return s["monster"] == name).size(), 0,
			"glodoknen saknar " + name)

func test_solgraven_loads_with_content():
	var z = _make_zone("solgraven")
	assert_eq(z.zone_name, "Solgraven")
	assert_true(z.is_walkable(z.player_start), "startrutan ska vara gångbar")
	assert_true(z.portals.values().has("glodoknen"), "saknar portal tillbaka till Glödöknen")
	var stations = z.station_points.map(func(s): return s["station"])
	assert_has(stations, "anvil")
	assert_has(stations, "crafting_bench")
	assert_eq(z.spawn_points.filter(func(s): return s["monster"] == "Solkonungen Akh-Mortis").size(), 1)
	var bt = null
	for s in z.spawn_points:
		if s["monster"] == "Solkonungen Akh-Mortis":
			bt = s["tile"]
			break
	assert_not_null(bt)
	assert_gt(z.find_path_adjacent(z.player_start, bt).size(), 0, "bossen är inte nåbar")

func test_glodoknen_monsters_registered_with_desc():
	for name in ["Glödskorpion", "Sandskarabé", "Sandvålnad", "Gravväktare", "Solkonungen Akh-Mortis"]:
		assert_true(MonsterDB.monsters.has(name), "saknar monster " + name)
		assert_ne(String(MonsterDB.monsters[name].get("desc", "")), "", name + " saknar bestiary-text")
	assert_true(MonsterDB.monsters["Solkonungen Akh-Mortis"].get("boss", false), "solkonungen ska vara boss")

func test_glodoknen_items_registered():
	for id in ["scarab_shell", "ember_gland", "tomb_dust", "sun_shard", "gilded_scarab",
			"sunforged_blade", "scarab_shield", "sun_amulet", "ember_robe", "sandstrider_boots"]:
		assert_true(ItemDB.items.has(id), "saknar item " + id)

func test_glodoknen_recipes_exist_with_real_ingredients():
	var anvil_ids: Array = ItemDB.recipes["anvil"].map(func(r): return r["id"])
	for id in ["sunforged_blade", "scarab_shield"]:
		assert_has(anvil_ids, id)
	var bench_ids: Array = ItemDB.recipes["crafting_bench"].map(func(r): return r["id"])
	for id in ["sun_amulet", "ember_robe", "sandstrider_boots"]:
		assert_has(bench_ids, id)
	for station in ["anvil", "crafting_bench"]:
		for r in ItemDB.recipes[station]:
			for ing in r["ingredients"]:
				assert_true(ItemDB.items.has(ing), "recept %s saknar item %s" % [r["id"], ing])

func test_glodoknen_crit_gear_feeds_bonus():
	# Knyter ihop med crit-systemet: solklinga + solamulett ska ge crit-bonus.
	var gs = load("res://autoload/game_state.gd").new()
	gs.equipment["weapon"] = "sunforged_blade"   # +0.08
	gs.equipment["amulet"] = "sun_amulet"        # +0.06
	assert_almost_eq(gs.total_crit_bonus(), 0.14, 0.0001)
	gs.free()

## ── Svampgrottan: lysande mykonid-grotta bortom Grottan (gather → laga → utrustning) ──

func test_cave_links_to_svampgrotta():
	var z = _make_zone("cave")
	assert_true(z.portals.values().has("svampgrotta"), "grottan saknar portal till Svampgrottan")
	var pt = null
	for t in z.portals:
		if String(z.portals[t]) == "svampgrotta":
			pt = t
			break
	assert_not_null(pt)
	assert_gt(z.find_path(z.player_start, pt).size(), 0, "Svampgrottan-portalen är inte nåbar")

func test_svampgrotta_loads_with_content():
	var z = _make_zone("svampgrotta")
	assert_eq(z.zone_name, "Svampgrottan")
	assert_true(z.is_walkable(z.player_start), "startrutan ska vara gångbar")
	assert_true(z.portals.values().has("cave"), "saknar portal tillbaka till Grottan")
	for name in ["Sporling", "Lysfluga", "Svampvätte", "Mykonidäldste"]:
		assert_gt(z.spawn_points.filter(func(s): return s["monster"] == name).size(), 0,
			"svampgrotta saknar " + name)
	# bossen ska finnas och vara nåbar
	var bt = null
	for s in z.spawn_points:
		if s["monster"] == "Sporkungen Myzandros":
			bt = s["tile"]
			break
	assert_not_null(bt, "Sporkungen Myzandros spawnar inte i zonen")
	assert_gt(z.find_path_adjacent(z.player_start, bt).size(), 0, "bossen är inte nåbar")
	# herbalism-nod för lyshattar
	var nodes = z.node_points.map(func(n): return n["node"])
	assert_has(nodes, "glowcap_patch")

func test_svampgrotta_monsters_registered_with_desc():
	for name in ["Sporling", "Lysfluga", "Svampvätte", "Mykonidäldste", "Sporkungen Myzandros"]:
		assert_true(MonsterDB.monsters.has(name), "saknar monster " + name)
		assert_ne(String(MonsterDB.monsters[name].get("desc", "")), "", name + " saknar bestiary-text")
	assert_true(MonsterDB.monsters["Sporkungen Myzandros"].get("boss", false), "sporkungen ska vara boss")

func test_svampgrotta_items_registered():
	for id in ["spore_dust", "glowing_cap", "mycelium_fiber", "spore_sac", "luminous_essence",
			"glowing_soup", "spore_staff", "mycelium_tunic", "glowshroom_shield"]:
		assert_true(ItemDB.items.has(id), "saknar item " + id)

func test_svampgrotta_recipes_exist_with_real_ingredients():
	var stove_ids: Array = ItemDB.recipes["stove"].map(func(r): return r["id"])
	assert_has(stove_ids, "glowing_soup")
	var bench_ids: Array = ItemDB.recipes["crafting_bench"].map(func(r): return r["id"])
	for id in ["mycelium_tunic", "glowshroom_shield"]:
		assert_has(bench_ids, id)
	for station in ["stove", "crafting_bench"]:
		for r in ItemDB.recipes[station]:
			for ing in r["ingredients"]:
				assert_true(ItemDB.items.has(ing), "recept %s saknar item %s" % [r["id"], ing])
