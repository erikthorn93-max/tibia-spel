extends Node2D
## Generisk flytande text som stiger uppåt och tonar ut. Återanvänds för
## skill-utbyten ("+2 Trä"), xp-pop och craft-resultat. Syskon till
## damage_number.gd men med fri text/färg istället för bara siffror.

const RISE_SPEED := 24.0   # pixlar/s uppåt
const LIFE       := 1.1    # sekunder total livstid
const FADE_START := 0.45   # andel av LIFE i slutet då fade börjar

var _lbl: Label
var _elapsed := 0.0
var _text := ""
var _color := Color.WHITE
var _fsize := 13

func setup(text: String, color: Color = Color.WHITE, fsize: int = 13) -> void:
	_text = text
	_color = color
	_fsize = fsize
	_build()

func _build() -> void:
	_lbl = Label.new()
	_lbl.z_index = 50
	_lbl.text = _text
	_lbl.add_theme_font_size_override("font_size", _fsize)
	_lbl.add_theme_color_override("font_color", _color)
	_lbl.add_theme_constant_override("outline_size", 2)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.custom_minimum_size = Vector2(90, 0)
	_lbl.position = Vector2(-45, -30)
	add_child(_lbl)

func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= RISE_SPEED * delta
	var fade_threshold := LIFE * (1.0 - FADE_START)
	var time_left := LIFE - _elapsed
	if time_left < fade_threshold:
		modulate.a = clampf(time_left / fade_threshold, 0.0, 1.0)
	if _elapsed >= LIFE:
		queue_free()
