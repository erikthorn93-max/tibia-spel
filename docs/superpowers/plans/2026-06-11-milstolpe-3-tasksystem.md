# Tibia2D Milstolpe 3 — Tasksystem: Implementationsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tasksystemet spelbart: Taskmaster-NPC med 8 tasks, Slayer-progression, unlocks som öppnar gated områden, bossen Ghulkungen med 1 h cooldown, bestiary (100/400/1000, +2 %/tier) med panel, debug-konsol, save v3.

**Architecture:** Två nya autoloads — `TaskSystem` (tasks/bestiary/Slayer-XP) och `UnlockSystem` (minimalt unlock-set, grund för M5). Zoner får legend-typerna `gate` och `taskmaster`; gates öppnas live via `UnlockSystem.unlock_added`. Kill-flödet: `monster._die()` → `TaskSystem.record_kill()`. All data i JSON.

**Tech Stack:** Godot 4.6.2 (`C:\Godot\Godot_v4.6.2-stable_win64.exe`), GDScript, GUT 9.6.0, JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-11-milstolpe-3-tasksystem-design.md`

**Viktiga kommandon:**
```bash
# Tester (bash — PowerShell-redirect sväljer Godot-output):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
# Re-import (krävs efter nya class_name/scener):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
# Boot-check:
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/monsters.json` | Ersätt | +Jättespindel, Skelettkrigare, Fantom, Ghulkungen (boss) |
| `data/items.json` | Modifiera | +`boss_crown` (trofé, 2500 guld) |
| `data/tasks.json` | Skapa | 8 tasks enligt spec-tabellen |
| `data/zones/cave.json` | Ersätt | +6 rader: Spindelhålan, Kryptan, Bossrummet bakom gates |
| `data/zones/forest.json` | Ersätt | +5 rader: Mörka dungen bakom gate |
| `data/zones/town.json` | Modifiera | +Taskmaster `T` på stationsraden |
| `autoload/unlock_system.gd` | Skapa | Unlock-set, signal `unlock_added` |
| `autoload/task_system.gd` | Skapa | Tasks, bestiary, Slayer-XP, boss-cooldown |
| `project.godot` | Modifiera | +2 autoloads, input-actions `toggle_bestiary` (B), `toggle_console` (§) |
| `world/zone.gd` | Modifiera | Legend-typer `gate`/`taskmaster`, live gate-öppning |
| `entities/monster/monster.gd` | Modifiera | `record_kill`, boss-skala, boss-kill-registrering |
| `entities/player/player.gd` | Modifiera | Skada × `damage_multiplier` |
| `entities/taskmaster_npc.gd/.tscn` | Skapa | Klickbar NPC → taskpanel |
| `entities/boss_marker.gd` | Skapa | "Ghulkungen är inte här..."-markör + respawn vid cooldown-slut |
| `autoload/world.gd` | Modifiera | Spawnar taskmaster; boss-cooldown-hantering |
| `autoload/save_manager.gd` | Modifiera | SAVE_VERSION 3 + migrering |
| `ui/task_panel.gd` | Skapa | Tillgängliga/Aktiva/Klara tasks |
| `ui/bestiary_panel.gd` | Skapa | B-panel: kills, tiers, bonus |
| `ui/debug_console.gd` | Skapa | §-konsol med kommandon |
| `ui/hud.gd` | Modifiera | Taskrad, `open_tasks()`, paneler |
| `tests/unit/test_unlock_system.gd` | Skapa | unlock/is_unlocked/idempotens/signal |
| `tests/unit/test_task_system.gd` | Skapa | take/abandon/complete/slots/belöningar |
| `tests/unit/test_bestiary.gd` | Skapa | kill-räkning, tiers, damage_multiplier |
| `tests/unit/test_tasks_data.gd` | Skapa | Datavalidering tasks ↔ monster ↔ gates |
| `tests/unit/test_zone.gd` | Modifiera | +gate-parsing, gate öppnas |
| `tests/unit/test_save.gd` | Modifiera | +v2→v3-migrering |

---

### Task 0: Branch

- [x] **Step 1: Skapa feature-branch**

```powershell
git -C C:\Users\Hem\tibia2d checkout -b m3-tasksystem
```

---

### Task 1: Monster- och itemdata

**Files:**
- Replace: `data/monsters.json`
- Modify: `data/items.json`
- Test: `tests/unit/test_databases.gd` (befintlig, ska förbli grön — den validerar att loot-items finns)

- [x] **Step 1: Ersätt `data/monsters.json`** (befintliga 5 oförändrade + 4 nya):

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
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.06}]},
	"Jättespindel": {"hp": 160, "atk": 24, "exp": 110, "speed": 2.6, "cooldown": 1.2, "aggro": 7, "color": "#3a2a1a",
		"loot": [{"item": "spider_silk", "min": 1, "max": 3, "chance": 0.8},
		         {"item": "iron_coin", "min": 15, "max": 40, "chance": 0.6},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.08}]},
	"Skelettkrigare": {"hp": 200, "atk": 28, "exp": 150, "speed": 2.0, "cooldown": 1.4, "aggro": 7, "color": "#b8b09a",
		"loot": [{"item": "bone_chips", "min": 2, "max": 4, "chance": 0.8},
		         {"item": "iron_coin", "min": 20, "max": 50, "chance": 0.8},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.08}]},
	"Fantom": {"hp": 260, "atk": 34, "exp": 220, "speed": 2.2, "cooldown": 1.6, "aggro": 8, "color": "#8a9ac8",
		"loot": [{"item": "iron_coin", "min": 30, "max": 80, "chance": 0.9},
		         {"item": "health_potion", "min": 1, "max": 1, "chance": 0.1},
		         {"item": "mana_potion", "min": 1, "max": 1, "chance": 0.08}]},
	"Ghulkungen": {"hp": 800, "atk": 40, "exp": 800, "speed": 1.6, "cooldown": 1.8, "aggro": 9, "color": "#3a5a2a", "boss": true,
		"loot": [{"item": "boss_crown", "min": 1, "max": 1, "chance": 1.0},
		         {"item": "iron_coin", "min": 200, "max": 400, "chance": 1.0},
		         {"item": "health_potion", "min": 1, "max": 2, "chance": 0.5}]}
}
```

