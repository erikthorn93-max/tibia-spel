class_name SpellFx
extends Node2D
## Återanvändbara besvärjelse-effekter. SpellSystem är ren logik och returnerar
## bara metadata; casters (spelaren) anropar dessa statiska fabriker som spawnar
## självstädande effekt-noder i världen.

const PROJ_SPEED := 460.0   # px/s för projektiler

var _mode := ""
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _color := Color.WHITE
var _on_arrive: Callable = Callable()
var _gfx: Node2D = null
var _max_r := 26.0

## Elementfärg för partiklar/glow.
static func element_color(element: String) -> Color:
	match element:
		"fire":     return Color(1.00, 0.45, 0.12)
		"ice":      return Color(0.55, 0.85, 1.00)
		"energy":   return Color(0.78, 0.55, 1.00)
		"death":    return Color(0.58, 0.22, 0.66)
		"holy":     return Color(1.00, 0.95, 0.60)
		"physical": return Color(0.85, 0.85, 0.85)
		_:          return Color(0.80, 0.80, 1.00)

## Partikelskur vid en världsposition (nedslag / cast-flash).
static func burst(parent: Node, world_pos: Vector2, color: Color, amount := 12, vmax := 95.0) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.position = world_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = vmax * 0.4
	p.initial_velocity_max = vmax
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	parent.add_child(p)
	p.get_tree().create_timer(0.9).timeout.connect(p.queue_free)

## Gnistor som stiger uppåt vid en position (fontän). Återanvänds av heal & nivå-upp.
static func fountain(parent: Node, world_pos: Vector2, color: Color, amount := 14) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.position = world_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	parent.add_child(p)
	p.get_tree().create_timer(1.1).timeout.connect(p.queue_free)

## Helande gnistor som stiger uppåt vid målet.
static func heal_sparkle(parent: Node, world_pos: Vector2) -> void:
	fountain(parent, world_pos, Color(0.45, 1.0, 0.5))

## Expanderande, tonande ring (cast/buff-markör).
static func ring(parent: Node, world_pos: Vector2, color: Color, max_r := 26.0) -> void:
	if parent == null:
		return
	var fx := SpellFx.new()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx._start_ring(color, max_r)

## Projektil som flyger från→till och kör on_arrive vid framkomst.
static func projectile(parent: Node, from: Vector2, to: Vector2, color: Color,
		on_arrive: Callable = Callable()) -> void:
	if parent == null:
		return
	var fx := SpellFx.new()
	parent.add_child(fx)
	fx._start_projectile(from, to, color, on_arrive)

# --- instans-implementation ---

func _start_ring(color: Color, max_r: float) -> void:
	_mode = "ring"
	_color = color
	_max_r = max_r
	_t = 0.0
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = color
	line.closed = true
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)))   # enhetscirkel, skalas via _process
	line.points = pts
	_gfx = line
	add_child(line)

func _start_projectile(from: Vector2, to: Vector2, color: Color, on_arrive: Callable) -> void:
	_mode = "projectile"
	_from = from
	_to = to
	_color = color
	_on_arrive = on_arrive
	_t = 0.0
	global_position = from
	var dot := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 4.5)
	dot.polygon = pts
	dot.color = color
	_gfx = dot
	add_child(dot)
	# mjuk glow-ytterring
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		gpts.append(Vector2(cos(a), sin(a)) * 8.0)
	glow.polygon = gpts
	glow.color = Color(color.r, color.g, color.b, 0.35)
	add_child(glow)
	move_child(glow, 0)

func _process(delta: float) -> void:
	match _mode:
		"ring":
			_t += delta
			var k := clampf(_t / 0.35, 0.0, 1.0)
			if _gfx != null:
				_gfx.scale = Vector2.ONE * (_max_r * k)
			modulate.a = 1.0 - k
			if k >= 1.0:
				queue_free()
		"projectile":
			var dist := _from.distance_to(_to)
			var dur := maxf(dist / PROJ_SPEED, 0.05)
			_t += delta
			var k := clampf(_t / dur, 0.0, 1.0)
			global_position = _from.lerp(_to, k)
			if k >= 1.0:
				if _on_arrive.is_valid():
					_on_arrive.call()
				queue_free()
