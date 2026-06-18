extends DraggablePanelContainer
## Bönpanel: begrav ben vid altaret för Prayer XP.
## XP per ben: 25 (ben) — Prayer höjer max-mana och ger passiv bonus i framtiden.

const XP_PER_BONE := 25

var _info_lbl: Label
var _btn_bury1: Button
var _btn_bury_all: Button

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(300, 180)
	set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "Bönaltare — Prayer"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	_info_lbl = Label.new()
	_info_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_info_lbl)

	var tip := Label.new()
	tip.text = "Varje ben ger %d Prayer XP." % XP_PER_BONE
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(tip)

	var btns := HBoxContainer.new()
	vbox.add_child(btns)

	_btn_bury1 = Button.new()
	_btn_bury1.text = "Begrav 1"
	_btn_bury1.pressed.connect(func(): _bury(1))
	btns.add_child(_btn_bury1)

	_btn_bury_all = Button.new()
	_btn_bury_all.text = "Begrav alla"
	_btn_bury_all.pressed.connect(func(): _bury_all())
	btns.add_child(_btn_bury_all)

	var close := Button.new()
	close.text = "Stäng"
	close.pressed.connect(func(): visible = false)
	btns.add_child(close)

	GameState.inventory_changed.connect(func(): if visible: _rebuild())

func open() -> void:
	visible = true
	_rebuild()

func _rebuild() -> void:
	var count := int(GameState.inventory.get("bones", 0))
	_info_lbl.text = "Du har %d ben i din inventering." % count
	_btn_bury1.disabled = count < 1
	_btn_bury_all.disabled = count < 1

func _bury(n: int) -> void:
	var have := int(GameState.inventory.get("bones", 0))
	var actual := mini(n, have)
	if actual <= 0:
		return
	GameState.remove_item("bones", actual)
	GameState.gain_skill_xp("prayer", actual * XP_PER_BONE)
	World.hud.show_message("Du begravde %d ben. +%d Prayer XP!" % [actual, actual * XP_PER_BONE])
	_rebuild()

func _bury_all() -> void:
	var count := int(GameState.inventory.get("bones", 0))
	_bury(count)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = false