- [x] **Step 2: Lägg till i `data/items.json`** (efter `attack_rune`-raden, glöm inte komma på raden före):

```json
	"boss_crown":      {"name": "Ghulkungens krona", "type": "trophy",  "value": 2500, "color": "#e8d44a"}
```

- [x] **Step 3: Kör tester — förvänta PASS** (test_databases validerar loot-items mot items.json)

- [x] **Step 4: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: 4 nya monster inkl boss Ghulkungen + kronan (data)"
```

---

### Task 2: UnlockSystem-autoload

**Files:**
- Create: `autoload/unlock_system.gd`
- Modify: `project.godot` (autoload)
- Test: `tests/unit/test_unlock_system.gd`

- [x] **Step 1: Skriv failande test `tests/unit/test_unlock_system.gd`**

```gdscript
extends GutTest

var us

func before_each():
	us = load("res://autoload/unlock_system.gd").new()

func after_each():
	us.free()

func test_starts_empty():
	assert_eq(us.unlocked.size(), 0)
	assert_false(us.is_unlocked("spindelhalan"))

func test_unlock_sets_and_emits():
	watch_signals(us)
	us.unlock("spindelhalan")
	assert_true(us.is_unlocked("spindelhalan"))
	assert_signal_emitted_with_parameters(us, "unlock_added", ["spindelhalan"])

func test_unlock_idempotent():
	watch_signals(us)
	us.unlock("kryptan")
	us.unlock("kryptan")
	assert_signal_emit_count(us, "unlock_added", 1)
	assert_eq(us.unlocked.size(), 1)
```

- [x] **Step 2: Kör — förvänta FAIL** (filen finns inte)

- [x] **Step 3: Skapa `autoload/unlock_system.gd`**

```gdscript
extends Node
## Autoload: UnlockSystem. Minimalt unlock-set — M5 bygger vidare.

signal unlock_added(id: String)

var unlocked: Dictionary = {}   # id -> true (set-semantik)

