# Tibia2D Milstolpe 1 — Spelbar kärna: Implementationsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ett spelbart 2D top-down RPG-skelett: stad + grotta, tile-rörelse, Tibia-strid mot 5 porterade monster, XP/level/skills, loot, save, character creation.

**Architecture:** Godot 4.6.2-projekt. All speldata i JSON (`data/`). Zoner byggs från ASCII-kartor i JSON → TileMapLayer med programmatiskt TileSet (placeholder-färgtiles, bytbara mot riktiga tilesets senare). Tile-baserad rörelse = ren grid-logik, ingen fysik för movement; endast Area2D för klick-targeting. Stridslogik i statiska, GUT-testade funktioner.

**Tech Stack:** Godot 4.6.2 (`C:\Godot\Godot_v4.6.2-stable_win64.exe`), GDScript, GUT (Godot Unit Test), JSON-data. Tile-storlek 32 px.

**Viktiga kommandon:**
```powershell
$GODOT = "C:\Godot\Godot_v4.6.2-stable_win64.exe"
# Kör alla tester headless:
& $GODOT --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
# Starta spelet:
& $GODOT --path C:\Users\Hem\tibia2d
```

---

## Filstruktur (skapas av planen)

| Fil | Ansvar |
|-----|--------|
| `project.godot` | Projektconfig, autoloads, input map |
| `data/items.json` | Items (subset för M1) |
| `data/monsters.json` | 5 monster med stats + loot |
| `data/zones/town.json`, `data/zones/cave.json` | ASCII-kartor + legend |
| `autoload/game_state.gd` | Spelarstats, XP/level, skills, inventory, signals |
| `autoload/item_db.gd` | Laddar items.json, roll_loot |
| `autoload/monster_db.gd` | Laddar monsters.json |
| `autoload/world.gd` | Zonladdning, spelarplacering, portaler |
| `autoload/save_manager.gd` | Save/load JSON, autosave |
| `combat/combat_formulas.gd` | Statiska skadeformler (testbara) |
| `world/zone.gd` | ASCII→TileMapLayer, walkability, AStarGrid2D, spawnpunkter |
| `world/placeholder_tiles.gd` | Genererar TileSet med färgtiles |
| `entities/player/player.gd/.tscn` | Grid-rörelse, targeting, auto-attack |
| `entities/player/character_visual.gd` | Paper-doll-lager (kropp/hår/tröja/byxor) |
| `entities/monster/monster.gd/.tscn` | HP, AI (aggro/A*/attack), död, loot |
| `entities/ground_item.gd` | Lootpåse på marken, klick=plocka |
| `ui/hud.gd/.tscn` | HP/mana/XP-bars, gold, inventory, F1-potion |
| `ui/main_menu.gd/.tscn` | Nytt spel / Fortsätt |
| `ui/character_creator.gd/.tscn` | Namn + färger → startar spelet |
| `tests/unit/test_*.gd` | GUT-tester |

---

### Task 1: Projektskelett + GUT

**Files:**
- Create: `project.godot`, `.gitignore`, `icon.svg`
- Create: `addons/gut/` (klonas), `tests/unit/test_smoke.gd`

- [ ] **Step 1: Skapa mappstruktur + .gitignore**

```powershell
cd C:\Users\Hem\tibia2d
"autoload","combat","data\zones","entities\player","entities\monster","ui","world","tests\unit","tools" | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }
Set-Content .gitignore ".godot/`n*.import`n" -Encoding utf8
```

- [ ] **Step 2: Skapa `project.godot`**

```ini
; project.godot
config_version=5

[application]
config/name="Tibia2D"
run/main_scene="res://ui/main_menu.tscn"
config/features=PackedStringArray("4.6")

[autoload]
GameState="*res://autoload/game_state.gd"
ItemDB="*res://autoload/item_db.gd"
MonsterDB="*res://autoload/monster_db.gd"
World="*res://autoload/world.gd"
SaveManager="*res://autoload/save_manager.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[input]
move_up={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
move_down={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
move_left={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
move_right={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
hotkey_1={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194332,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
toggle_inventory={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":73,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
debug_spawn={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194343,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}

[rendering]
textures/canvas_textures/default_texture_filter=0
```

(physical_keycode: 87=W, 83=S, 65=A, 68=D, 4194332=F1, 73=I, 4194343=F12. `default_texture_filter=0` = nearest, krävs för skarp pixelart.)

Notera: autoload-skripten finns inte ännu — Godot klagar tills Task 3–5 är klara. Det är OK; testerna kör ändå via GUT när filerna finns. Skapa tomma stubbar nu så projektet öppnar rent:

```powershell
"game_state","item_db","monster_db","world","save_manager" | ForEach-Object { Set-Content "autoload\$_.gd" "extends Node" -Encoding utf8 }
```

- [ ] **Step 3: Installera GUT**

```powershell
git clone --depth 1 https://github.com/bitwes/Gut.git C:\Users\Hem\tibia2d\_gut_tmp
Move-Item C:\Users\Hem\tibia2d\_gut_tmp\addons\gut C:\Users\Hem\tibia2d\addons\gut
Remove-Item -Recurse -Force C:\Users\Hem\tibia2d\_gut_tmp
```

Aktivera pluginen i `project.godot` — lägg till sektionen:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 4: Skriv röktest `tests/unit/test_smoke.gd`**

```gdscript
extends GutTest

func test_sanity():
	assert_eq(1 + 1, 2)
```

- [ ] **Step 5: Importera projektet en gång, kör testet**

