extends DraggablePanelContainer
## Karaktärspanel (C) — Tibia-stil paper-doll med alla utrustningsplatser.
## Dra item från inventory → slot för att utrusta. Högerklick på slot = ta av.
## Verktygs- och pilsloten är aktiv-markörer (föremålet ligger kvar i ryggsäcken).

const SLOT_NAMES := {
	"amulet":   "Halsband",
	"helmet":   "Hjälm",
	"backpack": "Ryggsäck",
	"weapon":   "Vapen",
	"body":     "Harnesk",
	"offhand":  "Sköld",
	"tool":     "Verktyg",
	"legs":     "Benskydd",
	"ammo":     "Pilar",
	"ring":     "Ring",
	"boots":    "Skor",
	"ring2":    "Ring 2",
	"light":    "Ljuskälla",
}
# Paper-doll-layout, 3 kolumner × 5 rader ("" = tom utfyllnadsruta).
const GRID_LAYOUT := [
	"amulet", "helmet", "backpack",
	"weapon", "body",   "offhand",
	"tool",   "legs",   "ammo",
	"ring",   "boots",  "ring2",
	"",       "light",  "",
]
const CELL := 46.0

const BG_COLOR   := Color(0.10, 0.08, 0.06, 0.97)
const BORDER     := Color(0.45, 0.35, 0.20)
const SLOT_BG    := Color(0.16, 0.12, 0.08)
const SLOT_EMPTY := Color(0.55, 0.48, 0.35)

var _icons:  Dictionary = {}   # slot -> TextureRect
var _empties: Dictionary = {}  # slot -> Label (slotnamn när tom)
var _armor_lbl: Label
var _atk_lbl: Label

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _ready() -> void:
	offset_left = 740.0
	offset_top  = 16.0
	visible = false
	custom_minimum_size = Vector2(190, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	var title := Label.new()
	title.text = "Karaktär"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for slot in GRID_LAYOUT:
		if slot == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(CELL, CELL)
			grid.add_child(spacer)
		else:
			grid.add_child(_make_slot(String(slot)))

	vbox.add_child(HSeparator.new())
	_armor_lbl = Label.new()
	_armor_lbl.add_theme_font_size_override("font_size", 11)
	_armor_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
	vbox.add_child(_armor_lbl)
	_atk_lbl = Label.new()
	_atk_lbl.add_theme_font_size_override("font_size", 11)
	_atk_lbl.add_theme_color_override("font_color", Color(0.90, 0.78, 0.60))
	vbox.add_child(_atk_lbl)

	GameState.equipment_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_refresh()

func _make_slot(slot: String) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.tooltip_text = SLOT_NAMES.get(slot, slot)

	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	cell.add_theme_stylebox_override("panel", sb)

	# Tom-silhuett (visar vad som hör hemma i sloten) syns när inget är utrustat
	var empty_icon := TextureRect.new()
	empty_icon.texture = EquipIcons.silhouette(slot)
	empty_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empties[slot] = empty_icon

	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons[slot] = icon

	var wrap := Control.new()        # håller ikon + tom-silhuett ovanpå varandra
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(empty_icon)
	wrap.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(wrap)

	var _slot := slot
	# Hover → tooltip för utrustat item
	cell.mouse_entered.connect(func():
		var eid := String(GameState.equipment.get(_slot, ""))
		if eid != "":
			ItemTooltip.show_for(eid, cell.get_global_rect().position + Vector2(-210, 0)))
	cell.mouse_exited.connect(func(): ItemTooltip.hide_tooltip())
	# Högerklick → ta av
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			if String(GameState.equipment.get(_slot, "")) != "":
				GameState.unequip(_slot)
				ItemTooltip.hide_tooltip())
	# Drag UT utrustat item + ta emot DROP
	cell.set_drag_forwarding(
		func(_pos: Vector2):
			var id := String(GameState.equipment.get(_slot, ""))
			if id.is_empty(): return null
			cell.set_drag_preview(_make_preview(id))
			return {"item_id": id, "qty": 1, "source": "equipment", "source_slot": _slot},
		func(_pos, data) -> bool:
			if not (data is Dictionary and data.has("item_id")): return false
			var item_slot := String(ItemDB.items.get(String(data["item_id"]), {}).get("slot", ""))
			return GameState.slot_accepts(_slot, item_slot),
		func(_pos, data):
			var iid := String(data.get("item_id", ""))
			if iid != "":
				GameState.equip(_slot, iid)
	)
	return cell

func _load_sprite(item_id: String) -> Texture2D:
	var path := "res://assets/sprites/items/%s.png" % item_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_preview(item_id: String) -> Control:
	var t := TextureRect.new()
	t.texture = _load_sprite(item_id)
	t.custom_minimum_size = Vector2(40, 40)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

func _refresh() -> void:
	for slot in _icons:
		var id := String(GameState.equipment.get(slot, ""))
		_icons[slot].texture = _load_sprite(id) if id != "" else null
		# Visa slotnamnet bara när tomt
		_empties[slot].visible = (id == "")
	if _armor_lbl:
		_armor_lbl.text = "Rustning: %d" % GameState.total_armor()
	if _atk_lbl:
		var w: Dictionary = ItemDB.items.get(String(GameState.equipment.get("weapon", "")), {})
		_atk_lbl.text = "Vapenskada: %d (%s)" % [int(w.get("atk", 0)), String(w.get("skill", "fist"))]
