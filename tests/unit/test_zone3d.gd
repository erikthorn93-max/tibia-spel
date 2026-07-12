extends GutTest
## Headless-tester för 3D-slicen (steg 4): Zone3D ska rendera en ZoneModel med
## MultiMesh-batcher som täcker hela terrängen, och Player3D ska följa samma
## PlayerSim-kontrakt som 2D-vyn (snap + interpolation ur move_progress).

const Zone3DScript = preload("res://world/zone3d.gd")
const Player3DScript = preload("res://entities/player/player3d.gd")

var _saved_tile: Vector2i
var _saved_agility

func before_each():
	UnlockSystem.unlocked.clear()
	_saved_tile = GameState.player_tile
	_saved_agility = GameState.skills.get("agility", {"level": 1, "xp": 0}).duplicate(true)

func after_each():
	UnlockSystem.unlocked.clear()
	GameState.player_tile = _saved_tile
	GameState.skills["agility"] = _saved_agility

func _load_model(zone_id: String) -> ZoneModel:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var m := ZoneModel.new()
	m.parse(JSON.parse_string(f.get_as_text()), zone_id)
	return m

func _build_view(m: ZoneModel) -> Zone3D:
	var z: Zone3D = Zone3DScript.new()
	add_child_autofree(z)
	z.build(m)
	return z

# ── Koordinatmappning ─────────────────────────────────────────────────────────

func test_tile_world_roundtrip():
	for t in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(120, 88)]:
		assert_eq(Zone3D.world3_to_tile(Zone3D.tile_to_world3(t)), t,
			"tile→värld→tile ska vara identitet")

func test_tile_center_is_half_offset():
	var p := Zone3D.tile_to_world3(Vector2i(2, 5))
	assert_almost_eq(p.x, 2.5, 0.001)
	assert_almost_eq(p.z, 5.5, 0.001)
	assert_almost_eq(p.y, 0.0, 0.001, "markytan ska ligga på y=0")

# ── Terrängbatcher ────────────────────────────────────────────────────────────

func test_build_covers_full_terrain():
	var m := _load_model("thais_fields")
	var z := _build_view(m)
	var total := 0
	var batches := 0
	for c in z.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("Terrain_"):
			batches += 1
			total += c.multimesh.instance_count
	assert_gt(batches, 0, "minst en terrängbatch ska skapas")
	assert_true(batches <= PlaceholderTiles.TERRAIN.size(),
		"max en MultiMesh-batch per terrängtyp (draw call-budget)")
	assert_eq(total, m.terrain.size(),
		"varje terrängruta ska ha exakt en instans — varken hål eller dubbletter")

func test_batches_share_material():
	var z := _build_view(_load_model("thais_fields"))
	var mats := {}
	for c in z.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("Terrain_"):
			mats[c.material_override] = true
	assert_eq(mats.size(), 1, "alla terrängbatcher ska dela ETT material (pooling)")

func test_portal_markers_created():
	var m := _load_model("thais_fields")
	var z := _build_view(m)
	var markers := 0
	for c in z.get_children():
		if String(c.name).begins_with("Marker_"):
			markers += 1
	var locked_shortcuts := 0
	for t in m.shortcut_points:
		if not UnlockSystem.is_unlocked(m.shortcut_points[t]):
			locked_shortcuts += 1
	var expected: int = m.portals.size() + locked_shortcuts + m.dungeon_entrances.size()
	assert_eq(markers, expected, "varje portal/genväg/ingång ska få en marker")

# ── Interaktionsmodeller (GLB-markörer) ───────────────────────────────────────

func _marker_model() -> ZoneModel:
	var m := ZoneModel.new()
	m.parse({"name": "Markörtest", "tiles": ["....", ".P..", "...."]}, "marker_flat")
	return m

func test_stair_marker_uses_staircase_model():
	var m := _marker_model()
	m.portals[Vector2i(0, 0)] = "town"
	m.stair_points[Vector2i(0, 0)] = {"to": "town", "up": true}
	var z := _build_view(m)
	var marker := z.get_node_or_null("Marker_0_0")
	assert_not_null(marker, "trappan ska få en markör-nod")
	var stair_mesh: Mesh = Zone3D._model_meshes("stone_staircase")[0]["mesh"]
	assert_eq((marker.get_child(0) as MeshInstance3D).mesh, stair_mesh,
		"trappmarkören ska använda stentrappans GLB-mesh ur den delade cachen")

