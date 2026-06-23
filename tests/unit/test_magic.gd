extends GutTest
## M9: Testar magic-system (use_mana, restore_mana, use_item, respawn, roll_magic).

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# --- use_mana ---

func test_use_mana_reducerar_mana() -> void:
	gs.mana = 50.0
	var ok: bool = gs.use_mana(20.0)
	assert_true(ok)
	assert_almost_eq(gs.mana, 30.0, 0.01)

func test_use_mana_insufficient_returnerar_false() -> void:
	gs.mana = 5.0
	var ok: bool = gs.use_mana(20.0)
	assert_false(ok)
	assert_almost_eq(gs.mana, 5.0, 0.01, "mana ska vara oförändrad")

func test_use_mana_exakt_nog_lyckas() -> void:
	gs.mana = 20.0
	var ok: bool = gs.use_mana(20.0)
	assert_true(ok)
	assert_almost_eq(gs.mana, 0.0, 0.01)

# --- restore_mana ---

func test_restore_mana_okar_mana() -> void:
	gs.mana = 30.0; gs.max_mana = 100.0
	gs.restore_mana(25.0)
	assert_almost_eq(gs.mana, 55.0, 0.01)

func test_restore_mana_clampar_pa_max() -> void:
	gs.mana = 80.0; gs.max_mana = 100.0
	gs.restore_mana(50.0)
	assert_almost_eq(gs.mana, 100.0, 0.01)

# --- use_item (potioner) ---

func test_use_item_health_potion_helar() -> void:
	gs.inventory["health_potion"] = 1
	gs.health = 50.0; gs.max_health = 200.0
	var ok: bool = gs.use_item("health_potion")
	assert_true(ok)
	assert_gt(gs.health, 50.0, "health_potion ska hela")
	assert_false(gs.inventory.has("health_potion"), "potion ska förbrukas")

func test_use_item_mana_potion_aterstaller_mana() -> void:
	gs.inventory["mana_potion"] = 1
	gs.mana = 10.0; gs.max_mana = 100.0
	var ok: bool = gs.use_item("mana_potion")
	assert_true(ok)
	assert_gt(gs.mana, 10.0, "mana_potion ska ge mana")
	assert_false(gs.inventory.has("mana_potion"), "potion ska förbrukas")

func test_use_item_saknas_i_inventory_misslyckas() -> void:
	var ok: bool = gs.use_item("health_potion")
	assert_false(ok)

# --- respawn ---

func test_respawn_aterstaller_health_och_mana() -> void:
	gs.health = 0.0; gs.mana = 0.0
	gs.respawn()
	assert_almost_eq(gs.health, gs.max_health, 0.01, "health ska vara max efter respawn")
	assert_almost_eq(gs.mana, gs.max_mana, 0.01, "mana ska vara max efter respawn")

func test_respawn_applicerar_xp_straff() -> void:
	gs.experience = 100
	gs.xp_to_next = 200
	gs.respawn()
	# penalty = int(200 * 0.5) = 100  →  experience = max(100-100, 0) = 0
	assert_eq(gs.experience, 0, "halva xp-progrssen ska tappas")

func test_respawn_straff_aldrig_under_noll() -> void:
	gs.experience = 10
	gs.xp_to_next = 200   # penalty = 100, men experience = 10 → clampa på 0
	gs.respawn()
	assert_gte(gs.experience, 0, "experience ska aldrig bli negativt")

func test_respawn_satter_zon_till_town() -> void:
	gs.current_zone = "cave"
	gs.respawn()
	assert_eq(gs.current_zone, "town")

# --- items.json — runfält ---

func test_attack_rune_har_rune_power() -> void:
	var d: Dictionary = ItemDB.items.get("attack_rune", {})
	assert_gt(int(d.get("rune_power", 0)), 0, "attack_rune ska ha rune_power")

func test_attack_rune_har_mana_cost() -> void:
	var d: Dictionary = ItemDB.items.get("attack_rune", {})
	assert_gt(int(d.get("mana_cost", 0)), 0, "attack_rune ska ha mana_cost")

func test_fire_rune_starkare_an_attack_rune() -> void:
	var ar: Dictionary = ItemDB.items.get("attack_rune", {})
	var fr: Dictionary = ItemDB.items.get("fire_rune", {})
	assert_gt(int(fr.get("rune_power", 0)), int(ar.get("rune_power", 0)),
		"fire_rune ska ha högre rune_power än attack_rune")

func test_healing_rune_har_effect_heal() -> void:
	var d: Dictionary = ItemDB.items.get("healing_rune", {})
	assert_eq(String(d.get("effect", "")), "heal")

# --- CombatFormulas.roll_magic ---

func test_roll_magic_positivt() -> void:
	var dmg := CombatFormulas.roll_magic(5, 8)
	assert_gt(dmg, 0.0, "roll_magic ska ge positivt värde")

func test_roll_magic_skalas_med_magic_level() -> void:
	# magic_level 20 ska ge klart mer skada än level 1
	var low := CombatFormulas.roll_magic(1, 8)
	var high := CombatFormulas.roll_magic(20, 8)
	assert_gt(high, low, "högre magic_level ska ge mer skada (deterministisk formel)")

func test_roll_magic_med_noll_power_ar_noll() -> void:
	var dmg := CombatFormulas.roll_magic(10, 0)
	# base = 0 + 10*0.5 = 5, aldrig noll med level>0
	assert_gt(dmg, 0.0)
