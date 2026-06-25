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

# --- kritiska träffar ---

func test_crit_chance_grows_with_skill():
	assert_gt(CF.crit_chance(80), CF.crit_chance(0), "högre skill → högre crit-chans")

func test_crit_chance_base_value():
	# skill 0, ingen bonus → grundchansen
	assert_almost_eq(CF.crit_chance(0), CF.CRIT_BASE_CHANCE, 0.0001)

func test_crit_chance_skill_scaling():
	# skill 50: 0.05 + 50*0.002 = 0.15
	assert_almost_eq(CF.crit_chance(50), 0.15, 0.0001)

func test_crit_chance_includes_bonus():
	assert_almost_eq(CF.crit_chance(0, 0.10), CF.CRIT_BASE_CHANCE + 0.10, 0.0001)

func test_crit_chance_capped():
	assert_almost_eq(CF.crit_chance(100000, 5.0), CF.CRIT_MAX_CHANCE, 0.0001, "crit-chans har ett tak")

func test_crit_chance_never_negative():
	assert_gte(CF.crit_chance(0, -10.0), 0.0)

func test_roll_crit_true_when_guaranteed():
	# 100 % bonus → alltid crit (klamppas till CRIT_MAX, som är > 0)
	var any_true := false
	for i in 50:
		if CF.roll_crit(0, 5.0):
			any_true = true
	assert_true(any_true, "med maxchans ska crit inträffa")

func test_roll_crit_false_when_impossible():
	# negativ bonus större än grundchansen → 0 % → aldrig crit
	for i in 50:
		assert_false(CF.roll_crit(0, -1.0))
