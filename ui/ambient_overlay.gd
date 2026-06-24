extends Control
## Ambient-partiklar som ger varje biom liv: svävande eldflugor om natten ute,
## drivande damm i grottor, stigande glödflagor vid vulkanen. Pollar aktiv zon
## + tid och tystnar när väder pågår (regn/dimma/snö äger då stämningen).
## All logik ligger i ui/biome.gd & ui/weather.gd (testbart) — noden renderar.

const Biome = preload("res://ui/biome.gd")
const Weather = preload("res://ui/weather.gd")

var kind := "none"
var _particles: Array[Vector2] = []
var _phases: PackedFloat32Array = []
var _t := 0.0
var _built_kind := ""
var _built_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var want := _resolve_kind()
	var sz := size
	if want != _built_kind or sz != _built_size:
		kind = want
		_rebuild(sz)
	if kind == "none":
		if not _particles.is_empty():
			queue_redraw()
		return
	_t += delta
	var vel := Biome.ambient_velocity(kind)
	for i in _particles.size():
		var p := _particles[i] + vel * delta
		# Mjuk sidledesvandring så rörelsen inte är spikrak.
		p.x += sin(_t * 0.9 + _phases[i]) * 7.0 * delta
		_particles[i] = Weather.wrap(p, sz.x, sz.y)
	queue_redraw()

## Vilken ambient-typ som ska visas just nu: biomets typ, men bara om inget
## väder pågår (annars äger vädret stämningen).
func _resolve_kind() -> String:
	var zone := World.current_zone
	if zone == null or not is_instance_valid(zone) or not ("zone_id" in zone):
		return "none"
	var wx := Weather.CLEAR
	if "weather" in zone:
		wx = Weather.resolve(zone.weather, WeatherSystem.current)
	if wx != Weather.CLEAR:
		return "none"
	return Biome.ambient_kind(Biome.classify(zone.zone_id), TimeOfDay.is_night)

func _rebuild(sz: Vector2) -> void:
	_built_kind = kind
	_built_size = sz
	_particles.clear()
	_phases.clear()
	if kind == "none" or sz.x <= 0 or sz.y <= 0:
		if sz.x <= 0 or sz.y <= 0:
			_built_size = Vector2.ZERO   # bygg om när storleken blivit giltig
		return
	var n := Biome.ambient_count(kind, sz.x * sz.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in n:
		_particles.append(Vector2(rng.randf() * sz.x, rng.randf() * sz.y))
		_phases.append(rng.randf() * TAU)

func _draw() -> void:
	if kind == "none":
		return
	var base := Biome.ambient_color(kind)
	var twinkle := Biome.ambient_twinkles(kind)
	var r := 1.8 if kind != "dust" else 1.2
	for i in _particles.size():
		var a := 0.7
		if twinkle:
			# Pulserande opacitet → blinkande eldflugor / pulserande glöd.
			a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 2.4 + _phases[i] * 3.0))
		var c := Color(base.r, base.g, base.b, a)
		draw_circle(_particles[i], r, c)
		if twinkle and a > 0.6:
			# Litet halo runt de starkast lysande för mjukt sken.
			draw_circle(_particles[i], r + 1.6, Color(base.r, base.g, base.b, a * 0.18))
