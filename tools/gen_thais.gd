extends SceneTree
## Deterministisk generator för Thais utkanter.
## Läser data/zones/_thais_core.txt (160×110), bygger 280×200-canvas med
## omgivande landsbygd, stämplar in kärnan, hugger portar, drar vägar,
## placerar omflyttade portaler och skriver town.json + två landsbygdszoner.
## Körs headless: godot --headless --path <proj> -s res://tools/gen_thais.gd

const CORE_W := 160
const CORE_H := 110
const MAP_W  := 280
const MAP_H  := 200
const OFF_X  := 60   # (MAP_W-CORE_W)/2
const OFF_Y  := 45   # (MAP_H-CORE_H)/2
const RNG_SEED := 4242

# Kärnans portaltecken som FLYTTAS UT (tas bort ur kärnan, placeras i utkanten/landsbygd)
const MOVED_FROM_CORE := ["0","1","2","D","V","I","T","L","R","C","G","A"]

# Portar (kärn-lokala koordinater på murkanten)
const GATE_N := Vector2i(80, 0)
const GATE_S := Vector2i(80, CORE_H - 1)
const GATE_E := Vector2i(CORE_W - 1, 56)
const GATE_W := Vector2i(0, 56)

# Landsbygdszonernas mått
const CZ_W := 120
const CZ_H := 100

func _init() -> void:
	var core := _load_core()
	var grid := _blank_grid()
	_paint_base(grid)
	_stamp_core(grid, core)
	_carve_gates_and_roads(grid)
	_place_town_portals(grid)
	_write_town(grid)
	_write_fields()
	_write_wilds()
	print("gen_thais: klar — town.json (%d×%d) + thais_fields + thais_wilds" % [MAP_W, MAP_H])
	quit()

# ─────────────────────────── Kärna & canvas ────────────────────────────

func _load_core() -> Array:
	var f := FileAccess.open("res://data/zones/_thais_core.txt", FileAccess.READ)
	assert(f != null, "_thais_core.txt saknas — kör extract_core.gd först")
	var rows: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.length() > 0:
			rows.append(line)
	f.close()
	assert(rows.size() == CORE_H, "kärnan har %d rader, väntade %d" % [rows.size(), CORE_H])
	assert(String(rows[0]).length() == CORE_W, "kärnbredd %d, väntade %d" % [String(rows[0]).length(), CORE_W])
	return rows

func _blank_grid() -> Array:
	var grid: Array = []
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			row.append(".")
		grid.append(row)
	return grid

func _set(grid: Array, x: int, y: int, ch: String) -> void:
	if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
		grid[y][x] = ch

# ───────────────────────────── Basterräng ──────────────────────────────

