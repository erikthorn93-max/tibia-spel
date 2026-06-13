# Tibia2D Milstolpe 6 — Procedurella dungeons: Implementationsplan

**Goal:** Seedad dungeongenerator (rum + korridorer) som producerar zondata, två tematiska ingångar (Katakomberna i kryptan, Sjunkna graven i Träskets hjärta), skattkista i slutrummet, exit-portal tillbaka. Efemära dungeons — sparfilen skriver alltid ytvärldens zon.

**Architecture:** `DungeonGenerator.generate(theme, seed)` är ren statisk logik som returnerar samma Dictionary-struktur som zonfilerna (+ `theme`/`exit_zone`). `zone.build(id)` refaktoreras till tunt skal över ny `build_from_data(data, id)`. `World.enter_dungeon(theme, seed)` genererar och bygger; `last_surface_zone/tile` spåras för exit-retur och save-översättning. Ny legendtyp `dungeon_entrance` + `chest`.

**Tech Stack:** Godot 4.6.2, GDScript, GUT 9.6.0, JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-12-milstolpe-6-dungeons-design.md`

**Kommandon:** samma som M5-planen (GUT-svit + boot-check via bash).

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/dungeon_themes.json` | Skapa | 2 teman: monsterpooler, noder, kistloot, exit_zone, terräng |
| `world/dungeon_generator.gd` | Skapa | Seedad generator: rum, MST-korridorer, P/exit/kista/spawns |
| `world/zone.gd` | Modifiera | `build_from_data`, legendtyp `chest` + `dungeon_entrance`, entrémarkör |
| `autoload/world.gd` | Modifiera | `enter_dungeon`, `last_surface_zone/tile`, kistspawn, exit-retur |
| `autoload/save_manager.gd` | Modifiera | Dungeonzon översätts till ytzon i snapshot |
| `entities/player/player.gd` | Modifiera | `_check_portal`: dungeon_entrance → enter_dungeon |
| `entities/treasure_chest.gd` | Skapa | Klickbar kista: guld + temaloot, engångsöppning |
| `data/zones/cave.json` | Modifiera | Ingång `D` i kryptan |
| `data/zones/swamp.json` | Modifiera | Ingång `D` i Träskets hjärta |
| `ui/debug_console.gd` | Modifiera | `dungeon <tema> [seed]` |
| `tests/unit/test_dungeon_generator.gd` | Skapa | Determinism, konnektivitet, struktur, spawntak, temaintegritet |
| `tests/unit/test_zone.gd` | Modifiera | build_from_data, entréparsning cave/swamp |
| `tests/unit/test_save.gd` | Modifiera | Save i dungeon skriver ytzon |

**Konventioner:**
- Generatorgrid 44×32, yttermur W. 7–10 rum (5–9 × 4–7), grow(1)-överlappskoll.
- Korridorer: varje nytt rum L-kopplas till närmaste redan kopplade rumscentrum; +2 slumpade extrakopplingar.
- Slutrum = störst BFS-avstånd i rumsgrafen från ingångsrummet → kista `C`.
- Spawns: 1–3 per rum (ej ingångsrummet), viktade ur temapoolen, tak 30.
- Dungeonzon-id: `dungeon:<tema>`; aldrig i sparfil.

---

### Task 0: Branch ✓
### Task 1: Tema-data + generator (TDD) ✓
- [x] `data/dungeon_themes.json` (katakomber, sjunkna_graven).
- [x] Failande tester: determinism, olika seeds skiljer, exakt 1 P/exit/kista, lika radlängder + intakt yttermur, flood-fill-konnektivitet (alla icke-W nåbara från P), spawntak ≤30 + pool ⊆ MonsterDB, temaintegritet (monster/noder/items finns), exit_zone per tema.
- [x] Implementera `world/dungeon_generator.gd`.
- [x] Commit: `feat: dungeongenerator — seedade rum+korridorer med kista och temapooler (TDD)`

### Task 2: Zone — build_from_data + nya legendtyper (TDD) ✓
- [x] Refaktor `build(id)` → läser JSON, delegerar till `build_from_data(data, id)`.
- [x] Legendtyp `chest` (→ `chest_points`, blockerad) och `dungeon_entrance` (→ `dungeon_entrances[t]=tema`, gångbar, mörk trappmarkör med temanamn).
- [x] Tester: generatordata bygger zon; cave/swamp-entréer parsas.
- [x] Commit: `feat: zoner byggs från data — kist- och dungeoningångs-tiles (TDD)`

### Task 3: World + save — enter_dungeon, ytzonsspårning ✓
- [x] `World.enter_dungeon(theme, seed=-1)`, `last_surface_zone/tile` (sätts i start_game för ytzoner), exit-retur till entrétilen, kistspawn i `_spawn_world_objects`.
- [x] `SaveManager.save_game`: dungeonzon ⇒ skriv `last_surface_zone/tile`.
- [x] Test: save i dungeon ger ytzon. Commit: `feat: dungeonresor — enter_dungeon, exit-retur och efemär save`

### Task 4: Skattkista + spelarhook ✓
- [x] `entities/treasure_chest.gd`: klick intill → guld (intervall) + items (chans/max) ur temat, engångs, gråtonas.
- [x] `player._check_portal`: dungeon_entrance → `World.enter_dungeon`.
- [x] Commit: `feat: skattkista med temaloot + nedstigning via ingångstile`

### Task 5: Världsdata + debug ✓
- [x] Ingång `D` i cave (kryptan) och swamp (Träskets hjärta).
- [x] Debug: `dungeon <tema> [seed]`.
- [x] Commit: `feat: dungeoningångar i kryptan och Träskets hjärta + debugkommando`

### Task 6: Helsvit + planbock ✓ (kod klar — kör testerna lokalt)
- [x] Kod: alla filer skrivna, granskade, committade (Tasks 1–5).
- [x] GUT-sviten körd headless: **172/172 gröna** (inkl. nya M6-tester). Trunkerade committade filer kompletterade i arbetsträdet och committade.
- [x] Boot-check headless: inga script-/parse-fel i Output.
- [ ] **Manuell smoke-test (Erik)**: debug-konsol `dungeon katakomber`, gå till kistan, öppna, gå till `0`-portalen.
- [ ] Merge m6-dungeons → master (se instruktion nedan).

#### GUT-kommando (PowerShell)
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path C:\Users\Hem\tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

#### Merge-instruktion
```powershell
cd C:\Users\Hem\tibia2d
git checkout master
git merge --no-ff m6-dungeons -m "feat: Milstolpe 6 — procedurella dungeons (merge m6-dungeons)"
```
