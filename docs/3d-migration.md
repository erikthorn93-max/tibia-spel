# 3D-migration — audit och plan

*Audit utförd 2026-07-02. Mål: samma spel (Tibia-känsla, OSRS-skills/quests)
renderat i 3D utan lagg — genom att byta presentationslager, inte skriva om.*

## Grundidé

Tibia är tile-baserat. Ett 3D-Tibia är samma rutnätssimulering som i dag,
presenterad med 3D-modeller och 3/4-kamera. All spellogik är redan datadriven
(JSON) och till stor del renderer-agnostisk. GLB-biblioteket i
`assets/_meshy_cache/` är starten på 3D-modellbiblioteket.

## Auditresultat

### 🟢 Redan renderer-agnostiskt (~75 %)

| Lager | Status |
|---|---|
| `data/*.json` (items, monsters, quests, skills, recipes, dialogue, spells, tasks, unlocks, charms, arena, nodes, npcs, outfits, dungeon_themes) | 100 % ren data |
| `combat/combat_formulas.gd`, `combat/combat_stance.gd` | 0 renderings-referenser |
| Autoloads: `quest_system`, `skill_atlas`, `spell_system`, `arena_system`, `charm_system`, `task_system`, `unlock_system`, `save_manager`, `dialogue_db`, `item_db`, `monster_db`, `time_of_day` | 0 renderings-referenser |
| `game_state.gd` | Nästan ren — en läcka: floating text spawnas direkt i scenträdet (~rad 227) |
| GUT-testerna | Testar logiklagret → säkerhetsnät under hela migrationen |

Undantagna (per design knutna till presentation, porteras separat):
`sfx.gd`, `ambience.gd`, `item_tooltip.gd`, `weather_system.gd`, `ui/`.

### 🟡 Blandat — logik och rendering i samma klass

- **`autoload/world.gd`** — spawn-regler, elite-chans, grav-drop och arenavågor
  är ren logik, men:
  - typad mot `Node2D` (`current_zone`, `player`, `game_root`)
  - instansierar `.tscn`-scener direkt (`_spawn_world_objects`)
  - `_make_elite()` petar direkt i monster-nodens `NameLabel`
  - anropar `hud.show_message()` direkt
- **`world/zone.gd`** — två saker i samma Node2D:
  - *logisk gridmodell*: `_walkable`, `portals`, `stair_points`, `gate_points`,
    `AStarGrid2D`, `occupy`/`vacate`/`is_occupied`, `find_path` (rad 10–40 är
    rena datastrukturer)
  - *tile-renderare*: `TileMapLayer`, portal-/dörr-/trappmarkers,
    shore/fringe/decor-overlays, pulse-tweens

### 🔴 Hårt kopplat — simulering bor på scen-noder

- **`entities/monster/monster.gd` (22 KB)**: hp, atk, statuseffekter, enrage,
  abilities och AI-tick kör i `_process` på en Sprite2D-nod, inflätat med
  tweens, hit-flash, damage numbers, status-auror.
- **`entities/player/player.gd` (22 KB)**: gridrörelse, attack-ticks,
  gathering, spellcasting inflätat med spelarljus, auror, spell-fx,
  target-markering via `modulate`.

## Refaktorplan

Allt görs i 2D-spelet, som fortsätter fungera efter varje steg. Testerna körs
efter varje steg.

### Steg 1 — Snabbfixar *(klart 2026-07-02)*
- [x] `game_state.gd`: charm-floating-text → signal (`charm_feedback`),
      player.gd prenumererar; även direktpeken `World.player.visual.play_hurt()`
      borttagen (player lyssnar redan på `player_hit`)
- [x] `world.gd` `_make_elite()` → `monster.make_elite()` med `is_elite`-fält;
      presentationen (★ + orange) bor i `_refresh_label()`
- [x] `world.gd`: `hud.show_message(...)` → signal (`world_message`),
      hud.gd prenumererar
- Känt kvarvarande: entities/ui anropar `World.hud.show_message` direkt på
  ~40 ställen — de är vy→vy-anrop och flyttas naturligt i steg 3.

### Steg 2 — Extrahera `ZoneModel` *(klart 2026-07-02)*
- [x] `world/zone_model.gd` (RefCounted): parse av zondata, terräng/walkable,
      AStar, portaler/trappor/gates/genvägar, spawn_table, occupy/vacate,
      apply_unlock — med signaler (`tile_opened`, `shortcut_opened`,
      `portal_unlocked`) som vyer prenumererar på
- [x] `zone.gd` (Node2D) är ren vy: tiles, overlays, markers. Bakåtkompatibla
      delegerande properties/metoder så world.gd/entities/ui är oförändrade
