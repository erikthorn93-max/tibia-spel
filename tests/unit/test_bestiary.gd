extends GutTest

var ts

func before_each():
	ts = load("res://autoload/task_system.gd").new()
	GameState.skills["slayer"] = {"level": 40, "xp": 0}

func after_each():
	ts.free()

func test_kills_counted_without_active_task():
	for i in 5:
		ts.record_kill("Orm")
	assert_eq(int(ts.bestiary["Orm"]), 5)

func test_bestiary_changed_emitted():
	watch_signals(ts)
	ts.record_kill("Orm")
	assert_signal_emitted(ts, "bestiary_changed")

func test_tier_thresholds():
	assert_eq(ts.tier("Råtta"), 0)
	ts.bestiary["Råtta"] = 99
	assert_eq(ts.tier("Råtta"), 0)
	ts.bestiary["Råtta"] = 100
	assert_eq(ts.tier("Råtta"), 1)
	ts.bestiary["Råtta"] = 400
	assert_eq(ts.tier("Råtta"), 2)
	ts.bestiary["Råtta"] = 1000
	assert_eq(ts.tier("Råtta"), 3)

func test_damage_multiplier_per_tier():
	assert_almost_eq(ts.damage_multiplier("Okänd"), 1.0, 0.001)
	ts.bestiary["Orm"] = 150
	assert_almost_eq(ts.damage_multiplier("Orm"), 1.02, 0.001)
	ts.bestiary["Orm"] = 450
	assert_almost_eq(ts.damage_multiplier("Orm"), 1.04, 0.001)
	ts.bestiary["Orm"] = 1200
	assert_almost_eq(ts.damage_multiplier("Orm"), 1.06, 0.001)

func test_boss_kill_gives_slayer_xp_and_cooldown():
	ts.record_kill("Ghulkungen")
	assert_eq(int(GameState.skills["slayer"]["xp"]), ts.BOSS_SLAYER_XP)
	assert_false(ts.boss_available("Ghulkungen"))
	assert_gt(ts.boss_cooldown_left("Ghulkungen"), 3500.0)

func test_boss_available_when_never_killed():
	assert_true(ts.boss_available("Ghulkungen"))
	assert_eq(ts.boss_cooldown_left("Ghulkungen"), 0.0)

func test_non_boss_kill_gives_no_slayer_xp():
	ts.record_kill("Ghoul")
	assert_eq(int(GameState.skills["slayer"]["xp"]), 0)
	assert_true(ts.boss_available("Ghoul"))