```powershell
$GODOT = "C:\Godot\Godot_v4.6.2-stable_win64.exe"
& $GODOT --headless --path C:\Users\Hem\tibia2d --import
& $GODOT --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Expected: `1 passed 0 failed`.

- [ ] **Step 6: Commit**

```powershell
cd C:\Users\Hem\tibia2d; git add -A; git commit -m "chore: projektskelett Godot 4.6 + GUT"
```

---

### Task 2: Speldata — items.json + monsters.json

**Files:**
- Create: `data/items.json`, `data/monsters.json`

Data porterad från godot_rpg (`bestiary.gd`, `monster_manager.gd`, `item_db.gd`).

- [ ] **Step 1: Skapa `data/items.json`**

```json
{
	"iron_coin":     {"name": "Järnmynt",      "type": "currency", "value": 1,  "color": "#c8a838"},
	"health_potion": {"name": "Hälsodryck",    "type": "potion",   "value": 45, "color": "#d03030", "heal": 60},
	"snake_skin":    {"name": "Ormskinn",      "type": "junk",     "value": 8,  "color": "#608830"},
	"spider_silk":   {"name": "Spindelsilke",  "type": "junk",     "value": 12, "color": "#d8d8e8"},
	"bone_chips":    {"name": "Benbitar",      "type": "junk",     "value": 10, "color": "#e0dcc8"},
	"ghoul_hand":    {"name": "Ghoulhand",     "type": "junk",     "value": 25, "color": "#5a7848"},
	"rusty_sword":   {"name": "Rostigt svärd", "type": "weapon",   "value": 30, "color": "#907860", "atk": 8},
	"iron_sword":    {"name": "Järnsvärd",     "type": "weapon",   "value": 150,"color": "#b0b8c0", "atk": 14}
}
```

- [ ] **Step 2: Skapa `data/monsters.json`**

`speed` = tiles/sekund, `cooldown` = sekunder mellan attacker, `aggro` = aggro-radie i tiles. Stats/loot porterade rakt av.

```json
{
	"Råtta":   {"hp": 20, "atk": 5,  "exp": 8,  "speed": 2.5, "cooldown": 1.1, "aggro": 6, "color": "#b88c61",
		"loot": [{"item": "iron_coin", "min": 1, "max": 4, "chance": 0.9}]},
	"Orm":     {"hp": 15, "atk": 4,  "exp": 6,  "speed": 2.2, "cooldown": 1.0, "aggro": 5, "color": "#618c2e",
		"loot": [{"item": "snake_skin", "min": 1, "max": 1, "chance": 0.75},
		         {"item": "iron_coin", "min": 1, "max": 2, "chance": 0.4}]},
	"Spindel": {"hp": 20, "atk": 7,  "exp": 12, "speed": 2.4, "cooldown": 1.1, "aggro": 6, "color": "#261f1a",
		"loot": [{"item": "spider_silk", "min": 1, "max": 1, "chance": 0.6},
		         {"item": "iron_coin", "min": 1, "max": 3, "chance": 0.35}]},
	"Skelett": {"hp": 45, "atk": 10, "exp": 35, "speed": 2.0, "cooldown": 1.4, "aggro": 7, "color": "#e0d9c2",
		"loot": [{"item": "bone_chips", "min": 1, "max": 2, "chance": 0.65},
		         {"item": "iron_coin", "min": 3, "max": 12, "chance": 0.75},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.04}]},
	"Ghoul":   {"hp": 95, "atk": 18, "exp": 65, "speed": 1.8, "cooldown": 1.8, "aggro": 7, "color": "#61854d",
		"loot": [{"item": "ghoul_hand", "min": 1, "max": 1, "chance": 0.5},
		         {"item": "iron_coin", "min": 10, "max": 35, "chance": 0.85},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.06}]}
}
```

- [ ] **Step 3: Commit**

```powershell
git add data; git commit -m "data: 5 monster + items porterade från godot_rpg"
```

---

### Task 3: GameState — stats, XP, skills

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/unit/test_game_state.gd`

- [ ] **Step 1: Skriv failande tester**

```gdscript
extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_xp_for_level():
	assert_eq(gs.xp_for_level(1), 100)   # 50*1*2
	assert_eq(gs.xp_for_level(2), 300)   # 50*2*3

func test_gain_exp_levels_up():
	gs.gain_exp(100)
	assert_eq(gs.level, 2)
	assert_eq(gs.experience, 0)

func test_level_up_raises_stats():
	var hp0 = gs.max_health
	gs.gain_exp(100)
	assert_eq(gs.max_health, hp0 + 25)
	assert_eq(gs.health, gs.max_health)

func test_skill_xp_next_formula():
	assert_eq(gs.skill_xp_next(0), 50)        # 50*1.1^0
	assert_eq(gs.skill_xp_next(10), 129)      # int(50*1.1^10)

func test_gain_skill_xp_levels_skill():
	gs.skills["sword"]["level"] = 0
	gs.skills["sword"]["xp"] = 0
	gs.gain_skill_xp("sword", 50)
	assert_eq(gs.skills["sword"]["level"], 1)

func test_inventory_add():
	gs.add_item("iron_coin", 5)
	gs.add_item("iron_coin", 3)
	assert_eq(gs.inventory["iron_coin"], 8)
```

- [ ] **Step 2: Kör — förvänta FAIL**

```powershell
& $GODOT --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

- [ ] **Step 3: Implementera `autoload/game_state.gd`**

```gdscript
extends Node
## Spelarens globala tillstånd. Autoload: GameState.

signal hp_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)
signal exp_changed(xp: int, xp_next: int, level: int)
signal gold_changed(gold: int)
signal inventory_changed
signal level_up(new_level: int)
signal player_died

const SKILL_XP_BASE := 50.0
const SKILL_XP_GROWTH := 1.1

var player_name := "Hjälte"
var level := 1
var experience := 0
var xp_to_next := 100
var health := 150.0
var max_health := 150.0
var mana := 100.0
var max_mana := 100.0
var gold := 0
var inventory: Dictionary = {}        # item_id -> qty
var equipped_weapon := "rusty_sword"
var appearance := {                   # character creation (M1: färger)
	"skin": "#e0b894", "hair": "#332211", "shirt": "#2e4dc0", "pants": "#1a1a52",
}
var skills: Dictionary = {
	"sword":     {"level": 10, "xp": 0},
	"shielding": {"level": 10, "xp": 0},
}
var current_zone := "town"
var player_tile := Vector2i.ZERO

func xp_for_level(lvl: int) -> int:
	return 50 * lvl * (lvl + 1)

func skill_xp_next(skill_level: int) -> int:
	return int(SKILL_XP_BASE * pow(SKILL_XP_GROWTH, skill_level))

func gain_exp(amount: int) -> void:
	experience += amount
	while experience >= xp_to_next:
		experience -= xp_to_next
		level += 1
		xp_to_next = xp_for_level(level)
		max_health += 25.0
		health = max_health
		max_mana += 12.0
		mana = max_mana
		level_up.emit(level)
	exp_changed.emit(experience, xp_to_next, level)

func gain_skill_xp(skill: String, amount: int) -> void:
	if not skills.has(skill):
		return
	var s: Dictionary = skills[skill]
	s["xp"] += amount
	while s["xp"] >= skill_xp_next(s["level"]):
		s["xp"] -= skill_xp_next(s["level"])
		s["level"] += 1

func take_damage(dmg: float) -> void:
	health = maxf(health - dmg, 0.0)
	hp_changed.emit(health, max_health)
	if health <= 0.0:
		player_died.emit()

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	hp_changed.emit(health, max_health)

func add_item(item_id: String, qty: int) -> void:
	if item_id == "iron_coin":
		gold += qty
		gold_changed.emit(gold)
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + qty
	inventory_changed.emit()

func remove_item(item_id: String, qty: int) -> bool:
	if int(inventory.get(item_id, 0)) < qty:
		return false
	inventory[item_id] -= qty
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true
```

- [ ] **Step 4: Kör tester — förvänta PASS (7/7)**

- [ ] **Step 5: Commit** — `git add -A; git commit -m "feat: GameState med XP/level/skills/inventory (TDD)"`

---

### Task 4: Stridsformler (statiska, testbara)

**Files:**
- Create: `combat/combat_formulas.gd`
- Test: `tests/unit/test_combat_formulas.gd`

- [ ] **Step 1: Skriv failande tester**

```gdscript
extends GutTest

