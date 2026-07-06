extends GutTest
## Gathering i 3D-slicen: GatherSim äger logiken (delad med 2D-vyn),
## GatherNode3D spawnas ur zonens node-punkter, klick sätter gather-mål
## och Player3D:s 2 s-tick kör försöken med samma besked som 2D.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _nodes(g: Node3D) -> Array:
	var out := []
	for n in g._npcs_root.get_children():
		if n is GatherNode3D:
			out.append(n)
	return out

# ── GatherSim: delad kärna (samma kontrakt som gamla GatherNode.attempt) ──────

func _make_sim() -> GatherSim:
	var s := GatherSim.new()
	s.def = {"skill": "mining", "level": 1, "tool": "pickaxe", "yields": "copper_ore",
		"xp": 15, "charges": [3, 5], "respawn": 30, "color": "#b87333", "label": "Kopparådra"}
	s.charges = 3
	return s

func test_sim_attempt_requires_tool():
	var s := _make_sim()
	GameState.inventory.erase("pickaxe")
	assert_eq(s.attempt(), "no_tool")

func test_sim_attempt_requires_level():
	var s := _make_sim()
	GameState.add_item("pickaxe", 1)
	s.def["level"] = 99
	assert_eq(s.attempt(), "low_level")
	GameState.remove_item("pickaxe", 1)

func test_sim_success_emits_harvested_and_consumes_charge():
	var s := _make_sim()
	watch_signals(s)
	var ore0 := int(GameState.inventory.get("copper_ore", 0))
	s.apply_success()
	assert_signal_emitted_with_parameters(s, "harvested", ["copper_ore", 1, false])
	assert_eq(int(GameState.inventory.get("copper_ore", 0)), ore0 + 1)
	assert_eq(s.charges, 2)
	GameState.remove_item("copper_ore", 1)

func test_sim_depletes_and_respawns():
	var s := _make_sim()
	watch_signals(s)
	s.charges = 1
	s.apply_success()
	assert_true(s.depleted)
	assert_signal_emitted(s, "depleted_now")
	assert_eq(s.attempt(), "depleted")
	s.respawn()
	assert_false(s.depleted)
	assert_between(s.charges, 3, 5, "laddningarna rullas om ur def-intervallet")
	assert_signal_emitted(s, "respawned")
	GameState.remove_item("copper_ore", 1)

# ── Väder ur zonmodellen (3D-motsvarigheten till zon-nodens weather) ──────────

