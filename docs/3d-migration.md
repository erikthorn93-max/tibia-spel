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
- [x] Gathering-kärnan till sim (2026-07-06): `entities/gather_sim.gd`
      (GatherSim, RefCounted) äger krav/chansrull med väderbonus/skörd/xp/
      laddningar/uttömning, med signaler (`swung`, `harvested`, `xp_only`,
      `depleted_now`, `respawned`). `gather_node.gd` är ren vy (sprite,
      squash, gnistor, flyttext, gråtoning, respawn-timer) med bakåt-
      kompatibel delegation; vädret skickas in av vyn så kärnan är headless.
- [ ] Player: spell-fx-plumbing till sim (låg prioritet — aim/fx är i
      praktiken presentationsbundna)
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
- [x] Gathering i 3D (2026-07-06, `entities/gather_node3d.gd`): noder
      spawnas ur zonens node-punkter — GLB per skill där en naturlig modell
      finns (mossy_rock/fir_tree_short/wildflower/fern), annars platshållar-
      låda i nodens signaturfärg (samma regel som stationer). Klick →
      `Player3D.set_gather_target` med 2 s-tick, auto-walk intill och samma
      besked som 2D ("Du behöver …"/"Kräver …"); strid, klick-för-att-gå och
      manuell rörelse nollar gather-målet ömsesidigt, precis som player.gd.
      Skörd/xp som poolad flyttext, squash-tween per sving (ingen allokering),
      uttömd nod sjunker ihop och grånar skylten tills respawn. Väderbonusen
      (storm-fisket) fungerar i 3D via nytt `ZoneModel.weather`-fält som
      GatherNode3D löser upp mot WeatherSystem. 16 nya tester i
      test_gather3d.gd (sim-kärna, väder, vy, spawning, klick-routing,
      gather-tick).
- [x] Markloot + grav i 3D (2026-07-06, `entities/ground_item3d.gd`):
      GroundItem3D — guldromb med pop-in, långsam snurr, 60 s livstid med
      slutblink (tider delas med 2D:s GroundItem). Monsterdöd spawnar påsen
      på dödstilen (`died(drops)`-signalen, som 2D-vyn); klick inom 1 ruta
      plockar allt via den generiska interactable-routern, med flyttext ur
      poolen. Döds-bokföringen extraherad till `World.drop_death_loot()`
      (renderer-agnostisk — 2D:s `_on_player_died` och game3d delar den);
      graven persisteras i GameState som förut och 3D-zonladdning återskapar
      den persistenta grav-påsen i grav-zonen. Minimapens loot-källa
      inkopplad via `attach_minimap` (gula prickar + gravsten fungerar i
      3D). 12 nya tester i test_loot3d.gd.
- [x] Arenan i 3D (2026-07-09): game3d spawnar arenavågorna som Monster3D
      (samma spawnregler som world.gd — lediga rutor minst 2 steg från
      spelaren, elite-rullen ingår, ingen respawn); world.gd:s handler är
      gated på 2D-zonen och game3d:s på arenazonen så exakt en vy spawnar.
      Att lämna sanden mitt i en omgång avbryter (som 2D:s start_game);
      döds-abort låg redan i world.gd:s autoload-koppling. Hud3D fick 2D:ns
      arenabanner (våg/namn/kvar, live via ArenaSystem-signalerna) med
      namngivna metod-kopplingar som auto-kopplas bort vid scenbyte.
      Arenastarten via Torbens dialog fungerade redan genom HUD-bryggan.
      7 nya tester i test_arena3d.gd.
- [x] Ljud i 3D (2026-07-09): Ambience-bädden läser nu den renderer-
      agnostiska zonmodellen (World.zone_model, satt av båda vyerna) i
      stället för 2D-zonnoden — regnsus/grottrummel/vindsus ljuder därmed
      även i 3D. Monster3D spelar stridsljuden (hit/crit, charm per element,
      dödsljud — samma regler som 2D:s monster.gd, dödsträffen låter via
      monster_die), Player3D kopplar kraftslagets denied/crit i _init som
      2D. Spelarens hurt/död/charm-block bor redan i GameState och var
      renderer-agnostiska. 4 nya tester (zonmodell-källan + spec-ljuden).
