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

# ── Strand-overlay (skum vid vatten) ──

func test_overlay_builds_tiles_for_all_masks():
	var ts := PlaceholderTiles.build_overlay()
	assert_not_null(ts)
	var src := ts.get_source(0) as TileSetAtlasSource
	for mask in range(1, 16):
		assert_true(src.has_tile(Vector2i(mask, 0)), "saknar overlay för mask %d" % mask)

func test_foam_tile_has_visible_pixels():
	var img := PlaceholderTiles.make_foam_tile(1)   # en kant
	var visible := 0
	for y in PlaceholderTiles.TILE:
		for x in PlaceholderTiles.TILE:
			if img.get_pixel(x, y).a > 0.0:
				visible += 1
	assert_gt(visible, 0, "skum-tile ska ha synliga pixlar")

func test_more_edges_means_more_foam():
	var one := _opaque_count(PlaceholderTiles.make_foam_tile(1))     # nordkant
	var all := _opaque_count(PlaceholderTiles.make_foam_tile(15))    # alla fyra kanter
	assert_gt(all, one, "fyra kanter ska ge mer skum än en")

func _opaque_count(img: Image) -> int:
	var n := 0
	for y in PlaceholderTiles.TILE:
		for x in PlaceholderTiles.TILE:
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n