func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	unlock_added.emit(id)

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)
```

- [x] **Step 4: Registrera autoload i `project.godot`** — i `[autoload]`-sektionen, efter `MonsterDB`-raden:

```ini
UnlockSystem="*res://autoload/unlock_system.gd"
```

- [x] **Step 5: Kör tester — förvänta PASS**

- [x] **Step 6: Commit**

```powershell
git -C C:\Users\Hem\tibia2d add -A; git -C C:\Users\Hem\tibia2d commit -m "feat: UnlockSystem-autoload (TDD)"
```

---

### Task 3: tasks.json + TaskSystem-autoload

**Files:**
- Create: `data/tasks.json` (8 tasks per spec-tabellen)
- Create: `autoload/task_system.gd`
- Modify: `project.godot` (autoload `TaskSystem` efter `UnlockSystem`)
- Test: `tests/unit/test_task_system.gd`, `tests/unit/test_bestiary.gd`, `tests/unit/test_tasks_data.gd`

- [x] **Step 1: Skapa `data/tasks.json`** — id:n `task_ratta`, `task_orm`, `task_spindel`, `task_skelett`, `task_ghoul`, `task_jattespindel`, `task_skelettkrigare`, `task_fantom`. Fält per spec: `monster, required, slayer_level_req, reward_slayer_xp, reward_gold, unlocks (valfri), repeatable: true`.

- [x] **Step 2: Skriv failande tester.** TaskSystem instansieras med `.new()`; GameState/UnlockSystem nås som autoloads och återställs i `before_each` (`GameState.skills["slayer"] = {"level": N, "xp": 0}`, `GameState.gold = 0`, `UnlockSystem.unlocked.clear()`). Täcker:
  - `test_task_system.gd`: take (slayer-krav + slots), abandon nollar progress, record_kill räknar bara aktiv task, claim ger XP+guld+unlock, repeterbar omtagning ger halv XP/guld och ingen ny unlock, slots 1/2/3 vid Slayer 1/15/30, boss-gate öppnas när ghoul+fantom klarade, Slayer-XP delas ENDAST ut via claim/boss.
  - `test_bestiary.gd`: kills räknas även utan aktiv task, tier-trösklar 100/400/1000, `damage_multiplier` = 1.0/1.02/1.04/1.06, boss-kill ger 2000 Slayer-XP + cooldown-timestamp, `boss_available` falsk under cooldown.
  - `test_tasks_data.gd`: varje tasks `monster` finns i MonsterDB; varje `unlocks`-id + `bossrummet` har gate-tile i någon zon-JSON (körs först efter Task 6 — skrivs nu, väntas FAIL på gates tills zondata finns).

- [x] **Step 3: Skapa `autoload/task_system.gd`** — API per spec:

```gdscript
extends Node
signal task_taken(id); signal task_progress(id); signal task_completed(id); signal bestiary_changed

const TIER_THRESHOLDS := [100, 400, 1000]
const BOSS_COOLDOWN := 3600.0
const BOSS_SLAYER_XP := 2000

var tasks: Dictionary = {}       # id -> def (laddas i _init från data/tasks.json)
var active: Dictionary = {}      # id -> progress (int)
var completed: Dictionary = {}   # id -> true (claimad minst en gång)
var bestiary: Dictionary = {}    # monster_name -> kills
var boss_kill_times: Dictionary = {}  # monster_name -> unix-ts

