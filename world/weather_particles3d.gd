class_name WeatherParticles3D
extends Node3D
## Nederbörd i 3D — regnstrimmor, tätt åskskyfall och mjukt fallande snö.
## 3D-motsvarigheten till ui/weather_overlay: all logik (typ, fart, färg,
## antal, strimlängd) bor i ui/weather.gd; den här noden renderar som EN
## MultiMesh-batch av billboardade quads i uniform väderfärg (en draw call,
## ingen per-frame-allokering). Lådan följer spelaren; partiklarna faller
## och wrappar. Dimväder har inga partiklar — env-dimman äger det (game3d).
## Pollar upplöst väder varje frame, som 2D-overlayn.

const TILE_PX := 32.0
## Nederbördslådan runt spelaren (m): x/z centrerade, y från marken och upp.
const BOX := Vector3(14.0, 8.0, 14.0)
const STREAK_WIDTH := 0.02
const FLAKE_SIZE := 0.05

var weather := Weather.CLEAR
var _mmi: MultiMeshInstance3D
var _pos: Array[Vector3] = []
var _phases: PackedFloat32Array = PackedFloat32Array()
var _t := 0.0

# ── Rena hjälpare (testbara headless) ─────────────────────────────────────────

## 2D-fallet (px/s, skärm-y nedåt) översatt till 3D (m/s, världs-y upp).
static func vel3(w: String) -> Vector3:
	var v := Weather.velocity(w) / TILE_PX
	return Vector3(v.x, -v.y, 0.0)

## Antal partiklar i lådan — samma täthetsformel som 2D (px²-arean av
## lådans markyta). Dimma/klart → 0.
static func count_for(w: String) -> int:
	return Weather.particle_count(w, BOX.x * BOX.z * TILE_PX * TILE_PX)

## Quad-storlek per väder: regn/åska är fallstrimmor (2D:s streak_length
## i meter), snö små flingor.
static func quad_size(w: String) -> Vector2:
	var slen := Weather.streak_length(w)
	if slen > 0.0:
		return Vector2(STREAK_WIDTH, slen / TILE_PX)
	return Vector2(FLAKE_SIZE, FLAKE_SIZE)

## Wrappar en lokal position tillbaka in i lådan (x/z centrerade, y ≥ 0).
static func wrap_local(p: Vector3) -> Vector3:
	p.x = wrapf(p.x, -BOX.x * 0.5, BOX.x * 0.5)
	p.z = wrapf(p.z, -BOX.z * 0.5, BOX.z * 0.5)
	p.y = wrapf(p.y, 0.0, BOX.y)
	return p

# ── Nod-logik ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var want := Weather.CLEAR
	var m: ZoneModel = World.zone_model
	if m != null:
		want = Weather.resolve(m.weather, WeatherSystem.current)
	if want != weather:
		_rebuild(want)
	if _pos.is_empty():
		return
	_t += delta
	var vel := vel3(weather)
	var snow := weather == Weather.SNOW
	var mm := _mmi.multimesh
	for i in _pos.size():
		var p := _pos[i] + vel * delta
		if snow:
			# Mjuk sicksack så flingorna dansar (samma som 2D).
			p.x += sin(_t * 1.6 + _phases[i]) * (10.0 / TILE_PX) * delta
		p = wrap_local(p)
		_pos[i] = p
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))

## Bygger om batchen för ett nytt väder. Deterministiskt frö (som 2D-overlayn).
func _rebuild(w: String) -> void:
	weather = w
	if _mmi != null:
		_mmi.queue_free()
		_mmi = null
	_pos.clear()
	_phases.clear()
	var n := count_for(w)
	if n <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240624
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = quad_size(w)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Weather.particle_color(w)
	col.a = Weather.particle_alpha(w)
	mat.albedo_color = col
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = n
	for i in n:
		var p := Vector3(
			(rng.randf() - 0.5) * BOX.x,
			rng.randf() * BOX.y,
			(rng.randf() - 0.5) * BOX.z)
		_pos.append(p)
		_phases.append(rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
