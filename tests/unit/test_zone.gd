extends GutTest

const ZoneScript = preload("res://world/zone.gd")

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
