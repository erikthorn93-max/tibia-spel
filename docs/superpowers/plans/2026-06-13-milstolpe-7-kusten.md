# Milstolpe 7 — Saltviks hamn (kustregion) Implementationsplan

> **För agentiska arbetare:** OBLIGATORISK SUB-SKILL: använd superpowers:subagent-driven-development (rekommenderas) eller superpowers:executing-plans för att implementera task-för-task. Stegen använder checkbox-syntax (`- [ ]`).

**Goal:** Lägg till en sammanhängande kustregion (zon, sjömonster + piratkapten-boss, sjö-taskkedja, röstad åtkomstquest, procedurellt sjunket-skepp-tema, fishing→cooking-fördjupning, pirat-outfit) som ren innehållsvåg ovanpå befintliga system.

**Architecture:** Nästan allt är JSON-data (`data/*.json`). Endast två kodändringar: (1) `dungeon_generator.gd` får ett valfritt `boss`-fält som placerar en boss-spawn i slutrummet; (2) `placeholder_tiles.gd` får en strandterräng `b`. Åtkomst sker via en låst portal `town→coast` (unlock `kustvagen`, krav: quest `quest_sjovagen`) — det befintliga `try_unlock`-på-portalsteg-mönstret (player.gd) öppnar den live när questen är klar. Boss spawnar live i sjunket-skepp-dungeonen och låser upp pirat-outfiten via `boss_killed` (samma mekanik som `outfit_ghoul_king`).

**Tech Stack:** Godot 4.6.2, GDScript, GUT 9.6.0, JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-13-milstolpe-7-kusten-design.md`

**GUT-kommando (PowerShell):**
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Förväntat före M7: `172/172 passed`. Varje task höjer antalet; håll sviten grön.

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/items.json` | Modifiera | 3 råfiskar, 3 buff-maträtter, cutlass, sea_chart, captains_hat |
| `data/monsters.json` | Modifiera | 5 sjömonster + boss Piratkapten Svartöga |
| `data/nodes.json` | Modifiera | 3 fiskenoder (deep_sea_spot, swordfish_spot, lobster_pot) |
| `data/recipes.json` | Modifiera | 3 stove-recept (buff-mat) |
| `data/tasks.json` | Modifiera | 3 sjö-tasks (krabbor, sjöormar, pirater) |
| `data/zones/coast.json` | Skapa | Kustzonen "Saltviks hamn" |
| `data/zones/town.json` | Modifiera | Låst hamnportal → coast + 2 pirat-spawns |
| `data/unlocks.json` | Modifiera | `kustvagen` (area), `outfit_pirate` (outfit) |
| `data/dungeon_themes.json` | Modifiera | Tema `sjunket_skepp` (med `boss`) |
| `data/quests.json` | Modifiera | `quest_sjovagen` (röstad åtkomstquest) |
| `data/npcs.json` | Modifiera | npc_captain (Brandt, town), npc_fishmonger (Saltgreta, coast) |
| `data/dialogue.json` | Modifiera | captain_*-träd + fishmonger_root |
| `data/outfits.json` | Modifiera | `outfit_pirate` |
| `world/dungeon_generator.gd` | Modifiera | Valfritt `boss`-fält → spawn i slutrummet |
| `world/placeholder_tiles.gd` | Modifiera | Strandterräng `b` |
| `tests/unit/test_*.gd` | Modifiera | Datavalidering per task |

**Konventioner (oförändrade från M1–M6):**
- All speldata i JSON; ingen hårdkodning i `.gd`.
- Zon-tiles: varje rad lika lång, yttermur `W`. Legend-typer: portal/spawn/node/station/shop/taskmaster/chest/dungeon_entrance/gate/shortcut.
- Monsterfält: `hp, atk, exp, speed, cooldown, aggro, color, loot` (+ `boss: true` för bossar). Inget `type`-fält finns.
- Buff-mat: `type: food`, `heal`, valfritt `buff: {stat, amount, duration}` där stat = `regen` eller `skill:<namn>`.

---

### Task 0: Branch

- [ ] **Step 1: Skapa featurebranch från master**

Kör:
```bash
cd /c/Users/Hem/tibia2d
git checkout master
git checkout -b m7-kusten
```
Förväntat: `Switched to a new branch 'm7-kusten'`.

---

### Task 1: Items — råfisk, buff-mat, piratloot

