# Tibia2D Milstolpe 2 — Skillsystem: Implementationsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alla 18 skills registrerade och synliga; gathering (mining/fishing/woodcutting/herbalism) med noder i världen, crafting (smithing/cooking/alchemy/runecrafting) vid stationer, butiks-NPC, vapenskills, buffsystem, ny skogszon, save-migrering v2.

**Architecture:** Generalisera på plats (spec-beslut): skills laddas från `data/skills.json` i GameState, noder/stationer/butik är klickbara entity-scener spawnade via zon-legend (samma mönster som monster-spawns), recept/noddata i JSON laddade av ItemDB. Inga nya autoloads.

**Tech Stack:** Godot 4.6.2 (`C:\Godot\Godot_v4.6.2-stable_win64.exe`), GDScript, GUT 9.6.0, JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-11-milstolpe-2-skillsystem-design.md`

**Viktiga kommandon:**
```bash
# Tester (bash — PowerShell-redirect sväljer Godot-output):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
# Re-import (krävs efter nya class_name/scener, annars "Could not find type"-parse-fel):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
# Starta spelet direkt i världen:
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --path /c/Users/Hem/tibia2d res://world/game.tscn
```

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/skills.json` | Skapa | 18 skilldefinitioner (kategori, xp_base, xp_growth, start_level) |
| `data/items.json` | Ersätt | +verktyg, råvaror, craftade varor, `skill`-fält på vapen, `buff`-fält |
| `data/recipes.json` | Skapa | Recept per stationstyp |
| `data/nodes.json` | Skapa | Gathering-nodtyper |
| `data/zones/forest.json` | Skapa | Skogszonen |
| `data/zones/town.json` | Ersätt | +portal till skogen, stationer, butik |
| `data/zones/cave.json` | Ersätt | +malmådror |
| `autoload/game_state.gd` | Modifiera | Skills från JSON, buffs, equip, butik, use_item |
| `autoload/item_db.gd` | Modifiera | Laddar även recipes.json + nodes.json |
| `autoload/world.gd` | Modifiera | Spawnar noder/stationer/butik, `hud`-referens |
| `world/zone.gd` | Modifiera | Legend-typer node/station/shop, `find_path_adjacent` |
| `entities/gather_node.gd/.tscn` | Skapa | Generisk gathering-nod |
| `entities/crafting_station.gd/.tscn` | Skapa | Klickbar station → receptpanel |
| `entities/shop_npc.gd/.tscn` | Skapa | Klickbar NPC → butikspanel |
| `entities/player/player.gd` | Modifiera | Auto-walk, gathering-loop, vapenskill-attack |
| `entities/monster/monster.gd` | Modifiera | Shielding via effective_skill_level |
| `autoload/save_manager.gd` | Modifiera | SAVE_VERSION 2 + migrering |
| `ui/hud.gd/.tscn` | Modifiera | Förenklad statsrad, buffvisning, meddelanden, interaktivt inventory |
| `ui/skill_panel.gd` | Skapa | K-panel med alla 18 skills |
| `ui/recipe_panel.gd` | Skapa | Receptpanel per station |
| `ui/shop_panel.gd` | Skapa | Köp/sälj-panel |
| `project.godot` | Modifiera | Input-action `toggle_skills` (K) |
| `tests/unit/test_skills.gd` | Skapa | Skillladdning, XP-kurvor, equip, vapenskill |
| `tests/unit/test_buffs.gd` | Skapa | Buff-applicering/expiry/regen/effective level |
| `tests/unit/test_recipes.gd` | Skapa | can_craft, ingredienser, datavalidering |
| `tests/unit/test_gather_node.gd` | Skapa | Chansformel, gating, laddningar |
| `tests/unit/test_shop.gd` | Skapa | buy_item/sell_item |
| `tests/unit/test_zone.gd` | Modifiera | +legend-parsing, find_path_adjacent |
| `tests/unit/test_save.gd` | Modifiera | +v1→v2-migrering |

---

### Task 0: Branch

- [ ] **Step 1: Skapa feature-branch**

```powershell
git -C C:\Users\Hem\tibia2d checkout -b m2-skillsystem
```

---

### Task 1: skills.json + GameState laddar skills från JSON

**Files:**
- Create: `data/skills.json`
- Modify: `autoload/game_state.gd`
- Test: `tests/unit/test_skills.gd`

- [ ] **Step 1: Skapa `data/skills.json`**

```json
{
	"sword":        {"name": "Sword",        "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 10},
	"axe":          {"name": "Axe",          "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"club":         {"name": "Club",         "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"fist":         {"name": "Fist",         "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"distance":     {"name": "Distance",     "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"shielding":    {"name": "Shielding",    "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 10},
	"magic":        {"name": "Magic Level",  "category": "combat",    "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"mining":       {"name": "Mining",       "category": "gathering", "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"fishing":      {"name": "Fishing",      "category": "gathering", "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"woodcutting":  {"name": "Woodcutting",  "category": "gathering", "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"herbalism":    {"name": "Herbalism",    "category": "gathering", "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"smithing":     {"name": "Smithing",     "category": "crafting",  "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"cooking":      {"name": "Cooking",      "category": "crafting",  "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"alchemy":      {"name": "Alchemy",      "category": "crafting",  "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"runecrafting": {"name": "Runecrafting", "category": "crafting",  "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"agility":      {"name": "Agility",      "category": "utility",   "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"thieving":     {"name": "Thieving",     "category": "utility",   "xp_base": 50, "xp_growth": 1.1, "start_level": 1},
	"slayer":       {"name": "Slayer",       "category": "utility",   "xp_base": 50, "xp_growth": 1.1, "start_level": 1}
}
```

- [ ] **Step 2: Skriv failande test `tests/unit/test_skills.gd`**

```gdscript
extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_loads_18_skills_from_json():
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skill_defs.size(), 18)

func test_start_levels():
	assert_eq(gs.skills["sword"]["level"], 10)
	assert_eq(gs.skills["shielding"]["level"], 10)
	assert_eq(gs.skills["mining"]["level"], 1)

func test_categories():
	assert_eq(gs.skill_defs["mining"]["category"], "gathering")
	assert_eq(gs.skill_defs["smithing"]["category"], "crafting")
	assert_eq(gs.skill_defs["slayer"]["category"], "utility")

func test_gain_skill_xp_emits_skill_changed():
	watch_signals(gs)
	gs.gain_skill_xp("mining", 10)
	assert_signal_emitted_with_parameters(gs, "skill_changed", ["mining"])

func test_ensure_all_skills_preserves_existing():
	gs.skills = {"sword": {"level": 25, "xp": 7}}
	gs.ensure_all_skills()
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skills["sword"]["level"], 25)
	assert_eq(gs.skills["sword"]["xp"], 7)
```

- [ ] **Step 3: Kör — förvänta FAIL** (skill_defs finns inte)

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
```

- [ ] **Step 4: Modifiera `autoload/game_state.gd`**

Lägg till signal efter `signal player_died`:

```gdscript
signal skill_changed(skill: String)
signal buffs_changed
```

Ersätt den hårdkodade skills-initialiseringen:

```gdscript
var skills: Dictionary = {
	"sword":     {"level": 10, "xp": 0},
	"shielding": {"level": 10, "xp": 0},
}
```

med:

```gdscript
var skills: Dictionary = {}
var skill_defs: Dictionary = {}

func _init() -> void:
	_load_skills()

func _load_skills() -> void:
	var f := FileAccess.open("res://data/skills.json", FileAccess.READ)
	skill_defs = JSON.parse_string(f.get_as_text())
	ensure_all_skills()

func ensure_all_skills() -> void:
	for id in skill_defs:
		if not skills.has(id):
			skills[id] = {"level": int(skill_defs[id].get("start_level", 1)), "xp": 0}
```

Ersätt `skill_xp_next` och `gain_skill_xp` med per-skill-kurva (befintligt test `test_skill_xp_next_formula` fortsätter fungera — default-argumentet ger samma kurva):

```gdscript
func skill_xp_next(skill_level: int, skill_id := "") -> int:
	var base := SKILL_XP_BASE
	var growth := SKILL_XP_GROWTH
	if skill_defs.has(skill_id):
		base = float(skill_defs[skill_id].get("xp_base", SKILL_XP_BASE))
		growth = float(skill_defs[skill_id].get("xp_growth", SKILL_XP_GROWTH))
	return int(base * pow(growth, skill_level))

func gain_skill_xp(skill: String, amount: int) -> void:
	if not skills.has(skill):
		return
	var s: Dictionary = skills[skill]
	s["xp"] += amount
	while s["xp"] >= skill_xp_next(s["level"], skill):
		s["xp"] -= skill_xp_next(s["level"], skill)
		s["level"] += 1
	skill_changed.emit(skill)
