extends GutTest
## Procedurellt karaktärsliv i 3D (CharacterMotion3D): gång-studs under steg,
## idle-andning i vila — samma idiom som 2D:s CharacterVisual. Vyerna
## applicerar kurvorna per frame i render_interpolate; attack-stöten pausar
## livs-animen så tweenen får styra kroppen ostört.

const Monster3DScript = preload("res://entities/monster/monster3d.gd")
const Player3DScript = preload("res://entities/player/player3d.gd")
const Npc3DScript = preload("res://entities/npc/npc3d.gd")

var _saved_tile: Vector2i

func before_each():
	_saved_tile = GameState.player_tile

func after_each():
	GameState.player_tile = _saved_tile

## Liten öppen testyta: 6×4 gräs, spelarstart mitt på.
func _flat_model() -> ZoneModel:
	var m := ZoneModel.new()
	m.parse({"name": "Testyta", "tiles": ["......", "..P...", "......", "......"]},
		"motion_flat")
	return m

# ── Kurvorna ──────────────────────────────────────────────────────────────────

func test_walk_bob_zero_at_tile_borders():
	assert_almost_eq(CharacterMotion3D.walk_bob(0.0), 0.0, 0.0001,
		"studsen ska vara noll vid stegets start")
	assert_almost_eq(CharacterMotion3D.walk_bob(1.0), 0.0, 0.0001,
		"studsen ska vara noll vid stegets slut (kontinuerlig över carry-over)")

func test_walk_bob_peaks_mid_step():
	assert_almost_eq(CharacterMotion3D.walk_bob(0.5), CharacterMotion3D.BOB_AMP,
		0.0001, "toppen mitt i steget ska vara BOB_AMP")
	assert_gt(CharacterMotion3D.walk_bob(0.25), 0.0, "studsen är alltid uppåt")

func test_breath_scale_oscillates_around_one():
	var lo := 1.0
	var hi := 1.0
	for i in 50:
		var s := CharacterMotion3D.breath_scale(float(i) * 0.1)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	assert_almost_eq(hi, 1.0 + CharacterMotion3D.BREATH_AMP, 0.001)
	assert_almost_eq(lo, 1.0 - CharacterMotion3D.BREATH_AMP, 0.001)

# ── Player3D: studs under steg, andning i vila ────────────────────────────────

func _make_player(m: ZoneModel) -> Player3D:
	var p: Player3D = Player3DScript.new()
	add_child_autofree(p)
	p.set_process(false)   # testet driver render_interpolate manuellt
	p.sim.zone = m
	p.snap_to(m.player_start)
	return p

func test_player_bobs_mid_step():
	var m := _flat_model()
	var p := _make_player(m)
	p.sim.step(Vector2i.RIGHT)
	p.sim_tick(SimTicker.SIM_DT)
	p.render_interpolate(1.0, 0.016)
	assert_almost_eq(p._visual.position.y,
		CharacterMotion3D.walk_bob(p.sim.move_progress), 0.0001,
		"mitt i ett steg ska visualen studsa enligt kurvan")
	assert_almost_eq(p._visual.scale.y, 1.0, 0.0001,
		"ingen andnings-skala under gång")

func test_player_breathes_at_rest():
	var m := _flat_model()
	var p := _make_player(m)
	p.sim_tick(SimTicker.SIM_DT)   # stilla: move_progress = 1.0
	p.render_interpolate(1.0, 0.5)
	assert_almost_eq(p._visual.position.y, 0.0, 0.0001,
		"i vila ska visualen stå på marken")
	assert_almost_eq(p._visual.scale.y, CharacterMotion3D.breath_scale(0.5),
		0.0001, "i vila ska visualen andas enligt kurvan")

func test_player_attack_pauses_life_anim():
	var m := _flat_model()
	var p := _make_player(m)
	p._on_attack_swung(Vector2i.RIGHT)
	assert_true(p._attacking, "attack-stöten ska flagga _attacking")
	p._visual.scale.y = 5.0   # sentinel: livs-animen får inte röra kroppen nu
	p.render_interpolate(1.0, 0.1)
	assert_almost_eq(p._visual.scale.y, 5.0, 0.0001,
		"livs-animen ska pausas medan attack-tweenen spelar")
	await wait_seconds(0.35)   # 0.07 + 0.13 s tween + marginal
	assert_false(p._attacking, "flaggan ska släppas när tweenen är klar")

# ── Monster3D: samma idiom på kroppen ─────────────────────────────────────────

func test_monster_bobs_while_chasing():
	var model := _flat_model()
	var mon: Monster3D = Monster3DScript.new()
	add_child_autofree(mon)
	mon.setup("Råtta", Vector2i(0, 1), model)
	var psim := PlayerSim.new()
	psim.tile = Vector2i(4, 1)   # inom aggro → jaktsteg
	mon.player_sim = psim
	mon.sim_tick(SimTicker.SIM_DT)
	mon.sim_tick(SimTicker.SIM_DT)
	assert_gt(mon.sim.move_progress, 0.0)
	mon.render_interpolate(1.0, 0.016)
	assert_almost_eq(mon._body_root.position.y,
		CharacterMotion3D.walk_bob(mon.sim.move_progress), 0.0001,
		"jagande monster ska studsa enligt kurvan")

func test_monster_breathes_at_rest():
	var model := _flat_model()
	var mon: Monster3D = Monster3DScript.new()
	add_child_autofree(mon)
	mon.setup("Råtta", Vector2i(0, 1), model)
	mon.sim_tick(SimTicker.SIM_DT)   # ingen spelare → AI fryst, stilla
	var t0: float = mon._breath_t
	mon.render_interpolate(1.0, 0.4)
	assert_almost_eq(mon._body_root.scale.y,
		CharacterMotion3D.breath_scale(t0 + 0.4), 0.0001,
		"vilande monster ska andas enligt kurvan (desynkad klocka)")

# ── Npc3D: idle-andning ───────────────────────────────────────────────────────

func test_npc_breathes():
	var n: Npc3D = Npc3DScript.new()
	add_child_autofree(n)
	n.set_process(false)   # testet driver _process manuellt
	n.setup("shop", Vector2i(2, 2))
	var t0: float = n._breath_t
	n._process(0.4)
	assert_almost_eq(n._body.scale.y,
		n._body_base_scale_y * CharacterMotion3D.breath_scale(t0 + 0.4), 0.0001,
		"NPC-kroppen ska andas kring sin basskala")
