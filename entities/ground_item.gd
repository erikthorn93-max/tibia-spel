class_name GroundItem
extends Node2D
## Lootpåse på marken. Klick = plocka allt.

var contents: Array = []

func setup(drops: Array, t: Vector2i) -> void:
	contents = drops
	position = Vector2(t) * 32 + Vector2(16, 16)
	var icon := Polygon2D.new()
	icon.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -8), Vector2(6, 0), Vector2(0, 8)])
	icon.color = Color("e8c84a")
	add_child(icon)
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(20, 20)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - int(position.x / 32)), absi(GameState.player_tile.y - int(position.y / 32)))
		if pdist <= 1:
			for d in contents:
				GameState.add_item(d["item"], d["qty"])
			queue_free()
