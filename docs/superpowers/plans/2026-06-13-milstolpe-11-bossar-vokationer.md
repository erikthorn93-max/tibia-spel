# Milstolpe 11 — Bossar & OSRS-stil Progression
**Branch:** `m11-bossar-vokationer`  
**Datum:** 2026-06-13

## Designfilosofi: OSRS-stil
Inga klasser eller vokationer — alla spelare har tillgång till alla skills.
Skills ökar genom användning. Högre nivå låser upp starkare vapen, runor,
recept och zoner. Spelaren specialiserar sig organiskt via vad de tränar.

## Uppgifter

### Task 1-3: Boss-enrage + stun + Urskogsvältaren ✅ KLAR
- monster.gd: enrage vid ≤50% HP (speed×1.5, atk×1.5, röd namnlabel)
- Urskogsvältaren: boss i skogen, stun-ability
- player.gd: rörelseblock under stun-status

### Task 4: Bågskjutning (ranged combat)
- `data/items.json`: `hunting_bow` (skill:"archery", atk:12, range:4, slot:"weapon")
  `wooden_arrow` (ammunition, qty-förbrukas per skott)
- `data/skills.json`: "archery" skill (om ej redan finns)
- `player.gd _update_attack()`: om equipped weapon har `range` > 1 →
  attack på distans (Chebyshev 1..range) — ingen närstrid krävs
- `combat_formulas.gd`: `roll_ranged(level, atk)` (liknande roll_melee)
- TDD: test_ranged.gd

### Task 5: Boss HP-bar i HUD
- `hud.gd`: `_boss_bar` PanelContainer, mitten-botten, dolt normalt
- Visar när `World.player.target` är ett boss-monster
- Stor HP-bar med bossens namn + HP-procent
- Uppdateras i `_process()` via monster-referens

### Task 6: Fishing + Cooking (ny gather-skill)
- `data/items.json`: raw_fish, cooked_fish, burnt_fish
- `data/gather_nodes.json`: fishing_spot (tool:"fishing_rod", skill:"fishing", level:1)
  loot: raw_fish (chans 0.9)
- `data/skills.json`: "fishing", "cooking" skills
- `data/recipes.json`: campfire: [{id:"cooked_fish", skill:"cooking", level:1,
  ingredients:{raw_fish:1}, xp:10}]
- `data/zones/coast.json`: fishing_spot-noder nära vattnet
- TDD: test_fishing.gd

### Task 7: Helsvit + smoke test + merge m11→master

## OSRS-paralleller implementerade
| OSRS | Tibia2D |
|------|---------|
| Attack/Strength/Defence | sword/fist/shielding |
| Magic | magic |
| Ranged | archery (Task 4) |
| Fishing | fishing (Task 6) |
| Cooking | cooking (Task 6) |
| Herblore | alchemy |
| Agility | agility |