```

- [ ] **Step 5: Kör tester — förvänta PASS** (samma kommando; alla gamla + nya gröna)

- [ ] **Step 6: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: 18 skills laddas från skills.json (TDD)"
```

---

### Task 2: items.json-utökning + ItemDB laddar recipes/nodes

**Files:**
- Replace: `data/items.json`
- Create: `data/recipes.json`, `data/nodes.json`
- Modify: `autoload/item_db.gd`
- Test: `tests/unit/test_recipes.gd` (datavalidering), `tests/unit/test_databases.gd` (oförändrad, ska förbli grön)

- [ ] **Step 1: Ersätt `data/items.json` med komplett ny fil**

```json
{
	"iron_coin":       {"name": "Järnmynt",        "type": "currency", "value": 1,   "color": "#c8a838"},
	"health_potion":   {"name": "Hälsodryck",      "type": "potion",   "value": 45,  "color": "#d03030", "heal": 60},
	"snake_skin":      {"name": "Ormskinn",        "type": "junk",     "value": 8,   "color": "#608830"},
	"spider_silk":     {"name": "Spindelsilke",    "type": "junk",     "value": 12,  "color": "#d8d8e8"},
	"bone_chips":      {"name": "Benbitar",        "type": "junk",     "value": 10,  "color": "#e0dcc8"},
	"ghoul_hand":      {"name": "Ghoulhand",       "type": "junk",     "value": 25,  "color": "#5a7848"},
	"rusty_sword":     {"name": "Rostigt svärd",   "type": "weapon",   "value": 30,  "color": "#907860", "atk": 8,  "skill": "sword"},
	"iron_sword":      {"name": "Järnsvärd",       "type": "weapon",   "value": 150, "color": "#b0b8c0", "atk": 14, "skill": "sword"},
	"steel_sword":     {"name": "Stålsvärd",       "type": "weapon",   "value": 320, "color": "#dce4ec", "atk": 18, "skill": "sword"},
	"bronze_axe":      {"name": "Bronsyxa",        "type": "weapon",   "value": 40,  "color": "#a87444", "atk": 7,  "skill": "axe"},
	"wooden_club":     {"name": "Träklubba",       "type": "weapon",   "value": 25,  "color": "#8a6a3c", "atk": 6,  "skill": "club"},
	"pickaxe":         {"name": "Hacka",           "type": "tool",     "value": 75,  "color": "#9a9aa2", "tool": true},
	"hatchet":         {"name": "Yxa (verktyg)",   "type": "tool",     "value": 75,  "color": "#b09060", "tool": true},
	"fishing_rod":     {"name": "Fiskespö",        "type": "tool",     "value": 60,  "color": "#c0a878", "tool": true},
	"sickle":          {"name": "Skära",           "type": "tool",     "value": 60,  "color": "#c8c8d0", "tool": true},
	"copper_ore":      {"name": "Kopparmalm",      "type": "material", "value": 12,  "color": "#b87333"},
	"iron_ore":        {"name": "Järnmalm",        "type": "material", "value": 25,  "color": "#8c8c94"},
	"gold_ore":        {"name": "Guldmalm",        "type": "material", "value": 60,  "color": "#e8c84a"},
	"log":             {"name": "Stock",           "type": "material", "value": 8,   "color": "#7a5a34"},
	"oak_log":         {"name": "Ekstock",         "type": "material", "value": 20,  "color": "#6a4a28"},
	"willow_log":      {"name": "Pilstock",        "type": "material", "value": 45,  "color": "#8a7a4c"},
	"raw_trout":       {"name": "Rå öring",        "type": "material", "value": 10,  "color": "#c08898"},
	"raw_pike":        {"name": "Rå gädda",        "type": "material", "value": 22,  "color": "#90a878"},
	"mint_herb":       {"name": "Mynta",           "type": "material", "value": 9,   "color": "#58b868"},
	"nightshade_herb": {"name": "Nattskatta",      "type": "material", "value": 18,  "color": "#6a4a8a"},
	"empty_vial":      {"name": "Tom flaska",      "type": "material", "value": 5,   "color": "#c8d8e0"},
	"copper_plate":    {"name": "Kopparharnesk",   "type": "armor",    "value": 90,  "color": "#b87333", "armor": 4},
	"cooked_trout":    {"name": "Stekt öring",     "type": "food",     "value": 18,  "color": "#d8a878", "heal": 40},
	"fish_stew":       {"name": "Fiskgryta",       "type": "food",     "value": 35,  "color": "#c89868", "heal": 30, "buff": {"stat": "regen", "amount": 2, "duration": 30}},
	"mana_potion":     {"name": "Manadryck",       "type": "potion",   "value": 55,  "color": "#3050d0", "mana": 50},
	"mining_brew":     {"name": "Gruvbrygd",       "type": "potion",   "value": 70,  "color": "#a88030", "buff": {"stat": "skill:mining", "amount": 2, "duration": 60}},
	"attack_rune":     {"name": "Attackruna",      "type": "rune",     "value": 30,  "color": "#d04848"}
}
```

(Obs: `copper_plate` är craft-för-sälj i M2 — rustnings-equip kommer i senare milstolpe. `attack_rune` blir kastbar när Magic byggs i M3+.)

- [ ] **Step 2: Skapa `data/recipes.json`**

```json
{
	"anvil": [
		{"id": "copper_plate", "level": 5,  "skill": "smithing", "ingredients": {"copper_ore": 3},                 "xp": 20},
		{"id": "iron_sword",   "level": 8,  "skill": "smithing", "ingredients": {"iron_ore": 2},                   "xp": 25},
		{"id": "steel_sword",  "level": 15, "skill": "smithing", "ingredients": {"iron_ore": 3, "copper_ore": 1},  "xp": 40}
	],
	"stove": [
		{"id": "cooked_trout", "level": 1,  "skill": "cooking", "ingredients": {"raw_trout": 1},                                     "xp": 10},
		{"id": "fish_stew",    "level": 10, "skill": "cooking", "ingredients": {"raw_trout": 1, "raw_pike": 1, "mint_herb": 1},      "xp": 25}
	],
	"alchemy_table": [
		{"id": "health_potion", "level": 1,  "skill": "alchemy", "ingredients": {"mint_herb": 2, "empty_vial": 1},                          "xp": 12},
		{"id": "mana_potion",   "level": 8,  "skill": "alchemy", "ingredients": {"nightshade_herb": 1, "empty_vial": 1},                    "xp": 18},
		{"id": "mining_brew",   "level": 15, "skill": "alchemy", "ingredients": {"nightshade_herb": 2, "mint_herb": 1, "empty_vial": 1},    "xp": 30}
	],
	"rune_altar": [
		{"id": "attack_rune", "level": 1, "skill": "runecrafting", "ingredients": {"bone_chips": 2, "spider_silk": 1}, "xp": 15}
	]
}
```

- [ ] **Step 3: Skapa `data/nodes.json`**

```json
{
	"copper_vein":      {"skill": "mining",      "level": 1,  "tool": "pickaxe",     "yields": "copper_ore",      "xp": 15, "charges": [3, 5], "respawn": 30, "color": "#b87333", "label": "Kopparådra"},
	"iron_vein":        {"skill": "mining",      "level": 15, "tool": "pickaxe",     "yields": "iron_ore",        "xp": 30, "charges": [3, 5], "respawn": 45, "color": "#8c8c94", "label": "Järnådra"},
	"gold_vein":        {"skill": "mining",      "level": 30, "tool": "pickaxe",     "yields": "gold_ore",        "xp": 60, "charges": [3, 4], "respawn": 60, "color": "#e8c84a", "label": "Guldådra"},
	"tree":             {"skill": "woodcutting", "level": 1,  "tool": "hatchet",     "yields": "log",             "xp": 15, "charges": [4, 6], "respawn": 20, "color": "#2e6b1e", "label": "Träd"},
	"oak_tree":         {"skill": "woodcutting", "level": 15, "tool": "hatchet",     "yields": "oak_log",         "xp": 30, "charges": [4, 6], "respawn": 35, "color": "#1e4b14", "label": "Ek"},
	"willow_tree":      {"skill": "woodcutting", "level": 30, "tool": "hatchet",     "yields": "willow_log",      "xp": 60, "charges": [3, 5], "respawn": 50, "color": "#5a7a3c", "label": "Pil"},
	"fishing_spot":     {"skill": "fishing",     "level": 1,  "tool": "fishing_rod", "yields": "raw_trout",       "xp": 15, "charges": [5, 8], "respawn": 25, "color": "#4a90c8", "label": "Fiskestim"},
	"pike_spot":        {"skill": "fishing",     "level": 15, "tool": "fishing_rod", "yields": "raw_pike",        "xp": 30, "charges": [4, 6], "respawn": 40, "color": "#3a70a8", "label": "Gäddstim"},
	"mint_patch":       {"skill": "herbalism",   "level": 1,  "tool": "sickle",      "yields": "mint_herb",       "xp": 15, "charges": [3, 4], "respawn": 25, "color": "#58b868", "label": "Mynta"},
	"nightshade_patch": {"skill": "herbalism",   "level": 15, "tool": "sickle",      "yields": "nightshade_herb", "xp": 30, "charges": [2, 4], "respawn": 45, "color": "#6a4a8a", "label": "Nattskatta"}
}
```

