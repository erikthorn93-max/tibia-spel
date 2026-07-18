class_name Zone3D
extends Node3D
## 3D-vy för en spelzon: renderar en ZoneModel med MultiMesh — en batch per
## terrängtyp (max 13 draw calls för marken, prestandakravet från dag 1).
## Miljömodeller (träd/klippor/vegetation ur assets/models3d) scattras också
## via MultiMesh: en batch per mesh-del i GLB:n, aldrig per instans. Kistor
## är klickbara entiteter (Chest3D), inte scatter.
## Samma modell som 2D-vyn (zone.gd); ingen spellogik här. Ett gemensamt
## material för alla terrängbatcher (material-pooling) — färgen bor per instans.

const DungeonGen = preload("res://world/dungeon_generator.gd")

const TILE3D := 1.0            # en tile = 1 meter
const GROUND_THICK := 0.1
const WALL_HEIGHT := 2.0
const WATER_DROP := 0.1        # vattenytan ligger nedsänkt under marknivån
const ROOF_HEIGHT := WALL_HEIGHT + 0.25   # taket sticker upp över väggkrönet

## Terränger som reser sig ur marken (tecken → höjd). Träd (t) och klippor (r)
## renderas som markplattor med GLB-scatter ovanpå — se modellerna nedan.
const TALL := {"W": WALL_HEIGHT, "w": WALL_HEIGHT}

## Internt gruppnyckel för takrutor (r-regioner som rör en vägg) i terräng-
## bygget — får aldrig kollidera med ett riktigt terrängtecken.
const ROOF_KEY := "R^"

## 3D-palett: varmare sten för väggar än 2D-fallbackens kalla grå (fönstrens
## basvägg = väggens — glasbandet står för fönsterkänslan). Tak i terrakotta,
## kröningssten i ljus kalksten. Marken behåller PlaceholderTiles-färgerna.
const COLOR_3D := {"W": Color("8a8478"), "w": Color("8a8478")}
const ROOF_COLOR := Color("8a3a22")
const CAP_COLOR := Color("aaa49a")
const GLASS_COLOR := Color("31505e")
const GLASS_GLOW := Color("7fb6d0")

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

## Interaktionsmodeller: riktiga GLB:er där en naturlig modell finns —
## trappor och dungeon-nedgångar får stentrappan, portaler smaragdsigillen
## (låsta i gråtonat material utan skimmer — samma form, "stängd", som 2D:s
## gråa virvel). Genvägar behåller kuben. Portaler/dörrar/nedgångar får
## billboardade skyltar med samma texter som 2D ("→ Zon", "Låst: …", "Ner: …").
const STAIR_MARKER := {"file": "stone_staircase", "h": 0.9}
const ENTRANCE_MARKER := {"file": "stone_staircase", "h": 0.75}
const PORTAL_MARKER := {"file": "emerald_sigil", "h": 0.9}
## Husdörrar (entrance-rutor): prop_door är byggd i världsskala (1,66 m) —
## h är ren skalfaktor 1,0, till skillnad från de 1 m-normaliserade modellerna.
const DOOR_MARKER := {"file": "prop_door", "h": 1.0}

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
var _roof_tiles: Dictionary = {}   # Vector2i -> true (r-rutor som är hustak)
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
		if model.entrance_points.has(t):
			_add_door_marker(t)
		elif model.stair_points.has(t):
			_add_model_marker(t, STAIR_MARKER, Color(0.80, 0.74, 0.48), 0.0)
		else:
			_add_portal_marker(t)
	for t in model.shortcut_points:
		if not UnlockSystem.is_unlocked(model.shortcut_points[t]):
			_shortcut_markers[t] = _add_marker(t, Color(0.8, 0.7, 0.4), 0.4)
	for t in model.dungeon_entrances:
		var entr := _add_model_marker(t, ENTRANCE_MARKER, Color(0.15, 0.12, 0.2), 0.0)
		_add_marker_label(entr, "Ner: " + DungeonGen.theme_name(
			String(model.dungeon_entrances[t])), Color(0.75, 0.7, 0.8), 1.1)

## Klassar zonens 'r'-rutor: en sammanhängande r-region som rör en vägg (W/w)
## är ett hustak — stadens byggnader får röda takvolymer — medan fristående
## regioner förblir klippmark med stenscatter (vildmarkens betydelse av 'r').
static func classify_roofs(m: ZoneModel) -> Dictionary:
	var roofs: Dictionary = {}
	var seen: Dictionary = {}
	for start: Vector2i in m.terrain:
		if String(m.terrain[start]) != "r" or seen.has(start):
			continue
		var region: Array[Vector2i] = [start]
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		var touches_wall := false
		while not queue.is_empty():
			var t: Vector2i = queue.pop_back()
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = t + d
				var ch := String(m.terrain.get(n, ""))
				if ch == "W" or ch == "w":
					touches_wall = true
				elif ch == "r" and not seen.has(n):
					seen[n] = true
					region.append(n)
					queue.append(n)
		if touches_wall:
			for t in region:
				roofs[t] = true
	return roofs

