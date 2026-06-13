extends CanvasLayer
## Dödsöverlägg: visas när spelaren dör, låter spelaren återuppstå i town.

var _panel: PanelContainer
var _btn: Button

func _ready() -> void:
	layer = 10          # ovanpå allt annat
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	GameState.player_died.connect(_show)
	GameState.player_respawned.connect(_hide)

func _build_ui() -> void:
	# Halvtransparent mörk bakgrund
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -160.0
	_panel.offset_top  = -100.0
	_panel.offset_right  = 160.0
	_panel.offset_bottom = 100.0
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Du dog!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Du förlorar halva din XP-progress."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	vbox.add_child(sub)

	_btn = Button.new()
	_btn.text = "Återuppstå i town"
	_btn.add_theme_font_size_override("font_size", 15)
	_btn.pressed.connect(_on_respawn)
	vbox.add_child(_btn)

func _show() -> void:
	visible = true

func _hide() -> void:
	visible = false

func _on_respawn() -> void:
	get_tree().paused = false
	GameState.respawn()
