extends GutTest

var us

func before_each():
	us = load("res://autoload/unlock_system.gd").new()

func after_each():
	us.free()

func test_starts_empty():
	assert_eq(us.unlocked.size(), 0)
	assert_false(us.is_unlocked("spindelhalan"))

func test_unlock_sets_and_emits():
	watch_signals(us)
	us.unlock("spindelhalan")
	assert_true(us.is_unlocked("spindelhalan"))
	assert_signal_emitted_with_parameters(us, "unlock_added", ["spindelhalan"])

func test_unlock_idempotent():
	watch_signals(us)
	us.unlock("kryptan")
	us.unlock("kryptan")
	assert_signal_emit_count(us, "unlock_added", 1)
	assert_eq(us.unlocked.size(), 1)

func test_defs_loaded():
	assert_true(us.defs.has("genvag_stenarna"))
	assert_eq(String(us.defs["genvag_stenarna"]["category"]), "shortcut")

func test_can_unlock_skill_requirement():
	GameState.skills["agility"] = {"level": 9, "xp": 0}
	assert_false(us.can_unlock("genvag_stenarna"))
	GameState.skills["agility"] = {"level": 10, "xp": 0}
	assert_true(us.can_unlock("genvag_stenarna"))
	GameState.skills["agility"] = {"level": 1, "xp": 0}

func test_can_unlock_skill_counts_buffs():
	GameState.skills["agility"] = {"level": 8, "xp": 0}
	GameState.apply_buff("skill:agility", 2, 60.0)
	assert_true(us.can_unlock("genvag_stenarna"))
	GameState.active_buffs.clear()
	GameState.skills["agility"] = {"level": 1, "xp": 0}

func test_can_unlock_quest_requirement():
	QuestSystem.reset()
	assert_false(us.can_unlock("trasket"))
	QuestSystem.completed["quest_crypt"] = true
	assert_true(us.can_unlock("trasket"))
	QuestSystem.reset()

func test_can_unlock_task_requirement():
	TaskSystem.completed.clear()
	assert_false(us.can_unlock("outfit_slayer"))
	TaskSystem.completed["task_ghoul"] = true
	assert_true(us.can_unlock("outfit_slayer"))
	TaskSystem.completed.clear()

func test_can_unlock_boss_requirement():
	TaskSystem.boss_kill_times.clear()
	assert_false(us.can_unlock("outfit_ghoul_king"))
	TaskSystem.boss_kill_times["Ghulkungen"] = 12345
	assert_true(us.can_unlock("outfit_ghoul_king"))
	TaskSystem.boss_kill_times.clear()

func test_can_unlock_empty_requires_is_false():
	# tomma krav = ges av extern källa (task-claim) — kan inte själv-upplåsas
	assert_false(us.can_unlock("spindelhalan"))

func test_try_unlock_grants_and_is_idempotent():
	QuestSystem.completed["quest_crypt"] = true
	watch_signals(us)
	assert_true(us.try_unlock("trasket"))
	assert_true(us.is_unlocked("trasket"))
	assert_true(us.try_unlock("trasket"))   # redan upplåst = true, ingen ny signal
	assert_signal_emit_count(us, "unlock_added", 1)
	QuestSystem.reset()

func test_try_unlock_fails_when_requirements_unmet():
	QuestSystem.reset()
	assert_false(us.try_unlock("trasket"))
	assert_false(us.is_unlocked("trasket"))

func test_display_name_and_hint():
	assert_eq(us.display_name("trasket"), "Träsket")
	assert_eq(us.display_name("okant_id"), "okant_id")
	assert_string_contains(us.hint_for("genvag_stenarna"), "Agility 10")
	assert_eq(us.hint_for("okant_id"), "")
