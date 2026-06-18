extends GutTest
## Tester för Thais-utkanter: nya tiles, generad town, nya landsbygdszoner.

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

func test_new_terrain_chars_registered():
	for ch in ["t", "c", "g"]:
		assert_true(PlaceholderTiles.TERRAIN.has(ch), "TERRAIN saknar '%s'" % ch)
		assert_true(PlaceholderTiles.TILE_FILES.has(ch), "TILE_FILES saknar '%s'" % ch)
		assert_true(PlaceholderTiles.COLORS.has(ch), "COLORS saknar '%s'" % ch)

func test_terrain_indices():
	assert_eq(PlaceholderTiles.TERRAIN["t"], 10)
	assert_eq(PlaceholderTiles.TERRAIN["c"], 11)
	assert_eq(PlaceholderTiles.TERRAIN["g"], 12)

# ── Genererad värld (kräver att gen_thais.gd körts) ──

func test_town_is_expanded():
	var z = _make_zone("town")
	assert_eq(z.grid_size.x, 280, "town bredd")
	assert_eq(z.grid_size.y, 200, "town höjd")

func test_town_player_start_walkable():
	var z = _make_zone("town")
	assert_ne(z.player_start, Vector2i.ZERO, "player_start saknas")
	assert_true(z.is_walkable(z.player_start), "player_start ej gångbar")

func test_town_keeps_local_portals():
	var z = _make_zone("town")
	var dests = z.portals.values()
	for d in ["cave", "forest", "coast", "troll_cave", "vampire_crypt", "dwarf_mine", "thais_fields", "thais_wilds"]:
		assert_true(dests.has(d), "town saknar portal till %s" % d)

func test_town_moved_exotic_out():
	var z = _make_zone("town")
	var dests = z.portals.values()
	for d in ["desert", "volcano", "ice", "demon_temple", "minotaur_maze", "orc_rift"]:
		assert_false(dests.has(d), "town har kvar exotisk portal %s" % d)

func test_fields_and_wilds_load():
	var fields = _make_zone("thais_fields")
	assert_eq(fields.grid_size, Vector2i(120, 100))
	assert_true(fields.portals.values().has("town"), "fields saknar retur till town")
	assert_true(fields.portals.values().has("ice"))
	assert_true(fields.portals.values().has("desert"))
	assert_ne(fields.player_start, Vector2i.ZERO, "fields player_start saknas")
	assert_true(fields.is_walkable(fields.player_start), "fields player_start ej gångbar")
	var wilds = _make_zone("thais_wilds")
	assert_true(wilds.portals.values().has("town"), "wilds saknar retur till town")
	for d in ["volcano", "demon_temple", "minotaur_maze", "orc_rift"]:
		assert_true(wilds.portals.values().has(d), "wilds saknar %s" % d)
	assert_true(wilds.is_walkable(wilds.player_start), "wilds player_start ej gångbar")

func test_fields_links_to_heights():
	var fields = _make_zone("thais_fields")
	assert_true(fields.portals.values().has("thais_heights"), "fields saknar portal till heights")

func test_heights_loads_and_returns():
	var heights = _make_zone("thais_heights")
	assert_eq(heights.grid_size, Vector2i(120, 100))
	assert_true(heights.portals.values().has("thais_fields"), "heights saknar retur till fields")
	assert_ne(heights.player_start, Vector2i.ZERO, "heights player_start saknas")
	assert_true(heights.is_walkable(heights.player_start), "heights player_start ej gångbar")

func test_heights_portal_reachable():
	_assert_dests_reachable(_make_zone("thais_heights"), ["thais_fields"], "thais_heights")

func test_heights_links_to_mountains():
	var heights = _make_zone("thais_heights")
	assert_true(heights.portals.values().has("thais_mountains"), "heights saknar portal till mountains")

func test_mountains_loads_and_returns():
	var m = _make_zone("thais_mountains")
	assert_eq(m.grid_size, Vector2i(120, 100))
	assert_true(m.portals.values().has("thais_heights"), "mountains saknar retur till heights")
	assert_ne(m.player_start, Vector2i.ZERO, "mountains player_start saknas")
	assert_true(m.is_walkable(m.player_start), "mountains player_start ej gångbar")

func test_mountains_portal_reachable():
	_assert_dests_reachable(_make_zone("thais_mountains"), ["thais_heights"], "thais_mountains")

# ── Nåbarhet: portaler featuren placerar i utkanterna/landsbygd ska gå att
# nå från spelarens start. (Interiöra byggnadsingångar — gillen, arena,
# trappor — testas inte här; deras nåbarhet ärvs oförändrat från kärnan.) ──

func _assert_dests_reachable(z, dests: Array, label: String) -> void:
	for t in z.portals:
		if not dests.has(z.portals[t]):
			continue
		var path = z.find_path(z.player_start, t)
		assert_gt(path.size(), 0, "%s: portal till %s vid %s ej nåbar från player_start" % [label, z.portals[t], str(t)])

func test_town_outdoor_portals_reachable():
	var dests = ["cave", "forest", "coast", "troll_cave", "vampire_crypt", "dwarf_mine", "thais_fields", "thais_wilds"]
	_assert_dests_reachable(_make_zone("town"), dests, "town")

func test_fields_portals_reachable():
	_assert_dests_reachable(_make_zone("thais_fields"), ["town", "ice", "desert"], "thais_fields")

func test_wilds_portals_reachable():
	_assert_dests_reachable(_make_zone("thais_wilds"), ["town", "volcano", "demon_temple", "minotaur_maze", "orc_rift"], "thais_wilds")
