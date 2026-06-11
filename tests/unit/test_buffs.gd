extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_apply_buff_adds_to_active():
	gs.apply_buff("skill:mining", 2, 60)
	assert_eq(gs.active_buffs.size(), 1)

func test_same_stat_replaces():
	gs.apply_buff("skill:mining", 2, 60)
	gs.apply_buff("skill:mining", 3, 30)
	assert_eq(gs.active_buffs.size(), 1)
	assert_eq(gs.active_buffs[0]["amount"], 3.0)

func test_effective_skill_level_includes_buff():
	gs.apply_buff("skill:mining", 2, 60)
	assert_eq(gs.effective_skill_level("mining"), 3)   # start 1 + 2
	assert_eq(gs.effective_skill_level("fishing"), 1)  # opåverkad

func test_buff_expires():
	gs.apply_buff("skill:mining", 2, 1.0)
	gs._tick_buffs(1.1)
	assert_eq(gs.active_buffs.size(), 0)
	assert_eq(gs.effective_skill_level("mining"), 1)

func test_regen_heals_over_time():
	gs.health = 100.0
	gs.apply_buff("regen", 2, 10)
	gs._tick_buffs(5.0)
	assert_almost_eq(gs.health, 110.0, 0.01)

func test_use_item_applies_buff_and_consumes():
	gs.add_item("mining_brew", 1)
	assert_true(gs.use_item("mining_brew"))
	assert_eq(gs.active_buffs.size(), 1)
	assert_false(gs.inventory.has("mining_brew"))

func test_use_item_heals():
	gs.health = 50.0
	gs.add_item("health_potion", 1)
	gs.use_item("health_potion")
	assert_eq(gs.health, 110.0)
