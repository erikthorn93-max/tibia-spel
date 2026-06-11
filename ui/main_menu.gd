extends Control

func _ready() -> void:
	$VBox/ContinueBtn.disabled = not SaveManager.has_save()
	$VBox/NewBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/character_creator.tscn"))
	$VBox/ContinueBtn.pressed.connect(_continue)

func _continue() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file("res://world/game.tscn")
