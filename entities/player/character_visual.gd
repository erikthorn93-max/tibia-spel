class_name CharacterVisual
extends Node2D
## Tibia-stil spelare-sprite med Sprite2D.

var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = load("res://assets/sprites/player.png") as Texture2D
	if tex:
		_sprite.texture = tex
	# Centrera spriten: origo på spelarens fotpunkt (mitten av tile)
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)

func apply_appearance(_appearance: Dictionary) -> void:
	pass   # reserverat för framtida palette-swap

func face(dir: Vector2i) -> void:
	scale.x = -1.0 if dir.x < 0 else 1.0

## Squish-animation vid attack: sträck ut i attackriktningen, studsa tillbaka.
func play_attack(dir: Vector2i) -> void:
	var sx := 1.3 if dir.x != 0 else 0.75
	var sy := 0.75 if dir.x != 0 else 1.3
	var flip := scale.x   # bevara vänster/höger-riktning
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(flip * sx, sy), 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(flip * 1.0, 1.0), 0.14).set_ease(Tween.EASE_IN_OUT)

## Blink-flash vid skada: röd tona → vit.
func play_hurt() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.4), 0.04)
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
