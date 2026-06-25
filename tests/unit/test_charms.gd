extends GutTest
## Charm-systemet: poängekonomi, köp/bär-regler, skadeberäkning och bestiarie-koppling.

var cs

func before_each():
	cs = load("res://autoload/charm_system.gd").new()

func after_each():
	cs.free()

func test_charms_loaded_from_json():
	assert_true(cs.charms.has("wound"))
	assert_eq(String(cs.charms["wound"]["type"]), "offense")
	assert_true(cs.charms.has("dodge"))
	assert_eq(String(cs.charms["dodge"]["type"]), "defense")

func test_award_points_accumulates_and_emits():
	watch_signals(cs)
	cs.award_points(5)
	cs.award_points(10)
	assert_eq(cs.points, 15)
	assert_signal_emitted(cs, "points_changed")

func test_award_non_positive_is_ignored():
	cs.award_points(0)
	cs.award_points(-5)
	assert_eq(cs.points, 0)

func test_cannot_afford_without_points():
	assert_false(cs.can_afford("wound"))
	assert_false(cs.unlock("wound"))
	assert_false(cs.is_unlocked("wound"))

func test_unlock_deducts_points_and_marks_unlocked():
	cs.award_points(100)
	assert_true(cs.unlock("wound"))          # kostar 60
	assert_eq(cs.points, 40)
	assert_true(cs.is_unlocked("wound"))

func test_unlock_twice_fails():
	cs.award_points(200)
	assert_true(cs.unlock("wound"))
	assert_false(cs.unlock("wound"))         # redan köpt
	assert_eq(cs.points, 140)

func test_unlock_unknown_id_fails():
	cs.award_points(1000)
	assert_false(cs.unlock("does_not_exist"))

func test_equip_requires_unlock():
	assert_false(cs.equip("wound"))
	cs.award_points(100)
	cs.unlock("wound")
	assert_true(cs.equip("wound"))
	assert_eq(cs.equipped_offense, "wound")

func test_equip_routes_by_type():
	cs.award_points(500)
	cs.unlock("wound")    # offense
	cs.unlock("parry")    # defense
	cs.equip("wound")
	cs.equip("parry")
	assert_eq(cs.equipped_offense, "wound")
	assert_eq(cs.equipped_defense, "parry")

func test_unequip_clears_slots():
	cs.award_points(500)
	cs.unlock("wound"); cs.unlock("parry")
	cs.equip("wound"); cs.equip("parry")
	cs.unequip_offense()
	cs.unequip_defense()
	assert_eq(cs.equipped_offense, "")
	assert_eq(cs.equipped_defense, "")

func test_offense_damage_is_fraction_of_max_hp():
	# wound = 5 % av max-HP
	assert_eq(cs.offense_damage("wound", 1000.0), 50)
	# curse = 8 %
	assert_eq(cs.offense_damage("curse", 1000.0), 80)

func test_offense_damage_minimum_one():
	assert_eq(cs.offense_damage("wound", 1.0), 1)

func test_defense_reduction_is_fraction_of_incoming():
	# parry mildrar 35 %
	assert_almost_eq(cs.defense_reduction("parry", 100.0), 35.0, 0.001)
	# dodge mildrar 100 %
	assert_almost_eq(cs.defense_reduction("dodge", 100.0), 100.0, 0.001)

func test_roll_offense_none_equipped():
	var r = cs.roll_offense(1000.0)
	assert_false(r["triggered"])

func test_roll_offense_guaranteed_trigger():
	cs.award_points(100); cs.unlock("wound"); cs.equip("wound")
	cs.charms["wound"]["chance"] = 1.0          # tvinga träff
	var r = cs.roll_offense(1000.0)
	assert_true(r["triggered"])
	assert_eq(int(r["amount"]), 50)
	assert_eq(String(r["element"]), "physical")

func test_roll_offense_never_triggers_at_zero_chance():
	cs.award_points(100); cs.unlock("wound"); cs.equip("wound")
	cs.charms["wound"]["chance"] = 0.0
	assert_false(cs.roll_offense(1000.0)["triggered"])

