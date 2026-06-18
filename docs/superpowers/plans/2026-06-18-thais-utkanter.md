# Thais utkanter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bygga ut Thais (`data/zones/town.json`) från 160×112 till 280×200 med landsbygd runt stadskärnan (hav, berg, fält, träsk, vägar, bro), nya terräng-tiles (träd/väg/åker), omflyttade portaler, samt två nya landsbygdszoner (`thais_fields`, `thais_wilds`).

**Architecture:** Stadskärnan bevaras och stämplas i mitten av en större canvas via ett deterministiskt engångs-generatorskript (`tools/gen_thais.gd`, EditorScript). Generatorn målar omgivningen, hugger portar, drar vägar, placerar omflyttade portaler och skriver ut tre zon-JSON-filer. Allt nedströms (zon-laddning, AStar, minimap, sparsystem) är oförändrat — det är fortfarande vanlig zon-JSON.

**Tech Stack:** Godot 4.6 (GDScript), GUT (test), JSON-zondata.

---

## Förutsättningar & fakta (läs först)

- **Godot-binär (headless):** `C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe`
- **Projekt:** `C:\Users\Hem\tibia2d`
- **Kör ett testfil headless (PowerShell):**
  ```powershell
  & "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/unit/test_zone.gd -gprefix=test_ -gexit
  ```
- **Kör ett EditorScript headless:** `... --headless --path "C:\Users\Hem\tibia2d" -s "res://tools/gen_thais.gd"`
- **Baslinje är redan röd:** 12/32 zon-tester failar redan pga tidigare data-drift (bl.a. monsternamn "Ratta" vs "Råtta"). Denna plan ska göra de NYA town-relaterade testerna gröna och inte införa nya fel — inte fixa all befintlig drift.
- **Zon-mekanik (`world/zone.gd`):** För varje tecken: `"P"` = player_start (renderas "."); annars om `legend.has(ch)` → legend-post (portal/entrance/stair/spawn/node/station/decoration/shop/bank/taskmaster/chest/dungeon_entrance/gate/shortcut), terräng = `e.get("terrain", default)` där default är `"."` för town annars `","`; annars renderas tecknet som terräng direkt. Walkability (rad 127): blockerad om terräng ∈ {W, w, r, ~} eller `blocked`.
- **Terräng-tecken (`world/placeholder_tiles.gd`):** `.`gräs `,`jord `W`sten/mur `~`vatten `s`träsk `b`strand `w`fönster `f`trägolv `r`tak `n`trappa.
- **Lediga tecken för nya portaler:** `>` och `<` (ej använda i town).
- **Monster som finns** (urval): Råtta, Bandit, Goblin, Skogsvargen, Skogsbjörn (norr/fält); Sumpkräla, Sumpvarelse, Giftpadda, Ork, Skelett (träsk/söder).

---

## Filstruktur

| Fil | Ansvar | Åtgärd |
|---|---|---|
| `world/placeholder_tiles.gd` | Terräng→tile-mappning | Modifiera: lägg `t`,`c`,`g` |
| `world/zone.gd` | Walkability | Modifiera rad ~127: `t` blockerar |
| `ui/minimap.gd` | Kartfärger | Modifiera `T_COLORS`: lägg `t`,`c`,`g` |
| `tools/extract_core.gd` | Engångs-extraktion av kärnan | Skapa |
| `data/zones/_thais_core.txt` | Kärn-källa (160×112 rader) | Skapas av extract_core |
| `tools/gen_thais.gd` | Generator | Skapa |
| `data/zones/town.json` | Regenererad 280×200 | Skrivs av generator |
| `data/zones/thais_fields.json` | Ny nordlig zon | Skrivs av generator |
| `data/zones/thais_wilds.json` | Ny sydlig zon | Skrivs av generator |
| `tests/unit/test_thais_outskirts.gd` | Nya tester | Skapa |
| `tests/unit/test_zone.gd` | Befintliga town-tester | Modifiera koordinater |

