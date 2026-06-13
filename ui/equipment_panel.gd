extends PanelContainer
## Utrustningspanel med drag-drop. Dra item från inventory → slot för att utrusta.
## Dra utrustat item → världen för att ta av och tappa.

const SLOT_NAMES := {
	"weapon":  "Vapen",
	"body":    "Harnesk",
	"helmet":  "Hjälm",
	"legs":    "Benskydd",
	"boots":   "Skor",
	"offhand": "Sköld",
}
const SLOT_ORDER := ["weapon", "helmet", "body", "offhand", "legs", "boots"]

var _icons:  Dictionary = {}
var _labels: Dictionary = {}
var _btns:   Dictionary = {}

func _ready() -> void:
	offset_left   = 760.0
	offset_top    = 16.0
	offset_right  = 960.0
	offset_bottom = 280.0
	visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.97)
	sb.border_color = Color(0.45, 0.35, 0.20)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left   = 8.0
	sb.content_margin_right  = 8.0
	sb.content_margin_top    = 8.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Utrustning"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for slot in SLOT_ORDER:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		hbox.mouse_filter = Control.MOUSE_FILTER_STOP

		# Slot-etikett
		var slot_lbl := Label.new()
		slot_lbl.text = SLOT_NAMES[slot]
		slot_lbl.custom_minimum_size = Vector2(68, 0)
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.55))
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(slot_lbl)

		# Ikon-slot (drag ut härifrån, ta emot drop hit)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		_icons[slot] = icon

		var _slot: String = slot   # fånga
		# Drag UT utrustat item
		icon.set_drag_forwarding(
			func(_pos: Vector2):
				var id := String(GameState.equipment.get(_slot, ""))
				if id.is_empty(): return null
				var preview := _make_preview(id)
				icon.set_drag_preview(preview)
				return {"item_id": id, "qty": 1, "source": "equipment", "source_slot": _slot},
			func(_pos, _data) -> bool: return false,
			func(_pos, _data): pass
		)
		# Ta emot item DROP på sloten
		hbox.set_drag_forwarding(
			func(_pos): return null,
			func(_pos, data) -> bool:
				if not (data is Dictionary and data.has("item_id")): return false
				var iid: String = String(data["item_id"])
				var d: Dictionary = ItemDB.items.get(iid, {})
				return String(d.get("slot", "")) == _slot,
			func(_pos, data):
				var iid := String(data.get("item_id", ""))
				if iid.is_empty(): return
				# Ta av gammalt item om sloten är upptagen
				var old_id := String(GameState.equipment.get(_slot, ""))
				if old_id != "" and old_id != iid:
					GameState.unequip(_slot)
				GameState.equip(_slot, iid)
		)
		hbox.add_child(icon)

		# Namn
		var item_lbl := Label.new()
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
		item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_lbl.clip_text = true
		_labels[slot] = item_lbl
		hbox.add_child(item_lbl)

		# Ta av-knapp
		var btn := Button.new()
		btn.text = "✕"
		btn.custom_minimum_size = Vector2(26, 26)
		btn.add_theme_font_size_override("font_size", 10)
		btn.visible = false
		btn.pressed.connect(func(): GameState.unequip(_slot))
		_btns[slot] = btn
		hbox.add_child(btn)

		vbox.add_child(hbox)

	vbox.add_child(HSeparator.new())
	var armor_lbl := Label.new()
	armor_lbl.name = "ArmorLbl"
	armor_lbl.add_theme_font_size_override("font_size", 10)
	armor_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
	vbox.add_child(armor_lbl)
	add_child(vbox)

	GameState.equipment_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_refresh()

func _load_sprite(item_id: String) -> Texture2D:
	var path := "res://assets/sprites/items/%s.png" % item_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_preview(item_id: String) -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(40, 40)
	var t := TextureRect.new()
	t.texture = _load_sprite(item_id)
	t.custom_minimum_size = Vector2(40, 40)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(t)
	return p

func _refresh() -> void:
	for slot in _labels:
		var id := String(GameState.equipment.get(slot, ""))
		_labels[slot].text = ItemDB.items.get(id, {}).get("name", "–") if id != "" else "–"
		_icons[slot].texture  = _load_sprite(id) if id != "" else null
		_btns[slot].visible   = id != ""
	var armor_lbl := find_child("ArmorLbl", true, false) as Label
	if armor_lbl:
		armor_lbl.text = "Rustning: %d   Sköld: +%d" % [GameState.total_armor(), GameState.total_shielding_bonus()]

func toggle() -> void:
	visible = not visible
	if visible: _refresh()