- [x] Väder i 3D (2026-07-09, `world/weather_particles3d.gd`): nederbörd som
      EN MultiMesh-batch (regnstrimmor, tätare/längre åskskyfall, dansande
      snöflingor — fart/färg/antal/strimlängd ur ui/weather.gd, samma som 2D);
      lådan följer spelaren, deterministiskt frö. Väderdimma + ljusdämpning i
      miljön via Atmosphere3D (WEATHER_FOG/WEATHER_LIGHT) — vädret äger
      stämningen över biomdimman, samma företrädesregel som 2D. Blixt &
      dunder vid åska i game3d med 2D:s exakta Weather-kurvor (nedslags-
      schemaläggning, dubbelblixt-avklingning, fördröjt dunder via Sfx);
      blixten lyser upp sol/ambient mot vitt. Dimväder har inga partiklar —
      env-dimman äger det. 12 nya tester i test_weather3d.gd.
- [x] Ambient-partiklar i 3D (2026-07-09, `world/ambient_particles3d.gd`):
      eldflugor om natten ute, drivande grottdamm, stigande glödflagor vid
      vulkanen — samma Biome-regler som 2D-overlayn (typ/färg/fart/antal ur
      biome.gd; vädret äger stämningen när det pågår). EN MultiMesh-batch av
      billboardade additiva quads (en draw call, ingen per-frame-allokering);
      lådan följer spelaren, partiklarna driver med sidledesvandring och
      wrappar, twinkle via instansfärg. 9 nya tester i test_ambient3d.gd.
- [x] Dygnsljus + biomstämning i 3D (2026-07-09, `world/atmosphere3d.gd`):
      Atmosphere3D — rena kurvor (3D-motsvarigheten till ui/atmosphere.gd)
      för sol/ambient/himmel över dygnet: neutral middagssol, varm gryning/
      skymning, svalt månsken på natten (aldrig beckmörkt), himlen nästan
      släckt vid midnatt. Biomdimma per zon via Biome.classify — grönt
      träskdis, tätt grottmörker, rödbrun vulkanaska, frostdis, hetta-dis i
      öknen; grottor har himmelstak (ser aldrig dagsljus). game3d applicerar
      per frame (skalära parametrar, ingen allokering) och per zonbyte.
      Bara billiga medel: exponentiell djupdimma, ingen volymetrik/post.
      10 nya tester i test_atmosphere3d.gd.
- [x] Skattkistor i 3D (2026-07-09, `entities/chest3d.gd`): Chest3D spawnas
      ur zonens chest-punkter (dungeons) — treasure_chest-GLB:n med billboardad
      skylt, klick inom 1 ruta via den generiska interactable-routern. Loot-
      rullen extraherad till `TreasureChest.open_loot()` (renderer-agnostisk,
      delas av 2D-kistan); öppnad kista sjunker ihop och grånar skylten (samma
      idiom som uttömda gathering-noder). Kistan togs bort ur Zone3D-scattern —
      vyn ägs av entiteten så öppnad-tillståndet syns. 9 nya tester i
      test_chest3d.gd.
- [x] Tema-styrd scatter (2026-07-09, `zone3d.gd`): trädset per biom via
      `Biome.classify(zone_id)` — öknen får kaktusar, träsket/vulkanlandet
      döda träd, isen tålig barrskog; biom utan egen rad behåller
      standardskogen. Gles markdekor per biom (`ground_decor_for`):
      småkaktusar på ökengräs, ormbunkar överallt i träsket, is/vulkan/
      grotta kala. Samma deterministiska jitter och draw call-budget som
      förut. 5 nya tester i test_zone3d.gd (trädset, modellfiler, dekor,
      öken- och träskzoner).
