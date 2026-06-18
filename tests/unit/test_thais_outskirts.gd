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