func slots() -> int                       # 1 + slayer>=15 + slayer>=30
func take_task(id) -> bool                # ej aktiv, slayer-krav, lediga slots
func abandon_task(id) -> void
func record_kill(monster_name) -> void    # bestiary++, aktiv progress++, boss => XP+ts
func is_task_done(id) -> bool             # progress >= required
func claim_reward(id) -> bool             # halv belöning om completed.has(id); unlock + boss-gate-check
func tier(monster_name) -> int
func damage_multiplier(monster_name) -> float   # 1.0 + 0.02 * tier
func boss_available(monster_name) -> bool       # now - ts >= 3600
func boss_cooldown_left(monster_name) -> float
```

Boss-gate: i `claim_reward`, om `completed` har både `task_ghoul` och `task_fantom` → `UnlockSystem.unlock("bossrummet")`.

- [x] **Step 4: Registrera autoload, kör tester — task/bestiary PASS** (tasks_data-gates får vänta på Task 6)
- [x] **Step 5: Commit** `feat: TaskSystem-autoload med bestiary och boss-cooldown (TDD)`

---

### Task 4: Save v3

**Files:** Modify `autoload/save_manager.gd`, `tests/unit/test_save.gd`

- [x] **Step 1: Failande tester:** `SAVE_VERSION == 3`; v2-snapshot (utan task-fält) laddar felfritt och ger tomma defaults; roundtrip bevarar `tasks_active/tasks_completed/bestiary/unlocked/boss_kill_times`.
- [x] **Step 2:** `SAVE_VERSION := 3`; `save_game()` skriver de fem nya fälten från TaskSystem/UnlockSystem; `load_game()` läser med `.get(..., {})`-defaults (v2→v3-migrering gratis).
- [x] **Step 3: Kör tester — PASS. Commit** `feat: save v3 — tasks, bestiary, unlocks, boss-cooldowns`

---

### Task 5: Zon-gates + taskmaster-legend

**Files:** Modify `world/zone.gd`, `tests/unit/test_zone.gd`

- [x] **Step 1: Failande tester** (mot temporär inline-testzon? Nej — gates testas mot cave.json efter Task 6; skriv testerna nu mot cave: gate-tiles parsas till `gate_points`, blockerade före unlock, `UnlockSystem.unlock("spindelhalan")` öppnar live: `is_walkable == true` efteråt. `before_each` rensar `UnlockSystem.unlocked`.)
- [x] **Step 2: zone.gd:**
  - Nya legend-typer i `build()`-match: `"gate"` → `gate_points[t] = e["unlock"]`; ritas som `"W"`-tile och blockeras om `not UnlockSystem.is_unlocked(id)`, annars normal terräng. Spara gate-terräng (default `","`) för öppning. `"taskmaster"` → `taskmaster_points.append(t)`, blocked.
  - `UnlockSystem.unlock_added.connect(_on_unlock_added)` i `build()`; handlern öppnar matchande gates: sätt terräng-tile, `_walkable[t] = true`, `_astar.set_point_solid(t, false)`.
- [x] **Step 3: Kör — zone-gatetesterna FAIL tills Task 6 (cave saknar gates). Commit ihop med Task 6.**

---

### Task 6: Zondata — nya områden

**Files:** Replace `data/zones/cave.json` (+6 rader), `data/zones/forest.json` (+5 rader), Modify `data/zones/town.json`

- [x] **Step 1: cave.json** — infoga 6 rader före bottenväggen: gaterad väggrad med `1`(spindelhålan, kol 10), `2`(kryptan, kol 23), `3`(bossrummet, kol 33), därunder tre kammare avdelade med väggar: `J` Jättespindel-spawns (x2), `S` Skelettkrigare-spawns (x2), `X` Ghulkungen-spawn (x1). Legend: `1/2/3` = gate med unlock-id, `J/S` = spawn, `X` = spawn Ghulkungen respawn 3600.
- [x] **Step 2: forest.json** — infoga 5 rader före bottenväggen: gaterad väggrad med `1`(morka_dungen, kol 18), kammare med `F` Fantom-spawns (x3), terräng `,`.
- [x] **Step 3: town.json** — `T` på stationsraden (`W..A.G.L.R..H..T...`), legend `"T": {"type": "taskmaster"}`.
- [x] **Step 4: Kör tester — test_zone + test_tasks_data nu PASS. Commit** `feat: gates + nya områden (spindelhålan, kryptan, bossrummet, mörka dungen) + taskmaster-tile`

---

### Task 7: Stridsintegration — record_kill, boss, skadebonus

**Files:** Modify `entities/monster/monster.gd`, `entities/player/player.gd`, `autoload/world.gd`; Create `entities/boss_marker.gd`

- [x] **Step 1: monster.gd:** `setup()`: `is_boss := bool(d.get("boss", false))` → `scale = Vector2(2, 2)`. `_die()`: `TaskSystem.record_kill(monster_name)` (TaskSystem hanterar boss-XP/cooldown internt).
- [x] **Step 2: player.gd `_update_attack`:** `dmg = roundf(dmg * TaskSystem.damage_multiplier(target.monster_name))` (minst originalskadan vid tier 0).
- [x] **Step 3: world.gd `_spawn_one`:** om monstret är boss och `not TaskSystem.boss_available(namn)` → spawna `boss_marker.gd` istället (Node2D som var sekund kollar: cooldown slut → `World.spawn_monster(...)` + `queue_free()`; spelare inom 6 tiles → HUD-meddelande "Ghulkungen är inte här... (X min)" max var 10:e sekund).
- [x] **Step 4: Kör tester + boot-check. Commit** `feat: kill-registrering, bossmekanik med cooldown-markör, bestiary-skadebonus`

---

### Task 8: Taskmaster-NPC + taskpanel

**Files:** Create `entities/taskmaster_npc.gd` + `.tscn`, `ui/task_panel.gd`; Modify `autoload/world.gd`, `ui/hud.gd`

- [x] **Step 1: taskmaster_npc.gd/.tscn** — kopiera shop_npc-mönstret (Polygon2D + Label "Taskmastern" + ClickArea); klick intill → `World.hud.open_tasks()`, annars "Gå närmare Taskmastern."
- [x] **Step 2: world.gd `_spawn_world_objects`:** spawna taskmaster för `zone.taskmaster_points`.
- [x] **Step 3: ui/task_panel.gd** — programmatisk PanelContainer (recipe_panel-mönstret) med `open()`: tre sektioner — Tillgängliga (filtrerade på slayer-nivå, "Ta task"-knapp spärrad vid fulla slots), Aktiva ("X/Y" + Avbryt), Klara ("Hämta belöning"). Lyssnar på `task_progress/task_completed` för refresh när öppen. Unlock vid claim → `World.hud.show_message("... har öppnats!")`.
- [x] **Step 4: hud.gd:** `open_tasks()` (stänger recipe/shop), Escape stänger även taskpanelen.
- [x] **Step 5: Boot-check + manuell verifiering. Commit** `feat: Taskmaster-NPC och taskpanel`

---

### Task 9: Bestiary-panel (B)

**Files:** Create `ui/bestiary_panel.gd`; Modify `ui/hud.gd`, `project.godot`

- [x] **Step 1: project.godot:** input-actions `toggle_bestiary` (physical B, keycode 66) och `toggle_console` (physical `, keycode 96 — tangenten under Esc, § på svenskt tangentbord).
- [x] **Step 2: bestiary_panel.gd** — skill_panel-mönstret: rad per monster i MonsterDB-ordning; dödade ≥1: namn, kills, ★-tiers, "+X % skada"; annars "???". Refresh via `TaskSystem.bestiary_changed` + vid visning.
- [x] **Step 3: hud.gd:** toggle på `toggle_bestiary`. Commit `feat: bestiary-panel (B) med tiers och skadebonus`

