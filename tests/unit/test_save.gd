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
	# Alla definierade skills ska finnas efter migrering (dynamiskt mot skills.json)
	assert_eq(gs.skills.size(), gs.skill_defs.size())
	assert_eq(gs.skills["sword"]["level"], 22)
	assert_eq(gs.skills["mining"]["level"], 1)
	gs.free()

func test_save_version_is_14():
	var sm2 = load("res://autoload/save_manager.gd").new()
	assert_eq(sm2.SAVE_VERSION, 14)
	sm2.free()

func test_charms_survive_roundtrip():
	CharmSystem.reset()
	CharmSystem.award_points(200)
	CharmSystem.unlock("wound")
	CharmSystem.equip("wound")
	CharmSystem.unlock("parry")
	CharmSystem.equip("parry")
	var pts := CharmSystem.points
	sm.save_game()
	CharmSystem.reset()
	assert_true(sm.load_game())
	assert_eq(CharmSystem.points, pts)
	assert_true(CharmSystem.is_unlocked("wound"))
	assert_eq(CharmSystem.equipped_offense, "wound")
	assert_eq(CharmSystem.equipped_defense, "parry")
	CharmSystem.reset()

func test_old_save_without_charms_defaults_empty():
	CharmSystem.reset()
	CharmSystem.award_points(50)
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("charm_points")
	s.erase("charms_unlocked")
	s.erase("charm_offense")
	s.erase("charm_defense")
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(CharmSystem.points, 0)
	assert_eq(CharmSystem.unlocked.size(), 0)
	assert_eq(CharmSystem.equipped_offense, "")

func test_grave_survives_roundtrip():
	GameState.set_grave("cave", Vector2i(7, 3), [{"item": "bone_chips", "qty": 5}])
	sm.save_game()
	GameState.clear_grave()
	assert_true(sm.load_game())
	assert_eq(GameState.grave_zone, "cave")
	assert_eq(GameState.grave_tile, Vector2i(7, 3))
	assert_eq(int(GameState.grave_drops[0]["qty"]), 5)
	assert_true(GameState.has_grave())

func test_old_save_without_grave_has_none():
	GameState.set_grave("cave", Vector2i(1, 1), [{"item": "gold_coin", "qty": 1}])
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("grave_zone")
	s.erase("grave_tile")
	s.erase("grave_drops")
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_false(GameState.has_grave())
	assert_eq(GameState.grave_zone, "")

func test_blessings_survive_roundtrip():
	GameState.blessings = 3
	sm.save_game()
	GameState.blessings = 0
	assert_true(sm.load_game())
	assert_eq(GameState.blessings, 3)

func test_old_save_without_blessings_defaults_to_zero():
	GameState.blessings = 4
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("blessings")   # gammal save saknar fältet
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(GameState.blessings, 0)

func test_home_point_survives_roundtrip():
	GameState.home_zone = "frodo_inn"
	GameState.home_tile = Vector2i(4, 8)
	sm.save_game()
	GameState.home_zone = "town"
	GameState.home_tile = Vector2i(-1, -1)
	assert_true(sm.load_game())
	assert_eq(GameState.home_zone, "frodo_inn")
	assert_eq(GameState.home_tile, Vector2i(4, 8))

func test_old_save_without_home_defaults_to_town():
	GameState.home_zone = "frodo_inn"
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("home_zone")   # gammal save saknar fältet
	s.erase("home_tile")
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(GameState.home_zone, "town")
	assert_eq(GameState.home_tile, Vector2i(-1, -1))

func test_satiation_survives_roundtrip():
	GameState.satiation = 234.0
	sm.save_game()
	GameState.satiation = 0.0
	assert_true(sm.load_game())
	assert_almost_eq(GameState.satiation, 234.0, 0.01)

func test_old_save_without_satiation_defaults_to_zero():
	GameState.satiation = 999.0
	sm.save_game()
	var s: Dictionary = sm.read_snapshot()
	s.erase("satiation")   # gammal save saknar fältet
	sm.write_snapshot(s)
	assert_true(sm.load_game())
	assert_eq(GameState.satiation, 0.0)

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
	var s: Dictionary = sm.read_snapshot()
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

func test_v4_roundtrip_quests():
	QuestSystem.reset()
	QuestSystem.active["quest_welcome"] = {"step": 1, "progress": 0}
	QuestSystem.completed["quest_snakes"] = true
	sm.save_game()
	QuestSystem.reset()
	assert_true(sm.load_game())
	assert_true(QuestSystem.active.has("quest_welcome"))
	assert_eq(int(QuestSystem.active["quest_welcome"]["step"]), 1)
	assert_true(QuestSystem.completed.has("quest_snakes"))
	QuestSystem.reset()
