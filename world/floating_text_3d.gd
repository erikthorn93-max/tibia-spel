class_name FloatingText3D
extends Node3D
## Poolade Label3D-flyttexter för 3D-slicen: skadesiffror, läkning och
## element-taggar. Fast pool som återanvänds rakt av — ingen allokering
## per träff (godot_rpg-lärdomen). Billboardade och utan djuptest så de
## alltid syns över figurerna.

const POOL_SIZE := 12
const RISE := 0.7          # meter texten stiger
const LIFETIME := 0.8      # sekunder innan den slocknat

var _pool: Array[Label3D] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.font_size = 48
		l.outline_size = 10
		l.pixel_size = 0.01
		l.visible = false
		add_child(l)
		_pool.append(l)

## Visar en text vid en världsposition (strax ovanför huvudhöjd) som stiger
## och tonar ut. Rundgång i poolen: äldsta etiketten återanvänds.
func show_text(world_pos: Vector3, text: String, color: Color) -> void:
	var l := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old != null and old.is_valid():
			old.kill()
	l.text = text
	l.modulate = color
	l.position = world_pos + Vector3(0, 1.35, 0)
	l.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + RISE, LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(LIFETIME - 0.35)
	tw.chain().tween_callback(func():
		l.visible = false
		l.modulate.a = 1.0)
	l.set_meta("tw", tw)

## Skadesiffra: vit normalt, guld + större vid crit.
func show_damage(world_pos: Vector3, amount: int, crit: bool) -> void:
	show_text(world_pos, str(amount),
		Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1))

## Läkning: grönt plus-tal.
func show_heal(world_pos: Vector3, amount: int) -> void:
	show_text(world_pos, "+%d" % amount, Color(0.35, 0.95, 0.35))
