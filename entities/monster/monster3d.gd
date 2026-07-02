class_name Monster3D
extends Node3D
## 3D-vy för ett monster: samma MonsterSim som 2D-vyn (monster.gd) äger AI,
## rörelse och strid — den här noden ritar platshållarlådan, hp-baren och
## attack-stöten. Spawnas av game3d; loot-drops på marken är 2D-bundna och
## hoppas över i slicen (exp/kills bokförs ändå av simuleringen).

const BAR_W := 0.8

var sim: MonsterSim
var player_sim: PlayerSim = null   # sätts av game3d — matar AI:n med spelar-tilen

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _visual: Node3D
var _body: MeshInstance3D
var _body_mat: StandardMaterial3D
var _hp_bar: MeshInstance3D
var _hp_mat: StandardMaterial3D
var _flash_tw: Tween

func _init() -> void:
	sim = MonsterSim.new()
	sim.damaged.connect(_on_sim_damaged)
	sim.moved.connect(_on_sim_moved)
	sim.attack_started.connect(_on_sim_attack_started)
	sim.enrage_started.connect(_on_sim_enraged)
	sim.died.connect(_on_sim_died)

func setup(mname: String, t: Vector2i, model: ZoneModel) -> void:
	sim.init_stats(mname, TimeOfDay.is_night)
	sim.place(t, model)
	position = Zone3D.tile_to_world3(t)
	_from = position
	_to = position
	_build_visual()

func make_elite() -> void:
	sim.make_elite()
	if _visual != null:
		_visual.scale = Vector3.ONE * 1.2
		_body_mat.emission_enabled = true
		_body_mat.emission = Color(1.0, 0.5, 0.0)
		_body_mat.emission_energy_multiplier = 0.35
	_refresh_hp_bar()

## Platshållarkropp i monstrets databasfärg + hp-bar ovanför. Materialen
## skapas EN gång här — träffar/enrage tweenar bara parametrar (ingen
## per-träff-allokering; lärdomen från godot_rpg).
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var d: Dictionary = MonsterDB.monsters.get(sim.monster_name, {})
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.9, 0.6)
	_body.mesh = box
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(String(d.get("color", "#aa3333")))
	_body.material_override = _body_mat
	_body.position.y = 0.45
	_visual.add_child(_body)
	_hp_bar = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(BAR_W, 0.07, 0.07)
	_hp_bar.mesh = bar
	_hp_mat = StandardMaterial3D.new()
	_hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar.material_override = _hp_mat
	_hp_bar.position.y = 1.25
	_visual.add_child(_hp_bar)
	_refresh_hp_bar()

func _refresh_hp_bar() -> void:
	if _hp_bar == null:
		return
	var ratio := float(sim.hp) / float(sim.max_hp) if sim.max_hp > 0 else 0.0
	_hp_bar.scale.x = maxf(ratio, 0.01)
	if sim.enraged:
		_hp_mat.albedo_color = Color(1.0, 0.2, 0.2)
	elif ratio > 0.5:
		_hp_mat.albedo_color = Color(0.18, 0.78, 0.18)
	elif ratio > 0.25:
		_hp_mat.albedo_color = Color(0.85, 0.72, 0.1)
	else:
		_hp_mat.albedo_color = Color(0.85, 0.12, 0.12)

## Vyns tick: mata AI:n med spelar-tilen och interpolera ur move_progress.
func _process(delta: float) -> void:
	if sim.dead:
		return
	var pt: Variant = null
	if player_sim != null:
		pt = player_sim.tile
	sim.ai_tick(delta, pt)
	position = _from.lerp(_to, sim.move_progress)

# ── Reaktioner på simuleringens signaler (rent visuellt) ──────────────────────
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	_from = position
	_to = Zone3D.tile_to_world3(to)
	var d := to - from
	if d != Vector2i.ZERO and _visual != null:
		_visual.rotation.y = atan2(-float(d.x), -float(d.y))

## Attack-stöt: kroppen lutar sig snabbt mot spelaren och studsar tillbaka.
func _on_sim_attack_started(dir: Vector2i) -> void:
	if _body == null or dir == Vector2i.ZERO:
		return
	var lunge := Vector3(dir.x, 0, dir.y).normalized() * 0.25
	var tw := create_tween()
	tw.tween_property(_body, "position", Vector3(0, 0.45, 0) + lunge, 0.07) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position", Vector3(0, 0.45, 0), 0.13) \
		.set_ease(Tween.EASE_IN_OUT)

## Träff: uppdatera baren + kort vit emission-blink (parameter-tween, ingen
## materialallokering).
func _on_sim_damaged(_amount: int, crit: bool) -> void:
	_refresh_hp_bar()
	if _body_mat == null:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	var rest_energy := 0.35 if sim.is_elite else 0.0
	var rest_color := Color(1.0, 0.5, 0.0) if sim.is_elite else Color(1, 1, 1)
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1, 1, 1)
	_body_mat.emission_energy_multiplier = 2.0 if crit else 1.0
	_flash_tw = create_tween()
	_flash_tw.tween_property(_body_mat, "emission_energy_multiplier", rest_energy, 0.18)
	_flash_tw.tween_callback(func():
		_body_mat.emission = rest_color
		_body_mat.emission_enabled = sim.is_elite)

func _on_sim_enraged() -> void:
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1.0, 0.1, 0.1)
	_body_mat.emission_energy_multiplier = 0.6
	_refresh_hp_bar()

## Död: simuleringen har bokfört exp/kills och frigjort tilen — krymp och
## försvinn. game3d schemalägger ev. respawn via died-signalen.
func _on_sim_died(_drops: Array) -> void:
	if _visual == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.25) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