func test_dungeon_entrance_uses_staircase_model():
	var m := _marker_model()
	m.dungeon_entrances[Vector2i(2, 2)] = "grotta"
	var z := _build_view(m)
	var marker := z.get_node_or_null("Marker_2_2")
	assert_not_null(marker, "nedgången ska få en markör-nod")
	var stair_mesh: Mesh = Zone3D._model_meshes("stone_staircase")[0]["mesh"]
	assert_eq((marker.get_child(0) as MeshInstance3D).mesh, stair_mesh,
		"dungeon-nedgången ska använda stentrappans GLB-mesh")

func test_entrance_uses_door_model():
	var m := _marker_model()
	m.portals[Vector2i(0, 0)] = "frodo_inn"
	m.entrance_points[Vector2i(0, 0)] = "frodo_inn"
	var z := _build_view(m)
	var marker := z.get_node_or_null("Marker_0_0")
	assert_not_null(marker, "entrance-rutan ska få en markör-nod")
	var door_mesh: Mesh = Zone3D._model_meshes("prop_door")[0]["mesh"]
	assert_eq((marker.get_child(0) as MeshInstance3D).mesh, door_mesh,
		"husdörren ska använda dörr-GLB:n, inte portalsigillen")
	assert_null((marker.get_child(0) as MeshInstance3D).material_overlay,
		"stängd dörr ska inte skimra (ingen overlay)")

func test_door_glb_exists():
	assert_true(ResourceLoader.exists("res://assets/models3d/prop_door.glb"),
		"prop_door.glb ska finnas — annars blir alla dörrar fallback-kuber")

func test_door_aligns_with_wall_row():
	var m := ZoneModel.new()
	# Vägg-rad i x-led runt (1,0) och vägg-kolumn i y-led runt (0,1).
	m.parse({"name": "Dörrtest", "tiles": ["W.W.", "WP..", "W..."]}, "door_flat")
	m.portals[Vector2i(1, 0)] = "frodo_inn"
	m.entrance_points[Vector2i(1, 0)] = "frodo_inn"
	m.portals[Vector2i(0, 1)] = "rain_castle"
	m.entrance_points[Vector2i(0, 1)] = "rain_castle"
	var z := _build_view(m)
	assert_almost_eq(float(z.get_node("Marker_1_0").rotation.y), 0.0, 0.001,
		"väggar i x-led → dörren spänner X (0°)")
	assert_almost_eq(float(z.get_node("Marker_0_1").rotation.y), PI / 2.0, 0.001,
		"väggar enbart i y-led → dörren vrids 90°")

func test_unlocked_portal_gets_sigil_locked_keeps_cube():
	var m := _marker_model()
	m.portals[Vector2i(0, 0)] = "town"
	m.portals[Vector2i(3, 0)] = "town"
	m.portal_locks[Vector2i(3, 0)] = "__marker_testlock"
	var z := _build_view(m)
	var sigil_mesh: Mesh = Zone3D._model_meshes("emerald_sigil")[0]["mesh"]
	var open_marker := z.get_node("Marker_0_0")
	assert_eq((open_marker.get_child(0) as MeshInstance3D).mesh, sigil_mesh,
		"olåst portal ska få smaragdsigillen")
	assert_not_null((open_marker.get_child(0) as MeshInstance3D).material_overlay,
		"portalsigillen ska skimra via en additiv overlay")
	var locked_marker: Node = z.get_node("Marker_3_0")
	assert_true(locked_marker is MeshInstance3D \
		and (locked_marker as MeshInstance3D).mesh is BoxMesh,
		"låst portal ska behålla den dämpade kuben")

func test_portal_unlock_swaps_cube_for_sigil():
	var m := _marker_model()
	m.portals[Vector2i(0, 0)] = "town"
	m.portal_locks[Vector2i(0, 0)] = "__marker_testlock"
	var z := _build_view(m)
	assert_true(z._portal_marker_nodes[Vector2i(0, 0)] is MeshInstance3D,
		"låst portal ska starta som kub")
	m.portal_locks.erase(Vector2i(0, 0))
	z._on_portal_unlocked(Vector2i(0, 0))
	var sigil_mesh: Mesh = Zone3D._model_meshes("emerald_sigil")[0]["mesh"]
	var marker: Node3D = z._portal_marker_nodes[Vector2i(0, 0)]
	assert_eq((marker.get_child(0) as MeshInstance3D).mesh, sigil_mesh,
		"upplåsning ska byta kuben mot sigillen")

