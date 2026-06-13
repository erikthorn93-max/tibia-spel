# Milstolpe 11 — Bossar & Vokationer
**Branch:** `m11-bossar-vokationer`  
**Datum:** 2026-06-13

## Mål
Bossfighter med flera faser, ny boss i skogen, och spelarklasser (vokationer)
som ger olika statistillväxt och spelstil.

## Uppgifter

### Task 1: Boss-enrage vid 50% HP (TDD)
- `monster.gd`: `var enraged := false`, `_check_enrage()`
- Vid `hp <= max_hp * 0.5` (första gången): `enraged = true`, `speed *= 1.5`, `atk = int(atk * 1.5)`
- Namnlabel blinkar rött (Color(1.0, 0.1, 0.1))
- `monsters.json`: Ghulkungen + Piratkapten Svartöga får `"enrage": true`
- TDD: test_boss_enrage.gd (enrage-tröskel, stat-ändring, ingen dubbel-enrage)

### Task 2: Boss HP-bar i HUD
- `hud.gd`: `_boss_bar_panel` (PanelContainer, mitten nedtill, dold normalt)
- Visar när `World.player.target` är ett boss-monster (har `boss`-flagga i MonsterDB)
- Uppdateras i `_process()` via `_refresh_boss_bar()`
- Bossnamn + stor orange/röd HP-bar
- TDD: (visuell feature — smoke test)

### Task 3: Ny boss — Urskogsvältaren (skogen)
- `monsters.json`: `"Urskogsvältaren"` HP=600, ATK=35, boss:true, ability: stun
- `ability: {"type":"stun","chance":0.3,"duration":2.0}`
- `monster.gd _try_apply_ability()`: stun → `GameState.apply_status("stun", 2.0, 0.0)`
- `player.gd _update_movement()`: om `GameState.has_status("stun")` → skippa rörelse
- `data/zones/forest.json`: lägg till Urskogsvältaren i spawn_table (respawn 600s)
- TDD: test_stun_status.gd

### Task 4: Spelarklasser (Vokationer)
- `data/vocations.json`: Riddare, Magiker, Bågman, Druid
  - `hp_per_level`, `mana_per_level`, `skill_bonuses: {}`
- `autoload/game_state.gd`: `var vocation := "riddare"`, `apply_vocation(id)`
  - `apply_vocation()` justerar `max_health`, `max_mana`, tillämpar skill_bonuses
- `ui/vocation_select.gd`: väljs vid nytt spel (om save saknas)
- SaveManager: spara/ladda vocation (SAVE_VERSION 7→8)
- TDD: test_vocations.gd

### Task 5: Vokation-HUD + startbonus
- HUD visar vocationnamn i stats-raden
- Riddare startar med rusty_sword + wooden_shield
- Magiker startar med attack_rune ×3, mana_potion ×1
- Bågman startar med hunting_bow (nytt vapen, range 1-4)
- Druid startar med healing_rune ×3
- TDD: test_vocation_start.gd

### Task 6: Helsvit + smoke test + merge m11→master
- Alla GUT-tester gröna (28 + nya)
- Smoke test: spela igenom town → forest → boss
- Merge

## Tekniska noter
- Stun-status: `GameState.apply_status("stun", duration, 0.0)` — tick_dmg=0 (ingen skada)
- `player.gd` kollar `GameState.has_status("stun")` i `_update_movement()` — skippar all input
- Boss HP-bar: uppdateras i `_process()` → ingen signal behövs
- Hunting bow: `"skill":"archery"`, `"range":4`, `"atk":12` — ny skill i skills.json
