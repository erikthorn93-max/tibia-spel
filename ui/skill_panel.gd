extends PanelContainer
## Skillpanel (K): alla skills grupperade per kategori, nivå + XP-progress.

const CATEGORY_ORDER := ["combat", "gathering", "crafting", "utility"]
const CATEGORY_LABELS := {"combat": "Strid", "gathering": "Gathering", "crafting": "Crafting", "utility": "Utility"}

var _rows: Dictionary = {}   # skill_id -> {lvl: Label, bar: ProgressBar}

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(320, 0)
	var root := VBoxContainer.new()
	add_child(root)
	for cat in CATEGORY_ORDER:
		var header := Label.new()
		header.text = CATEGORY_LABELS[cat]
		header.add_theme_font_size_override("font_size", 14)
		root.add_child(header)
		var ids: Array = GameState.skill_defs.keys().filter(
			func(id): return GameState.skill_defs[id]["category"] == cat)
		ids.sort()
		for id in ids:
			root.add_child(_make_row(id))
	GameState.skill_changed.connect(func(_s): _refresh())
	_refresh()

func _make_row(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = String(GameState.skill_defs[id]["name"])
	name_lbl.custom_minimum_size = Vector2(110, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)
	var lvl := Label.new()
	lvl.custom_minimum_size = Vector2(40, 0)
	lvl.add_theme_font_size_override("font_size", 11)
	row.add_child(lvl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 10)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_rows[id] = {"lvl": lvl, "bar": bar}
	return row

func _refresh() -> void:
	for id in _rows:
		var s: Dictionary = GameState.skills[id]
		_rows[id]["lvl"].text = "Lv %d" % int(s["level"])
		_rows[id]["bar"].max_value = GameState.skill_xp_next(int(s["level"]), id)
		_rows[id]["bar"].value = int(s["xp"])