func test_roll_defense_guaranteed_trigger():
	cs.award_points(100); cs.unlock("parry"); cs.equip("parry")
	cs.charms["parry"]["chance"] = 1.0
	var r = cs.roll_defense(100.0)
	assert_true(r["triggered"])
	assert_almost_eq(float(r["prevented"]), 35.0, 0.001)

func test_reset_clears_everything():
	cs.award_points(500); cs.unlock("wound"); cs.equip("wound")
	cs.reset()
	assert_eq(cs.points, 0)
	assert_eq(cs.equipped_offense, "")
	assert_eq(cs.unlocked.size(), 0)

func test_record_kill_awards_charm_points_at_tier():
	CharmSystem.reset()
	var ts = load("res://autoload/task_system.gd").new()
	ts.bestiary["Råtta"] = 99
	ts.record_kill("Råtta")                     # passerar 100 → tier 1
	assert_eq(CharmSystem.points, ts.CHARM_POINTS_PER_TIER[0])
	ts.bestiary["Råtta"] = 399
	ts.record_kill("Råtta")                     # passerar 400 → tier 2
	assert_eq(CharmSystem.points, ts.CHARM_POINTS_PER_TIER[0] + ts.CHARM_POINTS_PER_TIER[1])
	ts.free()
	CharmSystem.reset()

func test_element_colors_are_distinct():
	var phys = cs.element_color("physical")
	var fire = cs.element_color("fire")
	var energy = cs.element_color("energy")
	var death = cs.element_color("death")
	assert_ne(fire, energy)
	assert_ne(fire, death)
	assert_ne(energy, death)
	assert_ne(phys, fire)

func test_unknown_element_falls_back_to_default():
	# Okänt element ska ge samma färg som "physical" (default-grenen).
	assert_eq(cs.element_color("plasma"), cs.element_color("physical"))

func test_offense_roll_element_matches_charm_def():
	cs.award_points(200); cs.unlock("enflame"); cs.equip("enflame")
	cs.charms["enflame"]["chance"] = 1.0
	var r = cs.roll_offense(1000.0)
	assert_eq(String(r["element"]), "fire")
	# elementfärgen som siffran ritas med ska matcha fire-grenen
	assert_eq(cs.element_color(String(r["element"])), cs.element_color("fire"))

func test_unlock_sets_rank_one():
	cs.award_points(100)
	cs.unlock("wound")
	assert_eq(cs.rank("wound"), 1)

func test_unranked_charm_defaults_to_rank_one():
	# Ej köpt charm rapporterar rank 1 (för bakåtkompatibel skadeberäkning).
	assert_eq(cs.rank("wound"), 1)
	assert_almost_eq(cs.effective_value("wound"), float(cs.charms["wound"]["value"]), 0.0001)

func test_upgrade_raises_rank_and_spends_points():
	cs.award_points(1000)
	cs.unlock("wound")                       # kostar 60 → 940 kvar
	var before: int = cs.points
	assert_true(cs.upgrade("wound"))         # rank 1→2, kostar cost*1 = 60
	assert_eq(cs.rank("wound"), 2)
	assert_eq(cs.points, before - 60)

func test_upgrade_cost_scales_with_rank():
	cs.award_points(1000); cs.unlock("wound")
	assert_eq(cs.upgrade_cost("wound"), 60)  # rank 1→2
	cs.upgrade("wound")
	assert_eq(cs.upgrade_cost("wound"), 120) # rank 2→3 = cost*2

func test_cannot_upgrade_past_max_rank():
	cs.award_points(10000); cs.unlock("wound")
	cs.upgrade("wound"); cs.upgrade("wound")
	assert_eq(cs.rank("wound"), cs.MAX_RANK)
	assert_false(cs.can_upgrade("wound"))
	assert_false(cs.upgrade("wound"))

func test_cannot_upgrade_unowned_charm():
	cs.award_points(1000)
	assert_false(cs.can_upgrade("wound"))
	assert_false(cs.upgrade("wound"))

func test_rank_scales_effective_value_and_damage():
	cs.award_points(10000); cs.unlock("wound")
	var base: int = cs.offense_damage("wound", 1000.0)   # rank 1 = 50
	cs.upgrade("wound")                               # rank 2 = ×1.6
	assert_eq(cs.offense_damage("wound", 1000.0), int(round(base * 1.6)))
	cs.upgrade("wound")                               # rank 3 = ×2.4
	assert_eq(cs.offense_damage("wound", 1000.0), int(round(base * 2.4)))

