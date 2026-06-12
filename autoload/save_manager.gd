extends Node
## Autoload: SaveManager. JSON-sparfil + autosave var 60 s.

const SAVE_VERSION := 4
var save_path := "user://save.json"
var _timer := 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 60.0:
		_timer = 0.0
		if World.player != null:
			save_game()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func write_snapshot(snap: Dictionary) -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))

func read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func save_game() -> void:
	write_snapshot({
		"version": SAVE_VERSION,
		"name": GameState.player_name,
		"level": GameState.level, "experience": GameState.experience,
		"xp_to_next": GameState.xp_to_next,
		"health": GameState.health, "max_health": GameState.max_health,
		"mana": GameState.mana, "max_mana": GameState.max_mana,
		"gold": GameState.gold, "inventory": GameState.inventory,
		"skills": GameState.skills, "appearance": GameState.appearance,
		"equipped_weapon": GameState.equipped_weapon,
		"zone": GameState.current_zone,
		"tile": [GameState.player_tile.x, GameState.player_tile.y],
		"tasks_active": TaskSystem.active,
		"tasks_completed": TaskSystem.completed,
		"bestiary": TaskSystem.bestiary,
		"boss_kill_times": TaskSystem.boss_kill_times,
		"unlocked": UnlockSystem.unlocked,
		"quests_active": QuestSystem.active,
		"quests_completed": QuestSystem.completed,
	})

func load_game() -> bool:
	var s := read_snapshot()
	if s.is_empty():
		return false
	GameState.player_name = s.get("name", "Hjälte")
	GameState.level = int(s["level"]); GameState.experience = int(s["experience"])
	GameState.xp_to_next = int(s["xp_to_next"])
	GameState.health = float(s["health"]); GameState.max_health = float(s["max_health"])
	GameState.mana = float(s["mana"]); GameState.max_mana = float(s["max_mana"])
	GameState.gold = int(s["gold"]); GameState.inventory = s["inventory"]
	GameState.skills = s["skills"]; GameState.appearance = s["appearance"]
	GameState.ensure_all_skills()   # v1→v2: fyll på skills som saknas i gamla saves
	GameState.equipped_weapon = s.get("equipped_weapon", "rusty_sword")
	GameState.current_zone = s.get("zone", "town")
	var t: Array = s.get("tile", [-1, -1])
	GameState.player_tile = Vector2i(int(t[0]), int(t[1]))
	# v2→v3: saknade fält ger tomma defaults — tasks/bestiary börjar från noll
	TaskSystem.active = s.get("tasks_active", {})
	TaskSystem.completed = s.get("tasks_completed", {})
	TaskSystem.bestiary = s.get("bestiary", {})
	TaskSystem.boss_kill_times = s.get("boss_kill_times", {})
	UnlockSystem.unlocked = s.get("unlocked", {})
	# v3→v4: quests saknas i äldre saves — börja tomt
	QuestSystem.active = s.get("quests_active", {})
	QuestSystem.completed = s.get("quests_completed", {})
	return true
