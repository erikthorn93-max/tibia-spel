extends GutTest
## Ryggsäcks-drag till marken i 3D-slicen: World.drop_item är renderer-
## agnostisk bokföring + item_dropped-signal; game3d spawnar GroundItem3D
## (gated på att ingen 2D-zon lever) och Hud3D bär world_drop_zone så
## drag-and-drop ur ryggsäck/utrustning fungerar som i 2D.

const Game3DScene = preload("res://world/game3d.tscn")
const WorldDropZone = preload("res://ui/world_drop_zone.gd")

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

func _loot(g: Node3D) -> Array:
	var out := []
	for n in g._npcs_root.get_children():
		if n is GroundItem3D:
			out.append(n)
	return out

# ── World.drop_item: bokföring + signal (renderer-agnostiskt) ─────────────────

func test_drop_item_removes_from_inventory_and_emits():
	GameState.add_item("log", 3)
	GameState.player_tile = Vector2i(4, 4)
	var logs0 := int(GameState.inventory.get("log", 0))
	watch_signals(World)
	World.drop_item("log", 2)
	assert_eq(int(GameState.inventory.get("log", 0)), logs0 - 2,
		"droppen ska bokföras även utan 2D-zon")
	assert_signal_emitted_with_parameters(World, "item_dropped",
		[[{"item": "log", "qty": 2}], Vector2i(4, 4)])
	GameState.remove_item("log", 1)

# ── game3d: signalen spawnar påsen på spelar-tilen ────────────────────────────

func test_drop_spawns_ground_item3d_at_player_tile():
	var g := _boot()
	GameState.add_item("log", 1)
	GameState.player_tile = Vector2i(5, 5)
	World.drop_item("log", 1)
	var loot := _loot(g)
	assert_eq(loot.size(), 1, "droppen ska ge en lootpåse i 3D")
	assert_eq(loot[0].tile, Vector2i(5, 5), "påsen ska ligga på spelar-tilen")
	assert_eq(loot[0].contents, [{"item": "log", "qty": 1}])

func test_dropped_item_can_be_picked_up_again():
	var g := _boot()
	GameState.add_item("log", 1)
	GameState.player_tile = Vector2i(5, 5)
	var logs0 := int(GameState.inventory.get("log", 0))
	World.drop_item("log", 1)
	_loot(g)[0].interact()
	assert_eq(int(GameState.inventory.get("log", 0)), logs0,
		"påsen inom räckvidd ska kunna plockas tillbaka")
	GameState.remove_item("log", 1)

# ── Hud3D: world_drop_zone finns och tar emot drag-data ───────────────────────

func test_hud3d_carries_world_drop_zone():
	var g := _boot()
	var zones := []
	for c in g.hud.get_children():
		if c is WorldDropZone:
			zones.append(c)
	assert_eq(zones.size(), 1, "HUD-bryggan ska bära exakt en world_drop_zone")
	assert_eq(g.hud.get_child(0), zones[0], "drop-zonen ska ligga bakom panelerna")

func test_drop_zone_drag_drops_inventory_item():
	var g := _boot()
	GameState.add_item("log", 1)
	GameState.player_tile = Vector2i(6, 6)
	var dz: Control = g.hud.get_child(0)
	assert_true(dz._can_drop_data(Vector2.ZERO, {"item_id": "log", "qty": 1}))
	dz._drop_data(Vector2.ZERO, {"item_id": "log", "qty": 1, "source": "inventory"})
	var loot := _loot(g)
	assert_eq(loot.size(), 1, "drag till drop-zonen ska lägga påsen på marken")
	assert_eq(loot[0].tile, Vector2i(6, 6))
	assert_true(g.hud._msg_lbl.text.begins_with("Du tappade"),
		"samma besked som 2D")

func test_drop_zone_equipment_drag_unequips_first():
	var g := _boot()
	GameState.add_item("copper_helmet", 1)
	assert_true(GameState.equip("helmet", "copper_helmet"),
		"förutsättning: hjälmen ska gå att ta på")
	GameState.player_tile = Vector2i(6, 6)
	var dz: Control = g.hud.get_child(0)
	dz._drop_data(Vector2.ZERO, {"item_id": "copper_helmet", "qty": 1,
		"source": "equipment", "source_slot": "helmet"})
	assert_eq(String(GameState.equipment.get("helmet", "")), "",
		"utrustningen ska tas av innan droppen")
	var loot := _loot(g)
	assert_eq(loot.size(), 1, "avtagen utrustning ska hamna på marken")
	loot[0].queue_free()
