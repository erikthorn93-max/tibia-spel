class_name ShopNpc
extends Node2D
## Butiks-NPC. Klick intill → köp/sälj-panel.

var tile := Vector2i.ZERO

@onready var click_area: Area2D = $ClickArea

func setup(t: Vector2i) -> void:
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 1:
			World.hud.open_shop()
		else:
			World.hud.show_message("Gå närmare handlaren.")