## Grupperar tiles per terrängtecken och bygger en MultiMesh-batch per grupp.
## Takrutor bryts ut ur 'r'-gruppen till en egen takbatch, och väggarna får
## dressing (kröningssten + fönsterglas) ovanpå.
func _build_terrain() -> void:
	_roof_tiles = classify_roofs(model)
	var groups: Dictionary = {}
	for t: Vector2i in model.terrain:
		var ch: String = model.terrain[t]
		if ch == "r" and _roof_tiles.has(t):
			ch = ROOF_KEY
		if not groups.has(ch):
			groups[ch] = []
		groups[ch].append(t)
	for ch in groups:
		add_child(_make_batch(ch, groups[ch]))
	_build_wall_dressing()

func _make_batch(ch: String, tiles: Array) -> MultiMeshInstance3D:
	var is_roof := ch == ROOF_KEY
	var height: float = ROOF_HEIGHT if is_roof else TALL.get(ch, GROUND_THICK)
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
	var base: Color = ROOF_COLOR if is_roof \
		else COLOR_3D.get(ch, PlaceholderTiles.COLORS.get(ch, Color("888888")))
	var tall := is_roof or TALL.has(ch)
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		var pos := tile_to_world3(t)
		pos.y = y_center
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		# Deterministisk ljusvariation per ruta — samma idé som variant_for i 2D.
		# Höga volymer (väggar/tak) varieras symmetriskt åt båda hållen så
		# stenraderna får murkänsla i stället för slät massa.
		if tall:
			var v := float(_tile_hash(t) % 17 - 8) / 100.0
			mm.set_instance_color(i, base.lightened(v) if v >= 0.0 else base.darkened(-v))
		else:
			mm.set_instance_color(i, base.lightened(float(_tile_hash(t) % 13) / 100.0))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _shared_mat
	inst.name = "Roof_r" if is_roof else "Terrain_" + ch
	return inst

## Väggdressing: ljus kröningssten ovanpå varje vägg (siluetten läses som
## huggen mur i stället för slät låda) och ett glasband på fönsterrutorna (w)
## med svag emission så fönstren glimmar i skymningen. En batch vardera.
func _build_wall_dressing() -> void:
	var walls: Array = []
	var windows: Array = []
	for t: Vector2i in model.terrain:
		var ch: String = model.terrain[t]
		if ch == "W" or ch == "w":
			walls.append(t)
		if ch == "w":
			windows.append(t)
	if not walls.is_empty():
		var cap := BoxMesh.new()
		cap.size = Vector3(1.06, 0.09, 1.06)
		add_child(_dressing_batch("WallCap", cap, walls,
			WALL_HEIGHT - GROUND_THICK + 0.045, CAP_COLOR, 8, _shared_mat))
	if not windows.is_empty():
		var pane := BoxMesh.new()
		pane.size = Vector3(1.05, 0.6, 1.05)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = GLASS_COLOR
		glass.roughness = 0.25
		glass.emission_enabled = true
		glass.emission = GLASS_GLOW
		glass.emission_energy_multiplier = 0.35
		add_child(_dressing_batch("WindowPane", pane, windows, 1.25, Color.WHITE, 0, glass))

