extends GutTest

const CF = preload("res://combat/combat_formulas.gd")

func test_max_melee_grows_with_skill():
	var low = CF.max_melee(1, 10, 8)
	var high = CF.max_melee(1, 50, 8)
	assert_gt(high, low)

func test_max_melee_known_value():
	# atk 8, skill 10, level 1: 8*(10+4)/28 + 1/10 = 4.1 -> 4
	assert_eq(CF.max_melee(1, 10, 8), 4)

func test_max_melee_minst_1():
	assert_eq(CF.max_melee(1, 0, 0), 1)

func test_roll_melee_within_bounds():
	for i in 50:
		var d = CF.roll_melee(10, 30, 14)
		assert_between(d, 0, CF.max_melee(10, 30, 14))

func test_mitigate_reduces():
	assert_lt(CF.mitigate(20, 30, 5), 20)

func test_mitigate_never_negative():
	assert_eq(CF.mitigate(1, 200, 50), 0)

func test_monster_roll_within_bounds():
	for i in 50:
		assert_between(CF.roll_monster(18), 0, 18)
