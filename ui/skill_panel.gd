extends DraggablePanelContainer
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

var _cells: Dictionary = {}     # id -> nivå-Label
var _bars: Dictionary = {}      # id -> ProgressBar (XP-bar)
var _xp_history: Dictionary = {} # id -> Array[[tid_ms, total_xp]] (rullande fönster)
const XP_WINDOW_MS := 300000    # 5 min rullande fönster för xp/h
var _total_lbl: Label
var _guide: PanelContainer
var _guide_title: Label
var _guide_body: VBoxContainer
var _guide_skill := ""

const MET_FG := Color(0.55, 0.90, 0.45)   # grön: du klarar nivåkravet

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

	_build_guide()
	visibility_changed.connect(func(): if not visible and _guide: _guide.visible = false)

	GameState.skill_changed.connect(func(s):
		_record_xp(s)
		_refresh())
	_refresh()

# ── Träningsguide: klicka en skill → se var den tränas ──

func _build_guide() -> void:
	_guide = PanelContainer.new()
	_guide.top_level = true          # placeras i globala koordinater, oberoende av layout
	_guide.visible = false
	_guide.custom_minimum_size = Vector2(300, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	_guide.add_theme_stylebox_override("panel", sb)
	add_child(_guide)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_guide.add_child(vb)

	var header := HBoxContainer.new()
	vb.add_child(header)
	_guide_title = Label.new()
	_guide_title.add_theme_color_override("font_color", LVL_FG)
	_guide_title.add_theme_font_size_override("font_size", 13)
	_guide_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_guide_title)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 12)
	close.pressed.connect(func(): _guide.visible = false)
	header.add_child(close)

	vb.add_child(_sep())
	_guide_body = VBoxContainer.new()
	_guide_body.add_theme_constant_override("separation", 5)
	vb.add_child(_guide_body)

func _show_guide(skill_id: String) -> void:
	if _guide.visible and _guide_skill == skill_id:
		_guide.visible = false          # klicka samma skill igen = stäng
		return
	_guide_skill = skill_id
	for c in _guide_body.get_children():
		c.queue_free()

	var sname: String = String(GameState.skill_defs[skill_id]["name"]) \
		if skill_id in GameState.skill_defs else skill_id
	var lvl := int(GameState.skills.get(skill_id, {}).get("level", 1))
	_guide_title.text = "%s (Nv %d) — var du tränar" % [sname, lvl]

	var entries := SkillAtlas.entries_for(skill_id)
	if entries.is_empty():
		var hint := SkillAtlas.hint_for(skill_id)
		_guide_body.add_child(_body_label(hint if hint != "" else "Ingen träningsplats hittad."))
	else:
		for e in entries:
			_guide_body.add_child(_entry_row(e, lvl))

	_guide.reset_size()
	# Placera till vänster om skillpanelen, klampa innanför skärmen
	var vp := get_viewport_rect().size
	var gx := global_position.x - _guide.size.x - 8.0
	if gx < 4.0:
		gx = global_position.x + size.x + 8.0    # ryms inte vänster → lägg höger
	_guide.global_position = Vector2(gx, clampf(global_position.y, 4.0, maxf(4.0, vp.y - _guide.size.y - 4.0)))
	_guide.visible = true

