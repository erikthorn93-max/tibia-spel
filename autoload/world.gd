extends Node
## Autoload: World. Laddar zoner, äger spelarinstansen.

## Meddelanden till spelaren — HUD:en prenumererar (World rör inte UI direkt).
signal world_message(text: String)

## Ryggsäcks-drag till marken (world_drop_zone): bokfört och redo att spawnas.
## 2D-vyn spawnar påsen direkt i drop_item (gated på 2D-zonen); 3D-vyn
## prenumererar här — samma spegel-gating som arenavågorna.
signal item_dropped(drops: Array, tile: Vector2i)

const ZoneScript = preload("res://world/zone.gd")
const PlayerScene = preload("res://entities/player/player.tscn")
const DungeonGen = preload("res://world/dungeon_generator.gd")
# monster.tscn och treasure_chest.gd laddas lazy — existerar inte förrän Task 4/9.
const MONSTER_SCENE_PATH := "res://entities/monster/monster.tscn"
const CHEST_SCRIPT_PATH := "res://entities/treasure_chest.gd"

## 3D-läge valt i huvudmenyn. Styr vilken spelscen menyn/character creator
## startar OCH flaggar att 3D-sessionen får spara — F6-devkörningar och
## testsviten (use_3d = false) rör aldrig spelarens sparfil.
var use_3d := false

var current_zone: Node2D    # vy-container: zon-tiles + entitetsnoder
var zone_model: ZoneModel   # logisk zonmodell — all zondata läses härifrån
var player: Node2D
var game_root: Node2D    # sätts av game.tscn vid _ready
var hud: CanvasLayer     # sätts av hud.gd vid _ready
var aim: Node2D          # AimController, sätts av game_root vid _ready
var last_surface_zone := ""
var last_surface_tile := Vector2i(-1, -1)
# Grav-tillståndet (zon/tile/loot) bor i GameState så det persisteras och
# överlever zon-ombyggnad. Minimap läser GameState.grave_zone/grave_tile.

## Spelscenen för vald renderare — huvudmenyn och character creator routar hit.
func game_scene_path() -> String:
	return "res://world/game3d.tscn" if use_3d else "res://world/game.tscn"

func _ready() -> void:
	GameState.player_died.connect(_on_player_died)
	GameState.player_respawned.connect(_on_player_respawned)
	ArenaSystem.wave_started.connect(_on_arena_wave_started)
	ArenaSystem.arena_won.connect(_on_arena_won)
	ArenaSystem.arena_failed.connect(_on_arena_failed)

## Bygger om hemzonen och flyttar spelaren dit efter återuppståndelse.
func _on_player_respawned() -> void:
	if game_root == null:
		return
	start_game(GameState.current_zone, GameState.player_tile)

func start_game(zone_id: String, at_tile := Vector2i(-1, -1)) -> void:
	# Lämnar man arenan mitt i en omgång räknas det som uppgivet.
	if ArenaSystem.is_active() and zone_id != ArenaSystem.ARENA_ZONE:
		ArenaSystem.abort()
	if current_zone:
		# Rädda spelaren ur den gamla zonen innan vi river den
		if player and is_instance_valid(player) and player.get_parent() == current_zone:
			current_zone.remove_child(player)
		# Ta bort gamla zonen ur scen-trädet omedelbart (undviker await-hängning)
		if current_zone.get_parent():
			current_zone.get_parent().remove_child(current_zone)
		current_zone.queue_free()
	current_zone = Node2D.new()
	current_zone.set_script(ZoneScript)
	game_root.add_child(current_zone)
	current_zone.build(zone_id)
	zone_model = current_zone.model
	GameState.current_zone = zone_id
	QuestSystem.record_explore(zone_id)
	last_surface_zone = zone_id

	if player == null or not is_instance_valid(player):
		player = PlayerScene.instantiate()
	if player.get_parent():
		player.get_parent().remove_child(player)
	current_zone.add_child(player)
	player.zone = current_zone
	var start: Vector2i = at_tile if at_tile.x >= 0 else zone_model.player_start
	player.snap_to(start)

	_spawn_monsters()
	_spawn_world_objects()
	_spawn_grave_if_here()

