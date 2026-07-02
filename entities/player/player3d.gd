class_name Player3D
extends Node3D
## 3D-vy för spelaren: samma PlayerSim som 2D-vyn (player.gd) driver
## gridrörelsen — den här noden läser bara input-intent, interpolerar
## position ur sim.move_progress och vrider visualen efter facing.
## Ingen spellogik här; kapseln är platshållare tills GLB-karaktären är
## decimerad (steg 4-assets).

var sim := PlayerSim.new()
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _visual: Node3D

func _init() -> void:
	sim.moved.connect(_on_sim_moved)
	sim.facing_changed.connect(_on_facing_changed)
	sim.attack_swung.connect(_on_attack_swung)

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.3
	caps.height = 1.2
	body.mesh = caps
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.70, 0.50)
	body.material_override = mat
	body.position.y = 0.6
	_visual.add_child(body)
	# "Näsa" framåt (−Z) så facing syns på platshållarkapseln.
	var nose := MeshInstance3D.new()
	var nbox := BoxMesh.new()
	nbox.size = Vector3(0.12, 0.12, 0.2)
	nose.mesh = nbox
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.6, 0.35, 0.25)
	nose.material_override = nmat
	nose.position = Vector3(0, 0.9, -0.32)
	_visual.add_child(nose)

## Teleport (zonladdning/respawn) — nollställer interpolationen.
func snap_to(t: Vector2i) -> void:
	sim.snap_to(t)
	position = Zone3D.tile_to_world3(t)
	_from = position
	_to = position

func _process(delta: float) -> void:
	var intent := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): intent = Vector2i.UP
	elif Input.is_action_pressed("move_down"): intent = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): intent = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): intent = Vector2i.RIGHT
	sim.advance(delta, intent)
	sim.attack_tick(delta)
	position = _from.lerp(_to, sim.move_progress)

## Steg påbörjat: sätt interpolationsmål (positionen läses ur move_progress).
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	_from = Zone3D.tile_to_world3(from)
	_to = Zone3D.tile_to_world3(to)

## Vrid visualen så −Z pekar i gångriktningen (grid-y = världens z).
func _on_facing_changed(dir: Vector2i) -> void:
	if _visual != null:
		_visual.rotation.y = atan2(-float(dir.x), -float(dir.y))

## Sving utförd (träff eller miss): snabb stöt mot slagriktningen.
func _on_attack_swung(dir: Vector2i) -> void:
	if _visual == null or dir == Vector2i.ZERO:
		return
	var lunge := Vector3(dir.x, 0, dir.y).normalized() * 0.22
	var tw := create_tween()
	tw.tween_property(_visual, "position", lunge, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position", Vector3.ZERO, 0.13).set_ease(Tween.EASE_IN_OUT)