const CF = preload("res://combat/combat_formulas.gd")

func test_max_melee_grows_with_skill():
	var low = CF.max_melee(1, 10, 8)
	var high = CF.max_melee(1, 50, 8)
	assert_gt(high, low)

func test_max_melee_known_value():
	# atk 8, skill 10, level 1: 8*(10+4)/28 + 1/10 = 4.1 -> 4
	assert_eq(CF.max_melee(1, 10, 8), 4)

func test_max_melee_minst_1():
	assert_eq(CF.max_melee(1, 0, 0), 1)

func test_roll_melee_within_bounds():
	for i in 50:
		var d = CF.roll_melee(10, 30, 14)
		assert_between(d, 0, CF.max_melee(10, 30, 14))

func test_mitigate_reduces():
	assert_lt(CF.mitigate(20, 30, 5), 20)

func test_mitigate_never_negative():
	assert_eq(CF.mitigate(1, 200, 50), 0)

func test_monster_roll_within_bounds():
	for i in 50:
		assert_between(CF.roll_monster(18), 0, 18)
```

- [ ] **Step 2: Kör — förvänta FAIL** (filen finns inte)

- [ ] **Step 3: Implementera `combat/combat_formulas.gd`**

```gdscript
class_name CombatFormulas
## Statiska skadeformler. Tibia-inspirerade, medvetet enkla.

static func max_melee(level: int, skill: int, weapon_atk: int) -> int:
	return maxi(int(weapon_atk * (skill + 4) / 28.0 + level / 10.0), 1)

static func roll_melee(level: int, skill: int, weapon_atk: int) -> int:
	return randi_range(0, max_melee(level, skill, weapon_atk))

static func roll_monster(monster_atk: int) -> int:
	return randi_range(0, monster_atk)

static func mitigate(raw_dmg: int, shielding: int, armor: int) -> int:
	var reduction := randi_range(armor / 2, armor) + shielding / 3
	return maxi(raw_dmg - reduction, 0)
```

- [ ] **Step 4: Kör tester — förvänta PASS**

- [ ] **Step 5: Commit** — `git commit -am "feat: stridsformler (TDD)"`

---

### Task 5: ItemDB + MonsterDB (JSON-laddare)

**Files:**
- Modify: `autoload/item_db.gd`, `autoload/monster_db.gd`
- Test: `tests/unit/test_databases.gd`

- [ ] **Step 1: Skriv failande tester**

```gdscript
extends GutTest

var idb
var mdb

func before_each():
	idb = load("res://autoload/item_db.gd").new()
	idb._load()
	mdb = load("res://autoload/monster_db.gd").new()
	mdb._load()

func after_each():
	idb.free(); mdb.free()

func test_items_loaded():
	assert_true(idb.items.has("health_potion"))
	assert_eq(idb.items["health_potion"]["heal"], 60)

func test_monsters_loaded():
	assert_true(mdb.monsters.has("Ghoul"))
	assert_eq(int(mdb.monsters["Ghoul"]["hp"]), 95)

func test_roll_loot_returns_valid_items():
	for i in 20:
		for entry in idb.roll_loot(mdb.monsters["Skelett"]["loot"]):
			assert_true(idb.items.has(entry["item"]))
			assert_gt(int(entry["qty"]), 0)
```

- [ ] **Step 2: Kör — förvänta FAIL**

- [ ] **Step 3: Implementera `autoload/item_db.gd`**

```gdscript
extends Node
## Autoload: ItemDB

var items: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	items = JSON.parse_string(f.get_as_text())

func roll_loot(loot_table: Array) -> Array:
	var result: Array = []
	for entry in loot_table:
		if randf() <= float(entry["chance"]):
			result.append({"item": entry["item"], "qty": randi_range(int(entry["min"]), int(entry["max"]))})
	return result
```

och `autoload/monster_db.gd`:

```gdscript
extends Node
## Autoload: MonsterDB

var monsters: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open("res://data/monsters.json", FileAccess.READ)
	monsters = JSON.parse_string(f.get_as_text())
```

- [ ] **Step 4: Kör tester — förvänta PASS**

- [ ] **Step 5: Commit** — `git commit -am "feat: ItemDB + MonsterDB JSON-laddare (TDD)"`

---

### Task 6: Zoner — ASCII-karta → TileMapLayer + walkability

**Files:**
- Create: `data/zones/town.json`, `data/zones/cave.json`
- Create: `world/placeholder_tiles.gd`, `world/zone.gd`
- Test: `tests/unit/test_zone.gd`

Zonformat: `tiles` = rader av tecken. Teckentyper: `W` stenmur (blockerad), `.` gräs, `,` jordgolv, `~` vatten (blockerad), `P` spelarstart (gräs), `0-9` portal (golv), `a-z` monsterspawn (golv). `legend` mappar portal-/spawntecken.

- [ ] **Step 1: Skapa `data/zones/town.json`** (40×24 tiles — stad med murar, en grottportal `0`)

```json
{
	"name": "Thais",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W......................................W",
		"W..WWWW....WWWW.........................W",
		"W..W..W....W..W.....a...................W",
		"W..W..W....W..W.........................W",
		"W..WWWW....WWWW..............a..........W",
		"W.......................................W",
		"W...P....................~~~............W",
		"W........................~~~............W",
		"W.......................................W",
		"W............a..........................W",
		"W........................WWWWW..........W",
		"W........................W,,,W..........W",
		"W........................W,0,W..........W",
		"W........................W,,,W..........W",
		"W........................WW,WW..........W",
		"W.......................................W",
		"W.....a.................................W",
		"W.......................................W",
		"W..........a............................W",
		"W.......................................W",
		"W................a......................W",
		"W.......................................W",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "cave"},
		"a": {"type": "spawn", "monster": "Råtta", "respawn": 12.0}
	}
}
```

- [ ] **Step 2: Skapa `data/zones/cave.json`** (40×24 — grotta med Orm/Spindel/Skelett/Ghoul, portal `0` tillbaka)

```json
{
	"name": "Thais-grottan",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W,,,,,,,,,WWWWWWW,,,,,,,,,,,,,,,,,,,,,,W",
		"W,P,,0,,,,,,,,,,W,,,b,,,,,WWW,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,,,W,,,,c,,,,,W",
		"WWWWWW,,,,,b,,,,W,,,,,,,,,,,W,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,WWWWW,,WWWWWW,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,c,,,,,W",
		"W,,,b,,,,WWWWW,,,,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,W,,,W,,,,,c,,,,,,WWWWWW,,,,,,,W",
		"W,,,,,,,,W,,,W,,,,,,,,,,,,W,,,,,,,,,,,,W",
		"W,,,,,,,,WW,WW,,,,,,,,,,,,W,,,d,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,W,,,,,,,,,,,,W",
		"W,,b,,,,,,,,,,,,WWWW,,,,,,W,,,,,,d,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,WWWW,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,c,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,WWWWWW,,,,W,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,,,,,,e,,,,,,,W",
		"W,,,,,,,,,,,,,,,WWWWWWWW,,,,,,,,,,,,,,,W",
		"W,,,,c,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,WWWW,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,W,,,,,e,,,W",
		"W,,,,,,,,b,,,,,,,,,,,,,,,,,,,W,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,W,,,,,,,,,W",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "town"},
		"b": {"type": "spawn", "monster": "Orm", "respawn": 15.0},
		"c": {"type": "spawn", "monster": "Spindel", "respawn": 15.0},
		"d": {"type": "spawn", "monster": "Skelett", "respawn": 25.0},
		"e": {"type": "spawn", "monster": "Ghoul", "respawn": 45.0}
	}
}
```

- [ ] **Step 2b: Validera kartornas radlängder**

ASCII-kartor är lätta att få fel bredd på. Kör efter varje kartändring:

```powershell
foreach ($z in "town","cave") {
  $j = Get-Content "data\zones\$z.json" -Raw | ConvertFrom-Json
  $w = $j.tiles[0].Length
  for ($i=0; $i -lt $j.tiles.Count; $i++) {
    if ($j.tiles[$i].Length -ne $w) { Write-Host "$z rad $i har längd $($j.tiles[$i].Length), förväntade $w" }
  }
}
```

Expected: ingen output. Vid avvikelser: padda raden med `.` (town) / `,` (cave) före slut-`W`, eller korta den. `zone.gd` assertar också detta vid laddning.

- [ ] **Step 3: Skriv failande test `tests/unit/test_zone.gd`**

```gdscript
extends GutTest

