extends GutTest
## M11: Testar bågskjutning — roll_ranged() + item-fält.

# --- roll_ranged ---

func test_roll_ranged_returnerar_positivt() -> void:
	var dmg := CombatFormulas.roll_ranged(1, 12)
	assert_gt(dmg, 0.0, "skada ska vara positiv")

func test_roll_ranged_okar_med_hogre_skill() -> void:
	# distance 20 vs distance 1 — aldrig överlappande
	var low  := CombatFormulas.roll_ranged(1,  12)
	var high := CombatFormulas.roll_ranged(20, 12)
	# Deterministisk egenskap: max(low) = (12+1*0.4)*1.15 = 14.26
	#                          min(high) = (12+20*0.4)*0.85 = 17.0
	# Kör många gånger och kontrollera medelvärde
	var sum_low := 0.0; var sum_high := 0.0
	for i in 200:
		sum_low  += CombatFormulas.roll_ranged(1,  12)
		sum_high += CombatFormulas.roll_ranged(20, 12)
	assert_gt(sum_high / 200.0, sum_low / 200.0,
		"distance 20 ska ge högre snittskada än distance 1")

func test_roll_ranged_inom_rimligt_intervall() -> void:
	# roll_ranged(10, 12): base = 12+4 = 16, range [16*0.85, 16*1.15] = [13.6, 18.4]
	for i in 100:
		var dmg := CombatFormulas.roll_ranged(10, 12)
		assert_gte(dmg, 13.5, "skada ska vara ≥ min")
		assert_lte(dmg, 18.5, "skada ska vara ≤ max")

# --- items.json ---

func test_hunting_bow_finns() -> void:
	var d: Dictionary = ItemDB.items.get("hunting_bow", {})
	assert_false(d.is_empty(), "hunting_bow ska finnas i items.json")

func test_hunting_bow_har_range() -> void:
	var d: Dictionary = ItemDB.items.get("hunting_bow", {})
	assert_eq(int(d.get("range", 0)), 4, "range ska vara 4")

func test_hunting_bow_anvander_distance_skill() -> void:
	var d: Dictionary = ItemDB.items.get("hunting_bow", {})
	assert_eq(String(d.get("skill", "")), "distance")

func test_hunting_bow_kräver_pilar() -> void:
	var d: Dictionary = ItemDB.items.get("hunting_bow", {})
	assert_eq(String(d.get("ammo", "")), "wooden_arrow")

func test_wooden_arrow_finns() -> void:
	var d: Dictionary = ItemDB.items.get("wooden_arrow", {})
	assert_false(d.is_empty(), "wooden_arrow ska finnas")

func test_narsridsvapen_har_range_1_eller_saknas() -> void:
	# rusty_sword ska INTE ha range-fält (eller range=1)
	var d: Dictionary = ItemDB.items.get("rusty_sword", {})
	var r := int(d.get("range", 1))
	assert_lte(r, 1, "svärd ska ha range ≤ 1")

func test_distance_skill_finns() -> void:
	var d: Dictionary = GameState.skill_defs.get("distance", {})
	assert_false(d.is_empty(), "distance skill ska finnas i skills.json")
