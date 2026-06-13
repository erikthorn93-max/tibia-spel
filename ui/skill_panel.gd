extends PanelContainer
## OSRS-stil skillpanel (K) — 3-kolumns grid med ikon, namn och nivå.

## Layout: [skill_id, förkortning, ikon-färg]
## Ordning matchar OSRS-gridens känsla men med Tibia2D-skills.
const SKILL_LAYOUT: Array = [
	# Strid (6) — översta blocken
	["sword",        "Swd", Color(0.80, 0.15, 0.10)],
	["axe",          "Axe", Color(0.60, 0.30, 0.08)],
	["club",         "Clb", Color(0.45, 0.28, 0.18)],
	["fist",         "Fst", Color(0.90, 0.48, 0.10)],
	["shielding",    "Shd", Color(0.16, 0.50, 0.73)],
	["distance",     "Dst", Color(0.15, 0.68, 0.38)],
	# Magi
	["magic",        "Mag", Color(0.56, 0.27, 0.68)],
	["runecrafting", "Rct", Color(0.20, 0.60, 0.86)],
	["alchemy",      "Alc", Color(0.70, 0.35, 0.80)],
	# Skötsel/Gathering
	["mining",       "Min", Color(0.50, 0.55, 0.55)],
	["fishing",      "Fsh", Color(0.10, 0.74, 0.61)],
	["woodcutting",  "Wct", Color(0.18, 0.70, 0.35)],
	["herbalism",    "Hrb", Color(0.09, 0.63, 0.40)],
	["smithing",     "Smt", Color(0.59, 0.65, 0.65)],
	["cooking",      "Ckn", Color(0.95, 0.61, 0.07)],
	# Utility
	["agility",      "Agi", Color(0.91, 0.30, 0.24)],
	["thieving",     "Thv", Color(0.85, 0.68, 0.05)],
	["slayer",       "Sly", Color(0.60, 0.10, 0.10)],
]

const BG_COLOR  := Color(0.08, 0.05, 0.02)
const CELL_BG   := Color(0.14, 0.09, 0.04)
const TEXT_FG   := Color(1.00, 0.87, 0.60)
const LVL_FG    := Color(1.00, 1.00, 0.40)
const BORDER    := Color(0.36, 0.20, 0.08)
const SEP_COLOR := Color(0.50, 0.30, 0.10)

var _cells: Dictionary = {}   # id -> Label (nivålabel)
var _total_lbl: Label

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(252, 0)

	var sb_outer := StyleBoxFlat.new()
	sb_outer.bg_color = BG_COLOR
	sb_outer.border_color = BORDER
	sb_outer.set_border_width_all(2)
	sb_outer.set_corner_radius_all(4)
	sb_outer.content_margin_left   = 5.0
	sb_outer.content_margin_right  = 5.0
	sb_outer.content_margin_top    = 5.0
	sb_outer.content_margin_bottom = 5.0
	add_theme_stylebox_override("panel", sb_outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	# Rubrik
	var title := Label.new()
	title.text = "Färdigheter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", LVL_FG)
	title.add_theme_font_size_override("font_size", 12)
	root.add_child(title)

	var sep0 := _make_separator()
	root.add_child(sep0)

	# OSRS-grid: 3 kolumner
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	root.add_child(grid)

	for entry in SKILL_LAYOUT:
		grid.add_child(_make_cell(String(entry[0]), String(entry[1]), Color(entry[2])))

	root.add_child(_make_separator())

	# Total nivå
	_total_lbl = Label.new()
	_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_lbl.add_theme_color_override("font_color", TEXT_FG)
	_total_lbl.add_theme_font_size_override("font_size", 10)
	root.add_child(_total_lbl)

	GameState.skill_changed.connect(func(_s): _refresh())
	_refresh()

## Skapar en cell i OSRS-stil: färgad ikon ovanför, namn+nivå under.
func _make_cell(id: String, abbrev: String, icon_color: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(80, 52)

	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.content_margin_left   = 3.0
	sb.content_margin_right  = 3.0
	sb.content_margin_top    = 3.0
	sb.content_margin_bottom = 3.0
	cell.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(vbox)

	# Ikon-rad: färgruta + förkortning centrerat
	var icon_wrap := CenterContainer.new()
	vbox.add_child(icon_wrap)

	var icon_bg := ColorRect.new()
	icon_bg.color = icon_color
	icon_bg.custom_minimum_size = Vector2(26, 22)
	icon_wrap.add_child(icon_bg)

	var icon_lbl := Label.new()
	icon_lbl.text = abbrev
	icon_lbl.add_theme_font_size_override("font_size", 7)
	icon_lbl.add_theme_color_override("font_color", Color.WHITE)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_bg.add_child(icon_lbl)

	# Skillnamn (liten, sand-färg)
	var name_lbl := Label.new()
	name_lbl.text = String(GameState.skill_defs[id]["name"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 7)
	name_lbl.add_theme_color_override("font_color", TEXT_FG)
	vbox.add_child(name_lbl)

	# Nivå (gul, tydlig)
	var lvl_lbl := Label.new()
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	lvl_lbl.add_theme_color_override("font_color", LVL_FG)
	vbox.add_child(lvl_lbl)

	_cells[id] = lvl_lbl
	return cell

func _make_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = SEP_COLOR
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

func _refresh() -> void:
	var total := 0
	for id in _cells:
		var lv := int(GameState.skills[id]["level"])
		_cells[id].text = "%d" % lv
		total += lv
	if _total_lbl:
		_total_lbl.text = "Total: %d / %d" % [total, len(_cells) * 99]
