extends GutTest
## Headless-tester för Npc3D (NPC-vyn i 3D-slicen) och game3d:s NPC-spawning
## + klick-interaktion: dialog-NPC:er ur DialogueDB och service-NPC:er
## (handlare/bankir/magiker) ur zonens legend-punkter.

const Npc3DScript = preload("res://entities/npc/npc3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud   # Hud3D sätter World.hud = self vid _ready

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

func _make_npc(kind: String, t: Vector2i, id := "") -> Npc3D:
	var n: Npc3D = Npc3DScript.new()
	add_child_autofree(n)
	n.setup(kind, t, id)
	return n

# ── Npc3D: placering, gestalt och namn ────────────────────────────────────────

func test_setup_places_on_tile_center():
	var n := _make_npc("shop", Vector2i(3, 7))
	assert_eq(n.position, Zone3D.tile_to_world3(Vector2i(3, 7)))

func test_service_npc_display_names():
	assert_eq(_make_npc("shop", Vector2i.ZERO).display_name(), "Handlaren")
	assert_eq(_make_npc("bank", Vector2i.ZERO).display_name(), "Bankiren")

func test_dialogue_npc_name_from_dialogue_db():
	var n := _make_npc("dialogue", Vector2i.ZERO, "npc_ranger")
	assert_eq(n.display_name(), String(DialogueDB.npcs["npc_ranger"]["name"]),
		"dialog-NPC:n ska visa namnet ur DialogueDB")

func test_civilian_model_is_deterministic_per_id():
	var n1 := _make_npc("dialogue", Vector2i.ZERO, "npc_ranger")
	var n2 := _make_npc("dialogue", Vector2i.ZERO, "npc_ranger")
	assert_eq(n1._model_file(), n2._model_file(),
		"samma npc_id ska alltid ge samma civilmodell")
	assert_has(Npc3D.CIVILIAN_MODELS, n1._model_file())

func test_special_model_overrides_civilian():
	var n := _make_npc("dialogue", Vector2i.ZERO, "npc_tibianus")
	assert_eq(n._model_file(), "king", "kungen ska få sin givna gestalt")

func test_npc_vander_sig_mot_spelaren():
	var n := _make_npc("shop", Vector2i(5, 5))
	GameState.player_tile = Vector2i(6, 5)   # öster om NPC:n
	n._process(0.016)
	assert_almost_eq(n._body.rotation.y, atan2(-1.0, 0.0) + PI, 0.001,
		"NPC:n ska vrida kroppen mot spelaren i närheten")

func test_npc_ignorerar_avlagsen_spelare():
	var n := _make_npc("shop", Vector2i(5, 5))
	var before: float = n._body.rotation.y
	GameState.player_tile = Vector2i(20, 20)   # utom ATTENTION_DIST
	n._process(0.016)
	assert_almost_eq(n._body.rotation.y, before, 0.001,
		"långt borta: kroppen ska inte vridas")

func test_quest_marker_only_for_dialogue_npcs():
	var d := _make_npc("dialogue", Vector2i.ZERO, "npc_ranger")
	var s := _make_npc("shop", Vector2i.ZERO)
	assert_not_null(d._quest_marker, "dialog-NPC:er ska ha en quest-markör")
	assert_null(s._quest_marker, "service-NPC:er ska inte ha quest-markör")

# ── game3d: NPC-spawning per zon ──────────────────────────────────────────────

func _boot_game3d() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _npcs_of_kind(g: Node3D, kind: String) -> Array:
	var out := []
	for n in g._npcs_root.get_children():
		if n is Npc3D and n.kind == kind:
			out.append(n)
	return out

func test_game3d_spawns_dialogue_npcs_for_zone():
	var g := _boot_game3d()
	var expected := 0
	for id in DialogueDB.npcs:
		if String(DialogueDB.npcs[id]["zone"]) == g.model.zone_id:
			expected += 1
	assert_gt(expected, 0, "startzonen ska ha minst en dialog-NPC (npc_ranger)")
	assert_eq(_npcs_of_kind(g, "dialogue").size(), expected,
		"varje dialog-NPC i zonen ska få en Npc3D")

func test_game3d_spawns_service_npcs_from_legend_points():
	var g := _boot_game3d()
	g.load_zone("town")
	assert_eq(_npcs_of_kind(g, "shop").size(), g.model.shop_points.size(),
		"varje shop-punkt ska ge en handlare")
	assert_eq(_npcs_of_kind(g, "bank").size(), g.model.bank_points.size(),
		"varje bank-punkt ska ge en bankir")
	assert_eq(_npcs_of_kind(g, "spell_teacher").size(),
		g.model.spell_teacher_points.size(),
		"varje spell_teacher-punkt ska ge en magiker")

func test_zone_change_replaces_npcs():
	var g := _boot_game3d()
	var before: Node3D = g._npcs_root
	g.load_zone("town")
	assert_ne(g._npcs_root, before, "zonbytet ska bygga en ny NPC-rot")
	assert_gt(g._npcs_root.get_child_count(), 0, "town ska ha NPC:er")

# ── game3d: klick-interaktion ─────────────────────────────────────────────────

func test_click_npc_out_of_reach_shows_go_closer():
	var g := _boot_game3d()
	var npcs := _npcs_of_kind(g, "dialogue")
	assert_gt(npcs.size(), 0)
	var n: Npc3D = npcs[0]
	GameState.player_tile = n.tile + Vector2i(10, 0)   # långt utanför räckvidd
	g._click_tile(n.tile)
	assert_false(g.hud.dialogue_box.visible, "utom räckvidd: ingen dialog")
	assert_true(g.hud._msg_lbl.text.begins_with("Gå närmare"),
		"utom räckvidd: 'Gå närmare'-besked, samma UX som 2D")

func test_click_dialogue_npc_in_reach_opens_dialogue():
	var g := _boot_game3d()
	var npcs := _npcs_of_kind(g, "dialogue")
	var n: Npc3D = npcs[0]
	GameState.player_tile = n.tile + Vector2i(2, 0)   # dialograckvidd: 2 rutor
	g._click_tile(n.tile)
	assert_true(g.hud.dialogue_box.visible,
		"inom räckvidd ska klicket öppna dialogrutan")

func test_click_service_npc_in_reach_opens_panel():
	var g := _boot_game3d()
	g.load_zone("town")
	var shops := _npcs_of_kind(g, "shop")
	assert_gt(shops.size(), 0, "town ska ha en handlare")
	var n: Npc3D = shops[0]
	GameState.player_tile = n.tile + Vector2i(1, 0)   # serviceräckvidd: 1 ruta
	g._click_tile(n.tile)
	assert_true(g.hud.shop_panel.visible,
		"klick på handlaren inom räckvidd ska öppna butiken")

func test_zone_change_closes_open_panels():
	var g := _boot_game3d()
	g.load_zone("town")
	g.hud.open_shop()
	assert_true(g.hud.shop_panel.visible)
	g.load_zone("thais_fields")
	assert_false(g.hud.shop_panel.visible,
		"zonbytet ska stänga paneler som hörde till förra zonen")