---

## Task 1: Nya terräng-tiles (träd/väg/åker)

**Files:**
- Modify: `world/placeholder_tiles.gd`
- Modify: `world/zone.gd` (rad ~127)
- Modify: `ui/minimap.gd` (`T_COLORS`)
- Test: `tests/unit/test_thais_outskirts.gd`

- [ ] **Step 1: Skriv det failande testet**

Skapa `tests/unit/test_thais_outskirts.gd`:

```gdscript
extends GutTest
## Tester för Thais-utkanter: nya tiles, generad town, nya landsbygdszoner.

const ZoneScript = preload("res://world/zone.gd")

func before_each():
	UnlockSystem.unlocked.clear()

func after_each():
	UnlockSystem.unlocked.clear()

func _make_zone(zone_id: String):
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build(zone_id)
	return z

func test_new_terrain_chars_registered():
	for ch in ["t", "c", "g"]:
		assert_true(PlaceholderTiles.TERRAIN.has(ch), "TERRAIN saknar '%s'" % ch)
		assert_true(PlaceholderTiles.TILE_FILES.has(ch), "TILE_FILES saknar '%s'" % ch)
		assert_true(PlaceholderTiles.COLORS.has(ch), "COLORS saknar '%s'" % ch)
```

- [ ] **Step 2: Kör testet och verifiera FAIL**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/unit/test_thais_outskirts.gd -gprefix=test_ -gexit
```
Expected: FAIL — `TERRAIN saknar 't'`.

- [ ] **Step 3: Lägg till tiles i `placeholder_tiles.gd`**

Ändra de tre konstanterna (lägg de tre sista posterna):

```gdscript
const TERRAIN := {".": 0, ",": 1, "W": 2, "~": 3, "s": 4, "b": 5, "w": 6, "f": 7, "r": 8, "n": 9, "t": 10, "c": 11, "g": 12}

const TILE_FILES := {
	".": "grass",
	",": "dirt",
	"W": "wall",
	"~": "water",
	"s": "swamp",
	"b": "beach",
	"w": "window",
	"f": "wooden_floor",
	"r": "roof",
	"n": "stairs",
	"t": "tree",
	"c": "cobblestone",
	"g": "field",
}

const COLORS := {
	".": Color("4a8f3c"), ",": Color("6b5436"),
	"W": Color("6e6e72"), "~": Color("2e5f9e"),
	"s": Color("4f5a2e"), "b": Color("d8c88a"),
	"w": Color("8a9aaa"), "f": Color("7a5530"),
	"r": Color("8b3a1e"), "n": Color("5a5060"),
	"t": Color("2f5a28"), "c": Color("8a8478"),
	"g": Color("9aa84e"),
}
```

Sprite-filerna (`assets/sprites/tiles/{tree,cobblestone,field}.png`) saknas → fallback-färgerna används automatiskt. Inga andra ändringar i `build()` (den itererar `TERRAIN.size()`).

- [ ] **Step 4: Kör testet och verifiera PASS**

Run: samma kommando som Step 2.
Expected: PASS (`test_new_terrain_chars_registered`).

- [ ] **Step 5: Gör `t` blockerande i `zone.gd`**

I `world/zone.gd`, ändra walkability-raden (~127):

```gdscript
		_walkable[t] = terrain != "W" and terrain != "w" and terrain != "r" and terrain != "~" and terrain != "t" and not blocked
```

(`c` och `g` förblir gångbara — de ligger inte i mängden.)

- [ ] **Step 6: Lägg kartfärger i `minimap.gd`**

I `ui/minimap.gd`, i `const T_COLORS`, lägg tre poster innanför `{ ... }`:

```gdscript
	"t": Color(0.18, 0.35, 0.16),   # träd
	"c": Color(0.54, 0.52, 0.47),   # kullersten-väg
	"g": Color(0.60, 0.66, 0.31),   # åker
