# Tibia2D Milstolpe 2 — Skillsystem: Designspec

**Datum:** 2026-06-11
**Status:** Godkänd
**Bygger på:** `2026-06-10-tibia2d-design.md` §3 (skillsystemet), milstolpe 1 (mergad, taggad `m1-spelbar-karna`)

## Mål

Alla 18 skills registrerade och synliga. Fullt tränbara i M2: fyra gathering-skills (Mining, Fishing, Woodcutting, Herbalism), fyra crafting-skills (Smithing, Cooking, Alchemy, Runecrafting) samt vapenskillsen Sword, Axe, Club, Fist och Shielding. Magic, Distance, Thieving, Agility och Slayer registreras med nivå men får sina träningssystem i M3–M5.

## Scopebeslut (från brainstorm)

| Fråga | Beslut |
|-------|--------|
| Skillscope | Kärnan djup, resten registrerad |
| Gathering | OSRS-stil: klick → gå intill → träningsloop med timer |
| Verktyg | Krävs, ligger i inventory, köps/craftas |
| Crafting | Receptpanel vid station |
| Första verktyg | Butiks-NPC i stan (köp/sälj, ingen dialog) |
| Placering | Ny skogszon + malm i grottan + stationer/butik i stan |
| Skill-UI | Skillpanel på K; HUD-statsraden förenklas |
| Buffs | Enkel version i M2, delas av Cooking och Alchemy |
| Arkitektur | Generalisera på plats — inga nya autoloads |

## 1. Data

### `data/skills.json`
Alla 18 skills: `{ "mining": {"name": "Mining", "category": "gathering", "xp_base": 50, "xp_growth": 1.1, "start_level": 1}, ... }`
`GameState.skills` byggs från filen vid start. Sword/Shielding behåller `start_level: 10`. Befintliga `gain_skill_xp`/`skill_xp_next` återanvänds; `xp_base`/`xp_growth` läses per skill istället för konstanterna.

### `data/items.json` (utökning)
- **Verktyg:** `pickaxe`, `hatchet`, `fishing_rod`, `sickle` — fält `tool: true`
- **Vapen** får fält `skill`: `"sword"` | `"axe"` | `"club"`. Nya butiksvapen: `bronze_axe`, `wooden_club`. Utan vapen tränas `fist` (bas-atk 5).
- **Råvaror:** `copper_ore`, `iron_ore`, `gold_ore`, `log`, `oak_log`, `willow_log`, `raw_trout`, `raw_pike`, `mint_herb`, `nightshade_herb`, `empty_vial`
- **Craftat:** `steel_sword` (Smithing 15, slår `iron_sword`), `copper_plate` (rustning, Smithing 5), `cooked_trout`, `fish_stew` (buff), `mana_potion`, `mining_brew` (skill-buff), `attack_rune`
- **Buff-fält** på mat/potions: `{"buff": {"stat": "regen"|"skill:mining"|..., "amount": N, "duration": 60}}`

### `data/recipes.json`
Per stationstyp: `{"anvil": [{"id": "steel_sword", "level": 15, "skill": "smithing", "ingredients": {"iron_ore": 3, "copper_ore": 1}, "xp": 40}, ...], "stove": [...], "alchemy_table": [...], "rune_altar": [...]}`

### Zon-legend (utökning)
- `{"type": "node", "node": "copper_vein", "respawn": 30}` — gathering-nod
- `{"type": "station", "station": "anvil"}` — crafting-station
- `{"type": "shop"}` — butiks-NPC

### `data/nodes.json`
Nodtyper: `{"copper_vein": {"skill": "mining", "level": 1, "tool": "pickaxe", "yields": "copper_ore", "xp": 15, "charges": [3,5], "respawn": 30, "color": "#b87333"}, ...}`
Nodtyper M2: koppar/järn/guld-ådra (grottan), 3 trädtyper nivå 1/15/30, 2 fiskeplatser, 2 örtplatser (skogen).

## 2. Världen

- **`data/zones/forest.json`** (40×24): portal från stans norra sida, träd, flod med fiskeplatser, örtplatser, några Ormar/Spindlar.
- **Grottan:** malmådror placeras djupare in, närmare farligare monster (koppar nära ingången, guld längst in).
- **Stan:** städ + ugn, gryta, alkemibord, runaltare, butiks-NPC.
- Noder/stationer/butik är klickbara Area2D-entities, spawnas av `zone.gd` från legend — samma mönster som monster-spawns.
- Nya entity-scener: `entities/gather_node.gd/.tscn` (generisk, datadriven), `entities/crafting_station.gd/.tscn`, `entities/shop_npc.gd/.tscn`.

