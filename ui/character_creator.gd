extends Control

@onready var preview: CharacterVisual = $Preview

func _ready() -> void:
	preview.scale = Vector2(4, 4)
	preview.apply_appearance(GameState.appearance)
	for key in ["skin", "hair", "shirt", "pants"]:
		var btn: ColorPickerButton = get_node("VBox/%sRow/Picker" % key.capitalize())
		btn.color = Color(GameState.appearance[key])
		btn.color_changed.connect(func(c: Color):
			GameState.appearance[key] = "#" + c.to_html(false)
			preview.apply_appearance(GameState.appearance))
	$VBox/StartBtn.pressed.connect(_start)

func _start() -> void:
	var n: String = $VBox/NameRow/NameEdit.text.strip_edges()
	GameState.player_name = n if n != "" else "Hjälte"
	GameState.current_zone = "town"
	GameState.player_tile = Vector2i.ZERO
	get_tree().change_scene_to_file(World.game_scene_path())