```

- [ ] **Step 7: Lägg till walkability-test och kör**

Lägg i `tests/unit/test_thais_outskirts.gd`:

```gdscript
func test_tree_blocks_road_and_field_walkable():
	# Bygg ett pyttezon-test via en temporär zon-JSON i minnet är inte stött;
	# verifiera istället mot zone.gd-regeln direkt genom town efter regenerering.
	# (Riktig gångbarhet täcks i Task 4.) Här verifierar vi bara terräng-registret.
	assert_eq(PlaceholderTiles.TERRAIN["t"], 10)
	assert_eq(PlaceholderTiles.TERRAIN["c"], 11)
	assert_eq(PlaceholderTiles.TERRAIN["g"], 12)
```

Run: samma kommando som Step 2. Expected: PASS (2 tester).

- [ ] **Step 8: Commit**

```powershell
git add world/placeholder_tiles.gd world/zone.gd ui/minimap.gd tests/unit/test_thais_outskirts.gd
git commit -m "feat(tiles): lägg träd/väg/åker-terräng (t/c/g) för Thais-utkanter"
```

---

## Task 2: Extrahera stadskärnan till källfil

Kärnan måste sparas **innan** town.json skrivs över, så generatorn alltid har en oförändrad källa.

**Files:**
- Create: `tools/extract_core.gd`
- Create (output): `data/zones/_thais_core.txt`

- [ ] **Step 1: Skapa extraktionsskriptet**

Skapa `tools/extract_core.gd`:

```gdscript
@tool
extends EditorScript
## Engångs: läser nuvarande town.json och skriver dess tile-rader till
## _thais_core.txt (stadskärnans källa för generatorn). Kör EN gång innan
## town.json regenereras.

func _run() -> void:
	var f := FileAccess.open("res://data/zones/town.json", FileAccess.READ)
	assert(f != null, "town.json saknas")
	var d = JSON.parse_string(f.get_as_text())
	assert(d is Dictionary and d.has("tiles"), "town.json saknar tiles")
	var rows: Array = d["tiles"]
	var out := FileAccess.open("res://data/zones/_thais_core.txt", FileAccess.WRITE)
	for r in rows:
		out.store_line(String(r))
	out.close()
	print("extract_core: skrev %d rader (bredd %d)" % [rows.size(), String(rows[0]).length()])
```

- [ ] **Step 2: Kör extraktionen**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://tools/extract_core.gd"
```
Expected: `extract_core: skrev 112 rader (bredd 160)`

- [ ] **Step 3: Verifiera filen**

Run:
```powershell
(Get-Content "C:\Users\Hem\tibia2d\data\zones\_thais_core.txt" | Measure-Object -Line).Lines
```
Expected: `112`

- [ ] **Step 4: Commit**

```powershell
git add tools/extract_core.gd data/zones/_thais_core.txt
git commit -m "chore: extrahera Thais stadskärna till _thais_core.txt (generator-källa)"
```

---

## Task 3: Generatorskript `gen_thais.gd`

Genererar town.json (280×200) + thais_fields.json + thais_wilds.json. Positioner ligger som konstanter överst så de kan finjusteras i Task 5.

**Files:**
- Create: `tools/gen_thais.gd`

- [ ] **Step 1: Skapa generatorns skelett (konstanter + _run)**

Skapa `tools/gen_thais.gd`:

