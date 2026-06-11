extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_xp_for_level():
	assert_eq(gs.xp_for_level(1), 100)   # 50*1*2
	assert_eq(gs.xp_for_level(2), 300)   # 50*2*3

func test_gain_exp_levels_up():
	gs.gain_exp(100)
	assert_eq(gs.level, 2)
	assert_eq(gs.experience, 0)

func test_level_up_raises_stats():
	var hp0 = gs.max_health
	gs.gain_exp(100)
	assert_eq(gs.max_health, hp0 + 25)
	assert_eq(gs.health, gs.max_health)

func test_skill_xp_next_formula():
	assert_eq(gs.skill_xp_next(0), 50)        # 50*1.1^0
	assert_eq(gs.skill_xp_next(10), 129)      # int(50*1.1^10)

func test_gain_skill_xp_levels_skill():
	gs.skills["sword"]["level"] = 0
	gs.skills["sword"]["xp"] = 0
	gs.gain_skill_xp("sword", 50)
	assert_eq(gs.skills["sword"]["level"], 1)

func test_coins_route_to_gold():
	gs.add_item("iron_coin", 5)
	gs.add_item("iron_coin", 3)
	assert_eq(gs.gold, 8)

func test_inventory_add_stacks():
	gs.add_item("bone_chips", 2)
	gs.add_item("bone_chips", 3)
	assert_eq(gs.inventory["bone_chips"], 5)
