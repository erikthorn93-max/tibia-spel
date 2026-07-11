extends GutTest
## 3D-prestandakravet "fast simuleringstick frikopplad från renderingen":
## SimTicker omvandlar frame-tid till hela sim-steg (med tak mot dödsspiral),
## game3d tickar Player-/MonsterSim centralt och vyerna renderas med
## alpha-interpolation mellan de två senaste sim-stegen.

const Monster3DScript = preload("res://entities/monster/monster3d.gd")
const Player3DScript = preload("res://entities/player/player3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_health: float
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_health = GameState.health
	_saved_hud = World.hud   # Hud3D sätter World.hud = self vid _ready
	GameState.health = GameState.max_health   # inga döds-flöden mitt i testet

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	GameState.health = _saved_health
	World.hud = _saved_hud

## Liten öppen testyta: 6×4 gräs, spelarstart mitt på.
func _flat_model() -> ZoneModel:
	var m := ZoneModel.new()
	m.parse({"name": "Testyta", "tiles": ["......", "..P...", "......", "......"]},
		"tick_flat")
	return m

# ── SimTicker: frame-tid → hela sim-steg ──────────────────────────────────────

func test_short_frame_gives_no_step():
	var t := SimTicker.new()
	assert_eq(t.advance(SimTicker.SIM_DT * 0.4), 0, "under ett helt steg → 0 steg")
	assert_almost_eq(t.alpha(), 0.4, 0.001, "alpha ska vara andelen in i nästa steg")

func test_accumulates_across_frames():
	var t := SimTicker.new()
	assert_eq(t.advance(SimTicker.SIM_DT * 0.6), 0)
	assert_eq(t.advance(SimTicker.SIM_DT * 0.6), 1, "0.6 + 0.6 steg = 1 helt steg")
	assert_almost_eq(t.alpha(), 0.2, 0.001, "resten ska ligga kvar som alpha")

func test_long_frame_gives_multiple_steps():
	var t := SimTicker.new()
	assert_eq(t.advance(SimTicker.SIM_DT * 3.5), 3, "3.5 steg frame-tid = 3 hela steg")
	assert_almost_eq(t.alpha(), 0.5, 0.001)

func test_frozen_frame_clamps_and_drops_debt():
	var t := SimTicker.new()
	assert_eq(t.advance(10.0), SimTicker.MAX_STEPS,
		"en fryst frame ska klampas till MAX_STEPS")
	assert_almost_eq(t.alpha(), 0.0, 0.001,
		"sim-skulden ska droppas i stället för att jagas ikapp")

# ── Player3D: sim_tick bokför prev/curr, render_interpolate mjukar ────────────

func test_player3d_render_interpolates_between_ticks():
	var m := _flat_model()
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)   # testet tickar manuellt
	p.sim.zone = m
	p.snap_to(m.player_start)
	var from := Zone3D.tile_to_world3(m.player_start)
	var to := Zone3D.tile_to_world3(m.player_start + Vector2i.RIGHT)
	p.sim.step(Vector2i.RIGHT)
	p.sim_tick(SimTicker.SIM_DT)
	var curr_x := lerpf(from.x, to.x, p.sim.move_progress)
	p.render_interpolate(0.0)
	assert_almost_eq(p.position.x, from.x, 0.001, "alpha 0 = förra sim-steget")
	p.render_interpolate(1.0)
	assert_almost_eq(p.position.x, curr_x, 0.001, "alpha 1 = senaste sim-steget")
	p.render_interpolate(0.5)
	assert_almost_eq(p.position.x, lerpf(from.x, curr_x, 0.5), 0.001,
		"alpha 0.5 = mitt emellan de två senaste stegen")

func test_player3d_snap_resets_interpolation():
	var m := _flat_model()
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)
	p.sim.zone = m
	p.snap_to(m.player_start)
	p.sim.step(Vector2i.RIGHT)
	p.sim_tick(SimTicker.SIM_DT)
	p.snap_to(m.player_start)   # teleport (zonbyte/respawn) mitt i ett steg
	p.render_interpolate(0.0)
	assert_eq(p.position, Zone3D.tile_to_world3(m.player_start),
		"snap_to ska nollställa prev/curr så inget spöksteg interpoleras")

# ── Monster3D: sim_tick matar AI:n och bokför prev/curr ───────────────────────

func test_monster3d_sim_tick_feeds_ai_and_interpolates():
	var model := _flat_model()
	var mon: Monster3D = Monster3DScript.new()
	add_child_autofree(mon)
	mon.setup("Råtta", Vector2i(0, 1), model)
	var psim := PlayerSim.new()
	psim.tile = Vector2i(4, 1)   # 4 rutor bort — inom Råttans aggro
	mon.player_sim = psim
	mon.sim_tick(SimTicker.SIM_DT)
	mon.sim_tick(SimTicker.SIM_DT)
	assert_gt(mon.sim.move_progress, 0.0, "sim_tick ska mata AI:n som börjar jaga")
	var prev: Vector3 = mon._prev_pos
	var curr: Vector3 = mon._curr_pos
	assert_ne(prev, curr, "prev/curr ska skilja sig mitt i ett jaktsteg")
	mon.render_interpolate(0.5)
	assert_almost_eq(mon.position.x, lerpf(prev.x, curr.x, 0.5), 0.001,
		"renderingen ska interpolera mellan de två senaste sim-stegen")

# ── game3d: _process driver den centrala tick-loopen ──────────────────────────

func _free_tile_near_start(g: Node3D) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var t: Vector2i = g.model.player_start + d
		if g.model.is_walkable(t) and not g.model.is_occupied(t):
			return t
	return Vector2i(-1, -1)

func test_game3d_process_ticks_player_sim():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	g.set_process(false)   # testet driver _process manuellt (deterministiskt)
	var t := _free_tile_near_start(g)
	assert_ne(t, Vector2i(-1, -1), "det ska finnas en ledig ruta intill start")
	var start_pos: Vector3 = g.player.position
	g.player.walk_to(t)
	g._process(SimTicker.SIM_DT * SimTicker.MAX_STEPS)   # 5 sim-steg = 0.25 s
	assert_eq(g.player.sim.tile, t,
		"0.25 s vid grundfart 4 tiles/s ska fullborda steget till grannrutan")
	assert_ne(g.player.position, start_pos,
		"render-interpolationen ska ha flyttat vyn")

func test_game3d_process_ticks_monster_sims():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	g.set_process(false)
	var t := _free_tile_near_start(g)
	assert_ne(t, Vector2i(-1, -1))
	g._spawn_monster3d({"monster": "Råtta", "tile": t, "respawn": -1.0})
	var mon: Monster3D = null
	for c in g._monsters_root.get_children():
		if c is Monster3D and c.sim.tile == t:
			mon = c
	assert_not_null(mon, "det spawnade monstret ska finnas i monsterroten")
	# Intill spelaren → AI:n attackerar i stället för att jaga. attack_started
	# fyrar deterministiskt (före träff-/dodge-rullarna) när tick-loopen kör.
	var attacks: Array = []
	mon.sim.attack_started.connect(func(d): attacks.append(d))
	for _i in 16:   # 4 s sim-tid i fasta steg (cooldown ~1 s)
		g._process(SimTicker.SIM_DT * SimTicker.MAX_STEPS)
	assert_gt(attacks.size(), 0,
		"den centrala tick-loopen ska driva monster-AI:ns attacker")
