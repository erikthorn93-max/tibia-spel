# Milstolpe 4 — Quests + röster: Designspec

**Datum:** 2026-06-12
**Status:** Godkänd av Erik
**Bygger på:** Masterspec §5 (Quests med AI-röster), milstolpe 1–3 (mergade till master)

## Mål

Dialogsystem med spelarval, questlogg, 5 nya röstade quests, idle barks och en
lokal TTS-pipeline (Piper). Allt på engelska. Spelbart slutresultat: spelaren
kan prata med NPC:er, ta emot och slutföra quests, och höra genererade röster.

## Beslut (från brainstorm)

| Fråga | Beslut |
|-------|--------|
| TTS-motor | **Piper** (lokal, gratis). Pipelinen API-agnostisk så ElevenLabs kan pluggas in per NPC senare. |
| Språk | **Engelska** — 100+ Piper-röster ger varje NPC en egen röst. |
| Questinnehåll | **5 nya quests** skrivna för befintliga 2D-världen. Portering av de 16 gamla questsen skjuts till innehållsvågorna (M7+). |
| Navigering | **Text-hints i questloggen.** Ingen minimap eller questmarkör i M4. |
| Dialogsystem | **Eget datadrivet system** (alternativ A). Inga addons (Dialogic m.fl. avvisade: egna filformat bryter JSON-principen och försvårar TTS-pipelinen). |

---

## 1. Datamodell — tre nya JSON-filer

### `data/npcs.json`
NPC-definitioner:

```json
"npc_blacksmith": {
  "name": "Brom the Blacksmith",
  "zone": "town",
  "position": [12, 8],
  "sprite": "blacksmith",
  "voice": {"model": "en_US-joe-medium", "pitch": 1.0, "speed": 1.0},
  "barks": ["Mind the sparks!", "Finest steel in town."],
  "dialogue_root": "blacksmith_start"
}
```

### `data/dialogue.json`
Dialogträd, plattade noder med id-referenser:

```json
"blacksmith_start": {
  "speaker": "npc_blacksmith",
  "text": "Ah, a new face! Need something forged?",
  "emotion": "friendly",
  "choices": [
    {"text": "Who are you?", "next": "blacksmith_intro"},
    {"text": "I found your missing ore.", "next": "blacksmith_thanks",
     "conditions": [{"type": "quest_step", "quest": "quest_lost_ore", "step": 1}],
     "actions": [{"type": "advance_quest", "quest": "quest_lost_ore"}]},
    {"text": "Goodbye.", "next": null}
  ]
}
```

- **Villkor** utvärderas mot GameState/QuestSystem/UnlockSystem:
  `quest_active`, `quest_step`, `quest_completed`, `has_item`, `skill_level`, `unlock`.
  Val vars villkor inte uppfylls visas inte.
- **Actions:** `start_quest`, `advance_quest`, `give_item`, `take_item`, `end`.
- **Röstfilens sökväg härleds** ur nod-id: `audio/voice/<npc_id>/<nod_id>.ogg`.
  Lagras inte i datat. Saknas filen visas bara text.

### `data/quests.json`
```json
"quest_lost_ore": {
  "name": "The Lost Ore",
  "giver": "npc_blacksmith",
  "requires": [],
  "steps": [
    {"type": "collect", "item": "iron_ore", "count": 3,
     "hint": "Mine 3 iron ore in the cave."},
    {"type": "talk_to", "npc": "npc_blacksmith",
     "hint": "Return to Brom the Blacksmith in town."}
  ],
  "rewards": {"xp": 500, "gold": 200, "items": {"steel_sword": 1}}
}
```
Objective-typer i M4: `kill`, `collect`, `talk_to`, `explore`, `use_item`.
Steg är **0-baserade**: `quest_step`-villkoret ovan matchar när steg 1
(återvänd till smeden) är aktivt.

---

## 2. QuestSystem-autoload

Ny autoload (`autoload/quest_system.gd`), samma mönster som TaskSystem:

- State: aktiva quests med stegindex + progress, klarade quests.
- API: `start(quest_id)`, `advance(quest_id)`, `record_kill(monster_id)`,
  `record_collect(item_id)`, `record_explore(zone_id)`, `is_active()`, `current_step()`.
