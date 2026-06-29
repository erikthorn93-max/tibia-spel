extends GutTest
## Test för Aurelius gravforskar-kedja i Solgraven (solgraven):
##  Aurelius (npc_tomb_seeker) läser de murkna väggarnas skrift och väcker av
##  misstag den questlösa bossen Solkonungen Akh-Mortis. Kedjan fyller alltså
##  bosstäckningsluckan i Solgraven. Belöning: Solkungens diadem (amulett).

const NPC_ID := "npc_tomb_seeker"
const REWARD_ID := "solkungens_diadem"
const BOSS_ID := "Solkonungen Akh-Mortis"
const CHAIN := [
	{ qid = "quest_tomb_1", requires = [] },
	{ qid = "quest_tomb_2", requires = ["quest_tomb_1"] },
	{ qid = "quest_tomb_3", requires = ["quest_tomb_2"] },
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

func test_alla_kill_monster_och_collect_items_finns():
	for entry in CHAIN:
		for s in QuestSystem.quests[String(entry["qid"])]["steps"]:
			match String(s.get("type", "")):
				"kill":
					assert_true(MonsterDB.monsters.has(String(s["monster"])),
						"%s saknat monster %s" % [entry["qid"], s["monster"]])
				"collect":
					assert_true(ItemDB.items.has(String(s["item"])),
						"%s saknat item %s" % [entry["qid"], s["item"]])

# ── Bosstäckning ──────────────────────────────────────────────────────────────

func test_finalen_faller_den_questlosa_bossen():
	# Hela poängen med kedjan: ge Solkonungen Akh-Mortis en questlinje.
	assert_true(MonsterDB.monsters.has(BOSS_ID), "bossen %s saknas" % BOSS_ID)
	assert_true(bool(MonsterDB.monsters[BOSS_ID].get("boss", false)),
		"%s ska vara flaggad som boss" % BOSS_ID)
	var final_kills := []
	for s in QuestSystem.quests["quest_tomb_3"]["steps"]:
		if String(s.get("type", "")) == "kill":
			final_kills.append(String(s["monster"]))
	assert_true(final_kills.has(BOSS_ID), "quest_tomb_3 ska fälla %s" % BOSS_ID)

# ── Gating ──────────────────────────────────────────────────────────────────

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_tomb_1"))
	assert_false(QuestSystem.can_start("quest_tomb_2"), "tomb_2 ska kräva tomb_1")
	assert_false(QuestSystem.can_start("quest_tomb_3"), "tomb_3 ska kräva tomb_2")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_kedjan_spelas_igenom_och_ger_diademet():
	_play_quest("quest_tomb_1")
	_play_quest("quest_tomb_2")
	_play_quest("quest_tomb_3")
	assert_true(QuestSystem.completed.has("quest_tomb_3"), "gravkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Solkungens diadem ska delas ut")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_diademet_ar_en_giltig_amulett():
	assert_true(ItemDB.items.has(REWARD_ID), "diademet saknas")
	assert_eq(String(ItemDB.items[REWARD_ID]["slot"]), "amulet")

# ── Givare och dialog ─────────────────────────────────────────────────────────

func test_aurelius_star_pa_gangbar_ruta_i_solgraven():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "solgraven")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("solgraven"), "solgraven")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Aurelius står på en ogångbar ruta %s i solgraven" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
