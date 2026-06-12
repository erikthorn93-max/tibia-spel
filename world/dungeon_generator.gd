class_name DungeonGenerator
## Seedad dungeongenerator: rum + MST-korridorer. Producerar samma
## Dictionary-struktur som data/zones/*.json (+ "theme"/"exit_zone").
## Ren statisk logik — GUT-testbar utan scenträd.

const GRID_W := 44
const GRID_H := 32
const MAX_ROOMS := 10
const MIN_ROOMS := 6
const MAX_SPAWNS := 30
const SPAWN_CHARS := "abcdef"
const NODE_CHARS := "jk"

static var _themes_cache: Dictionary = {}

static func themes() -> Dictionary:
	if _themes_cache.is_empty():
		var f := FileAccess.open("res://data/dungeon_themes.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f else null
		_themes_cache = parsed if parsed is Dictionary else {}
	return _themes_cache

static func theme_name(theme_id: String) -> String:
	return String(themes().get(theme_id, {}).get("name", theme_id))

static func generate(theme_id: String, dseed: int) -> Dictionary:
	var th: Dictionary = themes()[theme_id]
	var floor_ch := String(th["floor_terrain"])
	var rng := RandomNumberGenerator.new()
	rng.seed = dseed

	# --- rum (icke-överlappande, 1 tiles marginal) ---
	var rooms: Array = []   # Rect2i
	var attempts := 0
	while rooms.size() < MAX_ROOMS and attempts < 300:
		attempts += 1
		var w := rng.randi_range(5, 9)
		var h := rng.randi_range(4, 7)
		var r := Rect2i(rng.randi_range(1, GRID_W - w - 1), rng.randi_range(1, GRID_H - h - 1), w, h)
		var ok := true
		for o in rooms:
			if r.grow(1).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)
	assert(rooms.size() >= MIN_ROOMS, "för få rum (seed %d)" % dseed)

	# --- grid: allt mur, carva rum ---
	var grid: Array = []
	for y in GRID_H:
		var row: Array = []
		row.resize(GRID_W)
		row.fill("W")
		grid.append(row)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[y][x] = floor_ch

	# --- korridorer: MST-stil (närmaste kopplade rum) + 2 extra loopar ---
	var edges: Dictionary = {}   # rumsindex -> Array[rumsindex]
	for i in rooms.size():
		edges[i] = []
	var connected := [0]
	for i in range(1, rooms.size()):
		var best := -1
		var best_d := 1 << 30
		for c in connected:
			var d := _center(rooms[i]).distance_squared_to(_center(rooms[c]))
			if d < best_d:
				best_d = int(d)
				best = c
		_carve_corridor(grid, _center_i(rooms[i]), _center_i(rooms[best]), floor_ch, rng)
		edges[i].append(best)
		edges[best].append(i)
		connected.append(i)
	for _extra in 2:
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if a != b and not edges[a].has(b):
			_carve_corridor(grid, _center_i(rooms[a]), _center_i(rooms[b]), floor_ch, rng)
			edges[a].append(b)
			edges[b].append(a)

	# --- ingångsrum (0) och slutrum (störst grafavstånd) ---
	var dist := _bfs_room_distances(edges, rooms.size())
	var far_room := 0
	for i in rooms.size():
		if dist[i] > dist[far_room]:
			far_room = i

	var entrance := _center_i(rooms[0])
	grid[entrance.y][entrance.x] = "P"
	grid[entrance.y][entrance.x + 1] = "0"   # exit-portal intill starten
	var chest := _center_i(rooms[far_room])
	grid[chest.y][chest.x] = "C"

	# --- spawns: 1–3 per rum (ej ingångsrummet), viktade ur poolen ---
	var pool: Array = []   # monsterindex viktat
	for mi in th["monsters"].size():
		for _w in int(th["monsters"][mi][1]):
			pool.append(mi)
	var used_monsters := {}
	var spawn_total := 0
	for i in range(1, rooms.size()):
		if spawn_total >= MAX_SPAWNS:
			break
		for _s in rng.randi_range(1, 3):
			if spawn_total >= MAX_SPAWNS:
				break
			var t := _random_floor_in_room(rooms[i], grid, floor_ch, rng)
			if t.x < 0:
				continue
			var mi: int = pool[rng.randi_range(0, pool.size() - 1)]
			grid[t.y][t.x] = SPAWN_CHARS[mi]
			used_monsters[mi] = true
			spawn_total += 1

	# --- gather-noder: 0–2 st ---
	var node_defs: Array = th.get("nodes", [])
	var used_nodes := {}
	if not node_defs.is_empty():
		for _n in rng.randi_range(0, 2):
			var ri := rng.randi_range(1, rooms.size() - 1)
			var t := _random_floor_in_room(rooms[ri], grid, floor_ch, rng)
			if t.x < 0:
				continue
			var ni := rng.randi_range(0, node_defs.size() - 1)
			grid[t.y][t.x] = NODE_CHARS[ni]
			used_nodes[ni] = true

	# --- legend ---
	var legend := {
		"0": {"type": "portal", "to": String(th["exit_zone"]), "terrain": floor_ch},
		"C": {"type": "chest", "terrain": floor_ch},
	}
	for mi in used_monsters:
		legend[SPAWN_CHARS[mi]] = {"type": "spawn", "monster": String(th["monsters"][mi][0]),
			"respawn": 9999.0, "terrain": floor_ch}   # ingen respawn i efemära dungeons
	for ni in used_nodes:
		legend[NODE_CHARS[ni]] = {"type": "node", "node": String(node_defs[ni]), "terrain": floor_ch}

	var tiles: Array = []
	for y in GRID_H:
		tiles.append("".join(grid[y]))

	return {"name": theme_name(theme_id), "tiles": tiles, "legend": legend,
		"theme": theme_id, "exit_zone": String(th["exit_zone"])}

static func _center(r: Rect2i) -> Vector2:
	return Vector2(r.position) + Vector2(r.size) / 2.0

static func _center_i(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2

static func _carve_corridor(grid: Array, from: Vector2i, to: Vector2i, floor_ch: String, rng: RandomNumberGenerator) -> void:
	var horiz_first := rng.randf() < 0.5
	var mid := Vector2i(to.x, from.y) if horiz_first else Vector2i(from.x, to.y)
	for t in _line(from, mid) + _line(mid, to):
		if grid[t.y][t.x] == "W":
			grid[t.y][t.x] = floor_ch

static func _line(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var d := (to - from).sign()
	var t := from
	out.append(t)
	while t != to:
		t += d
		out.append(t)
	return out

static func _bfs_room_distances(edges: Dictionary, n: int) -> Array:
	var dist: Array = []
	dist.resize(n)
	dist.fill(-1)
	dist[0] = 0
	var queue := [0]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in edges[i]:
			if dist[j] < 0:
				dist[j] = dist[i] + 1
				queue.append(j)
	return dist

static func _random_floor_in_room(r: Rect2i, grid: Array, floor_ch: String, rng: RandomNumberGenerator) -> Vector2i:
	for _try in 10:
		var t := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if grid[t.y][t.x] == floor_ch:
			return t
	return Vector2i(-1, -1)