- [x] `test_spawn_table.gd` testar ZoneModel headless (inga noder)
- Hela sviten grön efter steget: 90 scripts, 1035 tester, 11650 asserts

### Steg 3 — Extrahera `MonsterSim`/`PlayerSim` *(pågår)*
Rena klasser med hp/statuses/AI-tick/movement-intent och signaler
(`damaged`, `moved`, `died`, `status_changed`). Nod-scripten blir vyer som
prenumererar och animerar. `world.gd` typas om mot sim-klasserna.
- [x] `entities/monster/monster_sim.gd` (RefCounted, 2026-07-02): stats,
      skada/elementmod, statuseffekter, enrage, elite, död (exp/loot/kills) —
      signaler `damaged`, `charm_damaged`, `element_reaction`,
      `status_changed`, `enrage_started`, `died(drops)`. `monster.gd` är vy
      (sprite, damage numbers, auror, ljud, dödsanim) med bakåtkompatibel
      delegation.
- [x] Monster: AI-tick + movement-intent i sim (2026-07-02) — `ai_tick(delta,
      player_tile)` äger jakt/attack/steg mot ZoneModel (occupancy flyttad
      till sim, `place()`); nya signaler `moved`, `attack_started`,
      `player_dodged`. Vyn interpolerar position ur `move_progress` och
      matar in spelar-tilen. Headless AI-testsvit i
      `tests/unit/test_monster_sim_ai.gd` (11 tester).
- [x] `PlayerSim` — rörelsekärnan (2026-07-02): gridsteg med frame-budget/
      carry-over, auto-walk via A*, facing, bump-unlock, agility-tiers och
      portalsteg (`step_completed` → vyn portal-checkar; zonbyte avbryter
      budget-loopen via zon-referensjämförelse). Signaler `moved`,
      `step_completed`, `facing_changed`, `message`. Vyn läser input-intent
      och interpolerar ur `move_progress`. Headless-tester i
      `tests/unit/test_player_sim_movement.gd` (12 tester).
- [x] Player: auto-attack + kraftslag i PlayerSim (2026-07-02) — target är
      en `MonsterSim`; träffrull/crit/charm/giftvapen/spec-profiler
      (cleave/crush/double/power) körs i sim med signaler `attack_swung`,
      `healed`, `spec_flash`, `spec_denied`, `spec_released`.
      `MonsterSim.note(kind)` låter angriparen begära feedback-taggar
      ("miss"/"förgiftad"/"bedövad") via monster-vyn. Vyn nollar sim-målet
      när målnoden frigörs (zonbyte/despawn) och samlar cleave-kandidater.
      Headless-tester i `tests/unit/test_player_sim_combat.gd` (11 tester).
- [ ] Player: gathering-tick och spell-fx-plumbing till sim (låg prioritet —
      gather-noder och aim/fx är i praktiken presentationsbundna)
- [x] `world.gd` typas om mot modellagret (2026-07-02): nytt fält
      `World.zone_model: ZoneModel` sätts vid zonbygge; all zondata
      (spawn/node/station/shop/bank/taskmaster/spell_teacher/chest-punkter,
      player_start, grid_size, zone_id, dungeon_theme, is_walkable/is_occupied)
      läses ur modellen. `current_zone` är nu enbart vy-container (add_child).
      En 3D-vy kan därmed återanvända world.gd:s spawn-orkestrering rakt av.

### Steg 4 — 3D-slice *(pågår)*
- [x] `Zone3D` (2026-07-02, `world/zone3d.gd`): renderar ZoneModel med
      MultiMesh — en batch per terrängtyp (≤13 draw calls för marken), ETT
      delat material med per-instans-färg (pooling). Väggar/träd/tak reser
      sig ur marken, vatten nedsänkt. Portal-/genvägs-/ingångsmarkers som
      emissiva kuber; prenumererar på modellens signaler precis som 2D-vyn.
- [x] `Player3D` (2026-07-02, `entities/player/player3d.gd`): samma PlayerSim
      som 2D — läser input-intent, interpolerar ur `move_progress`, vrider
      visualen efter `facing_changed`. Platshållarkapsel tills GLB är klar.
- [x] `world/game3d.tscn` + `game3d.gd`: startbar slice (F6) — thais_fields
      som ZoneModel, 3/4-kamera (barn av spelaren), sol + billig sky-env.
      Ingen SSIL/post-processing, enligt prestandakraven.
- [x] Headless-tester i `tests/unit/test_zone3d.gd` (8 st): koordinat-
      mappning, full terrängtäckning, materialpooling, markers,
      snap/interpolation/facing.
