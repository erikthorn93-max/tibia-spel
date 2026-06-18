extends DraggablePanelContainer
## Garderob (U): bär upplåsta outfits; låsta visas gråtonade med krav-hint.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(400, 0)
	offset_left = 320.0
	offset_top = 100.0
	_list = VBoxContainer.new()
	add_child(_list)

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Garderob"
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	for id in GameState.outfit_defs:
		_list.add_child(_outfit_row(String(id)))

func _outfit_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var d: Dictionary = GameState.outfit_defs[id]
	var uid := String(d.get("unlock", ""))
	var available := uid == "" or UnlockSystem.is_unlocked(uid) or UnlockSystem.can_unlock(uid)
	var current := id == GameState.outfit_equipped
	var lbl := Label.new()
	lbl.text = ("» " if current else "") + String(d["name"])
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	if not available:
		lbl.modulate = Color(0.55, 0.55, 0.55)
		lbl.text += "  — " + UnlockSystem.hint_for(uid)
	row.add_child(lbl)
	if available and not current:
		var btn := Button.new()
		btn.text = "Bär"
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func():
			if uid != "":
				UnlockSystem.try_unlock(uid)
			GameState.equip_outfit(id)
			_rebuild())
		row.add_child(btn)
	return row
