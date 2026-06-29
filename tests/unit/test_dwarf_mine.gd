extends GutTest
## Test för utbyggnaden av Dvärgsgruvan (dwarf_mine):
##  • Tre nya monster: Dvärgsoldat, Dvärggeomant och bossen Stenkungen Brokk.
##  • Alla tre spawnar i zonen via spawn_table.
##  • Durin Stenbroders questkedja (mine_1..3) som kulminerar mot Brokk och ger
##    Stenkungens harnesk.

const NPC_ID := "npc_mine_dwarf"
const NEW_MONSTERS := ["Dvärgsoldat", "Dvärggeomant", "Stenkungen Brokk"]
const VALID_ABILITIES := ["poison", "burn", "drain", "stun", "slow"]
const REWARD_ID := "stenkungens_harnesk"
const CHAIN := [
	{ qid = "quest_mine_1", requires = [] },
	{ qid = "quest_mine_2", requires = ["quest_mine_1"] },
	{ qid = "quest_mine_3", requires = ["quest_mine_2"] },
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

# ── Nya monster ───────────────────────────────────────────────────────────────

func test_nya_monster_finns_med_giltig_ability():
	for m in NEW_MONSTERS:
		assert_true(MonsterDB.monsters.has(m), "%s saknas i bestiariet" % m)
		var ab: Dictionary = MonsterDB.monsters[m].get("ability", {})
		assert_true(VALID_ABILITIES.has(String(ab.get("type", ""))),
			"%s har en ability stridssystemet inte hanterar: %s" % [m, ab.get("type", "")])

func test_brokk_ar_flaggad_som_boss():
	assert_true(bool(MonsterDB.monsters["Stenkungen Brokk"].get("boss", false)),
		"Stenkungen Brokk ska vara en boss")

func test_nya_monsters_loot_pekar_pa_giltiga_items():
	for m in NEW_MONSTERS:
		for entry in MonsterDB.monsters[m].get("loot", []):
			assert_true(ItemDB.items.has(String(entry["item"])),
				"%s droppar okänt item %s" % [m, entry["item"]])

# ── Zon-spawn ─────────────────────────────────────────────────────────────────

func test_alla_tre_spawnar_i_dvargsgruvan():
	var table: Array = _zone_data("dwarf_mine").get("spawn_table", [])
	var listed := {}
	for e in table:
		listed[String(e["monster"])] = true
	for m in NEW_MONSTERS:
		assert_true(listed.has(m), "%s spawnar inte i dwarf_mine" % m)

func test_brokk_spawnar_ensam_med_lang_respawn():
	for e in _zone_data("dwarf_mine").get("spawn_table", []):
		if String(e["monster"]) == "Stenkungen Brokk":
			assert_eq(int(e["count"]), 1, "bossen ska bara spawna en gång")
			assert_gte(float(e["respawn"]), 600.0, "bossen ska ha lång respawn")

# ── Questkedjan ───────────────────────────────────────────────────────────────

func test_kedjan_finns_med_ratt_givare_och_requires():
	for entry in CHAIN:
		var q: Dictionary = QuestSystem.quests.get(String(entry["qid"]), {})
		assert_false(q.is_empty(), "%s saknas" % entry["qid"])
		assert_eq(String(q["giver"]), NPC_ID, "%s har fel givare" % entry["qid"])
		assert_eq(q["requires"], entry["requires"], "%s har fel requires" % entry["qid"])

func test_finalen_riktas_mot_brokk():
	assert_eq(String(QuestSystem.quests["quest_mine_3"]["steps"][0]["monster"]),
		"Stenkungen Brokk")

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_mine_1"))
	assert_false(QuestSystem.can_start("quest_mine_2"), "mine_2 ska kräva mine_1")
	assert_false(QuestSystem.can_start("quest_mine_3"), "mine_3 ska kräva mine_2")

func test_kedjan_spelas_igenom_och_ger_harnesket():
	_play_quest("quest_mine_1")
	_play_quest("quest_mine_2")
	_play_quest("quest_mine_3")
	assert_true(QuestSystem.completed.has("quest_mine_3"), "gruvkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Stenkungens harnesk ska delas ut")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_harnesket_ar_en_giltig_kroppsrustning():
	assert_true(ItemDB.items.has(REWARD_ID), "harnesket saknas")
	assert_eq(String(ItemDB.items[REWARD_ID]["slot"]), "body")
	assert_gt(int(ItemDB.items[REWARD_ID].get("armor", 0)), 0, "harnesket ska ge rustning")

# ── Givare och dialog ─────────────────────────────────────────────────────────

func test_durin_star_pa_gangbar_ruta_i_dwarf_mine():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "dwarf_mine")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("dwarf_mine"), "dwarf_mine")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Durin står på en ogångbar ruta %s i dwarf_mine" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
