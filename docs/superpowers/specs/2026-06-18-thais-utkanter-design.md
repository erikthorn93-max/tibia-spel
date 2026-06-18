# Thais utkanter — designspec

**Datum:** 2026-06-18
**Status:** Godkänd, redo för implementationsplan
**Omfattning:** Bygga ut Thais (`data/zones/town.json`) med landsbygd/utkanter utanför
stadskärnan, plus två nya landsbygdszoner — likt riktiga Tibia.

## Mål

Idag är Thais en 160×112-stadskärna vars kanter är fullproppade med ~12 portaler
som teleporterar rakt ut till separata vildmarks- och dungeonzoner. Det känns
overkligt: man går till stadskanten och teleporteras till en vulkan.

Målet är en sammanhängande värld där staden omges av landsbygd (hav, berg, fält,
träsk, vägar, en bro) innan man når vildmarken — och där de gamla portalerna
flyttas ut till tematiskt rimliga platser.

## Beslut (från brainstorming)

| Fråga | Beslut |
|---|---|
| Struktur | **Hybrid** — väx town.json + 1–2 nya landsbygdszoner |
| Skala | **~280×200** (stora utkanter) |
| Geografi | **Klassisk Thais** — hav väster, berg öster, fält+bro norr, träsk söder |
| Nya tiles | **Ja** — `t`=träd, `c`=kullersten-väg, `g`=åker |
| Exotiska resmål | **Ute i landsbygdszonerna** (ingen teleport-helgedom) |

## 1. Världslayout & mått

- Canvas: **160×112 → 280×200**. Stadskärnan stämplas i mitten med offset
  **(60, 44)** (eftersom (280−160)/2 = 60 och (200−112)/2 = 44). Kärnan bevaras
  oförändrad förutom att de utåtgående vildmarksportalerna tas bort från dess
  kanter (se §3).
- Terräng per väderstreck:
  - **Väster:** `~` hav → `b` strandremsa mot muren. Hamn-ingången (U→thais_docks)
    flyttas till stranden.
  - **Öster:** `W` bergsmassiv (blockerar) med `,`/`c` stigar. Grott- och
    gruvmynningar i berget.
  - **Norr:** `g` åkrar + `c`/`,` landsväg → **bro av `f` trägolv** över en flod
    (`~`) → portal till `thais_fields`.
  - **Söder:** `s` träsk + `.` gräs → trollmark → portal till `thais_wilds`.
  - **Skog:** `t`-träd i klungor i nordöstra brynet (blockerande), runt
    forest-portalen.

### Terräng-palett (efter tillägg)

Befintliga: `.`gräs, `,`jord, `W`sten/mur(block), `~`vatten(block), `s`träsk,
`b`strand, `w`fönster(block), `f`trägolv, `r`tak(block), `n`trappa.

Nya (läggs till i `world/placeholder_tiles.gd`):

| Tecken | Namn | Gångbar | Fallback-färg |
|---|---|---|---|
| `t` | tree (träd) | **Nej** (blockerar) | mörkgrön ~`#2f5a28` |
| `c` | cobblestone (kullersten-väg) | Ja | grå ~`#8a8478` |
| `g` | field (åker) | Ja | gulgrön ~`#9aa84e` |

Ändringar som krävs:
- `placeholder_tiles.gd`: lägg `t`,`c`,`g` i `TERRAIN`, `TILE_FILES`, `COLORS`.
  Atlas byggs av `TERRAIN.size()` kolumner → blir 13, inga andra ändringar.
- `zone.gd` rad 127 (walkability): lägg `t` i blockerande mängden:
  `terrain != "W" and terrain != "w" and terrain != "r" and terrain != "~" and terrain != "t"`.
  `c` och `g` är gångbara (inget tillägg behövs).
- `ui/minimap.gd` `T_COLORS`: lägg kartfärger för `t`/`c`/`g` så de syns på kartan.
- Riktiga sprites (`assets/sprites/tiles/{tree,cobblestone,field}.png`) är valfria
  senare; fallback-färgerna räcker för att leverera.

## 2. Nya landsbygdszoner

Två nya zonfiler, byggda i samma JSON-format (tiles + legend) som övriga zoner.

### `data/zones/thais_fields.json` — Norra landsbygd
- Åkrar (`g`), gård (byggnad), landsväg (`c`) som löper norrut.
- Når Thais via södra kanten (retur-portal → Thais norra bro-tile).
- **Kantportaler till exotiska resmål:** `ice` (långt norrut), `desert` (torr östkant).
- Spawn-tabell: milda fält-monster (t.ex. råttor, vargar).

### `data/zones/thais_wilds.json` — Trollmark/träsk (söder)
- Träsk (`s`), gräs (`.`), troll-/orcläger.
- Når Thais via norra kanten (retur-portal → Thais södra träsk-tile).
- **Kantportaler till exotiska resmål:** `volcano`, `demon_temple`,
  `minotaur_maze`, `orc_rift`.
- Spawn-tabell: troll/orc-tema.

Storleksriktlinje: tillräckligt stora (~120×100) för att rymma resvägen och de
fyra/två yttre portalerna utan att kännas trånga. Exakt mått sätts i planen.

