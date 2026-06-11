extends Node2D
## Spelets rotscen. Registrerar sig hos World och startar.

func _ready() -> void:
	World.game_root = self
	var hud := preload("res://ui/hud.tscn").instantiate()
	add_child(hud)
	World.start_game(GameState.current_zone,
		GameState.player_tile if SaveManager.has_save() and GameState.player_tile != Vector2i.ZERO else Vector2i(-1, -1))
