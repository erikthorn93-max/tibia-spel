extends GutTest

var ts

func before_each():
	ts = load("res://autoload/task_system.gd").new()
	GameState.skills["slayer"] = {"level": 1, "xp": 0}
	GameState.gold = 0
	UnlockSystem.unlocked.clear()

func after_each():
	ts.free()

func _set_slayer(lvl: int) -> void:
	GameState.skills["slayer"] = {"level": lvl, "xp": 0}

func _finish(task_id: String) -> void:
	var def: Dictionary = ts.tasks[task_id]
	for i in int(def["required"]):
		ts.record_kill(String(def["monster"]))

func test_take_requires_slayer_level():
	assert_false(ts.take_task("task_ghoul"))   # kräver Slayer 10
	_set_slayer(10)
	assert_true(ts.take_task("task_ghoul"))

func test_take_unknown_task_fails():
	assert_false(ts.take_task("task_drake"))

func test_take_same_task_twice_fails():
	assert_true(ts.take_task("task_ratta"))
	assert_false(ts.take_task("task_ratta"))

func test_slots_limit_enforced():
	assert_true(ts.take_task("task_ratta"))    # slayer 1 -> 1 slot
	assert_false(ts.take_task("task_orm"))
	_set_slayer(15)                            # 2 slots
	assert_true(ts.take_task("task_orm"))

func test_slots_progression():
	assert_eq(ts.slots(), 1)
	_set_slayer(15)
	assert_eq(ts.slots(), 2)
	_set_slayer(30)
	assert_eq(ts.slots(), 3)

func test_abandon_resets_progress():
	ts.take_task("task_ratta")
	ts.record_kill("Råtta")
	assert_eq(int(ts.active["task_ratta"]), 1)
	ts.abandon_task("task_ratta")
	assert_false(ts.active.has("task_ratta"))
	ts.take_task("task_ratta")
	assert_eq(int(ts.active["task_ratta"]), 0)

func test_record_kill_only_counts_active_task():
	ts.record_kill("Råtta")
	ts.take_task("task_ratta")
	ts.record_kill("Råtta")
	assert_eq(int(ts.active["task_ratta"]), 1)

func test_task_completed_signal_at_required():
	ts.take_task("task_ratta")
	watch_signals(ts)
	_finish("task_ratta")
	assert_signal_emitted_with_parameters(ts, "task_completed", ["task_ratta"])
	assert_true(ts.is_task_done("task_ratta"))

func test_claim_gives_xp_gold_and_unlock():
	_set_slayer(40)   # högt: 400 XP räcker inte för level-up -> xp kan asserteras rakt
	ts.take_task("task_spindel")
	_finish("task_spindel")
	assert_true(ts.claim_reward("task_spindel"))
	assert_eq(GameState.gold, 500)
	assert_eq(int(GameState.skills["slayer"]["xp"]), 400)
	assert_true(UnlockSystem.is_unlocked("spindelhalan"))
	assert_false(ts.active.has("task_spindel"))

func test_claim_unfinished_fails():
	ts.take_task("task_ratta")
	assert_false(ts.claim_reward("task_ratta"))

func test_repeat_gives_half_reward_no_new_unlock():
	_set_slayer(40)
	ts.take_task("task_spindel")
	_finish("task_spindel")
	ts.claim_reward("task_spindel")
	watch_signals(UnlockSystem)
	ts.take_task("task_spindel")
	_finish("task_spindel")
	assert_true(ts.claim_reward("task_spindel"))
	assert_eq(GameState.gold, 750)                            # 500 + 250
	assert_eq(int(GameState.skills["slayer"]["xp"]), 600)     # 400 + 200
	assert_signal_emit_count(UnlockSystem, "unlock_added", 0)

func test_no_slayer_xp_outside_claim_and_boss():
	_set_slayer(40)
	ts.take_task("task_ratta")
	for i in 10:
		ts.record_kill("Råtta")
	assert_eq(int(GameState.skills["slayer"]["xp"]), 0)

func test_boss_gate_opens_after_ghoul_and_fantom():
	_set_slayer(40)
	ts.take_task("task_ghoul")
	_finish("task_ghoul")
	ts.claim_reward("task_ghoul")
	assert_false(UnlockSystem.is_unlocked("bossrummet"))
	ts.take_task("task_fantom")
	_finish("task_fantom")
	ts.claim_reward("task_fantom")
	assert_true(UnlockSystem.is_unlocked("bossrummet"))