- [x] `Monster3D` (2026-07-02, `entities/monster/monster3d.gd`): vy över
      MonsterSim — AI-tick matas med spelar-tilen, interpolation ur
      `move_progress`, hp-bar, elite/enrage-emission, attack-stöt och
      dödskrympning. Material skapas EN gång per monster; träff-blink
      tweenar bara parametrar. Loot-drops på marken hoppas över i slicen
      (exp/kills bokförs av simmen).
- [x] Zonbyten i 3D (2026-07-02, `game3d.gd`): portalsteg via
      `step_completed` med samma regler som player.gd (lås → try_unlock +
      hint), dungeon-nedgångar via DungeonGen (exit tillbaka till ytrutan),
      monster-respawn per zon-epok, spelardöd → Tibia-återkomst till
      hemzonen. Mini-HUD (HP + meddelanden) tills riktiga HUD:en bryggas.
- [x] Spelarattack i 3D (2026-07-02): vänsterklick projiceras mot markplanet
      → tile; monster på rutan blir auto-attack-mål (röd målring, behålls
      medan man går — Tibia-stil), tom mark ger klick-för-att-gå via
      `walk_to`. Player3D kör `sim.attack_tick` och spelar sving-stöten
      via `attack_swung`. Målet nollas vid zonbyte.
- [x] Stridsfeedback i 3D (2026-07-02): `world/floating_text_3d.gd` — poolade
      billboardade Label3D (fast pool om 12, ingen per-träff-allokering) för
      skadesiffror (guld vid crit), charm-skada, element-taggar
      ("miss"/"förgiftad"/…) och läkning (+N). Kraftslag på F
      (`weapon_spec`-action som 2D) med cleave-insamling, guldstjärna +
      ljuspuls vid nedslag; hälsodryck på use_potion-knappen. HUD:en visar
      spec-mätaren ("Spec N%" → "KRAFTSLAG (F)").
- [x] Skills + quests synliga i slicen (2026-07-02): togglebar HUD-panel på
      samma actions som 2D (`toggle_skills`/`toggle_quest_log`) som listar
      färdigheter med nivåer resp. aktiva uppdrag med ledtrådar,
      live-uppdaterad via `skill_changed`/quest-signalerna. Skills tränas
      och quests fortskrider redan i 3D eftersom simarna äger logiken
      (gång→agility, strid→vapenskill, utforskning/kills→quests).
- [x] Riktig HUD-brygga (2026-07-03, `ui/hud3d.gd`): Hud3D (CanvasLayer)
      återanvänder 2D-spelets riktiga paneler ovanpå 3D-vyn — ryggsäck,
      skillpanel, besvärjelsebok, bestiarium, questlogg och utrustning — med
      samma toggle-actions som 2D (I/K/P/B/J/C, Escape stänger allt).
      Panelerna pratar bara med autoloads och behövde inte ändras; bryggan
      sätter `World.hud = self` så panelernas show_message-anrop landar i
      3D-HUD:ens meddelanderad. Inventoryt bröts ut ur hud.gd till
      `ui/inventory_panel.gd` (InventoryPanel) som nu delas av båda HUD:arna;
      game3d:s texbaserade mini-panel togs bort. HUD-bryggan komplett
      2026-07-05: minimap, NPC-paneler, spellcasting/hotbar och
      stationspaneler — se posterna nedan.
- [x] Assets, karaktärer (2026-07-03): `tools/decimate_glb.py` (Blender
      headless) decimerar Meshy-GLB:erna från `_meshy_cache` till
      `assets/models3d/` — polygonbudget per modell, texturer till 512px,
      normaliserade till 1,0 m höjd med fötterna på y=0. Player3D
      instansierar GLB-hjälten (kapsel kvar som fallback) och Monster3D
      instansierar via `MODELS`-mappningen (namn → fil + världshöjd;
      omappade monster behåller platshållarlådan i databasfärg).
      Träff-blink/elite/enrage omgjort till EN delad additiv
      `material_overlay` per monster — fungerar oavsett GLB:ns egna
      material, fortfarande utan per-träff-allokering. Modellernas framåt
      antas vara glTF-+Z (inre rotation PI) — finjusteras vid speltest.
- [x] Assets, miljö (2026-07-03): GLB-scatter i Zone3D via MultiMesh — träd
      (`t`, deterministiskt val ur pine_tree_tall/fir_tree_short/pine_stunted
      per ruta), klippor (`r` → mossy_rock), kistpunkter (treasure_chest,
      rakt ställda) samt gles vegetation (wildflower på var ~11:e gräsruta,
      fern på var ~13:e ängsruta — oblockerade rutor). Träd/klippor är nu
      markplattor med modellen ovanpå i stället för höga lådor. En batch per
      mesh-del i GLB:n (draw calls följer antalet modellfiler, inte
      instanser); mesh-delarna cachas statiskt så varje GLB instansieras EN
      gång per körning. Jitter (rotation/skala/position) är deterministisk
      per ruta. Scattern rivs och byggs om vid `tile_opened`, som marken.