func enter_dungeon(theme: String, dseed: int = -1) -> void:
	last_surface_zone = GameState.current_zone
	last_surface_tile = player.tile if player and is_instance_valid(player) else Vector2i(-1, -1)
	if dseed < 0:
		dseed = randi()
	var data := DungeonGen.generate(theme, dseed)
	SaveManager.save_game()   # spara med ytzon INNAN vi byter
	var rebuild := func():
		if current_zone:
			if player and is_instance_valid(player) and player.get_parent() == current_zone:
				current_zone.remove_child(player)
			if current_zone.get_parent():
				current_zone.get_parent().remove_child(current_zone)
			current_zone.queue_free()
		current_zone = Node2D.new()
		current_zone.set_script(ZoneScript)
		game_root.add_child(current_zone)
		current_zone.build_from_data(data, "dungeon:" + theme)
		zone_model = current_zone.model
		GameState.current_zone = "dungeon:" + theme
		QuestSystem.record_explore("dungeon:" + theme)
		if player == null or not is_instance_valid(player):
			player = PlayerScene.instantiate()
		if player.get_parent():
			player.get_parent().remove_child(player)
		current_zone.add_child(player)
		player.zone = current_zone
		player.snap_to(zone_model.player_start)
		_spawn_monsters()
		_spawn_world_objects()
	if hud != null and is_instance_valid(hud) and hud.has_method("transition"):
		hud.transition(rebuild)
	else:
		rebuild.call_deferred()

func change_zone(zone_id: String) -> void:
	SaveManager.save_game()
	# Dungeoneixt: återvänd till ingångstiln i ytzonen
	var dest_tile := Vector2i(-1, -1)
	if GameState.current_zone.begins_with("dungeon:") and zone_id == last_surface_zone and last_surface_tile.x >= 0:
		dest_tile = last_surface_tile
	var rebuild := func(): start_game(zone_id, dest_tile)
	if hud != null and is_instance_valid(hud) and hud.has_method("transition"):
		hud.transition(rebuild)
	else:
		rebuild.call_deferred()

func _spawn_monsters() -> void:
	for sp in zone_model.spawn_points:
		_spawn_one(sp)

func spawn_monster(monster_name: String, t: Vector2i, respawn := -1.0) -> Node2D:
	if not ResourceLoader.exists(MONSTER_SCENE_PATH):
		return null    # monster.tscn finns först efter Task 9
	var m: Node2D = load(MONSTER_SCENE_PATH).instantiate()
	current_zone.add_child(m)
	m.setup(monster_name, t, current_zone, respawn)
	# Elite-chans: 5 % dag, 15 % natt. Stats + presentation ägs av monstret.
	var elite_chance := 0.15 if TimeOfDay.is_night else 0.05
	if randf() < elite_chance:
		m.make_elite()
	return m

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
	for np in zone_model.node_points:
		var n: Node2D = preload("res://entities/gather_node.tscn").instantiate()
		current_zone.add_child(n)
		n.setup(np["node"], np["tile"])
	for sp in zone_model.station_points:
		var s: Node2D = preload("res://entities/crafting_station.tscn").instantiate()
		current_zone.add_child(s)
		s.setup(sp["station"], sp["tile"])
	for t in zone_model.shop_points:
		var npc: Node2D = preload("res://entities/shop_npc.tscn").instantiate()
		current_zone.add_child(npc)
		npc.setup(t)
	for t in zone_model.bank_points:
		var bnpc: Node2D = preload("res://entities/bank_npc.tscn").instantiate()
		current_zone.add_child(bnpc)
		bnpc.setup(t)
	for t in zone_model.taskmaster_points:
		var tm: Node2D = preload("res://entities/taskmaster_npc.tscn").instantiate()
		current_zone.add_child(tm)
		tm.setup(t)
	for t in zone_model.spell_teacher_points:
		var st: Node2D = preload("res://entities/spell_teacher_npc.tscn").instantiate()
		current_zone.add_child(st)
		st.setup(t)
	if ResourceLoader.exists(CHEST_SCRIPT_PATH):
		var ChestScript = load(CHEST_SCRIPT_PATH)
		for t in zone_model.chest_points:
			var chest := Node2D.new()
			chest.set_script(ChestScript)
			current_zone.add_child(chest)
			chest.setup(t, zone_model.dungeon_theme)
	for id in DialogueDB.npcs:
		var nd: Dictionary = DialogueDB.npcs[id]
		if String(nd["zone"]) == zone_model.zone_id:
			var npc: Node2D = preload("res://entities/npc.tscn").instantiate()
			npc.setup(id, Vector2i(int(nd["position"][0]), int(nd["position"][1])))
			current_zone.add_child(npc)   # setup FÖRE add_child — _ready läser npc_id

