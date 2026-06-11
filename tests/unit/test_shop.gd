extends GutTest

var gs

func before_each():
	gs = load("res://autoload/game_state.gd").new()

func after_each():
	gs.free()

func test_buy_deducts_gold_and_adds_item():
	gs.gold = 100
	assert_true(gs.buy_item("pickaxe"))    # value 75
	assert_eq(gs.gold, 25)
	assert_eq(gs.inventory.get("pickaxe", 0), 1)

func test_buy_fails_without_gold():
	gs.gold = 10
	assert_false(gs.buy_item("pickaxe"))
	assert_eq(gs.gold, 10)
	assert_false(gs.inventory.has("pickaxe"))

func test_sell_gives_half_value():
	gs.add_item("copper_ore", 2)           # value 12
	assert_true(gs.sell_item("copper_ore"))
	assert_eq(gs.gold, 6)
	assert_eq(gs.inventory.get("copper_ore", 0), 1)

func test_sell_fails_without_item():
	assert_false(gs.sell_item("copper_ore"))

func test_buy_unknown_item_returns_false():
	gs.gold = 1000
	assert_false(gs.buy_item("finns_inte"))
	assert_eq(gs.gold, 1000)
