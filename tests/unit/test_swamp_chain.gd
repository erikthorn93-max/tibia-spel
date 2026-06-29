extends GutTest
## Test för träskkedjan i Träsket (swamp):
##  Sippa, träskeremiten (npc_swamp_hermit), ger tre quests som spårar träskets
##  sjukdom till dess hjärta. Final-questen låser upp grinden "traskets_hjarta"
##  (annars bara nåbar via en 100-kills slayer-task) och ger en unik giftklubba.

const NPC_ID := "npc_swamp_hermit"
const UNLOCK_ID := "traskets_hjarta"
const REWARD_ID := "dypolsklubban"
const CHAIN := [
	{ qid = "quest_swamp_1", requires = [] },
	{ qid = "quest_swamp_2", requires = ["quest_swamp_1"] },
	{ qid = "quest_swamp_3", requires = ["quest_swamp_2"] },
]

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0
	UnlockSystem.unlocked.erase(UNLOCK_ID)

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

func test_finalen_riktas_mot_traskdjavul():
	assert_eq(String(QuestSystem.quests["quest_swamp_3"]["steps"][0]["monster"]), "Träskdjävul")

# ── Gating ──────────────────────────────────────────────────────────────────

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_swamp_1"))
	assert_false(QuestSystem.can_start("quest_swamp_2"), "swamp_2 ska kräva swamp_1")
	assert_false(QuestSystem.can_start("quest_swamp_3"), "swamp_3 ska kräva swamp_2")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_kedjan_spelas_igenom_ger_klubban_och_oppnar_hjartat():
	assert_false(UnlockSystem.is_unlocked(UNLOCK_ID), "hjärtat ska vara låst innan kedjan")
	_play_quest("quest_swamp_1")
	_play_quest("quest_swamp_2")
	_play_quest("quest_swamp_3")
	assert_true(QuestSystem.completed.has("quest_swamp_3"), "träskkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Dypölsklubban ska delas ut")
	assert_true(UnlockSystem.is_unlocked(UNLOCK_ID),
		"Träskets hjärta ska låsas upp när kedjan är klar")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_klubban_ar_ett_giltigt_giftvapen():
	assert_true(ItemDB.items.has(REWARD_ID), "klubban saknas")
	var it: Dictionary = ItemDB.items[REWARD_ID]
	assert_eq(String(it["type"]), "weapon")
	assert_eq(String(it["slot"]), "weapon")
	var ab: Dictionary = it.get("ability", {})
	assert_eq(String(ab.get("type", "")), "poison", "klubban ska förgifta")
	assert_gt(float(ab.get("chance", 0.0)), 0.0, "måste ha proc-chans")
	assert_gt(float(ab.get("tick_dmg", 0.0)), 0.0, "måste göra giftskada")

# ── Questgivaren och dialogen ─────────────────────────────────────────────────

func test_sippa_star_pa_gangbar_ruta_i_swamp():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "swamp")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("swamp"), "swamp")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Sippa står på en ogångbar ruta %s i swamp" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
