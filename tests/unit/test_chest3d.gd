extends GutTest
## Skattkistor i 3D-slicen: loot-rullen delas med 2D (TreasureChest.open_loot),
## Chest3D spawnas ur zonens chest-punkter (dungeons), klick inom 1 ruta ger
## engångsloot och kistan grånar — samma UX som 2D.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_gold: int
var _saved_inventory: Dictionary

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_gold = GameState.gold
	_saved_inventory = GameState.inventory.duplicate()

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	GameState.gold = _saved_gold
	GameState.inventory = _saved_inventory

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _chests(g: Node3D) -> Array:
	var out := []
	for n in g._npcs_root.get_children():
		if n is Chest3D:
			out.append(n)
	return out

# ── Delad loot-kärna (TreasureChest.open_loot) ────────────────────────────────

func test_open_loot_ger_guld_i_temats_intervall():
	var before := GameState.gold
	var msg := TreasureChest.open_loot("katakomber")
	var gained := GameState.gold - before
	assert_between(gained, 150, 400, "katakombernas chest_gold är [150, 400]")
	assert_true(msg.begins_with("Kistan: Du fick %d guld" % gained),
		"beskedet ska börja med guldsumman, samma format som 2D")
	assert_true(msg.ends_with("!"))

func test_open_loot_okant_tema_ger_standardguld():
	var before := GameState.gold
	TreasureChest.open_loot("finns_inte")
	assert_between(GameState.gold - before, 50, 150,
		"okänt tema ska falla tillbaka på standardintervallet [50, 150]")

# ── Chest3D: placering och visual ─────────────────────────────────────────────

func test_setup_places_on_tile_center():
	var c := Chest3D.new()
	add_child_autofree(c)
	c.setup(Vector2i(4, 7), "katakomber")
	assert_eq(c.position, Zone3D.tile_to_world3(Vector2i(4, 7)))
	assert_eq(c.display_name(), "Skattkista")
	assert_false(c.opened)

func test_visual_uses_chest_glb():
	var c := Chest3D.new()
	add_child_autofree(c)
	c.setup(Vector2i.ZERO, "katakomber")
	assert_true(ResourceLoader.exists("res://assets/models3d/treasure_chest.glb"),
		"kistmodellen ska finnas i modellbiblioteket")
	assert_almost_eq(c._base_scale.y, float(Chest3D.MODEL["h"]), 0.001,
		"GLB-vägen ska sätta världshöjden ur MODEL")

# ── game3d: spawning ur chest-punkter ─────────────────────────────────────────

func test_dungeon_spawns_chest_from_zone_points():
	var g := _boot()
	g.enter_dungeon("katakomber")
	assert_eq(_chests(g).size(), g.model.chest_points.size(),
		"varje chest-punkt ska ge en Chest3D")
	assert_eq(_chests(g).size(), 1, "generatorn lägger exakt en kista per dungeon")

func test_zone_change_clears_chests():
	var g := _boot()
	g.enter_dungeon("katakomber")
	assert_eq(_chests(g).size(), 1)
	g.load_zone("thais_fields")
	assert_eq(_chests(g).size(), 0, "ytzonen har inga kistor — vyerna ska städas")

# ── Klick-interaktion (engångsloot, räckvidd) ─────────────────────────────────

func test_click_chest_out_of_reach_shows_go_closer():
	var g := _boot()
	g.enter_dungeon("katakomber")
	var c: Chest3D = _chests(g)[0]
	GameState.player_tile = c.tile + Vector2i(5, 0)
	var before := GameState.gold
	g._click_tile(c.tile)
	assert_false(c.opened, "utom räckvidd: kistan förblir stängd")
	assert_eq(GameState.gold, before, "utom räckvidd: inget guld")
	assert_eq(g.hud._msg_lbl.text, "Gå intill kistan.",
		"samma besked som 2D-kistan")

func test_click_chest_in_reach_loots_once():
	var g := _boot()
	g.enter_dungeon("katakomber")
	var c: Chest3D = _chests(g)[0]
	GameState.player_tile = c.tile + Vector2i(1, 0)
	var before := GameState.gold
	g._click_tile(c.tile)
	assert_true(c.opened, "inom räckvidd: kistan öppnas")
	assert_between(GameState.gold - before, 150, 400, "temats guld bokförs")
	assert_true(g.hud._msg_lbl.text.begins_with("Kistan:"),
		"lootbeskedet ska visas i HUD:en")
	var after_first := GameState.gold
	g._click_tile(c.tile)
	assert_eq(GameState.gold, after_first, "engångsloot: andra klicket ger inget")

func test_opened_chest_grays_label():
	var c := Chest3D.new()
	add_child_autofree(c)
	c.setup(Vector2i.ZERO, "katakomber")
	GameState.player_tile = c.tile + Vector2i(1, 0)
	c.interact()
	assert_true(c.opened)
	assert_eq(c._label.modulate, Color(0.5, 0.5, 0.5),
		"öppnad kista ska gråna skylten, som 2D:s gråtoning")
