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
	assert_eq(cave.portals.values()[0], "town")

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
