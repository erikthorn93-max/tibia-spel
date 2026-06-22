extends DraggablePanelContainer
## Spellbook: två flikar.
##  • "Kända"  — dina inlärda besvärjelser; dra en rad till hotbaren för att binda.
##  • "Lär"    — köp nya besvärjelser av magikern (kräver magic-nivå + guld).
## Öppnas med P (Kända) eller via SpellTeacher-NPC:n (Lär).

var _tab := "known"          # "known" | "learn"
var _root: VBoxContainer
var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(400, 0)
	offset_left = 320.0
	offset_top = 100.0
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 4)
	add_child(_root)
	SpellSystem.spell_learned.connect(func(_id): if visible: _rebuild())
	GameState.gold_changed.connect(func(_g): if visible and _tab == "learn": _rebuild())

func open(learn_mode := false) -> void:
	_tab = "learn" if learn_mode else "known"
	visible = true
	move_to_front()
	_rebuild()

func toggle() -> void:
	visible = not visible
	if visible:
		_tab = "known"
		move_to_front()
		_rebuild()

# ── Bygge ────────────────────────────────────────────────────────────────────
func _rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "Magibok — guld: %d · magic %d" % [GameState.gold, GameState.effective_skill_level("magic")]
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	_root.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_root.add_child(tabs)
	tabs.add_child(_tab_button("Kända", "known"))
	tabs.add_child(_tab_button("Lär", "learn"))
	_root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	if _tab == "known":
		_build_known()
	else:
		_build_learn()

func _tab_button(text: String, tab: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = (_tab == tab)
	b.pressed.connect(func(): _tab = tab; _rebuild())
	return b

func _build_known() -> void:
	if GameState.learned_spells.is_empty():
		var hint := Label.new()
		hint.text = "Du kan inga besvärjelser än.\nBesök magikern i Thais för att lära dig."
		hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_list.add_child(hint)
		return
	var info := Label.new()
	info.text = "Dra en besvärjelse till en hotbar-ruta för att binda den."
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_list.add_child(info)
	for id in _sorted_ids(GameState.learned_spells):
		_list.add_child(_known_row(id))

func _build_learn() -> void:
	for id in _sorted_ids(SpellSystem.spells.keys()):
		_list.add_child(_learn_row(id))

## Sorterar spell-id:n på magic-nivå, sedan namn.
func _sorted_ids(ids: Array) -> Array:
	var arr := ids.duplicate()
	arr.sort_custom(func(a, b):
		var la := int(SpellSystem.spells.get(a, {}).get("magic_lvl", 1))
		var lb := int(SpellSystem.spells.get(b, {}).get("magic_lvl", 1))
		if la == lb:
			return String(SpellSystem.spells.get(a, {}).get("name", a)) < String(SpellSystem.spells.get(b, {}).get("name", b))
		return la < lb)
	return arr

func _spell_summary(def: Dictionary) -> String:
	return "“%s” · mana %d · magic %d" % [
		String(def.get("words", "")), int(def.get("mana_cost", 0)), int(def.get("magic_lvl", 1))]

# ── Rader ────────────────────────────────────────────────────────────────────
func _known_row(id: String) -> Control:
	var def: Dictionary = SpellSystem.spells.get(id, {})
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.18, 0.6)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6; sb.content_margin_right = 6
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	row.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = "%s   %s" % [String(def.get("name", id)), _spell_summary(def)]
	row.add_child(lbl)

	var _id := id
	row.set_drag_forwarding(
		func(_pos: Vector2):
			row.set_drag_preview(_drag_preview(String(def.get("name", _id))))
			return {"spell_id": _id},
		func(_pos, _data) -> bool: return false,
		func(_pos, _data): pass
	)
	return row

func _learn_row(id: String) -> Control:
	var def: Dictionary = SpellSystem.spells.get(id, {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var known := SpellSystem.knows_spell(id)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "%s   %s · %d guld" % [String(def.get("name", id)), _spell_summary(def), int(def.get("price", 0))]
	if known:
		lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	row.add_child(lbl)

	if known:
		var kn := Label.new()
		kn.text = "✓ Kan"
		kn.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		row.add_child(kn)
	else:
		var btn := Button.new()
		btn.text = "Lär"
		var _id := id
		btn.pressed.connect(func():
			var res: Dictionary = SpellSystem.learn_spell(_id)
			if World.hud:
				World.hud.show_message(String(res.get("reason", "")) if not res["ok"] else "Du lärde dig %s!" % String(def.get("name", _id)))
			_rebuild())
		row.add_child(btn)
	return row

func _drag_preview(label_text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.22, 0.9)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	p.add_child(l)
	return p
