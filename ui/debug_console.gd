extends CanvasLayer
## Debug-konsol (§, tangenten under Esc). Alltid registrerad — singleplayer offline.
## Pausar spelet när den är öppen så att ingen input läcker till spelvärlden.

var _panel: PanelContainer
var _log: RichTextLabel
var _line: LineEdit

func _ready() -> void:
	layer = 10
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.offset_left = 16.0
	_panel.offset_top = 16.0
	_panel.custom_minimum_size = Vector2(620, 260)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 210)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 11)
	box.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "kommando (enter på tom rad för hjälp)"
	_line.text_submitted.connect(_on_submit)
	box.add_child(_line)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		visible = not visible
		get_tree().paused = visible
		if visible:
			_line.clear()
			_line.grab_focus()
		get_viewport().set_input_as_handled()

func _say(s: String) -> void:
	_log.append_text(s + "\n")

func _on_submit(text: String) -> void:
	_line.clear()
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty():
		_help()
		return
	_say("> " + text)
	match parts[0]:
		"give":
			if parts.size() < 2 or not ItemDB.items.has(parts[1]):
				_say("Okänt item. Exempel: give health_potion 5")
				return
			var qty := int(parts[2]) if parts.size() > 2 else 1
			GameState.add_item(parts[1], qty)
			_say("Gav %d x %s" % [qty, parts[1]])
		"gold":
			if parts.size() < 2:
				_say("gold <antal>")
				return
			GameState.add_item("iron_coin", int(parts[1]))
			_say("Guld: %d" % GameState.gold)
		"xp":
			if parts.size() < 3 or not GameState.skills.has(parts[1]):
				_say("xp <skill> <mängd> — skills: %s" % ", ".join(GameState.skills.keys()))
				return
			GameState.gain_skill_xp(parts[1], int(parts[2]))
			_say("%s är nu nivå %d" % [parts[1], int(GameState.skills[parts[1]]["level"])])
		"kills":
			if parts.size() < 3 or not MonsterDB.monsters.has(parts[1]):
				_say("kills <monster> <antal> — monster: %s" % ", ".join(MonsterDB.monsters.keys()))
				return
			TaskSystem.bestiary[parts[1]] = int(parts[2])
			TaskSystem.bestiary_changed.emit()
			_say("%s: %d kills (tier %d)" % [parts[1], int(parts[2]), TaskSystem.tier(parts[1])])
		"unlock":
			if parts.size() < 2:
				_say("unlock <id>")
				return
			UnlockSystem.unlock(parts[1])
			_say("Upplåst: %s" % parts[1])
		"tasklist":
			for id in TaskSystem.tasks:
				var status := "tillgänglig"
				if TaskSystem.active.has(id):
					status = "aktiv %d/%d" % [int(TaskSystem.active[id]), int(TaskSystem.tasks[id]["required"])]
				elif TaskSystem.completed.has(id):
					status = "klarad"
				_say("%s (%s) — %s" % [id, TaskSystem.tasks[id]["monster"], status])
		"tp":
			if parts.size() < 2 or not FileAccess.file_exists("res://data/zones/%s.json" % parts[1]):
				_say("tp <zon> — zoner: town, cave, forest, swamp")
				return
			visible = false
			get_tree().paused = false
			World.change_zone(parts[1])
			_say("Teleporterade till %s" % parts[1])
		"heal":
			GameState.heal(GameState.max_health)
			GameState.mana = GameState.max_mana
			GameState.mana_changed.emit(GameState.mana, GameState.max_mana)
			_say("Full HP/mana.")
		"spawn":
			if parts.size() < 2 or not MonsterDB.monsters.has(parts[1]):
				_say("spawn <monster> — monster: %s" % ", ".join(MonsterDB.monsters.keys()))
				return
			var origin: Vector2i = GameState.player_tile
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if World.current_zone.is_walkable(origin + d):
					World.spawn_monster(parts[1], origin + d)
					_say("Spawnade %s" % parts[1])
					return
			_say("Ingen ledig tile intill spelaren.")
		"dungeon":
			var themes_f := FileAccess.open("res://data/dungeon_themes.json", FileAccess.READ)
			var themes: Dictionary = JSON.parse_string(themes_f.get_as_text()) if themes_f else {}
			if parts.size() < 2 or not themes.has(parts[1]):
				_say("dungeon <tema