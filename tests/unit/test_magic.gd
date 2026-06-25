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
	assert_eq(gs.current_zone, "town")   # standard-hempunkt är town

func test_respawn_gar_till_satt_hempunkt() -> void:
	gs.set_home("frodo_inn", Vector2i(3, 9))
	gs.current_zone = "cave"
	gs.respawn()
	assert_eq(gs.current_zone, "frodo_inn", "respawn ska gå till hempunkten")
	assert_eq(gs.player_tile, Vector2i(3, 9), "respawn ska placera på hem-tilen")

# --- välsignelser (blessings) ---

func test_buy_blessings_kostar_guld_och_okar_antal() -> void:
	gs.gold = 200
	var n: int = gs.buy_blessings(50)
	assert_eq(n, 4, "200 guld räcker till 4 välsignelser à 50")
	assert_eq(gs.blessings, 4)
	assert_eq(gs.gold, 0, "200 - 4*50 = 0")

func test_buy_blessings_klampas_till_max() -> void:
	gs.gold = 10000
	var n: int = gs.buy_blessings(50)
	assert_eq(n, gs.MAX_BLESSINGS, "kan aldrig köpa fler än MAX_BLESSINGS")
	assert_eq(gs.blessings, gs.MAX_BLESSINGS)
	assert_eq(gs.gold, 10000 - gs.MAX_BLESSINGS * 50)

func test_buy_blessings_utan_rad_ger_noll() -> void:
	gs.gold = 30
	var n: int = gs.buy_blessings(50)
	assert_eq(n, 0, "30 guld räcker inte till en välsignelse à 50")
	assert_eq(gs.blessings, 0)
	assert_eq(gs.gold, 30, "guldet ska vara orört")

func test_blessings_mildrar_xp_straff() -> void:
	gs.gold = 1000
	gs.buy_blessings(50)   # fullt välsignad → mult = 1 - 0.08*5 = 0.6
	gs.experience = 1000
	gs.xp_to_next = 200
	gs.respawn()
	# penalty = int(200 * 0.5 * 0.6) = 60 → experience = 1000 - 60 = 940
	assert_eq(gs.experience, 940, "full välsignelse ska minska xp-förlusten")

func test_respawn_forbrukar_valsignelser() -> void:
	gs.gold = 1000
	gs.buy_blessings(50)
	assert_eq(gs.blessings, gs.MAX_BLESSINGS)
	gs.respawn()
	assert_eq(gs.blessings, 0, "döden ska förbruka alla välsignelser")

func test_full_valsignelse_skyddar_allt_gods() -> void:
	gs.gold = 1000
	gs.buy_blessings(50)
	assert_almost_eq(gs.death_drop_fraction(), 0.0, 0.001, "full välsignelse → inget tappas")

func test_delvis_valsignelse_minskar_drop() -> void:
	gs.gold = 100
	gs.buy_blessings(50)   # 2 välsignelser
	assert_eq(gs.blessings, 2)
	# base 0.30 * (1 - 0.18*2) = 0.30 * 0.64 = 0.192
	assert_almost_eq(gs.death_drop_fraction(), 0.192, 0.001)

# --- grav (oupphämtad döds-loot) ---

func test_grave_helpers_set_and_clear() -> void:
	assert_false(gs.has_grave(), "ingen grav från start")
	gs.set_grave("forest", Vector2i(5, 9), [{"item": "bear_pelt", "qty": 2}])
	assert_true(gs.has_grave())
	assert_eq(gs.grave_zone, "forest")
	assert_eq(gs.grave_tile, Vector2i(5, 9))
	gs.clear_grave()
	assert_false(gs.has_grave())
	assert_eq(gs.grave_zone, "")
	assert_eq(gs.grave_tile, Vector2i(-1, -1))

func test_grave_med_tom_loot_raknas_inte() -> void:
	gs.set_grave("forest", Vector2i(5, 9), [])
	assert_false(gs.has_grave(), "tom loot-lista = ingen grav")

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