- [ ] **Step 4: Skriv failande test `tests/unit/test_recipes.gd`** (datavalidering + ItemDB-laddning; can_craft-logik kommer i Task 4 — lägg bara dessa tester nu)

```gdscript
extends GutTest

var db

func before_each():
	db = load("res://autoload/item_db.gd").new()
	db._load()

func after_each():
	db.free()

func test_recipes_loaded_for_all_station_types():
	for station in ["anvil", "stove", "alchemy_table", "rune_altar"]:
		assert_true(db.recipes.has(station), station)
		assert_gt(db.recipes[station].size(), 0, station)

func test_all_recipe_outputs_and_ingredients_exist_as_items():
	for station in db.recipes:
		for r in db.recipes[station]:
			assert_true(db.items.has(r["id"]), "saknat resultat-item: " + str(r["id"]))
			for ing in r["ingredients"]:
				assert_true(db.items.has(ing), "saknad ingrediens: " + str(ing))

func test_all_node_yields_and_tools_exist_as_items():
	for nid in db.nodes:
		assert_true(db.items.has(db.nodes[nid]["yields"]), nid)
		assert_true(db.items.has(db.nodes[nid]["tool"]), nid)

func test_weapons_have_skill_field():
	for id in db.items:
		if db.items[id].get("type") == "weapon":
			assert_true(db.items[id].has("skill"), id)
```

- [ ] **Step 5: Kör — förvänta FAIL** (`db.recipes` finns inte)

- [ ] **Step 6: Modifiera `autoload/item_db.gd`** — ersätt hela filen:

```gdscript
extends Node
## Autoload: ItemDB. Laddar items, recept och gathering-nodtyper.

var items: Dictionary = {}
var recipes: Dictionary = {}
var nodes: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	items = _read_json("res://data/items.json")
	recipes = _read_json("res://data/recipes.json")
	nodes = _read_json("res://data/nodes.json")

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func roll_loot(loot_table: Array) -> Array:
	var result: Array = []
	for entry in loot_table:
		if randf() <= float(entry["chance"]):
			result.append({"item": entry["item"], "qty": randi_range(int(entry["min"]), int(entry["max"]))})
	return result
```

- [ ] **Step 7: Kör tester — förvänta PASS**

- [ ] **Step 8: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: items/recipes/nodes-data + ItemDB laddar allt (TDD)"
```

---

### Task 3: Buffsystem i GameState

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/unit/test_buffs.gd`

- [ ] **Step 1: Skriv failande test `tests/unit/test_buffs.gd`**

```gdscript
extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_apply_buff_adds_to_active():
	gs.apply_buff("skill:mining", 2, 60)
	assert_eq(gs.active_buffs.size(), 1)

func test_same_stat_replaces():
	gs.apply_buff("skill:mining", 2, 60)
	gs.apply_buff("skill:mining", 3, 30)
	assert_eq(gs.active_buffs.size(), 1)
	assert_eq(gs.active_buffs[0]["amount"], 3.0)

func test_effective_skill_level_includes_buff():
	gs.apply_buff("skill:mining", 2, 60)
	assert_eq(gs.effective_skill_level("mining"), 3)   # start 1 + 2
	assert_eq(gs.effective_skill_level("fishing"), 1)  # opåverkad

func test_buff_expires():
	gs.apply_buff("skill:mining", 2, 1.0)
	gs._tick_buffs(1.1)
	assert_eq(gs.active_buffs.size(), 0)
	assert_eq(gs.effective_skill_level("mining"), 1)

func test_regen_heals_over_time():
	gs.health = 100.0
	gs.apply_buff("regen", 2, 10)
	gs._tick_buffs(5.0)
	assert_almost_eq(gs.health, 110.0, 0.01)

func test_use_item_applies_buff_and_consumes():
	gs.add_item("mining_brew", 1)
	assert_true(gs.use_item("mining_brew"))
	assert_eq(gs.active_buffs.size(), 1)
	assert_false(gs.inventory.has("mining_brew"))

func test_use_item_heals():
	gs.health = 50.0
	gs.add_item("health_potion", 1)
	gs.use_item("health_potion")
	assert_eq(gs.health, 110.0)
```

- [ ] **Step 2: Kör — förvänta FAIL**

- [ ] **Step 3: Lägg till i `autoload/game_state.gd`** (efter inventory-funktionerna):

```gdscript
var active_buffs: Array = []   # [{stat, amount, time_left}]

func _process(delta: float) -> void:
	_tick_buffs(delta)

func apply_buff(stat: String, amount: float, duration: float) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i]["stat"] == stat:
			active_buffs.remove_at(i)
	active_buffs.append({"stat": stat, "amount": amount, "time_left": duration})
	buffs_changed.emit()

func _tick_buffs(delta: float) -> void:
	var changed := false
	for i in range(active_buffs.size() - 1, -1, -1):
		var b: Dictionary = active_buffs[i]
		if b["stat"] == "regen":
			heal(float(b["amount"]) * delta)
		b["time_left"] -= delta
		if b["time_left"] <= 0.0:
			active_buffs.remove_at(i)
			changed = true
	if changed:
		buffs_changed.emit()

func effective_skill_level(skill: String) -> int:
	var lvl := int(skills.get(skill, {"level": 1})["level"])
	for b in active_buffs:
		if String(b["stat"]) == "skill:" + skill:
			lvl += int(b["amount"])
	return lvl

func use_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) < 1:
		return false
	var d: Dictionary = ItemDB.items.get(item_id, {})
	var used := false
	if d.has("heal"):
		heal(float(d["heal"]))
		used = true
	if d.has("mana"):
		mana = minf(mana + float(d["mana"]), max_mana)
		mana_changed.emit(mana, max_mana)
		used = true
	if d.has("buff"):
		var b: Dictionary = d["buff"]
		apply_buff(String(b["stat"]), float(b["amount"]), float(b["duration"]))
		used = true
	if used:
		remove_item(item_id, 1)
	return used
```

(Obs: testerna instansierar GameState med `.new()` utan scenträd — `_process` körs inte automatiskt, därför testas `_tick_buffs` direkt. Autoload-instansen i spelet tickas av motorn. `use_item` läser ItemDB-autoloaden som är laddad i testkörningen.)

- [ ] **Step 4: Kör tester — förvänta PASS**

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: buffsystem med regen/skillbuffs/use_item (TDD)"
```

---

### Task 4: Recipes-logik + equip/butik i GameState

**Files:**
- Create: `crafting/recipes.gd`
- Modify: `autoload/game_state.gd`
- Test: `tests/unit/test_recipes.gd` (utöka), `tests/unit/test_shop.gd`, `tests/unit/test_skills.gd` (utöka)

- [ ] **Step 1: Utöka `tests/unit/test_recipes.gd`** — lägg till längst ner:

```gdscript
func _recipe(level := 5, ingredients := {"copper_ore": 3}) -> Dictionary:
	return {"id": "copper_plate", "level": level, "skill": "smithing", "ingredients": ingredients, "xp": 20}

func test_can_craft_true_when_level_and_ingredients_ok():
	assert_true(Recipes.can_craft(_recipe(), {"copper_ore": 3}, 5))

func test_can_craft_false_on_low_level():
	assert_false(Recipes.can_craft(_recipe(5), {"copper_ore": 3}, 4))

func test_can_craft_false_on_missing_ingredients():
	assert_false(Recipes.can_craft(_recipe(), {"copper_ore": 2}, 99))

func test_missing_ingredients_lists_shortfall():
	var missing = Recipes.missing_ingredients(_recipe(), {"copper_ore": 1})
	assert_eq(missing, {"copper_ore": 2})
```

- [ ] **Step 2: Utöka `tests/unit/test_skills.gd`** — lägg till längst ner:

```gdscript
func test_weapon_skill_follows_equipped():
	gs.equipped_weapon = "bronze_axe"
	assert_eq(gs.weapon_skill(), "axe")
	gs.equipped_weapon = "wooden_club"
	assert_eq(gs.weapon_skill(), "club")

func test_weapon_skill_fist_when_unarmed():
	gs.equipped_weapon = ""
	assert_eq(gs.weapon_skill(), "fist")

func test_equip_swaps_with_inventory():
	gs.equipped_weapon = "rusty_sword"
	gs.add_item("bronze_axe", 1)
	assert_true(gs.equip_weapon("bronze_axe"))
	assert_eq(gs.equipped_weapon, "bronze_axe")
	assert_eq(gs.inventory.get("rusty_sword", 0), 1)
	assert_false(gs.inventory.has("bronze_axe"))

