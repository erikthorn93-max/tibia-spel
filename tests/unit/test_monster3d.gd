extends GutTest
## Headless-tester för Monster3D (vy över MonsterSim) och game3d:s
## zonorkestrering (monsterspawn + portalsteg → zonbyte).

const Monster3DScript = preload("res://entities/monster/monster3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_health: float
var _saved_spec: float
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_health = GameState.health
	_saved_spec = GameState.spec_energy
	_saved_hud = World.hud   # Hud3D sätter World.hud = self vid _ready
	GameState.health = GameState.max_health   # inga döds-flöden mitt i testet

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	GameState.health = _saved_health
	GameState.spec_energy = _saved_spec
	World.hud = _saved_hud

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

func test_alla_modellmappningar_pekar_pa_riktiga_filer():
	# Vakt: varje MODELS-post ska peka på en GLB som finns i assets/models3d.
	for mname in Monster3D.MODELS:
		var file := String(Monster3D.MODELS[mname]["file"])
		assert_true(
			ResourceLoader.exists("res://assets/models3d/%s.glb" % file),
			"%s mappar till %s.glb som saknas" % [mname, file])

func test_alla_modellmappningar_ar_riktiga_monster():
	# Vakt: MODELS-nycklarna ska finnas i MonsterDB — skyddar mot stavfel
	# (en felstavad nyckel ger tyst platshållarlåda i spelet).
	for mname in Monster3D.MODELS:
		assert_true(MonsterDB.monsters.has(mname),
			"MODELS-nyckeln '%s' finns inte i MonsterDB" % mname)

func test_alla_monster_har_gestalt():
	# Full täckning sedan 2026-07-12: varje monster i databasen ska ha en
	# modellmappning — ett nytt monster utan gestalt ska synas här, inte
	# som en tyst platshållarlåda i spelet.
	for mname in MonsterDB.monsters:
		assert_true(Monster3D.MODELS.has(mname),
			"monstret '%s' saknar modellmappning i Monster3D.MODELS" % mname)

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
	m.sim_tick(0.0)            # player_sim=null → AI fryst; bokför bara prev/curr
	m.render_interpolate(1.0)  # alpha 1 = senaste sim-steget
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

func test_status_aura_toggles_pa_gift():
	var model := _flat_model()
	var m := _make_monster(model, Vector2i(1, 1))
	assert_false(m._status_aura.emitting, "auran ska vara avslagen utan status")
	m.sim.apply_status("poison", 3.0, 1.0)
	assert_true(m._status_aura.emitting, "gift ska tända auran (status_changed)")
	assert_gt(m._status_aura.color.g, m._status_aura.color.r, "giftauran ska vara grön")
	m.sim.status_effects.clear()
	m._on_sim_status_changed()
	assert_false(m._status_aura.emitting, "auran ska släckas när giftet tickat ut")

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
	await wait_seconds(0.4)   # load_zone kör bakom zon-faden (0,18 s in)
	assert_eq(g.model.zone_id, dest, "modellen ska bytas till destinationszonen")
	assert_eq(GameState.current_zone, dest, "zonbytet ska bokföras i GameState")
	assert_eq(g.player.sim.zone, g.model, "spelarsimmen ska peka på nya modellen")

# ── game3d: klick-targeting och gå-till ───────────────────────────────────────

func _free_tile_near_start(g: Node3D) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var t: Vector2i = g.model.player_start + d
		if g.model.is_walkable(t) and not g.model.is_occupied(t):
			return t
	return Vector2i(-1, -1)

func test_click_monster_sets_target():
	var g := _boot_game3d()
	var t := _free_tile_near_start(g)
	assert_ne(t, Vector2i(-1, -1), "det ska finnas en ledig ruta intill start")
	g._spawn_monster3d({"tile": t, "monster": "Råtta", "respawn": -1.0})
	g._click_tile(t)
	assert_not_null(g.player.sim.target, "klick på monster ska sätta auto-attack-mål")
	assert_eq(g.player.sim.target.tile, t)
	assert_true(g._target_view._target_ring.visible, "målringen ska synas")

func test_click_ground_starts_autowalk():
	var g := _boot_game3d()
	var t := _free_tile_near_start(g)
	g._click_tile(t)
	assert_null(g.player.sim.target, "klick på tom mark ska inte sätta mål")
	assert_gt(g.player.sim.auto_path.size(), 0, "klick på mark ska starta auto-walk")

func test_target_cleared_on_zone_change():
	var g := _boot_game3d()
	var t := _free_tile_near_start(g)
	g._spawn_monster3d({"tile": t, "monster": "Råtta", "respawn": -1.0})
	g._click_tile(t)
	assert_not_null(g.player.sim.target)
	g.load_zone("town")
	assert_null(g.player.sim.target, "zonbyte ska nollställa auto-attack-målet")

func test_spec_hits_target_and_drains_meter():
	var g := _boot_game3d()
	var t := _free_tile_near_start(g)
	g._spawn_monster3d({"tile": t, "monster": "Råtta", "respawn": -1.0})
	g._click_tile(t)
	GameState.spec_energy = CombatFormulas.SPEC_MAX
	var target: MonsterSim = g.player.sim.target
	var hp_before: int = target.hp
	g._try_special()
	assert_true(target.hp < hp_before or target.dead,
		"kraftslaget ska skada målet")
	assert_lt(GameState.spec_energy, CombatFormulas.SPEC_MAX,
		"kraftslaget ska tömma spec-mätaren")

func test_spec_without_charge_is_denied():
	var g := _boot_game3d()
	var t := _free_tile_near_start(g)
	g._spawn_monster3d({"tile": t, "monster": "Råtta", "respawn": -1.0})
	g._click_tile(t)
	GameState.spec_energy = 0.0
	var target: MonsterSim = g.player.sim.target
	var hp_before: int = target.hp
	g._try_special()
	assert_eq(target.hp, hp_before, "utan laddning ska inget kraftslag ske")

# ── game3d: HUD-bryggan (2D-panelerna ovanpå 3D-vyn) ──────────────────────────

func _action(action_name: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	return ev

func test_hud3d_reuses_2d_panels_hidden_at_start():
	var g := _boot_game3d()
	for p in [g.hud.inv_panel, g.hud.skill_panel, g.hud.bestiary_panel,
			g.hud.spellbook_panel, g.hud.quest_log, g.hud.equipment_panel]:
		assert_not_null(p, "bryggan ska instansiera alla 2D-paneler")
		assert_false(p.visible, "panelerna ska starta dolda")
	assert_eq(World.hud, g.hud,
		"World.hud ska peka på bryggan så panelernas show_message-anrop når 3D-HUD:en")

func test_hud3d_toggle_actions_open_and_close():
	var g := _boot_game3d()
	g.hud._unhandled_input(_action("toggle_skills"))
	assert_true(g.hud.skill_panel.visible, "toggle_skills ska öppna skillpanelen")
	g.hud._unhandled_input(_action("toggle_inventory"))
	assert_true(g.hud.inv_panel.visible, "toggle_inventory ska öppna ryggsäcken")
	g.hud._unhandled_input(_action("toggle_quest_log"))
	assert_true(g.hud.quest_log.visible, "toggle_quest_log ska öppna questloggen")
	g.hud._unhandled_input(_action("toggle_skills"))
	assert_false(g.hud.skill_panel.visible, "samma tangent igen ska stänga panelen")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	g.hud._unhandled_input(esc)
	assert_false(g.hud.inv_panel.visible, "Escape ska stänga alla paneler")
	assert_false(g.hud.quest_log.visible, "Escape ska stänga alla paneler")

func test_hud3d_message_row():
	var g := _boot_game3d()
	g._show_msg("Hej 3D")
	assert_eq(g.hud._msg_lbl.text, "Hej 3D", "meddelanden ska gå via bryggan")

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