func test_zone_model_parses_weather():
	var f := FileAccess.open("res://data/zones/thais_fields.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	data["weather"] = "storm"
	var m := ZoneModel.new()
	m.parse(data, "thais_fields")
	assert_eq(m.weather, "storm")

func test_current_weather_resolves_from_model():
	var m := ZoneModel.new()
	m.weather = "storm"
	World.zone_model = m
	assert_eq(GatherNode3D.current_weather(), "storm")
	m.weather = "dynamic"
	assert_eq(GatherNode3D.current_weather(),
		Weather.resolve("dynamic", WeatherSystem.current),
		"dynamic ska följa det globala omgivningsvädret")
	World.zone_model = null
	assert_eq(GatherNode3D.current_weather(), Weather.CLEAR,
		"utan modell: klart väder (ingen bonus)")

# ── GatherNode3D: vy ──────────────────────────────────────────────────────────

func test_setup_places_on_tile_center():
	var n := GatherNode3D.new()
	add_child_autofree(n)
	n.setup("copper_vein", Vector2i(4, 7))
	assert_eq(n.position, Zone3D.tile_to_world3(Vector2i(4, 7)))
	assert_eq(n.display_name(), "Kopparådra")

func test_unknown_type_frees():
	var n := GatherNode3D.new()
	add_child_autofree(n)
	n.setup("finns_inte", Vector2i.ZERO)
	assert_push_error("okänd nodtyp")
	assert_true(n.is_queued_for_deletion(),
		"okänd nodtyp ska tas bort (samma regel som 2D)")

func test_depletion_shrinks_and_grays_label():
	var n := GatherNode3D.new()
	add_child_autofree(n)
	n.setup("copper_vein", Vector2i.ZERO)
	n.sim.charges = 1
	n.sim.apply_success()
	assert_true(n.depleted)
	assert_eq(n._label.modulate, Color(0.5, 0.5, 0.5),
		"uttömd nod ska gråna skylten")
	GameState.remove_item("copper_ore", 1)

# ── game3d: spawning ur node-punkter + klick-routing ──────────────────────────

func test_game3d_spawns_nodes_from_zone_points():
	var g := _boot()   # _ready laddar thais_fields
	assert_eq(_nodes(g).size(), g.model.node_points.size(),
		"varje node-punkt ska ge en GatherNode3D")
	assert_gt(_nodes(g).size(), 0, "fälten ska ha gather-noder")

func test_zone_change_replaces_nodes():
	var g := _boot()
	var before := _nodes(g).size()
	assert_gt(before, 0)
	g.load_zone("thais_wilds")
	assert_eq(_nodes(g).size(), g.model.node_points.size(),
		"noderna ska bytas ut med zonen")
	assert_null(g.player.gather_target, "zonbytet ska nolla gather-målet")

func test_click_gather_node_sets_gather_target():
	var g := _boot()
	var n: GatherNode3D = _nodes(g)[0]
	g.player.snap_to(n.tile + Vector2i(1, 0))   # intill → nåbar utan path
	g._click_tile(n.tile)
	assert_eq(g.player.gather_target, n,
		"klick på gather-nod ska sätta gather-målet")

func test_click_ground_clears_gather_target():
	var g := _boot()
	var n: GatherNode3D = _nodes(g)[0]
	g.player.snap_to(n.tile + Vector2i(1, 0))
	g._click_tile(n.tile)
	assert_eq(g.player.gather_target, n)
	g._click_tile(g.model.player_start)
	assert_null(g.player.gather_target,
		"klick-för-att-gå ska nolla gather-målet (som 2D:s walk_to)")

func test_monster_target_clears_gather_target():
	var g := _boot()
	var n: GatherNode3D = _nodes(g)[0]
	g.player.snap_to(n.tile + Vector2i(1, 0))
	g._click_tile(n.tile)
	var m: Monster3D = null
	for c in g._monsters_root.get_children():
		if c is Monster3D:
			m = c
			break
	assert_not_null(m, "fälten ska ha monster")
	g._set_target(m)
	assert_null(g.player.gather_target, "strid ersätter gather (som 2D)")
	assert_eq(g.player.sim.target, m.sim)

# ── Player3D: gather-tick med samma besked som 2D ─────────────────────────────

func _adjacent_node(g: Node3D, type: String) -> GatherNode3D:
	var n := GatherNode3D.new()
	g._npcs_root.add_child(n)
	n.setup(type, g.model.player_start + Vector2i(1, 0))
	g.player.snap_to(g.model.player_start)
	g.player.set_gather_target(n)
	return n

func test_gather_tick_no_tool_shows_need_message():
	var g := _boot()
	var n := _adjacent_node(g, "copper_vein")
	assert_eq(g.player.gather_target, n)
	GameState.inventory.erase("pickaxe")
	g.player._update_gather(0.016)
	assert_true(g.hud._msg_lbl.text.begins_with("Du behöver"),
		"utan verktyg: 'Du behöver'-besked, samma UX som 2D")
	assert_null(g.player.gather_target)

func test_gather_tick_low_level_shows_requirement():
	var g := _boot()
	var n := _adjacent_node(g, "copper_vein")
	GameState.add_item("pickaxe", 1)
	n.sim.def["level"] = 99
	g.player._update_gather(0.016)
	assert_true(g.hud._msg_lbl.text.begins_with("Kräver"),
		"för låg nivå: kravbesked, samma UX som 2D")
	assert_null(g.player.gather_target)
	GameState.remove_item("pickaxe", 1)
