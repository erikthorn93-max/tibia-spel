class_name Zone3D
extends Node3D
## 3D-vy för en spelzon: renderar en ZoneModel med MultiMesh — en batch per
## terrängtyp (max 13 draw calls för marken, prestandakravet från dag 1).
## Miljömodeller (träd/klippor/vegetation ur assets/models3d) scattras också
## via MultiMesh: en batch per mesh-del i GLB:n, aldrig per instans. Kistor
## är klickbara entiteter (Chest3D), inte scatter.
## Samma modell som 2D-vyn (zone.gd); ingen spellogik här. Ett gemensamt
## material för alla terrängbatcher (material-pooling) — färgen bor per instans.

const TILE3D := 1.0            # en tile = 1 meter
const GROUND_THICK := 0.1
const WALL_HEIGHT := 2.0
const WATER_DROP := 0.1        # vattenytan ligger nedsänkt under marknivån

## Terränger som reser sig ur marken (tecken → höjd). Träd (t) och klippor (r)
## renderas som markplattor med GLB-scatter ovanpå — se modellerna nedan.
const TALL := {"W": WALL_HEIGHT, "w": WALL_HEIGHT}

## Miljömodeller ur assets/models3d (normaliserade till 1,0 m höjd, fötter på
## y=0) + världshöjd i meter. Trädet väljs deterministiskt per ruta ur listan
## så skogen varierar utan fler batcher än en per modellfil.
const TREE_MODELS := [
	{"file": "pine_tree_tall", "h": 2.3},
	{"file": "fir_tree_short", "h": 1.7},
	{"file": "pine_stunted", "h": 1.4},
]
const ROCK_MODEL := {"file": "mossy_rock", "h": 0.8}
const FLOWER_MODEL := {"file": "wildflower", "h": 0.35}
const FERN_MODEL := {"file": "fern", "h": 0.4}
const FLOWER_EVERY := 11       # ungefär var elfte gräsruta (.) får en blomma
const FERN_EVERY := 13         # ungefär var trettonde ängsruta (g) får ormbunke

## Tema-styrd scatter: trädset per biom (Biome.classify på zon-id) — öknen
## får kaktusar, träsket och vulkanlandet döda träd, isen tålig barrskog.
## Biom utan egen rad behåller standardskogen (TREE_MODELS).
const BIOME_TREES := {
	Biome.SWAMP:   [{"file": "dead_tree", "h": 1.9}, {"file": "pine_stunted", "h": 1.3}],
	Biome.DESERT:  [{"file": "cactus", "h": 1.4}],
	Biome.VOLCANO: [{"file": "dead_tree", "h": 1.8}],
	Biome.CAVE:    [{"file": "dead_tree", "h": 1.5}],
	Biome.ICE:     [{"file": "fir_tree_short", "h": 1.7}, {"file": "pine_stunted", "h": 1.4}],
}
const CACTUS_SMALL := {"file": "cactus", "h": 0.6}
const CACTUS_EVERY := 17       # gles ökendekoration — enstaka småkaktusar

static func tree_models_for(biome: String) -> Array:
	return BIOME_TREES.get(biome, TREE_MODELS)

## Gles markdekor per biom för gräs (.) och äng (g): {"spec", "every"} eller
## {} = ingen dekor. Öknen får småkaktusar, träsket ormbunkar överallt;
## is/vulkan/grotta är kala. Standard: blommor på gräs, ormbunkar på äng.
static func ground_decor_for(biome: String, ch: String) -> Dictionary:
	match biome:
		Biome.DESERT:
			if ch == ".":
				return {"spec": CACTUS_SMALL, "every": CACTUS_EVERY}
			return {}
		Biome.ICE, Biome.VOLCANO, Biome.CAVE:
			return {}
		Biome.SWAMP:
			if ch == ".":
				return {"spec": FERN_MODEL, "every": FLOWER_EVERY}
			return {"spec": FERN_MODEL, "every": FERN_EVERY}
		_:
			if ch == ".":
				return {"spec": FLOWER_MODEL, "every": FLOWER_EVERY}
			return {"spec": FERN_MODEL, "every": FERN_EVERY}

## Cache av extraherade mesh-delar per modellfil: [{mesh, xform}].
## Delas mellan zonbyggen — GLB:n instansieras EN gång per körning.
static var _mesh_cache: Dictionary = {}

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
	_build_scatter()
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
		mm.set_instance_color(i, base.lightened(float(_tile_hash(t) % 13) / 100.0))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _shared_mat
	inst.name = "Terrain_" + ch
	return inst

## Deterministiskt hash per ruta — samma ruta ger samma värde varje besök.
static func _tile_hash(t: Vector2i) -> int:
	return absi((t.x * 73856093) ^ (t.y * 19349663))

