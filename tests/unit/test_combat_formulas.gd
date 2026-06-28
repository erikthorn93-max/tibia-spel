extends GutTest

const CF = preload("res://combat/combat_formulas.gd")

# ── Träffchans & undvikande ──

func test_hit_chance_base_when_even():
	assert_almost_eq(CF.hit_chance(20, 20), CF.HIT_BASE, 0.001)

func test_hit_chance_rises_with_accuracy_advantage():
	assert_gt(CF.hit_chance(50, 10), CF.hit_chance(20, 10))

func test_hit_chance_respects_floor_and_ceiling():
	assert_eq(CF.hit_chance(0, 9999), CF.HIT_FLOOR)
	assert_eq(CF.hit_chance(9999, 0), CF.HIT_CEIL)
	for acc in [0, 50, 9999]:
		for eva in [0, 50, 9999]:
			assert_between(CF.hit_chance(acc, eva), CF.HIT_FLOOR, CF.HIT_CEIL)

func test_accuracy_combines_level_and_skill():
	assert_eq(CF.accuracy(10, 30), 40)

func test_faster_monsters_evade_more():
	assert_gt(CF.monster_evasion(3.0), CF.monster_evasion(2.0))

func test_player_evasion_scales_with_agility_and_shielding():
	assert_gt(CF.player_evasion(50, 0), CF.player_evasion(20, 0))
	assert_gt(CF.player_evasion(20, 40), CF.player_evasion(20, 0), "sköld ska bidra")
	assert_gt(CF.player_evasion(40, 0), CF.player_evasion(0, 40),
		"agility ska väga tyngre än sköld")

func test_monster_accuracy_grows_with_atk():
	assert_gt(CF.monster_accuracy(50), CF.monster_accuracy(5))

func test_monster_hit_floor_is_higher_than_player_floor():
	# Monster ska missa mer sällan än spelaren kan — väjning trivialiserar inte faran.
	assert_gt(CF.MONSTER_HIT_FLOOR, CF.HIT_FLOOR)
	assert_eq(CF.hit_chance(0, 9999, CF.MONSTER_HIT_FLOOR), CF.MONSTER_HIT_FLOOR)

func test_custom_floor_does_not_affect_ceiling():
	assert_eq(CF.hit_chance(9999, 0, CF.MONSTER_HIT_FLOOR), CF.HIT_CEIL)

func test_roll_hit_within_chance_band():
	# Över många slag ska träffandelen ligga nära den teoretiska chansen.
	var acc := 30
	var eva := 10
	var hits := 0
	for i in 2000:
		if CF.roll_hit(acc, eva):
			hits += 1
	var rate := float(hits) / 2000.0
	assert_almost_eq(rate, CF.hit_chance(acc, eva), 0.06)

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

# ── Specialattack (kraftslag) ──

func test_max_ranged_is_roll_ranged_ceiling():
	# Toppvärdet ska vara roll_ranged utan ±15%-variationen.
	for i in 50:
		assert_lte(CF.roll_ranged(40, 20), CF.max_ranged(40, 20) * 1.151)

func test_charge_spec_accumulates_and_caps():
	assert_almost_eq(CF.charge_spec(0.0, CF.SPEC_GAIN), CF.SPEC_GAIN, 0.001)
	assert_eq(CF.charge_spec(CF.SPEC_MAX, CF.SPEC_GAIN), CF.SPEC_MAX)   # tak
	assert_eq(CF.charge_spec(50.0, 1000.0), CF.SPEC_MAX)
	assert_eq(CF.charge_spec(0.0, -50.0), 0.0)                          # golv

func test_spec_ready_only_when_full():
	assert_false(CF.spec_ready(CF.SPEC_MAX - 0.1))
	assert_true(CF.spec_ready(CF.SPEC_MAX))

func test_spec_damage_applies_multiplier():
	assert_almost_eq(CF.spec_damage(40.0), 40.0 * CF.SPEC_MULTIPLIER, 0.001)
	assert_gt(CF.SPEC_MULTIPLIER, 1.0, "kraftslaget ska slå hårdare än ett vanligt slag")

func test_spec_damage_custom_mult():
	assert_almost_eq(CF.spec_damage(50.0, 1.8), 90.0, 0.001)

# ── Vapentyps-kraftslag ──

func test_spec_profile_per_weapon_kind():
	assert_eq(String(CF.spec_profile("axe")["kind"]), "cleave")
	assert_eq(String(CF.spec_profile("club")["kind"]), "crush")
	assert_eq(String(CF.spec_profile("distance")["kind"]), "double")
	assert_eq(String(CF.spec_profile("sword")["kind"]), "power")

func test_spec_profile_unknown_weapon_defaults_to_power():
	var p := CF.spec_profile("fist")
	assert_eq(String(p["kind"]), "power")
	assert_almost_eq(float(p["mult"]), CF.SPEC_MULTIPLIER, 0.001)

func test_only_club_stuns():
	assert_gt(float(CF.spec_profile("club")["stun"]), 0.0)
	for w in ["axe", "distance", "sword", "fist"]:
		assert_eq(float(CF.spec_profile(w)["stun"]), 0.0, "%s ska inte bedöva" % w)

func test_all_spec_profiles_have_positive_mult():
	for w in ["axe", "club", "distance", "sword", "fist"]:
		assert_gt(float(CF.spec_profile(w)["mult"]), 0.0)

# ── GameState-integration: laddning & urladdning ──

func test_gamestate_spec_charges_and_consumes():
	GameState.spec_energy = 0.0
	watch_signals(GameState)
	GameState.add_spec(CF.SPEC_GAIN)
	assert_almost_eq(GameState.spec_energy, CF.SPEC_GAIN, 0.001)
	assert_signal_emitted(GameState, "spec_changed")
	assert_false(GameState.consume_spec(), "får inte släppa kraftslag innan mätaren är full")
	GameState.spec_energy = CF.SPEC_MAX
	assert_true(GameState.consume_spec(), "full mätare ska kunna släppas")
	assert_eq(GameState.spec_energy, 0.0, "mätaren ska tömmas av kraftslaget")

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