- [x] NPC:er i 3D (2026-07-04, `entities/npc/npc3d.gd`): dialog-NPC:er
      (DialogueDB, per zon) och service-NPC:er (handlare/bankir/taskmästare/
      magiker från zonens legend-punkter) som klickbara Npc3D-noder — samma
      räckviddsregler som 2D (dialog 2 rutor, service 1, annars "gå närmare").
      Civila GLB-gestalter väljs deterministiskt per npc-id (kungen för
      Tibianus), namnskylt + quest-markör (gul !/grå ?) som billboardade
      Label3D, live-uppdaterad via QuestSystem-signalerna. Hud3D fick
      dialogruta, butik, bank och taskpanel (2D-panelerna återanvända) med
      ömsesidig uteslutning; game3d klick-router: monster → mål, NPC →
      interaktion, mark → gå. Paneler stängs vid zonbyte. Headless-tester i
      `tests/unit/test_npc3d.gd` (13 st).
- [x] Minimap i 3D (2026-07-05): minimap.gd gjord renderer-agnostisk —
      terräng/portaler/POI:er läses ur ZoneModel (`World.zone_model`, som
      game3d nu publicerar vid zonbygge, precis som world.gd) i stället för
      2D-tilemapen; spelar-tilen ur `GameState.player_tile` (PlayerSim bokför
      i båda lägena). Entiteter (monster/loot/dialog-NPC:er) läses via
      utbytbara källor (Callables): 2D-HUD:en behåller standardkällorna
      (zon-vyns barn), Hud3D pekar om dem mot game3d:s Monster3D/Npc3D-rötter
      via `attach_minimap`. Samma minimap + fullkarta (M, zoom/pan) i båda
      HUD:arna utan dubblering. Nya tester i test_minimap.gd (modellcache +
      3D-koppling).
- [x] Spellcasting + hotbar i 3D (2026-07-05): SpellSystem fick en pluggbar
      monsterkälla (`monster_source`, med vakt mot fri-ade ägare) — game3d
      matar den med levande MonsterSim:ar, 2D-standarden läser zonens barn
      som förut. `Player3D.cast_spell` med samma kontrakt som player.gd:
      self/area_self löses direkt, target/area mot nuvarande auto-attack-mål
      inom räckvidd (2D:s sikt-läge ersätts av Tibia-regeln "kasta på
      targeten"). Billig 3D-fx: poolad flyttext + kort elementfärgad
      ljuspuls. Hotbaren (ui/hotkey_bar.gd) gjordes caster-pluggbar och
      återanvänds i Hud3D — drag-and-drop, cooldown-overlay, graying och
      cast-blixt följer med gratis. Träffade simmar ger vy-feedback via
      signalerna som vanligt. 9 nya tester i test_spell3d.gd.
- [x] Hantverksstationer i 3D (2026-07-05, `entities/station3d.gd`):
      Station3D spawnas ur zonens station-punkter — klickbar låda i
      stationens signaturfärg (GLB saknas ännu, samma platshållarregel som
      omappade monster) med billboardad namnskylt. Klick inom 1 ruta öppnar
      receptpanelen för stationstypen; bönaltaret öppnar prayer-panelen —
      samma regler som 2D:s CraftingStation (etiketterna delas därifrån).
      Hud3D fick recipe_panel + prayer_panel med gemensam ömsesidig
      uteslutning (`_close_service_panels`); game3d:s klick-router
      generaliserad till `_interactable_at` (allt i _npcs_root med
      tile + interact()). HUD-bryggan är därmed komplett — alla 2D-paneler
      finns i 3D. 9 nya tester i test_station3d.gd.
- [ ] Assets, miljö-uppföljning: fler monster-/NPC-modeller decimeras vid
      behov; `bush.glb` är kvar på 21 MB (texturtung — ta i nästa
      Blender-pass); tema-styrd scatter (t.ex. kaktus i öknen, dead_tree i
      träsket) när zonerna får fler miljötecken

### Prestandakrav i 3D (från godot_rpg-lärdomarna)
- Ingen SSIL/dyra post-effekter; budget per frame från dag 1
- MultiMesh för tiles/vegetation; chunkad värld med laddningsradie
- LOD på karaktärsmodeller; material-pooling (per-hit-allokering dödade
  godot_rpg-prestandan)
- Fast simulerings-tick frikopplad från renderingen

## Slutbild

Efter steg 3 är 3D-spelet "bara" ett nytt presentationslager. Skills, quests,
zoner, crafting, bestiarium och arena följer med automatiskt, och 2D-läget
lever kvar som referens/fallback tills 3D-slicen är ikapp.
