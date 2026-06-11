extends Node2D
## Spelets rotscen. Registrerar sig hos World och startar.

func _ready() -> void:
	World.game_root = self
	if ResourceLoader.exists("res://ui/hud.tscn"):    # HUD skapas i Task 11
		var hud := (load("res://ui/hud.tscn") as PackedScene).instantiate()
		add_child(hud)
	World.start_game(GameState.current_zone)