func test_unequip_returns_weapon_to_inventory():
	gs.equipped_weapon = "rusty_sword"
	gs.unequip_weapon()
	assert_eq(gs.equipped_weapon, "")
	assert_eq(gs.inventory.get("rusty_sword", 0), 1)
```

- [ ] **Step 3: Skapa `tests/unit/test_shop.gd`**

```gdscript
extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_buy_deducts_gold_and_adds_item():
	gs.gold = 100
	assert_true(gs.buy_item("pickaxe"))    # value 75
	assert_eq(gs.gold, 25)
	assert_eq(gs.inventory.get("pickaxe", 0), 1)

func test_buy_fails_without_gold():
	gs.gold = 10
	assert_false(gs.buy_item("pickaxe"))
	assert_eq(gs.gold, 10)
	assert_false(gs.inventory.has("pickaxe"))

func test_sell_gives_half_value():
	gs.add_item("copper_ore", 2)           # value 12
	assert_true(gs.sell_item("copper_ore"))
	assert_eq(gs.gold, 6)
	assert_eq(gs.inventory.get("copper_ore", 0), 1)

func test_sell_fails_without_item():
	assert_false(gs.sell_item("copper_ore"))
```

- [ ] **Step 4: Kör — förvänta FAIL** (Recipes finns inte, buy_item m.fl. finns inte)

- [ ] **Step 5: Skapa `crafting/recipes.gd`**

```gdscript
class_name Recipes
extends RefCounted
## Statisk receptlogik — ren och testbar. UI:t kopplar mot GameState.

static func can_craft(recipe: Dictionary, inventory: Dictionary, skill_level: int) -> bool:
	if skill_level < int(recipe["level"]):
		return false
	return missing_ingredients(recipe, inventory).is_empty()

