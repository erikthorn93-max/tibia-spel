extends GutTest
## M10: Testar statuseffekt-systemet (poison apply/clear/tick) i game_state.gd.

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# --- apply_status ---

func test_apply_status_laggar_till_effekt() -> void:
	gs.apply_status("poison", 10.0, 3.0)
	assert_true(gs.has_status("poison"), "poison ska finnas i status_effects")

func test_apply_status_sparar_tick_dmg() -> void:
	gs.apply_status("poison", 10.0, 4.5)
	var s: Dictionary = gs.status_effects["poison"]
	assert_almost_eq(float(s["tick_dmg"]), 4.5, 0.01)

func test_apply_status_sparar_duration() -> void:
	gs.apply_status("poison", 12.0, 3.0)
	var s: Dictionary = gs.status_effects["poison"]
	assert_almost_eq(float(s["time_left"]), 12.0, 0.01)

func test_apply_status_skriver_over_befintlig() -> void:
	gs.apply_status("poison", 5.0, 2.0)
	gs.apply_status("poison", 15.0, 8.0)  # ny, starkare
	var s: Dictionary = gs.status_effects["poison"]
	assert_almost_eq(float(s["tick_dmg"]), 8.0, 0.01, "starkare gift ska ersätta svagare")
	assert_almost_eq(float(s["time_left"]), 15.0, 0.01)

# --- clear_status ---

func test_clear_status_tar_bort_effekt() -> void:
	gs.apply_status("poison", 10.0, 3.0)
	gs.clear_status("poison")
	assert_false(gs.has_status("poison"), "poison ska vara borta")

func test_clear_status_pa_obefintlig_ger_inte_error() -> void:
	gs.clear_status("poison")   # ska inte krascha
	assert_false(gs.has_status("poison"))

# --- has_status ---

func test_has_status_false_om_ingen_effekt() -> void:
	assert_false(gs.has_status("poison"))

func test_has_status_true_efter_apply() -> void:
	gs.apply_status("poison", 5.0, 2.0)
	assert_true(gs.has_status("poison"))

# --- _tick_statuses ---

func test_poison_tick_sanker_health() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("poison", 10.0, 5.0)
	gs._tick_statuses(1.0)   # exakt 1s → 1 tick
	assert_almost_eq(gs.health, 95.0, 0.01, "5 dmg per tick")

func test_poison_tick_sker_var_sekund() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("poison", 10.0, 5.0)
	gs._tick_statuses(0.4)   # ej hel sekund ännu
	assert_almost_eq(gs.health, 100.0, 0.01, "ingen tick under 1s")
	gs._tick_statuses(0.7)   # nu totalt 1.1s → en tick
	assert_almost_eq(gs.health, 95.0, 0.01, "en tick vid >1s")

func test_poison_upphör_efter_duration() -> void:
	gs.health = 200.0; gs.max_health = 200.0
	gs.apply_status("poison", 3.0, 2.0)   # 3s duration, 2 dmg/tick
	gs._tick_statuses(4.0)   # passerar duration
	assert_false(gs.has_status("poison"), "poison ska ha upphört")

func test_poison_tick_ger_inte_negativ_health() -> void:
	gs.health = 1.0; gs.max_health = 100.0
	gs.apply_status("poison", 10.0, 50.0)
	gs._tick_statuses(1.0)
	assert_gte(gs.health, 0.0, "health ska aldrig bli negativ")

# --- DoT-omapplicering (balansfix: gift blir inte permanent av upprepade procs) ---

func test_aktiv_dot_fornyas_inte_av_lika_proc() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("poison", 10.0, 3.0)
	gs._tick_statuses(3.0)                  # time_left → 7.0
	gs.apply_status("poison", 10.0, 3.0)    # lika stark proc igen
	assert_almost_eq(float(gs.status_effects["poison"]["time_left"]), 7.0, 0.01,
		"lika stark proc ska INTE förnya till full duration")

func test_aktiv_dot_fornyas_inte_av_svagare_proc() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("poison", 10.0, 5.0)
	gs._tick_statuses(2.0)                  # time_left → 8.0
	gs.apply_status("poison", 10.0, 2.0)    # svagare proc
	assert_almost_eq(float(gs.status_effects["poison"]["tick_dmg"]), 5.0, 0.01,
		"svagare proc ska inte sänka tick_dmg")
	assert_almost_eq(float(gs.status_effects["poison"]["time_left"]), 8.0, 0.01,
		"svagare proc ska inte förnya duration")

func test_starkare_dot_skriver_over_och_fornyar() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("poison", 5.0, 2.0)
	gs._tick_statuses(1.0)                  # time_left → 4.0
	gs.apply_status("poison", 12.0, 6.0)    # starkare proc
	assert_almost_eq(float(gs.status_effects["poison"]["tick_dmg"]), 6.0, 0.01)
	assert_almost_eq(float(gs.status_effects["poison"]["time_left"]), 12.0, 0.01,
		"starkare gift ska förnya till sin fulla duration")

func test_stun_fornyas_fortfarande() -> void:
	# Icke-DoT (tick_dmg 0) ska förnyas som förr — annars kan stun inte staplas.
	gs.apply_status("stun", 2.0, 0.0)
	gs._tick_statuses(1.0)                  # time_left → 1.0
	gs.apply_status("stun", 2.0, 0.0)
	assert_almost_eq(float(gs.status_effects["stun"]["time_left"]), 2.0, 0.01,
		"stun ska förnyas till full duration vid ny proc")
