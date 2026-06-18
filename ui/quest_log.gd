extends DraggablePanelContainer
## Questlogg (J): aktiva quests med hint + progress, samt klarade.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(440, 0)
	offset_left = 300.0
	offset_top = 80.0
	_list = VBoxContainer.new()
	add_child(_list)
	QuestSystem.quest_started.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_progress.connect(func(_id): if visible: _rebuild())
	QuestSystem.step_advanced.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_completed.connect(func(_id): if visible: _rebuild())

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Questlogg"
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	if QuestSystem.active.is_empty() and QuestSystem.completed.is_empty():
		_row("Inga quests ännu. Prata med folk i staden!")
		return
	if not QuestSystem.active.is_empty():
		_section("Aktiva")
		for id in QuestSystem.active:
			var s := QuestSystem.current_step(id)
			var progress := ""
			if String(s.get("type", "")) in ["kill", "collect"]:
				progress = "  %d/%d" % [int(QuestSystem.active[id]["progress"]), int(s["count"])]
			_row("%s — %s%s" % [QuestSystem.quests[id]["name"], QuestSystem.hint(id), progress])
	if not QuestSystem.completed.is_empty():
		_section("Klarade")
		for id in QuestSystem.completed:
			_row("%s ✓" % QuestSystem.quests[id]["name"])

func _section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1.0, 0.85, 0.4)
	_list.add_child(lbl)

func _row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	_list.add_child(lbl)
