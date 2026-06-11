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
	assert_eq(z.portals.size(), 1)
	assert_eq(z.portals.values()[0], "cave")
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
