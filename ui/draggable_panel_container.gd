class_name DraggablePanelContainer
extends PanelContainer
## Dragbar PanelContainer.
## Håll nere vänster musknapp och dra för att flytta panelen fritt på skärmen.
## Klick (utan rörelse) passerar som vanligt till barn-noder.

const DRAG_THRESHOLD := 5.0   # pixlar rörelse innan drag aktiveras

var _pressed       := false
var _press_pos     := Vector2.ZERO
var _dragging      := false
var _drag_offset   := Vector2.ZERO
var _anchors_fixed := false   # true efter första draget

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_pressed   = true
		_press_pos = get_viewport().get_mouse_position()
	else:
		if _dragging:
			accept_event()   # svälja release för att undvika oavsiktliga klick på barnkontroller
		_pressed  = false
		_dragging = false

func _input(event: InputEvent) -> void:
	if not _pressed or not visible:
		return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		_pressed  = false
		_dragging = false
		return
	if not (event is InputEventMouseMotion):
		return
	var mpos := get_viewport().get_mouse_position()
	if not _dragging:
		if mpos.distance_to(_press_pos) < DRAG_THRESHOLD:
			return
		# Normalisera ankare till top-left för fri positionering
		if not _anchors_fixed:
			var abs_p := Vector2(global_position)
			set_anchors_and_offsets_preset(
				Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 0)
			position = abs_p
			_anchors_fixed = true
		_dragging    = true
		_drag_offset = position - _press_pos
		move_to_front()
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var np := mpos + _drag_offset
	np.x = clampf(np.x, 0.0, maxf(0.0, vp.x - size.x))
	np.y = clampf(np.y, 0.0, maxf(0.0, vp.y - size.y))
	position = np
	get_viewport().set_input_as_handled()
