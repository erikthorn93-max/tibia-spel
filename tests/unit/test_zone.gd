extends GutTest

const ZoneScript = preload("res://world/zone.gd")

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
	assert_false(z.is_walkable(Vector2i(0, 0)))   # W i hörnet
	assert_true(z.is_walkable(Vector2i(1, 1)))    # . innanför muren

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
	var ghouls = z.spawn_points.filter(func(s): return s["monster"] == "Ghoul")
	assert_eq(ghouls.size(), 2)

func test_pathfinding_finds_path():
	var z = _make_zone("town")
	var path = z.find_path(Vector2i(4, 7), Vector2i(10, 10))
	assert_gt(path.size(), 0)
	assert_eq(path[path.size() - 1], Vector2i(10, 10))

func test_forest_loads_with_nodes():
	var z = _make_zone("forest")
	assert_gt(z.node_points.size(), 5)
	var trees = z.node_points.filter(func(n): return n["node"] == "tree")
	assert_gt(trees.size(), 0)

func test_town_has_stations_and_shop():
	var z = _make_zone("town")
	assert_eq(z.station_points.size(), 4)
	assert_eq(z.shop_points.size(), 1)

func test_cave_has_ore_veins():
	var z = _make_zone("cave")
	var veins = z.node_points.filter(func(n): return n["node"].ends_with("_vein"))
	assert_eq(veins.size(), 6)

func test_node_tiles_are_blocked():
	var z = _make_zone("forest")
	assert_false(z.is_walkable(z.node_points[0]["tile"]))

func test_town_has_two_portals():
	var z = _make_zone("town")
	assert_eq(z.portals.size(), 2)
	assert_true(z.portals.values().has("forest"))

func test_find_path_adjacent_reaches_blocked_target():
	var z = _make_zone("town")
	var station_tile: Vector2i = z.station_points[0]["tile"]
	var path = z.find_path_adjacent(Vector2i(4, 7), station_tile)
	assert_gt(path.size(), 0)
	var last: Vector2i = path[path.size() - 1]
	assert_lte(maxi(absi(last.x - station_tile.x), absi(last.y - station_tile.y)), 1)

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
	var z = _make_zone("town")
	assert_eq(z.taskmaster_points.size(), 1)

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

func test_gate_ids_cover_task_unlocks_and_boss():
	var gate_ids: Array = []
	for id in ["town", "cave", "forest"]:
		var z = _make_zone(id)
		for t in z.gate_points:
			gate_ids.append(z.gate_points[t])
	var tasks = JSON.parse_string(FileAccess.open("res://data/tasks.json", FileAccess.READ).get_as_text())
	for tid in tasks:
		if tasks[tid].has("unlocks"):
			assert_has(gate_ids, String(tasks[tid]["unlocks"]), tid)
	assert_has(gate_ids, "bossrummet")
