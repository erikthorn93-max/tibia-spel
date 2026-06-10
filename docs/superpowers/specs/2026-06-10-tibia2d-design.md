# Tibia2D — Designspec

**Datum:** 2026-06-10
**Status:** Godkänd av Erik (alla 8 sektioner)
**Föregångare:** godot_rpg (3D-projektet) — data återanvänds, koden byggs ny

## Vision

Ett 2D top-down RPG i Godot 4 som kombinerar:
- **Tibia**: oändlig leveling, klickbaserad auto-attack-strid, tasksystem ("Killing in the Name of..."), outfits
- **OSRS**: brett skillsystem (~17 skills), gathering/crafting-loopar, Slayer-skill, character creation
- **Skyrim**: mängder av ljudsatta quests med AI-genererade röster (TTS), dialogträd, levande NPC:er

Singleplayer, offline. Fria asset-paket (LPC/Kenney). Handbyggd övervärld + procedurella dungeons.

**Prestanda är ett hårt krav:** 3D-föregångaren blev för långsam. Budget: 60 FPS med 50 aktiva monster i en zon, mäts från milstolpe 1.

---

## 1. Arkitektur & projektgrund

Nytt Godot 4-projekt i `C:/Users/Hem/tibia2d`, helt 2D.

```
tibia2d/
├── autoload/          # Globala system (singletons)
│   ├── GameState     # Spelarens data: level, skills, unlocks
│   ├── ItemDB        # ← porteras från godot_rpg (~300 items)
│   ├── SpellDB       # ← porteras (~90 spells/runor)
│   ├── MonsterDB     # ← porteras (bestiary-datat, ~80 monster)
│   ├── QuestDB       # ← porteras (16 quests) + byggs ut
│   ├── TaskSystem    # NYTT: Killing in the Name of-logik
│   ├── UnlockSystem  # NYTT: alla lås (områden/skills/monster/outfits)
│   └── SaveManager   # ← porteras, anpassas
├── data/              # All speldata som .json — INTE hårdkodad i .gd
├── world/             # TileMap-zoner (en .tscn per zon) + dungeongenerator
├── entities/          # Spelare, monster, NPC (scener + skript)
├── ui/                # HUD, skillpanel, questlogg, taskfönster, bestiary, garderob
├── tools/             # Pipeline-skript (TTS-generering m.m.)
└── audio/voice/       # TTS-genererade röstfiler per NPC/quest
```

### Principer

1. **All speldata i JSON** (`data/*.json`), inte i GDScript. Möjliggör massredigering/generering med skript; TTS-pipelinen läser dialog direkt ur datat.
2. **Zonbaserad värld.** Inte en jättescen (det laggade i 3D-projektet) utan separata zoner som laddas in/ut vid zonbyte. Varje zon = egen TileMap-scen. Procedurella dungeons genereras i samma zonformat.
3. **Datat porteras, koden skrivs ny.** Monster-, item-, spell- och questdata konverteras från godot_rpg:s .gd-filer till JSON med ett engångsskript.

---

## 2. Kärnloop — spelare, strid, monster

### Spelaren
- Tile-baserad rörelse (WASD/piltangenter + klick-att-gå), 8 riktningar visuellt, 4-riktningslogik som Tibia
- Stats: HP, Mana, Level (oändlig), Magic Level + alla skills
- Level-XP: Tibia-formel, exponentiellt växande krav, ingen cap

### Strid (Tibia-stil)
- Klicka på monster → target låses → auto-attack varje stridstick (1 tick = 1 s)
- Fri rörelse under strid: kiting, positionering är taktiken
- Hotkeys F1–F12 för spells, runor, potions
- Skadeformel: vapenskill + vapen-atk + level; försvar: shielding + rustning
- Melee = intilliggande tile; distance = 1–7 tiles; runor = target/area

### Monster
- Data i `data/monsters.json` (porterat): HP, atk, exp, svårighetsgrad, typ (Odöd/Djur/Demon/...), spawn-plats, loot-tabell
- AI: aggro-radie → jaga via A* på tilegrid → attackera. Vissa flyr vid låg HP, vissa har spells
- Spawnsystem per zon: spawn-punkter med respawn-timer — oändligt grindbart

### Prestanda
- Monster utanför skärm + marginal fryser sin AI helt
- Spawnsystemet begränsar max aktiva monster per zon
- 2D-sprites + TileMap

---

## 3. Skillsystemet (oändligt, OSRS-bredd)