# ── Miljö-scatter (GLB-modeller via MultiMesh) ────────────────────────────────
## Träd/klippor/kistor/vegetation grupperade per modellfil → en MultiMesh-batch
## per mesh-del i GLB:n. Samma draw call-budget som marken: antalet batcher
## beror på antalet modellfiler, inte antalet instanser.
func _build_scatter() -> void:
	var biome := Biome.classify(model.zone_id)
	var trees := tree_models_for(biome)
	var groups: Dictionary = {}   # fil → {"h", "jitter", "tiles"}
	for t: Vector2i in model.terrain:
		var ch: String = model.terrain[t]
		match ch:
			"t":
				_scatter_add(groups, trees[_tile_hash(t) % trees.size()], t, true)
			"r":
				_scatter_add(groups, ROCK_MODEL, t, true)
			".", "g":
				var decor := ground_decor_for(biome, ch)
				if not decor.is_empty() and _tile_hash(t) % int(decor["every"]) == 0 \
						and not model.blocked.has(t):
					_scatter_add(groups, decor["spec"], t, true)
	for file in groups:
		_make_scatter(file, groups[file])

func _scatter_add(groups: Dictionary, spec: Dictionary, t: Vector2i, jitter: bool) -> void:
	var file := String(spec["file"])
	if not groups.has(file):
		groups[file] = {"h": float(spec["h"]), "jitter": jitter, "tiles": []}
	groups[file]["tiles"].append(t)

## Bygger MultiMesh-batcher för en modellfil. Rotation/skala/position jittras
## deterministiskt per ruta (samma frö-idé som ljusvariationen) så världen ser
## likadan ut varje besök. Kistor står rakt och ojittrade.
func _make_scatter(file: String, group: Dictionary) -> void:
	var parts := _model_meshes(file)
	if parts.is_empty():
		return   # GLB saknas/tom — rutan behåller sin markplatta
	var tiles: Array = group["tiles"]
	var jitter: bool = group["jitter"]
	var h: float = group["h"]
	for pi in parts.size():
		var part: Dictionary = parts[pi]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = tiles.size()
		for i in tiles.size():
			var t: Vector2i = tiles[i]
			var hh := _tile_hash(t)
			var pos := tile_to_world3(t)
			var rot := 0.0
			var s := h
			if jitter:
				rot = TAU * float(hh % 97) / 97.0
				s *= 0.85 + 0.3 * float(hh % 31) / 31.0
				pos.x += (float(hh % 7) / 7.0 - 0.5) * 0.3
				pos.z += (float(hh % 13) / 13.0 - 0.5) * 0.3
			var basis := Basis(Vector3.UP, rot).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(basis, pos) * part["xform"])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.name = "Scatter_%s_%d" % [file, pi]
		add_child(inst)

## Extraherar mesh-delarna ur en GLB (mesh + transform relativt roten) och
## cachar dem. Eventuella surface-overrides på instansen bakas in i en kopia
## av meshen så materialen följer med in i MultiMeshen.
static func _model_meshes(file: String) -> Array:
	if _mesh_cache.has(file):
		return _mesh_cache[file]
	var parts: Array = []
	var path := "res://assets/models3d/%s.glb" % file
	if ResourceLoader.exists(path):
		var root: Node3D = (load(path) as PackedScene).instantiate()
		_collect_meshes(root, Transform3D.IDENTITY, parts)
		root.free()
	_mesh_cache[file] = parts
	return parts

static func _collect_meshes(n: Node, xf: Transform3D, out: Array) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		var mesh: Mesh = mi.mesh
		var has_override := false
		for i in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(i) != null:
				has_override = true
				break
		var am: ArrayMesh = null
		if has_override:
			am = mesh.duplicate() as ArrayMesh
		if am != null:
			for j in mi.get_surface_override_material_count():
				if mi.get_surface_override_material(j) != null:
					am.surface_set_material(j, mi.get_surface_override_material(j))
			mesh = am
		out.append({"mesh": mesh, "xform": xf})
	for c in n.get_children():
		_collect_meshes(c, xf, out)

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
	# Modellen har redan uppdaterat sin terräng — bygg om batcharna (inkl.
	# scattern: ett öppnat träd ska tappa sin modell). Händer enstaka gånger
	# per zonvistelse, så en full ombyggnad duger.
	for c in get_children():
		if String(c.name).begins_with("Terrain_") or String(c.name).begins_with("Scatter_"):
			c.queue_free()
	_build_terrain.call_deferred()
	_build_scatter.call_deferred()

func _on_shortcut_opened(t: Vector2i) -> void:
	if _shortcut_markers.has(t):
		_shortcut_markers[t].queue_free()
		_shortcut_markers.erase(t)

func _on_portal_unlocked(t: Vector2i) -> void:
	_add_portal_marker(t)