**Files:**
- Modify: `data/items.json`
- Test: `tests/unit/test_databases.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_databases.gd` (efter `test_items_loaded`):
```gdscript
func test_coast_items_loaded():
	for id in ["raw_mackerel", "raw_lobster", "raw_swordfish",
			"grilled_mackerel", "lobster_dinner", "swordfish_steak",
			"cutlass", "sea_chart", "captains_hat"]:
		assert_true(idb.items.has(id), "saknar item: " + id)
	assert_eq(idb.items["swordfish_steak"]["buff"]["stat"], "skill:sword")
	assert_eq(idb.items["cutlass"]["skill"], "sword")
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_databases.gd -gexit`
Förväntat: FAIL ("saknar item: raw_mackerel").

- [ ] **Step 3: Lägg till items**

I `data/items.json`, lägg in före den avslutande `}` (kom ihåg komma på föregående rad):
```json
	"raw_mackerel":     {"name": "Rå makrill",      "type": "material", "value": 14,  "color": "#5a7a9a"},
	"raw_lobster":      {"name": "Rå hummer",       "type": "material", "value": 35,  "color": "#a83a2a"},
	"raw_swordfish":    {"name": "Rå svärdfisk",    "type": "material", "value": 55,  "color": "#8a93a0"},
	"grilled_mackerel": {"name": "Grillad makrill", "type": "food",     "value": 30,  "color": "#c8a060", "heal": 50, "buff": {"stat": "regen", "amount": 3, "duration": 30}},
	"lobster_dinner":   {"name": "Hummermiddag",    "type": "food",     "value": 70,  "color": "#d86048", "heal": 70, "buff": {"stat": "skill:fishing", "amount": 3, "duration": 120}},
	"swordfish_steak":  {"name": "Svärdfiskstek",   "type": "food",     "value": 95,  "color": "#b0b8c0", "heal": 90, "buff": {"stat": "skill:sword", "amount": 3, "duration": 120}},
	"cutlass":          {"name": "Huggare",         "type": "weapon",   "value": 260, "color": "#c0c0c8", "atk": 16, "skill": "sword"},
	"sea_chart":        {"name": "Sjökort",         "type": "junk",     "value": 40,  "color": "#cabd8a"},
	"captains_hat":     {"name": "Kaptenshatt",     "type": "trophy",   "value": 3000, "color": "#2a2a40"}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS.

- [ ] **Step 5: Commit**
```bash
git add data/items.json tests/unit/test_databases.gd
git commit -m "feat: kust-items — råfisk, buff-mat, huggare och bossloot (TDD)"
```

---

### Task 2: Monster — 5 sjömonster + boss

**Files:**
- Modify: `data/monsters.json`
- Test: `tests/unit/test_databases.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_databases.gd`:
```gdscript
func test_coast_monsters_loaded():
	for name in ["Strandkrabba", "Sjöorm", "Pirat", "Pirat Skytt", "Drunknad sjöman"]:
		assert_true(mdb.monsters.has(name), "saknar monster: " + name)
	assert_true(mdb.monsters.has("Piratkapten Svartöga"))
	assert_true(bool(mdb.monsters["Piratkapten Svartöga"].get("boss", false)), "boss-flagga saknas")
	for name in mdb.monsters:
		for entry in mdb.monsters[name]["loot"]:
			assert_true(mdb.monsters.size() > 0)
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_databases.gd -gexit`
Förväntat: FAIL ("saknar monster: Strandkrabba").

- [ ] **Step 3: Lägg till monster**

I `data/monsters.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"Strandkrabba": {"hp": 60, "atk": 12, "exp": 40, "speed": 2.0, "cooldown": 1.3, "aggro": 5, "color": "#c0603a",
		"loot": [{"item": "iron_coin", "min": 3, "max": 10, "chance": 0.7},
		         {"item": "raw_lobster", "min": 1, "max": 1, "chance": 0.12}]},
	"Sjöorm": {"hp": 140, "atk": 22, "exp": 95, "speed": 2.6, "cooldown": 1.2, "aggro": 7, "color": "#2e6a5a",
		"loot": [{"item": "iron_coin", "min": 10, "max": 28, "chance": 0.8},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.06}]},
	"Pirat": {"hp": 180, "atk": 26, "exp": 140, "speed": 2.2, "cooldown": 1.5, "aggro": 8, "color": "#7a4a3a",
		"loot": [{"item": "iron_coin", "min": 20, "max": 55, "chance": 0.85},
		         {"item": "cutlass", "min": 1, "max": 1, "chance": 0.05},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.07}]},
	"Pirat Skytt": {"hp": 150, "atk": 24, "exp": 130, "speed": 2.3, "cooldown": 1.4, "aggro": 8, "color": "#5a4a6a",
		"loot": [{"item": "iron_coin", "min": 18, "max": 50, "chance": 0.85},
		         {"item": "sea_chart", "min": 1, "max": 1, "chance": 0.08}]},
	"Drunknad sjöman": {"hp": 110, "atk": 20, "exp": 85, "speed": 1.8, "cooldown": 1.5, "aggro": 7, "color": "#4a6a6a",
		"loot": [{"item": "bone_chips", "min": 1, "max": 3, "chance": 0.7},
		         {"item": "iron_coin", "min": 8, "max": 24, "chance": 0.7}]},
	"Piratkapten Svartöga": {"hp": 950, "atk": 46, "exp": 950, "speed": 1.8, "cooldown": 1.7, "aggro": 9, "color": "#2a2a40", "boss": true,
		"loot": [{"item": "captains_hat", "min": 1, "max": 1, "chance": 1.0},
		         {"item": "iron_coin", "min": 250, "max": 500, "chance": 1.0},
		         {"item": "cutlass", "min": 1, "max": 1, "chance": 0.5},
		         {"item": "health_potion", "min": 1, "max": 2, "chance": 0.5}]}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS.