const ZoneScript = preload("res://world/zone.gd")

func _make_zone(zone_id: String):
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build(zone_id)
	return z

func test_town_loads_and_has_player_start():
	var z = _make_zone("town")
	assert_ne(z.player_start, Vector2i.ZERO)
	assert_true(z.is_walkable(z.player_start))

func test_walls_block_floor_walkable():
	var z = _make_zone("town")
	assert_false(z.is_walkable(Vector2i(0, 0)))   # W i hörnet
	assert_true(z.is_walkable(Vector2i(1, 1)))    # . innanför muren

func test_rows_equal_length():
	for id in ["town", "cave"]:
		var z = _make_zone(id)
		assert_gt(z.grid_size.x, 0, id)            # build assertar radlängder

func test_portal_found():
	var z = _make_zone("town")
	assert_eq(z.portals.size(), 1)
	assert_eq(z.portals.values()[0], "cave")
	var cave = _make_zone("cave")
	assert_eq(cave.portals.values()[0], "town")

func test_spawns_parsed():
	var z = _make_zone("cave")
	var ghouls = z.spawn_points.filter(func(s): return s["monster"] == "Ghoul")
	assert_eq(ghouls.size(), 2)

func test_pathfinding_finds_path():
	var z = _make_zone("town")
	var path = z.find_path(Vector2i(4, 7), Vector2i(10, 10))
	assert_gt(path.size(), 0)
	assert_eq(path[path.size() - 1], Vector2i(10, 10))
```

- [ ] **Step 4: Kör — förvänta FAIL**

- [ ] **Step 5: Implementera `world/placeholder_tiles.gd`**

```gdscript
class_name PlaceholderTiles
## Genererar ett TileSet med enfärgade 32x32-tiles + svag brusstruktur.
## Byts mot riktigt tileset (LPC) i senare milstolpe — zone.gd berörs inte.

const TILE := 32
# atlas-kolumn per terrängtecken
const TERRAIN := {".": 0, ",": 1, "W": 2, "~": 3}
const COLORS := {
	".": Color("4a8f3c"), ",": Color("6b5436"),
	"W": Color("6e6e72"), "~": Color("2e5f9e"),
}

static func build() -> TileSet:
	var img := Image.create(TILE * TERRAIN.size(), TILE, false, Image.FORMAT_RGBA8)
	for ch in TERRAIN:
		var base: Color = COLORS[ch]
		var col: int = TERRAIN[ch]
		for y in TILE:
			for x in TILE:
				var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13 + col * 31)) * 43758.5, 1.0)
				img.set_pixel(col * TILE + x, y, Color(base.r * n, base.g * n, base.b * n))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for col in TERRAIN.size():
		src.create_tile(Vector2i(col, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts
```

- [ ] **Step 6: Implementera `world/zone.gd`**

```gdscript
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
```

- [ ] **Step 7: Kör tester — förvänta PASS** (alla zone-tester + tidigare)

- [ ] **Step 8: Commit** — `git commit -am "feat: zonsystem med ASCII-kartor, walkability, A* (TDD)"`

---

### Task 7: Spelaren — paper-doll + grid-rörelse

**Files:**
- Create: `entities/player/character_visual.gd`, `entities/player/player.gd`, `entities/player/player.tscn`

Ingen TDD här (scenkod) — verifieras med spelstart i Task 9.

- [ ] **Step 1: Skapa `entities/player/character_visual.gd`**

Paper-doll med tintade placeholder-lager. När LPC-sprites importeras (senare milstolpe) byts rektanglarna mot AnimatedSprite2D-lager — API:t (`apply_appearance`, `face`) består.

```gdscript
class_name CharacterVisual
extends Node2D
## Paper-doll: kropp/byxor/tröja/hår som tintade lager.

var _layers: Dictionary = {}   # namn -> Polygon2D

func _ready() -> void:
	# (namn, rektangel i lokala px, z)
	for def in [
		["skin",  Rect2(-7, -24, 14, 10)],   # huvud
		["pants", Rect2(-6, -4, 12, 8)],     # ben
		["shirt", Rect2(-8, -15, 16, 12)],   # torso
		["hair",  Rect2(-8, -27, 16, 5)],    # hår ovanpå huvudet
	]:
		var p := Polygon2D.new()
		var r: Rect2 = def[1]
		p.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
		add_child(p)
		_layers[def[0]] = p

func apply_appearance(appearance: Dictionary) -> void:
	for key in _layers:
		if appearance.has(key):
			_layers[key].color = Color(appearance[key])

func face(dir: Vector2i) -> void:
	scale.x = -1.0 if dir.x < 0 else 1.0
```

- [ ] **Step 2: Skapa `entities/player/player.gd`**

```gdscript
class_name Player
extends Node2D
## Tile-baserad rörelse + targeting + auto-attack (attack i Task 9).

const TILE := 32

var zone: Node2D                      # sätts av World vid zonladdning
var tile := Vector2i.ZERO
var _move_t := 1.0                    # 0..1 under pågående steg
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var move_speed := 4.0                 # tiles/sek
var facing := Vector2i.DOWN

@onready var visual: CharacterVisual = $CharacterVisual

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)

func snap_to(t: Vector2i) -> void:
	tile = t
	position = zone.tile_to_world(t)
	_move_t = 1.0
	GameState.player_tile = t

func _process(delta: float) -> void:
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta * move_speed, 1.0)
		position = _from.lerp(_to, _move_t)
		if _move_t >= 1.0:
			GameState.player_tile = tile
			_check_portal()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		facing = dir
		visual.face(dir)
		var next := tile + dir
		if zone.is_walkable(next):
			_from = position
			_to = zone.tile_to_world(next)
			tile = next
			_move_t = 0.0

