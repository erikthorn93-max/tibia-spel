extends Node2D
## En spelzon: bygger TileMapLayer från data/zones/<id>.json,
## äger walkability-grid, AStarGrid2D, portaler och spawnpunkter.

const TILE := 32
const DungeonGen = preload("res://world/dungeon_generator.gd")
const Weather = preload("res://ui/weather.gd")
const Lighting = preload("res://world/lighting.gd")

var zone_id := ""
var zone_name := ""
var weather := "clear"   # "clear" | "rain" | "fog" | "snow" — driver väder-overlay
var grid_size := Vector2i.ZERO
var player_start := Vector2i.ZERO
var portals: Dictionary = {}        # Vector2i -> mål-zon-id
var spawn_points: Array = []        # [{tile, monster, respawn}]
var node_points: Array = []        # [{tile, node}]
var station_points: Array = []     # [{tile, station}]
var shop_points: Array = []        # [tile]
var bank_points: Array = []        # [tile]
var taskmaster_points: Array = []  # [tile]
var spell_teacher_points: Array = []  # [tile]
var chest_points: Array = []       # [tile] (dungeons)
var dungeon_entrances: Dictionary = {}  # Vector2i -> tema-id
var _monster_tiles: Dictionary = {}    # Vector2i -> Monster (kollisionskarta)
var dungeon_theme := ""            # satt för genererade dungeons
var gate_points: Dictionary = {}   # Vector2i -> unlock-id
var shortcut_points: Dictionary = {}  # Vector2i -> unlock-id (bump-genvägar)
var portal_locks: Dictionary = {}     # Vector2i -> unlock-id (låsta portaler)
var _gate_terrain: Dictionary = {} # Vector2i -> terräng när gaten/genvägen öppnats
var _shortcut_markers: Dictionary = {}    # Vector2i -> Node2D
var _portal_marker_nodes: Dictionary = {} # Vector2i -> Array[Node]
var entrance_points: Dictionary = {}   # Vector2i -> zon-id (husportaler, dörrar)
var stair_points: Dictionary = {}      # Vector2i -> {"to": zon-id, "up": bool}
var _walkable: Dictionary = {}      # Vector2i -> bool
var _water: Dictionary = {}         # Vector2i -> true (för strand-overlay)
var _decor: Array = []              # [[Vector2i, dekal-index]] (naturdetaljer)
var _grass: Dictionary = {}         # Vector2i -> true (för gräsfrans)
var _path: Array = []              # Vector2i (jord/kullersten, för gräsfrans)
var _astar := AStarGrid2D.new()
var tilemap: TileMapLayer

func build(id: String) -> void:
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	build_from_data(JSON.parse_string(f.get_as_text()), id)

