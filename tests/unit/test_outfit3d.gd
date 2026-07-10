extends GutTest
## Garderoben i 3D-slicen: Hud3D bär 2D:ns wardrobe-panel (U) och Player3D
## läser outfiten som en färgton i tröjfärgen via en delad additiv
## material_overlay (samma idiom som Monster3D:s elite/enrage) — GLB-hjälten
## har bakad textur utan färgzoner, så per-plagg-färger är inte möjliga.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model
var _saved_outfit: String
var _saved_appearance: Dictionary
var _saved_base: Dictionary

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model
	_saved_outfit = GameState.outfit_equipped
	_saved_appearance = GameState.appearance.duplicate()
	_saved_base = GameState.appearance_base.duplicate()

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model
	GameState.outfit_equipped = _saved_outfit
	GameState.appearance = _saved_appearance
	GameState.appearance_base = _saved_base

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _meshes(n: Node, out: Array) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)
	return out

# ── Hud3D: garderobspanelen ───────────────────────────────────────────────────

func test_hud3d_carries_wardrobe():
	var g := _boot()
	assert_not_null(g.hud.wardrobe, "HUD-bryggan ska bära garderoben")
	g.hud.wardrobe.toggle()
	assert_true(g.hud.wardrobe.visible, "toggle ska öppna garderoben")

func test_close_all_hides_wardrobe():
	var g := _boot()
	g.hud.wardrobe.toggle()
	g.hud.close_all()
	assert_false(g.hud.wardrobe.visible, "Escape/close_all ska stänga garderoben")

# ── Player3D: outfit-tint via delad overlay ───────────────────────────────────

func test_overlay_covers_all_body_meshes():
	var g := _boot()
	var meshes := _meshes(g.player._visual, [])
	assert_gt(meshes.size(), 0, "kroppen ska ha minst en mesh")
	for m in meshes:
		assert_eq(m.material_overlay, g.player._outfit_mat,
			"alla kroppsmeshar ska bära den delade outfit-overlayen")

func test_standard_outfit_is_invisible():
	var g := _boot()
	GameState.outfit_equipped = "standard"
	GameState.appearance_changed.emit()
	assert_eq(g.player._outfit_mat.albedo_color, Color.BLACK,
		"standard-outfiten ska inte tinta (svart = osynlig i additiv blend)")

func test_outfit_tints_with_shirt_color():
	var g := _boot()
	GameState.appearance["shirt"] = "#5a1f1f"
	GameState.outfit_equipped = "outfit_slayer"
	GameState.appearance_changed.emit()
	assert_eq(g.player._outfit_mat.albedo_color, Color("#5a1f1f").darkened(0.7),
		"outfiten ska tinta kroppen i dämpad tröjfärg")

func test_outfit_material_is_reused_not_reallocated():
	var g := _boot()
	var mat: StandardMaterial3D = g.player._outfit_mat
	GameState.outfit_equipped = "outfit_slayer"
	GameState.appearance_changed.emit()
	GameState.outfit_equipped = "standard"
	GameState.appearance_changed.emit()
	assert_eq(g.player._outfit_mat, mat,
		"outfit-byten ska bara ändra parametrar — aldrig allokera nytt material")