static func missing_ingredients(recipe: Dictionary, inventory: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for ing in recipe["ingredients"]:
		var need := int(recipe["ingredients"][ing])
		var have := int(inventory.get(ing, 0))
		if have < need:
			missing[ing] = need - have
	return missing
```

- [ ] **Step 6: Lägg till i `autoload/game_state.gd`**:

```gdscript
func weapon_skill() -> String:
	var w: Dictionary = ItemDB.items.get(equipped_weapon, {})
	return String(w.get("skill", "fist"))

func equip_weapon(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) < 1:
		return false
	if ItemDB.items.get(item_id, {}).get("type") != "weapon":
		return false
	remove_item(item_id, 1)
	if equipped_weapon != "":
		add_item(equipped_weapon, 1)
	equipped_weapon = item_id
	inventory_changed.emit()
	return true

func unequip_weapon() -> void:
	if equipped_weapon == "":
		return
	add_item(equipped_weapon, 1)
	equipped_weapon = ""
	inventory_changed.emit()

func buy_item(item_id: String) -> bool:
	var price := int(ItemDB.items[item_id]["value"])
	if gold < price:
		return false
	gold -= price
	gold_changed.emit(gold)
	add_item(item_id, 1)
	return true

func sell_item(item_id: String) -> bool:
	if not remove_item(item_id, 1):
		return false
	gold += int(int(ItemDB.items[item_id]["value"]) * 0.5)
	gold_changed.emit(gold)
	return true

func craft(recipe: Dictionary) -> bool:
	var skill := String(recipe["skill"])
	if not Recipes.can_craft(recipe, inventory, effective_skill_level(skill)):
		return false
	for ing in recipe["ingredients"]:
		remove_item(ing, int(recipe["ingredients"][ing]))
	add_item(String(recipe["id"]), 1)
	gain_skill_xp(skill, int(recipe["xp"]))
	return true
```

- [ ] **Step 7: Re-import (ny class_name Recipes), kör tester — förvänta PASS**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
```

- [ ] **Step 8: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: receptlogik, craft, equip, butik i GameState (TDD)"
```

---

### Task 5: GatherNode-entity

**Files:**
- Create: `entities/gather_node.gd`, `entities/gather_node.tscn`
- Test: `tests/unit/test_gather_node.gd`

- [ ] **Step 1: Skriv failande test `tests/unit/test_gather_node.gd`**

```gdscript
extends GutTest

const GatherNodeScript = preload("res://entities/gather_node.gd")

func test_success_chance_formula():
	assert_almost_eq(GatherNodeScript.success_chance(1, 1), 0.40, 0.001)
	assert_almost_eq(GatherNodeScript.success_chance(11, 1), 0.60, 0.001)
	assert_almost_eq(GatherNodeScript.success_chance(99, 1), 0.90, 0.001)  # tak
	assert_almost_eq(GatherNodeScript.success_chance(1, 30), 0.05, 0.001)  # golv

func _make_node() -> Node2D:
	var n: Node2D = preload("res://entities/gather_node.tscn").instantiate()
	add_child_autofree(n)
	n.def = {"skill": "mining", "level": 1, "tool": "pickaxe", "yields": "copper_ore",
		"xp": 15, "charges": [3, 5], "respawn": 30, "color": "#b87333", "label": "Kopparådra"}
	n.charges = 3
	return n

func test_attempt_requires_tool():
	var n = _make_node()
	GameState.inventory.erase("pickaxe")
	assert_eq(n.attempt(), "no_tool")

func test_attempt_requires_level():
	var n = _make_node()
	GameState.add_item("pickaxe", 1)
	n.def["level"] = 99
	assert_eq(n.attempt(), "low_level")
	GameState.remove_item("pickaxe", 1)

func test_success_grants_yield_xp_and_consumes_charge():
	var n = _make_node()
	var ore0 = int(GameState.inventory.get("copper_ore", 0))
	var xp0 = int(GameState.skills["mining"]["xp"])
	n._on_success()
	assert_eq(int(GameState.inventory.get("copper_ore", 0)), ore0 + 1)
	assert_gt(int(GameState.skills["mining"]["xp"]) + int(GameState.skills["mining"]["level"]), xp0)
	assert_eq(n.charges, 2)

func test_depletes_at_zero_charges():
	var n = _make_node()
	n.charges = 1
	n._on_success()
	assert_true(n.depleted)
	assert_eq(n.attempt(), "depleted")
```

(Obs: dessa tester muterar den globala GameState-autoloaden — städa det du lägger till, som i test_attempt_requires_level.)

- [ ] **Step 2: Skapa `entities/gather_node.tscn`** (kan inte köra testet utan scenen)

```ini
[gd_scene load_steps=3 format=3 uid="uid://gnode00001"]

[ext_resource type="Script" path="res://entities/gather_node.gd" id="1"]

[sub_resource type="RectangleShape2D" id="shape1"]
size = Vector2(28, 28)

[node name="GatherNode" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(0, -13, 12, 0, 0, 13, -12, 0)

[node name="NameLabel" type="Label" parent="."]
offset_left = -40.0
offset_top = -32.0
offset_right = 40.0
offset_bottom = -20.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="ClickArea" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="ClickArea"]
shape = SubResource("shape1")
```

- [ ] **Step 3: Skapa `entities/gather_node.gd`** (skriv stub först om du vill se FAIL, annars direkt):

```gdscript
class_name GatherNode
extends Node2D
## Generisk gathering-nod. Typdata från ItemDB.nodes (data/nodes.json).

var node_type := ""
var def: Dictionary = {}
var tile := Vector2i.ZERO
var charges := 0
var depleted := false

@onready var body: Polygon2D = $Body
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

static func success_chance(level: int, req_level: int) -> float:
	return clampf(0.40 + 0.02 * float(level - req_level), 0.05, 0.90)

func setup(type: String, t: Vector2i) -> void:
	node_type = type
	def = ItemDB.nodes[type]
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
	body.color = Color(String(def["color"]))
	name_lbl.text = String(def["label"])

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		World.player.set_gather_target(self)

func attempt() -> String:
	if depleted:
		return "depleted"
	if int(GameState.inventory.get(String(def["tool"]), 0)) < 1:
		return "no_tool"
	if GameState.effective_skill_level(String(def["skill"])) < int(def["level"]):
		return "low_level"
	if randf() <= success_chance(GameState.effective_skill_level(String(def["skill"])), int(def["level"])):
		_on_success()
		return "ok"
	return "miss"

func _on_success() -> void:
	GameState.add_item(String(def["yields"]), 1)
	GameState.gain_skill_xp(String(def["skill"]), int(def["xp"]))
	charges -= 1
	if charges <= 0:
		_deplete()

func _deplete() -> void:
	depleted = true
	modulate = Color(0.45, 0.45, 0.45)
	if is_inside_tree():
		get_tree().create_timer(float(def["respawn"])).timeout.connect(_respawn)

func _respawn() -> void:
	depleted = false
	modulate = Color.WHITE
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
```

(Obs: `set_gather_target` på player implementeras i Task 7 — klicket är dynamiskt anrop och parsefelfritt nu.)

- [ ] **Step 4: Re-import (ny class_name + scen), kör tester — förvänta PASS**

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: GatherNode med chansformel, laddningar, respawn (TDD)"
```

---

### Task 6: Zon-legend (node/station/shop) + kartor + find_path_adjacent

**Files:**
- Modify: `world/zone.gd`
- Replace: `data/zones/town.json`, `data/zones/cave.json`
- Create: `data/zones/forest.json`
- Test: `tests/unit/test_zone.gd` (utöka)

- [ ] **Step 1: Utöka `tests/unit/test_zone.gd`** — lägg till längst ner:

```gdscript
func test_forest_loads_with_nodes():
	var z = _make_zone("forest")
	assert_gt(z.node_points.size(), 5)
	var trees = z.node_points.filter(func(n): return n["node"] == "tree")
	assert_gt(trees.size(), 0)

func test_town_has_stations_and_shop():
	var z = _make_zone("town")
	assert_eq(z.station_points.size(), 4)
	assert_eq(z.shop_points.size(), 1)

func test_cave_has_ore_veins():
	var z = _make_zone("cave")
	var veins = z.node_points.filter(func(n): return n["node"].ends_with("_vein"))
	assert_eq(veins.size(), 6)

func test_node_tiles_are_blocked():
	var z = _make_zone("forest")
	assert_false(z.is_walkable(z.node_points[0]["tile"]))

func test_town_has_two_portals():
	var z = _make_zone("town")
	assert_eq(z.portals.size(), 2)
	assert_true(z.portals.values().has("forest"))

func test_find_path_adjacent_reaches_blocked_target():
	var z = _make_zone("town")
	var station_tile: Vector2i = z.station_points[0]["tile"]
	var path = z.find_path_adjacent(Vector2i(4, 7), station_tile)
	assert_gt(path.size(), 0)
	var last: Vector2i = path[path.size() - 1]
	assert_lte(maxi(absi(last.x - station_tile.x), absi(last.y - station_tile.y)), 1)
```

- [ ] **Step 2: Kör — förvänta FAIL**

- [ ] **Step 3: Modifiera `world/zone.gd`** — lägg till fält efter `var spawn_points`:

```gdscript
var node_points: Array = []        # [{tile, node}]
var station_points: Array = []     # [{tile, station}]
var shop_points: Array = []        # [tile]
```

Ersätt legend-hanteringen i `build()` (hela `match ch:`-blocket) med:

```gdscript
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
							"spawn":
								spawn_points.append({"tile": t, "monster": e["monster"], "respawn": float(e["respawn"])})
							"node":
								node_points.append({"tile": t, "node": e["node"]})
								blocked = true
							"station":
								station_points.append({"tile": t, "station": e["station"]})
								blocked = true
							"shop":
								shop_points.append(t)
								blocked = true
			if not PlaceholderTiles.TERRAIN.has(terrain):
				terrain = "."
			tilemap.set_cell(t, 0, Vector2i(PlaceholderTiles.TERRAIN[terrain], 0))
			_walkable[t] = terrain != "W" and terrain != "~" and not blocked
```

Lägg till efter `find_path`:

```gdscript
func find_path_adjacent(from: Vector2i, to: Vector2i) -> Array:
	var best: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n := to + d
		if not is_walkable(n):
			continue
		if n == from:
			return [from]
		var p := find_path(from, n)
		if p.size() > 0 and (best.is_empty() or p.size() < best.size()):
			best = p
	return best
```

- [ ] **Step 4: Ersätt `data/zones/town.json`** (nytt: portal `1`→forest på nordsidan, stationsraden `A G L R` + butik `H` på rad 16):

```json
{
	"name": "Thais",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W..................1...................W",
		"W..WWWW....WWWW........................W",
		"W..W..W....W..W.....a..................W",
		"W..W..W....W..W........................W",
		"W..WWWW....WWWW..............a.........W",
		"W......................................W",
		"W...P....................~~~...........W",
		"W........................~~~...........W",
		"W......................................W",
		"W............a.........................W",
		"W........................WWWWW.........W",
		"W........................W,,,W.........W",
		"W........................W,0,W.........W",
		"W........................W,,,W.........W",
		"W........................WW,WW.........W",
		"W..A.G.L.R..H..........................W",
		"W.....a................................W",
		"W......................................W",
		"W..........a...........................W",
		"W......................................W",
		"W................a.....................W",
		"W......................................W",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "cave"},
		"1": {"type": "portal", "to": "forest"},
		"a": {"type": "spawn", "monster": "Råtta", "respawn": 12.0},
		"A": {"type": "station", "station": "anvil"},
		"G": {"type": "station", "station": "stove"},
		"L": {"type": "station", "station": "alchemy_table"},
		"R": {"type": "station", "station": "rune_altar"},
		"H": {"type": "shop"}
	}
}
```

- [ ] **Step 5: Ersätt `data/zones/cave.json`** (nytt: 2× koppar nära ingången rad 1, 2× järn rad 11, 2× guld rad 20 nära Ghouls):

```json
{
	"name": "Thais-grottan",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W,k,,,,,k,WWWWWWW,,,,,,,,,,,,,,,,,,,,,,W",
		"W,P,,0,,,,,,,,,,W,,,b,,,,,WWW,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,,,W,,,,c,,,,,W",
		"WWWWWW,,,,,b,,,,W,,,,,,,,,,,W,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,WWWWW,,WWWWWW,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,c,,,,,W",
		"W,,,b,,,,WWWWW,,,,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,W,,,W,,,,,c,,,,,,WWWWWW,,,,,,,W",
		"W,,,,,,,,W,,,W,,,,,,,,,,,,W,,,,,,,,,,,,W",
		"W,,,,,,,,WW,WW,,,,,,,,,,,,W,,,d,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,j,j,,,,,W,,,,,,,,,,,,W",
		"W,,b,,,,,,,,,,,,WWWW,,,,,,W,,,,,,d,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,WWWW,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,c,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,WWWWWW,,,,W,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,W,,,,,,,,,,,,,,e,,,,,,,W",
		"W,,,,,,,,,,,,,,,WWWWWWWW,,,,,,,,,,,,,,,W",
		"W,,,,c,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,WWWW,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,W,g,g,e,,,W",
		"W,,,,,,,,b,,,,,,,,,,,,,,,,,,,W,,,,,,,,,W",
		"W,,,,,,,,,,,,,,,,,,,,,,,,,,,,W,,,,,,,,,W",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "town"},
		"b": {"type": "spawn", "monster": "Orm", "respawn": 15.0},
		"c": {"type": "spawn", "monster": "Spindel", "respawn": 15.0},
		"d": {"type": "spawn", "monster": "Skelett", "respawn": 25.0},
		"e": {"type": "spawn", "monster": "Ghoul", "respawn": 45.0},
		"k": {"type": "node", "node": "copper_vein"},
		"j": {"type": "node", "node": "iron_vein"},
		"g": {"type": "node", "node": "gold_vein"}
	}
}
```

- [ ] **Step 6: Skapa `data/zones/forest.json`** (flod kolumn 26–27 med bro rad 11–12, träd väst, örter/monster öst, portal `0`→town i söder; fiskestim `f`/`q` ligger i floden med `"terrain": "~"`):

```json
{
	"name": "Gamla skogen",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W.........................~~..........W",
		"W..t......t.......o.......~~...m......W",
		"W.........................~~..........W",
		"W....t........y...........~~......n...W",
		"W...t.....................f~..........W",
		"W.........o.............t.~~..b.......W",
		"W.........................~~..........W",
		"W..t...t...................~~....m....W",
		"W.........................~~..........W",
		"W............y............~~..........W",
		"W......................................W",
		"W......................................W",
		"W.........................~~..........W",
		"W....o....t...............~~.....c....W",
		"W.........................~q...n......W",
		"W..t.......................~~..........W",
		"W.........................~~..........W",
		"W..........t.....o........~~..m.......W",
		"W.........................~~......b...W",
		"W....t.....................~~..........W",
		"W..................P.......~~..........W",
		"W....................0....~~..........W",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "town", "terrain": "."},
		"t": {"type": "node", "node": "tree", "terrain": "."},
		"o": {"type": "node", "node": "oak_tree", "terrain": "."},
		"y": {"type": "node", "node": "willow_tree", "terrain": "."},
		"f": {"type": "node", "node": "fishing_spot", "terrain": "~"},
		"q": {"type": "node", "node": "pike_spot", "terrain": "~"},
		"m": {"type": "node", "node": "mint_patch", "terrain": "."},
		"n": {"type": "node", "node": "nightshade_patch", "terrain": "."},
		"b": {"type": "spawn", "monster": "Orm", "respawn": 20.0, "terrain": "."},
		"c": {"type": "spawn", "monster": "Spindel", "respawn": 20.0, "terrain": "."}
	}
}
```

**VIKTIGT:** Validera radlängderna innan testkörning — `build()` assertar 40 tecken per rad. Snabbkoll:

```bash
python -c "
import json
for z in ['town','cave','forest']:
    d=json.load(open(f'C:/Users/Hem/tibia2d/data/zones/{z}.json',encoding='utf-8'))
    for i,r in enumerate(d['tiles']):
        assert len(r)==40, f'{z} rad {i}: {len(r)}'
    assert len(d['tiles'])==24 or z!='forest', z
print('OK')
"
```

Om någon rad har fel längd: justera antalet punkter i den raden tills den är exakt 40 tecken.

- [ ] **Step 7: Kör tester — förvänta PASS** (alla zone-tester + tidigare)

- [ ] **Step 8: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: skogszon, malmådror, stationer, legend-typer node/station/shop (TDD)"
```

---

### Task 7: Stations-/butiksentities + World spawnar världsobjekt

**Files:**
- Create: `entities/crafting_station.gd`, `entities/crafting_station.tscn`, `entities/shop_npc.gd`, `entities/shop_npc.tscn`
- Modify: `autoload/world.gd`

- [ ] **Step 1: Skapa `entities/crafting_station.gd`**

```gdscript
class_name CraftingStation
extends Node2D
## Klickbar crafting-station. Öppnar receptpanelen för sin stationstyp.

const LABELS := {"anvil": "Städ", "stove": "Gryta", "alchemy_table": "Alkemibord", "rune_altar": "Runaltare"}
const COLORS := {"anvil": "#5a5a62", "stove": "#8a4a2a", "alchemy_table": "#4a7a5a", "rune_altar": "#6a4a8a"}

var station_type := ""
var tile := Vector2i.ZERO

@onready var body: Polygon2D = $Body
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

func setup(type: String, t: Vector2i) -> void:
	station_type = type
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)
	body.color = Color(String(COLORS[type]))
	name_lbl.text = String(LABELS[type])

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 1:
			World.hud.open_recipes(station_type)
		else:
			World.hud.show_message("Gå närmare %s." % LABELS[station_type])
