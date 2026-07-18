class_name ZoneModel
extends RefCounted
## Ren simuleringsmodell för en spelzon: terränggrid, walkability, AStar,
## portaler, spawnpunkter, gates/genvägar och monsterkollision.
##
## Ingen rendering, inga noder — helt headless-testbar och delbar mellan
## 2D-vyn (zone.gd) och en framtida 3D-vy. Vyer prenumererar på signalerna
## för att rita om öppnade tiles/markers.
##
## Beroenden: UnlockSystem (ren autoload) och PlaceholderTiles.TERRAIN
## (statisk datatabell över giltiga terrängtecken — inte rendering).

## Visningsnamn för en zon (läses ur zonfilen, cachas per körning) — delas av
## 2D- och 3D-vyns skyltar. Saknad fil (t.ex. genererade dungeons) ger id:t.
static var _zone_names: Dictionary = {}
static func zone_display_name(id: String) -> String:
	if _zone_names.has(id):
		return _zone_names[id]
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	var n := String(d["name"]) if d is Dictionary and d.has("name") else id
	_zone_names[id] = n
	return n

signal tile_opened(t: Vector2i, terrain_ch: String)   # gate/genväg öppnad
signal shortcut_opened(t: Vector2i)                   # genväg öppnad (marker bort)
signal portal_unlocked(t: Vector2i)                   # låst portal upplåst

var zone_id := ""
var zone_name := ""
var dungeon_theme := ""            # satt för genererade dungeons
var weather := "clear"             # zonens deklarerade väder (rått zon-värde,
                                   # inkl. "dynamic" — vyer löser upp via Weather.resolve)
var grid_size := Vector2i.ZERO
var player_start := Vector2i.ZERO
var terrain: Dictionary = {}       # Vector2i -> terrängtecken (validerat)
var blocked: Dictionary = {}       # Vector2i -> true (legend-blockerad: möbel/npc/nod ...)
var portals: Dictionary = {}       # Vector2i -> mål-zon-id
var spawn_points: Array = []       # [{tile, monster, respawn}]
var node_points: Array = []        # [{tile, node}]
var station_points: Array = []     # [{tile, station}]
var shop_points: Array = []        # [tile]
var bank_points: Array = []        # [tile]
var taskmaster_points: Array = []  # [tile]
var spell_teacher_points: Array = []  # [tile]
var chest_points: Array = []       # [tile] (dungeons)
var dungeon_entrances: Dictionary = {}  # Vector2i -> tema-id
var gate_points: Dictionary = {}   # Vector2i -> unlock-id
var shortcut_points: Dictionary = {}  # Vector2i -> unlock-id (bump-genvägar)
var portal_locks: Dictionary = {}     # Vector2i -> unlock-id (låsta portaler)
var entrance_points: Dictionary = {}  # Vector2i -> zon-id (husportaler, dörrar)
var stair_points: Dictionary = {}     # Vector2i -> {"to": zon-id, "up": bool}
var _gate_terrain: Dictionary = {} # Vector2i -> terräng när gaten/genvägen öppnats
var _walkable: Dictionary = {}     # Vector2i -> bool
var _monster_tiles: Dictionary = {}   # Vector2i -> Monster (kollisionskarta)
var _astar := AStarGrid2D.new()

