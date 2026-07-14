extends GutTest
## Boss-markören i 3D: otillgänglig boss (task-cooldown) ger en pollande
## BossMarker3D i stället för monster; markören meddelar spelaren i närheten
## och spawnar bossen när cooldownen löpt ut — samma regler som 2D:s
## boss_marker.gd. Utan den dök bossen aldrig upp i 3D förrän zonombyggnad.

const Game3DScene = preload("res://world/game3d.tscn")
const BOSS := "Ghulkungen"
const BOSS_ZONE := "cave"

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud

func after_each():
	TaskSystem.boss_kill_times.erase(BOSS)
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func _make_boss_unavailable() -> void:
	TaskSystem.boss_kill_times[BOSS] = Time.get_unix_time_from_system()

func _markers(g: Node3D) -> Array:
	var out: Array = []
	for c in g._monsters_root.get_children():
		if c is BossMarker3D:
			out.append(c)
	return out

func _boss_views(g: Node3D) -> Array:
	var out: Array = []
	for c in g._monsters_root.get_children():
		if c is Monster3D and c.sim.monster_name == BOSS:
			out.append(c)
	return out

# ── Spawning ──────────────────────────────────────────────────────────────────

func test_unavailable_boss_spawns_marker_not_monster():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	assert_eq(_markers(g).size(), 1, "cooldown-boss ska ge exakt en markör")
	assert_eq(_boss_views(g).size(), 0, "bossen själv ska inte spawnas")

func test_available_boss_spawns_monster_directly():
	TaskSystem.boss_kill_times.erase(BOSS)
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	assert_eq(_markers(g).size(), 0, "tillgänglig boss ska inte ge markör")
	assert_eq(_boss_views(g).size(), 1, "bossen ska spawnas som Monster3D")

func test_marker_sits_on_boss_tile():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	var bm: BossMarker3D = _markers(g)[0]
	assert_eq(bm.monster_name, BOSS)
	assert_eq(bm.position, Zone3D.tile_to_world3(bm.tile),
		"markören ska stå på bossens spawnruta i världskoordinater")

# ── Cooldown löper ut ─────────────────────────────────────────────────────────

func test_marker_spawns_boss_when_cooldown_over():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	var bm: BossMarker3D = _markers(g)[0]
	TaskSystem.boss_kill_times.erase(BOSS)   # cooldownen har löpt ut
	bm._process(BossMarker3D.CHECK_INTERVAL + 0.1)
	assert_eq(_boss_views(g).size(), 1,
		"markören ska spawna bossen när den blir tillgänglig")
	assert_true(bm.is_queued_for_deletion(), "markören ska ta bort sig själv")

func test_marker_waits_while_cooldown_remains():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	var bm: BossMarker3D = _markers(g)[0]
	bm._process(BossMarker3D.CHECK_INTERVAL + 0.1)
	assert_eq(_boss_views(g).size(), 0, "ingen boss medan cooldownen pågår")
	assert_false(bm.is_queued_for_deletion(), "markören ska ligga kvar")

# ── Närhetsmeddelandet ────────────────────────────────────────────────────────

func test_marker_messages_nearby_player():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	var bm: BossMarker3D = _markers(g)[0]
	GameState.player_tile = bm.tile + Vector2i(2, 0)   # inom MSG_RANGE
	bm._process(BossMarker3D.CHECK_INTERVAL + 0.1)
	assert_string_contains(g.hud._msg_lbl.text, "är inte här",
		"spelare i närheten ska få cooldown-beskedet")

func test_marker_silent_for_distant_player():
	_make_boss_unavailable()
	var g := _boot()
	g.load_zone(BOSS_ZONE)
	var bm: BossMarker3D = _markers(g)[0]
	g.hud._msg_lbl.text = ""
	GameState.player_tile = bm.tile + Vector2i(BossMarker3D.MSG_RANGE + 1, 0)
	bm._process(BossMarker3D.CHECK_INTERVAL + 0.1)
	assert_eq(g.hud._msg_lbl.text, "", "spelare utom räckhåll ska inte störas")