func _paint_base(grid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	for y in MAP_H:
		for x in MAP_W:
			var ch := "."
			if x < 44:
				ch = "~"                       # hav
			elif x < 54:
				ch = "b"                       # strand
			elif x < OFF_X:
				ch = "."                       # gräs upp mot muren
			elif x >= OFF_X + CORE_W:
				ch = "W"                       # berg i öster
			elif y < OFF_Y:
				ch = "g" if rng.randf() < 0.75 else "."   # åkrar i norr
			elif y >= OFF_Y + CORE_H:
				ch = "s" if rng.randf() < 0.6 else "."    # träsk i söder
			grid[y][x] = ch
	# Flod i norr (bro fylls i av vägdragningen)
	for x in range(OFF_X, OFF_X + CORE_W):
		_set(grid, x, 18, "~")
		_set(grid, x, 19, "~")
	# Skogsbryn (träd) i nordost, söder om floden så det nås utan bro
	for y in range(22, OFF_Y):
		for x in range(OFF_X + CORE_W - 36, OFF_X + CORE_W):
			if rng.randf() < 0.35:
				_set(grid, x, y, "t")

# ──────────────────────────── Stämpla kärna ────────────────────────────

func _stamp_core(grid: Array, core: Array) -> void:
	for cy in CORE_H:
		var row: String = core[cy]
		for cx in CORE_W:
			var ch := row[cx]
			if MOVED_FROM_CORE.has(ch):
				ch = "W"   # mura igen där vildmarksportalen satt
			grid[OFF_Y + cy][OFF_X + cx] = ch

# ──────────────────────────── Portar & vägar ───────────────────────────

func _road_v(grid: Array, x: int, y0: int, y1: int) -> void:
	for y in range(min(y0, y1), max(y0, y1) + 1):
		_set(grid, x, y, "f" if grid[y][x] == "~" else "c")   # bro över vatten

func _road_h(grid: Array, y: int, x0: int, x1: int) -> void:
	for x in range(min(x0, x1), max(x0, x1) + 1):
		_set(grid, x, y, "f" if grid[y][x] == "~" else "c")

func _carve_gates_and_roads(grid: Array) -> void:
	# Norra porten → väg upp över bron till kartens topp
	var gn := Vector2i(OFF_X + GATE_N.x, OFF_Y + GATE_N.y)
	_set(grid, gn.x, gn.y, "c")
	_road_v(grid, gn.x, 1, gn.y)
	# Södra porten → väg ner till kartens botten
	var gs := Vector2i(OFF_X + GATE_S.x, OFF_Y + GATE_S.y)
	_set(grid, gs.x, gs.y, "c")
	_road_v(grid, gs.x, gs.y, MAP_H - 2)
	# Östra porten → stig in i berget
	var ge := Vector2i(OFF_X + GATE_E.x, OFF_Y + GATE_E.y)
	_set(grid, ge.x, ge.y, "c")
	_road_h(grid, ge.y, ge.x, OFF_X + CORE_W + 5)
	# Västra porten → strandväg ut mot havet
	var gw := Vector2i(OFF_X + GATE_W.x, OFF_Y + GATE_W.y)
	_set(grid, gw.x, gw.y, "c")
	_road_h(grid, gw.y, 52, gw.x)

# ───────────────────────── Omflyttade portaler ─────────────────────────

func _place_town_portals(grid: Array) -> void:
	var ge_y := OFF_Y + GATE_E.y
	var ex := OFF_X + CORE_W + 5            # strax in i berget
	# Östra berget: cave, dwarf_mine, vampire_crypt — korridor + portaler
	_road_v(grid, ex, ge_y - 40, ge_y + 40)
	_road_h(grid, ge_y - 40, ex, ex + 6); _set(grid, ex + 6, ge_y - 40, "0")  # cave
	_road_h(grid, ge_y,      ex, ex + 6); _set(grid, ex + 6, ge_y,      "G")  # dwarf_mine
	_road_h(grid, ge_y + 40, ex, ex + 6); _set(grid, ex + 6, ge_y + 40, "C")  # vampire_crypt
	# Södra träsket: troll_cave (på södra vägen)
	_set(grid, OFF_X + GATE_S.x, OFF_Y + CORE_H + 8, "T")
	# Nordöstra skogsbrynet: forest (söder om floden, nås via fältbandet)
	_set(grid, OFF_X + CORE_W - 12, 42, "1")
	# Västra stranden: coast (på strandvägens ände)
	_set(grid, 52, OFF_Y + GATE_W.y, "2")
	# Landsbygdsportaler vid vägändarna
	_set(grid, OFF_X + GATE_N.x, 1, ">")          # → thais_fields (norra bron)
	_set(grid, OFF_X + GATE_S.x, MAP_H - 2, "<")  # → thais_wilds (södra vägen)

# ───────────────────────────── Serialisering ───────────────────────────

func _grid_to_rows(grid: Array) -> Array:
	var rows: Array = []
	for y in MAP_H:
		var s := ""
		for x in MAP_W:
			s += grid[y][x]
		assert(s.length() == MAP_W, "rad %d fel bredd %d" % [y, s.length()])
		rows.append(s)
	return rows

func _write_zone(path: String, name: String, rows: Array, legend: Dictionary, spawn_table: Array) -> void:
	var d := {"name": name, "tiles": rows, "legend": legend}
	if not spawn_table.is_empty():
		d["spawn_table"] = spawn_table
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()

func _town_legend() -> Dictionary:
	# Behållna interiörer + kvarvarande närportaler + nya landsbygdsportaler.
	# (D/V/I/L/R/A flyttade till landsbygdszonerna och utelämnas.)
	return {
		"0": {"type": "portal", "to": "cave"},
		"1": {"type": "portal", "to": "forest"},
		"2": {"type": "portal", "to": "coast"},
		"T": {"type": "portal", "to": "troll_cave", "terrain": ","},
		"C": {"type": "portal", "to": "vampire_crypt", "terrain": ","},
		"G": {"type": "portal", "to": "dwarf_mine", "terrain": ","},
		">": {"type": "portal", "to": "thais_fields", "terrain": "c"},
		"<": {"type": "portal", "to": "thais_wilds", "terrain": "c"},
		"Z": {"type": "decoration", "station": "prayer_altar"},
		"B": {"type": "bank"},
		"H": {"type": "shop"},
		"E": {"type": "entrance", "to": "rain_castle", "terrain": ","},
		"K": {"type": "entrance", "to": "tibianus_temple", "terrain": ","},
		"F": {"type": "entrance", "to": "frodo_inn", "terrain": ","},
		"N": {"type": "entrance", "to": "thais_depot_int", "terrain": ","},
		"J": {"type": "entrance", "to": "knight_guild", "terrain": ","},
		"Q": {"type": "entrance", "to": "paladin_guild", "terrain": ","},
		"M": {"type": "entrance", "to": "sorcerer_guild", "terrain": ","},
		"U": {"type": "entrance", "to": "thais_docks", "terrain": ","},
		"X": {"type": "entrance", "to": "thais_jail", "terrain": ","},
		"O": {"type": "entrance", "to": "adventurer_guild", "terrain": ","},
		"Y": {"type": "entrance", "to": "knight_arena", "terrain": ","},
		"n": {"type": "stair_up", "to": "rain_castle_f2", "terrain": "n"},
		"a": {"type": "spawn", "monster": "Råtta", "respawn": 12.0},
		"p": {"type": "spawn", "monster": "Pirat", "respawn": 28.0},
	}

func _write_town(grid: Array) -> void:
	var rows := _grid_to_rows(grid)
	var spawns := [
		{"monster": "Bandit", "count": 4, "respawn": 30.0},
		{"monster": "Skogsvargen", "count": 3, "respawn": 35.0},
	]
	_write_zone("res://data/zones/town.json", "Thais", rows, _town_legend(), spawns)

# ───────────────────────────── Landsbygdszoner ─────────────────────────

func _put(s: String, i: int, ch: String) -> String:
	return s.substr(0, i) + ch + s.substr(i + 1)

func _border_or(rng: RandomNumberGenerator, x: int, y: int, fill_ch: String, fill_prob: float) -> String:
	if x == 0 or x == CZ_W - 1 or y == 0 or y == CZ_H - 1:
		return "W"   # kant-mur
	return fill_ch if rng.randf() < fill_prob else "."

func _fields_rows() -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = RNG_SEED + 1
	var rows: Array = []
	for y in CZ_H:
		var s := ""
		for x in CZ_W:
			s += _border_or(rng, x, y, "g", 0.7)
		rows.append(s)
	var mid := CZ_W / 2
	for y in range(1, CZ_H - 1):                 # vertikal väg
		rows[y] = _put(rows[y], mid, "c")
	rows[CZ_H - 3] = _put(rows[CZ_H - 3], mid, "P")   # player_start på vägen
	rows[CZ_H - 1] = _put(rows[CZ_H - 1], mid, ">")   # → town (söderut)
	rows[1]        = _put(rows[1], mid, "I")          # → ice (norrut)
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], CZ_W - 2, "D")   # → desert (öster)
	return rows

