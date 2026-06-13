# Tibia2D Milstolpe 7 — Saltviks hamn (kustregion): Designspec

**Datum:** 2026-06-13
**Status:** Godkänd av Erik
**Föregångare:** M6 (procedurella dungeons) — generatorn återanvänds och utökas

## Vision

En ny sammanhängande **kustregion** som vertikal innehållsskiva: motionerar hela
systemstacken i ett tema. Ny zon, sjömonster, en sjö-taskkedja, en röstad
åtkomstquest, ett procedurellt "sjunket skepp" med piratkapten-boss,
fishing→cooking-fördjupning och en pirat-outfit. Knyter regionen till en faktisk
spelloop (fiska → laga buff-mat) snarare än bara strid.

Detta är roadmappens M7 ("Innehållsvågor") avgränsad till **en** cohesiv region.

---

## 1. Åtkomst — unlock-väv

- **Kapten Brandt**: NPC vid stadens (town) hamnkant.
- Låst portal `town → coast`, unlock-id `kustvagen` (typ: `quest`-belöning).
- Öppnas av den röstade questen **"Sjövägen"** (§5). Innan upplåsning visar portalen
  en hint om kravet (befintlig `portal_locks` + `UnlockSystem.hint_for`).
- Fyller designspecens §6 "båtkapten"-låstyp.

## 2. Ny zon — `data/zones/coast.json` ("Saltviks hamn")

Handbyggd strand-/bryggzon. Innehåll:

| Element | Detalj |
|---|---|
| Fiskhandlar-NPC | dialog + shop (fiskeutrustning, säljer råfisk) |
| Kock-stove | `station: stove` på bryggan (cooking) |
| Sjö-taskmaster | NPC "Greta" — egen taskmaster för sjö-tasks |
| Fiskenoder | `deep_sea_spot`, `lobster_pot` (Fishing-nivå-gated) |
| Sjömonster-spawns | Strandkrabba, Sjöorm, Pirat, Pirat Skytt |
| Dungeoningång `D` | tema `sjunket_skepp`, exit-zon = `coast` |

Terräng: strand/sand + bryggor (gångbart) + vatten (blockerat, fiskbart vid noder).

## 3. Monster — 5 nya + 1 boss (`data/monsters.json`)

| Monster | Typ | Roll | Var |
|---|---|---|---|
| Strandkrabba | Djur | lägstanivå-grind | kust |
| Sjöorm | Djur | mid | kust + dungeon |
| Pirat | Humanoid | mid, melee | kust |
| Pirat Skytt | Humanoid | distance-anfall | kust |
| Drunknad sjöman | Odöd | dungeon-fyllnad | dungeon |
| **Piratkapten Svartöga** | Humanoid | **boss** (`boss: true`) | slutrum, sjunket skepp |

Loottabeller per monster; boss får unik loot (§8). Spawnplatser i `coast.json`
och via dungeon-temats pool.

## 4. Sjö-taskkedja (`data/tasks.json`, taskmaster Greta)

Kedja med monster-unlocks och boss-unlock i slutet:

- `task_krabbor` (Strandkrabba) → `unlocks_monster: Sjöorm`
- `task_sjoormar` (Sjöorm) → `unlocks_monster: Pirat`
- `task_pirater` (Pirat) → `boss_unlock: Piratkapten Svartöga`

Slayer-XP + guld som befintliga tasks. `repeatable: true` för grind.

## 5. Röstad quest — "Sjövägen" (`data/quests.json` + `dialogue.json` + `npcs.json`)

Flerstegsquest som är regionens åtkomstgrind, röstad via TTS-pipelinen (M4):

1. `talk_to` Kapten Brandt — han behöver hjälp innan han seglar dig ut.
2. `kill` 5 Pirat som har landstigit och plundrar **stadens** hamn (återanvänder §3-monstret
   Pirat). **Beroende:** Pirat måste därför ha en spawn-punkt i `town`-zonen (vid hamnkanten),
   nåbar före `kustvagen`-upplåsningen — inte bara i coast. Inget nytt objektiv-item behövs.
3. `talk_to` Brandt igen → belöning: guld + XP + **unlock `kustvagen`**.

