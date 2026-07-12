extends GutTest
## Hantverksstationer i 3D-slicen: Station3D spawnas ur zonens
## station-punkter, klick-interaktion med 1 rutas räckvidd öppnar
## receptpanelen (bönaltaret → prayer-panelen), och zonbyte städar.

const Station3DScript = preload("res://entities/station3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _stations(g: Node3D) -> Array:
	var out := []
	for n in g._npcs_root.get_children():
		if n is Station3D:
			out.append(n)
	return out

# ── Station3D: placering och namn ─────────────────────────────────────────────

func test_setup_places_on_tile_center():
	var s: Station3D = Station3DScript.new()
	add_child_autofree(s)
	s.setup("anvil", Vector2i(5, 9))
	assert_eq(s.position, Zone3D.tile_to_world3(Vector2i(5, 9)))
	assert_eq(s.display_name(), "Städ")

func test_alla_stationstyper_har_farg():
	# Vakt: varje stationstyp i 2D-vyns LABELS ska ha en platshållarfärg.
	for type in CraftingStation.LABELS:
		assert_true(Station3D.COLORS.has(type),
			"stationstypen %s saknar färg i Station3D" % type)

func test_alla_stationstyper_har_glb_modell():
	# Vakt: varje stationstyp ska ha en procedural GLB (build_station_models.py).
	for type in CraftingStation.LABELS:
		assert_true(
			ResourceLoader.exists("res://assets/models3d/station_%s.glb" % type),
			"stationstypen %s saknar station_%s.glb" % [type, type])

func test_station_med_modell_far_glb_visual():
	var s: Station3D = Station3DScript.new()
	add_child_autofree(s)
	s.setup("anvil", Vector2i(2, 2))
	var has_model := false
	for c in s.get_children():
		if c is Node3D and not (c is Label3D) and not (c is MeshInstance3D):
			has_model = true   # GLB-scenens rot är en ren Node3D
	assert_true(has_model, "mappad station ska bära GLB-modellen, inte lådan")

func test_station_utan_modell_far_platshallarlada():
	var s: Station3D = Station3DScript.new()
	add_child_autofree(s)
	s.setup("okand_station", Vector2i(2, 2))
	var has_box := false
	for c in s.get_children():
		if c is MeshInstance3D:
			has_box = true
	assert_true(has_box, "omappad station ska falla tillbaka till lådan")

# ── game3d: spawning ur station-punkter ───────────────────────────────────────

func test_game3d_spawns_stations_from_zone_points():
	var g := _boot()
	g.load_zone("thais_depot_int")
	assert_eq(_stations(g).size(), g.model.station_points.size(),
		"varje station-punkt ska ge en Station3D")
	assert_gt(_stations(g).size(), 0, "depån ska ha stationer")

func test_zone_change_replaces_stations():
	var g := _boot()
	g.load_zone("thais_depot_int")
	var before := _stations(g).size()
	assert_gt(before, 0)
	g.load_zone("thais_fields")
	assert_eq(_stations(g).size(), g.model.station_points.size(),
		"stationerna ska bytas ut med zonen")

# ── Klick-interaktion ─────────────────────────────────────────────────────────

func test_click_station_out_of_reach_shows_go_closer():
	var g := _boot()
	g.load_zone("thais_depot_int")
	var s: Station3D = _stations(g)[0]
	GameState.player_tile = s.tile + Vector2i(5, 0)
	g._click_tile(s.tile)
	assert_false(g.hud.recipe_panel.visible, "utom räckvidd: ingen panel")
	assert_true(g.hud._msg_lbl.text.begins_with("Gå närmare"),
		"utom räckvidd: 'Gå närmare'-besked, samma UX som 2D")

func test_click_crafting_station_in_reach_opens_recipes():
	var g := _boot()
	g.load_zone("thais_depot_int")
	var s: Station3D = _stations(g)[0]
	GameState.player_tile = s.tile + Vector2i(1, 0)
	g._click_tile(s.tile)
	assert_true(g.hud.recipe_panel.visible,
		"klick på stationen inom räckvidd ska öppna receptpanelen")

func test_click_prayer_altar_opens_prayer_panel():
	var g := _boot()
	g.load_zone("tibianus_temple")   # templet har altaret som station (town: dekoration)
	var altar: Station3D = null
	for s in _stations(g):
		if s.station_type == "prayer_altar":
			altar = s
	assert_not_null(altar, "templet ska ha ett bönaltare")
	GameState.player_tile = altar.tile + Vector2i(1, 0)
	g._click_tile(altar.tile)
	assert_true(g.hud.prayer_panel.visible,
		"bönaltaret ska öppna prayer-panelen, inte receptpanelen")
	assert_false(g.hud.recipe_panel.visible)

func test_opening_shop_closes_recipe_panel():
	var g := _boot()
	g.load_zone("thais_depot_int")
	var s: Station3D = _stations(g)[0]
	GameState.player_tile = s.tile + Vector2i(1, 0)
	g._click_tile(s.tile)
	assert_true(g.hud.recipe_panel.visible)
	g.hud.open_shop()
	assert_false(g.hud.recipe_panel.visible,
		"ömsesidig uteslutning: butiken ska stänga receptpanelen")

func test_zone_change_closes_recipe_panel():
	var g := _boot()
	g.load_zone("thais_depot_int")
	g.hud.open_recipes("anvil")
	assert_true(g.hud.recipe_panel.visible)
	g.load_zone("thais_fields")
	assert_false(g.hud.recipe_panel.visible,
		"zonbytet ska stänga receptpanelen")
