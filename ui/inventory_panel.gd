class_name InventoryPanel
extends DraggablePanelContainer
## Ryggsäckspanelen (I) — listar inventoryt med ikon, antal och Utrusta/Använd-
## knapp per rad; raderna är drag-källor för hotbar/utrustning. Utbruten ur
## hud.gd så både 2D-HUD:en och 3D-slicens HUD-brygga kan återanvända den —
## pratar bara med autoloads (GameState/ItemDB/ItemTooltip) och ItemIcons.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	offset_left = 16.0
	offset_top = 110.0
	offset_right = 260.0
	offset_bottom = 420.0
	var scroll := ScrollContainer.new()
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	GameState.inventory_changed.connect(refresh)
	refresh()

func toggle() -> void:
	visible = not visible
	if visible:
		move_to_front()

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in GameState.inventory:
		var d: Dictionary = ItemDB.items.get(id, {})
		if d.is_empty():
			continue
		var qty := int(GameState.inventory[id])
		if d.has("slot"):
			var slot := String(d["slot"])
			_list.add_child(_inv_row(id, qty, "Utrusta", func(): GameState.equip(slot, id)))
		elif d.has("heal") or d.has("mana") or d.has("buff") or d.get("usable", false):
			_list.add_child(_inv_row(id, qty, "Använd", func(): GameState.use_item(id)))
		else:
			_list.add_child(_inv_row(id, qty, "", Callable()))

func _make_drag_preview(item_id: String) -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(40, 40)
	var t := TextureRect.new()
	t.texture = ItemIcons.texture(item_id)
	t.custom_minimum_size = Vector2(40, 40)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(t)
	return p

func _inv_row(id: String, qty: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var _row_id := id
	row.mouse_entered.connect(func():
		ItemTooltip.show_for(_row_id, row.get_global_rect().position + Vector2(row.size.x + 4, 0)))
	row.mouse_exited.connect(func(): ItemTooltip.hide_tooltip())
	# Sprite (drag-källa)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(36, 36)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = ItemIcons.texture(id)
	tex.mouse_filter = Control.MOUSE_FILTER_STOP
	var _id := id
	var _qty := qty
	tex.set_drag_forwarding(
		func(_pos: Vector2):
			tex.set_drag_preview(_make_drag_preview(_id))
			return {"item_id": _id, "qty": _qty, "source": "inventory"},
		func(_pos, _data) -> bool: return false,
		func(_pos, _data): pass
	)
	row.add_child(tex)
	# Namn + antal
	var lbl := Label.new()
	var d: Dictionary = ItemDB.items.get(id, {})
	lbl.text = "%s  x%d" % [String(d.get("name", id)), qty]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	if action != "":
		var btn := Button.new()
		btn.text = action
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(cb)
		row.add_child(btn)
	return row
