class_name GroundItem
extends Node2D
## Lootpåse på marken. Klick inom 1 tile = plocka allt.
## Försvinner efter LIFETIME sekunder; blinkar sista BLINK_START sekunder.

const LIFETIME    := 60.0   # sekunder tills påsen försvinner
const BLINK_START := 10.0   # sekunder kvar när blinkandet börjar

var contents : Array = []   # [{item: String, qty: int}]
var tile     : Vector2i = Vector2i.ZERO

var _elapsed  := 0.0
var _icon     : Polygon2D = null

func setup(drops: Array, t: Vector2i) -> void:
	contents = drops
	tile     = t
	position = Vector2(t) * 32 + Vector2(16, 16)

	_icon = Polygon2D.new()
	_icon.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(0, -9), Vector2(6, 0), Vector2(0, 9)])
	_icon.color = Color("e8c84a")
	add_child(_icon)

	var area := Area2D.new()
	var cs   := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(22, 22)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_click)

func _process(delta: float) -> void:
	_elapsed += delta
	var time_left := LIFETIME - _elapsed
	if time_left <= 0.0:
		queue_free()
		return
	if _icon == null:
		return
	# Blinka snabbt under sista BLINK_START sekunder
	if time_left <= BLINK_START:
		_icon.visible = fmod(_elapsed * 5.0, 1.0) < 0.5
	else:
		_icon.visible = true

func _on_click(_vp: Viewport, event: InputEvent, _shape: int) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pt   := GameState.player_tile
	var dist := maxi(absi(pt.x - tile.x), absi(pt.y - tile.y))
	if dist > 1:
		World.hud.show_message("För långt bort.")
		return
	_collect()

func _collect() -> void:
	for d in contents:
		GameState.add_item(String(d["item"]), int(d["qty"]))
	queue_free()
