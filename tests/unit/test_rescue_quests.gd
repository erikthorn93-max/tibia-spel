extends GutTest
## Flödestest för fång-räddningsquesterna: erbjudande syns hos fången, questen
## startar, bossen fälls, rapporten slutför och belöningen delas ut. Använder de
## riktiga autoloadsen (QuestSystem/DialogueDB) — reset i before_each.

# qid -> {npc, boss, root, offer_text, report_text}
const RESCUES := {
	"quest_rescue_tobbe": {
		npc = "npc_troll_captive", boss = "Trollhövding", root = "npc_troll_captive_root",
		offer = "Jag fäller hövdingen och får ut dig.",
		report = "Hövdingen är fälld. Kom, vi går.",
	},
	"quest_revenge_roderik": {
		npc = "npc_dragon_hunter", boss = "Elddraken", root = "npc_dragon_hunter_root",
		offer = "Jag fäller Elddraken — för dina fem.",
		report = "Elddraken är död. Dina vänner är hämnade.",
	},
	"quest_free_vigdis": {
		npc = "npc_temple_templar", boss = "Ärkedemonen", root = "npc_temple_templar_root",
		offer = "Jag möter Ärkedemonen och bryter kultens makt.",
		report = "Ärkedemonen är besegrad. Du är fri.",
	},
}

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0

func _texts(node_id: String) -> Array:
	return DialogueDB.visible_choices(node_id).map(func(c): return String(c["text"]))

func test_quests_finns_med_ratt_givare_och_boss():
	for qid in RESCUES:
		var q: Dictionary = QuestSystem.quests.get(qid, {})
		assert_false(q.is_empty(), "%s saknas i quests.json" % qid)
		assert_eq(String(q["giver"]), String(RESCUES[qid]["npc"]), "%s har fel givare" % qid)
		assert_eq(String(q["steps"][0]["monster"]), String(RESCUES[qid]["boss"]),
			"%s ska börja med att fälla %s" % [qid, RESCUES[qid]["boss"]])

func test_bossarna_finns_i_monsterdatan():
	for qid in RESCUES:
		assert_true(MonsterDB.monsters.has(String(RESCUES[qid]["boss"])),
			"bossen %s saknas i monsterdatan" % RESCUES[qid]["boss"])

func test_erbjudandet_syns_bara_nar_questen_ar_startbar():
	for qid in RESCUES:
		var r: Dictionary = RESCUES[qid]
		assert_has(_texts(String(r["root"])), String(r["offer"]),
			"%s: erbjudandet ska synas innan start" % qid)
		QuestSystem.start(qid)
		assert_does_not_have(_texts(String(r["root"])), String(r["offer"]),
			"%s: erbjudandet ska försvinna när questen är aktiv" % qid)

func test_rapportvalet_syns_forst_efter_att_bossen_fallts():
	for qid in RESCUES:
		var r: Dictionary = RESCUES[qid]
		QuestSystem.start(qid)
		assert_does_not_have(_texts(String(r["root"])), String(r["report"]),
			"%s: rapporten ska vara dold innan bossen är död" % qid)
		QuestSystem.record_kill(String(r["boss"]))   # → talk_to-steget (step 1)
		assert_has(_texts(String(r["root"])), String(r["report"]),
			"%s: rapporten ska synas när bossen är fälld" % qid)

func test_hela_loopen_slutfor_och_belonar():
	for qid in RESCUES:
		var r: Dictionary = RESCUES[qid]
		var guld_innan := GameState.gold   # iron_coin är valuta → hamnar i gold
		QuestSystem.start(qid)
		QuestSystem.record_kill(String(r["boss"]))
		# rapportera in via dialog-action (advance_quest) → slutför questen
		QuestSystem.advance_talk(qid, String(r["npc"]))
		assert_true(QuestSystem.completed.has(qid), "%s slutfördes inte" % qid)
		assert_gt(GameState.gold, guld_innan, "%s ska dela ut guld" % qid)

func test_beloningsitems_finns_i_databasen():
	for qid in RESCUES:
		var items: Dictionary = QuestSystem.quests[qid].get("rewards", {}).get("items", {})
		for item_id in items:
			assert_true(ItemDB.items.has(String(item_id)),
				"%s belönar med okänt item %s" % [qid, item_id])
