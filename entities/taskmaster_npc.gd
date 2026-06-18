class_name TaskmasterNpc
extends Node2D
## Taskmaster-NPC. Klick intill → taskpanel.

var tile := Vector2i.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea

func setup(t: Vector2i) -> void:
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)

func _ready() -> void:
	_sprite.texture = load("res://assets/sprites/npcs/taskmaster_npc.png")
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 1:
			World.hud.open_tasks()
		else:
			World.hud.show_message("Gå närmare Taskmastern.")