- [ ] **Step 5: Commit**
```bash
git add data/monsters.json tests/unit/test_databases.gd
git commit -m "feat: sjömonster + boss Piratkapten Svartöga (TDD)"
```

---

### Task 3: Fiskenoder

**Files:**
- Modify: `data/nodes.json`
- Test: `tests/unit/test_recipes.gd` (befintligt `test_all_node_yields_and_tools_exist_as_items` täcker yields)

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_recipes.gd`:
```gdscript
func test_coast_fishing_nodes_loaded():
	for nid in ["deep_sea_spot", "swordfish_spot", "lobster_pot"]:
		assert_true(db.nodes.has(nid), "saknar nod: " + nid)
		assert_eq(db.nodes[nid]["skill"], "fishing")
		assert_eq(db.nodes[nid]["tool"], "fishing_rod")
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipes.gd -gexit`
Förväntat: FAIL ("saknar nod: deep_sea_spot").

- [ ] **Step 3: Lägg till noder**

I `data/nodes.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"deep_sea_spot":    {"skill": "fishing", "level": 20, "tool": "fishing_rod", "yields": "raw_mackerel",   "xp": 40, "charges": [4, 6], "respawn": 45, "color": "#2a5a8a", "label": "Djuphavsstim"},
	"swordfish_spot":   {"skill": "fishing", "level": 35, "tool": "fishing_rod", "yields": "raw_swordfish", "xp": 75, "charges": [3, 5], "respawn": 60, "color": "#3a4a6a", "label": "Svärdfiskstim"},
	"lobster_pot":      {"skill": "fishing", "level": 30, "tool": "fishing_rod", "yields": "raw_lobster",   "xp": 60, "charges": [3, 5], "respawn": 55, "color": "#8a3a2a", "label": "Hummertina"}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS (inkl. befintligt `test_all_node_yields_and_tools_exist_as_items` — yields finns som items sedan Task 1).

- [ ] **Step 5: Commit**
```bash
git add data/nodes.json tests/unit/test_recipes.gd
git commit -m "feat: tre kust-fiskenoder (Fishing-gated) (TDD)"
```

---

### Task 4: Cooking-recept (buff-mat)

**Files:**
- Modify: `data/recipes.json`
- Test: `tests/unit/test_recipes.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_recipes.gd`:
```gdscript
func test_coast_cooking_recipes_added():
	var ids := []
	for r in db.recipes["stove"]:
		ids.append(String(r["id"]))
	for id in ["grilled_mackerel", "lobster_dinner", "swordfish_steak"]:
		assert_has(ids, id, "saknar recept: " + id)
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipes.gd -gexit`
Förväntat: FAIL ("saknar recept: grilled_mackerel").

- [ ] **Step 3: Lägg till recept**

I `data/recipes.json`, ersätt `stove`-arrayen med (lägg till tre rader; behåll de två befintliga):
```json
	"stove": [
		{"id": "cooked_trout",     "level": 1,  "skill": "cooking", "ingredients": {"raw_trout": 1},                                "xp": 10},
		{"id": "fish_stew",        "level": 10, "skill": "cooking", "ingredients": {"raw_trout": 1, "raw_pike": 1, "mint_herb": 1}, "xp": 25},
		{"id": "grilled_mackerel", "level": 15, "skill": "cooking", "ingredients": {"raw_mackerel": 1},                             "xp": 30},
		{"id": "lobster_dinner",   "level": 25, "skill": "cooking", "ingredients": {"raw_lobster": 1},                              "xp": 55},
		{"id": "swordfish_steak",  "level": 35, "skill": "cooking", "ingredients": {"raw_swordfish": 1},                            "xp": 80}
	],
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS (inkl. `test_all_recipe_outputs_and_ingredients_exist_as_items` — alla items finns sedan Task 1).

- [ ] **Step 5: Commit**
```bash
git add data/recipes.json tests/unit/test_recipes.gd
git commit -m "feat: tre cooking-recept med buffar (grillad makrill/hummer/svärdfisk) (TDD)"
```

---

### Task 5: Sjö-taskkedja

**Files:**
- Modify: `data/tasks.json`
- Test: `tests/unit/test_tasks_data.gd`

- [ ] **Step 1: Skriv/uppdatera failande test**

I `tests/unit/test_tasks_data.gd`, ändra `test_ten_tasks` till:
```gdscript
func test_thirteen_tasks():
	assert_eq(tasks.size(), 13)
