extends PanelContainer
## Taskpanel hos Taskmastern: Tillgängliga / Aktiva / Klara tasks.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(440, 0)
	offset_left = 280.0
	offset_top = 100.0
	_list = VBoxContainer.new()
	add_child(_list)
	TaskSystem.task_taken.connect(func(_id): if visible: _rebuild())
	TaskSystem.task_progress.connect(func(_id): if visible: _rebuild())
	TaskSystem.task_completed.connect(func(_id): if visible: _rebuild())
	GameState.skill_changed.connect(func(_s): if visible: _rebuild())

func open() -> void:
	visible = true
	_rebuild()

func _slayer_level() -> int:
	return int(GameState.skills["slayer"]["level"])

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Killing in the Name of...   Slayer %d · %d/%d slots" % [
		_slayer_level(), TaskSystem.active.size(), TaskSystem.slots()]
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)

	var done: Array = []
	var running: Array = []
	var avail: Array = []
	for id in TaskSystem.tasks:
		if TaskSystem.active.has(id):
			(done if TaskSystem.is_task_done(id) else running).append(id)
		elif _slayer_level() >= int(TaskSystem.tasks[id]["slayer_level_req"]):
			avail.append(id)
	avail.sort_custom(func(a, b):
		return int(TaskSystem.tasks[a]["slayer_level_req"]) < int(TaskSystem.tasks[b]["slayer_level_req"]))

	if not done.is_empty():
		_section("Klara")
		for id in done:
			_list.add_child(_done_row(id))
	if not running.is_empty():
		_section("Aktiva")
		for id in running:
			_list.add_child(_active_row(id))
	if not avail.is_empty():
		_section("Tillgängliga")
		for id in avail:
			_list.add_child(_avail_row(id))

func _section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(1.0, 0.85, 0.4)
	_list.add_child(lbl)

func _row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl

func _btn(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	return b

func _avail_row(id: String) -> HBoxContainer:
	var def: Dictionary = TaskSystem.tasks[id]
	var repeat := TaskSystem.completed.has(id)
	var mult: float = 0.5 if repeat else 1.0
	var row := HBoxContainer.new()
	var info := "%s — döda %d  →  %d Slayer-XP, %d guld%s" % [def["monster"], int(def["required"]),
		int(int(def["reward_slayer_xp"]) * mult), int(int(def["reward_gold"]) * mult),
		"  (upprepning)" if repeat else ""]
	row.add_child(_row_label(info))
	var full := TaskSystem.active.size() >= TaskSystem.slots()
	row.add_child(_btn("Ta task", func(): TaskSystem.take_task(id), full))
	return row

func _active_row(id: String) -> HBoxContainer:
	var def: Dictionary = TaskSystem.tasks[id]
	var row := HBoxContainer.new()
	row.add_child(_row_label("%s  %d/%d" % [def["monster"], int(TaskSystem.active[id]), int(def["required"])]))
	row.add_child(_btn("Avbryt", func(): TaskSystem.abandon_task(id)))
	return row

func _done_row(id: String) -> HBoxContainer:
	var def: Dictionary = TaskSystem.tasks[id]
	var row := HBoxContainer.new()
	row.add_child(_row_label("%s  %d/%d ✓" % [def["monster"], int(TaskSystem.active[id]), int(def["required"])]))
	row.add_child(_btn("Hämta belöning", func():
		if TaskSystem.claim_reward(id):
			World.hud.show_message("Belöning hämtad!")))
	return row
