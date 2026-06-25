extends GutTest
## Testar att utrustningsbonusar (atk_bonus, def_bonus, speed_bonus) aggregeras
## och matar in i stridsmekaniken — tidigare var fälten enbart kosmetiska.

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# --- total_atk_bonus() ---

func test_atk_bonus_zero_with_starting_gear() -> void:
	assert_eq(gs.total_atk_bonus(), 0, "rusty_sword har ingen atk_bonus")

func test_atk_bonus_dragon_blade() -> void:
	gs.equipment["weapon"] = "drakvapen"
	assert_eq(gs.total_atk_bonus(), 38, "Drakklinga ger +38 atk_bonus")

func test_atk_bonus_summed_across_slots() -> void:
	# obsidian_blade (28) i weapon — bonusen summeras oavsett slot
	gs.equipment["weapon"] = "obsidian_blade"
	assert_eq(gs.total_atk_bonus(), 28)

# --- total_def_bonus() ---

func test_def_bonus_zero_without_leather() -> void:
	assert_eq(gs.total_def_bonus(), 0)

func test_def_bonus_full_leather_set() -> void:
	gs.equipment["helmet"] = "leather_cap"   # 2
	gs.equipment["body"] = "leather_vest"    # 5
	gs.equipment["legs"] = "leather_legs"    # 3
	gs.equipment["boots"] = "leather_boots"  # 2
	assert_eq(gs.total_def_bonus(), 12)

func test_def_bonus_independent_from_total_armor() -> void:
	# Läderrustning har def_bonus men inget armor-fält
	gs.equipment["body"] = "leather_vest"
	assert_eq(gs.total_armor(), 0, "läderväst saknar armor-fält")
	assert_eq(gs.total_def_bonus(), 5)

# --- total_speed_bonus() ---

func test_speed_bonus_zero_with_starting_gear() -> void:
	assert_almost_eq(gs.total_speed_bonus(), 0.0, 0.001)

func test_speed_bonus_pharaohs_scepter() -> void:
	gs.equipment["weapon"] = "pharaohs_scepter"
	assert_almost_eq(gs.total_speed_bonus(), 0.3, 0.001)

# --- total_crit_bonus() ---

func test_crit_bonus_zero_with_starting_gear() -> void:
	assert_almost_eq(gs.total_crit_bonus(), 0.0, 0.001, "startgear ger ingen crit-bonus")

func test_crit_bonus_feeds_crit_chance() -> void:
	# Utan crit-fält på gear ska crit_chance vara grundchansen för skill 0.
	var chance := CombatFormulas.crit_chance(0, gs.total_crit_bonus())
	assert_almost_eq(chance, CombatFormulas.CRIT_BASE_CHANCE, 0.0001)

# --- Integration: endgame-vapen blir verkligt vassare ---

func test_dragon_blade_outdamages_rusty_default() -> void:
	# Endgame-vapnet saknar atk-fält (default 5); atk_bonus måste lyfta skadan.
	gs.equipment["weapon"] = "drakvapen"
	var base_atk := 5
	var effective_atk: int = base_atk + gs.total_atk_bonus()   # 5 + 38 = 43
	var dragon_max := CombatFormulas.max_melee(gs.level, 10, effective_atk)
	var bare_max := CombatFormulas.max_melee(gs.level, 10, base_atk)
	assert_gt(dragon_max, bare_max,
		"Drakklingans atk_bonus måste ge mer skada än bara default-atk")