```

- [ ] **Step 2: Skapa `entities/crafting_station.tscn`**

```ini
[gd_scene load_steps=3 format=3 uid="uid://station0001"]

[ext_resource type="Script" path="res://entities/crafting_station.gd" id="1"]

[sub_resource type="RectangleShape2D" id="shape1"]
size = Vector2(30, 30)

[node name="CraftingStation" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-14, -10, 14, -10, 14, 12, -14, 12)

[node name="NameLabel" type="Label" parent="."]
offset_left = -40.0
offset_top = -30.0
offset_right = 40.0
offset_bottom = -18.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="ClickArea" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="ClickArea"]
shape = SubResource("shape1")
```

- [ ] **Step 3: Skapa `entities/shop_npc.gd`**

```gdscript
class_name ShopNpc
extends Node2D
## Butiks-NPC. Klick intill → köp/sälj-panel.

var tile := Vector2i.ZERO

@onready var click_area: Area2D = $ClickArea

func setup(t: Vector2i) -> void:
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 1:
			World.hud.open_shop()
		else:
			World.hud.show_message("Gå närmare handlaren.")
```

- [ ] **Step 4: Skapa `entities/shop_npc.tscn`**

```ini
[gd_scene load_steps=3 format=3 uid="uid://shopnpc001"]

[ext_resource type="Script" path="res://entities/shop_npc.gd" id="1"]

[sub_resource type="RectangleShape2D" id="shape1"]
size = Vector2(28, 28)

[node name="ShopNpc" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-10, -14, 10, -14, 10, 14, -10, 14)
color = Color(0.85, 0.7, 0.3, 1)

[node name="NameLabel" type="Label" parent="."]
offset_left = -40.0
offset_top = -32.0
offset_right = 40.0
offset_bottom = -20.0
text = "Handlare"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="ClickArea" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="ClickArea"]
shape = SubResource("shape1")
```

- [ ] **Step 5: Modifiera `autoload/world.gd`** — lägg till `hud`-fält efter `var game_root`:

```gdscript
var hud: CanvasLayer    # sätts av hud.gd vid _ready
```

Lägg till sist i `start_game()` (efter `_spawn_monsters()`):

```gdscript
	_spawn_world_objects()
```

Lägg till nya funktioner sist i filen:

```gdscript
func _spawn_world_objects() -> void:
	for np in current_zone.node_points:
		var n: Node2D = preload("res://entities/gather_node.tscn").instantiate()
		current_zone.add_child(n)
		n.setup(np["node"], np["tile"])
	for sp in current_zone.station_points:
		var s: Node2D = preload("res://entities/crafting_station.tscn").instantiate()
		current_zone.add_child(s)
		s.setup(sp["station"], sp["tile"])
	for t in current_zone.shop_points:
		var npc: Node2D = preload("res://entities/shop_npc.tscn").instantiate()
		current_zone.add_child(npc)
		npc.setup(t)
```

- [ ] **Step 6: Re-import + kör tester — förvänta PASS** (inga nya tester; befintliga får inte gå sönder)

- [ ] **Step 7: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: stations- och butiksentities, World spawnar världsobjekt"
```

---

### Task 8: Player — auto-walk, gathering-loop, vapenskill-attack

**Files:**
- Modify: `entities/player/player.gd`, `entities/monster/monster.gd`

- [ ] **Step 1: Modifiera `entities/player/player.gd`** — ersätt hela filen:

```gdscript
class_name Player
extends Node2D
## Tile-baserad rörelse + targeting + auto-attack + gathering (Tibia/OSRS-stil).

const TILE := 32
const ATTACK_COOLDOWN := 1.0
const GATHER_INTERVAL := 2.0

var zone: Node2D                      # sätts av World vid zonladdning
var tile := Vector2i.ZERO
var _move_t := 1.0                    # 0..1 under pågående steg
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var move_speed := 4.0                 # tiles/sek
var facing := Vector2i.DOWN
var target: Node2D = null
var _attack_timer := 0.0
var gather_target: Node2D = null
var _gather_timer := 0.0
var _auto_path: Array = []

@onready var visual: CharacterVisual = $CharacterVisual

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)

func snap_to(t: Vector2i) -> void:
	tile = t
	position = zone.tile_to_world(t)
	_move_t = 1.0
	GameState.player_tile = t

func set_target(m: Node2D) -> void:
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	target = m
	gather_target = null
	_auto_path = []
	if target:
		target.modulate = Color(1.4, 0.9, 0.9)   # röd markering som Tibia

func set_gather_target(n: Node2D) -> void:
	set_target(null)
	gather_target = n
	_gather_timer = 0.0
	if n:
		_auto_path = zone.find_path_adjacent(tile, n.tile)
		if _auto_path.is_empty() and _chebyshev(n.tile) > 1:
			World.hud.show_message("Kan inte nå dit.")
			gather_target = null

func _chebyshev(t: Vector2i) -> int:
	return maxi(absi(t.x - tile.x), absi(t.y - tile.y))

func _process(delta: float) -> void:
	_update_movement(delta)
	_update_attack(delta)
	_update_gather(delta)

func _update_movement(delta: float) -> void:
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
		_auto_path = []          # manuell rörelse avbryter auto-walk
		gather_target = null
		_step(dir)
		return
	if _auto_path.size() > 1:    # auto-walk mot gather-mål
		var next: Vector2i = _auto_path[1]
		_auto_path.remove_at(0)
		var d := next - tile
		if d != Vector2i.ZERO and zone.is_walkable(next):
			_step(d)

func _step(dir: Vector2i) -> void:
	facing = dir
	visual.face(dir)
	var next := tile + dir
	if zone.is_walkable(next):
		_from = position
		_to = zone.tile_to_world(next)
		tile = next
		_move_t = 0.0

func _update_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target and is_instance_valid(target) and not target.dead and _attack_timer <= 0.0:
		if _chebyshev(target.tile) <= 1:
			_attack_timer = ATTACK_COOLDOWN
			var wskill := GameState.weapon_skill()
			var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
			var dmg := CombatFormulas.roll_melee(GameState.level,
				GameState.effective_skill_level(wskill), int(weapon.get("atk", 5)))
			target.take_damage(dmg)
			GameState.gain_skill_xp(wskill, 1)

func _update_gather(delta: float) -> void:
	if gather_target == null or not is_instance_valid(gather_target):
		return
	if _chebyshev(gather_target.tile) > 1:
		return                    # på väg dit via auto-walk
	_gather_timer -= delta
	if _gather_timer > 0.0:
		return
	_gather_timer = GATHER_INTERVAL
	match gather_target.attempt():
		"no_tool":
			World.hud.show_message("Du behöver: %s" % ItemDB.items[gather_target.def["tool"]]["name"])
			gather_target = null
		"low_level":
			World.hud.show_message("Kräver %s %d." % [gather_target.def["skill"], int(gather_target.def["level"])])
			gather_target = null
		"depleted":
			gather_target = null

func _check_portal() -> void:
	if zone.portals.has(tile):
		World.change_zone(zone.portals[tile])
```