- [x] Assets, miljö-uppföljning (2026-07-09): `bush.glb` (21 MB) borttagen ur
      repot — Meshy-källan är ~292 000 osammanhängande lövkorts-öar i ett
      mesh, och edge-collapse-decimering kan aldrig gå under en triangel per
      ö (Blender-pass med join+decimate verifierade golvet). En spelbar
      buske kräver ombakning till några få alpha-kort; görs bara om busken
      faktiskt behövs (ingen kod refererade den). Källan finns kvar i
      gitignorerade `_meshy_cache`. Fler monster-/NPC-modeller decimeras
      vid behov med `tools/decimate_glb.py`.

- [x] Ryggsäcks-drag till marken i 3D (2026-07-10): `World.drop_item` är nu
      renderer-agnostisk bokföring + `item_dropped`-signal — 2D-påsen spawnas
      bara när 2D-zonen lever, game3d prenumererar och lägger en GroundItem3D
      på spelar-tilen (samma spegel-gating som arenavågorna). Hud3D bär
      2D:ns world_drop_zone oförändrad (först bland barnen, bakom panelerna),
      så drag ur ryggsäck och utrustning (unequip → drop) fungerar som i 2D,
      inklusive "Du tappade …"-beskedet via HUD-bryggan. 6 nya tester i
      test_drop3d.gd.
- [x] Garderoben i 3D (2026-07-10): Hud3D bär 2D:ns wardrobe-panel på samma
      toggle_wardrobe-action (U) — panelen var den sista som saknades i
      HUD-bryggan. Player3D visar outfiten som en färgton i tröjfärgen via
      en delad additiv material_overlay (Monster3D-idiomet: materialet skapas
      EN gång, outfit-byten ändrar bara albedo; standard = svart = osynlig).
      Hjälte-GLB:n har en bakad textur utan färgzoner (verifierat med
      tools/inspect_glb.gd), så per-plagg-färger kräver ommappade modeller —
      görs bara om outfits blir viktiga visuellt. Live-uppdatering via
      appearance_changed. 6 nya tester i test_outfit3d.gd.
- [x] 3D spelbart från huvudmenyn (2026-07-10): "3D-läge"-knapp i menyn sätter
      `World.use_3d` — Nytt spel/Fortsätt (och character creator) routar via
      `World.game_scene_path()` till game3d.tscn. Menystartade 3D-sessioner
      bootar från GameState/sparfilen (samma regel som 2D:s game_root) och
      sparar vid zonbyten + dungeon-nedgångar (ytzonen bokförs i
      `World.last_surface_zone` så SaveManager:s dungeon-normalisering delas);
      autosaven (60 s) täcker nu även 3D. F6-devkörningar av game3d.tscn och
      testsviten har use_3d = false: de bootar slice-startzonen som förut och
      rör ALDRIG spelarens sparfil. 10 nya tester i test_session3d.gd.
- [x] Dödsskärm i 3D + dödsvakt (2026-07-11): Hud3D bär 2D:ns dödsskärm
      (player_died → överlägg med "Återuppstå"-knappen); game3d auto-respawnar
      inte längre utan svarar på player_respawned med zonombyggnad bakom
      faden — samma UX som 2D. Buggfix i GameState.take_damage: dödsvakt så
      liket inte tar mer stryk — utan den re-emittades player_died per slag
      mot liket och det andra drop_death_loot-anropet såg tomt inventory och
      raderade graven (latent i BÅDA renderarna, mest trolig i 2D där
      spelaren själv väljer när respawn sker). 5 nya tester i test_death3d.gd.
- [x] Interaktionsmodeller (2026-07-11, `zone3d.gd`): trappor och dungeon-
      nedgångar renderas med stone_staircase-GLB:n, olåsta portaler med
      emerald_sigil + svag additiv skimmer-overlay (Monster3D-idiomet); låsta
      portaler och genvägar behåller den dämpade kuben ("stängd"). Markörerna
      bygger på den delade mesh-cachen (_model_meshes — GLB:n instansieras
      aldrig per marker), deterministisk 90°-vridning per ruta, och faller
      tillbaka till kuben om modellen saknas. Alla markörer heter Marker_x_y
      så vyn kan räknas/städas per namn. 5 nya tester i test_zone3d.gd.