- Signaler: `quest_started`, `step_advanced`, `quest_completed`.
- Lyssnar på samma kill-händelser som TaskSystem, inventory-ändringar (collect
  räknas mot aktuellt inventory), zonbyte (explore).
- Belöningar delas ut vid quest-slut via GameState/ItemDB.
- All logik GUT-testbar utan UI.

---

## 3. NPC-entitet + dialogruta

- **`entities/npc.gd` + `npc.tscn`** — generisk dialog-NPC. Klick + närhetskrav,
  samma interaktionsmönster som taskmaster-NPC:n. Spawnas från `data/npcs.json`
  per zon. Öppnar dialogrutan med sin `dialogue_root`.
- **`ui/dialogue_box.gd`** — talarnamn, textrad, valknappar (filtrerade på
  villkor), kör actions vid val. Spelar nodens .ogg om filen finns.
  ESC stänger (befintligt panelmönster).
- **Idle barks:** när spelaren kommer inom bark-radie slumpas en bark —
  flytande text ovanför NPC:n + ljud (`audio/voice/<npc_id>/bark_<n>.ogg`).
  Cooldown per NPC (~30 s) så det inte tjatar.

---

## 4. Questlogg

- **`ui/quest_log.gd`** på tangent **J** (ny input-action `toggle_quest_log`).
  Två sektioner: aktiva (namn + aktuellt stegs hint) och klarade.
- **HUD-rad** för senast startade aktiva quest, samma mönster som task-raden.
- Ingen minimap, inga questmarkörer (beslutat).

---

## 5. TTS-pipeline (separat verktyg)

```
data/dialogue.json + data/npcs.json
        │
tools/generate_voices.py      (lokal Piper via piper-tts)
        │
audio/voice/<npc_id>/<nod_id>.ogg  (+ bark_<n>.ogg)
```

- **Hash-manifest** (`tools/voice_manifest.json`): text+röstprofil hashas;
  bara nya/ändrade rader regenereras.
- **API-agnostisk:** liten backend-klass per motor (`PiperBackend` nu,
  `ElevenLabsBackend` senare). Röstprofilen i npcs.json väljer backend+röst.
- Körs manuellt av utvecklaren — aldrig av spelet. Spelet läser bara .ogg.
- Saknad fil = bara text, inget fel.

---

## 6. Innehåll — 5 quests, ~5 NPC:er

| # | Quest (arbetsnamn) | Typ | Knyter ihop |
|---|--------------------|-----|-------------|
| 1 | Welcome to Town | talk_to + explore | Intro: hitta runt, träffa NPC:erna |
| 2 | The Lost Ore | collect + talk_to | Mining → Smithing (M2) |
| 3 | Wolves at the Gates | kill | Skogen, stridsloopen (M1) |
| 4 | Into the Crypt | explore + use_item | Kryptan/mörka dungen (M3) |
| 5 | The Ghoul King's Shadow | kedja: kill + talk_to | Ghulkungen-bossen (M3), kräver quest 4 |

- 4–5 nya NPC:er med olika engelska Piper-röster + 2–3 barks var.
- Exakta dialogtexter skrivs i implementationsplanen.

---

## 7. Save v4 + teststrategi

- **Save v4:** questlägen (aktiva med stegprogress, klarade) in i sparfilen.
  Migrering v3→v4 enligt samma mönster som v2→v3 (tomma queststrukturer).
- **GUT-tester:** stegprogression per objective-typ, dialogvillkor och actions,
  belöningsutdelning, quest-förkrav, save-migrering v3→v4, dataintegritet
  (alla `next`/`npc`/`item`/`quest`-referenser i JSON pekar på existerande id:n).
- Boot-check utan skriptfel. Prestandabudget oförändrad: 60 FPS / 50 monster.

## Avgränsningar (YAGNI)

- Ingen minimap, inga questmarkörer.
- Inga porterade gamla quests (M7+).
- Ingen ElevenLabs-integration nu — bara backend-interfacet förbereds.
- Inga porträttbilder i dialogrutan — namn + text räcker i M4.
- Inga röstade spelarval (bara NPC-rader röstas).
