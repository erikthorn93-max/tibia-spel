extends GutTest
## Headless-tester för Monster3D (vy över MonsterSim) och game3d:s
## zonorkestrering (monsterspawn + portalsteg → zonbyte).

const Monster3DScript = preload("res://entities/monster/monster3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_health: float

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_health = GameState.health
	GameState.health = GameState.max_health   # inga döds-flöden mitt i testet

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	GameState.health = _saved_health

## Liten öppen testyta: 6×4 gräs, spelarstart mitt på.
func _flat_model() -> ZoneModel:
	var m := ZoneModel.new()
	m.parse({"name": "Testyta", "tiles": ["......", "..P...", "......", "......"]}, "t3d_flat")
	return m

func _make_monster(model: ZoneModel, t: Vector2i) -> Monster3D:
	var m: Monster3D = Monster3DScript.new()
	add_child_autofree(m)
	m.set_process(false)   # testet tickar sim manuellt
	m.setup("Råtta", t, model)
	return m

# ── Monster3D ─────────────────────────────────────────────────────────────────

func test_setup_places_and_occupies():
	var model := _flat_model()
	var m := _make_monster(model, Vector2i(0, 0))
	assert_eq(m.position, Zone3D.tile_to_world3(Vector2i(0, 0)))
	assert_true(model.is_occupied(Vector2i(0, 0)), "spawn-tilen ska ockuperas av simmen")

func test_chase_step_interpolates_position():
	var model := _flat_model()
	var m := _make_monster(model, Vector2i(0, 0))
	# Spelare 3 tiles bort: inom aggro (Råtta ser 5) → jaktsteg påbörjas.
	m.sim.ai_tick(0.016, Vector2i(3, 0))
	assert_lt(m.sim.move_progress, 1.0, "jaktsteget ska ha påbörjats")
	var expected := minf(m.sim.move_progress + 0.1 * m.sim.speed, 1.0)
	m.sim.ai_tick(0.1, Vector2i(3, 0))
	m._process(0.0)   # player_sim=null → AI fryst; bara interpolation körs
	var from := Zone3D.tile_to_world3(Vector2i(0, 0))
	var to := Zone3D.tile_to_world3(Vector2i(1, 0))
	assert_almost_eq(m.position.x, lerpf(from.x, to.x, expected), 0.001,
		"positionen ska interpoleras ur sim.move_progress")

func test_hp_bar_shrinks_on_damage():
	var model := _flat_model()
	var m := _make_monster(model, Vector2i(0, 0))
	assert_almost_eq(m._hp_bar.scale.x, 1.0, 0.001, "full hp → full bar")
	m.sim.take_damage(float(m.sim.max_hp) / 2.0)
	assert_almost_eq(m._hp_bar.scale.x, float(m.sim.hp) / float(m.sim.max_hp), 0.01,
		"baren ska spegla hp-kvoten efter skada")

func test_death_vacates_and_frees_node():
	var model := _flat_model()
	var m := _make_monster(model, Vector2i(0, 0))
	m.sim.take_damage(99999.0)
	assert_true(m.sim.dead)
	assert_false(model.is_occupied(Vector2i(0, 0)), "döden ska frigöra tilen")
	await wait_seconds(0.5)   # krymp-tween → queue_free
	assert_false(is_instance_valid(m), "noden ska försvinna efter dödsanimationen")

# ── game3d: spawn + portalsteg ────────────────────────────────────────────────

func _boot_game3d() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func test_game3d_spawns_zone_monsters():
	var g := _boot_game3d()
	var expected := 0
	for sp in g.model.spawn_points:
		var mname := String(sp["monster"])
		if bool(MonsterDB.monsters.get(mname, {}).get("boss", false)) \
				and not TaskSystem.boss_available(mname):
			continue
		expected += 1
	assert_eq(g._monsters_root.get_child_count(), expected,
		"varje tillgänglig spawnpunkt ska ge ett Monster3D")

func test_game3d_portal_step_changes_zone():
	var g := _boot_game3d()
	var portal_tile := Vector2i(-1, -1)
	for t in g.model.portals:
		if not g.model.portal_locks.has(t) and not g.model.dungeon_entrances.has(t):
			portal_tile = t
			break
	assert_ne(portal_tile, Vector2i(-1, -1), "startzonen ska ha en olåst portal")
	var dest := String(g.model.portals[portal_tile])
	g._on_player_step_completed(portal_tile)
	await wait_frames(3)   # load_zone är call_deferred
	assert_eq(g.model.zone_id, dest, "modellen ska bytas till destinationszonen")
	assert_eq(GameState.current_zone, dest, "zonbytet ska bokföras i GameState")
	assert_eq(g.player.sim.zone, g.model, "spelarsimmen ska peka på nya modellen")

func test_game3d_locked_portal_blocks():
	var g := _boot_game3d()
	UnlockSystem.unlocked.erase("__testlock_3d")
	var t := Vector2i(0, 0)
	g.model.portals[t] = "town"
	g.model.portal_locks[t] = "__testlock_3d"
	var before: String = g.model.zone_id
	g._on_player_step_completed(t)
	await wait_frames(3)
	assert_eq(g.model.zone_id, before, "låst portal utan uppfyllda krav ska inte byta zon")
