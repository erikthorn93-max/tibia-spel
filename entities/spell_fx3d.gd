class_name SpellFx3D
extends Node3D
## 3D-motsvarigheten till SpellFx (entities/spell_fx.gd): återanvändbara
## besvärjelse- och händelse-effekter. Samma repertoar som 2D — partikelskur,
## dödsskur per monstertyp, fontän, ring, projektil och ljusblixt — men i
## världsmeter (1 tile = 1 m; 2D-värdena är px vid 32 px/tile).
## Allt är engångshändelser (cast/död/plock) — självstädande noder, som 2D.
## Partikelmeshen + materialet delas statiskt så inget byggs om per skur;
## färg sätts via CPUParticles3D.color (vertex-färg i det delade materialet).

const PROJ_SPEED := 14.0    # m/s (2D:s 460 px/s vid 32 px/tile)
const PROJ_HEIGHT := 0.8    # projektilen flyger i brösthöjd
const PROJ_ARC := 0.35      # liten båge på vägen — läses som ett kast

static var _particle_mesh: QuadMesh = null
static var _ring_mesh: TorusMesh = null

var _mode := ""
var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _on_arrive: Callable = Callable()
var _gfx: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _max_r := 0.8

## Delad billboard-quad för alla partikelskurar (skapas EN gång per körning).
static func _get_particle_mesh() -> QuadMesh:
	if _particle_mesh == null:
		var m := QuadMesh.new()
		m.size = Vector2(0.05, 0.05)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material = mat
		_particle_mesh = m
	return _particle_mesh

## Delad tunn torus för expanderande ringar (enhetsradie, skalas per instans).
static func _get_ring_mesh() -> TorusMesh:
	if _ring_mesh == null:
		var m := TorusMesh.new()
		m.inner_radius = 0.92
		m.outer_radius = 1.0
		_ring_mesh = m
	return _ring_mesh

## Partikelskur vid en världsposition (nedslag / cast-flash).
static func burst(parent: Node, pos: Vector3, color: Color, amount := 12, vmax := 3.0) -> void:
	if parent == null:
		return
	_emit(parent, pos, color, amount, vmax * 0.4, vmax, Vector3(0, -6.0, 0),
		1.5, 3.0, 0.5)

## Dödsskur med stil per monstertyp (stilen ur SpellFx.death_kind — en källa).
## base_color = monstrets färg (fallback för dust). Samma profiler som 2D.
static func death_burst(parent: Node, pos: Vector3, base_color: Color, kind := "dust") -> void:
	if parent == null:
		return
	match kind:
		"bone":
			# Benskärvor som studsar ut och faller
			_emit(parent, pos, Color(0.90, 0.87, 0.78), 18, 1.9, 4.1,
				Vector3(0, -4.4, 0), 1.5, 3.0, 0.6)
		"ooze":
			# Tjock grön plask som klafsar nedåt
			_emit(parent, pos, Color(0.45, 0.78, 0.30), 14, 1.25, 3.0,
				Vector3(0, -5.6, 0), 2.5, 4.5, 0.55)
		"ember":
			# Glöd som stiger + mörk rök
			_emit(parent, pos, Color(1.0, 0.55, 0.15), 16, 1.6, 3.4,
				Vector3(0, 1.9, 0), 1.5, 3.0, 0.7)
			_emit(parent, pos, Color(0.25, 0.2, 0.18), 10, 0.6, 1.7,
				Vector3(0, 1.25, 0), 3.0, 5.0, 0.8)
		"ice":
			# Iskristaller som splittras utåt
			_emit(parent, pos, Color(0.65, 0.88, 1.0), 18, 2.2, 4.4,
				Vector3(0, -2.2, 0), 1.5, 3.0, 0.55)
		_:
			var dust := base_color.lerp(Color(0.25, 0.2, 0.18), 0.35)
			_emit(parent, pos, dust, 16, 1.4, 3.4,
				Vector3(0, -0.9, 0), 1.5, 3.0, 0.5)

