extends DraggablePanelContainer
## Questlogg (J) — OSRS-stil: ALLA quests listade och färgkodade efter status
## (Pågående/Tillgängliga/Låsta/Klarade). Klicka en quest för att fälla ut
## givare, förkrav (med ✓/✗) och belöning. Pågående visar aktuellt steg + progress.

const COL_DONE := Color(0.55, 0.9, 0.55)      # grön — klarad
const COL_ACTIVE := Color(1.0, 0.85, 0.4)     # gul — pågår
const COL_AVAIL := Color(0.92, 0.92, 0.92)    # vit — kan startas nu
const COL_LOCKED := Color(0.55, 0.55, 0.58)   # grå — krav ej uppfyllda
const COL_HINT := Color(0.75, 0.72, 0.6)
const COL_OK := Color(0.55, 0.9, 0.55)
const COL_MISS := Color(0.95, 0.5, 0.45)

# Svårighetsgrad (OSRS-stil) — färg + rangordning för sortering
const DIFF_COLOR : Dictionary = {
	"Nybörjare": Color(0.55, 0.85, 0.55),
	"Lätt":      Color(0.66, 0.88, 0.45),
	"Medel":     Color(0.95, 0.85, 0.40),
	"Svår":      Color(0.96, 0.62, 0.30),
	"Mästare":   Color(0.96, 0.45, 0.42),
}
const DIFF_RANK : Dictionary = {
	"Nybörjare": 0, "Lätt": 1, "Medel": 2, "Svår": 3, "Mästare": 4,
}

var _scroll: ScrollContainer
var _list: VBoxContainer
var _expanded: Dictionary = {}      # quest_id -> true (utfällda rader)
var _zone_names: Dictionary = {}    # zon-id -> displaynamn (cache)

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(460, 0)
	offset_left = 300.0
	offset_top = 70.0
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(460, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	QuestSystem.quest_started.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_progress.connect(func(_id): if visible: _rebuild())
	QuestSystem.step_advanced.connect(func(_id): if visible: _rebuild())
	QuestSystem.quest_completed.connect(func(_id): if visible: _rebuild())

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

# ── Status ────────────────────────────────────────────────────────────────

func _status(id: String) -> String:
	if QuestSystem.completed.has(id):
		return "done"
	if QuestSystem.active.has(id):
		return "active"
	if QuestSystem.can_start(id):
		return "avail"
	return "locked"

func _status_color(st: String) -> Color:
	match st:
		"done": return COL_DONE
		"active": return COL_ACTIVE
		"avail": return COL_AVAIL
		_: return COL_LOCKED

func _difficulty(id: String) -> String:
	return String(QuestSystem.quests.get(id, {}).get("difficulty", "Medel"))

func _diff_color(diff: String) -> Color:
	return DIFF_COLOR.get(diff, Color(0.85, 0.85, 0.85))

func _diff_rank(id: String) -> int:
	return int(DIFF_RANK.get(_difficulty(id), 2))

# ── Bygg ──────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	var groups := {"active": [], "avail": [], "locked": [], "done": []}
	for id in QuestSystem.quests:
		groups[_status(id)].append(id)

	var total := QuestSystem.quests.size()
	var done: int = groups["done"].size()
	var title := Label.new()
	title.text = "Questlogg          %d / %d klarade" % [done, total]
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)

	# Questpoäng (OSRS-stil) + Questkappa-status
	var sub := Label.new()
	sub.text = "Questpoäng: %d / %d" % [QuestSystem.total_quest_points(), QuestSystem.max_quest_points()]
	sub.add_theme_font_size_override("font_size", 12)
	if QuestSystem.all_completed():
		sub.text += "    ★ Questkappan förtjänad!"
		sub.modulate = Color(0.92, 0.78, 0.40)
	else:
		sub.modulate = Color(0.70, 0.72, 0.78)
	_list.add_child(sub)

	_group("Pågående", groups["active"])
	_group("Tillgängliga", groups["avail"])
	_group("Låsta", groups["locked"])
	_group("Klarade", groups["done"])

func _group(header: String, ids: Array) -> void:
	if ids.is_empty():
		return
	# Sortera efter svårighet (lättast först), sedan namn — naturlig progression.
	ids.sort_custom(func(a, b):
		var ra := _diff_rank(a)
		var rb := _diff_rank(b)
		if ra != rb:
			return ra < rb
		return String(QuestSystem.quests[a]["name"]) < String(QuestSystem.quests[b]["name"]))
	var lbl := Label.new()
	lbl.text = "— %s (%d) —" % [header, ids.size()]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.85, 0.78, 0.55)
	_list.add_child(lbl)
	for id in ids:
		_quest_row(id)