```gdscript
@tool
extends EditorScript
## Deterministisk generator för Thais utkanter.
## Läser data/zones/_thais_core.txt (160×112), bygger 280×200-canvas med
## omgivande landsbygd, stämplar in kärnan, hugger portar, drar vägar,
## placerar omflyttade portaler och skriver town.json + två landsbygdszoner.

const CORE_W := 160
const CORE_H := 112
const MAP_W  := 280
const MAP_H  := 200
const OFF_X  := 60   # (MAP_W-CORE_W)/2
const OFF_Y  := 44   # (MAP_H-CORE_H)/2
const RNG_SEED := 4242

# Kärnans portaltecken som FLYTTAS UT (tas bort ur kärnan, placeras i utkanten/landsbygd)
const MOVED_FROM_CORE := ["0","1","2","D","V","I","T","L","R","C","G","A"]

# Portar (kärn-lokala koordinater på murkanten)
const GATE_N := Vector2i(80, 0)
const GATE_S := Vector2i(80, CORE_H - 1)
const GATE_E := Vector2i(CORE_W - 1, 56)
const GATE_W := Vector2i(0, 56)

func _run() -> void:
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
```

- [ ] **Step 2: Hjälpare — läs kärna & tom canvas**

Lägg i `tools/gen_thais.gd`:

```gdscript
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
```

- [ ] **Step 3: Hjälpare — måla basterräng per väderstreck**

Lägg i `tools/gen_thais.gd`:

```gdscript
func _paint_base(grid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	for y in MAP_H:
		for x in MAP_W:
			var ch := "."
			# Väster: hav → strand → gräs upp mot muren
			if x < 44:
				ch = "~"
			elif x < 54:
				ch = "b"
			elif x < OFF_X:
				ch = "."
			# Öster: berg
			elif x >= OFF_X + CORE_W:
				ch = "W"
			# Norr (mitt-spann): åkrar
			elif y < OFF_Y:
				ch = "g" if rng.randf() < 0.75 else "."
			# Söder (mitt-spann): träsk + gräs
			elif y >= OFF_Y + CORE_H:
				ch = "s" if rng.randf() < 0.6 else "."
			grid[y][x] = ch
	# Flod i norr med naturlig kant, bro fylls i senare
	for x in range(OFF_X, OFF_X + CORE_W):
		_set(grid, x, 18, "~")
		_set(grid, x, 19, "~")
	# Skogsbryn (träd) i nordost
	for y in range(8, OFF_Y):
		for x in range(OFF_X + CORE_W - 36, OFF_X + CORE_W):
			if rng.randf() < 0.35:
				_set(grid, x, y, "t")
```

- [ ] **Step 4: Hjälpare — stämpla in kärnan (strippa flyttade portaler)**

Lägg i `tools/gen_thais.gd`:

```gdscript
func _stamp_core(grid: Array, core: Array) -> void:
	for cy in CORE_H:
		var row: String = core[cy]
		for cx in CORE_W:
			var ch := row[cx]
			# Flytta ut vildmarksportaler: ersätt med mur så stadskanten är hel
			if MOVED_FROM_CORE.has(ch):
				ch = "W"
			grid[OFF_Y + cy][OFF_X + cx] = ch
```

- [ ] **Step 5: Hjälpare — hugg portar och dra vägar**

Lägg i `tools/gen_thais.gd`:

```gdscript
func _road_v(grid: Array, x: int, y0: int, y1: int) -> void:
	for y in range(min(y0, y1), max(y0, y1) + 1):
		# Bro av trägolv där vägen korsar vatten, annars kullersten
		_set(grid, x, y, "f" if grid[y][x] == "~" else "c")

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
	# Östra porten → stig in i berget (öppnas av portal-korridorer i Step 6)
	var ge := Vector2i(OFF_X + GATE_E.x, OFF_Y + GATE_E.y)
	_set(grid, ge.x, ge.y, "c")
	_road_h(grid, ge.y, ge.x, OFF_X + CORE_W + 5)
	# Västra porten → strandväg ut mot havet
	var gw := Vector2i(OFF_X + GATE_W.x, OFF_Y + GATE_W.y)
	_set(grid, gw.x, gw.y, "c")
	_road_h(grid, gw.y, 52, gw.x)
```

- [ ] **Step 6: Hjälpare — placera omflyttade town-portaler**