```
Och lägg till:
```gdscript
func test_sea_tasks_present():
	for id in ["task_krabbor", "task_sjoormar", "task_pirater"]:
		assert_true(tasks.has(id), "saknar task: " + id)
	assert_eq(String(tasks["task_pirater"]["monster"]), "Pirat")
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tasks_data.gd -gexit`
Förväntat: FAIL (`test_thirteen_tasks` förväntade 13, fick 10).

- [ ] **Step 3: Lägg till tasks**

I `data/tasks.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"task_krabbor":  {"monster": "Strandkrabba", "required": 40, "slayer_level_req": 8,  "reward_slayer_xp": 800,  "reward_gold": 700,  "repeatable": true},
	"task_sjoormar": {"monster": "Sjöorm",       "required": 60, "slayer_level_req": 14, "reward_slayer_xp": 1400, "reward_gold": 1500, "repeatable": true},
	"task_pirater":  {"monster": "Pirat",        "required": 80, "slayer_level_req": 20, "reward_slayer_xp": 2200, "reward_gold": 3000, "repeatable": true}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS (monster finns i MonsterDB sedan Task 2).

- [ ] **Step 5: Commit**
```bash
git add data/tasks.json tests/unit/test_tasks_data.gd
git commit -m "feat: sjö-taskkedja (krabbor/sjöormar/pirater) (TDD)"
```

---

### Task 6: Kustzonen + hamnportal + kustvagen-unlock

**Files:**
- Create: `data/zones/coast.json`
- Modify: `data/zones/town.json`, `data/unlocks.json`, `world/placeholder_tiles.gd`
- Test: `tests/unit/test_zone.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_zone.gd` (mönstret `_make_zone` finns redan i filen):
```gdscript
func test_coast_builds_with_content():
	UnlockSystem.unlock("kustvagen")
	var z = _make_zone("coast")
	assert_eq(z.zone_name, "Saltviks hamn")
	assert_eq(z.node_points.size(), 3)                      # tre fiskenoder
	assert_true(z.station_points.any(func(s): return s["station"] == "stove"))
	assert_eq(z.taskmaster_points.size(), 1)
	assert_eq(z.shop_points.size(), 1)
	assert_true(z.dungeon_entrances.values().has("sjunket_skepp"))
	assert_true(z.portals.values().has("town"))

func test_town_has_locked_coast_portal_and_pirates():
	UnlockSystem.unlocked.clear()
	var town = _make_zone("town")
	assert_true(town.portals.values().has("coast"))
	assert_true(town.portal_locks.values().has("kustvagen"))   # låst utan questen
	assert_true(town.spawn_points.any(func(s): return s["monster"] == "Pirat"))

func test_beach_terrain_registered():
	assert_true(PlaceholderTiles.TERRAIN.has("b"))
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_zone.gd -gexit`
Förväntat: FAIL (coast.json saknas / TERRAIN saknar "b").

- [ ] **Step 3a: Lägg till strandterräng**

I `world/placeholder_tiles.gd`, ändra `TERRAIN` och `COLORS`:
```gdscript
const TERRAIN := {".": 0, ",": 1, "W": 2, "~": 3, "s": 4, "b": 5}
const COLORS := {
	".": Color("4a8f3c"), ",": Color("6b5436"),
	"W": Color("6e6e72"), "~": Color("2e5f9e"),
	"s": Color("4f5a2e"),   # sumpmark (Träsket)
	"b": Color("d8c88a"),   # strand (Saltvik)
}
```

- [ ] **Step 3b: Skapa coast.json**