func _check_portal() -> void:
	if zone.portals.has(tile):
		World.change_zone(zone.portals[tile])
```

- [ ] **Step 3: Skapa `entities/player/player.tscn`**

Scenen byggs som textfil (`.tscn` är textformat):

```ini
[gd_scene load_steps=3 format=3 uid="uid://player0001"]

[ext_resource type="Script" path="res://entities/player/player.gd" id="1"]
[ext_resource type="Script" path="res://entities/player/character_visual.gd" id="2"]

[node name="Player" type="Node2D"]
script = ExtResource("1")

[node name="CharacterVisual" type="Node2D" parent="."]
script = ExtResource("2")

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
position_smoothing_enabled = true
```

- [ ] **Step 4: Commit** — `git commit -am "feat: spelare med paper-doll och tile-rörelse"`

---

### Task 8: World-autoload — zonladdning + spelflöde

**Files:**
- Modify: `autoload/world.gd`
- Create: `world/game.tscn` (spelets rotscen: World fyller den)

- [ ] **Step 1: Implementera `autoload/world.gd`**

```gdscript
extends Node
## Autoload: World. Laddar zoner, äger spelarinstansen.

const ZoneScene = preload("res://world/zone.gd")
const PlayerScene = preload("res://entities/player/player.tscn")
const MonsterScene = preload("res://entities/monster/monster.tscn")

var current_zone: Node2D
var player: Node2D
var game_root: Node2D    # sätts av game.tscn vid _ready