## 3. Gameplay

### Gathering-loop
1. Klick på nod → spelaren pathar intill (befintlig A*).
2. Intill: försök var 2,0 s. Chans = `clamp(0.40 + 0.02 × (nivå − kravnivå), 0.05, 0.90)`.
3. Lyckat: resurs i inventory + XP. Noden förlorar 1 laddning (3–5 vid spawn).
4. Tom nod gråtonas, respawnar efter nodens respawntid (20–60 s).
5. Fel verktyg/för låg nivå → HUD-meddelande. Rörelse/attack avbryter loopen.

### Crafting
Klick på station → receptpanel för stationstypen. Per recept: ingredienser (grön/röd per innehav), kravnivå, resultat-ikon. Craft-knapp + "Gör 5". Craft drar ingredienser, ger resultat + XP direkt (ingen timer i M2).

### Butik
Klick på NPC → panel med två flikar: Köp (verktyg, bronze_axe, wooden_club, empty_vial) och Sälj (hela inventoryt, pris = `value × 0.5`). Guld via befintliga `GameState.gold`.

### Vapenskills
`player._update_attack` läser vapnets `skill`-fält och tränar den skillen; `CombatFormulas.roll_melee` tar vapenskillens nivå. Inget vapen → `fist`.

### Buffs
`GameState.active_buffs: Array[Dictionary]` med `{stat, amount, expires_at}`. Tick i `_process`: regen helar, utgångna tas bort (signal `buffs_changed`). `skill:`-buffs adderas vid skill-checks via ny helper `GameState.effective_skill_level(skill)`. Ny buff av samma stat ersätter den gamla. Buffs sparas inte (dör vid omstart, som OSRS).

## 4. UI

- **`ui/skill_panel.gd/.tscn`** — K togglar. Fyra kategorisektioner, varje skill: namn, nivå, XP-progressbar. Uppdateras via ny signal `GameState.skill_changed(skill)`.
- **HUD:** statsraden förenklas till `Lv X  XP a/b  Guld N  <vapenskill> M` + buffikoner med nedräkning.
- **`ui/recipe_panel.gd/.tscn`**, **`ui/shop_panel.gd/.tscn`** — samma visuella stil som inventoryt. Esc/klick utanför stänger.
- Ny input-action: `toggle_skills` (K).

## 5. Save & migrering

- `skills`-dictionaryn sparas redan generiskt — inga ändringar.
- `SAVE_VERSION` bumpas till 2. Migrering vid load: skills som saknas i saven läggs till från `skills.json` med startnivå. v1-saves fortsätter alltså fungera.
- `active_buffs` sparas inte.

## 6. Tester (GUT, TDD)

- skills.json-laddning: 18 skills, rätt kategorier, XP-kurva per skill
- Gathering: chansformeln (golv/tak), laddningar räknar ner, respawn-tidslogik
- Recept: validering av ingredienser + nivåkrav, craft drar/ger rätt items + XP
- Buffs: applicering, ersättning av samma stat, expiry, `effective_skill_level`
- Butik: köp drar guld + ger item; sälj ger `value × 0.5`
- Save: v1→v2-migrering ger alla 18 skills
- Vapenskill: rätt skill tränas per vapentyp, fist utan vapen

## 7. Prestanda

Noder är passiva (ingen AI) men fryser sin `_process` bortom `FREEZE_DIST` likt monster. Perftestkravet 60 FPS med 50 monster gäller fortsatt, nu med skogszonens noder aktiva.

## Acceptanskriterier

- [ ] Skillpanelen (K) visar alla 18 skills med nivå + progress
- [ ] Mining i grottan: hacka krävs, koppar→järn→guld gateat per nivå, ådror töms och respawnar
- [ ] Skogszonen nås via portal; träd/fiske/örter tränar respektive skill
- [ ] Butiken säljer verktyg/vapen och köper loot; guld dras/läggs korrekt
- [ ] Alla fyra stationer craftar enligt recept; steel_sword kräver Smithing 15 och slår iron_sword
- [ ] Mat/potions med buff visar ikon i HUD och påverkar regen/skill under duration
- [ ] Yxa tränar Axe, klubba Club, inget vapen Fist
- [ ] v1-save laddar utan fel och får alla nya skills
- [ ] Alla GUT-tester gröna; 60+ FPS i perftestet