## Tolkar zondata (samma format som data/zones/*.json och dungeon_generator).
func parse(data: Dictionary, id: String) -> void:
	zone_id = id
	zone_name = data["name"]
	dungeon_theme = String(data.get("theme", ""))
	weather = String(data.get("weather", "clear"))
	var rows: Array = data["tiles"]
	var legend: Dictionary = data.get("legend", {})
	grid_size = Vector2i(rows[0].length(), rows.size())
	for y in rows.size():
		assert(rows[y].length() == grid_size.x,
			"%s rad %d: längd %d, förväntade %d" % [id, y, rows[y].length(), grid_size.x])

	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var t := Vector2i(x, y)
			var ter := ch
			var blk := false
			match ch:
				"P":
					player_start = t
					ter = "."
				_:
					if legend.has(ch):
						var e: Dictionary = legend[ch]
						var default_terrain := "," if zone_id != "town" else "."
						ter = String(e.get("terrain", default_terrain))
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
								blk = true
							"station":
								station_points.append({"tile": t, "station": e["station"]})
								blk = true
							"decoration":
								blk = true   # blockerar rörelse, öppnar ingen panel
							"shop":
								shop_points.append(t)
								blk = true
							"bank":
								bank_points.append(t)
								blk = true
							"taskmaster":
								taskmaster_points.append(t)
								blk = true
							"spell_teacher":
								spell_teacher_points.append(t)
								blk = true
							"chest":
								chest_points.append(t)
								blk = true
							"dungeon_entrance":
								dungeon_entrances[t] = String(e["theme"])
							"gate":
								var uid := String(e["unlock"])
								gate_points[t] = uid
								_gate_terrain[t] = ter if PlaceholderTiles.TERRAIN.has(ter) else ","
								if not UnlockSystem.is_unlocked(uid):
									blk = true
									ter = "W"   # rasmassor tills gaten öppnas
							"shortcut":
								var suid := String(e["unlock"])
								shortcut_points[t] = suid
								_gate_terrain[t] = ter if PlaceholderTiles.TERRAIN.has(ter) else ","
								if not UnlockSystem.is_unlocked(suid):
									blk = true
									ter = String(e.get("locked_terrain", "W"))
			if not PlaceholderTiles.TERRAIN.has(ter):
				ter = "."
			terrain[t] = ter
			if blk:
				blocked[t] = true
			_walkable[t] = ter != "W" and ter != "w" and ter != "r" and ter != "~" and ter != "t" and not blk

	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for t in _walkable:
		if not _walkable[t]:
			_astar.set_point_solid(t, true)

	# Spawn-tabell: slumpmässiga tiles för varje entry
	var spawn_table: Array = data.get("spawn_table", [])
	if not spawn_table.is_empty():
		_fill_spawn_table(spawn_table)

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

## Reagerar på ett nytt unlock: öppnar gates/genvägar och låser upp portaler.
## Vyn kopplar UnlockSystem.unlock_added hit och ritar om via signalerna.
func apply_unlock(id: String) -> void:
	for t in gate_points:
		if gate_points[t] == id:
			_open_tile(t)
	for t in shortcut_points:
		if shortcut_points[t] == id:
			_open_tile(t)
			shortcut_opened.emit(t)
	for t in portal_locks.keys():
		if portal_locks[t] == id:
			portal_locks.erase(t)
			portal_unlocked.emit(t)

func _open_tile(t: Vector2i) -> void:
	var ter: String = _gate_terrain.get(t, ",")
	terrain[t] = ter
	blocked.erase(t)
	_walkable[t] = true
	_astar.set_point_solid(t, false)
	tile_opened.emit(t, ter)

## Unlock-id om tile är en låst gate/genväg, annars "".
func lock_at(t: Vector2i) -> String:
	if gate_points.has(t) and not UnlockSystem.is_unlocked(gate_points[t]):
		return gate_points[t]
	if shortcut_points.has(t) and not UnlockSystem.is_unlocked(shortcut_points[t]):
		return shortcut_points[t]
	return ""

func is_walkable(t: Vector2i) -> bool:
	return _walkable.get(t, false)

## Fri siktlinje mellan två tiles (avståndsattacker): sant när alla
## MELLANLIGGANDE tiles på Bresenham-linjen är gångbara — väggar/träd/vatten
## blockerar skottet. Ändpunkterna prövas inte (skytt och mål står ju där)
## och enheter skymmer inte varandra.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var x := from.x
	var y := from.y
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if to.x > from.x else -1
	var sy := 1 if to.y > from.y else -1
	var err := dx + dy
	while x != to.x or y != to.y:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if (x != to.x or y != to.y) and not is_walkable(Vector2i(x, y)):
			return false
	return true

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

## Monster-kollision: registrera en enhet (nod eller sim) på en tile.
func occupy(t: Vector2i, occupant: Object) -> void:
	_monster_tiles[t] = occupant

## Monster-kollision: frigör en tile när monstret lämnar eller dör.
func vacate(t: Vector2i) -> void:
	_monster_tiles.erase(t)

## Returnerar true om en annan enhet redan står på tile t.
func is_occupied(t: Vector2i) -> bool:
	return _monster_tiles.has(t)
