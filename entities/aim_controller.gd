extends Node2D
## Sikt-cursor för spells/runor som kräver ett mål (target/area).
## begin(def, on_confirm) går in i sikt-läge: highlightar räckvidden, ritar
## AoE-fotavtrycket under muspekaren, vänsterklick bekräftar en giltig ruta,
## höger/ESC avbryter. Lever som Node2D i världen (ritas över zonen).

const TILE := 32

var _active := false
var _on_confirm: Callable
var _range := 5
var _radius := 0
var _target_type := "target"   # "target" | "area"
var _cursor := Vector2i.ZERO
var _valid := false

func _ready() -> void:
	position = Vector2.ZERO
	z_index = 50
	set_process_input(false)

## Går in i sikt-läge. def kommer från SpellSystem.cast_def().
func begin(def: Dictionary, on_confirm: Callable) -> void:
	_on_confirm = on_confirm
	_range = int(def.get("range", SpellSystem.DEFAULT_RANGE))
	_radius = int(def.get("radius", 0))
	_target_type = String(def.get("target", "target"))
	_active = true
	set_process_input(true)
	_update_cursor()
	queue_redraw()

func _end() -> void:
	_active = false
	set_process_input(false)
	queue_redraw()

func _cancel() -> void:
	_end()
	if World.hud:
		World.hud.show_message("Avbröt.")

func _confirm() -> void:
	var picked := _cursor
	var cb := _on_confirm
	_end()
	if cb.is_valid():
		cb.call(picked)

# ── Input ────────────────────────────────────────────────────────────────────
## _input (inte _unhandled_input) så vi konsumerar klicket innan game_root
## tolkar det som gå-hit/välj-mål.
func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		_update_cursor()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_update_cursor()
			if _valid:
				_confirm()
			elif World.hud:
				World.hud.show_message("Ogiltigt mål.")   # siktet kvarstår
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_cancel()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel()

func _update_cursor() -> void:
	if World.current_zone == null:
		return
	_cursor = World.current_zone.world_to_tile(get_global_mouse_position())
	_valid = _is_valid(_cursor)

func _is_valid(t: Vector2i) -> bool:
	if World.player == null or not is_instance_valid(World.player):
		return false
	if _chebyshev(World.player.tile, t) > _range:
		return false
	if _target_type == "target":
		return _monster_at(t) != null
	return true   # area: vilken ruta som helst inom räckvidd

func _monster_at(t: Vector2i):
	if World.current_zone == null:
		return null
	for child in World.current_zone.get_children():
		if child.has_method("take_damage") and not bool(child.get("dead")) \
				and child.get("tile") == t:
			return child
	return null

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# ── Ritning ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if not _active or World.player == null or not is_instance_valid(World.player):
		return
	var center: Vector2i = World.player.tile
	# Räckvidd: svag blå markering på alla rutor inom range.
	for dy in range(-_range, _range + 1):
		for dx in range(-_range, _range + 1):
			var t := center + Vector2i(dx, dy)
			draw_rect(_tile_rect(t), Color(0.40, 0.62, 1.0, 0.08), true)
	# AoE-fotavtryck under cursorn (grönt = giltigt, rött = ogiltigt).
	var fill := Color(0.30, 1.0, 0.40, 0.28) if _valid else Color(1.0, 0.30, 0.30, 0.25)
	var line := Color(0.40, 1.0, 0.50, 0.9) if _valid else Color(1.0, 0.40, 0.40, 0.8)
	for dy in range(-_radius, _radius + 1):
		for dx in range(-_radius, _radius + 1):
			var rect := _tile_rect(_cursor + Vector2i(dx, dy))
			draw_rect(rect, fill, true)
			draw_rect(rect, line, false, 1.5)

func _tile_rect(t: Vector2i) -> Rect2:
	return Rect2(Vector2(t) * TILE, Vector2(TILE, TILE))
