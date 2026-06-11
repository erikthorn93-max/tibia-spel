class_name Player
extends Node2D
## Tile-baserad rörelse + targeting + auto-attack (Tibia-stil).

const TILE := 32
const ATTACK_COOLDOWN := 1.0

var zone: Node2D                      # sätts av World vid zonladdning
var tile := Vector2i.ZERO
var _move_t := 1.0                    # 0..1 under pågående steg
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var move_speed := 4.0                 # tiles/sek
var facing := Vector2i.DOWN
var target: Node2D = null
var _attack_timer := 0.0

@onready var visual: CharacterVisual = $CharacterVisual

func _ready() -> void:
	visual.apply_appearance(GameState.appearance)

func snap_to(t: Vector2i) -> void:
	tile = t
	position = zone.tile_to_world(t)
	_move_t = 1.0
	GameState.player_tile = t

func set_target(m: Node2D) -> void:
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	target = m
	if target:
		target.modulate = Color(1.4, 0.9, 0.9)   # röd markering som Tibia

func _process(delta: float) -> void:
	_update_movement(delta)
	_update_attack(delta)

func _update_movement(delta: float) -> void:
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta * move_speed, 1.0)
		position = _from.lerp(_to, _move_t)
		if _move_t >= 1.0:
			GameState.player_tile = tile
			_check_portal()
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"): dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		facing = dir
		visual.face(dir)
		var next := tile + dir
		if zone.is_walkable(next):
			_from = position
			_to = zone.tile_to_world(next)
			tile = next
			_move_t = 0.0

func _update_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target and is_instance_valid(target) and not target.dead and _attack_timer <= 0.0:
		var dist := maxi(absi(target.tile.x - tile.x), absi(target.tile.y - tile.y))
		if dist <= 1:
			_attack_timer = ATTACK_COOLDOWN
			var weapon: Dictionary = ItemDB.items[GameState.equipped_weapon]
			var dmg := CombatFormulas.roll_melee(GameState.level, GameState.skills["sword"]["level"], int(weapon["atk"]))
			target.take_damage(dmg)
			GameState.gain_skill_xp("sword", 1)

func _check_portal() -> void:
	if zone.portals.has(tile):
		World.change_zone(zone.portals[tile])
