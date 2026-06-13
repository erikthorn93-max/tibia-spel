extends PanelContainer
## UI-panel för utrustning (6 slots). Toggle med E-tangenten.
## Varje slot visar utrustat föremål (eller "Tom") med en "Ta av"-knapp.

const SLOT_NAMES := {
	"weapon":  "Vapen",
	"body":    "Harnesk",
	"helmet":  "Hjälm",
	"legs":    "Benskydd",
	"boots":   "Skor",
	"offhand": "Sköld/Sekundär",
}

var _labels: Dictionary = {}   # slot -> Label
var _btns:   Dictionary = {}   # slot -> Button

func _ready() -> void:
	# Placering uppe till höger (bredvid skill-panelen)
	offset_left   = 760.0
	offset_top    = 16.0
	offset_right  = 940.0
	offset_bottom = 220.0
	visible = false

	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "=== Utrustning ==="
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	for slot in ["weapon", "body", "helmet", "legs", "boots", "offhand"]:
		var hbox := HBoxContainer.new()

		var name_lbl := Label.new()
		name_lbl.text = SLOT_NAMES[slot] + ":"
		name_lbl.custom_minimum_size = Vector2(90, 0)
		name_lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(name_lbl)

		var item_lbl := Label.new()
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 11)
		_labels[slot] = item_lbl
		hbox.add_child(item_lbl)

		var btn := Button.new()
		btn.text = "Ta av"
		btn.add_theme_font_size_override("font_size", 10)
		btn.visible = false
		var s: String = slot   # capture för lambda
		btn.pressed.connect(func(): _on_unequip(s))
		_btns[slot] = btn
		hbox.add_child(btn)

		vbox.add_child(hbox)

	# Rustningssummering längst ner
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var armor_lbl := Label.new()
	armor_lbl.name = "ArmorLbl"
	armor_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(armor_lbl)

	add_child(vbox)

	# Lyssna på förändringar
	GameState.equipment_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for slot in _labels:
		var id := String(GameState.equipment.get(slot, ""))
		var lbl: Label = _labels[slot]
		var btn: Button = _btns[slot]
		if id == "":
			lbl.text = "–"
			btn.visible = false
		else:
			var d: Dictionary = ItemDB.items.get(id, {})
			lbl.text = String(d.get("name", id))
			btn.visible = true
	# Uppdatera rustningssummering
	var armor_lbl := find_child("ArmorLbl", true, false) as Label
	if armor_lbl:
		var armor := GameState.total_armor()
		var shield := GameState.total_shielding_bonus()
		armor_lbl.text = "Rustning: %d  Sköld: +%d" % [armor, shield]

func _on_unequip(slot: String) -> void:
	GameState.unequip(slot)

func toggle() -> void:
	visible = not visible
	if visible:
		_ref