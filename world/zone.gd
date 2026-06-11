extends Node2D
## En spelzon: bygger TileMapLayer från data/zones/<id>.json,
## äger walkability-grid, AStarGrid2D, portaler och spawnpunkter.

const TILE := 32

var zone_id := ""
var zone_name := ""
var grid_size := Vector2i.ZERO
var player_start := Vector2i.ZERO
var portals: Dictionary = {}        # Vector2i -> mål-zon-id
var spawn_points: Array = []        # [{tile, monster, respawn}]
var _walkable: Dictionary = {}      # Vector2i -> bool
var _astar := AStarGrid2D.new()
var tilemap: TileMapLayer

func build(id: String) -> void:
	zone_id = id
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	zone_name = data["name"]
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
			match ch:
				"P":
					player_start = t
					terrain = "."
				_:
					if legend.has(ch):
						var e: Dictionary = legend[ch]
						if e["type"] == "portal":
							portals[t] = e["to"]
						elif e["type"] == "spawn":
							spawn_points.append({"tile": t, "monster": e["monster"], "respawn": float(e["respawn"])})
						terrain = "," if zone_id != "town" else "."
			if not PlaceholderTiles.TERRAIN.has(terrain):
				terrain = "."
			tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[terrain], 0))
			_walkable[t] = terrain != "W" and terrain != "~"

	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for t in _walkable:
		if not _walkable[t]:
			_astar.set_point_solid(t, true)

func is_walkable(t: Vector2i) -> bool:
	return _walkable.get(t, false)

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to):
		return []
	return _astar.get_id_path(from, to)

static func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)

static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE).floor())
