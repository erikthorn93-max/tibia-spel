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