- [x] Procedurellt karaktärsliv i 3D (2026-07-11,
      `entities/character_motion3d.gd`): CharacterMotion3D — 3D-motsvarigheten
      till 2D:s CharacterVisual-kurvor: gång-studs under ett steg (noll vid
      tile-gränserna, topp mitt i — kontinuerlig över carry-over-steg) och
      subtil idle-andning. GLB-modellerna är origgade rekvisita, så livet är
      rena transformkurvor applicerade i render_interpolate (spelare/monster,
      studsen bokförs prev/curr per sim-steg och alpha-interpoleras som
      positionen) resp. _process (NPC:er — andning är hela deras liv).
      Attack-stöten pausar livs-animen via _attacking-flaggan (2D-idiomet);
      monster/NPC:er får desynkad andningsklocka så flocken inte andas i
      takt. Ingen allokering per frame. 9 nya tester i test_motion3d.gd.
- [x] Fast simuleringstick i 3D (2026-07-11, `world/sim_ticker.gd`): SimTicker
      (RefCounted) omvandlar frame-tid till hela sim-steg om 50 ms (20 Hz)
      med tak per frame — en fryst frame droppar sim-skulden i stället för
      att jagas ikapp i en dödsspiral. game3d tickar PlayerSim/MonsterSim
      centralt i stället för per vy-`_process`: GDScript-kostnaden för
      AI/strid följer tick-frekvensen i stället för bildfrekvensen, och
      simuleringen beter sig lika vid 30 som 240 FPS. Vyerna bokför
      prev/curr-position per sim-steg och renderas med alpha-interpolation
      mellan de två senaste stegen (klassisk fixed timestep + render-
      interpolation) — mjuk rörelse till priset av ett sim-stegs latens.
      Input-intent latchas per frame så korta tangenttryck mellan stegen
      inte tappas. Sista prestandakravet från godot_rpg-lärdomarna är därmed
      på plats. 9 nya tester i test_sim_tick3d.gd; 2D-vyerna oförändrade.
- [x] Zon-fade + spara vid avslut (2026-07-10): Hud3D fick 2D-HUD:ens
      transition (tona till svart → bygg om → tona in); game3d:s zonbyten
      (portal, dungeon-nedgång, dödsrespawn) kör bakom faden i stället för
      call_deferred. SaveManager sparar vid NOTIFICATION_WM_CLOSE_REQUEST
      (fönsterkryss/Alt+F4) med samma sessionsgate som autosaven
      (`_session_active`: 2D-spelare eller menystartad 3D) — gäller båda
      renderarna, och F6-dev/tester förblir save-fria. 4 nya tester i
      test_session3d.gd.
- [x] Ombakade karaktärs-GLB:er (2026-07-12, `tools/rebake_character.py`):
      alla 12 karaktärsmodeller ombakade från Meshy-källorna i
      assets/_meshy_cache med en pipeline som tål lösa mesh-öar: join till
      ETT objekt → svetsa vertex (merge by distance) → decimera till
      8000 tris → texturer till 512px → höjd normaliserad till 1,0 m med
      fötterna på y=0. Tidigare decimering betedde sig öaktigt (hål/spretiga
      kanter) eftersom edge-collapse kördes per ö. Sökvägar/skalning
      oförändrade (Monster3D:s `h`-värden gäller fortfarande) — ren
      asset-swap. Visuell QA via tools/shot_models.gd (kontaktkarta över
      alla 12) och tools/shot_player.gd.
- [x] Stationsmodeller i 3D (2026-07-12, `tools/build_station_models.py`):
      alla 7 stationstyper (städ/gryta/alkemibord/runaltare/hantverksbänk/
      bönaltare/arbetsbänk) har procedurala låg-poly-GLB:er byggda i headless
      Blender — primitiver med platta Principled-material, inga texturer
      (6–25 kB/st), världsskala med fötterna på y=0. Station3D laddar
      station_<typ>.glb och faller tillbaka till signaturfärgade lådan om
      filen saknas (Chest3D-idiomet). Lärdomar bakade i paletten: metallic
      1,0 blir svart i Godot utan reflektionsmiljö (guld → 0,4) och emission
      över ~1,5 bränns ut till vitt (runa/glöd/lågor hålls låga). Visuell QA
      via tools/shot_stations.gd. 3 nya tester i test_station3d.gd
      (GLB-vakt per typ, modell- och fallback-vägen).
