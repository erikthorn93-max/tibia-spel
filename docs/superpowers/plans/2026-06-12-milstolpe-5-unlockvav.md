# Tibia2D Milstolpe 5 — Unlock-väv: Implementationsplan

**Goal:** UnlockSystem fullt ut — kravdrivna unlocks (skill/quest/task/boss), bump-genvägar, låsta portaler, ny fjärde zon (Träsket) och outfit-unlocks med garderob (U). Agility får ett syfte: tränas av gång, krävs för genvägar.

**Architecture:** `data/unlocks.json` blir centralregister för alla unlock-id:n med krav + hint. UnlockSystem får `can_unlock`/`try_unlock` (utvärderar krav mot GameState/QuestSystem/TaskSystem vid anrop — inga nya beroenden vid boot). Zonlegenden får `shortcut`-typ och `unlock`-fält på portaler; interaktionen är bump (gå mot låst tile → försök låsa upp, annars hint). Outfits är färgscheman i `data/outfits.json` ovanpå appearance-basen; GameState äger `equip_outfit` + ny signal `appearance_changed`.

**Tech Stack:** Godot 4.6.2 (`C:\Godot\Godot_v4.6.2-stable_win64.exe`), GDScript, GUT 9.6.0, JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-12-milstolpe-5-unlockvav-design.md`

**Viktiga kommandon:**
```bash
# Tester (bash — PowerShell-redirect sväljer Godot-output):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
# Boot-check:
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/unlocks.json` | Skapa | Alla unlock-id:n: namn, kategori, krav, hint |
| `data/outfits.json` | Skapa | 5 outfits: färger + unlock-id |
| `data/zones/swamp.json` | Skapa | Träsket: 2 nya monster, nya noder, gate, 3 portaler |
| `data/zones/forest.json` | Modifiera | Låst portal → swamp + stenargenväg över floden |
| `data/zones/cave.json` | Modifiera | Genvägsportal → swamp (agility 15) |
| `data/monsters.json` | Modifiera | +Giftpadda, +Träskdjävul |
| `data/items.json` | Modifiera | +toad_gland, +swamp_essence, +raw_eel, +marsh_herb |
| `data/nodes.json` | Modifiera | +eel_spot (fishing 25), +marsh_patch (herbalism 25) |
| `data/tasks.json` | Modifiera | +task_giftpadda (unlocks traskets_hjarta), +task_traskdjavul |
| `autoload/unlock_system.gd` | Modifiera | defs, can_unlock/try_unlock, display_name/hint_for |
| `autoload/game_state.gd` | Modifiera | outfit_defs, appearance_base, equip_outfit, agility-XP |
| `autoload/save_manager.gd` | Modifiera | SAVE_VERSION 5: outfit_equipped + appearance_base |
| `world/placeholder_tiles.gd` | Modifiera | +terräng `s` (sumpmark) |
| `world/zone.gd` | Modifiera | shortcut-parsning, portal-lås, markörer |
| `entities/player/player.gd` | Modifiera | bump-upplåsning, låst portal, agility-XP, appearance_changed |
| `ui/wardrobe.gd` | Skapa | Garderob (U): outfits, lås, hints |
| `ui/hud.gd` | Modifiera | wardrobe-panel, U-toggle, unlock-namn från defs |
| `project.godot` | Modifiera | input `toggle_wardrobe` (U) |
| `tests/unit/test_unlocks_data.gd` | Skapa | Referensintegritet unlocks/outfits/zoner/tasks |
| `tests/unit/test_unlock_system.gd` | Modifiera | +kravutvärdering, try_unlock |
| `tests/unit/test_outfits.gd` | Skapa | equip bevarar skin, standard återställer |
| `tests/unit/test_zone.gd` | Modifiera | +shortcut/portal-lås/swamp |
| `tests/unit/test_save.gd` | Modifiera | +v4→v5-migrering + roundtrip |
| `tests/unit/test_tasks_data.gd` | Modifiera | 8 → 10 tasks |

**Konventioner:**
- Krav-typer i unlocks.json: `skill`+`level` (effective_skill_level), `quest` (klarad), `task_completed`, `boss_killed`, `unlock` (kedjning). Tom `requires` = ges av extern källa (task-claim).
- Bump-semantik: gå mot låst gate/shortcut/portal → `try_unlock`; lyckas ⇒ unlock_added öppnar + HUD-meddelande; misslyckas ⇒ hint som flytande meddelande.
- Outfits sätter aldrig `skin`. `standard` = tom färgdict = ren bas.
- Agility-XP: +1 per lyckat gångsteg (`player._step`).

---

### Task 0: Branch
- [x] `git checkout -b m5-unlockvav` ✓ (gjort)

### Task 1: Data — unlocks.json + outfits.json + integritetstest
- [x] `tests/unit/test_unlocks_data.gd`: alla unlock-id:n som refereras (zon-gates/shortcuts/portal-lås, tasks `unlocks`, outfits `unlock`) finns i unlocks.json; alla med `requires.skill` pekar på riktig skill; outfits färgnycklar ⊆ {hair, shirt, pants}; varje outfit-unlock har category `outfit`.
- [x] `data/unlocks.json`: spindelhalan/kryptan/morka_dungen/bossrummet (area, tomma krav — task-givna), trasket (area, quest_crypt), traskets_hjarta (area, task-given), genvag_stenarna (shortcut, agility 10), genvag_grottan (shortcut, agility 15), outfit_explorer (quest_welcome), outfit_slayer (task_ghoul), outfit_angler (fishing 30), outfit_ghoul_king (boss Ghulkungen).
- [x] `data/outfits.json`: standard (tom), explorer, slayer, angler, ghoul_king.
- [x] Commit: `feat: unlock- och outfitdata — centralregister med krav + integritetstest`

### Task 2: UnlockSystem — kravutvärdering (TDD)
- [x] Tester: can_unlock per kravtyp (skill via effective level inkl buff, quest, task, boss, kedjning), try_unlock idempotens + unlock vid uppfyllda krav, display_name/hint_for fallback.
- [x] Implementera: ladda unlocks.json i `_init`; `can_unlock`, `try_unlock`, `display_name`, `hint_for`. Befintliga unlock/is_unlocked orörda.
- [x] Commit: `feat: UnlockSystem — kravdrivna unlocks (skill/quest/task/boss/kedja) (TDD)`

### Task 3: Outfits i GameState (TDD)
- [x] Tester (`test_outfits.gd`): equip byter shirt/pants men aldrig skin; standard återställer basen; equip av låst outfit nekas; appearance_base initieras lazy.
- [x] GameState: `outfit_defs` (ladda outfits.json i `_init`), `appearance_base`, `outfit_equipped`, signal `appearance_changed`, `equip_outfit(id) -> bool`.
- [x] Commit: `feat: outfitsystem i GameState — färgscheman ovanpå basutseendet (TDD)`

### Task 4: Save v5 (TDD)
- [x] Tester: v4-snapshot (utan outfit-fält) migrerar → standard + bas=appearance; v5 roundtrip bevarar outfit + bas.
- [x] SAVE_VERSION 5; spara/ladda `outfit_equipped`, `appearance_base`.
- [x] Commit: `feat: save v5 — outfit och basutseende med v4-migrering`

### Task 5: Zone — shortcut, portal-lås, sumpterräng (TDD)
- [x] PlaceholderTiles: terräng `s` (Color "#4f5a2e").
- [x] zone.gd: legendtyp `shortcut` (som gate men i `shortcut_points`; valfri `locked_terrain`, default W; öppnas av unlock_added precis som gates); portal med `unlock`-fält → `portal_locks[t] = uid`; låst portalmarkör gråtonad med hint istället för zonnamn; shortcutmarkör (liten brun romb) när låst.
- [x] Tester: shortcut parsas + blockerad före unlock + öppnas live; låst portal registreras; forest stenargenväg; swamp laddar med noder/spawns/gate.
- [x] Commit: `feat: zon-stöd för genvägar, låsta portaler och sumpterräng (TDD)`

### Task 6: Player — bump-upplåsning + agility-XP
- [x] `_step`: om `next` ej walkable och har lås (gate/shortcut) → try_unlock, annars hint-meddelande. Lyckat steg ger +1 agility-XP.
- [x] `_check_portal`: låst portal → try_unlock; lyckas ⇒ res + "har öppnats"; annars hint, ingen resa.
- [x] `_ready`: koppla `appearance_changed` → visual.apply_appearance.
- [x] Boot-check. Commit: `feat: bump-upplåsning av genvägar/portaler + agility tränas av gång`

### Task 7: Träsket — zon + monster + items + noder + tasks
- [x] monsters.json: Giftpadda (hp 120, atk 20, exp 80), Träskdjävul (hp 230, atk 30, exp 180).
- [x] items.json: toad_gland, swamp_essence, raw_eel, marsh_herb. nodes.json: eel_spot, marsh_patch.
- [x] tasks.json: task_giftpadda (100, slayer 12, unlocks traskets_hjarta), task_traskdjavul (125, slayer 15). test_tasks_data → 10.
- [x] `data/zones/swamp.json` (~40×26, terräng s): portal → forest, genvägsportal → cave (genvag_grottan), gate traskets_hjarta med gold_vein/willow/fler Träskdjävular innanför.
- [x] forest.json: låst portal → swamp (östra kanten, rad 11) + stenargenväg över floden (rad 2, locked_terrain ~). cave.json: genvägsportal → swamp (rad 16 x=36).
- [x] Full svit + boot. Commit: `feat: Träsket — fjärde zonen med nya monster, noder, tasks och genvägsväv`

### Task 8: Garderob (U) + HUD
- [x] `ui/wardrobe.gd` (panelmönster som quest_log): rader per outfit — upplåst/upplåsbar ⇒ "Bär"-knapp (try_unlock + equip), låst ⇒ gråtonad + hint. Aktuell outfit markeras.
- [x] project.godot: input `toggle_wardrobe` (U). hud.gd: instansiera panel, U-toggle, ESC stänger, UNLOCK_NAMES ersätts med `UnlockSystem.display_name`.
- [x] Commit: `feat: garderob (U) — bär upplåsta outfits, se låsta med krav`

### Task 9: Helsvit + boot + planbock
- [x] Full GUT-svit grön, boot-check ren, bocka av planen, commit `docs: bocka av M5-planen`.
