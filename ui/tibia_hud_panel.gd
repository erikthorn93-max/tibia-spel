extends Control
## Tibia-stil höger-sidopanel.
## Innehåller HP/mana-bars, status, experience, target-sektion och knappar.
## Bredd: 176 px, ankarad till höger sida.

const PANEL_W := 176.0
const BAR_H   := 12.0

# Färger (klassisk Tibia-palett)
const C_BG       := Color(0.13, 0.11, 0.09)       # mörk brun bakgrund
const C_BORDER   := Color(0.55, 0.48, 0.32)       # guldbrun kant
const C_HP       := Color(0.80, 0.12, 0.12)       # röd HP
const C_HP_BG    := Color(0.20, 0.05, 0.05)
const C_MP       := Color(0.18, 0.35, 0.80)       # blå mana
const C_MP_BG    := Color(0.05, 0.07, 0.20)
const C_XP       := Color(0.75, 0.60, 0.10)       # guld XP
const C_XP_BG    := Color(0.18, 0.14, 0.03)
const C_TXT      := Color(0.88, 0.84, 0.62)       # gulvit text
const C_TXT_DIM  := Color(0.55, 0.50, 0.35)
const C_TARGET   := Color(0.85, 0.25, 0.25)       # target HP
const C_SECTION  := Color(0.22, 0.20, 0.16)       # sektion-bakgrund
const C_BTN_NORM := Color(0.28, 0.25, 0.20)
const C_BTN_HOV  := Color(0.40, 0.36, 0.28)

# Noder
var _hp_fill:     Control
var _mp_fill:     Control
var _xp_fill:     Control
var _hp_lbl:      Label
var _mp_lbl:      Label
var _lvl_lbl:     Label
var _gold_lbl:    Label
var _status_lbl:  Label
var _target_name: Label
var _target_fill: Control
var _target_sec:  Control   # hela target-sektionen
var _skill_lbl:   Label

func _ready() -> void:
	# Ankaras till höger
	anchor_left   = 1.0
	anchor_right  = 1.0
	anchor_top    = 0.0
	anchor_bottom = 1.0
	offset_left   = -PANEL_W
	offset_right  = 0.0
	offset_top    = 0.0
	offset_bottom = 0.0
	mouse_filter  = Control.MOUSE_FILTER_STOP

	_draw_panel()

# ─────────────────────────────────────────────────────────────────────
func _draw_panel() -> void:
	var y: float = 0.0

	# ── Yttre bakgrund ───────────────────────────────────────────────
	_bg_rect(0, 0, PANEL_W, 9999)

	# ── HP ──────────────────────────────────────────────────────────
	y = _section_label(y, "Hälsa")
	var hp_row := _bar_row(y, C_HP_BG, C_HP)
	_hp_fill  = hp_row[0]
	_hp_lbl   = hp_row[1]
	y += BAR_H + 2

	# ── Mana ────────────────────────────────────────────────────────
	y = _section_label(y, "Mana")
	var mp_row := _bar_row(y, C_MP_BG, C_MP)
	_mp_fill = mp_row[0]
	_mp_lbl  = mp_row[1]
	y += BAR_H + 2

	# ── XP ──────────────────────────────────────────────────────────
	y = _section_label(y, "Erfarenhet")
	var xp_row := _bar_row(y, C_XP_BG, C_XP)
	_xp_fill = xp_row[0]
	# XP bar har ingen siffer-label (för smal)
	xp_row[1].visible = false
	y += BAR_H + 4

	# ── Nivå / guld ─────────────────────────────────────────────────
	var info_sec := _make_section(y, 30)
	y += 32
	_lvl_lbl  = _lbl(info_sec,  4,  4, C_TXT,     11, "Nivå 1")
	_gold_lbl = _lbl(info_sec,  4, 16, C_XP,      10, "0 gp")
	_skill_lbl = _lbl(info_sec, 80,  4, C_TXT_DIM, 10, "")

	# ── Status-chips ────────────────────────────────────────────────
	var stat_sec := _make_section(y, 18)
	y += 20
	_status_lbl = _lbl(stat_sec, 4, 2, Color(0.3, 0.9, 0.3), 10, "")

	# ── Separator ────────────────────────────────────────────────────
	_hline(y); y += 3

	# ── Target-sektion ───────────────────────────────────────────────
	_target_sec = _make_section(y, 38)
	_target_sec.visible = false
	var tname := _lbl(_target_sec, 4, 3, C_TARGET, 11, "")
	_target_name = tname
	# Target HP-bar
	var t_bg := _sub_rect(_target_sec, 4, 18, PANEL_W - 8, BAR_H, C_HP_BG)
	var t_fill := _sub_rect(_target_sec, 4, 18, PANEL_W - 8, BAR_H, C_TARGET)
	_target_fill = t_fill
	# Klipp fyllningen via clip_contents på bg
	t_bg.clip_contents = true
	y += 42

	# ── Separator ────────────────────────────────────────────────────
	_hline(y)

