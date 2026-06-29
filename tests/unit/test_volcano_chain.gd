extends GutTest
## Test för den sammanhängande vulkankedjan (Mara Glödsmed → Smältkonungen).
## Validerar kedje-struktur, requires-gating, givarens position och en full
## genomspelning av alla fyra quests inklusive den unika slutbelöningen.

const NPC := "npc_volcano_smith"
const ROOTID := "volcano_smith_root"
const CHAIN := ["quest_volcano_1", "quest_volcano_2", "quest_volcano_3", "quest_volcano_4"]

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0

func _texts(node_id: String) -> Array:
	return DialogueDB.visible_choices(node_id).map(func(c): return String(c["text"]))

func _zone_data(zone_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

# Driver: utför alla steg i en quest (kill/collect/talk_to) tills den är klar.
func _play_quest(qid: String) -> void:
	assert_true(QuestSystem.start(qid), "kunde inte starta %s" % qid)
	for step in QuestSystem.quests[qid]["steps"]:
		match String(step.get("type", "")):
			"kill":
				for i in int(step["count"]):
					QuestSystem.record_kill(String(step["monster"]))
			"collect":
				GameState.add_item(String(step["item"]), int(step["count"]))
			"talk_to":
				QuestSystem.advance_talk(qid, String(step["npc"]))

# ── Struktur ────────────────────────────────────────────────────────────────

func test_kedjan_finns_med_ratt_givare():
	for qid in CHAIN:
		var q: Dictionary = QuestSystem.quests.get(qid, {})
		assert_false(q.is_empty(), "%s saknas" % qid)
		assert_eq(String(q["giver"]), NPC, "%s ska ges av Mara" % qid)

func test_requires_lankar_kedjan_i_ordning():
	assert_eq(QuestSystem.quests["quest_volcano_1"]["requires"], [])
	assert_eq(QuestSystem.quests["quest_volcano_2"]["requires"], ["quest_volcano_1"])
	assert_eq(QuestSystem.quests["quest_volcano_3"]["requires"], ["quest_volcano_2"])
	assert_eq(QuestSystem.quests["quest_volcano_4"]["requires"], ["quest_volcano_3"])

func test_finalen_riktas_mot_smaltkonungen():
	var steps: Array = QuestSystem.quests["quest_volcano_4"]["steps"]
	assert_eq(String(steps[0]["monster"]), "Smältkonungen")
	assert_true(MonsterDB.monsters.has("Smältkonungen"), "Smältkonungen saknas i monsterdatan")

func test_alla_kill_monster_finns():
	for qid in CHAIN:
		for s in QuestSystem.quests[qid]["steps"]:
			if String(s.get("type", "")) == "kill":
				assert_true(MonsterDB.monsters.has(String(s["monster"])),
					"%s refererar saknat monster %s" % [qid, s["monster"]])

# ── Givaren ─────────────────────────────────────────────────────────────────

func test_giver_npc_finns_och_star_pa_gangbar_ruta():
	assert_true(DialogueDB.npcs.has(NPC), "Mara saknas i npcs.json")
	var nd: Dictionary = DialogueDB.npcs[NPC]
	assert_eq(String(nd["zone"]), "volcano")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("volcano"), "volcano")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Maras ruta %s ska vara gångbar" % str(pos))
	z.free()

# ── Gating ──────────────────────────────────────────────────────────────────

func test_senare_quests_kan_inte_startas_forst():
	assert_true(QuestSystem.can_start("quest_volcano_1"), "Q1 ska vara startbar direkt")
	assert_false(QuestSystem.can_start("quest_volcano_2"), "Q2 ska kräva Q1")
	assert_false(QuestSystem.can_start("quest_volcano_4"), "Q4 ska kräva Q3")

func test_erbjudande_syns_forst_nar_steget_ar_naatt():
	# Q2:s erbjudande ska inte synas förrän Q1 är klar.
	assert_does_not_have(_texts(ROOTID), "Vad säger lavan dig nu?",
		"Q2-erbjudandet ska vara dolt från start")
	_play_quest("quest_volcano_1")
	assert_has(_texts(ROOTID), "Vad säger lavan dig nu?",
		"Q2-erbjudandet ska synas när Q1 är klar")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_hela_kedjan_kan_spelas_igenom_i_ordning():
	for qid in CHAIN:
		_play_quest(qid)
		assert_true(QuestSystem.completed.has(qid), "%s slutfördes inte" % qid)

func test_finalen_delar_ut_unik_amulett():
	for qid in CHAIN:
		_play_quest(qid)
	assert_eq(int(GameState.inventory.get("smaltkonungens_hjarta", 0)), 1,
		"Smältkonungens hjärta ska delas ut när kedjan är klar")

func test_unik_beloning_ar_definierad_och_utrustbar():
	assert_true(ItemDB.items.has("smaltkonungens_hjarta"), "belöningsamuletten saknas")
	assert_eq(String(ItemDB.items["smaltkonungens_hjarta"]["slot"]), "amulet",
		"Smältkonungens hjärta ska kunna bäras i amulett-sloten")