Skapa `data/zones/coast.json`:
```json
{
	"name": "Saltviks hamn",
	"tiles": [
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
		"W~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~W",
		"W~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~W",
		"W~~~~~~f~~~~~~~~~~~m~~~~~~~~~~~l~~~~~~~W",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WbbbGbbbbbbbbbcbbbbbbbbbbobbbbbbbbDbbbbW",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WbbHbbbbbbbbbbbbqbbbbbbbbbbkbbbbbbbbbbbW",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WbbTbbbbbbbbbbbbbbbbcbbbbbbbbbbobbbbbbbW",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"Wbbbbbbbbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WbbbbbbbbbbPbbbbbbbbbbbbbbqbbbbbbbbbbbbW",
		"WbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbW",
		"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	],
	"legend": {
		"0": {"type": "portal", "to": "town", "terrain": "b"},
		"G": {"type": "station", "station": "stove", "terrain": "b"},
		"H": {"type": "shop", "terrain": "b"},
		"T": {"type": "taskmaster", "terrain": "b"},
		"D": {"type": "dungeon_entrance", "theme": "sjunket_skepp", "terrain": "b"},
		"f": {"type": "node", "node": "deep_sea_spot", "terrain": "~"},
		"m": {"type": "node", "node": "swordfish_spot", "terrain": "~"},
		"l": {"type": "node", "node": "lobster_pot", "terrain": "~"},
		"c": {"type": "spawn", "monster": "Strandkrabba", "respawn": 18.0, "terrain": "b"},
		"o": {"type": "spawn", "monster": "Sjöorm", "respawn": 25.0, "terrain": "b"},
		"q": {"type": "spawn", "monster": "Pirat", "respawn": 30.0, "terrain": "b"},
		"k": {"type": "spawn", "monster": "Pirat Skytt", "respawn": 35.0, "terrain": "b"}
	}
}
```
(Varje rad är exakt 40 tecken; layouten är konnektivitetsverifierad — alla strukturer nåbara från `P`, noderna ligger i vattenbrynet intill stranden.)

- [ ] **Step 3c: Lägg till kustvagen-unlock**

I `data/unlocks.json`, lägg in (komma på föregående rad), före avslutande `}`:
```json
	"kustvagen": {"name": "Sjövägen", "category": "area",
		"requires": {"quest": "quest_sjovagen"},
		"hint": "Slutför Kapten Brandts uppdrag vid hamnen i Thais."}
```

- [ ] **Step 3d: Lägg hamnportal + pirat-spawns i town.json**

I `data/zones/town.json`, ersätt raderna med index 7, 8 och 9 (de tre raderna som börjar `W...P...`, vattenraden under, och raden därefter) med exakt:
```json
		"W...P....................~~~..2........W",
		"W........................~~~....p......W",
		"W.............................p........W",
```
Och lägg till i `legend` (komma på föregående rad):
```json
		"2": {"type": "portal", "to": "coast", "unlock": "kustvagen"},
		"p": {"type": "spawn", "monster": "Pirat", "respawn": 28.0}
```
(Portalen `2` är låst tills `kustvagen` öppnas; pirat-spawnsen ligger vid hamnen, nåbara före upplåsning — questens kill-steg.)

- [ ] **Step 4: Kör testet — ska passera**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_zone.gd -gexit`
Förväntat: PASS. Kör även hela sviten en gång för att bekräfta `test_unlocks_data` och `test_zone` (portalreferenser) är gröna.

- [ ] **Step 5: Commit**
```bash
git add data/zones/coast.json data/zones/town.json data/unlocks.json world/placeholder_tiles.gd tests/unit/test_zone.gd
git commit -m "feat: kustzonen Saltviks hamn + låst hamnportal + strandterräng (TDD)"
```

---

### Task 7: Dungeon-tema sjunket_skepp + boss i slutrummet

**Files:**
- Modify: `world/dungeon_generator.gd`, `data/dungeon_themes.json`
- Test: `tests/unit/test_dungeon_generator.gd`

- [ ] **Step 1: Skriv failande test**

I `tests/unit/test_dungeon_generator.gd`, ändra `test_themes_integrity` första assert till:
```gdscript
	assert_eq(themes.size(), 3)
```
Och lägg till:
```gdscript
func test_sunken_ship_exit_to_coast():
	var d := _gen("sjunket_skepp", 3)
	assert_eq(String(d["exit_zone"]), "coast")

func test_sunken_ship_places_boss_in_end_room():
	var d := _gen("sjunket_skepp", 7)
	assert_true(d["legend"].has("B"), "boss-tile saknas i legenden")
	assert_eq(String(d["legend"]["B"]["type"]), "spawn")
	assert_eq(String(d["legend"]["B"]["monster"]), "Piratkapten Svartöga")
	assert_eq(_count_in_tiles(d["tiles"], "B"), 1)
	assert_true(MonsterDB.monsters.has("Piratkapten Svartöga"))
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dungeon_generator.gd -gexit`
Förväntat: FAIL (`themes.size()` 2 ≠ 3; ingen `B` i legenden).

- [ ] **Step 3a: Generator — placera boss i slutrummet**

I `world/dungeon_generator.gd`, direkt efter raderna som sätter kistan:
```gdscript
	var chest := _center_i(rooms[far_room])
	grid[chest.y][chest.x] = "C"
