extends PanelContainer
## Tibia-stil hotkey-bar — 30 konfigurerbara rutor i 3 rader om 10.
## Draggbar via handtaget. Högerklick → konfigurera. Vänsterklick/tangent → använd.

const SLOT_COUNT := 30
const CFG_FILE   := "user://hotkeys.json"

const DEFAULT_KEYS: Array = [
	# Rad 1: F1–F10
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5,
	KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10,
	# Rad 2: F11, F12, 1–8
	KEY_F11, KEY_F12,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8,
	# Rad 3: 9, 0, Q, W, E, R, T, Y, U, I
	KEY_9, KEY_0,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I,
]
const DEFAULT_NAMES: Array = [
	"F1","F2","F3","F4","F5","F6","F7","F8","F9","F10",
	"F11","F12","1","2","3","4","5","6","7","8",
	"9","0","Q","W","E","R","T","Y","U","I",
]

var _slots: Array = []
var _slot_panels: Array = []
var _slot_icons:  Array = []
var _slot_name_lbls: Array = []
var _slot_key_lbls:  Array = []

var _dragging    := false
var _drag_offset := Vector2.ZERO

var _popup:       Control   = null
var _cfg_idx      := -1
var _wait_key     := false
var _cfg_key_btn:  Button   = null
var _cfg_item_lst: ItemList = null
var _pending_kname := ""
var _pending_kcode := 0

# ─────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_init_slots()
	_load_config()
	_build_bar()
	_build_popup()
	_refresh_all()

func _init_slots() -> void:
	_slots.clear()
	for i in SLOT_COUNT:
		_slots.append({"key_name": DEFAULT_NAMES[i], "keycode": int(DEFAULT_KEYS[i]), "item_id": ""})

func _load_config() -> void:
	if not FileAccess.file_exists(CFG_FILE):
		return
	var f := FileAccess.open(CFG_FILE, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for i in mini(parsed.size(), SLOT_COUNT):
			if parsed[i] is Dictionary:
				_slots[i] = parsed[i]

func _save_config() -> void:
	var f := FileAccess.open(CFG_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_slots))

# ─────────────────────────────────────────────
func _build_bar() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.93)
	sb.border_color = Color(0.45, 0.45, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 3.0
	sb.content_margin_right  = 3.0
	sb.content_margin_top    = 2.0
	sb.content_margin_bottom = 3.0
	add_theme_stylebox_override("panel", sb)

	# Förankrad längst ner — bredd för 10 rutor × 58px + marginaler
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left   =  80.0
	offset_right  = -80.0
	offset_top    = -196.0
	offset_bottom =  -4.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	# Drag-handle
	var handle := Label.new()
	handle.text = "≡ Hotkeys  (högerklicka ruta för att konfigurera)"
	handle.add_theme_font_size_override("font_size", 9)
	handle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.gui_input.connect(_on_handle_gui_input)
	vbox.add_child(handle)

	# Grid: 3 rader × 10 kolumner
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)

	for i in SLOT_COUNT:
		grid.add_child(_make_slot(i))

func _make_slot(idx: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(56, 56)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.14)
	sb.border_color = Color(0.40, 0.40, 0.50)
	sb.set_border_width_all(1)
	sb.content_margin_left   = 2.0
	sb.content_margin_right  = 2.0
	sb.content_margin_top    = 2.0
	sb.content_margin_bottom = 2.0
	cell.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(vbox)

	# Ikon
	var icon := ColorRect.new()
	icon.color = Color(0.18, 0.18, 0.22)
	icon.custom_minimum_size = Vector2(0, 24)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(icon)
	_slot_icons.append(icon)

	# Item-namn
	var nlbl := Label.new()
	nlbl.add_theme_font_size_override("font_size", 8)
	nlbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.70))
	nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nlbl.clip_text = true
	nlbl.custom_minimum_size = Vector2(52, 0)
	vbox.add_child(nlbl)
	_slot_name_lbls.append(nlbl)

	# Tangent
	var klbl := Label.new()
	klbl.add_theme_font_size_override("font_size", 10)
	klbl.add_theme_color_override("font_color", Color(0.55, 0.80, 1.00))
	klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(klbl)
	_slot_key_lbls.append(klbl)

	_slot_panels.append(cell)
	cell.gui_input.connect(func(ev): _on_slot_gui_input(ev, idx))
	return cell