func build_from_data(data: Dictionary, id: String) -> void:
	zone_id = id
	zone_name = data["name"]
	dungeon_theme = String(data.get("theme", ""))
	weather = Weather.from_zone_data(data)
	var rows: Array = data["tiles"]
	var legend: Dictionary = data.get("legend", {})
	grid_size = Vector2i(rows[0].length(), rows.size())
	for y in rows.size():
		assert(rows[y].length() == grid_size.x,
			"%s rad %d: längd %d, förväntade %d" % [id, y, rows[y].length(), grid_size.x])

	tilemap = TileMapLayer.new()
	tilemap.tile_set = PlaceholderTiles.build()
	add_child(tilemap)

	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var t := Vector2i(x, y)
			var terrain := ch
			var blocked := false
			match ch:
				"P":
					player_start = t
					terrain = "."
				_:
					if legend.has(ch):
						var e: Dictionary = legend[ch]
						var default_terrain := "," if zone_id != "town" else "."
						terrain = String(e.get("terrain", default_terrain))
						match e["type"]:
							"portal":
								portals[t] = e["to"]
								if e.has("unlock") and not UnlockSystem.is_unlocked(String(e["unlock"])):
									portal_locks[t] = String(e["unlock"])
							"entrance":
								portals[t] = e["to"]
								entrance_points[t] = String(e["to"])
								if e.has("unlock") and not UnlockSystem.is_unlocked(String(e["unlock"])):
									portal_locks[t] = String(e["unlock"])
							"stair_up":
								portals[t] = e["to"]
								stair_points[t] = {"to": String(e["to"]), "up": true}
							"stair_down":
								portals[t] = e["to"]
								stair_points[t] = {"to": String(e["to"]), "up": false}
							"spawn":
								spawn_points.append({"tile": t, "monster": e["monster"], "respawn": float(e.get("respawn", 30.0))})
							"node":
								node_points.append({"tile": t, "node": e["node"]})
								blocked = true
							"station":
								station_points.append({"tile": t, "station": e["station"]})
								blocked = true
							"decoration":
								blocked = true   # blockerar rörelse, öppnar ingen panel
							"shop":
								shop_points.append(t)
								blocked = true
							"bank":
								bank_points.append(t)
								blocked = true
							"taskmaster":
								taskmaster_points.append(t)
								blocked = true
							"spell_teacher":
								spell_teacher_points.append(t)
								blocked = true
							"chest":
								chest_points.append(t)
								blocked = true
							"dungeon_entrance":
								dungeon_entrances[t] = String(e["theme"])
							"gate":
								var uid := String(e["unlock"])
								gate_points[t] = uid
								_gate_terrain[t] = terrain if PlaceholderTiles.TERRAIN.has(terrain) else ","
								if not UnlockSystem.is_unlocked(uid):
									blocked = true
									terrain = "W"   # rasmassor tills gaten öppnas
							"shortcut":
								var suid := String(e["unlock"])
								shortcut_points[t] = suid
								_gate_terrain[t] = terrain if PlaceholderTiles.TERRAIN.has(terrain) else ","
								if not UnlockSystem.is_unlocked(suid):
									blocked = true
									terrain = String(e.get("locked_terrain", "W"))
			if not PlaceholderTiles.TERRAIN.has(terrain):
				terrain = "."
			tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[terrain], PlaceholderTiles.variant_for(t)))
			_walkable[t] = terrain != "W" and terrain != "w" and terrain != "r" and terrain != "~" and terrain != "t" and not blocked
			if terrain == "~":
				_water[t] = true
			else:
				if terrain == ".":
					_grass[t] = true
				elif terrain == "," or terrain == "c":
					_path.append(t)
				if not blocked:
					var dec := PlaceholderTiles.decor_for(t, terrain)
					if dec != PlaceholderTiles.DECOR_NONE:
						_decor.append([t, dec])

	_build_shore_overlay()
	_build_fringe_overlay()
	_build_decor_overlay()
	_build_water_overlay()

	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for t in _walkable:
		if not _walkable[t]:
			_astar.set_point_solid(t, true)

	if not gate_points.is_empty() or not shortcut_points.is_empty() or not portal_locks.is_empty():
		UnlockSystem.unlock_added.connect(_on_unlock_added)

	# Spawn-tabell: slumpmässiga tiles för varje entry
	var spawn_table: Array = data.get("spawn_table", [])
	if not spawn_table.is_empty():
		_fill_spawn_table(spawn_table)

	for t in portals:
		if entrance_points.has(t):
			_add_door_marker(t)
		elif stair_points.has(t):
			_add_stair_marker(t, stair_points[t]["up"])
		else:
			_add_portal_marker(t)
	for t in shortcut_points:
		if not UnlockSystem.is_unlocked(shortcut_points[t]):
			_add_shortcut_marker(t)
	for t in dungeon_entrances:
		_add_entrance_marker(t)

## Lägger ett skum-overlay-lager ovanpå varje vatten-tile som gränsar till
## land. Rent visuellt — påverkar varken walkability eller astar. Lagret läggs
## direkt efter bas-tilemap så det ritas ovanpå marken men under figurerna.
func _build_shore_overlay() -> void:
	if _water.is_empty():
		return
	var overlay := TileMapLayer.new()
	overlay.tile_set = PlaceholderTiles.build_overlay()
	add_child(overlay)
	move_child(overlay, tilemap.get_index() + 1)
	for t: Vector2i in _water:
		var mask := 0
		if _is_land(t + Vector2i(0, -1)): mask |= PlaceholderTiles.FOAM_N
		if _is_land(t + Vector2i(1, 0)):  mask |= PlaceholderTiles.FOAM_E
		if _is_land(t + Vector2i(0, 1)):  mask |= PlaceholderTiles.FOAM_S
		if _is_land(t + Vector2i(-1, 0)): mask |= PlaceholderTiles.FOAM_W
		if mask > 0:
			overlay.set_cell(t, 0, Vector2i(mask, 0))