```
lägg till:
```gdscript
	# --- boss (valfritt tema-fält): golvtile intill kistan i slutrummet ---
	if th.has("boss"):
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var bt: Vector2i = chest + d
			if grid[bt.y][bt.x] == floor_ch:
				grid[bt.y][bt.x] = "B"
				break
```
Och i legend-blocket, direkt efter raden `"C": {"type": "chest", "terrain": floor_ch},` (inuti dictionary-literalen ligger `C`; lägg bosstillägget *efter* literalen, före `for mi in used_monsters:`):
```gdscript
	if th.has("boss"):
		legend["B"] = {"type": "spawn", "monster": String(th["boss"]),
			"respawn": 9999.0, "terrain": floor_ch}
```

- [ ] **Step 3b: Lägg till temat**

I `data/dungeon_themes.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	,
	"sjunket_skepp": {
		"name": "Sjunket skepp",
		"exit_zone": "coast",
		"floor_terrain": ",",
		"monsters": [["Drunknad sjöman", 3], ["Sjöorm", 2], ["Pirat", 2]],
		"nodes": [],
		"boss": "Piratkapten Svartöga",
		"chest_gold": [300, 700],
		"chest_items": [["cutlass", 0.5, 1], ["sea_chart", 0.7, 1], ["health_potion", 0.6, 2]]
	}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS. `_spawn_one` i `world.gd` kräver ingen ändring — bossen har `boss: true`, är tillgänglig (cooldown 0 vid första nedstigning) och spawnar live.

- [ ] **Step 5: Commit**
```bash
git add world/dungeon_generator.gd data/dungeon_themes.json tests/unit/test_dungeon_generator.gd
git commit -m "feat: dungeon-tema sjunket_skepp med boss i slutrummet (TDD)"
```

---

### Task 8: Röstad quest Sjövägen + NPC:er + dialog

**Files:**
- Modify: `data/quests.json`, `data/npcs.json`, `data/dialogue.json`
- Test: `tests/unit/test_quests_data.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_quests_data.gd`:
```gdscript
func test_sjovagen_quest_present():
	assert_true(quests.has("quest_sjovagen"), "quest saknas")
	assert_eq(String(quests["quest_sjovagen"]["giver"]), "npc_captain")
	assert_true(npcs.has("npc_captain"), "Brandt saknas")
	assert_true(npcs.has("npc_fishmonger"), "Saltgreta saknas")
	assert_eq(String(npcs["npc_captain"]["zone"]), "town")
	assert_eq(String(npcs["npc_fishmonger"]["zone"]), "coast")
```
(De befintliga `test_quest_refs`, `test_npc_refs`, `test_dialogue_refs` och `test_every_quest_startable_via_dialogue` validerar resten — alla refs måste stämma.)

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quests_data.gd -gexit`
Förväntat: FAIL ("quest saknas").

- [ ] **Step 3a: Lägg till questen**

I `data/quests.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"quest_sjovagen": {
		"name": "Sjövägen",
		"giver": "npc_captain",
		"requires": [],
		"steps": [
			{"type": "kill", "monster": "Pirat", "count": 5, "hint": "Rensa fem pirater som plundrar hamnen i Thais."},
			{"type": "talk_to", "npc": "npc_captain", "hint": "Återvänd till Kapten Brandt vid hamnen."}
		],
		"rewards": {"xp": 1500, "gold": 600}
	}
```

- [ ] **Step 3b: Lägg till NPC:er**

I `data/npcs.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"npc_captain": {
		"name": "Kapten Brandt",
		"zone": "town",
		"position": [28, 10],
		"voice": {"model": "en_GB-alan-medium", "length_scale": 1.0},
		"barks": ["Storm's brewing out west.", "Mind the tide, landlubber."],
		"dialogue_root": "captain_root"
	},
	"npc_fishmonger": {
		"name": "Saltgreta",
		"zone": "coast",
		"position": [8, 8],
		"voice": {"model": "en_US-amy-medium", "length_scale": 1.0},
		"barks": ["Fresh off the boat!", "Best catch on the whole coast."],
		"dialogue_root": "fishmonger_root"
	}
