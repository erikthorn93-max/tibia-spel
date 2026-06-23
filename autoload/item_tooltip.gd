extends CanvasLayer
## ItemTooltip — singleton som visar item-info + statjämförelse vid hover.
## Anropas via ItemTooltip.show_for(item_id, screen_pos) / ItemTooltip.hide_tooltip()

var _panel: PanelContainer
var _icon:  TextureRect
var _name_lbl:  Label
var _stats_lbl: RichTextLabel
var _hide_timer := 0.0   # kort fördröjning för att undvika flimmer

func _ready() -> void:
	layer = 128   # alltid ovanpå allt annat
	_build_panel()
	_panel.visible = false

func _process(delta: float) -> void:
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_panel.visible = false

# ─── Public API ────────────────────────────────────────────────────────────────

func show_for(item_id: String, screen_pos: Vector2) -> void:
	_hide_timer = 0.0
	if item_id.is_empty():
		_panel.visible = false
		return
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if d.is_empty():
		_panel.visible = false
		return

	_icon.texture = _load_sprite(item_id)
	_name_lbl.text = String(d.get("name", item_id))

	var slot := String(d.get("slot", ""))
	var eq_id := ""
	var eq_d: Dictionary = {}
	if slot != "":
		eq_id = String(GameState.equipment.get(slot, ""))
		if eq_id != "" and eq_id != item_id:
			eq_d = ItemDB.items.get(eq_id, {})

	_stats_lbl.text = _build_stats_bbcode(d, eq_d, eq_id)

	_panel.visible = true
	await get_tree().process_frame   # låt panelen beräkna sin storlek
	_panel.position = _safe_pos(screen_pos)

func hide_tooltip() -> void:
	_hide_timer = 0.08   # kort grace-period mot flimmer vid horisontell rörelse

func hide_immediately() -> void:
	_hide_timer = 0.0
	_panel.visible = false

# ─── UI byggnad ────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color         = Color(0.08, 0.07, 0.05, 0.97)
	sb.border_color     = Color(0.50, 0.40, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 8.0
	sb.content_margin_right  = 10.0
	sb.content_margin_top    = 6.0
	sb.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	# Rubrikrad: ikon + namn
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_icon)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 13)
	_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_name_lbl)
	vbox.add_child(hdr)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_stats_lbl = RichTextLabel.new()
	_stats_lbl.bbcode_enabled  = true
	_stats_lbl.fit_content     = true
	_stats_lbl.scroll_active   = false
	_stats_lbl.custom_minimum_size = Vector2(180, 0)
	_stats_lbl.add_theme_font_size_override("normal_font_size", 11)
	_stats_lbl.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stats_lbl)

	_panel.add_child(vbox)
	add_child(_panel)

# ─── Stat-text (BBCode) ────────────────────────────────────────────────────────

func _build_stats_bbcode(d: Dictionary, eq_d: Dictionary, eq_id: String) -> String:
	var lines: PackedStringArray = []

	# Typ-rad
	var type_sv := _type_sv(String(d.get("type", "")), String(d.get("slot", "")))
	lines.append("[color=#998866]%s[/color]" % type_sv)

	# Jämförbara stats (vapen/rustning)
	var stat_keys := ["atk", "armor", "shielding_bonus", "atk_bonus", "def_bonus", "speed_bonus"]
	var stat_names := {
		"atk":            "ATK",
		"armor":          "Rustning",
		"shielding_bonus":"Blockering",
		"atk_bonus":      "ATK-bonus",
		"def_bonus":      "DEF-bonus",
		"speed_bonus":    "Hastighet",
	}
	for sk in stat_keys:
		if d.has(sk):
			var val := int(d[sk])
			var line := "[color=#cccccc]%s: %d[/color]" % [stat_names[sk], val]
			if not eq_d.is_empty():
				var eq_val := int(eq_d.get(sk, 0))
				var diff := val - eq_val
				if diff > 0:
					line += " [color=#44dd44](▲+%d)[/color]" % diff
				elif diff < 0:
					line += " [color=#dd4444](▼%d)[/color]" % diff
				else:
					line += " [color=#888888](=[/color][color=#888888])[/color]"
			lines.append(line)
		elif not eq_d.is_empty() and eq_d.has(sk):
			# Utrustat item har stat men detta inte — visar negativ diff
			var eq_val := int(eq_d[sk])
			if eq_val > 0:
				lines.append("[color=#cccccc]%s: 0 [color=#dd4444](▼-%d)[/color][/color]" % [stat_names[sk], eq_val])

	# Icke-jämförbara stats
	if d.has("heal"):
		lines.append("[color=#88ff88]Helande: +%d HP[/color]" % int(d["heal"]))
	if d.has("mana"):
		lines.append("[color=#8888ff]Mana: +%d[/color]" % int(d["mana"]))
	if d.has("rune_power"):
		lines.append("[color=#ffcc44]Kraft: %d[/color]" % int(d["rune_power"]))
	if d.has("magic_lvl"):
		lines.append("[color=#ccaaff]Magic level krav: %d[/color]" % int(d["magic_lvl"]))
	if d.has("range"):
		lines.append("[color=#cccccc]Räckvidd: %d[/color]" % int(d["range"]))
	if d.has("level_req"):
		lines.append("[color=#ffaa44]Level krav: %d[/color]" % int(d["level_req"]))
	if d.get("clears_poison", false):
		lines.append("[color=#88ffaa]Botar gift[/color]")

	# Bäst mot-rad om utrustat item finns
	if not eq_d.is_empty():
		var eq_name := String(eq_d.get("name", eq_id))
		lines.append("")
		lines.append("[color=#666655]Utrustat: %s[/color]" % eq_name)

	# Värde
	if d.has("value"):
		lines.append("[color=#888855]Värde: %d guld[/color]" % int(d["value"]))

	return "\n".join(lines)

func _type_sv(type: String, slot: String) -> String:
	match type:
		"weapon":  return "Vapen  (%s)" % _slot_sv(slot)
		"armor":   return "Rustning  (%s)" % _slot_sv(slot)
		"potion":  return "Dryck"
		"rune":    return "Runa"
		"food":    return "Mat"
		"material":return "Material"
		"ammo":    return "Ammunition"
		"tool":    return "Verktyg"
		"junk":    return "Skräp"
		"currency":return "Valuta"
		_:         return type if type != "" else "—"

func _slot_sv(slot: String) -> String:
	match slot:
		"weapon":  return "Vapen"
		"body":    return "Harnesk"
		"helmet":  return "Hjälm"
		"legs":    return "Benskydd"
		"boots":   return "Skor"
		"offhand": return "Sköld"
		_:         return slot

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _load_sprite(item_id: String) -> Texture2D:
	return ItemIcons.texture(item_id)

func _safe_pos(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return screen_pos + Vector2(16, 8)
	var vs  := Vector2(vp.get_visible_rect().size)
	var ps  := _panel.get_minimum_size()
	var p   := screen_pos + Vector2(18, 10)
	return Vector2(
		clampf(p.x, 4.0, vs.x - ps.x - 4.0),
		clampf(p.y, 4.0, vs.y - ps.y - 4.0)
	)
