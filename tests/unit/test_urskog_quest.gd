extends GutTest
## Innehållstest: väktarinnan Lunda & questkedjan i Urskogens hjärta.

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

func test_lunda_npc_in_urskog_zone():
	assert_true(npcs.has("npc_urskog_guardian"), "Lunda saknas i npcs.json")
	assert_eq(String(npcs["npc_urskog_guardian"]["zone"]), "urskogens_hjarta")
	assert_eq(String(npcs["npc_urskog_guardian"]["dialogue_root"]), "lunda_root")

func test_lunda_spawn_tile_is_walkable():
	# Positionen måste vara en gångbar ruta i zonen (inte vägg/spawn/nod).
	var pos: Array = npcs["npc_urskog_guardian"]["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_load("res://data/zones/urskogens_hjarta.json"), "urskogens_hjarta")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Lundas ruta %s ska vara gångbar" % str(pos))
	z.free()

func test_quest_chain_present_and_linked():
	assert_true(quests.has("quest_urskog_1"), "quest 1 saknas")
	assert_true(quests.has("quest_urskog_2"), "quest 2 saknas")
	assert_eq(String(quests["quest_urskog_1"]["giver"]), "npc_urskog_guardian")
	assert_has(quests["quest_urskog_2"]["requires"], "quest_urskog_1",
		"quest 2 ska kräva quest 1")

func test_capstone_targets_boss_and_rewards_amulet():
	var q: Dictionary = quests["quest_urskog_2"]
	var kills: Array = q["steps"].filter(func(s): return String(s["type"]) == "kill")
	assert_eq(String(kills[0]["monster"]), "Urskogsvältaren")
	assert_true(q["rewards"]["items"].has("urskog_amulett"))

func test_reward_amulet_is_defined_and_equippable():
	assert_true(ItemDB.items.has("urskog_amulett"), "belöningsamuletten saknas")
	assert_eq(String(ItemDB.items["urskog_amulett"]["slot"]), "amulet")

func test_both_quests_startable_via_lunda_dialogue():
	var started := {}
	for nid in nodes:
		if String(nodes[nid].get("speaker", "")) != "npc_urskog_guardian":
			continue
		for c in nodes[nid].get("choices", []):
			for a in c.get("actions", []):
				if String(a.get("type", "")) == "start_quest":
					started[String(a["quest"])] = true
	assert_true(started.has("quest_urskog_1"), "quest 1 går inte att starta hos Lunda")
	assert_true(started.has("quest_urskog_2"), "quest 2 går inte att starta hos Lunda")
