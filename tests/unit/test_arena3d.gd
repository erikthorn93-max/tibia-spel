extends GutTest
## Arenan i 3D-slicen: game3d spawnar vågorna (world.gd:s handler är gated
## på 2D-zonen), att lämna sanden räknas som uppgivet, och Hud3D visar
## samma arenabanner som 2D-HUD:en.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud

func after_each():
	if ArenaSystem.is_active():
		ArenaSystem.abort()
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _wave_size(index: int) -> int:
	var n := 0
	for s in ArenaSystem.waves[index]["spawns"]:
		n += int(s["count"])
	return n

# ── Vågspawning ───────────────────────────────────────────────────────────────

func test_wave_spawns_monsters_in_arena():
	var g := _boot()
	g.load_zone("knight_arena")
	var before: int = g._monsters_root.get_child_count()
	assert_true(ArenaSystem.start(), "omgången ska kunna starta")
	assert_eq(g._monsters_root.get_child_count() - before, _wave_size(0),
		"första vågen ska spawna alla sina monster som Monster3D")

func test_wave_does_not_spawn_outside_arena_zone():
	var g := _boot()   # startar i thais_fields
	var before: int = g._monsters_root.get_child_count()
	ArenaSystem.start()
	assert_eq(g._monsters_root.get_child_count(), before,
		"vågen ska inte spawna när 3D-vyn inte visar arenazonen")

func test_cleared_wave_spawns_next():
	var g := _boot()
	g.load_zone("knight_arena")
	ArenaSystem.start()
	var after_first: int = g._monsters_root.get_child_count()
	for _i in range(ArenaSystem.remaining()):
		ArenaSystem.record_kill("testdocka")
	assert_eq(ArenaSystem.current_wave, 1, "avklarad våg ska ge nästa")
	assert_eq(g._monsters_root.get_child_count() - after_first, _wave_size(1),
		"andra vågen ska spawna i 3D-vyn")

func test_arena_spawn_tiles_respect_distance_and_walkability():
	var g := _boot()
	g.load_zone("knight_arena")
	var ptile: Vector2i = g.player.sim.tile
	for t: Vector2i in g._arena_spawn_tiles():
		assert_true(g.model.is_walkable(t), "spawnruta ska vara gångbar")
		assert_gte(maxi(absi(t.x - ptile.x), absi(t.y - ptile.y)), 2,
			"spawnruta ska ligga minst 2 steg från spelaren")

# ── Lämna sanden = uppgivet ───────────────────────────────────────────────────

func test_leaving_arena_aborts_round():
	var g := _boot()
	g.load_zone("knight_arena")
	ArenaSystem.start()
	assert_true(ArenaSystem.is_active())
	g.load_zone("thais_fields")
	assert_false(ArenaSystem.is_active(),
		"att lämna arenazonen ska avbryta omgången, som 2D")

# ── HUD-bannern ───────────────────────────────────────────────────────────────

func test_banner_shows_wave_and_hides_when_done():
	var g := _boot()
	g.load_zone("knight_arena")
	assert_false(g.hud._arena_lbl.visible, "ingen banner utan aktiv omgång")
	ArenaSystem.start()
	assert_true(g.hud._arena_lbl.visible)
	assert_string_contains(g.hud._arena_lbl.text, "Våg 1/%d" % ArenaSystem.wave_count())
	assert_string_contains(g.hud._arena_lbl.text, "%d kvar" % ArenaSystem.remaining())
	ArenaSystem.abort()
	assert_false(g.hud._arena_lbl.visible, "bannern ska släckas när omgången är slut")

func test_banner_updates_on_kill():
	var g := _boot()
	g.load_zone("knight_arena")
	ArenaSystem.start()
	var before: int = ArenaSystem.remaining()
	ArenaSystem.record_kill("testdocka")
	assert_string_contains(g.hud._arena_lbl.text, "%d kvar" % (before - 1),
		"bannern ska följa kill-räkningen live")
