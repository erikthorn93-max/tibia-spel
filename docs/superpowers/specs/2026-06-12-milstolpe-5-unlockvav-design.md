# Milstolpe 5 — Unlock-väv: Designspec

**Datum:** 2026-06-12
**Status:** Utkast — väntar på godkännande
**Bygger på:** Masterspec §Milstolpar (rad 5), milstolpe 1–4 (mergade till master)

## Mål

UnlockSystem fullt ut: en väv av lås och belöningar som knyter ihop allt som
redan byggts. Skill-lås och genvägar i världen, områdeslås på zoner, en ny
fjärde zon (Träsket), samt outfit-unlocks med garderobs-UI. Spelbart
slutresultat: spelaren låser upp vägar med skills, hittar genvägar, når en ny
zon och klär sig i outfits som tjänats in via quests, tasks och bossar.

## Nuläge (vad M5 bygger på)

- `UnlockSystem` är ett minimalt set (`unlock`/`is_unlocked` + signal).
- Unlocks ges idag bara av task-claims (`tasks.json: unlocks`) och konsumeras
  av `gate`-tiles i zondata (rasmassor som öppnas).
- 3 zoner: town, forest, cave. Gated delområden: mörka dungen, spindelhålan,
  kryptan, bossrummet.
- Utseende: 4 färglager (skin, hair, shirt, pants) från character creation,
  appliceras av `character_visual.gd`.
- Save v4.

---

## 1. Datamodell — `data/unlocks.json` (nytt centralregister)

Alla unlock-id:n får en definition. Dataintegritetstester kräver att varje
unlock-id som refereras (gates, shortcuts, tasks, quests, outfits) finns här.

```json
"genvag_klippan": {
  "name": "Klippgenvägen",
  "category": "shortcut",
  "requires": {"skill": "agility", "level": 15},
  "hint": "Ett brant klippavsats — smidiga äventyrare tar sig upp."
},
"trasket": {
  "name": "Träsket",
  "category": "area",
  "requires": {"quest": "quest_into_the_crypt"},
  "hint": "Stigen söderut öppnas för den som utforskat kryptan."
},
"outfit_slayer": {
  "name": "Slayer's Garb",
  "category": "outfit",
  "requires": {"task_completed": "task_ghoul"},
  "hint": "Belöning för att ha jagat ghouls åt taskmastern."
}
```

- **Kategorier:** `area`, `shortcut`, `outfit`.
- **Krav-typer (`requires`):** `skill` (+level), `quest` (klarad),
  `task_completed`, `boss_killed`, `unlock` (kedjning). Tomt = ges direkt av
  annan källa (t.ex. task-claim, som idag).
- `UnlockSystem` utökas: `can_unlock(id)` (utvärderar krav mot
  GameState/QuestSystem/TaskSystem), `try_unlock(id)` (interaktiva lås),
  `definition(id)`. Befintliga `unlock()`/`is_unlocked()` orörda —
  tasks fortsätter fungera som idag.

---

## 2. Skill-lås, genvägar och områdeslås i zondata

Tre utökningar av zonlegenden (zone.gd):

- **`shortcut`** — OSRS-stil: tile är blockerad tills spelaren klickar på den
  och uppfyller skill-kravet; då låses den upp **permanent** och blir gångbar.
  Visas som t.ex. nedfallet träd/klippavsats med kravtext vid interaktion.
  ```json
  "G": {"type": "shortcut", "unlock": "genvag_klippan", "terrain": "."}
  ```
- **`gate` + krav** — befintliga gates kan utöver task-unlock även kräva skill:
  kravet läses från unlocks.json (gaten pekar redan på unlock-id).
- **`portal` + lås** — portaler kan kräva en unlock innan de fungerar:
  ```json
  "2": {"type": "portal", "to": "swamp", "unlock": "trasket"}
  ```
  Låst portal visas gråtonad med hint-text istället för zonnamn.

Misslyckad interaktion visar unlock-definitionens `hint` som flytande text —
spelaren ser alltid *vad* som krävs.

---

## 3. Ny zon — Träsket (`data/zones/swamp.json`)

Fjärde zonen, nås via låst portal i skogen (kräver `trasket`-unlocken).

- **Tema:** träskmark — ny terräng `s` (sumpmark, gångbar) i PlaceholderTiles.
- **Innehåll:** 2 nya monster (t.ex. Träskdjävul, Giftpadda — datadrivet i
  monsters.json), nya gathering-noder (sumpört för Herbalism, ålfiske),
  1 genväg tillbaka till grottans baksida (agility-genväg = snabbväg
  cave↔swamp när den öppnats).
- **Storlek:** samma klass som forest (~40×28).
- Nya tasks i tasks.json för de nya monstren (taskmastern får mer att ge).

---

## 4. Outfit-unlocks + garderob

### `data/outfits.json`
Outfits är färgscheman för de befintliga 4 lagren — ingen ny grafik behövs:

```json
"outfit_slayer": {
  "name": "Slayer's Garb",
  "colors": {"shirt": "#3a1f1f", "pants": "#1a1a1a"},
  "unlock": "outfit_slayer"
}
```

- Outfits sätter **shirt/pants** (ev. hair) — skin behålls alltid från
  character creation. "Standard" = spelarens egna färger, alltid tillgänglig.
- ~5 outfits i M5: Standard, quest-belöning, task-belöning (Slayer's Garb),
  boss-belöning (Ghoul King-tema), skill-milstolpe (t.ex. Master Gatherer
  vid level 30 i någon gathering-skill).

### Garderobs-UI (`ui/wardrobe.gd`)
- Tangent **U** (ny input-action `toggle_wardrobe`), samma panelmönster som
  questloggen (ESC stänger).
- Lista över alla outfits: upplåsta väljbara, låsta gråtonade med hint.
- Välj outfit → `GameState.appearance` uppdateras + `character_visual`
  uppdaterar spelaren direkt.

---

## 5. Save v5 + teststrategi

- **Save v5:** `outfit_equipped` (id, default `"standard"`) +
  `appearance_base` (originalfärgerna från character creation, så Standard
  alltid kan återställas). Migrering v4→v5: `appearance_base` = nuvarande
  `appearance`, outfit = standard. Unlocks sparas redan (set:et räcker —
  outfit-ägande ligger i UnlockSystem).
- **GUT-tester:**
  - UnlockSystem: kravutvärdering per typ (skill/quest/task/boss/kedja),
    `try_unlock` idempotens.
  - Zone: shortcut-parsning, låst portal blockerar, öppnas live vid unlock
    (samma mönster som gate-testerna).
  - Outfits: equip byter färger men bevarar skin, standard återställer bas.
  - Save: v4→v5-migrering, v5 roundtrip.
  - Dataintegritet: alla refererade unlock-id:n finns i unlocks.json; alla
    outfit-unlocks har category outfit; swamp-zonens monster/noder finns i
    sina databaser.
- Boot-check utan skriptfel. Prestandabudget oförändrad: 60 FPS / 50 monster.

## Avgränsningar (YAGNI)

- Inga animerade/spritebaserade outfits — färglager räcker (som M1).
- Ingen guldköpt outfit-shop — unlocks tjänas in, köp kan läggas till i M7+.
- Inga nya quests i M5 (Träsket får quests i innehållsvågorna M7+).
- Ingen minimap/världskarta.
- Procedurella dungeons är M6 — Träsket är handbyggd som övriga zoner.