## Lägger en gräsfrans på väg-/jordrutor som gränsar till gräs, så den hårda
## kanten mjukas upp. Eget overlay-lager mellan skum och dekor. Grid orört.
func _build_fringe_overlay() -> void:
	if _path.is_empty() or _grass.is_empty():
		return
	var layer := TileMapLayer.new()
	layer.tile_set = PlaceholderTiles.build_fringe()
	add_child(layer)
	for t: Vector2i in _path:
		var mask := 0
		if _grass.has(t + Vector2i(0, -1)): mask |= PlaceholderTiles.FOAM_N
		if _grass.has(t + Vector2i(1, 0)):  mask |= PlaceholderTiles.FOAM_E
		if _grass.has(t + Vector2i(0, 1)):  mask |= PlaceholderTiles.FOAM_S
		if _grass.has(t + Vector2i(-1, 0)): mask |= PlaceholderTiles.FOAM_W
		if mask > 0:
			layer.set_cell(t, 0, Vector2i(mask, 0))

## Lägger glesa naturdetaljer (blommor/tuvor/sten) ovanpå marken. Eget lager,
## ritas efter skummet → ovanpå mark & strand men under figurer. Rent visuellt.
func _build_decor_overlay() -> void:
	if _decor.is_empty():
		return
	var layer := TileMapLayer.new()
	layer.tile_set = PlaceholderTiles.build_decor()
	add_child(layer)
	for d in _decor:
		layer.set_cell(d[0], 0, Vector2i(int(d[1]), 0))

## Lägger ett animerat shimmer-lager ovanpå vattenrutorna (täcker bas-vattnet,
## under skummet). Drivs av en shader → levande ljusvågor. Återanvänder bas-
## atlasen. Läggs direkt ovanför bas-tilemap så skum/frans/dekor hamnar ovanpå.
func _build_water_overlay() -> void:
	if _water.is_empty():
		return
	var layer := TileMapLayer.new()
	layer.tile_set = tilemap.tile_set
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/water.gdshader")
	layer.material = mat
	add_child(layer)
	move_child(layer, tilemap.get_index() + 1)   # precis ovanför marken
	for t: Vector2i in _water:
		layer.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN["~"], PlaceholderTiles.variant_for(t)))

## En tile räknas som "land" mot skummet om den är inom kartan och inte vatten.
## Kartkanten (utanför) ger inget skum så vattnet inte ramas in vid världsranden.
func _is_land(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= grid_size.x or t.y >= grid_size.y:
		return false
	return not _water.has(t)

## Väljer slumpmässiga, fria walkable tiles för spawn_table-poster.
## Undviker player_start och befintliga spawn_points.
func _fill_spawn_table(table: Array) -> void:
	# Samla kandidat-tiles: walkable, inte player_start, minst 3 tiles bort
	var candidates: Array[Vector2i] = []
	for t: Vector2i in _walkable:
		if not _walkable[t]:
			continue
		if t == player_start:
			continue
		var dx := absi(t.x - player_start.x)
		var dy := absi(t.y - player_start.y)
		if maxi(dx, dy) < 4:   # Chebyshev-avstånd från start
			continue
		candidates.append(t)
	candidates.shuffle()

	# Reservera tiles som redan används av legend-spawn_points
	var used: Array[Vector2i] = []
	for sp in spawn_points:
		used.append(sp["tile"])

	for entry in table:
		var count := int(entry.get("count", 1))
		var mname := String(entry["monster"])
		var respawn := float(entry.get("respawn", 30.0))
		var placed := 0
		for t: Vector2i in candidates:
			if placed >= count:
				break
			if used.has(t):
				continue
			spawn_points.append({"tile": t, "monster": mname, "respawn": respawn})
			used.append(t)
			placed += 1

## Loopande puls (scale) som signalerar att en ruta går att interagera med.
func _pulse_marker(node: Node2D, lo := 1.0, hi := 1.25, dur := 0.7) -> void:
	if not node.is_inside_tree():
		return
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(hi, hi), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2(lo, lo), dur).set_trans(Tween.TRANS_SINE)

