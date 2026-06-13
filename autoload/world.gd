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
## Gravsten — sätts när spelaren dör, visas på minimap tills hen plockar upp loot
var grave_tile  := Vector2i(-1, -1)
var grave_zone  : Node2D = null   # vilken zon graven finns i

func _ready() -> void:
	GameState.player_died.connect(_on_player_died)

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
	# 5 % chans att bli ett elite-monster (starkare, mer exp, orange namn)
	if randf() < 0.05:
		_make_elite(m)
	return m

## Förvandlar ett monster till en elite-variant.
func _make_elite(m: Node2D) -> void:
	m.hp     = m.hp * 2
	m.max_hp = m.max_hp * 2
	m.atk    = int(float(m.atk) * 1.5)
	m.exp    = m.exp * 3
	# Orange namnlabel (tillgänglig efter add_child → _ready)
	if m.has_node("NameLabel"):
		var lbl: Label = m.get_node("NameLabel")
		lbl.text = "★ " + lbl.text
		lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	m._refresh_label()

func _spawn_one(sp: Dictionary) -> void:
	var mname := String(sp["monster"])
	if bool(MonsterDB.monsters.get(mname, {}).get("boss", false)) and not TaskSystem.boss_available(mname):
		spawn_boss_marker(mname, sp["tile"], float(sp["respawn"]))
		return
	spawn_monster(mname, sp["tile"], sp["respawn"])

func spawn_boss_marker(mname: String, t: Vector2i, respawn: float) -> void:
	var bm: Node2D = preload("res://entities/boss_marker.gd").new()
	current_zone.add_child(bm)
	bm.setup(mname, t, respawn)

func _spawn_world_objects() -> void:
	for np in current_zone.node_points:
		var n: Node2D = preload("res://entities/gather_node.tscn").instantiate()
		current_zone.add_child(n)
		n.setup(np["node"], np["tile"])
	for sp in current_zone.station_points:
		var s: Node2D = preload("res://entities/crafting_station.tscn").instantiate()
		current_zone.add_child(s)
		s.setup(sp["station"], sp["tile"])
	for t in current_zone.shop_points:
		var npc: Node2D = preload("res://entities/shop_npc.tscn").instantiate()
		current_zone.add_child(npc)
		npc.setup(t)
	for t in current_zone.taskmaster_points:
		var tm: Node2D = preload("res://entities/taskmaster_npc.tscn").instantiate()
		current_zone.add_child(tm)
		tm.setup(t)
	if ResourceLoader.exists(CHEST_SCRIPT_PATH):
		var ChestScript = load(CHEST_SCRIPT_PATH)
		for t in current_zone.chest_points:
			var chest := Node2D.new()
			chest.set_script(ChestScript)
			current_zone.add_child(chest)
			chest.setup(t, current_zone.dungeon_theme)
	for id in DialogueDB.npcs:
		var nd: Dictionary = DialogueDB.npcs[id]
		if String(nd["zone"]) == current_zone.zone_id:
			var npc: Node2D = preload("res://entities/npc.tscn").instantiate()
			npc.setup(id, Vector2i(int(nd["position"][0]), int(nd["position"][1])))
			current_zone.add_child(npc)   # setup FÖRE add_child — _ready läser npc_id

## Tappar döds-loot + placerar gravsten när spelaren dör.
## Kastar 30 % av v