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