func _add_portal_marker(t: Vector2i) -> void:
	for n in _portal_marker_nodes.get(t, []):
		n.queue_free()
	var locked := portal_locks.has(t)
	var c := Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	var swirl := Polygon2D.new()
	swirl.polygon = PackedVector2Array([
		Vector2(0, -11), Vector2(11, 0), Vector2(0, 11), Vector2(-11, 0)])
	swirl.color = Color(0.45, 0.45, 0.5) if locked else Color(0.62, 0.38, 0.9)
	swirl.position = c
	add_child(swirl)
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])
	inner.color = Color(0.6, 0.6, 0.65) if locked else Color(0.85, 0.72, 1.0)
	inner.position = c
	add_child(inner)
	var plight: PointLight2D = null
	if not locked:
		_pulse_marker(inner)   # levande glow → "gå hit"
		# Magiskt portalsken: en pulserande ljusö som lyser i mörkret.
		plight = Lighting.make_light(Color(0.62, 0.40, 0.95), 0.25, 64.0)
		plight.position = c
		add_child(plight)
		var ltw := plight.create_tween().set_loops()
		ltw.tween_property(plight, "energy", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
		ltw.tween_property(plight, "energy", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	var lbl := Label.new()
	lbl.text = "Låst: %s" % UnlockSystem.display_name(portal_locks[t]) if locked \
		else "→ " + _zone_display_name(String(portals[t]))
	lbl.position = c + Vector2(-64, -32)
	lbl.custom_minimum_size = Vector2(128, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.7, 0.7, 0.7) if locked else Color(0.88, 0.78, 1.0)
	add_child(lbl)
	_portal_marker_nodes[t] = [swirl, inner, lbl]
	if plight != null:
		_portal_marker_nodes[t].append(plight)

func _add_entrance_marker(t: Vector2i) -> void:
	var c := Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	var hole := Polygon2D.new()   # mörk trappa ner
	hole.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(8, 10), Vector2(-8, 10)])
	hole.color = Color(0.08, 0.07, 0.1)
	hole.position = c
	add_child(hole)
	var step := Polygon2D.new()
	step.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4), Vector2(6, 2), Vector2(-6, 2)])
	step.color = Color(0.25, 0.23, 0.28)
	step.position = c
	add_child(step)
	_pulse_marker(step, 1.0, 1.18, 0.9)
	var lbl := Label.new()
	lbl.text = "Ner: " + DungeonGen.theme_name(dungeon_entrances[t])
	lbl.position = c + Vector2(-64, -32)
	lbl.custom_minimum_size = Vector2(128, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.75, 0.7, 0.8)
	add_child(lbl)