func start_game(zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	if current_zone:
		current_zone.queue_free()
		await current_zone.tree_exited
	current_zone = Node2D.new()
	current_zone.set_script(load("res://world/zone.gd"))
	game_root.add_child(current_zone)
	current_zone.build(zone_id)
	GameState.current_zone = zone_id

	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate()
	if player.get_parent():
		player.get_parent().remove_child(player)
	current_zone.add_child(player)
	player.zone = current_zone
	var start: Vector2i = at_tile if at_tile.x >= 0 else current_zone.player_start
	player.snap_to(start)

	_spawn_monsters()

func change_zone(zone_id: String) -> void:
	SaveManager.save_game()
	start_game.call_deferred(zone_id)

func _spawn_monsters() -> void:
	for sp in current_zone.spawn_points:
		_spawn_one(sp)

func spawn_monster(monster_name: String, t: Vector2i, respawn := -1.0) -> Node2D:
	var m := MonsterScene.instantiate()
	current_zone.add_child(m)
	m.setup(monster_name, t, current_zone, respawn)
	return m

func _spawn_one(sp: Dictionary) -> void:
	spawn_monster(sp["monster"], sp["tile"], sp["respawn"])
```

- [ ] **Step 2: Skapa `world/game.tscn` + `world/game_root.gd`**

```gdscript
# world/game_root.gd
extends Node2D
## Spelets rotscen. Registrerar sig hos World och startar.

func _ready() -> void:
	World.game_root = self
	var hud := preload("res://ui/hud.tscn").instantiate()
	add_child(hud)
	World.start_game(GameState.current_zone)
```

```ini
[gd_scene load_steps=2 format=3 uid="uid://game000001"]

[ext_resource type="Script" path="res://world/game_root.gd" id="1"]

[node name="Game" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Commit** — `git commit -am "feat: World-autoload med zonladdning"`

---

### Task 9: Monster — HP, AI, strid, död, loot

**Files:**
- Create: `entities/monster/monster.gd`, `entities/monster/monster.tscn`, `entities/ground_item.gd`

- [ ] **Step 1: Skapa `entities/monster/monster.gd`**

```gdscript
class_name Monster
extends Node2D
## Monster: aggro -> A*-jakt -> melee. Fryser AI när spelaren är långt borta.

const FREEZE_DIST := 30        # tiles; bortom detta: ingen AI alls
const TILE := 32

var monster_name := ""
var hp := 0.0
var max_hp := 0.0
var atk := 0
var speed := 2.0               # tiles/sek
var cooldown := 1.5
var aggro_range := 6
var exp_reward := 0
var loot_table: Array = []
var respawn_time := -1.0
var home_tile := Vector2i.ZERO

var zone: Node2D
var tile := Vector2i.ZERO
var _move_t := 1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _atk_timer := 0.0
var _path: Array = []
var dead := false

@onready var body: Polygon2D = $Body
@onready var hp_bar: ColorRect = $HpBar
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

func setup(mname: String, t: Vector2i, z: Node2D, respawn := -1.0) -> void:
	monster_name = mname
	zone = z
	home_tile = t
	respawn_time = respawn
	var d: Dictionary = MonsterDB.monsters[mname]
	max_hp = float(d["hp"]); hp = max_hp
	atk = int(d["atk"]); exp_reward = int(d["exp"])
	speed = float(d["speed"]); cooldown = float(d["cooldown"])
	aggro_range = int(d["aggro"]); loot_table = d["loot"]
	tile = t
	position = zone.tile_to_world(t)
	body.color = Color(d["color"])
	name_lbl.text = mname
	_update_hp_bar()

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dead:
			World.player.set_target(self)

func _process(delta: float) -> void:
	if dead or World.player == null:
		return
	var player_tile: Vector2i = GameState.player_tile
	var dist := maxi(absi(player_tile.x - tile.x), absi(player_tile.y - tile.y))
	if dist > FREEZE_DIST:
		return                                       # prestanda: frys helt
	_atk_timer = maxf(_atk_timer - delta, 0.0)

	if _move_t < 1.0:                                # pågående steg
		_move_t = minf(_move_t + delta * speed, 1.0)
		position = _from.lerp(_to, _move_t)
		return

	if dist <= 1:                                    # intill: slå
		if _atk_timer <= 0.0:
			_atk_timer = cooldown
			var raw := CombatFormulas.roll_monster(atk)
			var dmg := CombatFormulas.mitigate(raw, GameState.skills["shielding"]["level"], 2)
			if dmg > 0:
				GameState.take_damage(dmg)
				GameState.gain_skill_xp("shielding", 1)
		return

	if dist <= aggro_range:                          # jaga
		_path = zone.find_path(tile, player_tile)
		if _path.size() > 1:
			var next: Vector2i = _path[1]
			if next != player_tile and zone.is_walkable(next):
				_step_to(next)

func _step_to(next: Vector2i) -> void:
	tile = next
	_from = position
	_to = zone.tile_to_world(next)
	_move_t = 0.0

func take_damage(dmg: float) -> void:
	if dead:
		return
	hp = maxf(hp - dmg, 0.0)
	_update_hp_bar()
	if hp <= 0.0:
		_die()

func _update_hp_bar() -> void:
	hp_bar.size.x = 28.0 * (hp / max_hp)
	hp_bar.color = Color.GREEN if hp / max_hp > 0.5 else (Color.YELLOW if hp / max_hp > 0.25 else Color.RED)

func _die() -> void:
	dead = true
	GameState.gain_exp(exp_reward)
	var drops: Array = ItemDB.roll_loot(loot_table)
	if not drops.is_empty():
		var gi := preload("res://entities/ground_item.gd").new()
		zone.add_child(gi)
		gi.setup(drops, tile)
	if respawn_time > 0.0:
		var t := get_tree().create_timer(respawn_time)
		var mname := monster_name
		var ht := home_tile
		var rt := respawn_time
		t.timeout.connect(func(): if is_instance_valid(zone): World.spawn_monster(mname, ht, rt))
	if World.player and World.player.target == self:
		World.player.set_target(null)
	queue_free()
```

- [ ] **Step 2: Skapa `entities/monster/monster.tscn`**

```ini
[gd_scene load_steps=3 format=3 uid="uid://monster0001"]

[ext_resource type="Script" path="res://entities/monster/monster.gd" id="1"]

[sub_resource type="RectangleShape2D" id="shape1"]
size = Vector2(28, 28)

[node name="Monster" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-12, -12, 12, -12, 12, 12, -12, 12)

[node name="HpBar" type="ColorRect" parent="."]
offset_left = -14.0
offset_top = -20.0
offset_right = 14.0
offset_bottom = -17.0
color = Color(0, 1, 0, 1)

[node name="NameLabel" type="Label" parent="."]
offset_left = -40.0
offset_top = -34.0
offset_right = 40.0
offset_bottom = -22.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="ClickArea" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="ClickArea"]
shape = SubResource("shape1")
```

- [ ] **Step 3: Skapa `entities/ground_item.gd`**

```gdscript
class_name GroundItem
extends Node2D
## Lootpåse på marken. Klick = plocka allt.

var contents: Array = []

func setup(drops: Array, t: Vector2i) -> void:
	contents = drops
	position = Vector2(t) * 32 + Vector2(16, 16)
	var icon := Polygon2D.new()
	icon.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -8), Vector2(6, 0), Vector2(0, 8)])
	icon.color = Color("e8c84a")
	add_child(icon)
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(20, 20)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - int(position.x / 32)), absi(GameState.player_tile.y - int(position.y / 32)))
		if pdist <= 1:
			for d in contents:
				GameState.add_item(d["item"], d["qty"])
			queue_free()
```

- [ ] **Step 4: Commit** — `git commit -am "feat: monster med AI, strid, loot, respawn"`

---

### Task 10: Targeting + auto-attack i spelaren

**Files:**
- Modify: `entities/player/player.gd`

- [ ] **Step 1: Lägg till targeting/attack i `player.gd`**

Lägg till efter `var facing := Vector2i.DOWN`:

```gdscript
var target: Node2D = null
var _attack_timer := 0.0
const ATTACK_COOLDOWN := 1.0

func set_target(m: Node2D) -> void:
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	target = m
	if target:
		target.modulate = Color(1.4, 0.9, 0.9)   # röd markering som Tibia
```

Lägg till sist i `_process` (efter rörelseblocket — attack sker även under rörelse, som Tibia):

```gdscript
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target and is_instance_valid(target) and not target.dead and _attack_timer <= 0.0:
		var dist := maxi(absi(target.tile.x - tile.x), absi(target.tile.y - tile.y))
		if dist <= 1:
			_attack_timer = ATTACK_COOLDOWN
			var weapon: Dictionary = ItemDB.items[GameState.equipped_weapon]
			var dmg := CombatFormulas.roll_melee(GameState.level, GameState.skills["sword"]["level"], int(weapon["atk"]))
			target.take_damage(dmg)
			GameState.gain_skill_xp("sword", 1)
```

OBS: flytta `return`-satsen i rörelse-lerp-blocket så att attacklogiken alltid körs — strukturen blir:

```gdscript
func _process(delta: float) -> void:
	_update_movement(delta)      # tidigare rörelsekod, utan attack
	_update_attack(delta)        # nya attackkoden ovan
```

Refaktorera till två privata metoder exakt så.

- [ ] **Step 2: Manuellt speltest**

```powershell
& $GODOT --path C:\Users\Hem\tibia2d res://world/game.tscn
```

(HUD-scenen finns inte ännu — kommentera tillfälligt bort HUD-raden i `game_root.gd` om den felar, återställ i Task 11.)

Verifiera: gå runt i stan med WASD, väggar blockerar, kliv på portalen → grottan laddas, klicka på en Orm → röd markering → gå intill → den tar skada varje sekund → dör → XP + lootpåse → klicka påsen → guld.

- [ ] **Step 3: Commit** — `git commit -am "feat: targeting + auto-attack (Tibia-stil)"`

---

### Task 11: HUD — bars, guld, inventory, F1-potion

**Files:**
- Create: `ui/hud.gd`, `ui/hud.tscn`

- [ ] **Step 1: Skapa `ui/hud.tscn`**

```ini
[gd_scene load_steps=2 format=3 uid="uid://hud0000001"]

[ext_resource type="Script" path="res://ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="HpBack" type="ColorRect" parent="."]
offset_left = 16.0
offset_top = 16.0
offset_right = 216.0
offset_bottom = 30.0
color = Color(0.2, 0.05, 0.05, 0.85)

[node name="HpBar" type="ColorRect" parent="."]
offset_left = 16.0
offset_top = 16.0
offset_right = 216.0
offset_bottom = 30.0
color = Color(0.8, 0.15, 0.15, 1)

[node name="ManaBack" type="ColorRect" parent="."]
offset_left = 16.0
offset_top = 34.0
offset_right = 216.0
offset_bottom = 48.0
color = Color(0.05, 0.05, 0.2, 0.85)

[node name="ManaBar" type="ColorRect" parent="."]
offset_left = 16.0
offset_top = 34.0
offset_right = 216.0
offset_bottom = 48.0
color = Color(0.2, 0.3, 0.9, 1)

[node name="StatsLabel" type="Label" parent="."]
offset_left = 16.0
offset_top = 52.0
offset_right = 400.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 12

[node name="InventoryPanel" type="PanelContainer" parent="."]
visible = false
offset_left = 16.0
offset_top = 80.0
offset_right = 220.0
offset_bottom = 300.0

[node name="InvList" type="Label" parent="InventoryPanel"]
theme_override_font_sizes/font_size = 12

[node name="DeathLabel" type="Label" parent="."]
visible = false
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
text = "Du dog! Tryck Enter."
theme_override_font_sizes/font_size = 32
```

- [ ] **Step 2: Skapa `ui/hud.gd`**

```gdscript
extends CanvasLayer

@onready var hp_bar: ColorRect = $HpBar
@onready var mana_bar: ColorRect = $ManaBar
@onready var stats: Label = $StatsLabel
@onready var inv_panel: PanelContainer = $InventoryPanel
@onready var inv_list: Label = $InventoryPanel/InvList
@onready var death_lbl: Label = $DeathLabel

func _ready() -> void:
	GameState.hp_changed.connect(func(_h, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.player_died.connect(_on_death)
	_refresh()
	_refresh_inv()

func _refresh() -> void:
	hp_bar.size.x = 200.0 * (GameState.health / GameState.max_health)
	mana_bar.size.x = 200.0 * (GameState.mana / GameState.max_mana)
	stats.text = "Lv %d  XP %d/%d  Guld %d  Svärd %d  Sköld %d" % [
		GameState.level, GameState.experience, GameState.xp_to_next, GameState.gold,
		GameState.skills["sword"]["level"], GameState.skills["shielding"]["level"]]

func _refresh_inv() -> void:
	var lines: Array = []
	for id in GameState.inventory:
		lines.append("%s x%d" % [ItemDB.items[id]["name"], GameState.inventory[id]])
	inv_list.text = "\n".join(lines) if lines else "(tomt)"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inv_panel.visible = not inv_panel.visible
	elif event.is_action_pressed("hotkey_1"):
		if GameState.remove_item("health_potion", 1):
			GameState.heal(float(ItemDB.items["health_potion"]["heal"]))
	elif death_lbl.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_respawn()

func _on_death() -> void:
	death_lbl.visible = true
	get_tree().paused = true

func _respawn() -> void:
	get_tree().paused = false
	death_lbl.visible = false
	GameState.health = GameState.max_health
	GameState.experience = int(GameState.experience * 0.9)   # Tibia: XP-förlust vid död
	World.start_game("town")
```

(`death_lbl`/HUD måste fungera pausad: sätt `process_mode = PROCESS_MODE_ALWAYS` på HUD-noden i `_ready`: `process_mode = Node.PROCESS_MODE_ALWAYS`.)

- [ ] **Step 3: Manuellt speltest** — bars uppdateras i strid, I öppnar inventory, F1 dricker potion (skaffa en från Skelett/Ghoul-loot), död → Enter → respawn i stan.

- [ ] **Step 4: Commit** — `git commit -am "feat: HUD med bars, inventory, F1-potion, död/respawn"`

---

### Task 12: SaveManager — spara/ladda + autosave

**Files:**
- Modify: `autoload/save_manager.gd`
- Test: `tests/unit/test_save.gd`

- [ ] **Step 1: Skriv failande test**

```gdscript
extends GutTest

var sm

func before_each():
	sm = load("res://autoload/save_manager.gd").new()
	sm.save_path = "user://test_save.json"

func after_each():
	sm.free()
	DirAccess.remove_absolute("user://test_save.json")

func test_roundtrip_preserves_state():
	var snap = {"version": 1, "level": 7, "gold": 123, "inventory": {"bone_chips": 4},
		"skills": {"sword": {"level": 22, "xp": 10}}, "zone": "cave"}
	sm.write_snapshot(snap)
	var loaded = sm.read_snapshot()
	assert_eq(int(loaded["level"]), 7)
	assert_eq(int(loaded["gold"]), 123)
	assert_eq(int(loaded["inventory"]["bone_chips"]), 4)
	assert_eq(loaded["zone"], "cave")

func test_read_missing_returns_empty():
	assert_eq(sm.read_snapshot(), {})
```

- [ ] **Step 2: Kör — förvänta FAIL**

- [ ] **Step 3: Implementera `autoload/save_manager.gd`**

```gdscript
extends Node
## Autoload: SaveManager. JSON-sparfil + autosave var 60 s.

const SAVE_VERSION := 1
var save_path := "user://save.json"
var _timer := 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 60.0:
		_timer = 0.0
		if World.player != null:
			save_game()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func write_snapshot(snap: Dictionary) -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))

func read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func save_game() -> void:
	write_snapshot({
		"version": SAVE_VERSION,
		"name": GameState.player_name,
		"level": GameState.level, "experience": GameState.experience,
		"xp_to_next": GameState.xp_to_next,
		"health": GameState.health, "max_health": GameState.max_health,
		"mana": GameState.mana, "max_mana": GameState.max_mana,
		"gold": GameState.gold, "inventory": GameState.inventory,
		"skills": GameState.skills, "appearance": GameState.appearance,
		"equipped_weapon": GameState.equipped_weapon,
		"zone": GameState.current_zone,
		"tile": [GameState.player_tile.x, GameState.player_tile.y],
	})

func load_game() -> bool:
	var s := read_snapshot()
	if s.is_empty():
		return false
	GameState.player_name = s.get("name", "Hjälte")
	GameState.level = int(s["level"]); GameState.experience = int(s["experience"])
	GameState.xp_to_next = int(s["xp_to_next"])
	GameState.health = float(s["health"]); GameState.max_health = float(s["max_health"])
	GameState.mana = float(s["mana"]); GameState.max_mana = float(s["max_mana"])
	GameState.gold = int(s["gold"]); GameState.inventory = s["inventory"]
	GameState.skills = s["skills"]; GameState.appearance = s["appearance"]
	GameState.equipped_weapon = s.get("equipped_weapon", "rusty_sword")
	GameState.current_zone = s.get("zone", "town")
	var t: Array = s.get("tile", [-1, -1])
	GameState.player_tile = Vector2i(int(t[0]), int(t[1]))
	return true
```

- [ ] **Step 4: Kör tester — förvänta PASS**

- [ ] **Step 5: Commit** — `git commit -am "feat: SaveManager med autosave (TDD)"`

---

### Task 13: Main menu + character creation

**Files:**
- Create: `ui/main_menu.gd`, `ui/main_menu.tscn`, `ui/character_creator.gd`, `ui/character_creator.tscn`

- [ ] **Step 1: Skapa `ui/main_menu.tscn` + `.gd`**

```gdscript
# ui/main_menu.gd
extends Control

func _ready() -> void:
	$VBox/ContinueBtn.disabled = not SaveManager.has_save()
	$VBox/NewBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/character_creator.tscn"))
	$VBox/ContinueBtn.pressed.connect(_continue)

func _continue() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file("res://world/game.tscn")
```

```ini
[gd_scene load_steps=2 format=3 uid="uid://menu000001"]

[ext_resource type="Script" path="res://ui/main_menu.gd" id="1"]

[node name="MainMenu" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="VBox" type="VBoxContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = 60.0

[node name="Title" type="Label" parent="VBox"]
text = "TIBIA2D"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 36

[node name="NewBtn" type="Button" parent="VBox"]
text = "Nytt spel"

[node name="ContinueBtn" type="Button" parent="VBox"]
text = "Fortsätt"
```

(Obs: `game_root.gd` använder `GameState.current_zone` och vid laddad save ska spelaren placeras på sparad tile — uppdatera `game_root.gd`:s `_ready` till: `World.start_game(GameState.current_zone, GameState.player_tile if SaveManager.has_save() and GameState.player_tile != Vector2i.ZERO else Vector2i(-1, -1))`.)

- [ ] **Step 2: Skapa `ui/character_creator.gd` + `.tscn`**

OSRS-stil: namn + färgval, förhandsvisning med paper-doll. ColorPickerButtons för hud/hår/tröja/byxor.

```gdscript
# ui/character_creator.gd
extends Control

@onready var preview: CharacterVisual = $Preview

func _ready() -> void:
	preview.scale = Vector2(4, 4)
	preview.apply_appearance(GameState.appearance)
	for key in ["skin", "hair", "shirt", "pants"]:
		var btn: ColorPickerButton = get_node("VBox/%sRow/Picker" % key.capitalize())
		btn.color = Color(GameState.appearance[key])
		btn.color_changed.connect(func(c: Color):
			GameState.appearance[key] = "#" + c.to_html(false)
			preview.apply_appearance(GameState.appearance))
	$VBox/StartBtn.pressed.connect(_start)

func _start() -> void:
	var n: String = $VBox/NameRow/NameEdit.text.strip_edges()
	GameState.player_name = n if n != "" else "Hjälte"
	GameState.current_zone = "town"
	GameState.player_tile = Vector2i.ZERO
	get_tree().change_scene_to_file("res://world/game.tscn")
```

```ini
[gd_scene load_steps=3 format=3 uid="uid://chargen0001"]

[ext_resource type="Script" path="res://ui/character_creator.gd" id="1"]
[ext_resource type="Script" path="res://entities/player/character_visual.gd" id="2"]

[node name="CharacterCreator" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Preview" type="Node2D" parent="."]
position = Vector2(880, 360)
script = ExtResource("2")

[node name="VBox" type="VBoxContainer" parent="."]
offset_left = 100.0
offset_top = 100.0
offset_right = 480.0
offset_bottom = 620.0

[node name="Header" type="Label" parent="VBox"]
text = "Skapa din karaktär"
theme_override_font_sizes/font_size = 28

[node name="NameRow" type="HBoxContainer" parent="VBox"]

[node name="NameLbl" type="Label" parent="VBox/NameRow"]
text = "Namn:  "

[node name="NameEdit" type="LineEdit" parent="VBox/NameRow"]
custom_minimum_size = Vector2(200, 0)

[node name="SkinRow" type="HBoxContainer" parent="VBox"]

[node name="Lbl" type="Label" parent="VBox/SkinRow"]
text = "Hudfärg:  "

[node name="Picker" type="ColorPickerButton" parent="VBox/SkinRow"]
custom_minimum_size = Vector2(60, 28)

[node name="HairRow" type="HBoxContainer" parent="VBox"]

[node name="Lbl" type="Label" parent="VBox/HairRow"]
text = "Hårfärg:  "

[node name="Picker" type="ColorPickerButton" parent="VBox/HairRow"]
custom_minimum_size = Vector2(60, 28)

[node name="ShirtRow" type="HBoxContainer" parent="VBox"]

[node name="Lbl" type="Label" parent="VBox/ShirtRow"]
text = "Tröja:  "

[node name="Picker" type="ColorPickerButton" parent="VBox/ShirtRow"]
custom_minimum_size = Vector2(60, 28)

[node name="PantsRow" type="HBoxContainer" parent="VBox"]

[node name="Lbl" type="Label" parent="VBox/PantsRow"]
text = "Byxor:  "

[node name="Picker" type="ColorPickerButton" parent="VBox/PantsRow"]
custom_minimum_size = Vector2(60, 28)

[node name="StartBtn" type="Button" parent="VBox"]
text = "Börja äventyret!"
```

(Obs nodnamn: `get_node("VBox/%sRow/Picker" % key.capitalize())` ger `VBox/SkinRow/Picker` osv — matchar scenen.)

- [ ] **Step 3: Manuellt speltest** — Nytt spel → ändra färger → förhandsvisning uppdateras → Börja → stan, karaktären har valda färger. Spela, dö/byt zon, stäng spelet, starta om → Fortsätt → allt återställt.

- [ ] **Step 4: Commit** — `git commit -am "feat: huvudmeny + character creation (OSRS-stil)"`

---

### Task 14: Prestandaverifiering — 50 monster @ 60 FPS

**Files:**
- Modify: `world/game_root.gd`

- [ ] **Step 1: Lägg till debugspawn + FPS-logg i `game_root.gd`**

```gdscript
var _fps_log_timer := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		var origin: Vector2i = GameState.player_tile
		var spawned := 0
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				if spawned >= 50: break
				var t := origin + Vector2i(dx, dy)
				if World.current_zone.is_walkable(t) and t != origin:
					World.spawn_monster("Råtta", t)
					spawned += 1
		print("DEBUG: spawnade %d råttor" % spawned)

func _process(delta: float) -> void:
	_fps_log_timer += delta
	if _fps_log_timer >= 2.0:
		_fps_log_timer = 0.0
		print("FPS: %d  Noder: %d" % [Engine.get_frames_per_second(), get_tree().get_node_count()])
```

- [ ] **Step 2: Mät**

Starta spelet, tryck F12 i grottan, jaga runt med 50 råttor efter dig. Läs FPS-loggen i konsolen.

Expected: **stabil 60 FPS**. Om inte: profilera innan vidare arbete (acceptanskrav från specen).

- [ ] **Step 3: Ta bort/behåll** — behåll debugkoden (nyttig framåt) men byt `print` till `print_debug`.

- [ ] **Step 4: Commit + tagga milstolpen**

```powershell
git add -A; git commit -m "feat: prestandaverifiering 50 monster @ 60 FPS"
git tag m1-spelbar-karna
```

---

## Acceptanskriterier (milstolpe 1 klar när allt stämmer)

- [ ] Nytt spel → character creation → stan; Fortsätt → laddar save
- [ ] WASD-rörelse tile för tile, väggar/vatten blockerar
- [ ] Portal stad ↔ grotta fungerar åt båda håll
- [ ] 5 monstertyper spawnar enligt zonkartorna och respawnar
- [ ] Klick-target + auto-attack; monster jagar via A*, slår tillbaka
- [ ] Sword/shielding-skills tränas; XP/level/HP växer; död → respawn med XP-förlust
- [ ] Loot droppar, plockas, guld räknas; F1 dricker potion
- [ ] Autosave + save vid zonbyte; allt överlever omstart
- [ ] Alla GUT-tester gröna; 60 FPS med 50 monster



