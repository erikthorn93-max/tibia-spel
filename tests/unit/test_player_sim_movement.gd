extends GutTest
## 3D-steg 3: PlayerSim äger gridrörelsen — steg, frame-budget med carry-over,
## auto-walk, facing och onåbarhets-meddelanden testas headless utan noder.

var _zone: ZoneModel
var _sim: PlayerSim

func before_each() -> void:
	_zone = ZoneModel.new()
	# 10×10 gräs med en vattenbarriär (ej gångbar) på kolumn 8, rad 0–8
	var rows: Array = []
	for y in 10:
		rows.append("........~." if y < 9 else "..........")
	_zone.parse({"name": "Testzon", "tiles": rows}, "test_player")
	_sim = PlayerSim.new()
	_sim.zone = _zone
	_sim.tile = Vector2i(5, 5)
	_sim.move_speed = 4.0

# --- steg ---

func test_steg_flyttar_och_signalerar() -> void:
	watch_signals(_sim)
	assert_true(_sim.step(Vector2i.RIGHT), "steg mot gångbar tile ska lyckas")
	assert_eq(_sim.tile, Vector2i(6, 5))
	assert_eq(_sim.move_progress, 0.0, "nytt steg ska nolla move_progress")
	assert_signal_emitted(_sim, "moved")

func test_steg_mot_vagg_blockeras() -> void:
	watch_signals(_sim)
	_sim.tile = Vector2i(7, 5)
	assert_false(_sim.step(Vector2i.RIGHT), "steg mot vatten ska misslyckas")
	assert_eq(_sim.tile, Vector2i(7, 5), "tilen ska vara oförändrad")
	assert_signal_not_emitted(_sim, "moved")

func test_steg_vander_facing_aven_mot_vagg() -> void:
	watch_signals(_sim)
	_sim.tile = Vector2i(7, 5)
	_sim.step(Vector2i.RIGHT)
	assert_eq(_sim.facing, Vector2i.RIGHT, "facing ska sättas även när steget blockeras")
	assert_signal_emitted(_sim, "facing_changed")

# --- advance / frame-budget ---

func test_advance_interpolerar_med_speed() -> void:
	_sim.step(Vector2i.RIGHT)
	_sim.advance(0.1)
	assert_almost_eq(_sim.move_progress, 0.4, 0.001, "0.1 s × speed 4.0 = 0.4")

func test_steget_fullbordas_och_signalerar() -> void:
	watch_signals(_sim)
	_sim.step(Vector2i.RIGHT)
	_sim.advance(0.3)   # 0.3 × 4.0 = 1.2 ≥ 1.0 → klart
	assert_eq(_sim.move_progress, 1.0)
	assert_signal_emitted(_sim, "step_completed")

func test_carry_over_ger_flera_steg_per_stor_budget() -> void:
	assert_true(_sim.walk_to(Vector2i(1, 5)), "målet ska vara nåbart")
	_sim.advance(1.0)   # 1 s × 4 tiles/s → hinner flera steg sömlöst
	assert_eq(_sim.tile.y, 5, "auto-walk ska följa raden")
	assert_lte(_sim.tile.x, 2, "minst 3 steg ska ha hunnits med på 1 s")

func test_manuell_input_avbryter_auto_walk() -> void:
	_sim.walk_to(Vector2i(1, 5))
	_sim.advance(0.05, Vector2i.UP)   # manuell riktning vinner
	assert_eq(_sim.auto_path, [], "manuell rörelse ska tömma auto_path")
	assert_eq(_sim.tile, Vector2i(5, 4), "steget ska gå åt input-hållet")

# --- walk_to / walk_adjacent_to ---

func test_walk_to_onabar_ruta_meddelar() -> void:
	watch_signals(_sim)
	assert_false(_sim.walk_to(Vector2i(8, 3)), "vatten ska vara onåbart")
	assert_signal_emitted(_sim, "message")
	assert_eq(_sim.auto_path, [])

func test_walk_to_egen_ruta_ar_ok() -> void:
	assert_true(_sim.walk_to(_sim.tile), "gå till egen ruta ska vara ok utan path")
	assert_eq(_sim.auto_path, [])

func test_walk_adjacent_redan_intill() -> void:
	watch_signals(_sim)
	assert_true(_sim.walk_adjacent_to(Vector2i(6, 5)), "redan intill → nåbar utan path")
	assert_signal_not_emitted(_sim, "message")

# --- agility-progression ---

func test_agility_ger_speed_tier() -> void:
	_sim.step(Vector2i.RIGHT)
	var tiers := [4.0, 4.4, 4.8, 5.2]
	assert_true(_sim.move_speed in tiers,
		"move_speed ska vara en agility-tier, fick %s" % _sim.move_speed)
