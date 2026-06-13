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

func test_sjovagen_quest_present():
	assert_true(quests.has("quest_sjovagen"), "quest saknas")
	assert_eq(String(quests["quest_sjovagen"]["giver"]), "npc_captain")
	assert_true(npcs.has("npc_captain"), "Brandt saknas")
	assert_true(npcs.has("npc_fishmonger"), "Saltgreta saknas")
	assert_eq(String(npcs["npc_captain"]["zone"]), "town")
	assert_eq(String(npcs["npc_fishmonger"]["zone"]), "coast")
