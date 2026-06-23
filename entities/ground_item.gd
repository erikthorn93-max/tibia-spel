class_name GroundItem
extends Node2D
## Lootpåse på marken. Klick inom 1 tile = plocka allt.
## Försvinner efter LIFETIME sekunder; blinkar sista BLINK_START sekunder.

const LIFETIME    := 60.0   # sekunder tills påsen försvinner
const BLINK_START := 10.0   # sekunder kvar när blinkandet börjar

var contents         : Array = []   # [{item: String, qty: int}]
var tile             : Vector2i = Vector2i.ZERO
var lifetime_override := -1.0       # om > 0 ersätter LIFETIME

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

	# Pop in när påsen landar
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var area := Area2D.new()
	var cs   := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(22, 22)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_click)

func _process(delta: float) -> void:
	_elapsed += delta
	var lifetime := lifetime_override if lifetime_override > 0.0 else LIFETIME
	var time_left := lifetime - _elapsed
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
	var parent := get_parent()
	var oy := 0.0
	for d in contents:
		GameState.add_item(String(d["item"]), int(d["qty"]))
		if parent != null:
			var iname := String(ItemDB.items.get(String(d["item"]), {}).get("name", d["item"]))
			var ft: Node2D = preload("res://entities/floating_text.gd").new()
			parent.add_child(ft)
			ft.global_position = global_position + Vector2(0, -10 + oy)
			ft.setup("+%d %s" % [int(d["qty"]), iname], Color(0.96, 0.86, 0.42), 12)
			oy -= 13.0   # stapla flera föremål uppåt
	if parent != null:
		SpellFx.burst(parent, global_position, Color(0.96, 0.86, 0.42), 8, 60.0)
	Sfx.pickup()
	queue_free()