## Tappar ett item på marken vid spelarens nuvarande tile. Bokföringen är
## renderer-agnostisk; bara 2D-påsen spawnas här (3D-vyn tar item_dropped).
func drop_item(item_id: String, qty: int = 1) -> void:
	var drops: Array = [{"item": item_id, "qty": qty}]
	if current_zone != null:
		var gi = preload("res://entities/ground_item.gd").new()
		current_zone.add_child(gi)
		gi.setup(drops, GameState.player_tile)
	GameState.remove_item(item_id, qty)
	item_dropped.emit(drops, GameState.player_tile)

## Tappar döds-loot + placerar gravsten när spelaren dör.
## Andelen styrs av death_drop_fraction() (ryggsäck + välsignelser minskar den).
## Graven persisteras i GameState så looten överlever respawn/zon-ombyggnad.
func _on_player_died() -> void:
	# Faller man i arenan är omgången förlorad.
	ArenaSystem.abort()
	if current_zone == null:
		return
	drop_death_loot()
	_spawn_grave_if_here()

## Rullar döds-droppen och bokför graven i GameState. Renderer-agnostisk
## (ingen vy-referens) — 3D-vyn anropar den själv vid spelardöd eftersom
## _on_player_died är gated på 2D-zonen.
func drop_death_loot() -> void:
	var drop_frac := GameState.death_drop_fraction()
	if drop_frac <= 0.0:
		GameState.clear_grave()   # full välsignelse: inget tappas
		return
	var drops: Array = []
	for item_id in GameState.inventory.keys():
		var qty: int = int(GameState.inventory[item_id])
		var drop_qty: int = max(1, int(qty * drop_frac))
		drops.append({"item": item_id, "qty": drop_qty})
		GameState.remove_item(item_id, drop_qty)
	if drops.is_empty():
		GameState.clear_grave()
		return
	GameState.set_grave(GameState.current_zone, GameState.player_tile, drops)

## Återskapar gravens lootpåse om spelaren är i grav-zonen. Persistent påse:
## försvinner inte med tiden och rensar graven när den plockas upp.
func _spawn_grave_if_here() -> void:
	if current_zone == null or not GameState.has_grave():
		return
	if GameState.grave_zone != zone_model.zone_id:
		return
	var gi = preload("res://entities/ground_item.gd").new()
	current_zone.add_child(gi)
	gi.setup(GameState.grave_drops, GameState.grave_tile)
	gi.persistent = true
	gi.is_grave = true

# ── Arena ─────────────────────────────────────────────────────────────────────
## Spawnar nästa arenavåg på lediga rutor en bit från spelaren.
func _on_arena_wave_started(index: int, spawns: Array) -> void:
	if current_zone == null or player == null or not is_instance_valid(player):
		return
	var tiles := _arena_spawn_tiles()
	var ti := 0
	for s in spawns:
		for _i in range(int(s.get("count", 0))):
			if ti >= tiles.size():
				break
			spawn_monster(String(s["monster"]), tiles[ti], -1.0)
			ti += 1
	var label := String(ArenaSystem.waves[index].get("name", ""))
	world_message.emit("Våg %d/%d%s" % [index + 1, ArenaSystem.wave_count(),
		(" — " + label) if label != "" else ""])

## Lediga, gångbara rutor minst 2 steg från spelaren, blandade.
func _arena_spawn_tiles() -> Array:
	var ptile: Vector2i = player.tile
	var out: Array = []
	for y in range(zone_model.grid_size.y):
		for x in range(zone_model.grid_size.x):
			var t := Vector2i(x, y)
			if not zone_model.is_walkable(t) or zone_model.is_occupied(t):
				continue
			if maxi(absi(t.x - ptile.x), absi(t.y - ptile.y)) < 2:
				continue
			out.append(t)
	out.shuffle()
	return out

func _on_arena_won() -> void:
	world_message.emit("Du har besegrat arenan! Publiken ropar ditt namn.")

func _on_arena_failed(_at_wave: int) -> void:
	world_message.emit("Du lämnade sanden. Arenan glömmer dig.")