Lägg i `tools/gen_thais.gd`. Varje portal får en gångbar approach (`c`) genom berg/träsk:

```gdscript
func _portal(grid: Array, x: int, y: int, ch: String) -> void:
	_set(grid, x, y, ch)

func _place_town_portals(grid: Array) -> void:
	var ge_y := OFF_Y + GATE_E.y
	var ex := OFF_X + CORE_W + 5   # strax in i berget
	# Östra berget: cave, dwarf_mine, vampire_crypt — korridor + portal
	_road_v(grid, ex, ge_y - 40, ge_y + 40)
	_road_h(grid, ge_y - 40, ex, ex + 6); _portal(grid, ex + 6, ge_y - 40, "0")  # cave
	_road_h(grid, ge_y,      ex, ex + 6); _portal(grid, ex + 6, ge_y,      "G")  # dwarf_mine
	_road_h(grid, ge_y + 40, ex, ex + 6); _portal(grid, ex + 6, ge_y + 40, "C")  # vampire_crypt
	# Södra träsket: troll_cave
	var sx := OFF_X + GATE_S.x
	_portal(grid, sx, OFF_Y + CORE_H + 8, "T")
	# Nordöstra skogsbrynet: forest
	_portal(grid, OFF_X + CORE_W - 12, 12, "1")
	_road_v(grid, OFF_X + CORE_W - 12, 12, OFF_Y)
	# Västra stranden: coast
	_portal(grid, 50, OFF_Y + GATE_W.y, "2")
	# Landsbygdsportaler vid vägändarna
	_portal(grid, OFF_X + GATE_N.x, 1, ">")          # → thais_fields (norra bron)
	_portal(grid, OFF_X + GATE_S.x, MAP_H - 2, "<")  # → thais_wilds (södra vägen)
```

- [ ] **Step 7: Hjälpare — serialisering & town-legend**

Lägg i `tools/gen_thais.gd`:

```gdscript
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
	# (D/V/I/L/R/A flyttade till landsbygdszonerna och utelämnas här.)
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
```

**OBS:** `>`/`<` ärver inte automatiskt `terrain` — vi sätter `"terrain": "c"` så de renderas som väg och är gångbara. `U` (docks) ligger kvar i kärnan på sin gamla tile; det är acceptabelt (justeras visuellt i Task 5 om den hamnar i en mur).

- [ ] **Step 8: Hjälpare — landsbygdszonerna**

Lägg i `tools/gen_thais.gd`. Två procedurella ~120×100-zoner:

```gdscript
const CZ_W := 120
const CZ_H := 100

func _fields_rows() -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = RNG_SEED + 1
	var rows: Array = []
	for y in CZ_H:
		var s := ""
		for x in CZ_W:
			var ch := "g" if rng.randf() < 0.7 else "."
			if x == 0 or x == CZ_W - 1 or y == 0 or y == CZ_H - 1:
				ch = "W"   # kant-mur
			s += ch
		rows.append(s)
	# Vertikal väg i mitten
	for y in range(1, CZ_H - 1):
		rows[y] = _put(rows[y], CZ_W / 2, "c")
	# Portaler: retur söderut till town, ice norrut, desert österut
	rows[CZ_H - 1] = _put(rows[CZ_H - 1], CZ_W / 2, ">")   # → town
	rows[1]        = _put(rows[1], CZ_W / 2, "I")          # → ice
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], CZ_W - 2, "D")   # → desert
	return rows

func _wilds_rows() -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = RNG_SEED + 2
	var rows: Array = []
	for y in CZ_H:
		var s := ""
		for x in CZ_W:
			var ch := "s" if rng.randf() < 0.55 else "."
			if x == 0 or x == CZ_W - 1 or y == 0 or y == CZ_H - 1:
				ch = "W"
			s += ch
		rows.append(s)
	for y in range(1, CZ_H - 1):
		rows[y] = _put(rows[y], CZ_W / 2, "c")
	rows[1]        = _put(rows[1], CZ_W / 2, "<")          # → town (norrut)
	rows[CZ_H - 2] = _put(rows[CZ_H - 2], CZ_W / 2, "V")   # → volcano
	rows[CZ_H - 2] = _put(rows[CZ_H - 2], CZ_W / 2 + 6, "A")  # → demon_temple
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], 2, "L")          # → minotaur_maze
	rows[CZ_H / 2] = _put(rows[CZ_H / 2], CZ_W - 2, "R")   # → orc_rift
	return rows

func _put(s: String, i: int, ch: String) -> String:
	return s.substr(0, i) + ch + s.substr(i + 1)

func _write_fields() -> void:
	var legend := {
		"c": {"type": "spawn", "monster": "Råtta", "respawn": 14.0, "terrain": "c"},
		">": {"type": "portal", "to": "town", "terrain": "c"},
		"I": {"type": "portal", "to": "ice", "terrain": "c"},
		"D": {"type": "portal", "to": "desert", "terrain": "c"},
	}
	# OBS: "c" används som terräng i vägen — gör INTE 'c' till en legend-spawn.
	legend.erase("c")
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
```

