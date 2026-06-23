extends Control
class_name CooldownOverlay
## Mörk radial svep-mask ovanpå en hotbar-ikon medan en besvärjelse/runa är på
## cooldown. Wedgen krymper medsols från toppen tills sloten är redo igen.
## Sätt remaining/total via set_cooldown(); rita sker bara när remaining > 0.

const _FILL  := Color(0.02, 0.02, 0.05, 0.62)   # mörk slöja över ikonen
const _EDGE  := Color(0.55, 0.65, 1.00, 0.85)   # ljus kant längs sveplinjen
const _TXT   := Color(0.92, 0.95, 1.00)
const _SEGS  := 36                               # polygonsegment för wedgen

var _remaining := 0.0
var _total     := 1.0
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

## Sätts varje frame av hotbaren (auktoritativ källa = SpellSystem.cooldown_left).
## Ritar bara om om värdet faktiskt ändrats eller wedgen just blev tom.
func set_cooldown(remaining: float, total: float) -> void:
	var r := maxf(remaining, 0.0)
	if is_equal_approx(r, _remaining):
		return
	var was_active := _remaining > 0.0
	_remaining = r
	_total = maxf(total, 0.01)
	if _remaining > 0.0 or was_active:
		queue_redraw()

func _draw() -> void:
	if _remaining <= 0.0:
		return
	var frac := clampf(_remaining / _total, 0.0, 1.0)
	var c := size * 0.5
	var r := maxf(size.x, size.y)            # täck hela rutan
	# Wedge: medsols från toppen, täcker återstående andel.
	var pts := PackedVector2Array([c])
	var start := -PI / 2.0
	var span := frac * TAU
	for i in range(_SEGS + 1):
		var a := start + span * (float(i) / _SEGS)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, _FILL)
	# Ljus kant längs den roterande sveplinjen.
	var edge_a := start + span
	draw_line(c, c + Vector2(cos(edge_a), sin(edge_a)) * r, _EDGE, 1.0)
	# Sekundsiffra centrerad.
	var label := String.num(_remaining, 1) if _remaining < 10.0 else str(int(ceil(_remaining)))
	var fs := 11
	var ts := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var pos := c - ts * 0.5 + Vector2(0, ts.y * 0.5)
	draw_string_outline(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _TXT)
