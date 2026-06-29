extends GutTest
## Test för Nadiras relikjakt i Ökenruinerna (desert):
##  Nadira, relikjägerska (npc_desert_nomad), ger en fristående sidokedja vid
##  sidan av byäldstens farao-arc (quest_desert_*). Tema: gräv fram en glömd
##  relik bit för bit. Belöning: Ökenkungens sigill (ring).

const NPC_ID := "npc_desert_nomad"
const REWARD_ID := "okenkungens_sigill"
const CHAIN := [
	{ qid = "quest_relic_1", requires = [] },
	{ qid = "quest_relic_2", requires = ["quest_relic_1"] },
	{ qid = "quest_relic_3", requires = ["quest_relic_2"] },
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

func test_kedjan_ar_fristaende_fran_faraos_arc():
	# Relikkedjan ska inte hänga på byäldstens quest_desert_*.
	for entry in CHAIN:
		for req in QuestSystem.quests[String(entry["qid"])]["requires"]:
			assert_false(String(req).begins_with("quest_desert_"),
				"%s ska inte kräva byäldstens farao-kedja" % entry["qid"])

# ── Gating ──────────────────────────────────────────────────────────────────

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_relic_1"))
	assert_false(QuestSystem.can_start("quest_relic_2"), "relic_2 ska kräva relic_1")
	assert_false(QuestSystem.can_start("quest_relic_3"), "relic_3 ska kräva relic_2")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_kedjan_spelas_igenom_och_ger_sigillen():
	_play_quest("quest_relic_1")
	_play_quest("quest_relic_2")
	_play_quest("quest_relic_3")
	assert_true(QuestSystem.completed.has("quest_relic_3"), "relikkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Ökenkungens sigill ska delas ut")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_sigillen_ar_en_giltig_ring():
	assert_true(ItemDB.items.has(REWARD_ID), "sigillen saknas")
	assert_eq(String(ItemDB.items[REWARD_ID]["slot"]), "ring")

# ── Givare och dialog ─────────────────────────────────────────────────────────

func test_nadira_star_pa_gangbar_ruta_i_desert():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "desert")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("desert"), "desert")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Nadira står på en ogångbar ruta %s i desert" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
