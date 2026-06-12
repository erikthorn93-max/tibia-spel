# Tibia2D Milstolpe 4 — Quests + röster: Implementationsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dialogsystem med spelarval, questlogg (J), 5 nya engelska quests, idle barks och en lokal Piper-TTS-pipeline — spelaren kan prata med NPC:er, driva quests och höra genererade röster.

**Architecture:** Två nya autoloads — `QuestSystem` (queststate, stegprogression, belöningar) och `DialogueDB` (dialogdata, villkor, actions). Kill-flödet återanvänds: `monster._die()` → `QuestSystem.record_kill()`. Explore via `World.start_game` (zon) och `player` (tile). All data i JSON; röstfiler genereras offline av `tools/generate_voices.py` och spelas bara upp om de finns.

**Tech Stack:** Godot 4.6.2 (`C:\Godot\Godot_v4.6.2-stable_win64.exe`), GDScript, GUT 9.6.0, Python 3 + piper-tts (+ ffmpeg om tillgängligt), JSON-data.

**Spec:** `docs/superpowers/specs/2026-06-12-milstolpe-4-quests-roster-design.md`

**Viktiga kommandon:**
```bash
# Tester (bash — PowerShell-redirect sväljer Godot-output):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
# Re-import (krävs efter nya scener/ljudfiler):
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
# Boot-check:
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

---

## Filstruktur

| Fil | Åtgärd | Ansvar |
|-----|--------|--------|
| `data/quests.json` | Skapa | 5 quests med steg + belöningar |
| `data/npcs.json` | Skapa | 5 NPC:er: zon, position, röstprofil, barks |
| `data/dialogue.json` | Skapa | Alla dialogträd (plattade noder) |
| `data/items.json` | Modifiera | +`warding_candle` (questitem, `usable`) |
| `autoload/quest_system.gd` | Skapa | Queststate, stegprogression, belöningar |
| `autoload/dialogue_db.gd` | Skapa | Dialogdata, villkorsutvärdering, actions |
| `autoload/save_manager.gd` | Modifiera | SAVE_VERSION 4 + quests i snapshot |
| `autoload/world.gd` | Modifiera | `record_explore` vid zonbyte; spawna dialog-NPC:er |
| `autoload/game_state.gd` | Modifiera | `usable`-items + `record_use`-hook |
| `entities/monster/monster.gd` | Modifiera | +`QuestSystem.record_kill` |
| `entities/player/player.gd` | Modifiera | +`record_position` vid tile-byte |
| `entities/npc.gd` + `npc.tscn` | Skapa | Dialog-NPC: klick → dialogruta; idle barks |
| `ui/dialogue_box.gd` | Skapa | Dialogruta: text, val, röstuppspelning |
| `ui/quest_log.gd` | Skapa | Questlogg (J): aktiva + klarade |
| `ui/hud.gd` + `hud.tscn` | Modifiera | QuestsLabel, `open_dialogue`, ESC, panelinstanser |
| `project.godot` | Modifiera | +2 autoloads, input `toggle_quest_log` (J) |
| `tools/generate_voices.py` | Skapa | Piper-pipeline med hash-manifest |
| `audio/voice/<npc>/<id>.ogg` | Genereras | Röstfiler (committas) |
| `tests/unit/test_quests_data.gd` | Skapa | Referensintegritet quests/dialogue/npcs |
| `tests/unit/test_quest_system.gd` | Skapa | Stegprogression, krav, belöningar |
| `tests/unit/test_dialogue.gd` | Skapa | Villkor, negation, actions |
| `tests/unit/test_save.gd` | Modifiera | +v3→v4-migrering + roundtrip |

**Konventioner:**
- Queststeg är **0-baserade**. `talk_to`-steg avanceras ENDAST via dialog-action `advance_quest`; `kill`/`collect`/`explore`/`use_item` avanceras automatiskt.
- `collect` mäter aktuellt inventory (inte ackumulerade plock); inlämning sker med dialog-action `take_item`.
- Röstfil per nod: `res://audio/voice/<npc_id>/<nod_id>.ogg` (eller `.wav`); barks: `bark_<index>`. Saknad fil ⇒ bara text.
- UI-etiketter på svenska (som övriga spelet); dialog, questnamn och hints på engelska (röstas/visas som innehåll).

---

### Task 0: Branch

- [ ] **Step 1: Skapa feature-branch**

```bash
cd /c/Users/Hem/tibia2d && git checkout -b m4-quests
```

---

### Task 1: Speldata — quests, NPC:er, dialog + valideringstest

**Files:**
- Create: `data/quests.json`, `data/npcs.json`, `data/dialogue.json`
- Modify: `data/items.json`
- Test: `tests/unit/test_quests_data.gd`

- [ ] **Step 1: Skriv valideringstestet (failar — datafilerna saknas)**

`tests/unit/test_quests_data.gd`:

```gdscript
extends GutTest
## Referensintegritet: quests ↔ dialogue ↔ npcs ↔ items ↔ monster ↔ zoner.

var quests: Dictionary
var npcs: Dictionary
var nodes: Dictionary

func before_all():
	quests = _load("res://data/quests.json")
	npcs = _load("res://data/npcs.json")
	nodes = _load("res://data/dialogue.json")

func _load(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

func test_data_files_exist():
	assert_false(quests.is_empty(), "quests.json saknas/tom")
	assert_false(npcs.is_empty(), "npcs.json saknas/tom")
	assert_false(nodes.is_empty(), "dialogue.json saknas/tom")

func test_quest_refs():
	for id in quests:
		var q: Dictionary = quests[id]
		assert_true(npcs.has(String(q["giver"])), "%s: okänd giver" % id)
		for req in q.get("requires", []):
			assert_true(quests.has(String(req)), "%s: okänt krav %s" % [id, req])
		for s in q["steps"]:
			assert_has(["kill", "collect", "talk_to", "explore", "use_item"], String(s["type"]), "%s: okänd stegtyp" % id)
			assert_true(s.has("hint"), "%s: steg saknar hint" % id)
			match String(s["type"]):
				"kill":
					assert_true(MonsterDB.monsters.has(String(s["monster"])), "%s: okänt monster" % id)
				"collect", "use_item":
					assert_true(ItemDB.items.has(String(s["item"])), "%s: okänt item" % id)
				"talk_to":
					assert_true(npcs.has(String(s["npc"])), "%s: okänd npc" % id)
				"explore":
					assert_true(FileAccess.file_exists("res://data/zones/%s.json" % s["zone"]), "%s: okänd zon" % id)
		for item_id in q.get("rewards", {}).get("items", {}):
			assert_true(ItemDB.items.has(String(item_id)), "%s: okänt belöningsitem" % id)

func test_npc_refs():
	for id in npcs:
		var n: Dictionary = npcs[id]
		assert_true(nodes.has(String(n["dialogue_root"])), "%s: okänd dialogue_root" % id)
		assert_true(FileAccess.file_exists("res://data/zones/%s.json" % n["zone"]), "%s: okänd zon" % id)
		assert_true(n.has("voice"), "%s: saknar röstprofil" % id)
		assert_true(n.has("position"), "%s: saknar position" % id)

func test_dialogue_refs():
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		assert_true(npcs.has(String(n["speaker"])), "%s: okänd speaker" % nid)
		for c in n.get("choices", []):
			if c.get("next") != null:
				assert_true(nodes.has(String(c["next"])), "%s: okänd next %s" % [nid, c["next"]])
			for cond in c.get("conditions", []):
				if cond.has("quest"):
					assert_true(quests.has(String(cond["quest"])), "%s: villkor mot okänd quest" % nid)
				if cond.has("item"):
					assert_true(ItemDB.items.has(String(cond["item"])), "%s: villkor mot okänt item" % nid)
			for a in c.get("actions", []):
				if a.has("quest"):
					assert_true(quests.has(String(a["quest"])), "%s: action mot okänd quest" % nid)
				if a.has("item"):
					assert_true(ItemDB.items.has(String(a["item"])), "%s: action mot okänt item" % nid)

func test_every_quest_startable_via_dialogue():
	var started := {}
	for nid in nodes:
		for c in nodes[nid].get("choices", []):
			for a in c.get("actions", []):
				if String(a.get("type", "")) == "start_quest":
					started[String(a["quest"])] = true
	for id in quests:
		assert_true(started.has(id), "%s startas aldrig i någon dialog" % id)
```