- [x] Procedurala kreatursmodeller (2026-07-12,
      `tools/build_creature_models.py`): fem arketyper (spindel/orm/fågel/
      padda/krabba) i 14 färgvarianter (creature_*.glb) byggda i headless
      Blender — samma konventioner som karaktärerna (1,0 m-normaliserade,
      fötter på y=0, nos mot +Z). Ormen ligger i Tibia-posen: hoprullad
      spiral med rest hals (utsträckt/rest orm läste som larv). 22 nya
      poster i Monster3D.MODELS (bl.a. alla spindlar, ormar/maskar, fåglar
      och krabborna) — 44 av 99 monster har nu gestalt, resten behåller
      lådan. 2 nya vakttester i test_monster3d.gd: varje MODELS-post pekar
      på en existerande GLB OCH ett riktigt MonsterDB-namn (felstavad
      nyckel ger annars tyst platshållarlåda). Visuell QA via
      tools/shot_creatures.gd.
- [x] Kreatursmodeller batch 2 (2026-07-12): elva nya arketyper i 26
      varianter — blob (lava/is/träsk/sot), svampfolk, vålnad, golem/väktare
      (is/kristall/korall/sten/trä), fisk (haj/mörk/lyktfisk med lysande
      betespö), skorpion, skarabé, kraken, avgrundsöga, lysfluga och varan.
      36 nya MODELS-poster (33 nya modeller + 3 återbruk: farao → zombie,
      solkonungen → skelett, leviatanen → blå orm) — 80 av 99 monster har
      nu gestalt. Kvar som lådor: humanoiderna (troll/minotaurer/dvärgar/
      vampyrer/nekromant/lich), drakarna, ärkedemonen och vildsvinet —
      kräver egna arketyper. Vakttesterna täcker alla poster automatiskt.
- [x] Kreatursmodeller batch 3 — FULL TÄCKNING (2026-07-12): sex sista
      arketyper i 12 varianter — brute (troll grön/minotaur hornad), dvärg
      (gruv/järn/geomant-lila med skägg+hjälm), kåpgestalt (vampyr/nekromant/
      lich med lysande ögon), drake (eld/is med svepta vingar, rest hals,
      horn), ärkedemon (brute + vingmembran) och vildsvin. 17 nya poster →
      ALLA 99 monster har gestalt; platshållarlådan lever kvar enbart som
      fallback för framtida omappade monster. Lärdom: upprätta vingovaler
      vid huvudhöjd läser som kaninöron — vingar ska svepas bakåt-utåt i
      axelhöjd. Ny fulltäckningsvakt i test_monster3d.gd: varje monster i
      MonsterDB MÅSTE ha en MODELS-post — ett nytt monster utan gestalt
      faller i test i stället för att tyst bli en låda.

- [x] Husdörrar i 3D (2026-07-12, `tools/build_prop_models.py`): entrance-
      rutorna (värdshus/slott/gillen) fick en procedural trädörr i stenkarm
      (prop_door.glb, 12 kB, världsskala 1,66 m — under vägghöjden 2,0) i
      stället för portalsigillet — samma dörr/trappa/portal-åtskillnad som
      2D-vyn. Dörren vrids efter sin väggrad (grannväggar i x-led → spänner X,
      enbart y-led → 90°); markörvridningen flyttad till markör-roten så den
      är läsbar för tester. Låsta och olåsta dörrar ser lika ut (stängd dörr
      läses som stängd — låset prövas vid steget, som 2D). Nytt visuellt
      QA-verktyg `tools/shot_zone.gd/.tscn`: bygger en riktig zon med Zone3D
      i game3d:s ljus/kamera och skärmdumpar namngivna punkter (start/bank/
      butik/dörr). 3 nya tester i test_zone3d.gd (dörrmesh + ingen overlay,
      GLB-vakt, väggriktning).

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