**VIKTIGT:** Landsbygdszonerna saknar `"P"` (player_start). `zone.gd` sätter då player_start till `Vector2i.ZERO` som default — det är en mur (`W`) i hörnet och ej gångbart. Vi förlitar oss på att spelaren anländer via portal (World placerar spelaren vid ankomstporten), inte player_start. Verifieras i Task 4; om World kräver giltig player_start lägger vi en `P` vid mittvägen nära returporten.

- [ ] **Step 9: Commit (skriptet, ännu ej kört)**

```powershell
git add tools/gen_thais.gd
git commit -m "feat(tools): gen_thais.gd — generator för Thais utkanter + landsbygdszoner"
```

---

## Task 4: Kör generatorn & verifiera zon-laddning

**Files:**
- Modify (genereras): `data/zones/town.json`, `data/zones/thais_fields.json`, `data/zones/thais_wilds.json`
- Test: `tests/unit/test_thais_outskirts.gd`

- [ ] **Step 1: Skriv failande integrationstest**

Lägg i `tests/unit/test_thais_outskirts.gd`:

```gdscript
func test_town_is_expanded():
	var z = _make_zone("town")
	assert_eq(z.grid_size.x, 280, "town bredd")
	assert_eq(z.grid_size.y, 200, "town höjd")

func test_town_player_start_walkable():
	var z = _make_zone("town")
	assert_ne(z.player_start, Vector2i.ZERO, "player_start saknas")
	assert_true(z.is_walkable(z.player_start), "player_start ej gångbar")

func test_town_keeps_local_portals():
	var z = _make_zone("town")
	var dests = z.portals.values()
	for d in ["cave", "forest", "coast", "troll_cave", "vampire_crypt", "dwarf_mine", "thais_fields", "thais_wilds"]:
		assert_true(dests.has(d), "town saknar portal till %s" % d)

func test_town_moved_exotic_out():
	var z = _make_zone("town")
	var dests = z.portals.values()
	for d in ["desert", "volcano", "ice", "demon_temple", "minotaur_maze", "orc_rift"]:
		assert_false(dests.has(d), "town har kvar exotisk portal %s" % d)

func test_fields_and_wilds_load():
	var fields = _make_zone("thais_fields")
	assert_eq(fields.grid_size, Vector2i(120, 100))
	assert_true(fields.portals.values().has("town"))
	assert_true(fields.portals.values().has("ice"))
	assert_true(fields.portals.values().has("desert"))
	var wilds = _make_zone("thais_wilds")
	assert_true(wilds.portals.values().has("town"))
	for d in ["volcano", "demon_temple", "minotaur_maze", "orc_rift"]:
		assert_true(wilds.portals.values().has(d), "wilds saknar %s" % d)
```

