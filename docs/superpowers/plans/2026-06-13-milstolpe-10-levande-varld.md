# Milstolpe 10 — Levande Värld & Statuseffekter

**Branch:** `m10-levande-varld`  
**Mål:** Zonerna fylls med passande monster som respawnar; gift/brinnande statuseffekter gör striden taktisk.

---

## Bakgrund

Zonerna (forest, cave, swamp, coast) har tomma `entities`-listor. Spelet är spelbart bara med
debug-spawn (F11 → råttor). M10 gör världen levande: varje zon har en spawn-tabell, monster
respawnar efter en stund, och Orm/Giftpadda kan gifta spelaren.

---

## Uppgifter

### Task 1 — Zon-spawn-tabeller i JSON (TDD)
- Lägg till `"spawn_table"` i varje zon-JSON: `[{monster, weight, max}]`  
- `zone.gd` läser tabellen och håller ett aktuellt antal levande monster per typ  
- Monster respawnar 30 s efter döden på en ledig tile nära ursprungspositionen  
- Tester: spawn respekterar `max`, respawn sker inte om `max` uppnåtts

### Task 2 — Statuseffekter på spelare: Gift
- `game_state.gd`: `apply_status(id, duration, tick_dmg)` / `clear_status(id)`  
- Aktiva statusar tickar skada i `_process` (separat från `active_buffs`)  
- HUD: rött "Giftig!"-chip under HP-baren  
- `monsters.json`: Orm + Giftpadda får `"ability": "poison"` (`tick: 3, duration: 12`)  
- `monster.gd`: efter attack, `randi() < ability_chance` → `GameState.apply_status("poison", ...)`  
- Tester: poison tick sänker HP, duration räknas ned, clear tar bort

### Task 3 — Antidotum & botande
- `items.json`: `antidote_potion` (`{"name":"Motgift","type":"potion","value":40,"clears_poison":true}`)
- `game_state.gd use_item()`: om `clears_poison` → `clear_status("poison")`
- `recipes.json` alchemy: `antidote_potion` L5 (nightshade_herb×2 + mint_herb×1 + empty_vial)
- Tester: antidot tar bort gift-status

### Task 4 — Brinnande på monster (fire_rune-effekt)
- `monster.gd`: `var status_effects: Dictionary = {}` — `{"burn": {tick, time_left}}`  
- `monster.gd _process`: tickar skada från `status_effects`  
- `player.gd _cast_rune()`: om `effect == "damage"` och runa är `fire_rune` → `target.apply_status("burn", 8, 4.0)`  
- Monster-HP-baren pulserar orange vid burn  
- Tester: burn tick minskar monster-HP, upphör efter duration

### Task 5 — Élitmonster (sällsynt variant)
- `world.gd spawn_monster()`: 5 % chans att spawna élitvariant  
- Élit: namn prefixat "Élite", 2× HP, 1.5× ATK, orange namnfärg, 3× exp + extra loot-chans  
- Tester: élitmonster har korrekt HP-multiplikator

### Task 6 — Helsvit + smoke test + merge m10→master
- Alla tester gröna  
- Smoke test: vandra i skogen → bekämpa élite-orm → bli giftig → drick motgift →  
  byt till cave → verifierar att råttor respawnar

---

## Filer som berörs

| Fil | Förändring |
|-----|-----------|
| `data/zones/*.json` | + `spawn_table` |
| `world/zone.gd` | + spawn/respawn-logik |
| `autoload/game_state.gd` | + `apply_status`, `clear_status`, status-tick |
| `entities/monster/monster.gd` | + `ability`-attack, `status_effects`-tick, burn-visual |
| `data/monsters.json` | + `ability`-fält på Orm, Giftpadda |
| `data/items.json` | + `antidote_potion` |
| `data/recipes.json` | + antidot-recept |
| `ui/hud.gd` | + statuseffekt-chip (Giftig) |
| `tests/unit/test_status.gd` | ny, ~18 tester |
