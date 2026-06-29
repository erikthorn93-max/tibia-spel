extends GutTest
## Test för piratkedjan i Saltviks hamn (coast):
##  Branka Saltskägg (npc_marooned_mate) → tre quests som kulminerar i att fälla
##  Piratkapten Svartöga i det sjunkna skeppet. Unik belöning: Svartögas sabel.
##  Detta var den enda bossen i spelet helt utan en quest riktad mot sig.

const NPC_ID := "npc_marooned_mate"
const CHAIN := [
	{ qid = "quest_coast_1", requires = [],                boss = "" },
	{ qid = "quest_coast_2", requires = ["quest_coast_1"], boss = "" },
	{ qid = "quest_coast_3", requires = ["quest_coast_2"], boss = "Piratkapten Svartöga" },
]

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0

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

func _zone_data(zone_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

# ── Struktur ────────────────────────────────────────────────────────────────

func test_kedjan_finns_med_ratt_givare_och_requires():
	for entry in CHAIN:
		var q: Dictionary = QuestSystem.quests.get(String(entry["qid"]), {})
		assert_false(q.is_empty(), "%s saknas" % entry["qid"])
		assert_eq(String(q["giver"]), NPC_ID, "%s har fel givare" % entry["qid"])
		assert_eq(q["requires"], entry["requires"], "%s har fel requires" % entry["qid"])

func test_alla_kill_monster_finns_i_bestiariet():
	for entry in CHAIN:
		for s in QuestSystem.quests[String(entry["qid"])]["steps"]:
			if String(s.get("type", "")) == "kill":
				assert_true(MonsterDB.monsters.has(String(s["monster"])),
					"%s refererar saknat monster %s" % [entry["qid"], s["monster"]])

func test_finalen_riktas_mot_svartoga():
	assert_eq(String(QuestSystem.quests["quest_coast_3"]["steps"][0]["monster"]),
		"Piratkapten Svartöga")

# ── Gating ──────────────────────────────────────────────────────────────────

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_coast_1"))
	assert_false(QuestSystem.can_start("quest_coast_2"), "coast_2 ska kräva coast_1")
	assert_false(QuestSystem.can_start("quest_coast_3"), "coast_3 ska kräva coast_2")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_kedjan_spelas_igenom_och_ger_sabeln():
	_play_quest("quest_coast_1")
	_play_quest("quest_coast_2")
	_play_quest("quest_coast_3")
	assert_true(QuestSystem.completed.has("quest_coast_3"), "piratkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get("svartogas_sabel", 0)), 1,
		"Svartögas sabel ska delas ut")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_sabeln_ar_definierad_och_utrustbar():
	assert_true(ItemDB.items.has("svartogas_sabel"), "sabeln saknas")
	assert_eq(String(ItemDB.items["svartogas_sabel"]["type"]), "weapon")
	assert_eq(String(ItemDB.items["svartogas_sabel"]["slot"]), "weapon")

# ── Questgivaren bor i hamnen och är korrekt länkad ───────────────────────────

func test_branka_finns_i_coast_pa_gangbar_ruta():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas i npcs.json" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "coast", "Branka ska stå i Saltviks hamn")
	var root := String(nd.get("dialogue_root", ""))
	assert_eq(root, NPC_ID + "_root", "fel dialog-root")
	assert_true(DialogueDB.nodes.has(root), "dialognoden %s saknas" % root)
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("coast"), "coast")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Branka står på en ogångbar ruta %s i coast" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	# Varje quest ska ha en _offer-nod med start_quest och en _report-nod.
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