## MultiMesh-batch för väggdressing: samma platta ovanpå varje angiven ruta,
## med valfri symmetrisk ljusvariation (var_pct = ±procent, 0 = ingen).
func _dressing_batch(bname: String, mesh: Mesh, tiles: Array, y: float,
		base: Color, var_pct: int, mat: StandardMaterial3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		var pos := tile_to_world3(t)
		pos.y = y
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		var col := base
		if var_pct > 0:
			var v := float(_tile_hash(t) % (2 * var_pct + 1) - var_pct) / 100.0
			col = base.lightened(v) if v >= 0.0 else base.darkened(-v)
		mm.set_instance_color(i, col)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	inst.name = bname
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
				if not _roof_tiles.has(t):   # takrutor är byggnader, inte stenrösen
					_scatter_add(groups, ROCK_MODEL, t, true)
			".", "g":
				var decor := ground_decor_for(biome, ch)
				if not decor.is_empty() and _tile_hash(t) % int(decor["every"]) == 0 \
						and not model.blocked.has(t):
					_scatter_add(groups, decor["spec"], t, true)
	for file in groups:
		_make_scatter(file, groups[file])
	_build_town_props()

## Stadsrekvisita: lyktstolpar längs gator som löper intill väggar och
## tunnor/lådor i golvlagda interiörer — deterministiskt urval per ruta
## (hash-gallring), placerade indragna mot väggen så gångstråket hålls fritt.
## MultiMesh-batch per mesh-del, precis som scattern.
func _build_town_props() -> void:
	var lanterns: Array = []
	var barrels: Array = []
	var crates: Array = []
	for t: Vector2i in model.terrain:
		if model.blocked.has(t):
			continue
		var ch: String = model.terrain[t]
		var wd := _wall_neighbor_dir(t)
		if wd == Vector2i.ZERO:
			continue
		var off := Vector3(wd.x, 0, wd.y)
		var h := _tile_hash(t)
		if (ch == "c" or ch == "b") and h % 5 == 0:
			lanterns.append({"t": t, "off": off * 0.34})
		elif ch == "f":
			if h % 9 == 0:
				barrels.append({"t": t, "off": off * 0.26})
			elif h % 9 == 4:
				crates.append({"t": t, "off": off * 0.26})
	_make_props("prop_lantern", lanterns, false)
	_make_props("prop_barrel", barrels, true)
	_make_props("prop_crate", crates, true)

## Första kardinalgrannen som är vägg (W/w), annars ZERO — props ställs mot
## väggen och gator utan vägg intill hålls rena.
func _wall_neighbor_dir(t: Vector2i) -> Vector2i:
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var ch := String(model.terrain.get(t + d, ""))
		if ch == "W" or ch == "w":
			return d
	return Vector2i.ZERO

## Bygger MultiMesh-batcher för en världsskalig prop på givna platser
## ({"t": tile, "off": världsoffset}). rot_jitter vrider deterministiskt.
func _make_props(file: String, entries: Array, rot_jitter: bool) -> void:
	if entries.is_empty():
		return
	var parts := _model_meshes(file)
	if parts.is_empty():
		return   # GLB saknas — rutan klarar sig utan rekvisita
	for pi in parts.size():
		var part: Dictionary = parts[pi]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = entries.size()
		for i in entries.size():
			var e: Dictionary = entries[i]
			var t: Vector2i = e["t"]
			var pos: Vector3 = tile_to_world3(t) + e["off"]
			var rot := 0.0
			if rot_jitter:
				rot = TAU * float(_tile_hash(t) % 89) / 89.0
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rot), pos) * part["xform"])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.name = "Props_%s_%d" % [file, pi]
		add_child(inst)

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
			var xb := Basis(Vector3.UP, rot).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(xb, pos) * part["xform"])
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
	mi.name = "Marker_%d_%d" % [t.x, t.y]
	mi.position = tile_to_world3(t) + Vector3(0, 0.35, 0)
	mi.rotation.y = PI / 4.0   # ställd på hörn — läses som "interagera här"
	add_child(mi)
	return mi

## Riktig GLB-modell på en interaktionsruta — mesh-delarna ur den delade
## cachen (ingen instansiering per marker), deterministisk 90°-vridning per
## ruta (eller explicit vridning via rot, för riktade markörer som dörrar).
## Faller tillbaka till kub-markern om modellen saknas. glow > 0 ger
## en svag additiv overlay i signaturfärgen (Monster3D-idiomet) så rutan
## läses som magisk/interaktiv även i skymning. override_mat ersätter
## GLB:ns egna material (låst portal = gråtonad sigill, som 2D:s grå virvel).
func _add_model_marker(t: Vector2i, spec: Dictionary, color: Color, glow: float,
		rot := NAN, override_mat: StandardMaterial3D = null) -> Node3D:
	var parts := _model_meshes(String(spec["file"]))
	if parts.is_empty():
		return _add_marker(t, color, maxf(glow, 0.3))
	var root := Node3D.new()
	root.name = "Marker_%d_%d" % [t.x, t.y]
	root.position = tile_to_world3(t)
	if is_nan(rot):
		rot = (PI / 2.0) * float(_tile_hash(t) % 4)
	root.rotation.y = rot   # vridningen bor på roten (läsbar för tester/vyer)
	var xb := Basis.IDENTITY.scaled(Vector3.ONE * float(spec["h"]))
	var overlay: StandardMaterial3D = null
	if glow > 0.0:
		overlay = StandardMaterial3D.new()
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		overlay.albedo_color = color * glow
	for part: Dictionary in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part["mesh"]
		mi.transform = Transform3D(xb, Vector3.ZERO) * part["xform"]
		if overlay != null:
			mi.material_overlay = overlay
		if override_mat != null:
			mi.material_override = override_mat
		root.add_child(mi)
	add_child(root)
	return root