func _quest_row(id: String) -> void:
	var st := _status(id)
	var q: Dictionary = QuestSystem.quests[id]
	var is_open: bool = _expanded.has(id)
	var arrow := "▾ " if is_open else "▸ "
	var mark := ""
	if st == "done":
		mark = "  ✓"
	elif st == "active":
		mark = "   (%s)" % _step_progress(id)
	elif st == "locked":
		mark = "   🔒"

	# Rad = [färgad svårighets-badge] + [quest-knapp]. Badgen bär svårighetsfärgen,
	# knapptexten bär status-färgen (klar/pågår/tillgänglig/låst) — som i OSRS.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var diff := _difficulty(id)
	var badge := Label.new()
	badge.custom_minimum_size = Vector2(64, 0)
	badge.text = diff
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", _diff_color(diff))
	row.add_child(badge)

	var btn := Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "%s%s%s" % [arrow, String(q["name"]), mark]
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", _status_color(st))
	btn.add_theme_color_override("font_hover_color", _status_color(st).lightened(0.2))
	btn.pressed.connect(func():
		if _expanded.has(id): _expanded.erase(id)
		else: _expanded[id] = true
		_rebuild())
	row.add_child(btn)
	_list.add_child(row)

	if is_open:
		_details(id, st)

func _details(id: String, st: String) -> void:
	var q: Dictionary = QuestSystem.quests[id]

	# Svårighet + questpoäng
	var diff := _difficulty(id)
	_detail_line("Svårighet: %s   (%d questpoäng)" % [diff, QuestSystem.quest_points(id)], _diff_color(diff))

	# Givare + plats
	var giver := String(q.get("giver", ""))
	var gname := String(DialogueDB.npcs.get(giver, {}).get("name", giver))
	var gzone := _zone_display(String(DialogueDB.npcs.get(giver, {}).get("zone", "")))
	_detail_line("Givare: %s%s" % [gname, ("  —  " + gzone) if gzone != "" else ""], COL_HINT)

	# Förkrav (OSRS-stil med ✓/✗)
	var reqs: Array = q.get("requires", [])
	if reqs.is_empty():
		_detail_line("Förkrav: inga", COL_HINT)
	else:
		_detail_line("Förkrav:", COL_HINT)
		for r in reqs:
			var rid := String(r)
			var rname := String(QuestSystem.quests.get(rid, {}).get("name", rid))
			var ok: bool = QuestSystem.completed.has(rid)
			_detail_line("    %s  %s" % [("✓" if ok else "✗"), rname], COL_OK if ok else COL_MISS)

	# Aktuellt steg (endast pågående)
	if st == "active":
		_detail_line("Steg: %s   %s" % [QuestSystem.hint(id), _step_progress(id)], COL_ACTIVE)

	# Belöning
	_detail_line("Belöning: %s" % _reward_text(id), Color(0.7, 0.85, 0.7))

func _detail_line(text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = "   " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(440, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = col
	_list.add_child(lbl)

# ── Hjälpare ──────────────────────────────────────────────────────────────

func _step_progress(id: String) -> String:
	var s := QuestSystem.current_step(id)
	if String(s.get("type", "")) in ["kill", "collect"]:
		return "%d/%d" % [int(QuestSystem.active[id]["progress"]), int(s["count"])]
	return "pågår"

func _reward_text(id: String) -> String:
	var r: Dictionary = QuestSystem.quests[id].get("rewards", {})
	var parts: Array = []
	if int(r.get("xp", 0)) > 0:
		parts.append("%d XP" % int(r["xp"]))
	if int(r.get("gold", 0)) > 0:
		parts.append("%d guld" % int(r["gold"]))
	for item_id in r.get("items", {}):
		var nm := String(ItemDB.items.get(item_id, {}).get("name", item_id))
		var n := int(r["items"][item_id])
		parts.append(nm if n <= 1 else "%s ×%d" % [nm, n])
	for sk in r.get("skill_xp", {}):
		parts.append("%d %s-xp" % [int(r["skill_xp"][sk]), sk])
	if int(r.get("charm_points", 0)) > 0:
		parts.append("%d charm-poäng" % int(r["charm_points"]))
	for uid in r.get("unlocks", []):
		parts.append("Outfit: %s" % UnlockSystem.display_name(String(uid)))
	return ", ".join(parts) if not parts.is_empty() else "—"

func _zone_display(zone_id: String) -> String:
	if zone_id == "":
		return ""
	if _zone_names.has(zone_id):
		return _zone_names[zone_id]
	var zname := zone_id
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.has("name"):
			zname = String(d["name"])
	_zone_names[zone_id] = zname
	return zname
