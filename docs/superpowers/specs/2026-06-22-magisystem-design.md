# Magisystem — design

**Datum:** 2026-06-22
**Status:** Godkänd, redo för planering
**Milstolpe:** Magi (instant-spells + runor)

## Sammanfattning

Tibia2D har en `magic`-skill i `skills.json` och ett komplett mana-system, men
magin är i praktiken **trasig och halvkopplad**: `active_rune` sätts aldrig från
UI:t, och input-actionerna `use_rune`/`use_potion` är inte ens definierade i
`project.godot`. Det går alltså inte att kasta magi idag.

Denna milstolpe bygger magi till ett förstaklassigt system på två ben, precis som
i Tibia:

1. **Instant-spells** — kostar bara mana, kastas direkt, lärs av en NPC mot guld +
   magic-nivå (attack, heal, support, conjure).
2. **Runor** — items som conjureras med mana och sedan kastas från hotbaren mot ett
   mål via ett **sikt-cursor-läge** (aim mode).

All casting går genom **en** väg: hotbar → (instant) SpellSystem, eller (kräver mål)
AimController → SpellSystem. Det döda `active_rune`/`use_rune`-spåret tas bort.

## Mål och icke-mål

### Mål
- Datadriven spell-databas (`data/spells.json`) med attack/heal/support/conjure.
- Sikt-cursor (aim mode) för spells/runor som kräver ett mål, med range- och
  AoE-preview.
- Spellbook-panel: lista kända spells, dra till hotbar, lär nya spells via NPC.
- Conjure-spells som skapar runor av `blank_rune` → knyter magi till ekonomin.
- Färdigställ de befintliga runorna (inkl. AoE-runor GFB/ice wave) genom samma
  aim/cast-väg.
- Magic-XP från casting driver magic-nivån (kärn-loop).
- GUT-tester för gating, conjure, inlärning, AoE, XP, ren headless-boot.

### Icke-mål (YAGNI, v1)
- Ingen PvP-magi.
- Inga field-runor (kvardröjande eldfält/giftfält på mark).
- Ingen line-of-sight-blockering — aim använder enkel range-radie (Chebyshev).
- Ingen ny mana-regenerering utöver befintlig (potions/vila som redan finns).

## Arkitektur

Allt följer befintliga mönster. `player.gd` hålls fokuserad på
movement/attack/gather — aim-logiken bor i en egen nod, spell-logiken i en autoload.

| Unit | Fil | Ansvar |
|------|-----|--------|
| **SpellSystem** (autoload) | `autoload/spell_system.gd` | Laddar `spells.json`; håller inlärda spells; `can_cast()`-gating (nivå/mana/cooldown/reagent); cooldown-timers; `resolve_cast(spell_id, caster, target_tile)` (damage/heal/support/conjure); delar ut magic-XP. Ren logik, inget UI. |
| **AimController** | `entities/aim_controller.gd` (nod i `world/game.tscn`) | Sikt-läget: highlightar räckvidds-rutor, ritar AoE-fotavtryck under muspekaren, vänsterklick bekräftar → callback med vald ruta, höger/ESC avbryter. |
| **SpellbookPanel** | `ui/spellbook_panel.gd` (`DraggablePanelContainer`) | Listar kända spells (ord, mana, lvl, cd); dra spell → hotbar. "Lär"-flik via lärare: köp spells för guld. ESC stänger. |
| **SpellTeacherNPC** | `entities/spell_teacher_npc.gd` (+ `.tscn`) | NPC i Thais som öppnar Spellbook i lär-läge. Följer `taskmaster_npc`-mönstret. |
| **Hotkey-bar (utökas)** | `ui/hotkey_bar.gd` | Slot kan hålla `spell_id` **eller** `item_id`. Spell/runa som kräver mål → startar AimController; instant-spell → kastas direkt; potion/mat → `use_item` (oförändrat). Tar emot spell-drop ({"spell_id": …}). |

### Dataflöde vid casting
```
Hotbar-tangent/klick (eller Spellbook-klick)
  -> slot har spell_id?  -> SpellSystem.can_cast(spell_id)
                              fail -> HUD-meddelande, avbryt
                              ok, target=self    -> SpellSystem.resolve_cast(..., caster.tile)
                              ok, target≠self    -> AimController.begin(spell_def, on_confirm)
       slot har rune-item? -> samma väg (runa har target-typ i item-datan)
       slot har potion/mat -> GameState.use_item (oförändrat)

AimController.begin -> spelaren riktar -> vänsterklick på giltig ruta
  -> SpellSystem.resolve_cast(spell_id/rune_id, caster, vald_ruta)
       attack  -> hämta monster i zonen inom radius av rutan -> take_damage(roll_magic) [+status]
       heal    -> caster.heal
       support -> GameState.add_status(buff, duration)
       conjure -> remove blank_rune + mana -> add_item(rune, amount)
  -> dra mana, sätt cooldown, gain_skill_xp("magic", n)
```

## Datadriven targeting

Varje spell/runa har en `target`-typ:

- `self` — heal/support; kastas **direkt utan aim** (exura, haste, magic shield, healing-runa).
- `target` — en fiende; aim-cursorn måste landa på en varelse inom `range`.
- `area` — AoE; aim-cursorn väljer valfri ruta inom `range`, träffar den + alla
  varelser inom `radius` (Chebyshev).