Alla skills oändliga, Tibia-stil avtagande takt. Gemensam XP-kurva: `xp_next = bas × 1.1^nivå`, justerbar per skill i `data/skills.json`.

| Kategori | Skills | Tränas av |
|----------|--------|-----------|
| **Strid** | Sword, Axe, Club, Fist | Slag med vapentypen |
| | Distance | Bågar, kastvapen |
| | Shielding | Blockera med sköld |
| | Magic Level | Mana spenderad |
| **Gathering** | Mining | Malm (koppar→järn→guld→demonit...) |
| | Fishing | Fisk ur vatten |
| | Woodcutting | Trä ur träd |
| | Herbalism | Örter från växtplatser |
| **Crafting** | Smithing | Vapen/rustning av malm — kan överträffa butiksvaror |
| | Cooking | Mat med buffs (regen, skill-boost) |
| | Alchemy | Potions av örter |
| | Runecrafting | Egna attackrunor |
| **Utility** | Agility | Rörelsehastighet + genvägar i världen |
| | Thieving | Kistor, ficktjuveri, låsdyrkning |
| | Slayer | ENDAST tasks + bossar (se §4) |

### Designprinciper
- Varje gatheringskill matar minst en craftingskill (mining→smithing, herbalism→alchemy, woodcutting→fletching under Distance)
- Innehåll gateas av skillnivå (malm/fisk/recept kräver nivå X) och ibland av quest-unlock (§6)

---

## 4. Tasksystemet — "Killing in the Name of..." + Slayer

### Taskmasters
- NPC i varje större stad (som Grizzly Adams)
- Erbjuder tasks filtrerade på Slayer-nivå + unlocks
- 1 aktiv task-slot från start; upp till 3 via Slayer-nivå

### Taskformat (`data/tasks.json`)
```json
"task_ghouls": {
  "monster": "Ghoul",
  "required": 300,
  "slayer_level_req": 15,
  "reward_slayer_xp": 4500,
  "reward_gold": 2000,
  "unlocks_monster": "Fantom",
  "boss_unlock": "Ghulkungen",
  "repeatable": true
}
```
- `unlocks_monster`: monstret börjar spawna för spelaren efter klarad task
- `boss_unlock`: bossfight blir tillgänglig
- `repeatable`: kan göras om för Slayer-XP (reducerad belöning)

### Kill-tracking
- Bestiary räknar alla kills permanent (tiers porteras: t.ex. 100/400/1000)
- Tasks räknar bara kills medan tasken är aktiv (som Tibia)
- Bestiary-tiers ger permanent +2 % skada per tier mot den monstertypen (förenklad charm-mekanik)

### Unlock-kedjor
- Klarad task → svårare monstervariant låses upp (Ork → Ork Krigare → Ork Berserker...)
- Task-milstolpar (t.ex. 5 tasks i en kategori) → bossfight i bossrum: egen ingång, 20 h cooldown (som Demodras)
- Bossar: unik loot + stor Slayer-XP

### Slayer-skillen
- XP endast från tasks + bossar
- Gatear: tillgängliga tasks, antal task-slots, slayer-only-områden (dubbel gate: Slayer-nivå OCH task-upplåsta monster)

---

## 5. Quests med AI-röster (Skyrim-känslan)

### Queststruktur (`data/quests.json`)
- Objective-typer: `kill`, `collect`, `talk_to`, `explore`, `use_item`
- Flerstegsquests och questkedjor (B kräver A)
- Belöningar: XP, guld, items, unlocks (§6)
- 16 gamla quests porteras som startinnehåll

### Dialogsystem
- Dialogträd per NPC: rader + spelarval
- Varje rad i datat: text, talare, känsloläge, sökväg till röstfil
- Idle barks: korta repliker när spelaren går förbi

### TTS-pipeline (separat verktyg)
```
data/quests.json + data/dialogue.json
        │
   tools/generate_voices.py   (anropar TTS-API)
        │
audio/voice/<npc_id>/<rad_id>.ogg
```
- Röstprofil per NPC i `data/npcs.json`
- Endast nya/ändrade rader genereras (hash-jämförelse)
- TTS-val: ElevenLabs primärt, Piper (lokal, gratis) som fallback — båda utvärderas i milstolpe 4
- Spelet spelar bara .ogg; saknas fil visas bara text

### Questlogg-UI
- Journal: aktiva/klarade quests, aktuellt steg, questmarkör på minimap (avstängbar)

---

## 6. Unlock-systemet

`UnlockSystem`-autoload äger ALLA lås. API: `UnlockSystem.has("area_edron")`.