func _entry_row(e: Dictionary, player_lvl: int) -> Label:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(284, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	var met: bool = player_lvl >= int(e["level"])
	var check := "✔" if met else "•"
	var kind := " (station)" if String(e.get("kind", "")) == "station" else ""
	var zones: Array = e.get("zones", [])
	var where := ", ".join(PackedStringArray(zones)) if not zones.is_empty() else "(ännu ej tillgänglig)"
	lbl.text = "%s Nv %d  %s%s\n      → %s" % [check, int(e["level"]), String(e["label"]), kind, where]
	lbl.add_theme_color_override("font_color", MET_FG if met else TEXT_FG)
	return lbl

func _body_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(284, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", TEXT_FG)
	return lbl

func _make_cell(id: String, label: String, icon_color: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(96, 66)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_guide(id))
	# Tooltip byggs om vid hover så xp/h och tid till nästa nivå är färska
	cell.mouse_entered.connect(func(): cell.tooltip_text = _tooltip_for(id, label))

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

	# XP-bar — fylls enligt skill_xp_progress, färgad i skillens egen färg
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0001
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.03, 0.01)
	bar_bg.border_color = BORDER
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = icon_color
	bar_fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(bar)

	_cells[id] = lvl_lbl
	_bars[id] = bar
	_ignore_mouse(vbox)   # barn ska inte sluka klicket — cellen hanterar det
	return cell

## Sätter mouse_filter = IGNORE på en kontroll och alla dess barn.
func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in c.get_children():
		if child is Control:
			_ignore_mouse(child)

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
		if _bars.has(id):
			_bars[id].value = GameState.skill_xp_progress(id)
	if _total_lbl:
		_total_lbl.text = "Total nivå: %d / %d" % [total, len(_cells) * 99]

# ── XP-takt (xp/h) + tid till nästa nivå ──

## Sparar en (tid, total-xp)-punkt och rensar punkter äldre än fönstret.
func _record_xp(id: String) -> void:
	var now := Time.get_ticks_msec()
	var hist: Array = _xp_history.get(id, [])
	hist.append([now, GameState.skill_total_xp(id)])
	# behåll punkter inom fönstret (plus den närmast före, som referens)
	while hist.size() > 2 and now - int(hist[0][0]) > XP_WINDOW_MS:
		hist.remove_at(0)
	_xp_history[id] = hist

## XP per timme baserat på det rullande fönstret (0 om för lite data).
func _xp_per_hour(id: String) -> float:
	var hist: Array = _xp_history.get(id, [])
	if hist.size() < 2:
		return 0.0
	var first: Array = hist[0]
	var last: Array = hist[-1]
	var dt := (int(last[0]) - int(first[0])) / 1000.0   # sekunder
	if dt <= 0.0:
		return 0.0
	var dxp := int(last[1]) - int(first[1])
	return float(dxp) / dt * 3600.0

func _tooltip_for(id: String, label: String) -> String:
	var sname: String = String(GameState.skill_defs[id]["name"]) if id in GameState.skill_defs else label
	var lvl := GameState.skill_base_level(id)
	var in_lvl := GameState.skill_xp_in_level(id)
	var to_next := GameState.skill_xp_to_next(id)
	var need := in_lvl + to_next
	var pct := int(round(GameState.skill_xp_progress(id) * 100.0))
	var rate := _xp_per_hour(id)

	var lines := PackedStringArray()
	lines.append("%s — Nivå %d" % [sname, lvl])
	lines.append("XP: %s / %s (%d%%)" % [_fmt(in_lvl), _fmt(need), pct])
	lines.append("Kvar: %s xp" % _fmt(to_next))
	if rate > 0.0:
		lines.append("Takt: %s xp/h" % _fmt(int(round(rate))))
		lines.append("Nästa nivå: %s" % _fmt_eta(to_next, rate))
	else:
		lines.append("Takt: — (träna för att mäta)")
	lines.append("Klicka: var tränar jag %s?" % sname)
	return "\n".join(lines)

## Tusentalsavgränsare med mellanslag: 12345 -> "12 345".
func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out

## Uppskattad tid kvar givet xp/h.
func _fmt_eta(xp_left: int, rate_per_h: float) -> String:
	if rate_per_h <= 0.0:
		return "okänd"
	var hours := float(xp_left) / rate_per_h
	var total_min := int(ceil(hours * 60.0))
	if total_min < 1:
		return "< 1 min"
	if total_min < 60:
		return "~%d min" % total_min
	var h := total_min / 60
	var m := total_min % 60
	return "~%d h %d min" % [h, m] if m > 0 else "~%d h" % h