## 3. Portal-omflyttning

Interiörerna (banker, shoppar, gillen, depot, värdshus, tempel, arena, fängelse,
prayer-altare, trappa till rain_castle_f2) ligger kvar i stadskärnan **oförändrade**.

De ~12 utåtgående vildmarks-/dungeonportalerna flyttas:

| Destination | Gammalt | Ny placering |
|---|---|---|
| cave | stadskant | Östra berget (grottmynning) |
| dwarf_mine | stadskant | Östra berget (gruvmynning) |
| vampire_crypt | stadskant | Östra berget (krypta i klippan) |
| troll_cave | stadskant | Södra träsket (nära Thais) |
| forest | stadskant | Nordöstra skogsbrynet |
| coast | stadskant | Västra stranden |
| ice | stadskant | Via `thais_fields` (norra kanten) |
| desert | stadskant | Via `thais_fields` (östra kanten) |
| volcano | stadskant | Via `thais_wilds` (söder) |
| demon_temple | stadskant | Via `thais_wilds` (söder) |
| minotaur_maze | stadskant | Via `thais_wilds` |
| orc_rift | stadskant | Via `thais_wilds` |

**Reciprocitet:** måldestinationernas retur-portaler pekar idag på Thais
`player_start` (stadens mitt). Det behålls som standard. Om vi vill landa vid rätt
port istället sätts retur-tiles per destination — markeras som valfri förbättring,
ej blockerande.

## 4. Bygg-metod — engångsgenerator

En handbyggd 280×200-karta (56 000 tiles) är orealistisk och radbredd-känslig.
Istället ett deterministiskt **engångs-generatorskript** som körs i Godot-editorn.

`tools/gen_thais.gd` (EditorScript eller `@tool`-skript):
1. Läser stadskärnan från en sparad källa **`data/zones/_thais_core.txt`** (de
   nuvarande 112 tile-raderna, extraherade ur dagens town.json innan ändring).
2. Skapar en 280×200-canvas och målar omgivningen seedat:
   hav+strand (väster), berg+stigar (öster), åkrar+väg+flod+bro (norr),
   träsk+trollmark (söder), skogsbryn (nordost).
3. Stämplar in kärnan på offset (60,44).
4. Hugger **portar** i kärnmurarna i linje med vägarna och drar
   väg (`c`/`,`) gata→port→kartkant/bro.
5. Tar bort kärnans gamla vildmarksportaltecken och placerar de omflyttade
   portalerna på sina nya tiles (§3).
6. Skriver ut **ny `data/zones/town.json`** (tiles + sammanslagen legend), med
   garanterat exakt 280 tecken per rad.

Statisk output committas. Skriptet sparas för framtida regenerering/tweaks.
Allt nedströms (minimap, AStar-pathfinding, sparsystem) är oförändrat — det är
fortfarande bara en vanlig zon-JSON.

## 5. Risker & kantfall

- **Radbredd-assert** (`zone.gd:47`): generatorn garanterar 280 tecken/rad → ingen
  handfel.
- **Skiftläges-dubbletter i legend** (känt problem, obs 703): nya legend-tecken
  (`t`,`c`,`g` är terräng, ej legend; men nya portaltecken) måste vara unika och
  skiftlägesmedvetna. Verifiera mot befintliga town-tecken.
- **Legend-teckenbrist:** town använder redan många bokstäver. Inventera lediga
  tecken innan nya portaler placeras; återanvänd befintliga portaltecken där det
  går (samma destination = samma tecken).
- **Performance:** AStarGrid2D över 56 000 celler — Godot klarar det, men verifiera
  laddningstid och att pathfinding-uppdatering inte hänger sig.
- **Minimap:** pan/zoom fungerar nu (tidigare fix); 280×200 ryms i pan-intervallet.
  Verifiera att hela kartan går att panorera.
- **Spawns i utkanter:** nya områden får egna spawn-tabeller så de inte känns döda.
- **Backup av kärnan:** spara `_thais_core.txt` **innan** town.json skrivs över, så
  kärnan aldrig går förlorad.

## Leverabler

1. `world/placeholder_tiles.gd` — `t`/`c`/`g` tillagda.
2. `world/zone.gd` — `t` blockerande i walkability.
3. `ui/minimap.gd` — kartfärger för `t`/`c`/`g`.
4. `data/zones/_thais_core.txt` — extraherad stadskärna (källa).
5. `tools/gen_thais.gd` — generatorskript.
6. `data/zones/town.json` — regenererad 280×200.
7. `data/zones/thais_fields.json`, `data/zones/thais_wilds.json` — nya zoner.
8. Tester: zon-laddning utan assert-fel, walkability för nya tiles, alla 12
   portaldestinationer nåbara, reciproka returer fungerar.

## Avgränsningar (ej i denna omgång)

- Riktiga sprites för `t`/`c`/`g` (fallback-färger räcker nu).
- Retur-tiles per portal (landar i stadens mitt tills vidare).
- Innehåll i de exotiska målzonerna (desert/volcano/ice m.fl.) — de finns redan
  som separata zoner; här flyttar vi bara hur man når dem.
