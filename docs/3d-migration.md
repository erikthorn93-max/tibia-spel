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

### Steg 2 — Extrahera `ZoneModel` *(en session)*
`RefCounted`-klass med grid, walkable, portaler, trappor, gates, AStar,
occupy/vacate, find_path. `zone.gd` (Node2D) äger en `ZoneModel` och blir ren
vy (tiles, markers, overlays). `world.gd` och entities pratar med modellen.
Vinst: helt headless-testbar världslogik.

### Steg 3 — Extrahera `MonsterSim`/`PlayerSim` *(2–3 sessioner)*
Rena klasser med hp/statuses/AI-tick/movement-intent och signaler
(`damaged`, `moved`, `died`, `status_changed`). Nod-scripten blir vyer som
prenumererar och animerar. `world.gd` typas om mot sim-klasserna.

### Steg 4 — 3D-slice *(parallellt spår när steg 2–3 är klara)*
- `Zone3D` + `Monster3D`/`Player3D` som *alternativa vyer* över samma modeller
- En zon (bit av Thais), gridrörelse, en monstertyp, en skill, en quest
- Assets: GLB:er från `_meshy_cache` — **måste decimeras i Blender först**
  (råa Meshy-modeller är 15–40 MB st)

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