# ─── Hjälpfunktioner ─────────────────────────────────────────────────
func _bg_rect(x: float, y: float, w: float, h: float) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size     = Vector2(w, h)
	r.color    = C_BG
	add_child(r)
	# Kantlinje (vänster)
	var line := ColorRect.new()
	line.position = Vector2(0, 0)
	line.size     = Vector2(2, 9999)
	line.color    = C_BORDER
	add_child(line)
	return r

func _section_label(y: float, text: String) -> float:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(4, y + 1)
	lbl.size = Vector2(PANEL_W - 8, 14)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", C_TXT_DIM)
	add_child(lbl)
	return y + 13

func _bar_row(y: float, bg_col: Color, fill_col: Color) -> Array:
	# Bakgrund
	var bg := ColorRect.new()
	bg.position = Vector2(4, y)
	bg.size     = Vector2(PANEL_W - 8, BAR_H)
	bg.color    = bg_col
	add_child(bg)
	# Fyllning (klippt)
	bg.clip_contents = true
	var fill := ColorRect.new()
	fill.position = Vector2(0, 0)
	fill.size     = Vector2(PANEL_W - 8, BAR_H)
	fill.color    = fill_col
	bg.add_child(fill)
	# Text
	var lbl := Label.new()
	lbl.position = Vector2(0, 0)
	lbl.size     = Vector2(PANEL_W - 8, BAR_H)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	bg.add_child(lbl)
	return [fill, lbl]

func _make_section(y: float, h: float) -> ColorRect:
	var sec := ColorRect.new()
	sec.position = Vector2(2, y)
	sec.size     = Vector2(PANEL_W - 4, h)
	sec.color    = C_SECTION
	add_child(sec)
	return sec

func _sub_rect(parent: Control, x: float, y: float, w: float, h: float, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size     = Vector2(w, h)
	r.color    = col
	parent.add_child(r)
	return r

func _lbl(parent: Control, x: float, y: float, col: Color, size: int, text: String) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = Vector2(x, y)
	l.size     = Vector2(PANEL_W - x - 4, 14)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _hline(y: float) -> void:
	var r := ColorRect.new()
	r.position = Vector2(4, y)
	r.size     = Vector2(PANEL_W - 8, 1)
	r.color    = C_BORDER
	add_child(r)

# ─── Uppdatering ─────────────────────────────────────────────────────
func refresh(hp: float, max_hp: float, mp: float, max_mp: float,
		xp: int, xp_next: int, level: int, gold: int,
		skill_name: String, skill_lvl: int, status_text: String) -> void:
	var hp_r := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var mp_r := clampf(mp / maxf(max_mp, 1.0), 0.0, 1.0)
	var xp_r := clampf(float(xp) / maxf(float(xp_next), 1.0), 0.0, 1.0)
	_hp_fill.size.x = (PANEL_W - 8) * hp_r
	_mp_fill.size.x = (PANEL_W - 8) * mp_r
	_xp_fill.size.x = (PANEL_W - 8) * xp_r
	_hp_lbl.text  = "%d / %d" % [int(hp), int(max_hp)]
	_mp_lbl.text  = "%d / %d" % [int(mp), int(max_mp)]
	_lvl_lbl.text = "Nivå %d" % level
	_gold_lbl.text = "%d gp" % gold
	_skill_lbl.text = "%s %d" % [skill_name, skill_lvl]
	_status_lbl.text = status_text

func refresh_target(name: String, hp: float, max_hp: float) -> void:
	if name.is_empty():
		_target_sec.visible = false
		return
	_target_sec.visible = true
	_target_name.text = name
	var r := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_target_fill.size.x = (PANEL_W - 8) * r
