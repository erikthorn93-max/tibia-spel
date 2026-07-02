extends Node2D
## Vy för en spelzon: ritar TileMapLayer + overlays + markers utifrån en
## ZoneModel. All spellogik (walkability, AStar, portaler, spawns, kollision)
## bor i modellen — den här noden är utbytbar mot en 3D-vy utan att logiken
## rörs. Publika fält/metoder delegerar till modellen så befintliga anropare
## (world.gd, entities, ui) fungerar oförändrat.

const TILE := 32
const DungeonGen = preload("res://world/dungeon_generator.gd")
const Weather = preload("res://ui/weather.gd")
const Lighting = preload("res://world/lighting.gd")

var model: ZoneModel
var weather := "clear"   # "clear" | "rain" | "fog" | "snow" — driver väder-overlay
var tilemap: TileMapLayer
var _shortcut_markers: Dictionary = {}    # Vector2i -> Node2D
var _portal_marker_nodes: Dictionary = {} # Vector2i -> Array[Node]

# ── Delegation till modellen (bakåtkompatibelt API) ───────────────────────────
var zone_id: String:
	get: return model.zone_id
var zone_name: String:
	get: return model.zone_name
var dungeon_theme: String:
	get: return model.dungeon_theme
var grid_size: Vector2i:
	get: return model.grid_size
var player_start: Vector2i:
	get: return model.player_start
var portals: Dictionary:
	get: return model.portals
var spawn_points: Array:
	get: return model.spawn_points
var node_points: Array:
	get: return model.node_points
var station_points: Array:
	get: return model.station_points
var shop_points: Array:
	get: return model.shop_points
var bank_points: Array:
	get: return model.bank_points
var taskmaster_points: Array:
	get: return model.taskmaster_points
var spell_teacher_points: Array:
	get: return model.spell_teacher_points
var chest_points: Array:
	get: return model.chest_points
var dungeon_entrances: Dictionary:
	get: return model.dungeon_entrances
var gate_points: Dictionary:
	get: return model.gate_points
var shortcut_points: Dictionary:
	get: return model.shortcut_points
var portal_locks: Dictionary:
	get: return model.portal_locks
var entrance_points: Dictionary:
	get: return model.entrance_points
var stair_points: Dictionary:
	get: return model.stair_points
var _walkable: Dictionary:   # minimap itererar denna
	get: return model._walkable

func lock_at(t: Vector2i) -> String: return model.lock_at(t)
func is_walkable(t: Vector2i) -> bool: return model.is_walkable(t)
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]: return model.find_path(from, to)
func find_path_adjacent(from: Vector2i, to: Vector2i) -> Array: return model.find_path_adjacent(from, to)
func occupy(t: Vector2i, monster: Node) -> void: model.occupy(t, monster)
func vacate(t: Vector2i) -> void: model.vacate(t)
func is_occupied(t: Vector2i) -> bool: return model.is_occupied(t)

static func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)

static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE).floor())

# ── Bygge ─────────────────────────────────────────────────────────────────────
func build(id: String) -> void:
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	build_from_data(JSON.parse_string(f.get_as_text()), id)

func build_from_data(data: Dictionary, id: String) -> void:
	model = ZoneModel.new()
	model.parse(data, id)
	weather = Weather.from_zone_data(data)
	model.tile_opened.connect(_on_tile_opened)
	model.shortcut_opened.connect(_on_shortcut_opened)
	model.portal_unlocked.connect(_on_portal_unlocked)

	_build_tilemap()
	_build_shore_overlay()
	_build_fringe_overlay()
	_build_decor_overlay()
	_build_water_overlay()

	# Unlock-lyssnare kopplas via noden (auto-bortkoppling när zonen frigörs).
	if not model.gate_points.is_empty() or not model.shortcut_points.is_empty() \
			or not model.portal_locks.is_empty():
		UnlockSystem.unlock_added.connect(_on_unlock_added)

	for t in model.portals:
		if model.entrance_points.has(t):
			_add_door_marker(t)
		elif model.stair_points.has(t):
			_add_stair_marker(t, model.stair_points[t]["up"])
		else:
			_add_portal_marker(t)
	for t in model.shortcut_points:
		if not UnlockSystem.is_unlocked(model.shortcut_points[t]):
			_add_shortcut_marker(t)
	for t in model.dungeon_entrances:
		_add_entrance_marker(t)

func _build_tilemap() -> void:
	tilemap = TileMapLayer.new()
	tilemap.tile_set = PlaceholderTiles.build()
	add_child(tilemap)
	for t: Vector2i in model.terrain:
		tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[model.terrain[t]], PlaceholderTiles.variant_for(t)))

# ── Överlägg (härledda ur modellens terräng — rent visuella) ──────────────────
func _is_water(t: Vector2i) -> bool:
	return model.terrain.get(t, "") == "~"