func test_model_marker_falls_back_to_cube():
	var m := _marker_model()
	var z := _build_view(m)
	var n := z._add_model_marker(Vector2i(1, 0),
		{"file": "finns_inte_alls", "h": 1.0}, Color.RED, 0.0)
	assert_true(n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh,
		"saknad GLB ska falla tillbaka till kub-markören")

# ── Miljö-scatter (GLB-modeller) ──────────────────────────────────────────────

func _scatter_nodes(z: Zone3D, file: String) -> Array:
	var out := []
	for c in z.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("Scatter_" + file):
			out.append(c)
	return out

func test_model_meshes_nonempty_and_cached():
	var a: Array = Zone3D._model_meshes("treasure_chest")
	assert_gt(a.size(), 0, "GLB:n ska ge minst en mesh-del")
	assert_true(is_same(a, Zone3D._model_meshes("treasure_chest")),
		"mesh-delarna ska cachas — GLB:n instansieras EN gång per körning")

func test_tree_tiles_get_glb_scatter():
	var m := ZoneModel.new()
	var tree_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for t in tree_tiles:
		m.terrain[t] = "t"
	var z := _build_view(m)
	# Samma deterministiska val som vyn: räkna förväntade instanser per fil.
	var per_file := {}
	for t in tree_tiles:
		var spec: Dictionary = Zone3D.TREE_MODELS[Zone3D._tile_hash(t) % Zone3D.TREE_MODELS.size()]
		per_file[spec["file"]] = int(per_file.get(spec["file"], 0)) + 1
	for file in per_file:
		var nodes := _scatter_nodes(z, String(file))
		assert_gt(nodes.size(), 0, "trädfilen %s ska få minst en scatter-batch" % file)
		for c in nodes:
			assert_eq(c.multimesh.instance_count, int(per_file[file]),
				"varje trädruta ska ge exakt en instans i sin modellfils batch")

func test_tree_terrain_renders_as_ground_pad():
	var m := ZoneModel.new()
	m.terrain[Vector2i(0, 0)] = "t"
	var z := _build_view(m)
	var found := false
	for c in z.get_children():
		if c is MultiMeshInstance3D and String(c.name) == "Terrain_t":
			found = true
			assert_almost_eq((c.multimesh.mesh as BoxMesh).size.y, Zone3D.GROUND_THICK, 0.001,
				"trädrutan ska vara markplatta — GLB-modellen står ovanpå")
	assert_true(found, "trädterrängen ska fortfarande få en markbatch")

func test_chest_points_are_not_scatter():
	# Kistor ägs av Chest3D (klickbar entitet) — zonen ska inte scattra dem.
	var m := ZoneModel.new()
	m.terrain[Vector2i(0, 0)] = "f"
	m.chest_points = [Vector2i(0, 0)]
	var z := _build_view(m)
	assert_eq(_scatter_nodes(z, "treasure_chest").size(), 0,
		"kistpunkter ska inte ge scatter — Chest3D äger kistvisualen")

# ── Tema-styrd scatter (biom via zon-id) ──────────────────────────────────────

func test_tree_set_follows_biome():
	assert_eq(Zone3D.tree_models_for(Biome.DESERT)[0]["file"], "cactus")
	assert_eq(Zone3D.tree_models_for(Biome.SWAMP)[0]["file"], "dead_tree")
	assert_eq(Zone3D.tree_models_for(Biome.VOLCANO)[0]["file"], "dead_tree")
	assert_eq(Zone3D.tree_models_for(Biome.FOREST)[0]["file"], "pine_tree_tall",
		"skogsbiomet behåller standardskogen")
	assert_eq(Zone3D.tree_models_for(Biome.FOREST).size(), Zone3D.TREE_MODELS.size())
	assert_eq(Zone3D.tree_models_for(Biome.DEFAULT)[0]["file"], "pine_tree_tall")

func test_biome_tree_files_exist():
	for biome in Zone3D.BIOME_TREES:
		for spec in Zone3D.BIOME_TREES[biome]:
			assert_true(ResourceLoader.exists("res://assets/models3d/%s.glb" % spec["file"]),
				"%s: modellen %s ska finnas" % [biome, spec["file"]])

