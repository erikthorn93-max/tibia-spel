extends GutTest
## Tester för tile-atlas: varianter per terräng + deterministiskt variantval.

func test_build_returns_tileset_with_source():
	var ts := PlaceholderTiles.build()
	assert_not_null(ts)
	assert_not_null(ts.get_source(0))

func test_atlas_has_base_and_variant_tiles_for_every_terrain():
	var ts := PlaceholderTiles.build()
	var src := ts.get_source(0) as TileSetAtlasSource
	for ch in PlaceholderTiles.TERRAIN:
		var col: int = PlaceholderTiles.TERRAIN[ch]
		assert_true(src.has_tile(Vector2i(col, 0)),
			"saknar bas-tile för '%s'" % ch)
		assert_true(src.has_tile(Vector2i(col, PlaceholderTiles.VARIANTS - 1)),
			"saknar sista varianten för '%s'" % ch)

func test_variant_for_in_range():
	for i in 50:
		var v := PlaceholderTiles.variant_for(Vector2i(i, i * 3 + 1))
		assert_between(v, 0, PlaceholderTiles.VARIANTS - 1)

func test_variant_for_is_deterministic():
	assert_eq(
		PlaceholderTiles.variant_for(Vector2i(5, 7)),
		PlaceholderTiles.variant_for(Vector2i(5, 7)))

func test_variant_for_produces_variety():
	var seen := {}
	for x in 20:
		for y in 20:
			seen[PlaceholderTiles.variant_for(Vector2i(x, y))] = true
	assert_gt(seen.size(), 1, "ska ge mer än en variant över en yta")