---

### Task 10: Debug-konsol (§)

**Files:** Create `ui/debug_console.gd`; Modify `ui/hud.gd` (instansiering)

- [x] **Step 1:** CanvasLayer (layer 10) med PanelContainer + RichTextLabel-logg + LineEdit. Toggle via `toggle_console`; när synlig: LineEdit grabbar fokus, `_input` markerar tangenttryck som hanterade (ingen läcka till spelet); när stängd: släpper fokus, noll input-konsumtion.
- [x] **Step 2: Kommandon** (parse via `split(" ")`, okänt → hjälptext):
  `give <item_id> [antal]`, `gold <antal>`, `xp <skill> <mängd>`, `kills <monster> <antal>` (sätter bestiary direkt + bestiary_changed), `unlock <id>`, `tasklist` (alla tasks + status), `tp <zon>`, `heal`, `spawn <monster>` (intill spelaren).
- [x] **Step 3: Boot-check. Commit** `feat: debug-konsol (§) med give/gold/xp/kills/unlock/tasklist/tp/heal/spawn`

---

### Task 11: HUD-taskrad

**Files:** Modify `ui/hud.gd`

- [x] **Step 1:** Label under buffarna: "Skelett 34/100 · Ghoul 12/150" — uppdateras via `task_taken/task_progress/task_completed` + vid claim/abandon (refresh från `TaskSystem.active`). Commit `feat: aktiva tasks i HUD`

---

### Task 12: Slutverifiering

- [x] **Step 1:** Full GUT-svit grön (förväntat ~90+ tester)
- [x] **Step 2:** Re-import + boot-check utan script-/parsefel
- [x] **Step 3:** Perftest: `--perftest` ger min-FPS ≥ 60
- [x] **Step 4:** Slutcommit, kvar på `m3-tasksystem` för manuellt speltest (acceptanskriterier i specen) innan merge