func test_ground_decor_per_biome():
	assert_eq(Zone3D.ground_decor_for(Biome.DEFAULT, ".")["spec"]["file"], "wildflower")
	assert_eq(Zone3D.ground_decor_for(Biome.DEFAULT, "g")["spec"]["file"], "fern")
	assert_eq(Zone3D.ground_decor_for(Biome.DESERT, ".")["spec"]["file"], "cactus")
	assert_true(Zone3D.ground_decor_for(Biome.DESERT, "g").is_empty(), "ökenäng är kal")
	assert_true(Zone3D.ground_decor_for(Biome.ICE, ".").is_empty(), "isen är kal")
	assert_true(Zone3D.ground_decor_for(Biome.VOLCANO, ".").is_empty(), "vulkanmark är kal")
	assert_true(Zone3D.ground_decor_for(Biome.CAVE, "g").is_empty(), "grottor är kala")
	assert_eq(Zone3D.ground_decor_for(Biome.SWAMP, ".")["spec"]["file"], "fern",
		"träsket byter blommor mot ormbunkar")

func test_desert_zone_trees_become_cacti():
	var m := ZoneModel.new()
	m.zone_id = "glodoknen"   # "okn" → DESERT (Biome.classify)
	for t in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		m.terrain[t] = "t"
	var z := _build_view(m)
	assert_gt(_scatter_nodes(z, "cactus").size(), 0, "öknens träd ska vara kaktusar")
	assert_eq(_scatter_nodes(z, "pine_tree_tall").size(), 0, "inga tallar i öknen")

func test_swamp_zone_gets_dead_trees():
	var m := ZoneModel.new()
	m.zone_id = "swamp"
	for x in range(8):   # nog många rutor för att träsk-setet ska synas
		m.terrain[Vector2i(x, 0)] = "t"
	var z := _build_view(m)
	var batches := _scatter_nodes(z, "dead_tree").size() \
		+ _scatter_nodes(z, "pine_stunted").size()
	assert_gt(batches, 0, "träskets träd ska komma ur träsk-setet")
	assert_eq(_scatter_nodes(z, "pine_tree_tall").size(), 0, "inga tallar i träsket")

# ── Player3D över PlayerSim ───────────────────────────────────────────────────

func _first_walkable_dir(m: ZoneModel, from: Vector2i) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if m.is_walkable(from + d):
			return d
	return Vector2i.ZERO

func test_player3d_connects_spec_sounds():
	# Kraftslagets ljud kopplas i _init — samma UX som 2D:s player.gd.
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	assert_gt(p.sim.spec_denied.get_connections().size(), 0,
		"nekat kraftslag ska ha en ljudkoppling")
	assert_gt(p.sim.spec_released.get_connections().size(), 0,
		"utlöst kraftslag ska ha en ljudkoppling")

func test_player3d_snap_places_on_tile_center():
	var m := _load_model("thais_fields")
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)   # testet tickar sim manuellt
	p.sim.zone = m
	p.snap_to(m.player_start)
	assert_eq(p.position, Zone3D.tile_to_world3(m.player_start))

func test_player3d_interpolates_between_tiles():
	var m := _load_model("thais_fields")
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)
	p.sim.zone = m
	p.snap_to(m.player_start)
	var dir := _first_walkable_dir(m, m.player_start)
	assert_ne(dir, Vector2i.ZERO, "player_start ska ha en gångbar granne")
	p.sim.step(dir)
	p.sim_tick(0.0)
	p.render_interpolate(1.0)   # alpha 1 = senaste sim-steget
	assert_eq(p.position, Zone3D.tile_to_world3(m.player_start),
		"vid move_progress 0 ska vyn stå kvar på från-rutan")
	# En kvarts sekund vid grundfart 4 tiles/s = halvvägs in i steget.
	var expected_progress: float = 0.125 * p.sim.move_speed
	p.sim_tick(0.125)
	p.render_interpolate(1.0)
	var from := Zone3D.tile_to_world3(m.player_start)
	var to := Zone3D.tile_to_world3(m.player_start + dir)
	assert_almost_eq(p.position.x, lerpf(from.x, to.x, expected_progress), 0.001)
	assert_almost_eq(p.position.z, lerpf(from.z, to.z, expected_progress), 0.001)

func test_player3d_visual_faces_walk_direction():
	var m := _load_model("thais_fields")
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)
	p.sim.zone = m
	p.snap_to(m.player_start)
	p.sim.set_facing(Vector2i.RIGHT)
	assert_almost_eq(p._visual.rotation.y, atan2(-1.0, 0.0), 0.001,
		"österut: visualens −Z ska peka mot +X")
