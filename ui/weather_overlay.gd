extends Control
## Heltäckande väder-overlay: ritar regnstrimmor, snöflingor eller drivande
## dimma plus en svag färgtvätt. Pollar World.current_zone.weather varje frame
## och bygger om partiklar när vädret eller skärmstorleken ändras. Ren rendering
## — all logik ligger i ui/weather.gd (testbar).

const Weather = preload("res://ui/weather.gd")

var weather := Weather.CLEAR
var _particles: Array[Vector2] = []     # regn/snö-positioner
var _phases: PackedFloat32Array = []    # per partikel: fas för snöns sicksack
var _fog_blobs: Array = []              # dimma: {base:Vector2, r:float, ph:float}
var _t := 0.0
var _built_weather := ""
var _built_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	# Synka mot aktuell zon (täcker alla zonbyten utan extra signaler).
	# "dynamic"-zoner följer det globala omgivningsvädret.
	var zone := World.current_zone
	var want := Weather.CLEAR
	if zone != null and is_instance_valid(zone) and "weather" in zone:
		want = Weather.resolve(zone.weather, WeatherSystem.current)
	var sz := size
	if want != _built_weather or sz != _built_size:
		weather = want
		_rebuild(sz)

	if weather == Weather.CLEAR and _fog_blobs.is_empty():
		return

	_t += delta
	var vel := Weather.velocity(weather)
	for i in _particles.size():
		var p := _particles[i] + vel * delta
		if weather == Weather.SNOW:
			p.x += sin(_t * 1.6 + _phases[i]) * 10.0 * delta   # mjuk sicksack
		_particles[i] = Weather.wrap(p, sz.x, sz.y)
	queue_redraw()

func _rebuild(sz: Vector2) -> void:
	_built_weather = weather
	_built_size = sz
	_particles.clear()
	_phases.clear()
	_fog_blobs.clear()
	if sz.x <= 0 or sz.y <= 0:
		_built_size = Vector2.ZERO   # tvinga ombyggnad när storleken är giltig
		return
	var n := Weather.particle_count(weather, sz.x * sz.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240624
	for i in n:
		_particles.append(Vector2(rng.randf() * sz.x, rng.randf() * sz.y))
		_phases.append(rng.randf() * TAU)
	if weather == Weather.FOG:
		for i in 5:
			_fog_blobs.append({
				"base": Vector2(rng.randf() * sz.x, rng.randf() * sz.y),
				"r": rng.randf_range(sz.y * 0.30, sz.y * 0.55),
				"ph": rng.randf() * TAU,
			})

func _draw() -> void:
	if weather == Weather.CLEAR:
		return
	# Färgtvätt över hela skärmen.
	draw_rect(Rect2(Vector2.ZERO, size), Weather.tint(weather))

	if weather == Weather.FOG:
		var fog_c := Color(0.78, 0.82, 0.86, 0.05)
		for b in _fog_blobs:
			var drift := Vector2(sin(_t * 0.18 + b["ph"]) * 60.0, cos(_t * 0.12 + b["ph"]) * 24.0)
			draw_circle(b["base"] + drift, b["r"], fog_c)
		return

	var col := Weather.particle_color(weather)
	col.a = Weather.particle_alpha(weather)
	var slen := Weather.streak_length(weather)
	if slen > 0.0:
		# Regn: strimmor längs fallriktningen.
		var dir := Weather.velocity(weather).normalized() * slen
		for p in _particles:
			draw_line(p, p - dir, col, 1.0)
	else:
		# Snö: små runda flingor.
		for p in _particles:
			draw_circle(p, 1.4, col)