- `area_self` — självcentrerad AoE-burst; kastas **direkt utan aim**, träffar alla
  varelser inom `radius` runt spelaren (t.ex. Berserk / exori).

AimController läser `range` och `radius` från spell-/rune-datan och ritar både
räckvidden (dimmar out-of-range) och AoE-previewen under cursorn. Ogiltigt klick
avbryter inte siktet — visar bara en hint ("för långt bort").

## Spells & runor

### `data/spells.json` (instant-spells)
Fält per spell: `name`, `words`, `type` (`attack|heal|support|conjure`),
`target` (`self|target|area`), `element`, `base_power`, `mana_cost`, `magic_lvl`,
`cooldown`, `price` (guld att lära), valfri `radius`, valfri `status`
(typ/duration/power), och för conjure: `produces` (rune-id), `amount`, `reagent`
(`blank_rune`).

Planerad startuppsättning (~16 spells, exakta värden sätts i plan/implementation):

| Ord | Namn | Typ | Target | Magic-lvl |
|-----|------|-----|--------|-----------|
| exura | Light Healing | heal | self | 8 |
| exura gran | Intense Healing | heal | self | 20 |
| utevo lux | Light | support | self | 8 |
| utani hur | Haste | support | self | 14 |
| utamo vita | Magic Shield | support | self | 14 |
| exori vis | Energy Strike | attack | target | 12 |
| exori flam | Flame Strike | attack | target | 14 |
| exori frigo | Ice Strike | attack | target | 15 |
| exori mort | Death Strike | attack | target | 16 |
| exevo flam hur | Fire Wave | attack | area | 18 |
| exevo frigo hur | Ice Wave | attack | area | 20 |
| exori | Berserk | attack | area_self | 35 |
| adori vis | Conjure Energy | conjure | self | 13 |
| adori flam | Conjure Fire | conjure | self | 15 |
| adori frigo | Conjure Ice | conjure | self | 15 |
| adevo grav flam | Conjure GFB | conjure | self | 27 |

### Runor (items)
De befintliga runorna (`attack_rune`, `fire_rune`, `healing_rune`, `ice_rune`,
`energy_rune`, `death_rune`) behålls och kastas via aim. `healing_rune` får
`target: self`. AoE-runorna `fire_bomb_rune` (GFB) och `ice_wave_rune` får
`target: area` + `radius` + `rune_power` + `mana_cost` (saknas idag). Ny item
`blank_rune` (köps i shop / dropas) som conjure-spells förbrukar.

## Inlärning & ekonomi

SpellTeacher-NPC i Thais öppnar Spellbookens lär-flik. Spells med uppfylld
magic-nivå går att köpa för guld → läggs i `GameState.learned_spells`.
Conjure-spells gör magi till en intäktskälla (sälj runor) och knyter ihop med den
befintliga bank/shop-ekonomin.

## Uppstädning av trasig kod

- Lägg till saknade input-actions i `project.godot` (`use_potion` m.fl. som
  refereras men inte finns).
- Ta bort det döda `active_rune`/`use_rune`-spåret i `player.gd` och
  `_update_spells()`/`_cast_rune()` — all casting går nu genom hotbar +
  AimController.
- `GameState`: nytt `learned_spells: Array[String]` (persisteras av SaveManager);
  `active_rune` migreras bort (ignoreras vid load, fält tas bort ur save-payload).
- Mana-systemet (`mana`, `use_mana`, `restore_mana`, `mana_changed`) finns redan
  och återanvänds oförändrat.

## Felhantering

- `can_cast` returnerar `{ok: bool, reason: String}`; varje fel ger ett
  HUD-meddelande och avbryter utan att förbruka mana/runa/guld.
- Attack/area-spell utan något mål i träffområdet: mana och cooldown förbrukas
  ändå (du "missade") — matchar Tibia; men single-`target`-aim som inte landar på
  en varelse räknas som ogiltigt klick (ingen förbrukning).
- Conjure utan `blank_rune` eller mana: tydligt meddelande, ingen förbrukning.
- Out-of-range-klick i aim-läge: hint, siktet kvarstår.

## Testning (GUT)

Nya tester:
- `can_cast`-gating: blockerar vid för låg magic-nivå, för lite mana, aktiv
  cooldown.
- Conjure: förbrukar `blank_rune` + mana, lägger till rätt runa i `amount`.
- Inlärning: drar guld, lägger till spell i `learned_spells`, blockerar vid för
  låg nivå/för lite guld.
- AoE: ett spell med `radius` träffar flera monster runt målrutan.
- Magic-XP: casting höjer magic-XP enligt typ.
- Headless-boot förblir ren (inga parser-/load-fel).

## Berörda filer (översikt)

**Nya:** `autoload/spell_system.gd`, `entities/aim_controller.gd`,
`ui/spellbook_panel.gd`, `entities/spell_teacher_npc.gd` (+ `.tscn`),
`data/spells.json`, GUT-tester under `tests/`.

**Ändras:** `project.godot` (autoload SpellSystem, input-actions, toggle_spellbook),
`autoload/game_state.gd` (learned_spells), `autoload/save_manager.gd`
(persistens + migrering), `ui/hotkey_bar.gd` (spell-slots), `entities/player/player.gd`
(ta bort död rune-kod, casting-entrypoint), `data/items.json` (blank_rune,
AoE-runfält), `world/game.tscn` (AimController-nod), Thais-zon (placera teacher-NPC).
