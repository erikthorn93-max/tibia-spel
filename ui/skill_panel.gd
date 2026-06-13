extends PanelContainer
## OSRS-stil skillpanel (K) — exakt OSRS-layout med 26 skills.
## Kolumner speglar OSRS-gridens ordning: vänster=strid, mitten=support, höger=gathering.

## [id, förkortning, ikon-färg]  — 3 kolumner × 9 rader = 27 celler (1 tom)
## Rad 1-7: direkt OSRS-mapping. Rad 8-9: Tibia-extras (club, fist, alchemy)
const SKILL_LAYOUT: Array = [
	# Kolumn 1 (Attack→sword, Strength→axe, Defence→shielding, Ranged→distance, Prayer, Magic, Runecraft, Construction, Club)
	# Kolumn 2 (Hitpoints→constitution, Agility, Herblore→herbalism, Thieving, Crafting, Fletching, Slayer, Hunter→hunting, Fist)
	# Kolumn 3 (Mining, Smithing, Fishing, Cooking, Firemaking, Woodcutting, Farming, Alchemy, [tom])
	# Rad 1
	["sword",        "Attack",  Color(0.80, 0.15, 0.10)],
	["constitution", "HP",      Color(0.80, 0.10, 0.10)],
	["mining",       "Mining",  Color(0.50, 0.55, 0.55)],
	# Rad 2
	["axe",          "Strengt", Color(0.60, 0.30, 0.08)],
	["agility",      "Agility", Color(0.91, 0.30, 0.24)],
	["smithing",     "Smithng", Color(0.70, 0.75, 0.75)],
	# Rad 3
	["shielding",    "Defence", Color(0.16, 0.50, 0.73)],
	["herbalism",    "Herblre", Color(0.09, 0.63, 0.40)],
	["fishing",      "Fishing", Color(0.10, 0.74, 0.61)],
	# Rad 4
	["distance",     "Ranged",  Color(0.15, 0.68, 0.38)],
	["thieving",     "Thievng", Color(0.85, 0.68, 0.05)],
	["cooking",      "Cookng",  Color(0.95, 0.61, 0.07)],
	# Rad 5
	["prayer",       "Prayer",  Color(0.80, 0.80, 0.50)],
	["crafting",     "Craftng", Color(0.70, 0.55, 0.35)],
	["firemaking",   "Firemkg", Color(0.95, 0.45, 0.05)],
	# Rad 6
	["magic",        "Magic",   Color(0.56, 0.27, 0.68)],
	["fletching",    "Fletchg", Color(0.35, 0.65, 0.35)],
	["woodcutting",  "WoodCut", Color(0.18, 0.70, 0.35)],
	# Rad 7
	["runecrafting", "Runecft", Color(0.20, 0.60, 0.86)],
	["slayer",       "Slayer",  Color(0.60, 0.10, 0.10)],
	["farming",      "Farmng",  Color(0.30, 0.70, 0.20)],
	# Rad 8 — Tibia-extras
	["construction", "Constrct",Color(0.70, 0.60, 0.40)],
	["hunting",      "Hunter",  Color(0.40, 0.55, 0.20)],
	["alchemy",      "Alchemy", Color(0.70, 0.35, 0.80)],
	# Rad 9 — Tibia-unika melé
	["club",         "Club",    Color(0.45, 0.28, 0.18)],
	["fist",         "Fist",    Color(0.90, 0.48, 0.10)],
]

const BG_COLOR  := Color(0.08, 0.05, 0.02)
const CELL_BG   := Color(0.14, 0.09, 0.04)
const TEXT_FG   := Color(1.00, 0.87, 0.60)
const LVL_FG    := Color(1.00, 1.00, 0.35)
const BORDER    := Color(0.36, 0.20, 0.08)
const SEP_COLOR := Color(0.50, 0.30, 0.10)

var _cells: Dictionary = {}
var _total_lbl: Label

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(306, 0)

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

	var title := Label.new()
	title.text = "Färdigheter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", LVL_FG)
	title.add_theme_font_size_override("font_size", 13)
	root.add_child(title)
	root.add_child(_sep())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	root.add_child(grid)

	for entry in SKILL_LAYOUT:
		grid.add_child(_make_cell(String(entry[0]), String(entry[1]), Color(entry[2])))

	# Separator + "Tibia-skills" label efter rad 7 (index 21)
	# (Vi lägger bara en separator visuellt via färgen på cellerna)

	root.add_child(_sep())
	_total_lbl = Label.new()
	_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_lbl.add_theme_color_override("font_color", TEXT_FG)
	_total_lbl.add_theme_font_size_override("font_size", 11)
	root.add_child(_total_lbl)

	GameState.skill_changed.connect(func(_s): _refresh())
	_refresh()

func _make_cell(id: String, label: String, icon_color: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(96, 58)

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

	# Ikon — färgad ruta med text
	var icon_wrap := CenterContainer.new()
	vbox.add_child(icon_wrap)

	var icon_bg := ColorRect.new()
	icon_bg.color = icon_color
	icon_bg.custom_minimum_size = Vector2(32, 24)
	icon_wrap.add_child(icon_bg)

	var icon_lbl := Label.new()
	icon_lbl.text = label.substr(0, 3)
	icon_lbl.add_theme_font_size_override("font_size", 8)
	icon_lbl.add_theme_color_override("font_color", Color.WHITE)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_bg.add_child(icon_lbl)

	# Skillnamn — hämtas från GameState (svenska/engelska)
	var sname: String = String(GameState.skill_defs[id]["name"]) if id in GameState.skill_defs else label
	var name_lbl := Label.new()
	name_lbl.text = sname
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", TEXT_FG)
	vbox.add_child(name_lbl)

	# Nivå — stor gul siffra
	var lvl_lbl := Label.new()
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", LVL_FG)
	vbox.add_child(lvl_lbl)

	_cells[id] = lvl_lbl
	return cell

func _sep() -> ColorRect:
	var r := ColorRect.new()
	r.color = SEP_COLOR
	r.custom_minimum_size = Vector2(0, 1)
	return r

func _refresh() -> void:
	var total := 0
	for id in _cells:
		if id in GameState.skills:
			var lv := int(GameState.skills[id]["level"])
			_cells[id].text = str(lv)
			total += lv
		else:
			_cells[id].text = "1"
	if _total_lbl:
		_total_lbl.text = "Total nivå: %d / %d" % [total, len(_cells) * 99]