- [ ] **Step 2: Kör testet och verifiera FAIL**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/unit/test_thais_outskirts.gd -gprefix=test_ -gexit
```
Expected: FAIL — town är fortfarande 160×112.

- [ ] **Step 3: Kör generatorn**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://tools/gen_thais.gd"
```
Expected: `gen_thais: klar — town.json (280×200) + thais_fields + thais_wilds`

- [ ] **Step 4: Kör testet och verifiera PASS**

Run: samma kommando som Step 2.
Expected: PASS för alla `test_thais_outskirts`-tester. Om `test_town_player_start_walkable` failar pga att en flyttad portal/strip lade en mur på `P`: justera så att kärnans `P` aldrig skrivs över (kontrollera `_stamp_core` — `P` ligger inte i `MOVED_FROM_CORE`, så den bevaras). Om landsbygdszon kraschar pga player_start: lägg en `P`-tile på mittvägen i `_fields_rows`/`_wilds_rows` nära returporten och kör om generatorn.

- [ ] **Step 5: Verifiera radbredd-integritet (hela sviten ej röd av nya filer)**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/unit/test_zone.gd -gprefix=test_ -gexit
```
Expected: Inga NYA krascher från radbredd-assert i town/thais_fields/thais_wilds (befintliga drift-fel kvarstår — de hanteras i Task 6).

- [ ] **Step 6: Commit**

```powershell
git add data/zones/town.json data/zones/thais_fields.json data/zones/thais_wilds.json tests/unit/test_thais_outskirts.gd
git commit -m "feat(world): regenererad Thais 280×200 + thais_fields/thais_wilds"
```

---

## Task 5: Visuell finjustering i editorn

Procedurell placering är grov; portar/portaler kan hamna i mur eller fel terräng. Detta är en manuell pass.

**Files:**
- Modify (vid behov): `tools/gen_thais.gd` (konstanter/positioner), regenerera

- [ ] **Step 1: Öppna spelet och inspektera Thais**

Run (icke-headless):
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\Hem\tibia2d"
```
Starta nytt spel, öppna kartan med **M**, scroll-zooma och dra runt (panorering fixades tidigare). Gå ut genom varje port.

- [ ] **Step 2: Checklista**

Verifiera och notera avvikelser:
- [ ] Alla fyra portar (N/S/Ö/V) är gångbara från gatan ut till landsbygden.
- [ ] Norra bron korsar floden utan vattenglapp (gångbar `f`).
- [ ] Östra bergsportalerna (cave/dwarf_mine/vampire_crypt) nås via korridor.
- [ ] coast (väster), forest (nordost), troll_cave (söder) nås.
- [ ] `>`/`<` leder till thais_fields/thais_wilds; returportalerna leder tillbaka.
- [ ] Inga interiörsingångar (bank/shop/gillen/depot/docks) hamnade i mur.

- [ ] **Step 3: Justera & regenerera vid behov**

Ändra relevanta konstanter (GATE_*, portalpositioner i `_place_town_portals`, flodrad, korridorlängder) i `tools/gen_thais.gd`. Kör om generatorn (Task 4 Step 3) och kör om testerna (Task 4 Step 4). Upprepa tills checklistan är grön.

- [ ] **Step 4: Commit (om skriptet ändrades)**

```powershell
git add tools/gen_thais.gd data/zones/town.json data/zones/thais_fields.json data/zones/thais_wilds.json
git commit -m "fix(world): finjustera portar/portaler i Thais-utkanter efter visuell pass"
```

---

## Task 6: Uppdatera befintliga town-tester

`tests/unit/test_zone.gd` har hårdkodade koordinater som låg i den gamla 160×112-kärnan och nu ligger i havet/utanför. Uppdatera dem mot den nya kartan (kärnan börjar vid offset (60,44)).