- Röstprofil för Brandt i `npcs.json`; dialograder i `dialogue.json` med talare/känsloläge/röstfil-sökväg.
- Endast denna quest är röstad i M7. Bossen nås via taskkedjan, inte en andra röstad quest.

## 6. Fishing → cooking-skiva

**Nya fiskenoder** (Fishing-nivå-gated, i `coast.json` + nodlogik):
- `deep_sea_spot` (~nivå 20) → makrill/svärdfisk
- `lobster_pot` (~nivå 30) → hummer

**Nya råvaror** (`data/items.json`): `raw_mackerel`, `raw_lobster`, `raw_swordfish`.

**Nya stove-recept med buffar** (`data/recipes.json`, station `stove`, skill `cooking`):
- `grilled_mackerel` (cooking ~15) → HP-regen-buff
- `lobster_dinner` (cooking ~25) → tillfällig boost
- `swordfish_steak` (cooking ~35) → tillfällig stridsskill-boost

Buffar använder befintliga buff-systemet (jfr `test_buffs.gd`). Maten ger en
`buff`-effekt vid förtäring (typ + duration i item-datat).

## 7. Procedurellt dungeon-tema — `sjunket_skepp` (`data/dungeon_themes.json`)

Tredje temat (efter katakomber, sjunkna_graven). Återanvänder M6-generatorn.

- **Monsterpool:** Drunknad sjöman, Sjöorm, Pirat (viktad).
- **Kistloot:** piratguld (intervall) + huggare-vapen + sjökort (chans/max).
- **exit_zone:** `coast`.
- **Terräng:** träplanksdäck (gångbart) + vatten (yttermur/block).

**Generator-utökning (liten):** temat kan ange ett `boss`-fält. Generatorn placerar
boss-spawnen i **slutrummet** (samma rum som kistan) med boss-flaggan satt.
`World._spawn_one` routar redan bossar till `spawn_boss_marker` +
`TaskSystem.boss_available`-gate, så live-vs-markör styrs av taskkedjan (§4).
Dungeonen är efemär (M6: sparfilen skriver ytzonen `coast`).

## 8. Outfit — `outfit_pirate` ("Piratens mundering") (`data/outfits.json`)

- **Bas-unlock:** besegra Piratkapten Svartöga (boss-unlock).
- **2 addons** (Tibia-stil, hårdare krav via `UnlockSystem`):
  - Addon 1: laga `swordfish_steak` (kopplar cooking-loopen till kosmetik).
  - Addon 2: X kills på Svartöga **eller** Fishing-nivå-tröskel.
- Matchar befintlig outfit-struktur (kombinerade krav i `unlocks.json`).

## 9. Items (`data/items.json`)

Råfisk (§6) + tillagad buff-mat (§6) + piratloot (huggare-vapen, sjökort) + unik
bossloot från Svartöga. Inga nya item-typer utöver befintliga (vapen/mat/material).

## 10. Tester (GUT, TDD)

- **DB-integritet:** monster/task/quest/outfit/recept refererar bara giltiga ids
  (monster finns i MonsterDB, ingredienser finns i ItemDB, unlock-ids existerar).
- **Zon:** `coast.json` byggs → fiskenoder, stove-station, taskmaster, dungeoningång
  parsade och gångbara där de ska.
- **Dungeon:** `sjunket_skepp` genererar deterministiskt; boss placeras i slutrummet;
  exit_zone = coast; pool ⊆ MonsterDB.
- **Recept:** nya recept giltiga (ingredienser finns, producerar item, rätt skill/nivå).
- **Quest/unlock:** "Sjövägen"-flödet låser upp `kustvagen`; portalen öppnas live.
- **Buff-mat:** förtäring ger rätt buff-typ/duration.

## Avgränsningar (YAGNI)

- **1 röstad quest** (Sjövägen). Bossen nås via taskkedjan, ingen andra röstad quest.
- **Inga nya skills** — fishing/cooking finns redan; M7 fördjupar dem med data.
- **Ingen ny stadsekonomi** utöver fiskhandlarens utbud.
- **Outfit angler finns redan** — M7:s outfit är pirat, ingen dubblering.
- Ingen ny generatoralgoritm — bara `boss`-placering i slutrummet ovanpå M6.
