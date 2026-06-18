extends Node2D
## Flytande skadenummer — spawnas ovanför monster vid träff.
## Stiger uppåt och tonar ut på ~0.9 s, sedan queue_free().

const RISE_SPEED  := 28.0   # pixlar/s uppåt
const LIFE        := 0.9    # sekunder total livstid
const FADE_START  := 0.4    # andel av LIFE innan fade börjar

var _lbl:    Label
var _elapsed := 0.0
var _dmg:    float = 0.0
var _is_crit := false
var _force_color: Color = Color(-1, -1, -1)   # negativ = ingen override

func setup(dmg: float, crit := false, force_color: Color = Color(-1, -1, -1)) -> void:
	_dmg    = dmg
	_is_crit = crit
	_force_color = force_color
	_build_label()

func _build_label() -> void:
	_lbl = Label.new()
	_lbl.z_index = 50

	var text := str(int(_dmg)) if _dmg > 0 else "miss"

	# Tibia-stil: kritisk = stor gul, normal = vit, miss = grå
	var fsize  := 14
	var color  := Color(1.0, 1.0, 1.0)
	if _force_color.r >= 0.0:
		color = _force_color   # spelarhit-färg (röd/grön/orange)
	elif _is_crit:
		fsize  = 18
		color  = Color(1.0, 0.92, 0.15)   # gulvit
		text   = str(int(_dmg)) + "!"
	elif _dmg == 0:
		color  = Color(0.7, 0.7, 0.7)
		fsize  = 11

	_lbl.text = text
	_lbl.add_theme_font_size_override("font_size", fsize)
	_lbl.add_theme_color_override("font_color", color)

	# Svart kontur (outline) för läsbarhet
	_lbl.add_theme_constant_override("outline_size", 2)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	# Centrera texten horisontellt
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.custom_minimum_size  = Vector2(60, 0)
	_lbl.position             = Vector2(-30, -28)   # ovanför monster

	add_child(_lbl)

func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= RISE_SPEED * delta

	# Fade-out under sista delen av livet
	var fade_threshold := LIFE * (1.0 - FADE_START)
	var time_left := LIFE - _elapsed
	if time_left < fade_threshold:
		var alpha := clampf(time_left / fade_threshold, 0.0, 1.0)
		modulate = Color(1, 1, 1, alpha)

	if _elapsed >= LIFE:
		queue_free()
