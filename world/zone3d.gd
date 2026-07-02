class_name Zone3D
extends Node3D
## 3D-vy för en spelzon: renderar en ZoneModel med MultiMesh — en batch per
## terrängtyp (max 13 draw calls för marken, prestandakravet från dag 1).
## Samma modell som 2D-vyn (zone.gd); ingen spellogik här. Ett gemensamt
## material för alla batcher (material-pooling) — färgen bor per instans.

const TILE3D := 1.0            # en tile = 1 meter
const GROUND_THICK := 0.1
const WALL_HEIGHT := 2.0
const TREE_HEIGHT := 1.6
const WATER_DROP := 0.1        # vattenytan ligger nedsänkt under marknivån

## Terränger som reser sig ur marken (tecken → höjd).
const TALL := {"W": WALL_HEIGHT, "t": TREE_HEIGHT, "w": WALL_HEIGHT, "r": WALL_HEIGHT}

var model: ZoneModel
var _shared_mat: StandardMaterial3D
var _shortcut_markers: Dictionary = {}    # Vector2i -> Node3D
var _portal_marker_nodes: Dictionary = {} # Vector2i -> Node3D

static func tile_to_world3(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * TILE3D, 0.0, (t.y + 0.5) * TILE3D)

static func world3_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE3D)), int(floor(p.z / TILE3D)))

func build(m: ZoneModel) -> void:
	model = m
	model.tile_opened.connect(_on_tile_opened)
	model.shortcut_opened.connect(_on_shortcut_opened)
	model.portal_unlocked.connect(_on_portal_unlocked)
	_shared_mat = StandardMaterial3D.new()
	_shared_mat.vertex_color_use_as_albedo = true
	_shared_mat.roughness = 1.0

	_build_terrain()
	for t in model.portals:
		if model.stair_points.has(t):
			_add_marker(t, Color(0.80, 0.74, 0.48), 0.5)   # trappa
		else:
			_add_portal_marker(t)
	for t in model.shortcut_points:
		if not UnlockSystem.is_unlocked(model.shortcut_points[t]):
			_shortcut_markers[t] = _add_marker(t, Color(0.8, 0.7, 0.4), 0.4)
	for t in model.dungeon_entrances:
		_add_marker(t, Color(0.15, 0.12, 0.2), 0.3)        # mörkt schakt ner

## Grupperar tiles per terrängtecken och bygger en MultiMesh-batch per grupp.
func _build_terrain() -> void:
	var groups: Dictionary = {}
	for t: Vector2i in model.terrain:
		var ch: String = model.terrain[t]
		if not groups.has(ch):
			groups[ch] = []
		groups[ch].append(t)
	for ch in groups:
		add_child(_make_batch(ch, groups[ch]))

func _make_batch(ch: String, tiles: Array) -> MultiMeshInstance3D:
	var height: float = TALL.get(ch, GROUND_THICK)
	var y_center := height / 2.0 - GROUND_THICK
	if ch == "~":
		y_center -= WATER_DROP
	var box := BoxMesh.new()
	box.size = Vector3(TILE3D, height, TILE3D)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = tiles.size()
	var base: Color = PlaceholderTiles.COLORS.get(ch, Color("888888"))
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		var pos := tile_to_world3(t)
		pos.y = y_center
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		# Deterministisk ljusvariation per ruta — samma idé som variant_for i 2D.
		var h := absi((t.x * 73856093) ^ (t.y * 19349663))
		mm.set_instance_color(i, base.lightened(float(h % 13) / 100.0))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _shared_mat
	inst.name = "Terrain_" + ch
	return inst

# ── Markers ───────────────────────────────────────────────────────────────────
## Självlysande liten kub på en interaktionsruta — 3D-motsvarigheten till
## 2D-vyns pulserande polygoner. Returnerar noden så anroparen kan städa den.
func _add_marker(t: Vector2i, color: Color, glow: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = glow > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = glow
	mi.material_override = mat
	mi.position = tile_to_world3(t) + Vector3(0, 0.35, 0)
	mi.rotation.y = PI / 4.0   # ställd på hörn — läses som "interagera här"
	add_child(mi)
	return mi

func _add_portal_marker(t: Vector2i) -> void:
	if _portal_marker_nodes.has(t):
		_portal_marker_nodes[t].queue_free()
	var locked: bool = model.portal_locks.has(t)
	var color := Color(0.45, 0.45, 0.5) if locked else Color(0.62, 0.38, 0.9)
	_portal_marker_nodes[t] = _add_marker(t, color, 0.0 if locked else 1.2)

# ── Reaktioner på modellens signaler (samma kontrakt som 2D-vyn) ──────────────
func _on_tile_opened(_t: Vector2i, _terrain_ch: String) -> void:
	# Modellen har redan uppdaterat sin terräng — bygg om batcharna.
	# Händer enstaka gånger per zonvistelse, så en full ombyggnad duger.
	for c in get_children():
		if String(c.name).begins_with("Terrain_"):
			c.queue_free()
	_build_terrain.call_deferred()

func _on_shortcut_opened(t: Vector2i) -> void:
	if _shortcut_markers.has(t):
		_shortcut_markers[t].queue_free()
		_shortcut_markers.erase(t)

func _on_portal_unlocked(t: Vector2i) -> void:
	_add_portal_marker(t)
