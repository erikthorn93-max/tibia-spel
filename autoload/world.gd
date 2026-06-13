extends Node
## Autoload: World. Laddar zoner, äger spelarinstansen.

const ZoneScript = preload("res://world/zone.gd")
const PlayerScene = preload("res://entities/player/player.tscn")
const DungeonGen = preload("res://world/dungeon_generator.gd")
# monster.tscn och treasure_chest.gd laddas lazy — existerar inte förrän Task 4/9.
const MONSTER_SCENE_PATH := "res://entities/monster/monster.tscn"
const CHEST_SCRIPT_PATH := "res://entities/treasure_chest.gd"

var current_zone: Node2D
var player: Node2D
var game_root: Node2D    # sätts av game.tscn vid _ready
var hud: CanvasLayer     # sätts av hud.gd vid _ready
var last_surface_zone := ""
var last_surface_tile := Vector2i(-1, -1)

func start_game(zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	if current_zone:
		current_zone.queue_free()
		await current_zone.tree_exited
	current_zone = Node2D.new()
	current_zone.set_script(ZoneScript)
	game_root.add_child(current_zone)
	current_zone.build(zone_id)
	GameState.current_zone = zone_id
	QuestSystem.record_explore(zone_id)
	last_surface_zone = zone_id

	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate()
	if player.get_parent():
		player.get_parent().remove_child(player)
	current_zone.add_child(player)
	player.zone = current_zone
	var start: Vector2i = at_tile if at_tile.x >= 0 else current_zone.player_start
	player.snap_to(start)

	_spawn_monsters()
	_spawn_world_objects()

func enter_dungeon(theme: String, dseed: int = -1) -> void:
	last_surface_zone = GameState.current_zone
	last_surface_tile = player.tile if player and is_instance_valid(player) else Vector2i(-1, -1)
	if dseed < 0:
		dseed = randi()
	var data := DungeonGen.generate(theme, dseed)
	SaveManager.save_game()   # spara med ytzon INNAN vi byter
	if current_zone:
		current_zone.queue_free()
		await current_zone.tree_exited
	current_zone = Node2D.new()
	current_zone.set_script(ZoneScript)
	game_root.add_child(current_zone)
	current_zone.build_from_data(data, "dungeon:" + theme)
	GameState.current_zone = "dungeon:" + theme
	QuestSystem.record_explore("dungeon:" + theme)
	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate()
	if player.get_parent():
		player.get_parent().remove_child(player)
	current_zone.add_child(player)
	player.zone = current_zone
	player.snap_to(current_zone.player_start)
	_spawn_monsters()
	_spawn_world_objects()

func change_zone(zone_id: String) -> void:
	SaveManager.save_game()
	# Dungeoneixt: återvänd till ingångstiln i ytzonen
	if GameState.current_zone.begins_with("dungeon:") and zone_id == last_surface_zone and last_surface_tile.x >= 0:
		start_game.call_deferred(zone_id, last_surface_tile)
	else:
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
	var mname := String(sp["monster"])
	if bool(MonsterDB.monsters.get(