## Lägger ett skum-overlay-lager ovanpå varje vatten-tile som gränsar till
## land. Rent visuellt — påverkar varken walkability eller astar. Lagret läggs
## direkt efter bas-tilemap så det ritas ovanpå marken men under figurerna.
func _build_shore_overlay() -> void:
	var any := false
	var overlay := TileMapLayer.new()
	overlay.tile_set = PlaceholderTiles.build_overlay()
	for t: Vector2i in model.terrain:
		if not _is_water(t):
			continue
		var mask := 0
		if _is_land(t + Vector2i(0, -1)): mask |= PlaceholderTiles.FOAM_N
		if _is_land(t + Vector2i(1, 0)):  mask |= PlaceholderTiles.FOAM_E
		if _is_land(t + Vector2i(0, 1)):  mask |= PlaceholderTiles.FOAM_S
		if _is_land(t + Vector2i(-1, 0)): mask |= PlaceholderTiles.FOAM_W
		if mask > 0:
			overlay.set_cell(t, 0, Vector2i(mask, 0))
			any = true
	if any:
		add_child(overlay)
		move_child(overlay, tilemap.get_index() + 1)
	else:
		overlay.free()

## Lägger en gräsfrans på väg-/jordrutor som gränsar till gräs, så den hårda
## kanten mjukas upp. Eget overlay-lager mellan skum och dekor. Grid orört.
func _build_fringe_overlay() -> void:
	var any := false
	var layer := TileMapLayer.new()
	layer.tile_set = PlaceholderTiles.build_fringe()
	for t: Vector2i in model.terrain:
		var ch: String = model.terrain[t]
		if ch != "," and ch != "c":
			continue
		var mask := 0
		if model.terrain.get(t + Vector2i(0, -1), "") == ".": mask |= PlaceholderTiles.FOAM_N
		if model.terrain.get(t + Vector2i(1, 0), "") == ".":  mask |= PlaceholderTiles.FOAM_E
		if model.terrain.get(t + Vector2i(0, 1), "") == ".":  mask |= PlaceholderTiles.FOAM_S
		if model.terrain.get(t + Vector2i(-1, 0), "") == ".": mask |= PlaceholderTiles.FOAM_W
		if mask > 0:
			layer.set_cell(t, 0, Vector2i(mask, 0))
			any = true
	if any:
		add_child(layer)
	else:
		layer.free()

## Lägger glesa naturdetaljer (blommor/tuvor/sten) ovanpå marken. Eget lager,
## ritas efter skummet → ovanpå mark & strand men under figurer. Rent visuellt.
func _build_decor_overlay() -> void:
	var any := false
	var layer := TileMapLayer.new()
	layer.tile_set = PlaceholderTiles.build_decor()
	for t: Vector2i in model.terrain:
		if _is_water(t) or model.blocked.has(t):
			continue
		var dec := PlaceholderTiles.decor_for(t, model.terrain[t])
		if dec != PlaceholderTiles.DECOR_NONE:
			layer.set_cell(t, 0, Vector2i(int(dec), 0))
			any = true
	if any:
		add_child(layer)
	else:
		layer.free()

## Lägger ett animerat shimmer-lager ovanpå vattenrutorna (täcker bas-vattnet,
## under skummet). Drivs av en shader → levande ljusvågor. Återanvänder bas-
## atlasen. Läggs direkt ovanför bas-tilemap så skum/frans/dekor hamnar ovanpå.
func _build_water_overlay() -> void:
	var any := false
	var layer := TileMapLayer.new()
	layer.tile_set = tilemap.tile_set
	for t: Vector2i in model.terrain:
		if _is_water(t):
			layer.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN["~"], PlaceholderTiles.variant_for(t)))
			any = true
	if not any:
		layer.free()
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/water.gdshader")
	layer.material = mat
	add_child(layer)
	move_child(layer, tilemap.get_index() + 1)   # precis ovanför marken

## En tile räknas som "land" mot skummet om den är inom kartan och inte vatten.
## Kartkanten (utanför) ger inget skum så vattnet inte ramas in vid världsranden.
func _is_land(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= model.grid_size.x or t.y >= model.grid_size.y:
		return false
	return not _is_water(t)

# ── Markers ───────────────────────────────────────────────────────────────────
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
	var locked := model.portal_locks.has(t)
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
	lbl.text = "Låst: %s" % UnlockSystem.display_name(model.portal_locks[t]) if locked \
		else "→ " + _zone_display_name(String(model.portals[t]))
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
	lbl.text = "Ner: " + DungeonGen.theme_name(model.dungeon_entrances[t])
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
	lbl.text = _zone_display_name(String(model.portals[t]))
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

# ── Reaktioner på modellens signaler ──────────────────────────────────────────
func _on_unlock_added(id: String) -> void:
	model.apply_unlock(id)

func _on_tile_opened(t: Vector2i, terrain_ch: String) -> void:
	tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[terrain_ch], PlaceholderTiles.variant_for(t)))

func _on_shortcut_opened(t: Vector2i) -> void:
	if _shortcut_markers.has(t):
		_shortcut_markers[t].queue_free()
		_shortcut_markers.erase(t)

func _on_portal_unlocked(t: Vector2i) -> void:
	_add_portal_marker(t)