- [ ] **Step 2: Modifiera `entities/monster/monster.gd`** — i `_process`, ersätt mitigeringsraden:

```gdscript
			var dmg := CombatFormulas.mitigate(raw, GameState.skills["shielding"]["level"], 2)
```

med:

```gdscript
			var dmg := CombatFormulas.mitigate(raw, GameState.effective_skill_level("shielding"), 2)
```

- [ ] **Step 3: Kör tester — förvänta PASS** (befintliga; gathering-loopen verifieras manuellt i Task 11)

- [ ] **Step 4: Snabb boot-check**

```bash
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

Expected: ingen output (inga skriptfel).

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: auto-walk, gathering-loop, vapenskill-attack"
```

---

### Task 9: Save-migrering v2

**Files:**
- Modify: `autoload/save_manager.gd`
- Test: `tests/unit/test_save.gd` (utöka)

- [ ] **Step 1: Utöka `tests/unit/test_save.gd`** — lägg till längst ner:

```gdscript
func test_v1_snapshot_migrates_to_all_skills():
	var gs = load("res://autoload/game_state.gd").new()
	gs.skills = {"sword": {"level": 22, "xp": 10}, "shielding": {"level": 14, "xp": 0}}
	gs.ensure_all_skills()
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skills["sword"]["level"], 22)
	assert_eq(gs.skills["mining"]["level"], 1)
	gs.free()

func test_save_version_is_2():
	assert_eq(load("res://autoload/save_manager.gd").new().SAVE_VERSION, 2)
```

(Obs: GUT håller en referens till scriptet; `load(...).new().SAVE_VERSION` läcker en nod — acceptabelt i test, eller bind till variabel och `free()`.)

- [ ] **Step 2: Kör — förvänta FAIL** (SAVE_VERSION är 1)

- [ ] **Step 3: Modifiera `autoload/save_manager.gd`**

Ändra:

```gdscript
const SAVE_VERSION := 1
```

till:

```gdscript
const SAVE_VERSION := 2
```

I `load_game()`, lägg till direkt efter raden `GameState.skills = s["skills"]; ...`:

```gdscript
	GameState.ensure_all_skills()   # v1→v2: fyll på skills som saknas i gamla saves
```

- [ ] **Step 4: Kör tester — förvänta PASS**

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: save v2 med skillmigrering (TDD)"
```

---

### Task 10: UI — skillpanel (K), HUD-meddelanden, buffvisning, interaktivt inventory

**Files:**
- Create: `ui/skill_panel.gd`
- Modify: `ui/hud.gd`, `ui/hud.tscn`, `project.godot`

- [ ] **Step 1: Lägg till input-action `toggle_skills` i `project.godot`** — i `[input]`-sektionen, efter `toggle_inventory`-raden:

```ini
toggle_skills={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]}
```

(75 = fysisk K.)

- [ ] **Step 2: Skapa `ui/skill_panel.gd`** (bygger rader programmatiskt — ingen .tscn behövs):

```gdscript
extends PanelContainer
## Skillpanel (K): alla skills grupperade per kategori, nivå + XP-progress.

const CATEGORY_ORDER := ["combat", "gathering", "crafting", "utility"]
const CATEGORY_LABELS := {"combat": "Strid", "gathering": "Gathering", "crafting": "Crafting", "utility": "Utility"}

var _rows: Dictionary = {}   # skill_id -> {lvl: Label, bar: ProgressBar}

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(320, 0)
	var root := VBoxContainer.new()
	add_child(root)
	for cat in CATEGORY_ORDER:
		var header := Label.new()
		header.text = CATEGORY_LABELS[cat]
		header.add_theme_font_size_override("font_size", 14)
		root.add_child(header)
		var ids: Array = GameState.skill_defs.keys().filter(
			func(id): return GameState.skill_defs[id]["category"] == cat)
		ids.sort()
		for id in ids:
			root.add_child(_make_row(id))
	GameState.skill_changed.connect(func(_s): _refresh())
	_refresh()

func _make_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = String(GameState.skill_defs[id]["name"])
	name_lbl.custom_minimum_size = Vector2(110, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)
	var lvl := Label.new()
	lvl.custom_minimum_size = Vector2(40, 0)
	lvl.add_theme_font_size_override("font_size", 11)
	row.add_child(lvl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 10)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_rows[id] = {"lvl": lvl, "bar": bar}
	return row

func _refresh() -> void:
	for id in _rows:
		var s: Dictionary = GameState.skills[id]
		_rows[id]["lvl"].text = "Lv %d" % int(s["level"])
		_rows[id]["bar"].max_value = GameState.skill_xp_next(int(s["level"]), id)
		_rows[id]["bar"].value = int(s["xp"])
```

- [ ] **Step 3: Modifiera `ui/hud.tscn`** — ersätt `InventoryPanel`-delen. Hela nya .tscn:

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
offset_right = 460.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 12

[node name="BuffsLabel" type="Label" parent="."]
offset_left = 16.0
offset_top = 70.0
offset_right = 460.0
offset_bottom = 86.0
theme_override_font_sizes/font_size = 11
modulate = Color(0.7, 0.9, 1, 1)

[node name="MessageLabel" type="Label" parent="."]
visible = false
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 90.0
offset_right = 200.0
offset_bottom = 112.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 14
modulate = Color(1, 0.9, 0.5, 1)

[node name="InventoryPanel" type="PanelContainer" parent="."]
visible = false
offset_left = 16.0
offset_top = 110.0
offset_right = 260.0
offset_bottom = 420.0

[node name="InvScroll" type="ScrollContainer" parent="InventoryPanel"]

[node name="InvList" type="VBoxContainer" parent="InventoryPanel/InvScroll"]
size_flags_horizontal = 3

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

- [ ] **Step 4: Ersätt `ui/hud.gd`** med:

```gdscript
extends CanvasLayer

@onready var hp_bar: ColorRect = $HpBar
@onready var mana_bar: ColorRect = $ManaBar
@onready var stats: Label = $StatsLabel
@onready var buffs_lbl: Label = $BuffsLabel
@onready var msg_lbl: Label = $MessageLabel
@onready var inv_panel: PanelContainer = $InventoryPanel
@onready var inv_list: VBoxContainer = $InventoryPanel/InvScroll/InvList
@onready var death_lbl: Label = $DeathLabel