# ─────────────────────────────────────────────
func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.z_index = 100

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.97)
	sb.border_color = Color(0.50, 0.50, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left   = 8.0
	sb.content_margin_right  = 8.0
	sb.content_margin_top    = 8.0
	sb.content_margin_bottom = 8.0
	_popup.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 320)
	vbox.add_theme_constant_override("separation", 6)
	_popup.add_child(vbox)

	var title := Label.new()
	title.text = "Konfigurera slot"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var item_lbl := Label.new()
	item_lbl.text = "Välj föremål (från inventory):"
	item_lbl.add_theme_font_size_override("font_size", 10)
	item_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	vbox.add_child(item_lbl)

	_cfg_item_lst = ItemList.new()
	_cfg_item_lst.custom_minimum_size = Vector2(0, 150)
	_cfg_item_lst.select_mode = ItemList.SELECT_SINGLE
	_cfg_item_lst.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_cfg_item_lst)

	var key_row := HBoxContainer.new()
	vbox.add_child(key_row)
	var key_lbl := Label.new()
	key_lbl.text = "Tangent:"
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(key_lbl)
	_cfg_key_btn = Button.new()
	_cfg_key_btn.custom_minimum_size = Vector2(80, 0)
	_cfg_key_btn.add_theme_font_size_override("font_size", 11)
	_cfg_key_btn.pressed.connect(_on_key_btn_pressed)
	key_row.add_child(_cfg_key_btn)

	var hint := Label.new()
	hint.text = "(klicka Tangent-knappen, tryck sedan en tangent)"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var clear_btn := Button.new()
	clear_btn.text = "Töm slot"
	clear_btn.add_theme_font_size_override("font_size", 11)
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_row.add_child(clear_btn)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.add_theme_font_size_override("font_size", 11)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(_on_ok_pressed)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Avbryt"
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): _popup.visible = false)
	btn_row.add_child(cancel_btn)

	get_parent().add_child(_popup)

# ─────────────────────────────────────────────
func _open_config(idx: int) -> void:
	_cfg_idx = idx
	_wait_key = false
	_pending_kname = String(_slots[idx].get("key_name", ""))
	_pending_kcode = int(_slots[idx].get("keycode", 0))

	_cfg_item_lst.clear()
	_cfg_item_lst.add_item("— Ingen —")
	var current_id: String = String(_slots[idx].get("item_id", ""))
	var sel_index := 0
	var row := 1
	for id in GameState.inventory:
		var d: Dictionary = ItemDB.items.get(id, {})
		if d.is_empty():
			continue
		var qty := int(GameState.inventory[id])
		_cfg_item_lst.add_item("%s  x%d" % [String(d.get("name", id)), qty])
		_cfg_item_lst.set_item_metadata(row, id)
		if id == current_id:
			sel_index = row
		row += 1
	_cfg_item_lst.select(sel_index)
	_cfg_key_btn.text = _pending_kname if _pending_kname != "" else "—"
	_popup.visible = true
	var vp := get_viewport_rect().size
	_popup.position = (vp - _popup.size) * 0.5

func _on_key_btn_pressed() -> void:
	_wait_key = true
	_cfg_key_btn.text = "Tryck tangent..."

func _on_ok_pressed() -> void:
	if _cfg_idx < 0:
		return
	var sel := _cfg_item_lst.get_selected_items()
	var item_id := ""
	if sel.size() > 0 and sel[0] > 0:
		item_id = String(_cfg_item_lst.get_item_metadata(sel[0]))
	_slots[_cfg_idx]["item_id"]  = item_id
	_slots[_cfg_idx]["key_name"] = _pending_kname
	_slots[_cfg_idx]["keycode"]  = _pending_kcode
	_popup.visible = false
	_refresh_slot(_cfg_idx)
	_save_config()

func _on_clear_pressed() -> void:
	if _cfg_idx >= 0:
		_slots[_cfg_idx]["item_id"] = ""
	_popup.visible = false
	_refresh_slot(_cfg_idx)
	_save_config()

# ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _wait_key and _popup != null and _popup.visible:
		var kname := OS.get_keycode_string(event.keycode)
		if kname.is_empty():
			kname = "K%d" % event.keycode
		_pending_kname = kname
		_pending_kcode = int(event.keycode)
		_cfg_key_btn.text = kname
		_wait_key = false
		get_viewport().set_input_as_handled()
		return
	for i in SLOT_COUNT:
		if int(_slots[i].get("keycode", 0)) == int(event.keycode):
			_use_slot(i)
			get_viewport().set_input_as_handled()
			return

func _use_slot(idx: int) -> void:
	var item_id: String = String(_slots[idx].get("item_id", ""))
	if item_id.is_empty():
		return
	if not GameState.use_item(item_id):
		World.hud.show_message("Kan inte använda: %s" % item_id)

# ─────────────────────────────────────────────
func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_use_slot(idx)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_open_config(idx)

# ─────────────────────────────────────────────
func _refresh_all() -> void:
	for i in SLOT_COUNT:
		_refresh_slot(i)

func _refresh_slot(idx: int) -> void:
	if idx >= _slot_icons.size():
		return
	var slot: Dictionary = _slots[idx]
	var item_id: String = String(slot.get("item_id", ""))
	var d: Dictionary = ItemDB.items.get(item_id, {}) if item_id != "" else {}
	if d.is_empty():
		_slot_icons[idx].color    = Color(0.18, 0.18, 0.22)
		_slot_name_lbls[idx].text = ""
	else:
		var col_str: String = String(d.get("color", "#888888"))
		_slot_icons[idx].color = Color.html(col_str) if col_str.begins_with("#") else Color(0.4, 0.4, 0.5)
		var qty := int(GameState.inventory.get(item_id, 0))
		_slot_name_lbls[idx].text = "%s\nx%d" % [String(d.get("name", item_id)), qty]
	_slot_key_lbls[idx].text = String(slot.get("key_name", ""))