## Billboardad skylt på en interaktionsruta — samma texter som 2D:s Label-
## markörer (Npc3D-idiomet: no_depth_test så den läses genom väggar/träd).
func _add_marker_label(parent: Node3D, text: String, color: Color, y: float) -> void:
	var l := Label3D.new()
	l.name = "Skylt"
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 36
	l.outline_size = 10
	l.pixel_size = 0.01
	l.position.y = y - parent.position.y
	parent.add_child(l)

## Husdörr på en entrance-ruta — samma åtskillnad som 2D-vyns dörrmarkör.
## Dörrbladet spänner X i modellen; står väggarna i y-led vrids den 90° så
## dörren fyller luckan i sin väggrad. Stängd dörr = ingen glow (låsta och
## olåsta ser lika ut — låset prövas vid steget, som 2D).
func _add_door_marker(t: Vector2i) -> void:
	var marker := _add_model_marker(t, DOOR_MARKER, Color(0.45, 0.32, 0.18), 0.0,
		_door_rotation(t))
	# Namnskylt på husdörren så den går att hitta — samma text som 2D. Vid
	# dubbeldörrar (två entrance-rutor i rad mot samma zon) skyltas bara den
	# första — billboardade skyltar på grannrutor överlappar annars varandra.
	for prev in [t + Vector2i.LEFT, t + Vector2i.UP]:
		if model.entrance_points.has(prev) and model.portals.get(prev) == model.portals[t]:
			return
	_add_marker_label(marker, ZoneModel.zone_display_name(
		String(model.portals[t])), Color(1.0, 0.88, 0.55), 1.95)

## Väggar i x-led (grannar vänster/höger) → dörren spänner X (0°); väggar
## enbart i y-led → 90°. Fristående dörr utan väggrad behåller 0°.
func _door_rotation(t: Vector2i) -> float:
	var wall_x: bool = TALL.has(model.terrain.get(t + Vector2i.LEFT, "")) \
		or TALL.has(model.terrain.get(t + Vector2i.RIGHT, ""))
	var wall_y: bool = TALL.has(model.terrain.get(t + Vector2i.UP, "")) \
		or TALL.has(model.terrain.get(t + Vector2i.DOWN, ""))
	if wall_y and not wall_x:
		return PI / 2.0
	return 0.0

func _add_portal_marker(t: Vector2i) -> void:
	if _portal_marker_nodes.has(t):
		var old: Node3D = _portal_marker_nodes[t]
		old.name = "MarkerDying"   # frigör namnet åt ersättaren
		old.queue_free()
	if model.portal_locks.has(t):
		# Låst: samma sigillform i gråtonat material utan skimmer — 2D:s grå
		# virvel. Skylten säger vad som krävs, som 2D:s "Låst: …"-etikett.
		var gray := StandardMaterial3D.new()
		gray.albedo_color = Color(0.45, 0.45, 0.5)
		gray.roughness = 1.0
		var locked := _add_model_marker(t, PORTAL_MARKER,
			Color(0.45, 0.45, 0.5), 0.0, NAN, gray)
		_add_marker_label(locked, "Låst: %s" % UnlockSystem.display_name(
			String(model.portal_locks[t])), Color(0.7, 0.7, 0.7), 1.25)
		_portal_marker_nodes[t] = locked
	else:
		var open := _add_model_marker(t, PORTAL_MARKER,
			Color(0.62, 0.38, 0.9), 0.5)
		_add_marker_label(open, "→ " + ZoneModel.zone_display_name(
			String(model.portals[t])), Color(0.88, 0.78, 1.0), 1.25)
		_portal_marker_nodes[t] = open

# ── Reaktioner på modellens signaler (samma kontrakt som 2D-vyn) ──────────────
func _on_tile_opened(_t: Vector2i, _terrain_ch: String) -> void:
	# Modellen har redan uppdaterat sin terräng — bygg om batcharna (inkl.
	# scattern: ett öppnat träd ska tappa sin modell). Händer enstaka gånger
	# per zonvistelse, så en full ombyggnad duger.
	for c in get_children():
		var n := String(c.name)
		if n.begins_with("Terrain_") or n.begins_with("Scatter_") \
				or n.begins_with("Roof_") or n.begins_with("Props_") \
				or n == "WallCap" or n == "WindowPane":
			c.queue_free()
	_build_terrain.call_deferred()
	_build_scatter.call_deferred()

func _on_shortcut_opened(t: Vector2i) -> void:
	if _shortcut_markers.has(t):
		_shortcut_markers[t].queue_free()
		_shortcut_markers.erase(t)

func _on_portal_unlocked(t: Vector2i) -> void:
	_add_portal_marker(t)
