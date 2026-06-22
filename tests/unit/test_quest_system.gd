extends GutTest

var qs

func before_each():
	qs = add_child_autofree(load("res://autoload/quest_system.gd").new())
	GameState.gold = 0
	GameState.inventory.clear()

func test_start_unknown_fails():
	assert_false(qs.start("quest_drake"))

func test_start_and_signal():
	watch_signals(qs)
	assert_true(qs.start("quest_welcome"))
	assert_signal_emitted_with_parameters(qs, "quest_started", ["quest_welcome"])
	assert_eq(int(qs.active["quest_welcome"]["step"]), 0)

func test_start_twice_fails():
	qs.start("quest_welcome")
	assert_false(qs.start("quest_welcome"))

func test_requires_gate():
	assert_false(qs.start("quest_lost_ore"))   # kräver quest_welcome
	qs.completed["quest_welcome"] = true
	assert_true(qs.start("quest_lost_ore"))

func test_giver_marker_start_active_and_clears():
	# quest_snakes ges av npc_hunter, inga krav → startbar från början
	assert_eq(qs.giver_marker("npc_hunter"), "start")
	# Efter start → pågående quest att återvända till
	qs.start("quest_snakes")
	assert_eq(qs.giver_marker("npc_hunter"), "active")
	# Efter slutförande → ingen markör
	for i in 8:
		qs.record_kill("Orm")
	qs.advance_talk("quest_snakes", "npc_hunter")
	assert_eq(qs.giver_marker("npc_hunter"), "")

func test_giver_marker_hidden_until_requirements_met():
	# npc_scholars quests kräver quest_welcome → ingen markör förrän det är klart
	assert_eq(qs.giver_marker("npc_scholar"), "")
	qs.completed["quest_welcome"] = true
	assert_eq(qs.giver_marker("npc_scholar"), "start")   # quest_crypt nu startbar

func test_kill_progress_and_advance():
	qs.start("quest_snakes")
	for i in 8:
		qs.record_kill("Orm")
	assert_eq(int(qs.active["quest_snakes"]["step"]), 1)   # vidare till talk_to

func test_kill_wrong_monster_ignored():
	qs.start("quest_snakes")
	qs.record_kill("Råtta")
	assert_eq(int(qs.active["quest_snakes"]["progress"]), 0)

func test_collect_advances_via_inventory():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)   # inventory_changed → _check_collect
	assert_eq(int(qs.active["quest_lost_ore"]["step"]), 1)

func test_collect_partial_progress():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 2)
	assert_eq(int(qs.active["quest_lost_ore"]["step"]), 0)
	assert_eq(int(qs.active["quest_lost_ore"]["progress"]), 2)

func test_talk_advance_requires_npc_match():
	qs.start("quest_welcome")
	assert_false(qs.advance_talk("quest_welcome", "npc_elder"))      # steg 0 är Brom
	assert_true(qs.advance_talk("quest_welcome", "npc_blacksmith"))
	assert_eq(int(qs.active["quest_welcome"]["step"]), 1)

func test_explore_zone():
	qs.start("quest_welcome")
	qs.advance_talk("quest_welcome", "npc_blacksmith")
	qs.record_explore("forest")
	assert_eq(int(qs.active["quest_welcome"]["step"]), 2)

func test_explore_tile_radius():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(0, 0))
	assert_eq(int(qs.active["quest_crypt"]["step"]), 0)    # för långt bort
	qs.record_position("cave", Vector2i(21, 28))           # inom radie 3 från [20,29]
	assert_eq(int(qs.active["quest_crypt"]["step"]), 1)

func test_use_item_step():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(20, 29))
	qs.record_use("warding_candle")
	assert_eq(int(qs.active["quest_crypt"]["step"]), 2)

func test_use_item_wrong_step_ignored():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_use("warding_candle")    # steg 0 är explore
	assert_eq(int(qs.active["quest_crypt"]["step"]), 0)

func test_completion_rewards_gold():
	qs.start("quest_snakes")
	for i in 8:
		qs.record_kill("Orm")
	watch_signals(qs)
	assert_true(qs.advance_talk("quest_snakes", "npc_hunter"))
	assert_signal_emitted_with_parameters(qs, "quest_completed", ["quest_snakes"])
	assert_false(qs.active.has("quest_snakes"))
	assert_true(qs.completed.has("quest_snakes"))
	assert_eq(GameState.gold, 300)

func test_completion_item_reward():
	qs.completed["quest_welcome"] = true
	qs.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)
	qs.advance_talk("quest_lost_ore", "npc_blacksmith")
	assert_eq(int(GameState.inventory.get("steel_sword", 0)), 1)

func test_use_item_via_gamestate_consumes_and_records():
	qs.completed["quest_welcome"] = true
	qs.start("quest_crypt")
	qs.record_position("cave", Vector2i(20, 29))   # → steg 1 (use_item)
	GameState.add_item("warding_candle", 1)
	# OBS: GameState.use_item anropar det GLOBALA QuestSystem — flytta state dit
	QuestSystem.reset()
	QuestSystem.active["quest_crypt"] = {"step": 1, "progress": 0}
	assert_true(GameState.use_item("warding_candle"))
	assert_eq(int(GameState.inventory.get("warding_candle", 0)), 0)
	assert_eq(int(QuestSystem.active["quest_crypt"]["step"]), 2)
	QuestSystem.reset()

func test_hint_follows_step():
	qs.start("quest_welcome")
	assert_string_contains(qs.hint("quest_welcome"), "Brom")
	qs.advance_talk("quest_welcome", "npc_blacksmith")
	assert_string_contains(qs.hint("quest_welcome"), "forest")
