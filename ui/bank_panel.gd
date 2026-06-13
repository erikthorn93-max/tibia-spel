extends PanelContainer
## Bankpanel: sätt in föremål från inventory → bank, ta ut från bank → inventory.
## Tvåkolumns-layout: Inventering (vänster) | Bankförvar (höger).
## Klick på föremål = flytta hela stacken. Shift+klick = flytta 1 st.

const BANK_SLOTS := 200   # max unika föremålstyper i banken

var _inv_list:  VBoxContainer
var _bank_list: VBoxContainer
var _title_lbl: Label

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(600, 420)
	# Centrera i viewporten
	set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# — Titel + stängknapp —
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ Stäng"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): visible = false)
	top_row.add_child(close_btn)

	# — Kolumnrubriker —
	var col_hdrs := HBoxContainer.new()
	vbox.add_child(col_hdrs)

	var inv_hdr := Label.new()
	inv_hdr.text = "Inventering"
	inv_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_hdr.add_theme_font_size_override("font_size", 12)
	col_hdrs.add_child(inv_hdr)

	var bank_hdr := Label.new()
	bank_hdr.text = "Bankförvar"
	bank_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_hdr.add_theme_font_size_override("font_size", 12)
	col_hdrs.add_child(bank_hdr)

	# — Tvåkolumns scroll-area —
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	var inv_scroll := ScrollContainer.new()
	inv_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.custom_minimum_size = Vector2(280, 340)
	cols.add_child(inv_scroll)

	_inv_list = VBoxContainer.new()
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(_inv_list)

	var sep := VSeparator.new()
	cols.add_child(sep)

	var bank_scroll := ScrollContainer.new()
	bank_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_scroll.custom_minimum_size = Vector2(280, 340)
	cols.add_child(bank_scroll)

	_bank_list = VBoxContainer.new()
	_bank_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_scroll.add_child(_bank_list)

	# — Tip längst ner —
	var tip := Label.new()
	tip.text = "Klick = flytta hel stack  |  Shift+klick = flytta 1 st"
	tip.add_theme_font_size_override("font_size", 9)
	tip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(tip)

	# Lyssna på förändringar
	GameState.inventory_changed.connect(func(): if visible: _rebuild())

func open() -> void:
	visible = true
	_rebuild()

func _rebuild() -> void:
	_clear(_inv_list)
	_clear(_bank_list)

	var used_slots := GameState.bank.size()
	_title_lbl.text = "Bank  —  %d / %d slots använda" % [used_slots, BANK_SLOTS]

	# Inventering → vänster kolumn
	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(tom inventering)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		_inv_list.add_child(empty_lbl)
	else:
		for item_id in GameState.inventory:
			var qty := int(GameState.inventory[item_id])
			_inv_list.add_child(_make_row(item_id, qty, true))

	# Bankförvar → höger kolumn
	if GameState.bank.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(banken är tom)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		_bank_list.add_child(empty_lbl)
	else:
		for item_id in GameState.bank:
			var qty := int(GameState.bank[item_id])
			_bank_list.add_child(_make_row(item_id, qty, false))

func _make_row(item_id: String, qty: int, in_inventory: bool) -> HBoxContainer:
	var row := HBoxContainer.new()

	var d: Dictionary = ItemDB.items.get(item_id, {})
	var name_txt: String = String(d.get("name", item_id))

	var lbl := Label.new()
	lbl.text = "%s  x%d" % [name_txt, qty]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "→ Bank" if in_inventory else "→ Inv"
	btn.add_theme_font_size_override("font_size", 9)
	btn.pressed.connect(func(): _move(item_id, qty, in_inventory, false))
	row.add_child(btn)

	var btn1 := Button.new()
	btn1.text = "×1"
	btn1.add_theme_font_size_override("font_size", 9)
	btn1.pressed.connect(func(): _move(item_id, 1, in_inventory, false))
	row.add_child(btn1)

	return row

## Flytta qty st av item_id:
##   in_inventory=true  → inv → bank
##   in_inventory=false → bank → inv
func _move(item_id: String, qty: int, from_inventory: bool, _shift: bool) -> void:
	var actual := mini(qty, _available(item_id, from_inventory))
	if actual <= 0:
		return
	if from_inventory:
		# Kontrollera bankkapacitet (ny slot krävs om item saknas i banken)
		if not GameState.bank.has(item_id) and GameState.bank.size() >= BANK_SLOTS:
			World.hud.show_message("Banken är full (%d slots)." % BANK_SLOTS)
			return
		GameState.remove_item(item_id, actual)
		_bank_deposit(item_id, actual)
	else:
		_bank_withdraw(item_id, actual)
		GameState.add_item(item_id, actual)
	_rebuild()

func _available(item_id: String, from_inventory: bool) -> int:
	if from_inventory:
		return int(GameState.inventory.get(item_id, 0))
	return int(GameState.bank.get(item_id, 0))

func _bank_deposit(item_id: String, qty: int) -> void:
	GameState.bank[item_id] = int(GameState.bank.get(item_id, 0)) + qty

func _bank_withdraw(item_id: String, qty: int) -> void:
	var current := int(GameState.bank.get(item_id, 0))
	var new_qty := current - qty
	if new_qty <= 0:
		GameState.bank.erase(item_id)
	else:
		GameState.bank[item_id] = new_qty

func _clear(container: VBoxContainer) -> void:
	for c in container.get_children():
		c.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = false
