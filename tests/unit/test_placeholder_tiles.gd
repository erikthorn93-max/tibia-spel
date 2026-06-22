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

# ── Naturdetaljer (dekor-overlay) ──

func test_decor_atlas_has_all_decals():
	var ts := PlaceholderTiles.build_decor()
	assert_not_null(ts)
	var src := ts.get_source(0) as TileSetAtlasSource
	for i in PlaceholderTiles.DECOR_TILES:
		assert_true(src.has_tile(Vector2i(i, 0)), "saknar dekal %d" % i)

func test_decor_for_is_deterministic():
	assert_eq(
		PlaceholderTiles.decor_for(Vector2i(9, 4), "."),
		PlaceholderTiles.decor_for(Vector2i(9, 4), "."))

func test_decor_for_none_on_undecorated_terrain():
	# Mur/vatten ska aldrig få dekal.
	for t in 30:
		assert_eq(PlaceholderTiles.decor_for(Vector2i(t, t), "W"), PlaceholderTiles.DECOR_NONE)
		assert_eq(PlaceholderTiles.decor_for(Vector2i(t, t * 2), "~"), PlaceholderTiles.DECOR_NONE)

func test_decor_for_is_sparse_but_present():
	var decorated := 0
	for x in 30:
		for y in 30:
			if PlaceholderTiles.decor_for(Vector2i(x, y), ".") != PlaceholderTiles.DECOR_NONE:
				decorated += 1
	assert_gt(decorated, 0, "någon ruta ska dekoreras")
	assert_lt(decorated, 450, "dekor ska vara gles (< hälften av 900)")

func test_decor_for_returns_valid_decal_index():
	for x in 40:
		var d := PlaceholderTiles.decor_for(Vector2i(x, x + 3), ".")
		if d != PlaceholderTiles.DECOR_NONE:
			assert_between(d, 0, PlaceholderTiles.DECOR_TILES - 1)

# ── Gräsfrans (väg/jord → gräs-övergång) ──

func test_fringe_atlas_has_tiles_for_all_masks():
	var ts := PlaceholderTiles.build_fringe()
	assert_not_null(ts)
	var src := ts.get_source(0) as TileSetAtlasSource
	for mask in range(1, 16):
		assert_true(src.has_tile(Vector2i(mask, 0)), "saknar frans för mask %d" % mask)

func test_fringe_tile_has_visible_pixels():
	var img := PlaceholderTiles.make_fringe_tile(PlaceholderTiles.FOAM_N)
	var visible := 0
	for y in PlaceholderTiles.TILE:
		for x in PlaceholderTiles.TILE:
			if img.get_pixel(x, y).a > 0.0:
				visible += 1
	assert_gt(visible, 0, "fransen ska ha synliga pixlar")

func test_fringe_more_edges_means_more_pixels():
	var one := _opaque_count(PlaceholderTiles.make_fringe_tile(PlaceholderTiles.FOAM_N))
	var all := _opaque_count(PlaceholderTiles.make_fringe_tile(15))
	assert_gt(all, one, "fyra kanter ska ge mer frans än en")
