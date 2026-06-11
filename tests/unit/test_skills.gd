extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_loads_18_skills_from_json():
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skill_defs.size(), 18)

func test_start_levels():
	assert_eq(gs.skills["sword"]["level"], 10)
	assert_eq(gs.skills["shielding"]["level"], 10)
	assert_eq(gs.skills["mining"]["level"], 1)

func test_categories():
	assert_eq(gs.skill_defs["mining"]["category"], "gathering")
	assert_eq(gs.skill_defs["smithing"]["category"], "crafting")
	assert_eq(gs.skill_defs["slayer"]["category"], "utility")

func test_gain_skill_xp_emits_skill_changed():
	watch_signals(gs)
	gs.gain_skill_xp("mining", 10)
	assert_signal_emitted_with_parameters(gs, "skill_changed", ["mining"])

func test_ensure_all_skills_preserves_existing():
	gs.skills = {"sword": {"level": 25, "xp": 7}}
	gs.ensure_all_skills()
	assert_eq(gs.skills.size(), 18)
	assert_eq(gs.skills["sword"]["level"], 25)
	assert_eq(gs.skills["sword"]["xp"], 7)
