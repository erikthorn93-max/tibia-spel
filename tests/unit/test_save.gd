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

func test_save_version_is_2():
	var sm2 = load("res://autoload/save_manager.gd").new()
	assert_eq(sm2.SAVE_VERSION, 2)
	sm2.free()
