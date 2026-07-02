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
		if c is MultiMeshInstance3D:
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
		if c is MultiMeshInstance3D:
			mats[c.material_override] = true
	assert_eq(mats.size(), 1, "alla terrängbatcher ska dela ETT material (pooling)")

func test_portal_markers_created():
	var m := _load_model("thais_fields")
	var z := _build_view(m)
	var markers := 0
	for c in z.get_children():
		if c is MeshInstance3D:
			markers += 1
	var locked_shortcuts := 0
	for t in m.shortcut_points:
		if not UnlockSystem.is_unlocked(m.shortcut_points[t]):
			locked_shortcuts += 1
	var expected: int = m.portals.size() + locked_shortcuts + m.dungeon_entrances.size()
	assert_eq(markers, expected, "varje portal/genväg/ingång ska få en marker")

# ── Player3D över PlayerSim ───────────────────────────────────────────────────

func _first_walkable_dir(m: ZoneModel, from: Vector2i) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if m.is_walkable(from + d):
			return d
	return Vector2i.ZERO

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
	p._process(0.0)
	assert_eq(p.position, Zone3D.tile_to_world3(m.player_start),
		"vid move_progress 0 ska vyn stå kvar på från-rutan")
	# En kvarts sekund vid grundfart 4 tiles/s = halvvägs in i steget.
	var expected_progress: float = 0.125 * p.sim.move_speed
	p._process(0.125)
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
