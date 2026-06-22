extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_loads_18_skills_from_json():
	assert_eq(gs.skills.size(), 26)
	assert_eq(gs.skill_defs.size(), 26)

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

func test_gain_skill_xp_emits_skill_leveled_on_levelup():
	watch_signals(gs)
	gs.gain_skill_xp("mining", gs.skill_xp_next(1, "mining"))
	assert_eq(gs.skills["mining"]["level"], 2)
	assert_signal_emitted_with_parameters(gs, "skill_leveled", ["mining", 2])

func test_gain_skill_xp_no_levelup_no_skill_leveled():
	watch_signals(gs)
	gs.gain_skill_xp("mining", 1)   # för lite för att gå upp en nivå
	assert_signal_not_emitted(gs, "skill_leveled")

func test_gain_skill_xp_emits_skill_leveled_once_per_level():
	watch_signals(gs)
	var need: int = gs.skill_xp_next(1, "mining") + gs.skill_xp_next(2, "mining")
	gs.gain_skill_xp("mining", need)
	assert_eq(gs.skills["mining"]["level"], 3)
	assert_eq(get_signal_emit_count(gs, "skill_leveled"), 2)

func test_ensure_all_skills_preserves_existing():
	gs.skills = {"sword": {"level": 25, "xp": 7}}
	gs.ensure_all_skills()
	assert_eq(gs.skills.size(), 26)
	assert_eq(gs.skills["sword"]["level"], 25)
	assert_eq(gs.skills["sword"]["xp"], 7)

func test_skill_xp_next_uses_per_skill_curve():
	assert_eq(gs.skill_xp_next(0, "sword"), 50)        # xp_base 50
	gs.skill_defs["sword"]["xp_base"] = 100.0
	assert_eq(gs.skill_xp_next(0, "sword"), 100)       # per-skill override används

func test_weapon_skill_follows_equipped():
	gs.equipped_weapon = "bronze_axe"
	assert_eq(gs.weapon_skill(), "axe")
	gs.equipped_weapon = "wooden_club"
	assert_eq(gs.weapon_skill(), "club")

func test_weapon_skill_fist_when_unarmed():
	gs.equipped_weapon = ""
	assert_eq(gs.weapon_skill(), "fist")

func test_equip_swaps_with_inventory():
	gs.equipped_weapon = "rusty_sword"
	gs.add_item("bronze_axe", 1)
	assert_true(gs.equip_weapon("bronze_axe"))
	assert_eq(gs.equipped_weapon, "bronze_axe")
	assert_eq(gs.inventory.get("rusty_sword", 0), 1)
	assert_false(gs.inventory.has("bronze_axe"))

func test_unequip_returns_weapon_to_inventory():
	gs.equipped_weapon = "rusty_sword"
	gs.unequip_weapon()
	assert_eq(gs.equipped_weapon, "")
	assert_eq(gs.inventory.get("rusty_sword", 0), 1)

func test_equip_same_weapon_does_not_duplicate():
	gs.equipped_weapon = "rusty_sword"
	assert_true(gs.equip_weapon("rusty_sword"))
	assert_eq(gs.equipped_weapon, "rusty_sword")
	assert_false(gs.inventory.has("rusty_sword"))