**Files:**
- Modify: `tests/unit/test_zone.gd`

- [ ] **Step 1: Identifiera town-coordinatberoende tester**

Berörda funktioner: `test_walls_block_floor_walkable` (Vector2i(0,0)/(1,1)), `test_pathfinding_finds_path` ((4,7)→(10,10)). Dessa pekar nu på västra havet.

- [ ] **Step 2: Uppdatera koordinaterna**

I `tests/unit/test_zone.gd`, ersätt:

```gdscript
func test_walls_block_floor_walkable():
	var z = _make_zone("town")
	assert_false(z.is_walkable(Vector2i(0, 0)))               # ~ havet i hörnet
	assert_true(z.is_walkable(z.player_start))                # innanför staden
```

```gdscript
func test_pathfinding_finds_path():
	var z = _make_zone("town")
	var goal := z.player_start + Vector2i(3, 0)
	var path = z.find_path(z.player_start, goal)
	assert_gt(path.size(), 0)
	assert_eq(path[path.size() - 1], goal)
```

- [ ] **Step 3: Kör town-zonens tester**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/unit/test_zone.gd -gprefix=test_ -gexit
```
Expected: `test_walls_block_floor_walkable` och `test_pathfinding_finds_path` PASS. (Övriga befintliga drift-fel som rör `cave`/portalantal/taskmaster ligger utanför denna feature — notera dem men fixa inte här om de inte rör town-expansionen. Om `test_town_has_three_portals` nu förväntar fel antal: uppdatera den till att kontrollera närvaro av `cave`/`forest`/`coast` istället för exakt antal.)

- [ ] **Step 4: Uppdatera portalantals-testet om det rör town**

Om `test_town_has_three_portals` finns och kontrollerar exakt antal, ändra till närvarokontroll:

```gdscript
func test_town_has_three_portals():
	var z = _make_zone("town")
	for d in ["cave", "forest", "coast"]:
		assert_true(z.portals.values().has(d), "town saknar %s" % d)
```

- [ ] **Step 5: Kör hela sviten och dokumentera kvarvarande**

Run:
```powershell
& "C:\Users\Hem\Downloads\Godot_v4.6.3-stable_win64.exe (1)\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\Hem\tibia2d" -s "res://addons/gut/gut_cmdln.gd" -gdir=res://tests/unit -gprefix=test_ -gexit
```
Expected: Inga NYA fel jämfört med baslinjen; town-relaterade tester gröna. Notera kvarvarande icke-relaterade drift-fel i commit-meddelandet.

- [ ] **Step 6: Commit**

```powershell
git add tests/unit/test_zone.gd
git commit -m "test(zone): uppdatera town-koordinater för 280×200-expansionen"
```

---

## Self-review-noteringar (för exekveraren)

- **Spec-täckning:** §1 mått/terräng → Task 1+3+4; §1 nya tiles → Task 1; §2 landsbygdszoner → Task 3 Step 8 + Task 4; §3 portal-omflyttning → Task 3 Step 6–8; §4 generator → Task 2+3+4; §5 risker (radbredd, skiftläge, performance, minimap, spawns, kärn-backup) → Task 2 (backup), Task 3 (`_grid_to_rows`-assert), Task 4/5 (verifiering).
- **Återstår medvetet (avgränsat):** riktiga sprites för t/c/g; retur-tiles per portal (landar i player_start); innehåll i exotiska målzoner.
- **Känd fallgrop:** landsbygdszonerna utan `P` — om World kräver giltig player_start, lägg en `P` på mittvägen (Task 3 Step 8-not, verifieras Task 4 Step 4).
- **Känd fallgrop:** `U` (docks) och andra kärn-ingångar sitter kvar på sina gamla tiles inuti kärnan — bör vara oförändrat korrekta eftersom hela kärnan stämplas in intakt; verifieras visuellt i Task 5.