func _wilds_rows() -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = RNG_SEED + 2
	var rows: Array = []
	for y in CZ_H:
		var s := ""
		for x in CZ_W:
			s += _border_or(rng, x, y, "s", 0.55)
		rows.append(s)
	var mid := CZ_W / 2
	for y in range(1, CZ_H - 1):
		rows[y] = _put(rows[y], mid, "c")
	rows[3]        = _put(rows[3], mid, "P")          # player_start nära norra porten
	rows[1]        = _put(rows[1], mid, "<")          # → town (norrut)
	rows[CZ_H - 2] = _put(rows[CZ_H - 2], mid, "V")   # → volcano
	rows[CZ_H - 2] = _put(rows[CZ_H - 2], mid + 6, "A")   # → demon_temple
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], 2, "L")          # → minotaur_maze
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], CZ_W - 2, "R")   # → orc_rift
	return rows

func _write_fields() -> void:
	var legend := {
		">": {"type": "portal", "to": "town", "terrain": "c"},
		"I": {"type": "portal", "to": "ice", "terrain": "c"},
		"D": {"type": "portal", "to": "desert", "terrain": "c"},
	}
	var spawns := [
		{"monster": "Bandit", "count": 5, "respawn": 30.0},
		{"monster": "Skogsbjörn", "count": 3, "respawn": 40.0},
	]
	_write_zone("res://data/zones/thais_fields.json", "Norra landsbygden", _fields_rows(), legend, spawns)

func _write_wilds() -> void:
	var legend := {
		"<": {"type": "portal", "to": "town", "terrain": "c"},
		"V": {"type": "portal", "to": "volcano", "terrain": ","},
		"A": {"type": "portal", "to": "demon_temple", "terrain": ","},
		"L": {"type": "portal", "to": "minotaur_maze", "terrain": ","},
		"R": {"type": "portal", "to": "orc_rift", "terrain": ","},
	}
	var spawns := [
		{"monster": "Sumpkräla", "count": 5, "respawn": 28.0},
		{"monster": "Ork", "count": 4, "respawn": 35.0},
		{"monster": "Giftpadda", "count": 3, "respawn": 30.0},
	]
	_write_zone("res://data/zones/thais_wilds.json", "Trollmarken", _wilds_rows(), legend, spawns)