- [ ] **Step 2: Kör testet — förvänta FAIL**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_quests_data -gexit 2>&1 | tail -15
```
Förväntat: FAIL i `test_data_files_exist` ("quests.json saknas/tom").

- [ ] **Step 3: Lägg till `warding_candle` i `data/items.json`**

Lägg till efter `boss_crown`-posten (behåll JSON-kommatecken korrekt):

```json
"warding_candle": {"name": "Warding Candle", "type": "quest", "value": 0, "usable": true}
```

- [ ] **Step 4: Skapa `data/quests.json`**

Kryptan-måltilen `[20, 29]` ligger i mittkammaren i `cave.json` (bakom gaten `kryptan` på rad 27, x=23).

```json
{
	"quest_welcome": {
		"name": "Welcome to Town",
		"giver": "npc_elder",
		"requires": [],
		"steps": [
			{"type": "talk_to", "npc": "npc_blacksmith", "hint": "Introduce yourself to Brom the Blacksmith in town."},
			{"type": "explore", "zone": "forest", "hint": "Take a walk through the old forest."},
			{"type": "talk_to", "npc": "npc_elder", "hint": "Report back to Elder Rowan."}
		],
		"rewards": {"xp": 200, "gold": 100}
	},
	"quest_lost_ore": {
		"name": "The Lost Ore",
		"giver": "npc_blacksmith",
		"requires": ["quest_welcome"],
		"steps": [
			{"type": "collect", "item": "iron_ore", "count": 3, "hint": "Mine 3 iron ore in the cave."},
			{"type": "talk_to", "npc": "npc_blacksmith", "hint": "Bring the ore back to Brom."}
		],
		"rewards": {"xp": 500, "gold": 200, "items": {"steel_sword": 1}}
	},
	"quest_snakes": {
		"name": "Serpents in the Grass",
		"giver": "npc_hunter",
		"requires": [],
		"steps": [
			{"type": "kill", "monster": "Orm", "count": 8, "hint": "Cull 8 snakes in the forest."},
			{"type": "talk_to", "npc": "npc_hunter", "hint": "Return to Sylva the Huntress."}
		],
		"rewards": {"xp": 800, "gold": 300}
	},
	"quest_crypt": {
		"name": "Into the Crypt",
		"giver": "npc_scholar",
		"requires": ["quest_welcome"],
		"steps": [
			{"type": "explore", "zone": "cave", "tile": [20, 29], "radius": 3, "hint": "Find the old crypt behind the cave's south passage."},
			{"type": "use_item", "item": "warding_candle", "hint": "Light the warding candle inside the crypt."},
			{"type": "talk_to", "npc": "npc_scholar", "hint": "Tell Maelis what you saw."}
		],
		"rewards": {"xp": 1200, "gold": 400}
	},
	"quest_ghoul_king": {
		"name": "The Ghoul King's Shadow",
		"giver": "npc_scholar",
		"requires": ["quest_crypt"],
		"steps": [
			{"type": "kill", "monster": "Ghulkungen", "count": 1, "hint": "Slay the Ghoul King in his lair. (Finish the ghoul and phantom slayer tasks to open it.)"},
			{"type": "talk_to", "npc": "npc_scholar", "hint": "Bring word of your victory to Maelis."}
		],
		"rewards": {"xp": 3000, "gold": 1500}
	}
}
```

- [ ] **Step 5: Skapa `data/npcs.json`**

Positionerna är verifierat gångbara tiles i respektive zon (town 40×24, forest 40×28).

```json
{
	"npc_elder": {
		"name": "Elder Rowan",
		"zone": "town",
		"position": [10, 7],
		"voice": {"model": "en_GB-alan-medium", "length_scale": 1.1},
		"barks": ["Fine weather for the harvest.", "Stay out of trouble, now."],
		"dialogue_root": "elder_root"
	},
	"npc_blacksmith": {
		"name": "Brom the Blacksmith",
		"zone": "town",
		"position": [3, 15],
		"voice": {"model": "en_US-joe-medium", "length_scale": 1.0},
		"barks": ["Mind the sparks!", "Finest steel in town."],
		"dialogue_root": "blacksmith_root"
	},
	"npc_scholar": {
		"name": "Maelis the Scholar",
		"zone": "town",
		"position": [10, 10],
		"voice": {"model": "en_US-lessac-medium", "length_scale": 1.0},
		"barks": ["So many secrets...", "The old texts never lie. Mostly."],
		"dialogue_root": "scholar_root"
	},
	"npc_fisherman": {
		"name": "Old Finn",
		"zone": "town",
		"position": [24, 7],
		"voice": {"model": "en_GB-northern_english_male-medium", "length_scale": 1.15},
		"barks": ["Nibble... no, nothing.", "The big one got away again."],
		"dialogue_root": "finn_root"
	},
	"npc_hunter": {
		"name": "Sylva the Huntress",
		"zone": "forest",
		"position": [16, 19],
		"voice": {"model": "en_US-amy-medium", "length_scale": 0.95},
		"barks": ["Tread softly.", "Something's moving in the brush..."],
		"dialogue_root": "hunter_root"
	}
}
```

- [ ] **Step 6: Skapa `data/dialogue.json`**

```json
{
	"elder_root": {
		"speaker": "npc_elder", "emotion": "friendly",
		"text": "Welcome, stranger. Our little town could use a helping hand.",
		"choices": [
			{"text": "Who are you?", "next": "elder_who"},
			{"text": "Is there anything I can do?", "next": "elder_offer",
			 "conditions": [{"type": "quest_available", "quest": "quest_welcome"}]},
			{"text": "I've seen the forest, as you asked.", "next": "elder_thanks",
			 "conditions": [{"type": "quest_step", "quest": "quest_welcome", "step": 2}],
			 "actions": [{"type": "advance_quest", "quest": "quest_welcome"}]},
			{"text": "Goodbye.", "next": null}
		]
	},
	"elder_who": {
		"speaker": "npc_elder", "emotion": "neutral",
		"text": "I am Rowan, elder of this town. I have watched over it for forty years.",
		"choices": [
			{"text": "Back.", "next": "elder_root"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"elder_offer": {
		"speaker": "npc_elder", "emotion": "friendly",
		"text": "Get to know the place. Meet Brom at the forge, and take a look at the old forest north of here.",
		"choices": [
			{"text": "I'll do that.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_welcome"}]},
			{"text": "Maybe later.", "next": null}
		]
	},
	"elder_thanks": {
		"speaker": "npc_elder", "emotion": "friendly",
		"text": "Good. You'll do fine here. Take this for your trouble.",
		"choices": [
			{"text": "Thank you.", "next": null}
		]
	},
	"blacksmith_root": {
		"speaker": "npc_blacksmith", "emotion": "friendly",
		"text": "Ah, a new face! Need something forged?",
		"choices": [
			{"text": "Rowan sent me to introduce myself.", "next": "blacksmith_welcome",
			 "conditions": [{"type": "quest_step", "quest": "quest_welcome", "step": 0}],
			 "actions": [{"type": "advance_quest", "quest": "quest_welcome"}]},
			{"text": "Need any help?", "next": "blacksmith_offer",
			 "conditions": [{"type": "quest_available", "quest": "quest_lost_ore"}]},
			{"text": "I have your iron ore.", "next": "blacksmith_thanks",
			 "conditions": [{"type": "quest_step", "quest": "quest_lost_ore", "step": 1},
			                {"type": "has_item", "item": "iron_ore", "count": 3}],
			 "actions": [{"type": "take_item", "item": "iron_ore", "count": 3},
			             {"type": "advance_quest", "quest": "quest_lost_ore"}]},
			{"text": "Who are you?", "next": "blacksmith_who"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"blacksmith_who": {
		"speaker": "npc_blacksmith", "emotion": "neutral",
		"text": "Brom. Best smith in town. Only smith, too.",
		"choices": [
			{"text": "Back.", "next": "blacksmith_root"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"blacksmith_welcome": {
		"speaker": "npc_blacksmith", "emotion": "friendly",
		"text": "Rowan's taken a liking to you, eh? Good. Come back once you've seen the forest.",
		"choices": [
			{"text": "Goodbye.", "next": null}
		]
	},
	"blacksmith_offer": {
		"speaker": "npc_blacksmith", "emotion": "neutral",
		"text": "My ore shipment never arrived. Bring me three iron ore from the cave and I'll make it worth your while.",
		"choices": [
			{"text": "Consider it done.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_lost_ore"}]},
			{"text": "Not right now.", "next": null}
		]
	},
	"blacksmith_thanks": {
		"speaker": "npc_blacksmith", "emotion": "friendly",
		"text": "Fine ore! Here, a steel sword, forged while you wait. Well, almost.",
		"choices": [
			{"text": "Thank you.", "next": null}
		]
	},
	"scholar_root": {
		"speaker": "npc_scholar", "emotion": "neutral",
		"text": "Fascinating ruins in that cave. Simply fascinating...",
		"choices": [
			{"text": "What do you study?", "next": "scholar_who"},
			{"text": "Need help with your research?", "next": "scholar_offer",
			 "conditions": [{"type": "quest_available", "quest": "quest_crypt"}]},
			{"text": "I lost the candle you gave me.", "next": "scholar_candle",
			 "conditions": [{"type": "quest_step", "quest": "quest_crypt", "step": 1},
			                {"type": "has_item", "item": "warding_candle", "not": true}],
			 "actions": [{"type": "give_item", "item": "warding_candle", "count": 1}]},
			{"text": "I lit the candle in the crypt.", "next": "scholar_crypt_done",
			 "conditions": [{"type": "quest_step", "quest": "quest_crypt", "step": 2}],
			 "actions": [{"type": "advance_quest", "quest": "quest_crypt"}]},
			{"text": "Is there more to be done?", "next": "scholar_offer2",
			 "conditions": [{"type": "quest_available", "quest": "quest_ghoul_king"}]},
			{"text": "The Ghoul King is dead.", "next": "scholar_king_done",
			 "conditions": [{"type": "quest_step", "quest": "quest_ghoul_king", "step": 1}],
			 "actions": [{"type": "advance_quest", "quest": "quest_ghoul_king"}]},
			{"text": "Goodbye.", "next": null}
		]
	},
	"scholar_who": {
		"speaker": "npc_scholar", "emotion": "neutral",
		"text": "Maelis. I study the old crypt beneath the cave. Or I would, if it weren't crawling with the dead.",
		"choices": [
			{"text": "Back.", "next": "scholar_root"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"scholar_offer": {
		"speaker": "npc_scholar", "emotion": "neutral",
		"text": "Take this warding candle to the crypt behind the cave's south passage, and light it there. It should reveal whatever lingers.",
		"choices": [
			{"text": "I'll light it.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_crypt"},
			             {"type": "give_item", "item": "warding_candle", "count": 1}]},
			{"text": "Sounds dangerous. Maybe later.", "next": null}
		]
	},
	"scholar_candle": {
		"speaker": "npc_scholar", "emotion": "annoyed",
		"text": "Careless! Here is another. Do be careful with this one.",
		"choices": [
			{"text": "Thank you.", "next": null}
		]
	},
	"scholar_crypt_done": {
		"speaker": "npc_scholar", "emotion": "worried",
		"text": "A shadow, you say? Then it is as I feared. The Ghoul King stirs. We are not done, you and I.",
		"choices": [
			{"text": "I'll be ready.", "next": null}
		]
	},
	"scholar_offer2": {
		"speaker": "npc_scholar", "emotion": "worried",
		"text": "The candle revealed his shadow. The Ghoul King must be destroyed. Finish the slayer tasks to open his lair, then end him.",
		"choices": [
			{"text": "He's as good as dead.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_ghoul_king"}]},
			{"text": "I need to prepare.", "next": null}
		]
	},
	"scholar_king_done": {
		"speaker": "npc_scholar", "emotion": "friendly",
		"text": "Then it is over. The crypt can finally rest. And so can I. You have my deepest thanks.",
		"choices": [
			{"text": "Farewell, Maelis.", "next": null}
		]
	},
	"hunter_root": {
		"speaker": "npc_hunter", "emotion": "neutral",
		"text": "Quiet... you'll scare the game.",
		"choices": [
			{"text": "Who are you?", "next": "hunter_who"},
			{"text": "Need a hand with anything?", "next": "hunter_offer",
			 "conditions": [{"type": "quest_available", "quest": "quest_snakes"}]},
			{"text": "The snakes are dealt with.", "next": "hunter_thanks",
			 "conditions": [{"type": "quest_step", "quest": "quest_snakes", "step": 1}],
			 "actions": [{"type": "advance_quest", "quest": "quest_snakes"}]},
			{"text": "Goodbye.", "next": null}
		]
	},
	"hunter_who": {
		"speaker": "npc_hunter", "emotion": "neutral",
		"text": "Sylva. I hunt these woods. The snakes have grown bold lately.",
		"choices": [
			{"text": "Back.", "next": "hunter_root"},
			{"text": "Goodbye.", "next": null}
		]
	},
	"hunter_offer": {
		"speaker": "npc_hunter", "emotion": "neutral",
		"text": "Snakes everywhere this season. Cull eight of them and the forest paths will be safe again.",
		"choices": [
			{"text": "I'm on it.", "next": null,
			 "actions": [{"type": "start_quest", "quest": "quest_snakes"}]},
			{"text": "Not my problem.", "next": null}
		]
	},
	"hunter_thanks": {
		"speaker": "npc_hunter", "emotion": "friendly",
		"text": "Well done. The paths are safer already. Here, your share of the bounty.",
		"choices": [
			{"text": "Thank you.", "next": null}
		]
	},
	"finn_root": {
		"speaker": "npc_fisherman", "emotion": "neutral",
		"text": "The fish aren't biting today. They never are.",
		"choices": [
			{"text": "Good luck, old man.", "next": null}
		]
	}
}
```

- [ ] **Step 7: Kör valideringstestet — förvänta PASS**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_quests_data -gexit 2>&1 | tail -8
```
Förväntat: alla tester gröna.

- [ ] **Step 8: Commit**

```bash
git add data/quests.json data/npcs.json data/dialogue.json data/items.json tests/unit/test_quests_data.gd
git commit -m "feat: questdata — 5 quests, 5 NPC:er, dialogträd + warding_candle (data + integritetstest)"
```

---

### Task 2: QuestSystem-autoload

**Files:**
- Create: `autoload/quest_system.gd`
- Modify: `project.godot` (autoload-sektionen)
- Test: `tests/unit/test_quest_system.gd`

- [ ] **Step 1: Registrera autoload i `project.godot`**

Lägg till i `[autoload]`-sektionen efter `TaskSystem`-raden (ordningen spelar roll — före `World`):

```ini
QuestSystem="*res://autoload/quest_system.gd"
DialogueDB="*res://autoload/dialogue_db.gd"
```

(DialogueDB-filen skapas i Task 3 — skapa en tom platshållare nu så projektet bootar:)

```gdscript
extends Node
## Autoload: DialogueDB. Fylls i Task 3.
```

- [ ] **Step 2: Skriv failande tester**

`tests/unit/test_quest_system.gd`:

```gdscript
extends GutTest

var qs

func before_each():
	qs = add_child_autofree(load("res://autoload/quest_system.gd").new())
	GameState.gold = 0
	GameState.inventory.clear()

func test_start_unknown_fails():
	assert_false(qs.start("quest_drake"))

func test_start_and_signal():
	watch_signals(qs)
	assert_true(qs.start("quest_welcome"))
	assert_signal_emitted_with_parameters(qs, "quest_started", ["quest_welcome"])
	assert_eq(int(qs.active["quest_welcome"]["step"]), 0)

func test_start_twice_fails():
	qs.start("quest_welcome")
	assert_false(qs.start("quest_welcome"))

func test_requires_gate():
	assert_false(qs.start("quest_lost_ore"))   # kräver quest_welcome
	qs.completed["quest_welcome"] = true
	assert_true(qs.start("quest_lost_ore"))

func test_kill_progress_and_advance():
	qs.start("quest_snakes")
	for i in 8:
		qs.record_kill("Orm")
	assert_eq(int(qs.active["quest_snakes"]["step"]), 1)   # vidare till talk_to

func test_kill_wrong_monster_ignored():
	qs.start("quest_snakes")
	qs.record_kill("Råtta")
	assert_eq(int(qs.active["quest_snakes"]["progress"]), 0)

func test_collect_advances_via_inventory():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)   # inventory_changed → _check_collect
	assert_eq(int(qs.active["quest_lost_ore"]["step"]), 1)

func test_collect_partial_progress():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 2)
	assert_eq(int(qs.active["quest_lost_ore"]["step"]), 0)
	assert_eq(int(qs.active["quest_lost_ore"]["progress"]), 2)

func test_talk_advance_requires_npc_match():
	qs.start("quest_welcome")
	assert_false(qs.advance_talk("quest_welcome", "npc_elder"))      # steg 0 är Brom
	assert_true(qs.advance_talk("quest_welcome", "npc_blacksmith"))
	assert_eq(int(qs.active["quest_welcome"]["step"]), 1)

func test_explore_zone():
	qs.start("quest_welcome")
	qs.advance_talk("quest_welcome", "npc_blacksmith")
	qs.record_explore("forest")
	assert_eq(int(qs.active["quest_welcome"]["step"]), 2)

func test_explore_tile_radius():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(0, 0))
	assert_eq(int(qs.active["quest_crypt"]["step"]), 0)    # för långt bort
	qs.record_position("cave", Vector2i(21, 28))           # inom radie 3 från [20,29]
	assert_eq(int(qs.active["quest_crypt"]["step"]), 1)

func test_use_item_step():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(20, 29))
	qs.record_use("warding_candle")
	assert_eq(int(qs.active["quest_crypt"]["step"]), 2)

func test_use_item_wrong_step_ignored():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_use("warding_candle")    # steg 0 är explore
	assert_eq(int(qs.active["quest_crypt"]["step"]), 0)

func test_completion_rewards_gold():
	qs.start("quest_snakes")
	for i in 8:
		qs.record_kill("Orm")
	watch_signals(qs)
	assert_true(qs.advance_talk("quest_snakes", "npc_hunter"))
	assert_signal_emitted_with_parameters(qs, "quest_completed", ["quest_snakes"])
	assert_false(qs.active.has("quest_snakes"))
	assert_true(qs.completed.has("quest_snakes"))
	assert_eq(GameState.gold, 300)

func test_completion_item_reward():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)
	qs.advance_talk("quest_lost_ore", "npc_blacksmith")
	assert_eq(int(GameState.inventory.get("steel_sword", 0)), 1)

func test_hint_follows_step():
	qs.start("quest_welcome")
	assert_string_contains(qs.hint("quest_welcome"), "Brom")
	qs.advance_talk("quest_welcome", "npc_blacksmith")
	assert_string_contains(qs.hint("quest_welcome"), "forest")
```

- [ ] **Step 3: Kör — förvänta FAIL (filen saknas)**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_quest_system -gexit 2>&1 | tail -8
```

- [ ] **Step 4: Implementera `autoload/quest_system.gd`**

```gdscript
extends Node
## Autoload: QuestSystem. Äger queststate: start, stegprogression, belöningar.
## talk_to avanceras ENDAST via advance_talk (dialog-action); övriga stegtyper automatiskt.

signal quest_started(id: String)
signal quest_progress(id: String)
signal step_advanced(id: String)
signal quest_completed(id: String)

var quests: Dictionary = {}     # quest_id -> def (data/quests.json)
var active: Dictionary = {}     # quest_id -> {"step": int, "progress": int}
var completed: Dictionary = {}  # quest_id -> true

func _init() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	quests = parsed if parsed is Dictionary else {}

func _ready() -> void:
	GameState.inventory_changed.connect(_check_collect)

func can_start(id: String) -> bool:
	if not quests.has(id) or active.has(id) or completed.has(id):
		return false
	for req in quests[id].get("requires", []):
		if not completed.has(String(req)):
			return false
	return true

func start(id: String) -> bool:
	if not can_start(id):
		return false
	active[id] = {"step": 0, "progress": 0}
	quest_started.emit(id)
	_check_collect()   # collect-steg kan redan vara uppfyllt
	return true

func current_step(id: String) -> Dictionary:
	if not active.has(id):
		return {}
	return quests[id]["steps"][int(active[id]["step"])]

func hint(id: String) -> String:
	return String(current_step(id).get("hint", ""))

func record_kill(monster_name: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "kill" and String(s["monster"]) == monster_name:
			active[id]["progress"] = int(active[id]["progress"]) + 1
			if int(active[id]["progress"]) >= int(s["count"]):
				_advance(id)
			else:
				quest_progress.emit(id)

func record_explore(zone_id: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "explore" and String(s["zone"]) == zone_id and not s.has("tile"):
			_advance(id)

func record_position(zone_id: String, t: Vector2i) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "explore" and String(s["zone"]) == zone_id and s.has("tile"):
			var target := Vector2i(int(s["tile"][0]), int(s["tile"][1]))
			if maxi(absi(t.x - target.x), absi(t.y - target.y)) <= int(s.get("radius", 0)):
				_advance(id)

func record_use(item_id: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "use_item" and String(s["item"]) == item_id:
			_advance(id)

func advance_talk(id: String, npc_id: String) -> bool:
	var s := current_step(id)
	if s.get("type") == "talk_to" and String(s["npc"]) == npc_id:
		_advance(id)
		return true
	return false

func _check_collect() -> void:
	for id in active.keys():
		if not active.has(id):   # kan ha avancerat/slutförts under loopen
			continue
		var s := current_step(id)
		if s.get("type") != "collect":
			continue
		var have := mini(int(GameState.inventory.get(String(s["item"]), 0)), int(s["count"]))
		if have >= int(s["count"]):
			_advance(id)
		elif have != int(active[id]["progress"]):
			active[id]["progress"] = have
			quest_progress.emit(id)

func _advance(id: String) -> void:
	var steps: Array = quests[id]["steps"]
	var next := int(active[id]["step"]) + 1
	if next >= steps.size():
		_complete(id)
		return
	active[id] = {"step": next, "progress": 0}
	step_advanced.emit(id)
	_check_collect()   # nästa steg kan redan vara uppfyllt

func _complete(id: String) -> void:
	var r: Dictionary = quests[id].get("rewards", {})
	GameState.gain_exp(int(r.get("xp", 0)))
	if r.has("gold"):
		GameState.add_item("iron_coin", int(r["gold"]))
	for item_id in r.get("items", {}):
		GameState.add_item(String(item_id), int(r["items"][item_id]))
	active.erase(id)
	completed[id] = true
	quest_completed.emit(id)

func reset() -> void:
	active.clear()
	completed.clear()
```

OBS: efter JSON-laddning av sparfil är `step`/`progress` floats — därför `int()`-casts vid varje läsning (samma mönster som TaskSystem).

- [ ] **Step 5: Kör — förvänta PASS**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_quest_system -gexit 2>&1 | tail -8
```

- [ ] **Step 6: Commit**

```bash
git add autoload/quest_system.gd autoload/dialogue_db.gd project.godot tests/unit/test_quest_system.gd
git commit -m "feat: QuestSystem-autoload — stegprogression (kill/collect/explore/use/talk), krav, belöningar (TDD)"
```

---

### Task 3: DialogueDB-autoload — villkor och actions

**Files:**
- Modify: `autoload/dialogue_db.gd` (ersätt platshållaren från Task 2)
- Test: `tests/unit/test_dialogue.gd`

- [ ] **Step 1: Skriv failande tester**

`tests/unit/test_dialogue.gd`:

```gdscript
extends GutTest
## Använder de RIKTIGA autoloadsen QuestSystem/DialogueDB — reset i before_each.

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0

func _texts(node_id: String) -> Array:
	return DialogueDB.visible_choices(node_id).map(func(c): return String(c["text"]))

func test_loads_data():
	assert_false(DialogueDB.npcs.is_empty())
	assert_false(DialogueDB.nodes.is_empty())

func test_unconditioned_choices_visible():
	assert_has(_texts("blacksmith_root"), "Who are you?")
	assert_has(_texts("blacksmith_root"), "Goodbye.")

func test_quest_step_choice_hidden_by_default():
	assert_does_not_have(_texts("blacksmith_root"), "I have your iron ore.")

func test_quest_available_condition():
	assert_does_not_have(_texts("blacksmith_root"), "Need any help?")   # kräver quest_welcome klar
	QuestSystem.completed["quest_welcome"] = true
	assert_has(_texts("blacksmith_root"), "Need any help?")

func test_quest_step_and_has_item():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_lost_ore")
	assert_does_not_have(_texts("blacksmith_root"), "I have your iron ore.")
	GameState.add_item("iron_ore", 3)   # collect-steget avancerar till steg 1
	assert_has(_texts("blacksmith_root"), "I have your iron ore.")

func test_not_negation_on_has_item():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_crypt")
	QuestSystem.active["quest_crypt"]["step"] = 1   # simulera: framme vid kryptan, ljuset tappat
	assert_has(_texts("scholar_root"), "I lost the candle you gave me.")
	GameState.add_item("warding_candle", 1)
	assert_does_not_have(_texts("scholar_root"), "I lost the candle you gave me.")

func test_run_actions_start_and_give():
	QuestSystem.completed["quest_welcome"] = true
	DialogueDB.run_actions([
		{"type": "start_quest", "quest": "quest_crypt"},
		{"type": "give_item", "item": "warding_candle", "count": 1}
	], "npc_scholar")
	assert_true(QuestSystem.active.has("quest_crypt"))
	assert_eq(int(GameState.inventory.get("warding_candle", 0)), 1)

func test_run_actions_take_and_advance_completes():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)    # → steg 1 (talk_to)
	DialogueDB.run_actions([
		{"type": "take_item", "item": "iron_ore", "count": 3},
		{"type": "advance_quest", "quest": "quest_lost_ore"}
	], "npc_blacksmith")
	assert_true(QuestSystem.completed.has("quest_lost_ore"))
	assert_eq(int(GameState.inventory.get("iron_ore", 0)), 0)
```

- [ ] **Step 2: Kör — förvänta FAIL**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_dialogue -gexit 2>&1 | tail -8
```

- [ ] **Step 3: Implementera `autoload/dialogue_db.gd` (ersätt hela platshållaren)**

```gdscript
extends Node
## Autoload: DialogueDB. Laddar dialogue.json + npcs.json,
## utvärderar val-villkor och kör dialog-actions. UI:t renderar bara.

var npcs: Dictionary = {}
var nodes: Dictionary = {}

func _init() -> void:
	npcs = _load_json("res://data/npcs.json")
	nodes = _load_json("res://data/dialogue.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

func visible_choices(node_id: String) -> Array:
	var out: Array = []
	for c in nodes.get(node_id, {}).get("choices", []):
		if _conditions_met(c.get("conditions", [])):
			out.append(c)
	return out

func _conditions_met(conds: Array) -> bool:
	for c in conds:
		if not eval_condition(c):
			return false
	return true

func eval_condition(c: Dictionary) -> bool:
	var ok := false
	match String(c["type"]):
		"quest_available":
			ok = QuestSystem.can_start(String(c["quest"]))
		"quest_active":
			ok = QuestSystem.active.has(String(c["quest"]))
		"quest_step":
			ok = QuestSystem.active.has(String(c["quest"])) \
				and int(QuestSystem.active[String(c["quest"])]["step"]) == int(c["step"])
		"quest_completed":
			ok = QuestSystem.completed.has(String(c["quest"]))
		"has_item":
			ok = int(GameState.inventory.get(String(c["item"]), 0)) >= int(c.get("count", 1))
		"skill_level":
			ok = GameState.effective_skill_level(String(c["skill"])) >= int(c["level"])
		"unlock":
			ok = UnlockSystem.is_unlocked(String(c["id"]))
	return not ok if bool(c.get("not", false)) else ok

func run_actions(actions: Array, npc_id: String) -> void:
	for a in actions:
		match String(a["type"]):
			"start_quest":
				QuestSystem.start(String(a["quest"]))
			"advance_quest":
				QuestSystem.advance_talk(String(a["quest"]), npc_id)
			"give_item":
				GameState.add_item(String(a["item"]), int(a.get("count", 1)))
			"take_item":
				GameState.remove_item(String(a["item"]), int(a.get("count", 1)))
```

- [ ] **Step 4: Kör — förvänta PASS**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_dialogue -gexit 2>&1 | tail -8
```

- [ ] **Step 5: Commit**

```bash
git add autoload/dialogue_db.gd tests/unit/test_dialogue.gd
git commit -m "feat: DialogueDB-autoload — villkorsutvärdering (inkl not-negation) och dialog-actions (TDD)"
```

---

### Task 4: Spelhooks — kill, explore, position, use_item

**Files:**
- Modify: `entities/monster/monster.gd` (~rad 114), `autoload/world.gd` (~rad 22), `entities/player/player.gd` (rad 31 och 65), `autoload/game_state.gd` (`use_item`), `ui/hud.gd` (`_refresh_inv`)

- [ ] **Step 1: monster.gd — questkills**

Efter raden `TaskSystem.record_kill(monster_name)` i `_die()`:

```gdscript
	QuestSystem.record_kill(monster_name)
```

- [ ] **Step 2: world.gd — explore vid zonbyte**

I `start_game()`, direkt efter `GameState.current_zone = zone_id`:

```gdscript
	QuestSystem.record_explore(zone_id)
```

- [ ] **Step 3: player.gd — position vid tile-byte**

I `snap_to()` efter `GameState.player_tile = t`:

```gdscript
	QuestSystem.record_position(GameState.current_zone, t)
```

I `_physics_process` (rad ~65) efter `GameState.player_tile = tile`:

```gdscript
			QuestSystem.record_position(GameState.current_zone, tile)
```

- [ ] **Step 4: game_state.gd — usable-items + record_use**

I `use_item()`, efter `if d.has("buff"):`-blocket och före `if used:`:

```gdscript
	if d.get("usable", false):
		used = true
```

och ändra slutet av funktionen:

```gdscript
	if used:
		remove_item(item_id, 1)
		QuestSystem.record_use(item_id)
	return used
```

- [ ] **Step 5: hud.gd — "Använd"-knapp för usable-items**

I `_refresh_inv()`, ändra villkorsraden:

```gdscript
			elif d.has("heal") or d.has("mana") or d.has("buff") or d.get("usable", false):
```

- [ ] **Step 6: Lägg till hook-test i `tests/unit/test_quest_system.gd`**

```gdscript
func test_use_item_via_gamestate_consumes_and_records():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(20, 29))   # → steg 1 (use_item)
	GameState.add_item("warding_candle", 1)
	# OBS: GameState.use_item anropar det GLOBALA QuestSystem — flytta state dit
	QuestSystem.reset()
	QuestSystem.active["quest_crypt"] = {"step": 1, "progress": 0}
	assert_true(GameState.use_item("warding_candle"))
	assert_eq(int(GameState.inventory.get("warding_candle", 0)), 0)
	assert_eq(int(QuestSystem.active["quest_crypt"]["step"]), 2)
	QuestSystem.reset()
```

- [ ] **Step 7: Kör hela sviten + boot-check — förvänta PASS / inga skriptfel**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

- [ ] **Step 8: Commit**

```bash
git add entities/monster/monster.gd autoload/world.gd entities/player/player.gd autoload/game_state.gd ui/hud.gd tests/unit/test_quest_system.gd
git commit -m "feat: questhooks — kill/explore/position/use_item kopplade till QuestSystem"
```

---

### Task 5: Save v4

**Files:**
- Modify: `autoload/save_manager.gd`
- Test: `tests/unit/test_save.gd`

- [ ] **Step 1: Skriv failande tester (lägg till i befintliga `test_save.gd`, följ filens befintliga setup/teardown med temporär save_path)**

```gdscript
func test_v3_save_migrates_to_v4_empty_quests():
	# v3-snapshot saknar quests-fälten helt
	var snap := SaveManager.read_snapshot()
	QuestSystem.active["quest_welcome"] = {"step": 1, "progress": 0}
	QuestSystem.completed["quest_snakes"] = true
	SaveManager.save_game()
	var s := SaveManager.read_snapshot()
	s.erase("quests_active")
	s.erase("quests_completed")
	s["version"] = 3
	SaveManager.write_snapshot(s)
	assert_true(SaveManager.load_game())
	assert_eq(QuestSystem.active.size(), 0)
	assert_eq(QuestSystem.completed.size(), 0)

func test_v4_roundtrip_quests():
	QuestSystem.reset()
	QuestSystem.active["quest_welcome"] = {"step": 1, "progress": 0}
	QuestSystem.completed["quest_snakes"] = true
	SaveManager.save_game()
	QuestSystem.reset()
	assert_true(SaveManager.load_game())
	assert_true(QuestSystem.active.has("quest_welcome"))
	assert_eq(int(QuestSystem.active["quest_welcome"]["step"]), 1)
	assert_true(QuestSystem.completed.has("quest_snakes"))
	QuestSystem.reset()
```

- [ ] **Step 2: Kör — förvänta FAIL (fälten sparas inte ännu)**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_save -gexit 2>&1 | tail -8
```

- [ ] **Step 3: Implementera i `save_manager.gd`**

Ändra `const SAVE_VERSION := 3` → `const SAVE_VERSION := 4`.

I `save_game()`-dicten, efter `"unlocked": UnlockSystem.unlocked,`:

```gdscript
		"quests_active": QuestSystem.active,
		"quests_completed": QuestSystem.completed,
```

I `load_game()`, efter `UnlockSystem.unlocked = s.get("unlocked", {})`:

```gdscript
	# v3→v4: quests saknas i äldre saves — börja tomt
	QuestSystem.active = s.get("quests_active", {})
	QuestSystem.completed = s.get("quests_completed", {})
```

- [ ] **Step 4: Kör — förvänta PASS**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gselect=test_save -gexit 2>&1 | tail -8
```

- [ ] **Step 5: Commit**

```bash
git add autoload/save_manager.gd tests/unit/test_save.gd
git commit -m "feat: save v4 — queststate i sparfilen med v3-migrering"
```

---

### Task 6: Dialog-NPC-entitet med idle barks

**Files:**
- Create: `entities/npc.gd`, `entities/npc.tscn`
- Modify: `autoload/world.gd` (`_spawn_world_objects`)

- [ ] **Step 1: Skapa `entities/npc.gd`**

```gdscript
class_name DialogueNpc
extends Node2D
## Dialog-NPC: klick intill → dialogruta. Idle barks vid närhet.

const BARK_COOLDOWN := 30.0
const BARK_SHOW_TIME := 4.0
const BARK_RADIUS := 4

var npc_id := ""
var tile := Vector2i.ZERO
var _bark_timer := 0.0

@onready var click_area: Area2D = $ClickArea
@onready var name_lbl: Label = $NameLabel
@onready var bark_lbl: Label = $BarkLabel
@onready var bark_audio: AudioStreamPlayer2D = $BarkAudio

func setup(id: String, t: Vector2i) -> void:
	npc_id = id
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)

func _ready() -> void:
	name_lbl.text = String(DialogueDB.npcs[npc_id]["name"])
	click_area.input_event.connect(_on_click)

func _process(delta: float) -> void:
	if _bark_timer > 0.0:
		_bark_timer -= delta
		if bark_lbl.visible and _bark_timer < BARK_COOLDOWN - BARK_SHOW_TIME:
			bark_lbl.visible = false
		return
	var pdist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
	if pdist <= BARK_RADIUS:
		_bark()

func _bark() -> void:
	_bark_timer = BARK_COOLDOWN
	var barks: Array = DialogueDB.npcs[npc_id].get("barks", [])
	if barks.is_empty():
		return
	var i := randi() % barks.size()
	bark_lbl.text = String(barks[i])
	bark_lbl.visible = true
	for ext in ["ogg", "wav"]:
		var p := "res://audio/voice/%s/bark_%d.%s" % [npc_id, i, ext]
		if ResourceLoader.exists(p):
			bark_audio.stream = load(p)
			bark_audio.play()
			return

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 2:
			World.hud.open_dialogue(npc_id)
		else:
			World.hud.show_message("Gå närmare %s." % DialogueDB.npcs[npc_id]["name"])
```

- [ ] **Step 2: Skapa `entities/npc.tscn`** (samma mönster som taskmaster, grön kropp)

```ini
[gd_scene load_steps=3 format=3 uid="uid://dialognpc1"]

[ext_resource type="Script" path="res://entities/npc.gd" id="1"]

[sub_resource type="RectangleShape2D" id="shape1"]
size = Vector2(28, 28)

[node name="DialogueNpc" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-10, -14, 10, -14, 10, 14, -10, 14)
color = Color(0.2, 0.6, 0.35, 1)

[node name="NameLabel" type="Label" parent="."]
offset_left = -48.0
offset_top = -32.0
offset_right = 48.0
offset_bottom = -20.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="BarkLabel" type="Label" parent="."]
visible = false
offset_left = -72.0
offset_top = -48.0
offset_right = 72.0
offset_bottom = -34.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 10
modulate = Color(1, 1, 0.75, 1)

[node name="BarkAudio" type="AudioStreamPlayer2D" parent="."]

[node name="ClickArea" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="ClickArea"]
shape = SubResource("shape1")
```

- [ ] **Step 3: Spawna NPC:er i `world.gd`**

Sist i `_spawn_world_objects()`:

```gdscript
	for id in DialogueDB.npcs:
		var nd: Dictionary = DialogueDB.npcs[id]
		if String(nd["zone"]) == current_zone.zone_id:
			var npc: Node2D = preload("res://entities/npc.tscn").instantiate()
			current_zone.add_child(npc)
			npc.setup(id, Vector2i(int(nd["position"][0]), int(nd["position"][1])))
```

- [ ] **Step 4: Re-import + boot-check (ny scen + class_name)**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```
Förväntat: inga skriptfel. (`open_dialogue` finns inte i HUD ännu — den anropas bara vid klick, inte vid boot.)

- [ ] **Step 5: Commit**

```bash
git add entities/npc.gd entities/npc.tscn autoload/world.gd
git commit -m "feat: dialog-NPC-entitet med idle barks; spawnas per zon från npcs.json"
```

---

### Task 7: Dialogruta-UI

**Files:**
- Create: `ui/dialogue_box.gd`
- Modify: `ui/hud.gd`

- [ ] **Step 1: Skapa `ui/dialogue_box.gd`**

```gdscript
extends PanelContainer
## Dialogruta: NPC-namn, text, valknappar. Spelar nodens röstfil om den finns.

var _npc_id := ""
var _name_lbl: Label
var _text_lbl: Label
var _choices: VBoxContainer
var _audio: AudioStreamPlayer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(540, 0)
	offset_left = 370.0
	offset_top = 470.0
	var v := VBoxContainer.new()
	add_child(v)
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.modulate = Color(1.0, 0.85, 0.4)
	v.add_child(_name_lbl)
	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 13)
	v.add_child(_text_lbl)
	_choices = VBoxContainer.new()
	v.add_child(_choices)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)

func open(npc_id: String) -> void:
	_npc_id = npc_id
	_show_node(String(DialogueDB.npcs[npc_id]["dialogue_root"]))

func close() -> void:
	visible = false
	_audio.stop()

func _show_node(node_id: String) -> void:
	var n: Dictionary = DialogueDB.nodes.get(node_id, {})
	if n.is_empty():
		close()
		return
	visible = true
	_name_lbl.text = String(DialogueDB.npcs[_npc_id]["name"])
	_text_lbl.text = String(n["text"])
	_play_voice(node_id)
	for c in _choices.get_children():
		c.queue_free()
	for c in DialogueDB.visible_choices(node_id):
		var b := Button.new()
		b.text = String(c["text"])
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_choice.bind(c))
		_choices.add_child(b)

func _on_choice(c: Dictionary) -> void:
	DialogueDB.run_actions(c.get("actions", []), _npc_id)
	var nxt = c.get("next")
	if nxt == null:
		close()
	else:
		_show_node(String(nxt))

func _play_voice(node_id: String) -> void:
	_audio.stop()
	for ext in ["ogg", "wav"]:
		var p := "res://audio/voice/%s/%s.%s" % [_npc_id, node_id, ext]
		if ResourceLoader.exists(p):
			_audio.stream = load(p)
			_audio.play()
			return
```

- [ ] **Step 2: Koppla in i `ui/hud.gd`**

Lägg till medlemsvariabel efter `var bestiary_panel: PanelContainer`:

```gdscript
var dialogue_box: PanelContainer
```

I `_ready()` efter `bestiary_panel`-instansieringen:

```gdscript
	dialogue_box = preload("res://ui/dialogue_box.gd").new()
	add_child(dialogue_box)
```

Ny metod efter `open_tasks()`:

```gdscript
func open_dialogue(npc_id: String) -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.visible = false
	dialogue_box.open(npc_id)
```

I `_unhandled_input`, ESC-grenen — lägg till:

```gdscript
			dialogue_box.close()
```

- [ ] **Step 3: Boot-check + hela testsviten**

```bash
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add ui/dialogue_box.gd ui/hud.gd
git commit -m "feat: dialogruta — text, villkorsfiltrerade val, röstuppspelning, ESC stänger"
```

---

### Task 8: Questlogg (J) + HUD-questrad

**Files:**
- Create: `ui/quest_log.gd`
- Modify: `ui/hud.gd`, `ui/hud.tscn`, `project.godot`

- [ ] **Step 1: Input-action `toggle_quest_log` (J) i `project.godot`**

Efter `toggle_console`-blocket i `[input]`:

```ini
toggle_quest_log={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: QuestsLabel i `ui/hud.tscn`**

Efter `TasksLabel`-noden:

```ini
[node name="QuestsLabel" type="Label" parent="."]
offset_left = 16.0
offset_top = 102.0
offset_right = 600.0
offset_bottom = 118.0
theme_override_font_sizes/font_size = 11
modulate = Color(0.7, 1, 0.7, 1)
```

- [ ] **Step 3: Skapa `ui/quest_log.gd`**

```gdscript
extends PanelContainer
## Questlogg (J): aktiva quests med hint + progress, samt klarade.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(440, 0)
	offset_left = 300.0
	offset_top = 80.0
	_list = VBoxContainer.new()
	add_child(_list)
	QuestSystem.quest_started.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_progress.connect(func(_id): if visible: _rebuild())
	QuestSystem.step_advanced.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_completed.connect(func(_id): if visible: _rebuild())

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Questlogg"
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	if QuestSystem.active.is_empty() and QuestSystem.completed.is_empty():
		_row("Inga quests ännu. Prata med folk i staden!")
		return
	if not QuestSystem.active.is_empty():
		_section("Aktiva")
		for id in QuestSystem.active:
			var s := QuestSystem.current_step(id)
			var progress := ""
			if String(s.get("type", "")) in ["kill", "collect"]:
				progress = "  %d/%d" % [int(QuestSystem.active[id]["progress"]), int(s["count"])]
			_row("%s — %s%s" % [QuestSystem.quests[id]["name"], QuestSystem.hint(id), progress])
	if not QuestSystem.completed.is_empty():
		_section("Klarade")
		for id in QuestSystem.completed:
			_row("%s ✓" % QuestSystem.quests[id]["name"])

func _section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1.0, 0.85, 0.4)
	_list.add_child(lbl)

func _row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	_list.add_child(lbl)
```

- [ ] **Step 4: Koppla in i `ui/hud.gd`**

Medlemsvariabel efter `var dialogue_box: PanelContainer`:

```gdscript
var quest_log: PanelContainer
```

`@onready`-rad efter `tasks_lbl`:

```gdscript
@onready var quests_lbl: Label = $QuestsLabel
```

I `_ready()` efter dialogue_box-instansieringen:

```gdscript
	quest_log = preload("res://ui/quest_log.gd").new()
	add_child(quest_log)
	QuestSystem.quest_started.connect(func(_id): _refresh_quests())
	QuestSystem.quest_progress.connect(func(_id): _refresh_quests())
	QuestSystem.step_advanced.connect(func(_id): _refresh_quests())
	QuestSystem.quest_completed.connect(func(id):
		_refresh_quests()
		show_message("Quest klar: %s!" % QuestSystem.quests[id]["name"]))
```

och sist i `_ready()` (bland övriga refresh-anropen): `_refresh_quests()`.

Ny metod efter `_refresh_tasks()`:

```gdscript
func _refresh_quests() -> void:
	if QuestSystem.active.is_empty():
		quests_lbl.text = ""
		return
	var id: String = QuestSystem.active.keys().back()   # senast startade
	quests_lbl.text = "%s — %s" % [QuestSystem.quests[id]["name"], QuestSystem.hint(id)]
```

I `_unhandled_input`: ny gren före ESC-grenen:

```gdscript
		elif event.is_action_pressed("toggle_quest_log"):
			quest_log.toggle()
```

och i ESC-grenen, lägg till:

```gdscript
			quest_log.visible = false
```

- [ ] **Step 5: Boot-check + hela testsviten — förvänta PASS**

```bash
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -10
```

- [ ] **Step 6: Commit**

```bash
git add ui/quest_log.gd ui/hud.gd ui/hud.tscn project.godot
git commit -m "feat: questlogg (J) med aktiva/klarade + HUD-questrad och quest-klar-meddelande"
```

---

### Task 9: TTS-pipeline (Piper) + röstgenerering

**Files:**
- Create: `tools/generate_voices.py`
- Genereras: `audio/voice/<npc_id>/*.ogg` (eller `.wav`), `tools/voice_manifest.json`

- [ ] **Step 1: Installera Piper**

```bash
pip install piper-tts
python -m piper --help 2>&1 | head -5
```
Förväntat: hjälptext. OBS: flaggnamn varierar mellan piper-versioner (`--length-scale` vs `--length_scale`, `-f` vs `--output_file`) — kontrollera hjälptexten och justera konstanterna överst i skriptet vid behov.

- [ ] **Step 2: Skapa `tools/generate_voices.py`**

```python
"""Genererar röstfiler för NPC-dialog och barks via Piper (lokal TTS).

Användning:   python tools/generate_voices.py [--force]
Kräver:       pip install piper-tts
              ffmpeg i PATH för .ogg-konvertering (annars behålls .wav — spelet spelar båda)
Röstmodeller laddas ner automatiskt till tools/voices/ första gången.
Hash-manifest (tools/voice_manifest.json) gör att bara nya/ändrade rader genereras.
Backend-klassen är utbytbar — en ElevenLabsBackend kan pluggas in per NPC senare.
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VOICE_DIR = ROOT / "audio" / "voice"
MODEL_DIR = Path(__file__).resolve().parent / "voices"
MANIFEST = Path(__file__).resolve().parent / "voice_manifest.json"

# Justera vid behov efter `python -m piper --help`:
ARG_MODEL = "--model"
ARG_OUTPUT = "--output-file"
ARG_LENGTH = "--length-scale"
ARG_DATA_DIR = "--data-dir"


class PiperBackend:
    def synth(self, text: str, voice: dict, wav_path: Path) -> None:
        cmd = [sys.executable, "-m", "piper",
               ARG_MODEL, voice["model"],
               ARG_DATA_DIR, str(MODEL_DIR),
               ARG_LENGTH, str(float(voice.get("length_scale", 1.0))),
               ARG_OUTPUT, str(wav_path)]
        subprocess.run(cmd, input=text.encode("utf-8"), check=True)


def to_ogg(wav_path: Path) -> Path:
    if shutil.which("ffmpeg") is None:
        return wav_path  # behåll .wav
    ogg = wav_path.with_suffix(".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
                    "-i", str(wav_path), str(ogg)], check=True)
    wav_path.unlink()
    return ogg


def line_hash(text: str, voice: dict) -> str:
    return hashlib.sha1(json.dumps([text, voice], sort_keys=True).encode()).hexdigest()


def main() -> None:
    force = "--force" in sys.argv
    npcs = json.loads((ROOT / "data" / "npcs.json").read_text(encoding="utf-8"))
    nodes = json.loads((ROOT / "data" / "dialogue.json").read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    backend = PiperBackend()

    jobs = []  # (npc_id, line_id, text)
    for node_id, n in nodes.items():
        jobs.append((n["speaker"], node_id, n["text"]))
    for npc_id, npc in npcs.items():
        for i, bark in enumerate(npc.get("barks", [])):
            jobs.append((npc_id, f"bark_{i}", bark))

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    done = skipped = 0
    for npc_id, line_id, text in jobs:
        voice = npcs[npc_id]["voice"]
        key = f"{npc_id}/{line_id}"
        h = line_hash(text, voice)
        out_dir = VOICE_DIR / npc_id
        exists = any((out_dir / f"{line_id}{ext}").exists() for ext in (".ogg", ".wav"))
        if not force and manifest.get(key) == h and exists:
            skipped += 1
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        wav = out_dir / f"{line_id}.wav"
        backend.synth(text, voice, wav)
        to_ogg(wav)
        manifest[key] = h
        done += 1
        print(f"  {key}")

    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    print(f"Genererade {done}, hoppade över {skipped}.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Generera rösterna**

```bash
cd /c/Users/Hem/tibia2d && python tools/generate_voices.py
```
Förväntat: ~30 rader genereras (24 dialognoder + 10 barks), modeller laddas ner första gången. Lyssna stickprovsmässigt på ett par filer.

- [ ] **Step 4: Re-importera så Godot ser ljudfilerna**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d --import 2>&1 | tail -3
```

- [ ] **Step 5: Verifiera att manifestet hoppar över oförändrade rader**

```bash
python tools/generate_voices.py
```
Förväntat: `Genererade 0, hoppade över 34.` (eller motsvarande antal).

- [ ] **Step 6: Commit (inkl. genererade ljudfiler + Godots .import-filer)**

```bash
git add tools/generate_voices.py tools/voice_manifest.json audio/
git commit -m "feat: Piper-TTS-pipeline med hash-manifest + genererade röstfiler för alla NPC:er"
```

---

### Task 10: Slutverifiering

- [ ] **Step 1: Hela testsviten**

```bash
"/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | tail -15
```
Förväntat: ~130+ tester, alla gröna.

- [ ] **Step 2: Boot-check utan fel**

```bash
timeout 8 "/c/Godot/Godot_v4.6.2-stable_win64.exe" --headless --path /c/Users/Hem/tibia2d res://world/game.tscn 2>&1 | grep -iE "script error|parse error" | head -5
```

- [ ] **Step 3: Fånga upp genererade .uid-filer**

Godot genererar `.uid`-filer för nya skript vid import. Kontrollera och committa dem:

```bash
git status --short
git add "*.uid" && git commit -m "chore: Godot-genererade .uid-filer för M4-skript" || echo "inga .uid-filer"
```

- [ ] **Step 4: Bocka av planen + commit**

Markera alla utförda checkboxar i denna fil och committa:

```bash
git add docs/superpowers/plans/2026-06-12-milstolpe-4-quests-roster.md
git commit -m "docs: bocka av M4-planen"
```

- [ ] **Step 5: Manuellt speltest (användaren)**

Acceptanskriterier:
1. **Quest 1:** Prata med Elder Rowan → ta quest → prata med Brom → gå till skogen → tillbaka till Rowan → belöning + "Quest klar"-meddelande.
2. **Quest 2:** Brom efter quest 1 → gräv 3 järnmalm i grottan (HUD-raden visar 0/3 → 3/3) → lämna in → stålsvärd i inventory.
3. **Quest 3:** Sylva i skogen → döda 8 ormar → lämna in.
4. **Quest 4:** Maelis → ljus i inventory → gå till kryptan (kräver kryptan-task-unlock; använd §-konsolen vid behov) → använd ljuset där (I-panelen, "Använd") → tillbaka till Maelis. Testa även "I lost the candle"-flödet.
5. **Quest 5:** Maelis efter quest 4 → döda Ghulkungen → lämna in.
6. **Röster:** NPC-repliker hörs (engelska); olika röster per NPC; barks syns + hörs när man går förbi.
7. **Questlogg:** J öppnar/stänger; ESC stänger; visar hint + progress; klarade quests listas.
8. **Save:** Spara mitt i quest 2 (zonbyte), starta om, ladda — queststate kvar.
```

---

## Efter planen

- Mergas till master först efter godkänt manuellt speltest (Steg 4 ovan), som M3.
