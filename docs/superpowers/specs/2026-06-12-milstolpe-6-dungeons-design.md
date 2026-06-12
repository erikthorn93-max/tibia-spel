# Milstolpe 6 — Procedurella dungeons: Designspec

**Datum:** 2026-06-12
**Status:** Utkast — väntar på godkännande
**Bygger på:** Masterspec §Milstolpar (rad 6), milstolpe 1–5 (mergade till master)

## Mål

En dungeongenerator som bygger spelbara, slumpade dungeons av samma zondata-
format som handbyggda zoner — plus två tematiska ingångar i världen. Spelbart
slutresultat: spelaren kliver ner i en ingång, utforskar en unik dungeon med
monster ur temats pool, hittar skattkistan i slutrummet och tar sig ut.

## Nuläge (vad M6 bygger på)

- `zone.gd.build(id)` läser `data/zones/<id>.json` → tiles + legend.
  Generatorn kan producera exakt samma Dictionary-struktur.
- 4 zoner, unlock-väv (M5), 9 monster i MonsterDB, gather-noder, save v5.
- Prestandabudget: 60 FPS / 50 monster — gäller även genererade zoner.

## Beslut

| Fråga | Beslut |
|-------|--------|
| Algoritm | **Rum + korridorer** (slumpade icke-överlappande rum, korridorer i MST-ordning + någon extra loop). Förutsägbart testbar, klassisk dungeon-känsla. |
| Determinism | **Seedad RNG** (`RandomNumberGenerator` med given seed). Samma seed ⇒ samma dungeon. Krav för GUT-tester. |
| Livslängd | **Efemära.** Ny seed per nedstigning. Sparfilen lagrar aldrig dungeon-state — sparas det i en dungeon skrivs ingångszonen som position. |
| Utgång | Exit-portal i ingångsrummet tillbaka till ingångszonen. Död ⇒ respawn i stan (befintligt). |
| Belöning | **Skattkista** i slutrummet (rummet längst från ingången): guld + temaloot. Öppnas en gång per dungeon. |
| Nya monster | **Inga.** Temapooler återanvänder befintliga monster — innehållsvågor är M7+. |

---

## 1. Generator — `world/dungeon_generator.gd` (ren logik, GUT-testbar)

```gdscript
static func generate(theme_id: String, seed: int) -> Dictionary
# returnerar {"name": ..., "tiles": [...], "legend": {...}, "exit_zone": ...}
```

- Grid ~44×32, allt `W`. Placera 7–10 rum (5×4–9×7), förkasta överlapp.
- Korridorer: koppla rummen med minimal spanning tree (L-formade gångar),
  + 1–2 extra kopplingar för loopar.
- **Ingångsrum:** spelarstart `P` + exit-portal. **Slutrum:** rummet med längst
  graf-avstånd från ingången → skattkista `C` (+ ev. vaktspawns).
- Spawns: per rum (utom ingångsrummet) 1–3 monster ur temats pool, viktade.
  Totalt tak ~30 spawns (under prestandabudgeten).
- Noder: 0–2 gather-noder per tema strösslade i rum (t.ex. ådror i katakomber).
- Validering inbyggd: golvtile-flood-fill — alla rum nåbara från `P`.

### `data/dungeon_themes.json`
```json
"katakomber": {
  "name": "Katakomberna",
  "floor_terrain": ",",
  "monsters": [["Skelett", 3], ["Spindel", 2], ["Ghoul", 1], ["Skelettkrigare", 1]],
  "nodes": ["iron_vein", "gold_vein"],
  "chest_gold": [150, 400],
  "chest_items": [["health_potion", 0.6, 2], ["bone_chips", 0.8, 4], ["gold_ore", 0.3, 2]]
}
```
Andra temat: **"sjunkna_graven"** (Träsk-ingång): Giftpadda/Träskdjävul/Orm,
marsh_patch/eel-fritt (inga vattennoder), terräng `s`, dyrare kista.

## 2. Världskoppling — två ingångar

| Ingång | Plats | Krav (befintlig unlock-väv) |
|--------|-------|------------------------------|
| Katakomberna | Kryptan i grottan (bakom `kryptan`-gaten) | Skelett-tasken klarad (som idag) |
| Sjunkna graven | Träskets hjärta | Paddtasken klarad (som idag) |

- Ny legendtyp **`dungeon_entrance`**: `{"type": "dungeon_entrance", "theme": "katakomber"}`.
  Renderas som mörk trappa-markör. Kliv på ⇒ `World.enter_dungeon(theme)`.
- `World.enter_dungeon`: slumpa seed, generera data, bygg zon från data
  (`zone.build_from_data(dict)` — refaktor: `build(id)` blir ett tunt skal som
  läser JSON och anropar build_from_data).
- `GameState.current_zone` i dungeon = `"dungeon:<theme>"`;
  `SaveManager.save_game` översätter till ingångszonen.

## 3. Skattkista — `entities/treasure_chest.gd`

- Klick intill (samma interaktionsmönster som NPC:er): guld + items från
  temats loot-tabell, HUD-meddelande, kistan blir öppnad (gråtonad, tom).
- Quest-/taskneutral i M6 (inga kistquests ännu).

## 4. Debug + teststrategi

- Debug-konsol: `dungeon <tema> [seed]` — hoppa direkt in i given dungeon.
- **GUT-tester** (`test_dungeon_generator.gd` + utökningar):
  - Determinism: samma seed ⇒ identiska tiles.
  - Konnektivitet: flood-fill från P når exit, kista och alla spawntiles.
  - Struktur: exakt 1 P, 1 exit, 1 kista; radlängder lika; yttermur intakt.
  - Spawns: ≤ 30, alla monster ur temats pool och finns i MonsterDB.
  - Teman: integritetstest mot monsters/items/nodes (som test_unlocks_data).
  - Save i dungeon skriver ingångszonen.
- Boot-check + manuellt speltest. Prestanda: 60 FPS-budgeten gäller.

## Avgränsningar (YAGNI)

- Ingen flervåningsstruktur (en nivå per nedstigning).
- Inga dungeon-bossar, inga nya monster/items — M7+.
- Ingen minimap, ingen dungeon-persistens i sparfilen.
- Inga låsta dörrar/nycklar inne i dungeons (unlock-väven är ytvärldens).
