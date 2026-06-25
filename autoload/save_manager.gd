extends Node
## Autoload: SaveManager. JSON-sparfil + autosave var 60 s.

const SAVE_VERSION := 12
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
	# Dungeonzoner är efemära — spara alltid ytzonen istället
	var save_zone := GameState.current_zone
	var save_tile := GameState.player_tile
	if save_zone.begins_with("dungeon:"):
		save_zone = World.last_surface_zone
		save_tile = World.last_surface_tile
	write_snapshot({
		"version": SAVE_VERSION,
		"name": GameState.player_name,
		"level": GameState.level, "experience": GameState.experience,
		"xp_to_next": GameState.xp_to_next,
		"health": GameState.health, "max_health": GameState.max_health,
		"mana": GameState.mana, "max_mana": GameState.max_mana,
		"gold": GameState.gold, "inventory": GameState.inventory,
		"skills": GameState.skills, "appearance": GameState.appearance,
		"appearance_base": GameState.appearance_base,
		"outfit_equipped": GameState.outfit_equipped,
		"equipment": GameState.equipment,
		"zone": save_zone,
		"tile": [save_tile.x, save_tile.y],
		"tasks_active": TaskSystem.active,
		"tasks_completed": TaskSystem.completed,
		"bestiary": TaskSystem.bestiary,
		"boss_kill_times": TaskSystem.boss_kill_times,
		"unlocked": UnlockSystem.unlocked,
		"quests_active": QuestSystem.active,
		"quests_completed": QuestSystem.completed,
		"learned_spells": GameState.learned_spells,
		"bank": GameState.bank,
		"satiation": GameState.satiation,
		"home_zone": GameState.home_zone,
		"home_tile": [GameState.home_tile.x, GameState.home_tile.y],
		"blessings": GameState.blessings,
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
	# v4→v5: outfit_equipped/appearance_base saknas i gamla saves.
	# Härled basen från appearance så "standard" alltid kan återställas.
	var ab_raw = s.get("appearance_base", {})
	if ab_raw is Dictionary and not ab_raw.is_empty():
		GameState.appearance_base = ab_raw
	else:
		GameState.appearance_base = GameState.appearance.duplicate()
	GameState.outfit_equipped = String(s.get("outfit_equipped", "standard"))
	GameState.ensure_all_skills()   # v1→v2: fyll på skills som saknas i gamla saves
	# v5→v6: equipped_weapon → equipment["weapon"]; saknas equipment-dict → bygg från equipped_weapon
	if s.has("equipment") and s["equipment"] is Dictionary:
		# Bygg från EQUIPMENT_SLOTS så nya slots (halsband/ring/pilar/verktyg)
		# fylls på automatiskt och saknade fält i äldre saves blir tomma.
		var eq: Dictionary = {}
		for slot in GameState.EQUIPMENT_SLOTS:
			eq[slot] = String(s["equipment"].get(slot, ""))
		GameState.equipment = eq
	else:
		# Migrera v5-save: gamla equipped_weapon → weapon-slot
		var eq: Dictionary = {}
		for slot in GameState.EQUIPMENT_SLOTS:
			eq[slot] = ""
		eq["weapon"] = String(s.get("equipped_weapon", "rusty_sword"))
		GameState.equipment = eq
	GameState.current_zone = s.get("zone", "town")
	var t: Array = s.get("tile", [-1, -1])
	GameState.player_tile = Vector2i(int(t[0]), int(t[1]))
	# v2→v3: saknade fält ger tomma defaults — tasks/bestiary börjar från noll
	TaskSystem.active = s.get("tasks_active", {})
	TaskSystem.completed = s.get("tasks_completed", {})
	TaskSystem.bestiary = s.get("bestiary", {})
	TaskSystem.boss_kill_times = s.get("boss_kill_times", {})
	# v9: unlocked sparas som Dictionary {id: true}; gamla saves kan ha Array [id, ...]
	var _ul_raw = s.get("unlocked", {})
	if _ul_raw is Dictionary:
		UnlockSystem.unlocked = _ul_raw
	else:
		UnlockSystem.unlocked = {}
		for _uid in _ul_raw:
			UnlockSystem.unlocked[str(_uid)] = true
	QuestSystem.active = s.get("quests_active", {})
	# quests_completed: gamla saves kan ha Array [id, ...], nya har Dictionary {id: true}
	var _qc_raw = s.get("quests_completed", {})
	if _qc_raw is Dictionary:
		QuestSystem.completed = _qc_raw
	else:
		QuestSystem.completed = {}
		for _qid in _qc_raw:
			QuestSystem.completed[str(_qid)] = true
	# v9: instant-spells. active_rune (v≤8) ignoreras medvetet — run-spåret är borttaget.
	var ls_raw = s.get("learned_spells", [])
	GameState.learned_spells = ls_raw if ls_raw is Array else []
	# v8: bankförvar
	var bank_raw = s.get("bank", {})
	GameState.bank = bank_raw if bank_raw is Dictionary else {}
	# v10: mättnad (satiation) — gamla saves utan fältet börjar omättade
	GameState.satiation = float(s.get("satiation", 0.0))
	# v11: hempunkt — gamla saves utan fältet får town som standard
	GameState.home_zone = String(s.get("home_zone", "town"))
	var ht: Array = s.get("home_tile", [-1, -1])
	GameState.home_tile = Vector2i(int(ht[0]), int(ht[1]))
	# v12: välsignelser — gamla saves utan fältet börjar ovälsignade
	GameState.blessings = int(s.get("blessings", 0))
	return true
