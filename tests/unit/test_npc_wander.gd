extends GutTest
## NpcWanderSim: dialog-NPC:ernas strosande kring hemrutan — radie, paus,
## spelarfrys, förbjudna rutor och occupancy testas headless utan noder.

const FAR := Vector2i(50, 50)   # spelaren långt borta (utom frysavstånd)

var _zone: ZoneModel
var _sim: NpcWanderSim

func _make_zone(rows: Array) -> ZoneModel:
	var z := ZoneModel.new()
	z.parse({"name": "Testzon", "tiles": rows}, "test_wander")
	return z

func _open_rows() -> Array:
	var rows: Array = []
	for y in 10:
		rows.append("..........")
	return rows

func before_each() -> void:
	_zone = _make_zone(_open_rows())
	_sim = NpcWanderSim.new()
	_sim.place(Vector2i(5, 5), _zone)

# --- placering & occupancy ---

func test_place_occuperar_hemrutan() -> void:
	assert_true(_zone.is_occupied(Vector2i(5, 5)), "place() ska occupera hemrutan")

func test_steg_flyttar_occupancy() -> void:
	_sim.try_step(FAR)
	assert_false(_zone.is_occupied(Vector2i(5, 5)), "gamla rutan ska frigöras")
	assert_true(_zone.is_occupied(_sim.tile), "nya rutan ska occuperas")

# --- steg ---

func test_steg_ar_kardinal_granne() -> void:
	watch_signals(_sim)
	assert_true(_sim.try_step(FAR), "öppen mark: steget ska lyckas")
	assert_signal_emitted(_sim, "moved")
	var d := _sim.tile - Vector2i(5, 5)
	assert_eq(absi(d.x) + absi(d.y), 1, "steget ska vara en kardinalgranne")
	assert_eq(_sim.move_progress, 0.0, "nytt steg ska nolla move_progress")

func test_haller_sig_inom_radien() -> void:
	for i in 60:
		if _sim.move_progress < 1.0:
			_sim.move_progress = 1.0   # avsluta steget direkt — vi testar bara valet
		_sim.try_step(FAR)
		var d := maxi(absi(_sim.tile.x - _sim.home.x), absi(_sim.tile.y - _sim.home.y))
		assert_between(d, 0, NpcWanderSim.RADIUS, "får aldrig lämna radien kring hem")

func test_instangd_star_stilla() -> void:
	watch_signals(_sim)
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		_zone.occupy(Vector2i(5, 5) + d, RefCounted.new())
	assert_false(_sim.try_step(FAR), "alla grannar upptagna: inget steg")
	assert_signal_not_emitted(_sim, "moved")

func test_kliver_inte_pa_spelaren() -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0)]:
		_zone.occupy(Vector2i(5, 5) + d, RefCounted.new())
	assert_false(_sim.try_step(Vector2i(6, 5)),
		"enda fria grannen är spelarens ruta: inget steg")

func test_kliver_inte_pa_portal() -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0)]:
		_zone.occupy(Vector2i(5, 5) + d, RefCounted.new())
	_zone.portals[Vector2i(6, 5)] = "annan_zon"
	assert_false(_sim.try_step(FAR),
		"enda fria grannen är en portal: inget steg")

func test_kliver_inte_pa_trappa() -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0)]:
		_zone.occupy(Vector2i(5, 5) + d, RefCounted.new())
	_zone.stair_points[Vector2i(6, 5)] = {"to": "annan_zon", "up": true}
	assert_false(_sim.try_step(FAR),
		"enda fria grannen är en trappa: inget steg")

# --- tick ---

func test_tick_fryser_nar_spelaren_ar_nara() -> void:
	watch_signals(_sim)
	_sim._pause = 0.0
	_sim.tick(0.1, Vector2i(5, 7))   # dist 2 ≤ PLAYER_FREEZE_DIST
	assert_signal_not_emitted(_sim, "moved", "ska stå stilla när spelaren är nära")

func test_tick_vilar_mellan_stegen() -> void:
	watch_signals(_sim)
	_sim._pause = 5.0
	_sim.tick(0.1, FAR)
	assert_signal_not_emitted(_sim, "moved", "pausen ska hållas")

func test_tick_stegar_efter_pausen() -> void:
	watch_signals(_sim)
	_sim._pause = 0.05
	_sim.tick(0.1, FAR)
	assert_signal_emitted(_sim, "moved", "utlupen paus på öppen mark ska ge ett steg")
	assert_between(_sim._pause, NpcWanderSim.PAUSE_MIN, NpcWanderSim.PAUSE_MAX,
		"ny paus ska slumpas inom intervallet")

func test_tick_avancerar_paborjat_steg() -> void:
	_sim.try_step(FAR)
	_sim.tick(0.25, FAR)
	assert_almost_eq(_sim.move_progress, 0.25 * NpcWanderSim.STEP_SPEED, 0.001,
		"move_progress ska följa STEP_SPEED")

func test_tick_utan_zon_ar_noop() -> void:
	var s := NpcWanderSim.new()
	s.tick(0.1, FAR)
	pass_test("tick utan zon ska inte krascha")