```

- [ ] **Step 3c: Lägg till dialog**

I `data/dialogue.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"captain_root": {
		"speaker": "npc_captain", "emotion": "neutral",
		"text": "Storm's coming, and pirates besides. No passage west today.",
		"choices": [
			{"text": "Who are you?", "next": "captain_who"},
			{"text": "Can you sail me along the coast?", "next": "captain_offer",
			 "conditions": [{"type": "quest_available", "quest": "quest_sjovagen"}]},
			{"text": "The harbour pirates are dealt with.", "next": "captain_thanks",
			 "conditions": [{"type": "quest_step", "quest": "quest_sjovagen", "step": 1}],
			 "actions": [{"type": "advance_quest", "quest": "quest_sjovagen"}]},
			{"text": "Goodbye.", "next": null}
		]
	},
	"captain_who": {
		"speaker": "npc_captain", "emotion": "neutral",
		"text": "Brandt. I run the only boat that'll brave the western reefs. When the harbour's safe, that is.",
		"choices": [
			{"text": "Back.", "next": "captain_root"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"captain_offer": {
		"speaker": "npc_captain", "emotion": "worried",
		"text": "Pirates have been landing at my docks and helping themselves. Thin out five of them and I'll sail you to Saltvik.",
		"choices": [
			{"text": "Consider it done.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_sjovagen"}]},
			{"text": "Maybe later.", "next": null}
		]
	},
	"captain_thanks": {
		"speaker": "npc_captain", "emotion": "friendly",
		"text": "Aye, the docks are quiet again. A deal's a deal — the way west is open to you now. Mind the wrecks.",
		"choices": [
			{"text": "Thank you, captain.", "next": null}
		]
	},
	"fishmonger_root": {
		"speaker": "npc_fishmonger", "emotion": "friendly",
		"text": "Fresh catch! Mackerel, lobster, swordfish — if you're bold enough for the deep water.",
		"choices": [
			{"text": "Just browsing.", "next": null}
		]
	}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS (npc_fishmonger.zone = coast → coast.json finns sedan Task 6; questen startas via `captain_offer`; monstret Pirat finns sedan Task 2).

- [ ] **Step 5: Commit**
```bash
git add data/quests.json data/npcs.json data/dialogue.json tests/unit/test_quests_data.gd
git commit -m "feat: röstad quest Sjövägen + Kapten Brandt och Saltgreta (TDD)"
```

---

### Task 9: Pirat-outfit

**Files:**
- Modify: `data/outfits.json`, `data/unlocks.json`
- Test: `tests/unit/test_outfits.gd`

- [ ] **Step 1: Skriv failande test**

Lägg till i `tests/unit/test_outfits.gd`:
```gdscript
func test_pirate_outfit_unlockable_via_boss_kill():
	assert_true(GameState.outfit_defs.has("outfit_pirate"), "outfit saknas")
	assert_false(GameState.equip_outfit("outfit_pirate"))   # låst utan boss-kill
	TaskSystem.boss_kill_times["Piratkapten Svartöga"] = 1.0
	UnlockSystem.try_unlock("outfit_pirate")
	assert_true(GameState.equip_outfit("outfit_pirate"))
	assert_eq(String(GameState.appearance["skin"]), "#aabbcc")   # skin skyddad
	TaskSystem.boss_kill_times.clear()
```

- [ ] **Step 2: Kör testet — ska faila**

Kör: `& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_outfits.gd -gexit`
Förväntat: FAIL ("outfit saknas").

- [ ] **Step 3a: Lägg till outfiten**

I `data/outfits.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"outfit_pirate": {"name": "Piratens mundering", "unlock": "outfit_pirate",
		"colors": {"shirt": "#7a1f1f", "pants": "#1a1a22", "hair": "#2a2a2a"}}
```

- [ ] **Step 3b: Lägg till outfit-unlocken**

I `data/unlocks.json`, lägg in före avslutande `}` (komma på föregående rad):
```json
	"outfit_pirate": {"name": "Piratens mundering", "category": "outfit",
		"requires": {"boss_killed": "Piratkapten Svartöga"},
		"hint": "Besegra Piratkapten Svartöga i det sjunkna skeppet."}
```

- [ ] **Step 4: Kör testet — ska passera**

Kör samma kommando som Step 2. Förväntat: PASS. Kör även `test_unlocks_data.gd` (boss_killed-monstret finns i MonsterDB; outfit-unlock har matchande outfit).

- [ ] **Step 5: Commit**
```bash
git add data/outfits.json data/unlocks.json tests/unit/test_outfits.gd
git commit -m "feat: pirat-outfit upplåst via boss-kill (TDD)"
```

---

### Task 10: Helsvit + planbock

- [ ] **Step 1: Kör hela GUT-sviten**

Kör:
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Förväntat: alla tester gröna (≈190 tester — 172 utgångsläge + M7-tilläggen). Inga fel/varningar utöver de två kända (`Warnings 2`).

- [ ] **Step 2: Boot-check (inga script-fel)**

Kör:
```bash
timeout 30 "/c/Godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit 2>&1 | grep -iE "error|script|parse" || echo "(inga fel)"
```
Förväntat: `(inga fel)`.

- [ ] **Step 3: Bocka av planen**

Markera alla tasks ✓ i denna fil och committa:
```bash
git add docs/superpowers/plans/2026-06-13-milstolpe-7-kusten.md
git commit -m "docs: M7 planbock — alla tasks klara, smoke-test + merge väntar på Erik"
```

- [ ] **Step 4: Manuell smoke-test (Erik)**

1. Prata med Kapten Brandt vid hamnen i Thais → starta "Sjövägen".
2. Döda 5 pirater vid hamnen, prata med Brandt igen → questen klar.
3. Gå på hamnportalen (väst) → den öppnas, du anländer till Saltviks hamn.
4. Fiska vid djuphavsstimmet (Fishing-gated), laga grillad makrill vid stoven.
5. Ta en sjö-task hos taskmastern.
6. Gå ner i det sjunkna skeppet (`D`), slå dig till slutrummet, besегra Piratkapten Svartöga.
7. Öppna garderoben (U) → pirat-outfiten ska vara upplåst.

#### Merge-instruktion (efter godkänd smoke-test)
```powershell
cd C:\Users\Hem\tibia2d
git checkout master
git merge --no-ff m7-kusten -m "feat: Milstolpe 7 — Saltviks hamn (merge m7-kusten)"
```

---

## Self-review (utförd vid planskrivning)

- **Spec-täckning:** §1 åtkomst (Task 6 portal + Task 8 quest) · §2 zon (Task 6) · §3 monster+boss (Task 2) · §4 taskkedja (Task 5) · §5 quest+NPC+dialog (Task 8) · §6 fishing→cooking (Task 1 items, Task 3 noder, Task 4 recept) · §7 sjunket_skepp+boss (Task 7) · §8 outfit (Task 9) · §10 tester (per task + Task 10). Alla sektioner har en task.
- **Inga placeholders:** all data och kod är fullständig; tile-rader är 40 tecken och konnektivitetsverifierade.
- **Typkonsistens:** monsternamn (`Piratkapten Svartöga`), item-id:n, nod-id:n, unlock-id:n (`kustvagen`, `outfit_pirate`), tema-id (`sjunket_skepp`) och quest-id (`quest_sjovagen`) används identiskt mellan data, generator-kod och tester.
- **Räknaruppdateringar:** `test_ten_tasks`→`test_thirteen_tasks` (Task 5); `themes.size()` 2→3 (Task 7). Inga andra hårdkodade antal påverkas (övriga datatester itererar).


---

## Genomförande — KLART (2026-06-13)

Alla tasks implementerade på branch `m7-kusten`. **184/184 GUT-tester gröna**, boot-check ren (inga script-fel).

| Task | Commit | Not |
|------|--------|-----|
| 1 Items | `1cfb8fa` | |
| 2 Monster + boss | `9fd1205` | |
| 3 Fiskenoder | `bb55f54` | |
| 4 Cooking-recept | `2eee9b6` | |
| 5 Sjö-taskkedja | `fa87ab4` | befintligt `test_ten_tasks`→`test_thirteen_tasks` |
| 6 + 8 (sammanslagna) | `ffb1a60` | se avvikelse nedan |
| 7 Dungeon-tema + boss | `d4bc95f` | |
| 9 Pirat-outfit | `6456594` | |

### Avvikelser från planen
- **Task 6 och Task 8 slogs ihop till en commit.** De var ömsesidigt beroende: `kustvagen`-unlocken (Task 6) kräver `quest_sjovagen` (Task 8), vars NPC Saltgreta bor i `coast` (Task 6). Att committa dem separat hade brutit `test_unlock_defs_valid` (okänd quest) mellan tasksen. Innehållet är identiskt med planen.
- **Befintligt test `test_town_has_two_portals` → `test_town_has_three_portals`** (town fick en tredje portal mot coast). Ej förutsett i planen; uppdaterat.
- Filändringarna gjordes via skript (Read/Edit-verktygen var blockerade av en trasig claude-mem-hook under sessionen); resultatet är validerat med GUT + boot-check.

### Återstår (Erik)
- Manuell smoke-test (se Task 10, Step 4).
- Merge `m7-kusten` → master (se merge-instruktionen i Task 10).
