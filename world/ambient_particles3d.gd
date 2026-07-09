class_name AmbientParticles3D
extends Node3D
## Ambient-partiklar i 3D — eldflugor om natten ute, drivande damm i grottor,
## stigande glödflagor vid vulkanen. 3D-motsvarigheten till ui/ambient_overlay:
## samma rena Biome-funktioner bestämmer typ/färg/fart/antal, och vädret äger
## stämningen när det pågår (regn/dimma/snö → inga ambientpartiklar).
## Renderas som EN MultiMesh-batch av billboardade additiva quads (en draw
## call); positionerna driver och wrappar i en lokal låda som game3d centrerar
## på spelaren varje frame. Ingen allokering per frame.

const TILE_PX := 32.0     # 2D-farterna är i px/s — en tile är 32 px = 1 m
## Partikellådan runt spelaren (m): x/z centrerade, y från marken och upp.
const BOX := Vector3(18.0, 6.0, 18.0)
const QUAD_SIZE := {"fireflies": 0.09, "embers": 0.08, "dust": 0.05}

var kind := "none"
var _mmi: MultiMeshInstance3D
var _pos: Array[Vector3] = []
var _phases: PackedFloat32Array = PackedFloat32Array()
var _t := 0.0

# ── Rena hjälpare (testbara headless) ─────────────────────────────────────────

## Vilken ambient-typ som ska visas: biomets typ (natt spelar in), men bara
## när vädret är klart — annars äger vädret stämningen, som i 2D.
static func resolve_kind(zone_id: String, is_night: bool, wx: String) -> String:
	if wx != Weather.CLEAR:
		return "none"
	return Biome.ambient_kind(Biome.classify(zone_id), is_night)

## 2D-driften (px/s) översatt till 3D (m/s): x → x, 2D:s skärm-y (nedåt
## positiv) → världs-y uppochnedvänd. Glödflagor stiger, damm sjunker.
static func vel3(kind_: String) -> Vector3:
	var v := Biome.ambient_velocity(kind_) / TILE_PX
	return Vector3(v.x, -v.y, 0.0)

## Antal partiklar i lådan — samma täthetsformel som 2D (px²-arean av
## lådans markyta), så stämningen är gles i båda vyerna.
static func count_for(kind_: String) -> int:
	return Biome.ambient_count(kind_, BOX.x * BOX.z * TILE_PX * TILE_PX)

## Wrappar en lokal position tillbaka in i lådan (x/z centrerade, y ≥ 0).
static func wrap_local(p: Vector3) -> Vector3:
	p.x = wrapf(p.x, -BOX.x * 0.5, BOX.x * 0.5)
	p.z = wrapf(p.z, -BOX.z * 0.5, BOX.z * 0.5)
	p.y = wrapf(p.y, 0.0, BOX.y)
	return p

# ── Nod-logik ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var want := "none"
	var m: ZoneModel = World.zone_model
	if m != null:
		want = resolve_kind(m.zone_id, TimeOfDay.is_night,
			Weather.resolve(m.weather, WeatherSystem.current))
	if want != kind:
		_rebuild(want)
	if kind == "none":
		return
	_t += delta
	var vel := vel3(kind)
	var base := Biome.ambient_color(kind)
	var twinkle := Biome.ambient_twinkles(kind)
	var mm := _mmi.multimesh
	for i in _pos.size():
		var p := _pos[i] + vel * delta
		# Mjuk sidledesvandring så driften inte är spikrak (samma som 2D).
		p.x += sin(_t * 0.9 + _phases[i]) * (7.0 / TILE_PX) * delta
		p = wrap_local(p)
		_pos[i] = p
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		if twinkle:
			# Blinkande eldflugor / pulserande glöd — bara alpha ändras.
			var a := 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 2.4 + _phases[i] * 3.0))
			mm.set_instance_color(i, Color(base.r, base.g, base.b, a))

## Bygger om batchen för en ny typ. Deterministiskt frö (som 2D-overlayn).
func _rebuild(new_kind: String) -> void:
	kind = new_kind
	if _mmi != null:
		_mmi.queue_free()
		_mmi = null
	_pos.clear()
	_phases.clear()
	if kind == "none":
		return
	var n := count_for(kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	var s := float(QUAD_SIZE.get(kind, 0.07))
	quad.size = Vector2(s, s)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = n
	var base := Biome.ambient_color(kind)
	for i in n:
		var p := Vector3(
			(rng.randf() - 0.5) * BOX.x,
			rng.randf() * BOX.y,
			(rng.randf() - 0.5) * BOX.z)
		_pos.append(p)
		_phases.append(rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_color(i, Color(base.r, base.g, base.b, 0.7))
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
