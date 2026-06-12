extends Node2D
## Markör på bossens spawnpunkt under cooldown: meddelar spelaren i närheten
## och respawnar bossen när cooldownen löpt ut.

const CHECK_INTERVAL := 1.0
const MSG_RANGE := 6
const MSG_COOLDOWN := 10.0

var monster_name := ""
var tile := Vector2i.ZERO
var respawn_time := 3600.0
var _check_timer := 0.0
var _msg_timer := 0.0

func setup(mname: String, t: Vector2i, respawn: float) -> void:
	monster_name = mname
	tile = t
	respawn_time = respawn
	position = Vector2(t) * 32 + Vector2(16, 16)

func _process(delta: float) -> void:
	_check_timer -= delta
	_msg_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = CHECK_INTERVAL
		if TaskSystem.boss_available(monster_name):
			World.spawn_monster(monster_name, tile, respawn_time)
			queue_free()
			return
	var dist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
	if dist <= MSG_RANGE and _msg_timer <= 0.0:
		_msg_timer = MSG_COOLDOWN
		if World.hud:
			World.hud.show_message("%s är inte här... (%d min)" % [monster_name,
				int(ceil(TaskSystem.boss_cooldown_left(monster_name) / 60.0))])
