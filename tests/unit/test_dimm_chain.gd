extends GutTest
## Test för Skogsväktaren Eldrins kedja i Dimmoren (dimmoren):
##  Eldrin (npc_forestwarden) är den siste skogsväktaren. Hans EGEN kedja
##  (quest_dimm_*) handlar om att skydda den levande skogen och lägga hans
##  fallna väktarbröder till ro — distinkt från röta/Urskogsvältaren-arcen
##  som ges av Lunda (npc_urskog_guardian, quest_urskog_*).
##  Belöning: Dimväktarens båge (distansvapen) — den förste väktarens relik.

const NPC_ID := "npc_forestwarden"
const REWARD_ID := "dimvaktarens_bage"
const CHAIN := [
	{ qid = "quest_dimm_1", requires = [] },
	{ qid = "quest_dimm_2", requires = ["quest_dimm_1"] },
	{ qid = "quest_dimm_3", requires = ["quest_dimm_2"] },
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

func test_kedjan_ar_fristaende_fran_urskog_arcen():
	# Eldrins egen kedja ska inte hänga på Lundas röta/Vältaren-quests.
	for entry in CHAIN:
		for req in QuestSystem.quests[String(entry["qid"])]["requires"]:
			assert_false(String(req).begins_with("quest_urskog_"),
				"%s ska inte kräva urskog-kedjan" % entry["qid"])

# ── Gating ──────────────────────────────────────────────────────────────────

func test_stegen_kraver_foregaende_quest():
	assert_true(QuestSystem.can_start("quest_dimm_1"))
	assert_false(QuestSystem.can_start("quest_dimm_2"), "dimm_2 ska kräva dimm_1")
	assert_false(QuestSystem.can_start("quest_dimm_3"), "dimm_3 ska kräva dimm_2")

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_kedjan_spelas_igenom_och_ger_bagen():
	_play_quest("quest_dimm_1")
	_play_quest("quest_dimm_2")
	_play_quest("quest_dimm_3")
	assert_true(QuestSystem.completed.has("quest_dimm_3"), "dimmkedjan slutfördes inte")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Dimväktarens båge ska delas ut")

# ── Unik belöning ─────────────────────────────────────────────────────────────

func test_bagen_ar_ett_giltigt_distansvapen():
	assert_true(ItemDB.items.has(REWARD_ID), "bågen saknas")
	var it: Dictionary = ItemDB.items[REWARD_ID]
	assert_eq(String(it["type"]), "weapon")
	assert_eq(String(it["slot"]), "weapon")
	assert_eq(String(it["skill"]), "distance")
	assert_true(it.has("ammo"), "en båge ska ha ammunition")

# ── Givare och dialog ─────────────────────────────────────────────────────────

func test_eldrin_star_pa_gangbar_ruta_i_dimmoren():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), "dimmoren")
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data("dimmoren"), "dimmoren")
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Eldrin står på en ogångbar ruta %s i dimmoren" % str(pos))
	z.free()

func test_dialogen_erbjuder_och_rapporterar_alla_tre_quests():
	for entry in CHAIN:
		var qid := String(entry["qid"])
		assert_true(DialogueDB.nodes.has(qid + "_offer"), "%s_offer saknas" % qid)
		assert_true(DialogueDB.nodes.has(qid + "_report"), "%s_report saknas" % qid)
