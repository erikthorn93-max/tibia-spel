extends Node
## Autoload: World. Laddar zoner, äger spelarinstansen.

const ZoneScript = preload("res://world/zone.gd")
const PlayerScene = preload("res://entities/player/player.tscn")
# monster.tscn laddas lazy i spawn_monster — skapas i Task 9.
const MONSTER_SCENE_PATH := "res://entities/monster/monster.tscn"

var current_zone: Node2D
var player: Node2D
var game_root: Node2D    # sätts av game.tscn vid _ready

func start_game(zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	if current_zone:
		current_zone.queue_free()
		await current_zone.tree_exited
	current_zone = Node2D.new()
	current_zone.set_script(ZoneScript)
	game_root.add_child(current_zone)
	current_zone.build(zone_id)
	GameState.current_zone = zone_id

	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate()
	if player.get_parent():
		player.get_parent().remove_child(player)
	current_zone.add_child(player)
	player.zone = current_zone
	var start: Vector2i = at_tile if at_tile.x >= 0 else current_zone.player_start
	player.snap_to(start)

	_spawn_monsters()

func change_zone(zone_id: String) -> void:
	SaveManager.save_game()
	start_game.call_deferred(zone_id)

func _spawn_monsters() -> void:
	for sp in current_zone.spawn_points:
		_spawn_one(sp)

func spawn_monster(monster_name: String, t: Vector2i, respawn := -1.0) -> Node2D:
	if not ResourceLoader.exists(MONSTER_SCENE_PATH):
		return null    # monster.tscn finns först efter Task 9
	var m: Node2D = load(MONSTER_SCENE_PATH).instantiate()
	current_zone.add_child(m)
	m.setup(monster_name, t, current_zone, respawn)
	return m

func _spawn_one(sp: Dictionary) -> void:
	spawn_monster(sp["monster"], sp["tile"], sp["respawn"])
