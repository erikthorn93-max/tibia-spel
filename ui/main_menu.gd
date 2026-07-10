extends Control

func _ready() -> void:
	$VBox/ContinueBtn.disabled = not SaveManager.has_save()
	# 3D-läget: routar Nytt spel/Fortsätt till 3D-scenen och låter sessionen
	# spara (World.use_3d). F6-körningar av game3d.tscn förblir save-fria.
	var chk := CheckButton.new()
	chk.text = "3D-läge"
	chk.button_pressed = World.use_3d
	chk.toggled.connect(func(on: bool): World.use_3d = on)
	$VBox.add_child(chk)
	$VBox/NewBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/character_creator.tscn"))
	$VBox/ContinueBtn.pressed.connect(_continue)

func _continue() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(World.game_scene_path())
