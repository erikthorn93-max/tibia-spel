extends PanelContainer
## UI-panel för utrustning (6 slots) med sprites. Toggle med E-tangenten.

const SLOT_NAMES := {
	"weapon":  "Vapen",
	"body":    "Harnesk",
	"helmet":  "Hjälm",
	"legs":    "Benskydd",
	"boots":   "Skor",
	"offhand": "Sköld",
}

var _icons:  Dictionary = {}   # slot -> TextureRect
var _labels: Dictionary = {}   # slot -> Label
var _btns:   Dictionary = {}   # slot -> Button

func _ready() -> void:
	offset_left   = 760.0
	offset_top    = 16.0
	offset_right  = 960.0
	offset_bottom = 260.0
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

	for slot in ["weapon", "helmet", "body", "offhand", "legs", "boots"]:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		# Slot-namn
		var slot_lbl := Label.new()
		slot_lbl.text = SLOT_NAMES[slot]
		slot_lbl.custom_minimum_size = Vector2(72, 0)
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.55))
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(slot_lbl)

		# Sprite
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icons[slot] = icon
		hbox.add_child(icon)

		# Itemnamn
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
		var s: String = slot
		btn.pressed.connect(func(): GameState.unequip(s))
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

func _refresh() -> void:
	for slot in _labels:
		var id := String(GameState.equipment.get(slot, ""))
		var lbl: Label = _labels[slot]
		var btn: Button = _btns[slot]
		var icon: TextureRect = _icons[slot]
		if id == "":
			lbl.text = "–"
			icon.texture = null
			btn.visible = false
		else:
			var d: Dictionary = ItemDB.items.get(id, {})
			lbl.text = String(d.get("name", id))
			icon.texture = _load_sprite(id)
			btn.visible = true
	var armor_lbl := find_child("ArmorLbl", true, false) as Label
	if armor_lbl:
		var armor  := GameState.total_armor()
		var shield := GameState.total_shielding_bonus()
		armor_lbl.text = "Rustning: %d   Sköld: +%d" % [armor, shield]

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()