func _add_door_marker(t: Vector2i) -> void:
	## Ritar en brun dörröppning (husportal).
	var c := Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	# Ytterkarm
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([
		Vector2(-8, -11), Vector2(8, -11),
		Vector2(8,  9),  Vector2(5,  9),
		Vector2(5, -8),  Vector2(-5, -8),
		Vector2(-5,  9), Vector2(-8,  9)])
	frame.color = Color(0.30, 0.16, 0.05)
	frame.position = c
	add_child(frame)
	# Dörrpanel
	var panel := Polygon2D.new()
	panel.polygon = PackedVector2Array([
		Vector2(-5, -8), Vector2(5, -8), Vector2(5, 9), Vector2(-5, 9)])
	panel.color = Color(0.52, 0.30, 0.10)
	panel.position = c
	add_child(panel)
	# Handtag
	var knob := Polygon2D.new()
	knob.polygon = PackedVector2Array([
		Vector2(2, -1), Vector2(4, -1), Vector2(4, 1), Vector2(2, 1)])
	knob.color = Color(0.85, 0.72, 0.20)
	knob.position = c
	add_child(knob)
	# Pulserande ledstjärna ovanför dörren — drar ögat hit (som portaler/trappor)
	var beacon := Polygon2D.new()
	beacon.polygon = PackedVector2Array([
		Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	beacon.color = Color(1.0, 0.85, 0.35)
	beacon.position = c + Vector2(0, -20)
	add_child(beacon)
	_pulse_marker(beacon, 0.8, 1.3, 0.8)
	# Namnskylt på husdörren så den går att hitta (saknades tidigare)
	var lbl := Label.new()
	lbl.text = _zone_display_name(String(portals[t]))
	lbl.position = c + Vector2(-64, -44)
	lbl.custom_minimum_size = Vector2(128, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(1.0, 0.88, 0.55)
	add_child(lbl)

func _add_stair_marker(t: Vector2i, going_up: bool) -> void:
	## Ritar en trappil (upp eller ned).
	var c := Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	var arrow := Polygon2D.new()
	if going_up:
		arrow.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(7, -2), Vector2(3, -2),
			Vector2(3, 8),   Vector2(-3, 8), Vector2(-3, -2),
			Vector2(-7, -2)])
	else:
		arrow.polygon = PackedVector2Array([
			Vector2(0, 10),  Vector2(7, 2),  Vector2(3, 2),
			Vector2(3, -8),  Vector2(-3, -8),Vector2(-3, 2),
			Vector2(-7, 2)])
	arrow.color = Color(0.80, 0.74, 0.48)
	arrow.position = c
	add_child(arrow)

func _add_shortcut_marker(t: Vector2i) -> void:
	var d := Polygon2D.new()
	d.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)])
	d.color = Color(0.8, 0.7, 0.4)
	d.position = Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	add_child(d)
	_shortcut_markers[t] = d

func _zone_display_name(id: String) -> String:
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	return String(d["name"]) if d is Dictionary and d.has("name") else id

func _on_unlock_added(id: String) -> void:
	for t in gate_points:
		if gate_points[t] == id:
			_open_tile(t)
	for t in shortcut_points:
		if shortcut_points[t] == id:
			_open_tile(t)
			if _shortcut_markers.has(t):
				_shortcut_markers[t].queue_free()
				_shortcut_markers.erase(t)
	for t in portal_locks.keys():
		if portal_locks[t] == id:
			portal_locks.erase(t)
			_add_portal_marker(t)

func _open_tile(t: Vector2i) -> void:
	tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[_gate_terrain[t]], PlaceholderTiles.variant_for(t)))
	_walkable[t] = true
	_astar.set_point_solid(t, false)

## Unlock-id om tile är en låst gate/genväg, annars "".
func lock_at(t: Vector2i) -> String:
	if gate_points.has(t) and not UnlockSystem.is_unlocked(gate_points[t]):
		return gate_points[t]
	if shortcut_points.has(t) and not UnlockSystem.is_unlocked(shortcut_points[t]):
		return shortcut_points[t]
	return ""

func is_walkable(t: Vector2i) -> bool:
	return _walkable.get(t, false)

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to):
		return []
	return _astar.get_id_path(from, to)

func find_path_adjacent(from: Vector2i, to: Vector2i) -> Array:
	var best: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n: Vector2i = to + d
		if not is_walkable(n):
			continue
		if n == from:
			return [from]
		var p := find_path(from, n)
		if p.size() > 0 and (best.is_empty() or p.size() < best.size()):
			best = p
	return best

static func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)

static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE).floor())

## Monster-kollision: registrera ett monster på en tile.
func occupy(t: Vector2i, monster: Node) -> void:
	_monster_tiles[t] = monster

## Monster-kollision: frigör en tile när monstret lämnar eller dör.
func vacate(t: Vector2i) -> void:
	_monster_tiles.erase(t)

## Returnerar true om en annan enhet redan står på tile t.
func is_occupied(t: Vector2i) -> bool:
	return _monster_tiles.has(t)
