extends GutTest
## Integrationstest: driver en HEL arenaomgång genom den LEVANDE kopplingen.
## Till skillnad från test_arena.gd (ren logik) bygger detta den riktiga
## knight_arena-zonen, sätter World.current_zone/player, och låter
## ArenaSystem.start() → World._on_arena_wave_started spawna äkta monster.
## Att fälla dem (take_damage) går via monster._die() → ArenaSystem.record_kill,
## så exakt det live-flöde som inte kunde testas på logiknivå verifieras här.

const ZoneScript = preload("res://world/zone.gd")
const PlayerScene = preload("res://entities/player/player.tscn")

var _zone: Node2D
var _player: Node2D
var _saved_zone
var _saved_model
var _saved_player

func before_each():
	ArenaSystem.reset()
	GameState.inventory.clear()
	UnlockSystem.unlocked.erase(ArenaSystem.CHAMPION_UNLOCK)
	_saved_zone = World.current_zone
	_saved_model = World.zone_model
	_saved_player = World.player
	_zone = ZoneScript.new()
	add_child_autofree(_zone)
	_zone.build(ArenaSystem.ARENA_ZONE)
	World.current_zone = _zone
	World.zone_model = _zone.model
	_player = PlayerScene.instantiate()
	_zone.add_child(_player)
	_player.zone = _zone
	_player.snap_to(_zone.player_start)
	World.player = _player

func after_each():
	World.current_zone = _saved_zone
	World.zone_model = _saved_model
	World.player = _saved_player
	ArenaSystem.reset()
	UnlockSystem.unlocked.erase(ArenaSystem.CHAMPION_UNLOCK)

func _wave_count(i: int) -> int:
	var n := 0
	for s in ArenaSystem.waves[i].get("spawns", []):
		n += int(s.get("count", 0))
	return n

## Levande (ej döda) monster i arenan just nu.
func _live_monsters() -> Array:
	var out: Array = []
	for c in _zone.get_children():
		if c.has_method("take_damage") and not bool(c.get("dead")):
			out.append(c)
	return out

# ── Spawning ──────────────────────────────────────────────────────────────────

func test_start_spawnar_forsta_vagens_monster_i_zonen():
	ArenaSystem.start()
	assert_eq(_live_monsters().size(), _wave_count(0),
		"World ska ha spawnat exakt våg 1:s monster i arenan")

func test_arenamonster_ateruppstar_inte():
	ArenaSystem.start()
	for m in _live_monsters():
		assert_lt(float(m.respawn_time), 0.0,
			"arenamonster ska spawnas utan respawn (annars bryts vågräkningen)")

func test_spawn_pa_lediga_gangbara_rutor():
	ArenaSystem.start()
	var seen := {}
	for m in _live_monsters():
		var t: Vector2i = m.tile
		assert_true(_zone.is_walkable(t), "monster spawnat på ogångbar ruta %s" % str(t))
		assert_false(seen.has(t), "två monster spawnade på samma ruta %s" % str(t))
		seen[t] = true

# ── Full genomspelning via riktiga dödsfall ──────────────────────────────────

func test_hel_omgang_via_riktiga_dodsfall_ger_beloning():
	ArenaSystem.start()
	var safety := 0
	# Fäll allt som reser sig tills arenan vunnits. Varje dödsfall driver
	# record_kill, och sista monstret i en våg spawnar nästa våg synkront.
	while ArenaSystem.is_active() and safety < 400:
		safety += 1
		var mobs := _live_monsters()
		if mobs.is_empty():
			await get_tree().process_frame
			continue
		mobs[0].take_damage(999999.0)
	assert_lt(safety, 400, "omgången avslutades inte inom rimligt antal slag")
	assert_false(ArenaSystem.is_active(), "arenan ska vara vunnen efter sista vågen")
	assert_eq(int(GameState.inventory.get("triumph_blade", 0)), 1,
		"Triumfklingan ska delas ut efter en hel genomspelning")

func test_vagnummer_okar_nar_en_vag_rensas():
	ArenaSystem.start()
	assert_eq(ArenaSystem.current_wave, 0)
	for m in _live_monsters():
		m.take_damage(999999.0)
	# Hela våg 1 fälld → nästa våg ska ha startat och spawnats.
	assert_eq(ArenaSystem.current_wave, 1, "ska ha gått vidare till våg 2")
	assert_eq(_live_monsters().size(), _wave_count(1),
		"våg 2:s monster ska ha spawnats i zonen")
