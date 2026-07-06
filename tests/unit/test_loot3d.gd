extends GutTest
## Markloot i 3D-slicen: GroundItem3D (monsterdrop + grav) med samma regler
## som 2D:s GroundItem — 1 rutas pickup-räckvidd, 60 s livstid med blink,
## persistent grav-loot som rensar GameState-graven. World.drop_death_loot
## är den delade döds-bokföringen (extraherad ur _on_player_died).

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model
var _saved_grave: Array   # [zone, tile, drops]

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model
	_saved_grave = [GameState.grave_zone, GameState.grave_tile, GameState.grave_drops]

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model
	GameState.grave_zone = _saved_grave[0]
	GameState.grave_tile = _saved_grave[1]
	GameState.grave_drops = _saved_grave[2]

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

# ── GroundItem3D: placering, pickup, livstid ──────────────────────────────────

func test_setup_places_on_tile_center():
	var gi := GroundItem3D.new()
	add_child_autofree(gi)
	gi.setup([{"item": "log", "qty": 2}], Vector2i(3, 8))
	assert_eq(gi.position, Zone3D.tile_to_world3(Vector2i(3, 8)))
	assert_eq(gi.tile, Vector2i(3, 8))

func test_pickup_out_of_reach_leaves_loot():
	var g := _boot()
	var gi: GroundItem3D = g._spawn_loot3d([{"item": "log", "qty": 1}], Vector2i(5, 5))
	GameState.player_tile = Vector2i(9, 5)
	var logs0 := int(GameState.inventory.get("log", 0))
	gi.interact()
	assert_eq(int(GameState.inventory.get("log", 0)), logs0,
		"utom räckvidd: inget plockas")
	assert_false(gi.is_queued_for_deletion())
	assert_true(g.hud._msg_lbl.text.begins_with("För långt bort"),
		"samma besked som 2D")

func test_pickup_in_reach_collects_all():
	var g := _boot()
	var gi: GroundItem3D = g._spawn_loot3d(
		[{"item": "log", "qty": 2}, {"item": "copper_ore", "qty": 1}], Vector2i(5, 5))
	GameState.player_tile = Vector2i(6, 5)
	var logs0 := int(GameState.inventory.get("log", 0))
	var ore0 := int(GameState.inventory.get("copper_ore", 0))
	gi.interact()
	assert_eq(int(GameState.inventory.get("log", 0)), logs0 + 2)
	assert_eq(int(GameState.inventory.get("copper_ore", 0)), ore0 + 1)
	assert_true(gi.is_queued_for_deletion(), "tömd påse försvinner")
	GameState.remove_item("log", 2)
	GameState.remove_item("copper_ore", 1)

func test_expires_after_lifetime():
	var gi := GroundItem3D.new()
	add_child_autofree(gi)
	gi.setup([{"item": "log", "qty": 1}], Vector2i.ZERO)
	gi._process(GroundItem.LIFETIME + 1.0)
	assert_true(gi.is_queued_for_deletion(), "påsen ska försvinna efter livstiden")

func test_persistent_loot_never_expires():
	var gi := GroundItem3D.new()
	add_child_autofree(gi)
	gi.setup([{"item": "log", "qty": 1}], Vector2i.ZERO)
	gi.persistent = true
	gi._process(GroundItem.LIFETIME + 1.0)
	assert_false(gi.is_queued_for_deletion(), "grav-loot tickar inte ned")

# ── game3d: monsterdrop och klick-routing ─────────────────────────────────────

func test_monster_death_spawns_loot_on_tile():
	var g := _boot()
	var m: Monster3D = null
	for c in g._monsters_root.get_children():
		if c is Monster3D:
			m = c
			break
	assert_not_null(m, "fälten ska ha monster")
	g._on_monster_dropped([{"item": "log", "qty": 1}], m.sim)
	var loot := _loot(g)
	assert_eq(loot.size(), 1, "monsterdöd med drops ska ge en lootpåse")
	assert_eq(loot[0].tile, m.sim.tile, "påsen ska ligga på dödstilen")

func test_empty_drops_spawn_nothing():
	var g := _boot()
	g._on_monster_dropped([], null)
	assert_eq(_loot(g).size(), 0, "tom loot-rull ska inte ge någon påse")

func test_click_loot_via_interactable_router():
	var g := _boot()
	var gi: GroundItem3D = g._spawn_loot3d([{"item": "log", "qty": 1}], Vector2i(5, 5))
	g.player.snap_to(Vector2i(6, 5))
	var logs0 := int(GameState.inventory.get("log", 0))
	g._click_tile(Vector2i(5, 5))
	assert_eq(int(GameState.inventory.get("log", 0)), logs0 + 1,
		"klick på lootpåsen inom räckvidd ska plocka den")
	assert_true(gi.is_queued_for_deletion())
	GameState.remove_item("log", 1)

# ── Grav: delad bokföring + 3D-vy ─────────────────────────────────────────────

func test_drop_death_loot_sets_grave():
	GameState.add_item("log", 4)
	GameState.current_zone = "thais_fields"
	GameState.player_tile = Vector2i(7, 7)
	World.drop_death_loot()
	assert_true(GameState.has_grave(), "döds-droppen ska bokföra en grav")
	assert_eq(GameState.grave_zone, "thais_fields")
	assert_eq(GameState.grave_tile, Vector2i(7, 7))
	# Återställ: lägg tillbaka allt som droppades och rensa graven.
	for d in GameState.grave_drops:
		GameState.add_item(String(d["item"]), int(d["qty"]))
	GameState.clear_grave()
	GameState.remove_item("log", 4)

func test_zone_load_spawns_grave_here():
	var g := _boot()
	GameState.set_grave("thais_fields", Vector2i(6, 6), [{"item": "log", "qty": 3}])
	g.load_zone("thais_fields")
	var graves := _loot(g).filter(func(gi): return gi.is_grave)
	assert_eq(graves.size(), 1, "grav-zonen ska återskapa lootpåsen vid zonladdning")
	assert_eq(graves[0].tile, Vector2i(6, 6))
	assert_true(graves[0].persistent)
	GameState.clear_grave()

func test_zone_load_skips_grave_elsewhere():
	var g := _boot()
	GameState.set_grave("thais_wilds", Vector2i(6, 6), [{"item": "log", "qty": 3}])
	g.load_zone("thais_fields")
	var graves := _loot(g).filter(func(gi): return gi.is_grave)
	assert_eq(graves.size(), 0, "graven ligger i en annan zon — ingen påse här")
	GameState.clear_grave()

func test_grave_pickup_clears_gamestate_grave():
	var g := _boot()
	GameState.set_grave("thais_fields", Vector2i(6, 6), [{"item": "log", "qty": 3}])
	g.load_zone("thais_fields")
	var grave: GroundItem3D = _loot(g).filter(func(gi): return gi.is_grave)[0]
	GameState.player_tile = Vector2i(6, 7)
	grave.interact()
	assert_false(GameState.has_grave(), "upphämtad grav ska rensas ur GameState")
	GameState.remove_item("log", 3)
