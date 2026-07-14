class_name BossMarker3D
extends Node3D
## 3D-motsvarigheten till entities/boss_marker.gd: osynlig markör på bossens
## spawnpunkt under task-cooldown — meddelar spelaren i närheten och spawnar
## bossen (via callbacken från game3d) när cooldownen löpt ut. Utan markören
## dök bossen aldrig upp i 3D förrän zonen laddades om.

const CHECK_INTERVAL := 1.0
const MSG_RANGE := 6
const MSG_COOLDOWN := 10.0

var monster_name := ""
var tile := Vector2i.ZERO
var _spawn_cb := Callable()   # game3d._spawn_monster3d bunden med spawnposten
var _check_timer := 0.0
var _msg_timer := 0.0

func setup(sp: Dictionary, spawn_cb: Callable) -> void:
	monster_name = String(sp["monster"])
	tile = sp["tile"]
	_spawn_cb = spawn_cb
	position = Zone3D.tile_to_world3(tile)

func _process(delta: float) -> void:
	_check_timer -= delta
	_msg_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = CHECK_INTERVAL
		if TaskSystem.boss_available(monster_name):
			if _spawn_cb.is_valid():
				_spawn_cb.call()
			queue_free()
			return
	var dist := maxi(absi(GameState.player_tile.x - tile.x),
		absi(GameState.player_tile.y - tile.y))
	if dist <= MSG_RANGE and _msg_timer <= 0.0:
		_msg_timer = MSG_COOLDOWN
		if World.hud:
			World.hud.show_message("%s är inte här... (%d min)" % [monster_name,
				int(ceil(TaskSystem.boss_cooldown_left(monster_name) / 60.0))])
