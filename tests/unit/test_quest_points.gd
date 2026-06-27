extends GutTest
## Questpoäng (OSRS-stil) och Questkappan: poäng härleds ur svårigheten, total
## summeras över klarade quests, och Questkappan låses upp först när ALLA är
## klara. Använder riktiga QuestSystem/UnlockSystem — spara/återställ globalt.

var _saved_completed: Dictionary
var _saved_unlocked: Dictionary

func before_each():
	_saved_completed = QuestSystem.completed.duplicate(true)
	_saved_unlocked = UnlockSystem.unlocked.duplicate(true)
	QuestSystem.completed.clear()
	UnlockSystem.unlocked.clear()

func after_each():
	QuestSystem.completed = _saved_completed
	UnlockSystem.unlocked = _saved_unlocked

func _complete_all():
	for id in QuestSystem.quests:
		QuestSystem.completed[id] = true

# ── Poäng per quest ────────────────────────────────────────────────────────

func test_quest_points_harleds_ur_svarighet():
	assert_eq(QuestSystem.quest_points("quest_welcome"), 1, "Nybörjare = 1 qp")
	assert_eq(QuestSystem.quest_points("quest_guild_paladin"), 3, "Svår = 3 qp")
	assert_eq(QuestSystem.quest_points("quest_thais_hero"), 5, "Mästare = 5 qp")

func test_total_quest_points_summerar_klarade():
	QuestSystem.completed["quest_welcome"] = true        # 1
	QuestSystem.completed["quest_guild_paladin"] = true  # 3
	assert_eq(QuestSystem.total_quest_points(), 4)

func test_max_quest_points_summerar_alla():
	assert_eq(QuestSystem.total_quest_points(), 0, "inga klarade => 0")
	assert_gt(QuestSystem.max_quest_points(), QuestSystem.total_quest_points(),
		"maxpoäng ska överstiga 0 när quests finns")

# ── Questkappan ────────────────────────────────────────────────────────────

func test_all_completed_falskt_initialt():
	assert_false(QuestSystem.all_completed())

func test_all_completed_sant_nar_alla_klara():
	_complete_all()
	assert_true(QuestSystem.all_completed())

func test_questkappan_last_tills_alla_klara():
	assert_false(UnlockSystem.try_unlock("outfit_questcape"),
		"Questkappan ska vara låst innan allt är klart")
	_complete_all()
	assert_true(UnlockSystem.try_unlock("outfit_questcape"),
		"Questkappan ska kunna låsas upp när allt är klart")

func test_try_unlock_all_beviljar_questkappan_vid_full_completion():
	_complete_all()
	UnlockSystem.try_unlock_all()
	assert_true(UnlockSystem.is_unlocked("outfit_questcape"),
		"try_unlock_all ska bevilja Questkappan när alla quests är klara")

func test_questkappan_finns_som_outfit_och_unlock():
	assert_true(GameState.outfit_defs.has("outfit_questcape"), "Questkappan saknas i outfits")
	assert_true(UnlockSystem.defs.has("outfit_questcape"), "Questkappan saknas i unlocks")