func test_rank_scales_defense_reduction():
	cs.award_points(10000); cs.unlock("numb")        # value 0.20
	var base: float = cs.defense_reduction("numb", 100.0)  # rank 1 = 20
	cs.upgrade("numb")
	assert_almost_eq(cs.defense_reduction("numb", 100.0), base * 1.6, 0.001)

func test_reset_clears_ranks():
	cs.award_points(1000); cs.unlock("wound"); cs.upgrade("wound")
	cs.reset()
	assert_eq(cs.ranks.size(), 0)
	assert_eq(cs.rank("wound"), 1)

func test_leech_charm_configured():
	assert_true(cs.charms.has("leech"))
	assert_eq(String(cs.charms["leech"]["type"]), "offense")
	assert_eq(String(cs.charms["leech"]["element"]), "death")

func test_lifesteal_zero_for_non_leech_charms():
	assert_eq(cs.lifesteal("wound"), 0.0)
	assert_eq(cs.lifesteal("parry"), 0.0)
	assert_eq(cs.lifesteal("does_not_exist"), 0.0)

func test_lifesteal_reads_charm_field():
	assert_almost_eq(cs.lifesteal("leech"), 0.6, 0.0001)

func test_leech_heal_amount_follows_dealt_damage():
	# Läkning = utdelad skada × lifesteal; skadan följer rank.
	cs.award_points(10000); cs.unlock("leech")
	var dealt: int = cs.offense_damage("leech", 1000.0)   # rank 1
	assert_almost_eq(float(dealt) * cs.lifesteal("leech"), float(dealt) * 0.6, 0.001)
	cs.upgrade("leech")                                    # rank 2 → större skada → mer leech
	var dealt2: int = cs.offense_damage("leech", 1000.0)
	assert_gt(dealt2, dealt)

func test_all_charms_have_known_type():
	for id in cs.charms:
		assert_has(["offense", "defense"], String(cs.charms[id].get("type", "")),
			"%s har okänd charm-typ" % id)

func test_element_modifier_defaults_to_normal():
	assert_eq(cs.element_modifier({}, "fire"), 1.0)
	assert_eq(cs.element_modifier({"element_mod": {}}, "fire"), 1.0)
	assert_eq(cs.element_modifier({"element_mod": {"energy": 1.5}}, "fire"), 1.0)

func test_element_modifier_reads_def():
	var def = {"element_mod": {"fire": 0.0, "energy": 1.5, "death": 0.4}}
	assert_eq(cs.element_modifier(def, "fire"), 0.0)
	assert_eq(cs.element_modifier(def, "energy"), 1.5)
	assert_eq(cs.element_modifier(def, "death"), 0.4)

func test_resisted_damage_normal():
	assert_eq(cs.resisted_damage(50, 1.0), 50)

func test_resisted_damage_weak_amplifies():
	assert_eq(cs.resisted_damage(50, 1.5), 75)

func test_resisted_damage_immune_is_zero():
	assert_eq(cs.resisted_damage(50, 0.0), 0)

func test_resisted_damage_resistant_min_one():
	# Kraftig resistens får aldrig nolla ut en träff helt (bara immunitet gör det).
	assert_eq(cs.resisted_damage(1, 0.3), 1)

func test_data_monsters_have_valid_element_mods():
	# Alla element_mod i datan ska peka på kända charm-element.
	var valid := {"fire": true, "energy": true, "death": true, "physical": true}
	var found := 0
	for mname in MonsterDB.monsters:
		var mods = MonsterDB.monsters[mname].get("element_mod", {})
		if mods is Dictionary and not mods.is_empty():
			found += 1
			for el in mods:
				assert_true(valid.has(el), "%s har okänt element: %s" % [mname, el])
	assert_gt(found, 0, "minst ett monster ska ha element_mod")

func test_record_kill_no_points_between_thresholds():
	CharmSystem.reset()
	var ts = load("res://autoload/task_system.gd").new()
	for i in 5:
		ts.record_kill("Råtta")
	assert_eq(CharmSystem.points, 0)
	ts.free()
