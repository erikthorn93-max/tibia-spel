extends GutTest

var sm

func before_each():
	sm = load("res://autoload/save_manager.gd").new()
	sm.save_path = "user://test_save.json"

func after_each():
	sm.free()
	DirAccess.remove_absolute("user://test_save.json")

func test_roundtrip_preserves_state():
	var snap = {"version": 1, "level": 7, "gold": 123, "inventory": {"bone_chips": 4},
		"skills": {"sword": {"level": 22, "xp": 10}}, "zone": "cave"}
	sm.write_snapshot(snap)
	var loaded = sm.read_snapshot()
	assert_eq(int(loaded["level"]), 7)
	assert_eq(int(loaded["gold"]), 123)
	assert_eq(int(loaded["inventory"]["bone_chips"]), 4)
	assert_eq(loaded["zone"], "cave")

func test_read_missing_returns_empty():
	assert_eq(sm.read_snapshot(), {})

func test_v1_snapshot_migrates_to_all_skills():
	var gs = load("res://autoload/game_state.gd").new()
	gs.skills = {"sword": {"level": 22, "xp": 10}, "shielding": {"level": 14, "xp": 0}}
	gs.ensure_all_skills()
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skills["sword"]["level"], 22)
	assert_eq(gs.skills["mining"]["level"], 1)
	gs.free()

func test_save_version_is_5():
	var sm2 = load("res://autoload/save_manager.gd").new()
	assert_eq(sm2.SAVE_VERSION, 5)
	sm2.free()

func test_v4_save_migrates_to_v5_standard_outfit():
	GameState.outfit_equipped = "standard"
	GameState.appearance_base = {}
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("outfit_equipped")
	s.erase("appearance_base")
	s["version"] = 4
	s["appearance"] = {"skin": "#aa0000", "hair": "#0000aa", "shirt": "#00aa00", "pants": "#aaaa00"}
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(GameState.outfit_equipped, "standard")
	# basen sätts från appearance så standard alltid kan återställas
	assert_eq(String(GameState.appearance_base["shirt"]), "#00aa00")

func test_v5_roundtrip_outfit_and_base():
	UnlockSystem.unlocked["outfit_slayer"] = true
	GameState.appearance = {"skin": "#e0b894", "hair": "#332211", "shirt": "#2e4dc0", "pants": "#1a1a52"}
	GameState.appearance_base = {}
	GameState.equip_outfit("outfit_slayer")
	sm.save_game()
	GameState.equip_outfit("standard")
	GameState.outfit_equipped = "standard"
	assert_true(sm.load_game())
	assert_eq(GameState.outfit_equipped, "outfit_slayer")
	assert_eq(String(GameState.appearance_base["shirt"]), "#2e4dc0")
	assert_eq(String(GameState.appearance["shirt"]), "#5a1f1f")
	UnlockSystem.unlocked.clear()
	GameState.equip_outfit("standard")

func test_save_in_dungeon_writes_surface_zone():
	var prev_zone := GameState.current_zone
	GameState.current_zone = "dungeon:katakomber"
	World.last_surface_zone = "cave"
	World.last_surface_tile = Vector2i(5, 10)
	sm.save_game()
	var s := sm.read_snapshot()
	assert_eq(String(s["zone"]), "cave")
	assert_eq(int(s["tile"][0]), 5)
	assert_eq(int(s["tile"][1]), 10)
	GameState.current_zone = prev_zone

func _clear_task_state():
	TaskSystem.reset()
	UnlockSystem.unlocked.clear()

func test_v2_snapshot_loads_with_empty_task_defaults():
	_clear_task_state()
	sm.write_snapshot({"version": 2, "level": 3, "experience": 10, "xp_to_next": 100,
		"health": 100, "max_health": 100, "mana": 50, "max_mana": 50,
		"gold": 5, "inventory": {}, "skills": {"sword": {"level": 10, "xp": 0}},
		"appearance": {"skin": "#e0b894", "hair": "#332211", "shirt": "#2e4dc0", "pants": "#1a1a52"},
		"zone": "town", "tile": [3, 3]})
	assert_true(sm.load_game())
	assert_eq(TaskSystem.active, {})
	assert_eq(TaskSystem.completed, {})
	assert_eq(TaskSystem.bestiary, {})
	assert_eq(UnlockSystem.unlocked, {})

func test_v3_roundtrip_preserves_task_state():
	_clear_task_state()
	TaskSystem.active = {"task_ratta": 12}
	TaskSystem.completed = {"task_orm": true}
	TaskSystem.bestiary = {"Råtta": 150}
	TaskSystem.boss_kill_times = {"Ghulkungen": 1700000000.0}
	UnlockSystem.unlocked = {"spindelhalan": true}
	sm.save_game()   # sm har testsökvägen; tillstånd läses från autoloads
	_clear_task_state()
	assert_true(sm.load_game())
	assert_eq(int(TaskSystem.active["task_ratta"]), 12)
	assert_true(TaskSystem.completed.has("task_orm"))
	assert_eq(int(TaskSystem.bestiary["Råtta"]), 150)
	assert_true(UnlockSystem.is_unlocked("spindelhalan"))
	assert_true(TaskSystem.boss_kill_times.has("Ghulkungen"))
	_clear_task_state()

func test_v3_save_migrates_to_v4_empty_quests():
	_clear_task_state()
	QuestSystem.reset()
	QuestSystem.active["quest_welcome"] = {"step": 1, "progress": 0}
	QuestSystem.completed["quest_snakes"] = true
	sm.save_game()
	# v3-snapshot saknar quests-fälten helt
	var s = sm.read_snapshot()
	s.erase("quests_active")
	s.erase("quests_completed")
	s["version"] = 3
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(QuestSystem.active.size(), 0)
	assert_eq(QuestSystem.completed.size(), 0)
	QuestSystem.reset()

func test_v4_roundtrip_qu