## Gnistor som stiger uppåt (fontän). Återanvänds av heal & nivå-upp.
static func fountain(parent: Node, pos: Vector3, color: Color, amount := 14) -> void:
	if parent == null:
		return
	_emit(parent, pos, color, amount, 0.95, 1.9, Vector3(0, 0.6, 0),
		1.5, 3.0, 0.7, Vector3.UP, 35.0, 0.7)

## Helande gnistor som stiger uppåt vid målet.
static func heal_sparkle(parent: Node, pos: Vector3) -> void:
	fountain(parent, pos, Color(0.45, 1.0, 0.5))

## Intern fabrik: en självstädande engångs-CPUParticles3D med givna parametrar.
static func _emit(parent: Node, pos: Vector3, color: Color, amount: int,
		vmin: float, vmax: float, gravity: Vector3,
		smin: float, smax: float, lifetime: float,
		direction := Vector3.UP, spread := 180.0, explosiveness := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = explosiveness
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = _get_particle_mesh()
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color = color
	parent.add_child(p)
	p.get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)

## Expanderande, tonande markring (cast/buff/nivå-upp-markör). max_r i meter.
static func ring(parent: Node, pos: Vector3, color: Color, max_r := 0.8) -> void:
	if parent == null:
		return
	var fx := SpellFx3D.new()
	parent.add_child(fx)
	fx.position = pos + Vector3(0, 0.05, 0)
	fx._start_ring(color, max_r)

## Projektil som flyger från→till (markpositioner; höjd/båge läggs på internt)
## och kör on_arrive vid framkomst.
static func projectile(parent: Node, from: Vector3, to: Vector3, color: Color,
		on_arrive: Callable = Callable()) -> void:
	if parent == null:
		return
	var fx := SpellFx3D.new()
	parent.add_child(fx)
	fx._start_projectile(from, to, color, on_arrive)

## Kort ljusblixt vid ett nedslag — "lyser upp rummet" ett ögonblick.
## Tonar ut och städar sig själv (3D-motsvarigheten till player.gd:s
## _spawn_spell_flash; skalas inte av dygnet så träffen alltid syns).
static func flash(parent: Node, pos: Vector3, color: Color, peak := 1.8, radius := 3.0) -> void:
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = peak
	light.omni_range = radius
	light.position = pos + Vector3(0, 0.8, 0)
	parent.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)

# --- instans-implementation ---

func _start_ring(color: Color, max_r: float) -> void:
	_mode = "ring"
	_max_r = max_r
	_t = 0.0
	_gfx = MeshInstance3D.new()
	_gfx.mesh = _get_ring_mesh()
	# Eget material per ring (engångshändelse) — alfan animeras i _process.
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = color
	_gfx.material_override = _mat
	_gfx.scale = Vector3(0.01, 0.3, 0.01)   # platt torus, växer i _process
	add_child(_gfx)

func _start_projectile(from: Vector3, to: Vector3, color: Color, on_arrive: Callable) -> void:
	_mode = "projectile"
	_from = from
	_to = to
	_on_arrive = on_arrive
	_t = 0.0
	position = from + Vector3(0, PROJ_HEIGHT, 0)
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	core.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	core.material_override = mat
	add_child(core)
	# mjuk glow-ytterkula
	var glow := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.2
	gs.height = 0.4
	glow.mesh = gs
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	glow.material_override = gmat
	add_child(glow)

func _process(delta: float) -> void:
	match _mode:
		"ring":
			_t += delta
			var k := clampf(_t / 0.35, 0.0, 1.0)
			if _gfx != null:
				var r := maxf(_max_r * k, 0.01)
				_gfx.scale = Vector3(r, 0.3, r)
			if _mat != null:
				_mat.albedo_color.a = 1.0 - k
			if k >= 1.0:
				queue_free()
		"projectile":
			var dist := _from.distance_to(_to)
			var dur := maxf(dist / PROJ_SPEED, 0.05)
			_t += delta
			var k := clampf(_t / dur, 0.0, 1.0)
			position = _from.lerp(_to, k) \
				+ Vector3(0, PROJ_HEIGHT + sin(PI * k) * PROJ_ARC, 0)
			if k >= 1.0:
				if _on_arrive.is_valid():
					_on_arrive.call()
				queue_free()
