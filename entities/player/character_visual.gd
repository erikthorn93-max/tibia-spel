class_name CharacterVisual
extends Node2D
## Paper-doll: kropp/byxor/tröja/hår som tintade lager.

var _layers: Dictionary = {}   # namn -> Polygon2D

func _ready() -> void:
	# (namn, rektangel i lokala px, z)
	for def in [
		["skin",  Rect2(-7, -24, 14, 10)],   # huvud
		["pants", Rect2(-6, -4, 12, 8)],     # ben
		["shirt", Rect2(-8, -15, 16, 12)],   # torso
		["hair",  Rect2(-8, -27, 16, 5)],    # hår ovanpå huvudet
	]:
		var p := Polygon2D.new()
		var r: Rect2 = def[1]
		p.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
		add_child(p)
		_layers[def[0]] = p

func apply_appearance(appearance: Dictionary) -> void:
	for key in _layers:
		if appearance.has(key):
			_layers[key].color = Color(appearance[key])

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