### Låstyper (`data/unlocks.json`)
| Typ | Exempel |
|-----|---------|
| Område/zon | Edron kräver quest; Slayer-grottan kräver Slayer 30 |
| Hel skill | Runecrafting låst bakom quest (jfr Rune Mysteries); Thieving bakom tjuvgillets intro |
| Monster | Task-unlocks (§4) |
| Boss | Bossrum via task-milstolpar |
| Recept | Demonit-smide: Smithing 60 OCH dvärgquest |
| Genvägar | Agility-genvägar kan kräva engångsquest |
| Outfits/addons | Se §8 |

### Kombinerade krav
```json
"area_demonhola": {
  "requires": [
    {"type": "quest", "id": "demonjakten"},
    {"type": "skill", "skill": "slayer", "level": 40},
    {"type": "task_count", "category": "demon", "count": 3}
  ]
}
```

### I världen
Lås syns som portvakter, magiska dörrar, stenblock, båtkaptener — alltid med hint om kravet.

### Procedurella dungeons
- Generator: rum + korridorer på tilegrid (klassisk algoritm)
- Monsterpooler styrs av spelarens unlocks
- Ingångar utspridda i världen, kan själva vara unlock-gated

---

## 7. Sparande, milstolpar & teststrategi

### Sparsystem
- En JSON-sparfil i `user://`: skills, unlocks, taskprogress, bestiary, questlägen, inventory, bank, position, utseende/outfits
- Autosave var 60 s + vid zonbyte; manuell save i meny
- Versionsfält för framtida migrering

### Milstolpar (varje spelbar)
| # | Milstolpe | Innehåll |
|---|-----------|----------|
| 1 | Spelbar kärna | Nytt projekt, stadzon + grotta, rörelse, Tibia-strid, 5 monster, XP/level, loot, save, **basic character creation** |
| 2 | Skillsystem | Alla ~17 skills, gathering-noder, crafting-stationer, recept |
| 3 | Tasksystem | Taskmaster, tasks, Slayer, monster-unlocks, första bossen, bestiary-UI |
| 4 | Quests + röster | Dialogsystem, questlogg, TTS-pipeline, 5 röstade quests, idle barks |
| 5 | Unlock-väv | UnlockSystem fullt ut: 3+ zoner, skill-lås, områdeslås, genvägar, **outfit-unlocks + garderob** |
| 6 | Procedurella dungeons | Generator + 2 ingångar |
| 7+ | Innehållsvågor | Fler zoner, monster, tasks, quests, bossar — ren dataproduktion |

### Teststrategi
- GUT (Godot Unit Test) för logik: XP-/skadeformler, unlock-krav, taskräkning, dungeongenerator
- Manuella speltest per milstolpe
- Debug-konsol i spelet: ge XP/items/unlocks, teleport mellan zoner

### Prestandabudget
60 FPS med 50 aktiva monster i en zon — verifieras i milstolpe 1 innan vidare bygge.

---

## 8. Character creation & outfits

### Character creation (OSRS-stil)
- Vid nytt spel: kön/kroppstyp, hudfärg, frisyr, hårfärg, skäggstil, startfärger på kläder
- Rent kosmetiskt — inga stats-/klassval; din "klass" blir vad du tränar
- Design-koncept från godot_rpg:s character_creator återanvänds, byggs nytt för 2D

### Teknik: paper-doll (LPC)
- LPC-sprites är lagerbaserade: kropp + frisyr + kläder + vapen med matchande animationsframes
- Palette-shader för fri färgsättning av hår/kläder
- Equipment syns automatiskt på karaktären

### Upplåsbara outfits (Tibia-stil)
- Outfits = kompletta utseendepaket ("Riddare", "Pirat", "Demonjägare"...)
- Låses via `UnlockSystem`: quest-belöningar, task-milstolpar, bossdrops, bestiary-tiers, Slayer-nivåer
- Varje outfit har 2 addons med egna svårare krav (som Tibia)
- Garderobs-UI: byt outfit när som helst (kosmetiskt; equipment-stats gäller oavsett)
- Frisör-NPC för att ändra frisyr/färger (jfr OSRS makeover mage)

---

## Avgränsningar (YAGNI)

- Ingen multiplayer
- Ingen PvP
- Inga handgjorda cutscenes — dialog + röster bär berättelsen
- Charm-systemet förenklat till bestiary-tier-bonus (+2 %/tier), inte Tibias fulla charmlista
- Fletching är inte egen skill — ingår under Distance-träning/recept
