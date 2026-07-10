extends GutTest
## 3D som spelbar session: huvudmenyns 3D-läge (World.use_3d) routar spel-
## scenerna, game3d bootar från GameState (sparfilen) när sessionen är
## menystartad, och sparande sker bara i menystartade sessioner — F6-dev
## och testsviten rör aldrig spelarens sparfil.

const Game3DScript = preload("res://world/game3d.gd")
const Game3DScene = preload("res://world/game3d.tscn")
const MainMenuScene = preload("res://ui/main_menu.tscn")
const TEST_SAVE := "user://test_session3d_save.json"

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model
var _saved_use3d: bool
var _saved_path: String
var _saved_surface_zone: String
var _saved_surface_tile: Vector2i

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model
	_saved_use3d = World.use_3d
	_saved_path = SaveManager.save_path
	_saved_surface_zone = World.last_surface_zone
	_saved_surface_tile = World.last_surface_tile
	SaveManager.save_path = TEST_SAVE   # inga tester rör riktiga sparfilen

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model
	World.use_3d = _saved_use3d
	SaveManager.save_path = _saved_path
	World.last_surface_zone = _saved_surface_zone
	World.last_surface_tile = _saved_surface_tile
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)

# ── Scenrouting (huvudmenyn/character creator) ────────────────────────────────

func test_game_scene_path_follows_use_3d():
	World.use_3d = false
	assert_eq(World.game_scene_path(), "res://world/game.tscn")
	World.use_3d = true
	assert_eq(World.game_scene_path(), "res://world/game3d.tscn")

func test_menu_checkbox_sets_use_3d():
	World.use_3d = false
	var menu: Control = MainMenuScene.instantiate()
	add_child_autofree(menu)
	var chk: CheckButton = null
	for c in menu.get_node("VBox").get_children():
		if c is CheckButton:
			chk = c
	assert_not_null(chk, "menyn ska ha 3D-lägesknappen")
	chk.button_pressed = true
	assert_true(World.use_3d, "3D-knappen ska sätta World.use_3d")

# ── Boot-regeln (samma som 2D:s game_root för menystartade sessioner) ─────────

func test_boot_target_dev_run_uses_slice_zone():
	var bt: Dictionary = Game3DScript.boot_target(false, "town", Vector2i(9, 9))
	assert_eq(String(bt["zone"]), Game3DScript.START_ZONE,
		"F6-dev/tester ska boota slice-startzonen")
	assert_eq(bt["tile"], Vector2i(-1, -1))

func test_boot_target_menu_launch_honors_gamestate():
	var bt: Dictionary = Game3DScript.boot_target(true, "town", Vector2i(9, 9))
	assert_eq(String(bt["zone"]), "town", "menystart ska boota sparfilens zon")
	assert_eq(bt["tile"], Vector2i(9, 9), "…och sparfilens tile")

func test_boot_target_zero_tile_falls_to_player_start():
	var bt: Dictionary = Game3DScript.boot_target(true, "town", Vector2i.ZERO)
	assert_eq(bt["tile"], Vector2i(-1, -1),
		"nytt spel (tile 0,0) ska landa på zonens player_start")

func test_boot_target_missing_zone_falls_to_slice_zone():
	var bt: Dictionary = Game3DScript.boot_target(true, "dungeon:cave", Vector2i(4, 4))
	assert_eq(String(bt["zone"]), Game3DScript.START_ZONE,
		"zon utan fil (efemär dungeon) ska falla till slice-startzonen")

func test_menu_launched_boot_loads_gamestate_zone():
	World.use_3d = true
	GameState.current_zone = "town"
	GameState.player_tile = Vector2i.ZERO
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	assert_eq(g.model.zone_id, "town", "menystartad 3D-session ska boota GameStates zon")

# ── Sparande: bara menystartade sessioner ─────────────────────────────────────

func test_save_session_skipped_for_dev_runs():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	World.use_3d = false
	g._save_session()
	assert_false(FileAccess.file_exists(TEST_SAVE),
		"F6-dev/tester får aldrig skriva sparfilen")

func test_save_session_writes_for_menu_sessions():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	World.use_3d = true
	g._save_session()
	assert_true(FileAccess.file_exists(TEST_SAVE),
		"menystartad session ska spara")

func test_enter_dungeon_saves_surface_zone():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	World.use_3d = true
	var surface := GameState.current_zone
	var stile: Vector2i = g.player.sim.tile
	g.enter_dungeon("katakomber")
	assert_eq(World.last_surface_zone, surface,
		"ytzonen ska bokföras i World för dungeon-normaliseringen")
	assert_eq(World.last_surface_tile, stile)
	var snap := SaveManager.read_snapshot()
	assert_eq(String(snap.get("zone", "")), surface,
		"sparfilen ska bära ytzonen — aldrig den efemära dungeonzonen")