var skill_panel: PanelContainer
var recipe_panel: PanelContainer
var shop_panel: PanelContainer
var _msg_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # måste fungera när trädet pausas vid död
	World.hud = self
	skill_panel = preload("res://ui/skill_panel.gd").new()
	skill_panel.offset_left = 940.0
	skill_panel.offset_top = 16.0
	add_child(skill_panel)
	recipe_panel = preload("res://ui/recipe_panel.gd").new()
	add_child(recipe_panel)
	shop_panel = preload("res://ui/shop_panel.gd").new()
	add_child(shop_panel)
	GameState.hp_changed.connect(func(_h, _m): _refresh())
	GameState.mana_changed.connect(func(_v, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.skill_changed.connect(func(_s): _refresh())
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.buffs_changed.connect(_refresh_buffs)
	GameState.player_died.connect(_on_death)
	_refresh()
	_refresh_inv()
	_refresh_buffs()

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			msg_lbl.visible = false
	if not GameState.active_buffs.is_empty():
		_refresh_buffs()   # nedräkning

func show_message(text: String) -> void:
	msg_lbl.text = text
	msg_lbl.visible = true
	_msg_timer = 2.5

func open_recipes(station_type: String) -> void:
	shop_panel.visible = false
	recipe_panel.open(station_type)

func open_shop() -> void:
	recipe_panel.visible = false
	shop_panel.open()

func _refresh() -> void:
	hp_bar.size.x = 200.0 * (GameState.health / GameState.max_health)
	mana_bar.size.x = 200.0 * (GameState.mana / GameState.max_mana)
	var wskill := GameState.weapon_skill()
	stats.text = "Lv %d  XP %d/%d  Guld %d  %s %d" % [
		GameState.level, GameState.experience, GameState.xp_to_next, GameState.gold,
		GameState.skill_defs[wskill]["name"], GameState.effective_skill_level(wskill)]

func _refresh_buffs() -> void:
	var parts: Array = []
	for b in GameState.active_buffs:
		parts.append("%s +%d (%ds)" % [String(b["stat"]).trim_prefix("skill:"), int(b["amount"]), int(ceil(b["time_left"]))])
	buffs_lbl.text = "  ".join(parts)

func _refresh_inv() -> void:
	for c in inv_list.get_children():
		c.queue_free()
	if GameState.equipped_weapon != "":
		inv_list.add_child(_inv_row(GameState.equipped_weapon, 1, "Ta av", func(): GameState.unequip_weapon()))
	for id in GameState.inventory:
		var d: Dictionary = ItemDB.items[id]
		var qty := int(GameState.inventory[id])
		if d.get("type") == "weapon":
			inv_list.add_child(_inv_row(id, qty, "Utrusta", func(): GameState.equip_weapon(id)))
		elif d.has("heal") or d.has("mana") or d.has("buff"):
			inv_list.add_child(_inv_row(id, qty, "Använd", func(): GameState.use_item(id)))
		else:
			inv_list.add_child(_inv_row(id, qty, "", Callable()))

func _inv_row(id: String, qty: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	var prefix := "[E] " if id == GameState.equipped_weapon and action == "Ta av" else ""
	lbl.text = "%s%s x%d" % [prefix, ItemDB.items[id]["name"], qty]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	if action != "":
		var btn := Button.new()
		btn.text = action
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(cb)
		row.add_child(btn)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inv_panel.visible = not inv_panel.visible
	elif event.is_action_pressed("toggle_skills"):
		skill_panel.visible = not skill_panel.visible
	elif event.is_action_pressed("hotkey_1"):
		if not GameState.use_item("health_potion"):
			show_message("Ingen hälsodryck.")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		recipe_panel.visible = false
		shop_panel.visible = false
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

(Obs: hud.gd refererar `recipe_panel.open`/`shop_panel.open` — panelerna skapas i Task 11. Skapa tomma stubbar i Step 5 så att spelet bootar mellan tasks.)

- [ ] **Step 5: Skapa stubbar `ui/recipe_panel.gd` och `ui/shop_panel.gd`** (ersätts i Task 11):

```gdscript
# ui/recipe_panel.gd (stub)
extends PanelContainer

func _ready() -> void:
	visible = false

func open(_station_type: String) -> void:
	visible = true
```

```gdscript
# ui/shop_panel.gd (stub)
extends PanelContainer

func _ready() -> void:
	visible = false

func open() -> void:
	visible = true
```

- [ ] **Step 6: Kör tester + boot-check — förvänta PASS / inga skriptfel**

- [ ] **Step 7: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: skillpanel (K), HUD-meddelanden, buffvisning, interaktivt inventory"
```

---

### Task 11: Recept- och butikspaneler

**Files:**
- Replace: `ui/recipe_panel.gd`, `ui/shop_panel.gd`

- [ ] **Step 1: Ersätt `ui/recipe_panel.gd`**

```gdscript
extends PanelContainer
## Receptpanel: visar stationens recept, craftar via GameState.craft.

var station_type := ""
var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(360, 0)
	offset_left = 300.0
	offset_top = 120.0
	_list = VBoxContainer.new()
	add_child(_list)
	GameState.inventory_changed.connect(func(): if visible: _rebuild())
	GameState.skill_changed.connect(func(_s): if visible: _rebuild())

func open(type: String) -> void:
	station_type = type
	visible = true
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = {"anvil": "Städ — Smithing", "stove": "Gryta — Cooking",
		"alchemy_table": "Alkemibord — Alchemy", "rune_altar": "Runaltare — Runecrafting"}[station_type]
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	for r in ItemDB.recipes[station_type]:
		_list.add_child(_recipe_row(r))

func _recipe_row(r: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "%s  (kräver %s %d)" % [ItemDB.items[r["id"]]["name"], r["skill"], int(r["level"])]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	head.add_child(name_lbl)
	var ok := Recipes.can_craft(r, GameState.inventory, GameState.effective_skill_level(String(r["skill"])))
	var btn := Button.new()
	btn.text = "Crafta"
	btn.disabled = not ok
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func(): GameState.craft(r))
	head.add_child(btn)
	var btn5 := Button.new()
	btn5.text = "x5"
	btn5.disabled = not ok
	btn5.add_theme_font_size_override("font_size", 10)
	btn5.pressed.connect(func():
		for i in 5:
			if not GameState.craft(r):
				break)
	head.add_child(btn5)
	box.add_child(head)
	var ing_lbl := Label.new()
	var parts: Array = []
	for ing in r["ingredients"]:
		var need := int(r["ingredients"][ing])
		var have := int(GameState.inventory.get(ing, 0))
		parts.append("%s %d/%d" % [ItemDB.items[ing]["name"], have, need])
	ing_lbl.text = "   " + ", ".join(parts)
	ing_lbl.add_theme_font_size_override("font_size", 10)
	ing_lbl.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.6)
	box.add_child(ing_lbl)
	return box
```

- [ ] **Step 2: Ersätt `ui/shop_panel.gd`**

```gdscript
extends PanelContainer
## Butikspanel: köp basvaror, sälj inventory för halva värdet.

const STOCK := ["pickaxe", "hatchet", "fishing_rod", "sickle", "bronze_axe", "wooden_club", "empty_vial"]

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(360, 0)
	offset_left = 300.0
	offset_top = 120.0
	_list = VBoxContainer.new()
	add_child(_list)
	GameState.inventory_changed.connect(func(): if visible: _rebuild())
	GameState.gold_changed.connect(func(_g): if visible: _rebuild())

func open() -> void:
	visible = true
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Handlare — guld: %d" % GameState.gold
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	var buy_hdr := Label.new()
	buy_hdr.text = "— Köp —"
	_list.add_child(buy_hdr)
	for id in STOCK:
		_list.add_child(_trade_row(id, int(ItemDB.items[id]["value"]), "Köp",
			func(): if not GameState.buy_item(id): World.hud.show_message("För lite guld.")))
	var sell_hdr := Label.new()
	sell_hdr.text = "— Sälj —"
	_list.add_child(sell_hdr)
	for id in GameState.inventory:
		_list.add_child(_trade_row(id, int(int(ItemDB.items[id]["value"]) * 0.5), "Sälj",
			func(): GameState.sell_item(id)))

func _trade_row(id: String, price: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	var qty := int(GameState.inventory.get(id, 0))
	var qty_txt := " x%d" % qty if action == "Sälj" else ""
	lbl.text = "%s%s — %d guld" % [ItemDB.items[id]["name"], qty_txt, price]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = action
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(cb)
	row.add_child(btn)
	return row
```

- [ ] **Step 3: Kör tester + boot-check — förvänta PASS / inga skriptfel**

- [ ] **Step 4: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: recept- och butikspaneler"
```

---

### Task 12: Manuellt speltest + perftest + milstolpstagg

- [ ] **Step 1: Fullständig testkörning**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
```

Expected: alla tester PASS.

- [ ] **Step 2: Perftest** (befintligt `--perftest`-läge spawnar 50 råttor):

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --path /c/Users/Hem/tibia2d res://world/game.tscn -- --perftest 2>&1 | grep PERFTEST
```

Expected: `min >= 60`.

- [ ] **Step 3: Manuellt speltest** (starta: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --path C:\Users\Hem\tibia2d res://world/game.tscn`)

Checklista (= acceptanskriterier i specen):
1. K visar skillpanelen med 18 skills
2. Döda Råttor i stan → guld → handlaren: köp hacka + fiskespö + skära + yxa (verktyg) — guld dras
3. Norra portalen → skogen; hugg träd (Woodcutting tränas), fiska vid floden, plocka mynta
4. Grottan: bryt koppar; järnådra säger "Kräver mining 15"
5. Stan: städet craftar copper_plate (Smithing 5 — bryt mer koppar först eller verifiera spärr); grytan steker öring
6. Alkemibordet: hälsodryck av 2 mynta + flaska; drick med F1
7. Köp bronsyxa → utrusta i inventoryt (I) → slå monster → Axe tränas (syns i statsraden)
8. Ät fiskgryta → regen-buff syns med nedräkning
9. Dö → Enter → respawn; starta om spelet → Fortsätt → skills kvar

- [ ] **Step 4: Commit + tagg**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: milstolpe 2 komplett — speltest verifierat"
git -C C:\Users\Hem\tibia2d tag m2-skillsystem
```

---

## Acceptanskriterier (från specen)

- [ ] Skillpanelen (K) visar alla 18 skills med nivå + progress
- [ ] Mining i grottan: hacka krävs, koppar→järn→guld gateat per nivå, ådror töms och respawnar
- [ ] Skogszonen nås via portal; träd/fiske/örter tränar respektive skill
- [ ] Butiken säljer verktyg/vapen och köper loot; guld dras/läggs korrekt
- [ ] Alla fyra stationer craftar enligt recept; steel_sword kräver Smithing 15 och slår iron_sword
- [ ] Mat/potions med buff visar ikon i HUD och påverkar regen/skill under duration
- [ ] Yxa tränar Axe, klubba Club, inget vapen Fist
- [ ] v1-save laddar utan fel och får alla nya skills
- [ ] Alla GUT-tester gröna; 60+ FPS i perftestet
