extends GutTest
## Test för de två odöd-kedjorna:
##  • Vampyrkedjan (Cornelius → VampyrHerre), unik belöning vampyrjagarens_signet
##  • Lich-kedjan (Maelis, fortsättning på Ghulkungen → Lich), unik belöning sjalssten

# kedja -> [{qid, requires, giver, boss}]
const CHAINS := {
	"vampire": [
		{ qid = "quest_vampire_1", giver = "npc_vampire_hunter", requires = [], boss = "Vampyr" },
		{ qid = "quest_vampire_2", giver = "npc_vampire_hunter", requires = ["quest_vampire_1"], boss = "VampyrHerre" },
	],
	"lich": [
		{ qid = "quest_lich_1", giver = "npc_scholar", requires = ["quest_ghoul_king"], boss = "Nekromant" },
		{ qid = "quest_lich_2", giver = "npc_scholar", requires = ["quest_lich_1"], boss = "Lich" },
	],
}

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

# ── Struktur ────────────────────────────────────────────────────────────────

func test_kedjorna_finns_med_ratt_givare_och_requires():
	for key in CHAINS:
		for entry in CHAINS[key]:
			var q: Dictionary = QuestSystem.quests.get(String(entry["qid"]), {})
			assert_false(q.is_empty(), "%s saknas" % entry["qid"])
			assert_eq(String(q["giver"]), String(entry["giver"]), "%s har fel givare" % entry["qid"])
			assert_eq(q["requires"], entry["requires"], "%s har fel requires" % entry["qid"])

func test_alla_boss_och_kill_monster_finns():
	for key in CHAINS:
		for entry in CHAINS[key]:
			for s in QuestSystem.quests[String(entry["qid"])]["steps"]:
				if String(s.get("type", "")) == "kill":
					assert_true(MonsterDB.monsters.has(String(s["monster"])),
						"%s refererar saknat monster %s" % [entry["qid"], s["monster"]])

func test_finalerna_riktas_mot_ratt_boss():
	assert_eq(String(QuestSystem.quests["quest_vampire_2"]["steps"][0]["monster"]), "VampyrHerre")
	assert_eq(String(QuestSystem.quests["quest_lich_2"]["steps"][0]["monster"]), "Lich")

# ── Gating ──────────────────────────────────────────────────────────────────

func test_vampyr_andra_steget_kraver_forsta():
	assert_true(QuestSystem.can_start("quest_vampire_1"))
	assert_false(QuestSystem.can_start("quest_vampire_2"), "vampire_2 ska kräva vampire_1")

func test_lich_kedjan_kraver_ghulkungen_questen():
	assert_false(QuestSystem.can_start("quest_lich_1"),
		"lich_1 ska vara låst innan Ghulkungen-questen är klar")
	QuestSystem.completed["quest_ghoul_king"] = true
	assert_true(QuestSystem.can_start("quest_lich_1"),
		"lich_1 ska öppnas när Ghulkungen-questen är klar")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_vampyrkedjan_spelas_igenom_och_ger_signet():
	_play_quest("quest_vampire_1")
	_play_quest("quest_vampire_2")
	assert_true(QuestSystem.completed.has("quest_vampire_2"), "vampyrkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get("vampyrjagarens_signet", 0)), 1,
		"Vampyrjägarens signet ska delas ut")

func test_lichkedjan_spelas_igenom_och_ger_sjalssten():
	QuestSystem.completed["quest_ghoul_king"] = true   # förkrav uppfyllt
	_play_quest("quest_lich_1")
	_play_quest("quest_lich_2")
	assert_true(QuestSystem.completed.has("quest_lich_2"), "lich-kedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get("sjalssten", 0)), 1, "Själssten ska delas ut")

# ── Unika belöningar ────────────────────────────────────────────────────────

func test_unika_beloningar_ar_definierade_och_utrustbara():
	assert_true(ItemDB.items.has("vampyrjagarens_signet"), "signet saknas")
	assert_eq(String(ItemDB.items["vampyrjagarens_signet"]["slot"]), "ring")
	assert_true(ItemDB.items.has("sjalssten"), "själssten saknas")
	assert_eq(String(ItemDB.items["sjalssten"]["slot"]), "amulet")
