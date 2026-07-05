extends Node
## 30 fritt positionerbara hotkey-rutor.
## Vänsterklick = använd item. Drag (håll + flytta) = flytta rutan. Högerklick = konfigurera.

const SLOT_COUNT    := 30
const CFG_FILE      := "user://hotkeys.json"
const SLOT_W        := 36.0
const SLOT_H        := 36.0
const DRAG_THRESHOLD := 5.0

const DEFAULT_KEYS: Array = [
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5,
	KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10,
	KEY_F11, KEY_F12,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8,
	KEY_9, KEY_0,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I,
]
const DEFAULT_NAMES: Array = [
	"F1","F2","F3","F4","F5","F6","F7","F8","F9","F10",
	"F11","F12","1","2","3","4","5","6","7","8",
	"9","0","Q","W","E","R","T","Y","U","I",
]

# Slot-data: [{key_name, keycode, item_id, pos_x, pos_y}]
var _slots: Array = []

## Kastaren (äger cast_spell) — standard World.player (2D); Hud3D pekar om
## den till Player3D. Läses vid varje användning, aldrig cachad som nod.
var caster: Object = null

# En Control-nod per slot
var _slot_nodes:    Array = []
var _slot_icons:    Array = []
var _slot_name_lbls: Array = []
var _slot_key_lbls:  Array = []
var _slot_cooldowns: Array = []   # CooldownOverlay per slot
var _slot_cast_ids:  Array = []   # castbart id per slot ("" om ej spell/runa)
var _slot_blink:     Array = []   # kvarvarande blink-tid (s) per slot

# Drag-tillstånd
var _drag_slot    := -1
var _drag_offset  := Vector2.ZERO
var _drag_start   := Vector2.ZERO
var _drag_moved   := false

# Konfig-popup (delad)
var _popup:       Control  = null
var _cfg_idx      := -1
var _wait_key     := false
var _cfg_key_btn:  Button  = null
var _cfg_item_lst: ItemList = null
var _pending_kname := ""
var _pending_kcode := 0

# ─────────────────────────────────────────────
func _ready() -> void:
	_init_slots()
	_load_config()
	for i in SLOT_COUNT:
		_build_slot(i)
	_build_popup()
	_refresh_all()
	SpellSystem.spell_cast.connect(_on_spell_cast)

## Lyckad cast → blixt på alla slottar bundna till samma besvärjelse/runa.
func _on_spell_cast(id: String, _result: Dictionary) -> void:
	for i in _slot_cast_ids.size():
		if String(_slot_cast_ids[i]) == id:
			_slot_blink[i] = _BLINK_TIME

func _default_pos(i: int) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var col := i % 10
	var row := i / 10
	return Vector2(80.0 + col * (SLOT_W + 2.0), vp.y - 130.0 + row * (SLOT_H + 2.0))

func _init_slots() -> void:
	_slots.clear()
	for i in SLOT_COUNT:
		var dp := _default_pos(i)
		_slots.append({
			"key_name": DEFAULT_NAMES[i],
			"keycode":  int(DEFAULT_KEYS[i]),
			"item_id":  "",
			"spell_id": "",
			"pos_x":    dp.x,
			"pos_y":    dp.y,
		})

func _load_config() -> void:
	if not FileAccess.file_exists(CFG_FILE):
		return
	var f := FileAccess.open(CFG_FILE, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for i in mini(parsed.size(), SLOT_COUNT):
			if parsed[i] is Dictionary:
				_slots[i].merge(parsed[i], true)

func _save_config() -> void:
	var f := FileAccess.open(CFG_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_slots))

# ─────────────────────────────────────────────
func _build_slot(idx: int) -> void:
	var slot_data: Dictionary = _slots[idx]

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	cell.position = Vector2(float(slot_data.get("pos_x", 80.0)), float(slot_data.get("pos_y", 80.0)))
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.z_index = 10

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.35)
	sb.border_color = Color(0.55, 0.55, 0.70, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 2.0
	sb.content_margin_right  = 2.0
	sb.content_margin_top    = 2.0
	sb.content_margin_bottom = 2.0
	cell.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(vbox)

	# Sprite-ikon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)
	_slot_icons.append(icon)

	# Item-namn (dold, behålls för kompatibilitet med _refresh_slot)
	var nlbl := Label.new()
	nlbl.visible = false
	vbox.add_child(nlbl)
	_slot_name_lbls.append(nlbl)

	# Tangent-label (liten, hörnet)
	var klbl := Label.new()
	klbl.add_theme_font_size_override("font_size", 8)
	klbl.add_theme_color_override("font_color", Color(0.75, 0.90, 1.00))
	klbl.add_theme_constant_override("outline_size", 1)
	klbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	klbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(klbl)
	_slot_key_lbls.append(klbl)

	# Cooldown-overlay ovanpå ikonen (full ruta, ignorerar mus).
	var cd := CooldownOverlay.new()
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell.add_child(cd)
	_slot_cooldowns.append(cd)
	_slot_cast_ids.append("")
	_slot_blink.append(0.0)

	_slot_nodes.append(cell)
	cell.gui_input.connect(func(ev): _on_slot_input(ev, idx, cell))
	# Ta emot item-drop → tilldela till slot
	var _ci := idx
	cell.set_drag_forwarding(
		func(_pos): return null,
		func(_pos, data) -> bool: return data is Dictionary and (data.has("item_id") or data.has("spell_id")),
		func(_pos, data):
			if data.has("spell_id"):
				var sid := String(data.get("spell_id", ""))
				if sid.is_empty(): return
				_slots[_ci]["spell_id"] = sid
				_slots[_ci]["item_id"]  = ""    # spell ersätter item i sloten
			else:
				var iid := String(data.get("item_id", ""))
				if iid.is_empty(): return
				_slots[_ci]["item_id"]  = iid
				_slots[_ci]["spell_id"] = ""    # item ersätter spell i sloten
			_save_config()
			_refresh_slot(_ci)
	)
	get_parent().add_child(cell)

# ─────────────────────────────────────────────
func _on_slot_input(ev: InputEvent, idx: int, node: Control) -> void:
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					_drag_slot   = idx
					_drag_start  = ev.global_position
					_drag_offset = node.global_position - ev.global_position
					_drag_moved  = false
				else:
					if not _drag_moved:
						_use_slot(idx)      # kort klick → använd
					else:
						# Drag avslutad → spara position
						_slots[idx]["pos_x"] = node.position.x
						_slots[idx]["pos_y"] = node.position.y
						_save_config()
						_set_border(node, Color(0.55, 0.55, 0.70, 0.55))
					_drag_slot  = -1
					_drag_moved = false
			MOUSE_BUTTON_RIGHT:
				if ev.pressed:
					_open_config(idx)
	elif ev is InputEventMouseMotion and _drag_slot == idx:
		if not _drag_moved and ev.global_position.distance_to(_drag_start) > DRAG_THRESHOLD:
			_drag_moved = true
			_set_border(node, Color(0.90, 0.70, 0.20))  # gul kant under drag
		if _drag_moved:
			node.global_position = ev.global_position + _drag_offset

func _set_border(node: Control, col: Color) -> void:
	var sb: StyleBox = node.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.border_color = col

# ─────────────────────────────────────────────
func _use_slot(idx: int) -> void:
	# Spell-slot → kasta via magisystemet.
	var spell_id: String = String(_slots[idx].get("spell_id", ""))
	if spell_id != "":
		_cast_via_caster(spell_id)
		return
	var item_id: String = String(_slots[idx].get("item_id", ""))
	if item_id.is_empty():
		return
	# Runor kastas via magisystemet (kan kräva sikte), inte via use_item.
	if not SpellSystem.cast_def(item_id).is_empty():
		_cast_via_caster(item_id)
		return
	if not GameState.use_item(item_id):
		World.hud.show_message("Kan inte använda: %s" % item_id)

func _cast_via_caster(id: String) -> void:
	if caster != null and is_instance_valid(caster):
		caster.cast_spell(id)
	elif World.player and is_instance_valid(World.player):
		World.player.cast_spell(id)

# ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _wait_key and _popup != null and _popup.visible:
		var kname := OS.get_keycode_string(event.keycode)
		if kname.is_empty():
			kname = "K%d" % event.keycode
		_pending_kname = kname
		_pending_kcode = int(event.keycode)
		_cfg_key_btn.text = kname
		_wait_key = false
		get_viewport().set_input_as_handled()
		return
	for i in SLOT_COUNT:
		if int(_slots[i].get("keycode", 0)) == int(event.keycode):
			# Konsumera bara om sloten har item ELLER spell — annars låt HUD-tangenter gå igenom
			var has_content := String(_slots[i].get("item_id", "")) != "" \
				or String(_slots[i].get("spell_id", "")) != ""
			if has_content:
				_use_slot(i)
				get_viewport().set_input_as_handled()
			return

# ─────────────────────────────────────────────
func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.z_index = 200

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.97)
	sb.border_color = Color(0.50, 0.50, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left   = 8.0
	sb.content_margin_right  = 8.0
	sb.content_margin_top    = 8.0
	sb.content_margin_bottom = 8.0
	_popup.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 320)
	vbox.add_theme_constant_override("separation", 6)
	_popup.add_child(vbox)

	var title := Label.new()
	title.text = "Konfigurera ruta"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var item_lbl := Label.new()
	item_lbl.text = "Välj föremål:"
	item_lbl.add_theme_font_size_override("font_size", 10)
	item_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	vbox.add_child(item_lbl)

	_cfg_item_lst = ItemList.new()
	_cfg_item_lst.custom_minimum_size = Vector2(0, 155)
	_cfg_item_lst.select_mode = ItemList.SELECT_SINGLE
	_cfg_item_lst.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_cfg_item_lst)

	var key_row := HBoxContainer.new()
	vbox.add_child(key_row)
	var key_lbl := Label.new()
	key_lbl.text = "Tangent:"
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(key_lbl)
	_cfg_key_btn = Button.new()
	_cfg_key_btn.custom_minimum_size = Vector2(80, 0)
	_cfg_key_btn.add_theme_font_size_override("font_size", 11)
	_cfg_key_btn.pressed.connect(func(): _wait_key = true; _cfg_key_btn.text = "Tryck tangent...")
	key_row.add_child(_cfg_key_btn)

	var hint := Label.new()
	hint.text = "Klicka Tangent-knappen och tryck sedan valfri tangent"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)
	for cfg in [["Töm", _on_clear], ["OK", _on_ok], ["Avbryt", func(): _popup.visible = false]]:
		var b := Button.new()
		b.text = cfg[0]
		b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(cfg[1])
		btn_row.add_child(b)

	get_parent().add_child(_popup)

func _open_config(idx: int) -> void:
	_cfg_idx = idx
	_wait_key = false
	_pending_kname = String(_slots[idx].get("key_name", ""))
	_pending_kcode = int(_slots[idx].get("keycode", 0))

	_cfg_item_lst.clear()
	_cfg_item_lst.add_item("— Ingen —")
	var current_id: String = String(_slots[idx].get("item_id", ""))
	var sel := 0
	var row := 1
	for id in GameState.inventory:
		var d: Dictionary = ItemDB.items.get(id, {})
		if d.is_empty(): continue
		var qty := int(GameState.inventory[id])
		_cfg_item_lst.add_item("%s  x%d" % [String(d.get("name", id)), qty])
		_cfg_item_lst.set_item_metadata(row, id)
		if id == current_id: sel = row
		row += 1
	_cfg_item_lst.select(sel)
	_cfg_key_btn.text = _pending_kname if _pending_kname != "" else "—"
	_popup.visible = true
	var vp := get_viewport().get_visible_rect().size
	_popup.position = (vp - _popup.size) * 0.5

func _on_ok() -> void:
	if _cfg_idx < 0: return
	var sel := _cfg_item_lst.get_selected_items()
	var item_id := ""
	if sel.size() > 0 and sel[0] > 0:
		item_id = String(_cfg_item_lst.get_item_metadata(sel[0]))
	_slots[_cfg_idx]["item_id"]  = item_id
	if item_id != "":
		_slots[_cfg_idx]["spell_id"] = ""    # valt item ersätter ev. spell
	_slots[_cfg_idx]["key_name"] = _pending_kname
	_slots[_cfg_idx]["keycode"]  = _pending_kcode
	_popup.visible = false
	_refresh_slot(_cfg_idx)
	_save_config()

func _on_clear() -> void:
	if _cfg_idx >= 0:
		_slots[_cfg_idx]["item_id"]  = ""
		_slots[_cfg_idx]["spell_id"] = ""
	_popup.visible = false
	_refresh_slot(_cfg_idx)
	_save_config()

# ─────────────────────────────────────────────
const _DIM        := Color(0.5, 0.5, 0.58, 0.6)   # gråton för "har inte råd"
const _BLINK_TIME := 0.28                          # blixt-längd (s)
const _BLINK_COL  := Color(1.7, 1.7, 1.7, 1.0)     # additiv ljusning vid cast

## Pollar cooldown & affordability per spell/rune-slot; driver overlay, graying
## och cast-blixt.
func _process(delta: float) -> void:
	for i in _slot_cooldowns.size():
		var id := String(_slot_cast_ids[i])
		if id == "":
			_slot_cooldowns[i].set_cooldown(0.0, 1.0)
			continue
		var left := SpellSystem.cooldown_left(id)
		# _cd_total bygger en rune-def — undvik det utom när sloten faktiskt laddar.
		_slot_cooldowns[i].set_cooldown(left, _cd_total(id) if left > 0.0 else 1.0)
		var base: Color = Color.WHITE if SpellSystem.affordable(id) else _DIM
		if _slot_blink[i] > 0.0:
			_slot_blink[i] = maxf(_slot_blink[i] - delta, 0.0)
			_slot_icons[i].modulate = base.lerp(_BLINK_COL, _slot_blink[i] / _BLINK_TIME)
		else:
			_slot_icons[i].modulate = base

## Full cooldown-längd för ett spell-/rune-id (för wedge-andelen).
func _cd_total(id: String) -> float:
	if SpellSystem.spells.has(id):
		return float(SpellSystem.spells[id].get("cooldown", 1.0))
	return float(SpellSystem.cast_def(id).get("cooldown", 1.0))

func _refresh_all() -> void:
	for i in SLOT_COUNT:
		_refresh_slot(i)

func _refresh_slot(idx: int) -> void:
	if idx >= _slot_icons.size(): return
	var slot: Dictionary = _slots[idx]
	var icon: TextureRect = _slot_icons[idx]
	var nlbl: Label = _slot_name_lbls[idx]
	var spell_id: String = String(slot.get("spell_id", ""))
	var item_id: String = String(slot.get("item_id", ""))
	icon.texture = null
	icon.modulate = Color.WHITE
	nlbl.visible = false
	var cell: Control = _slot_nodes[idx]
	cell.tooltip_text = ""
	_slot_cast_ids[idx] = ""
	if spell_id != "":
		var ssp := "res://assets/sprites/spells/%s.png" % spell_id
		if ResourceLoader.exists(ssp):
			icon.texture = load(ssp)
		else:
			# Ingen sprite → procedurell element-ikon (samma som spellbok).
			icon.texture = SpellIcons.texture(spell_id, SpellSystem.spells.get(spell_id, {}))
		cell.tooltip_text = _spell_tooltip(spell_id)
		_slot_cast_ids[idx] = spell_id
	elif item_id != "":
		icon.texture = ItemIcons.texture(item_id)
		cell.tooltip_text = String(ItemDB.items.get(item_id, {}).get("name", item_id))
		# Bara runor gråtonas av mana/krav — vanliga items (drycker) lämnas vita.
		if not SpellSystem.cast_def(item_id).is_empty():
			_slot_cast_ids[idx] = item_id
	_slot_key_lbls[idx].text = String(slot.get("key_name", ""))

## Tooltip för en bunden besvärjelse: namn, ord, mana, magic-krav, cooldown.
func _spell_tooltip(spell_id: String) -> String:
	var d: Dictionary = SpellSystem.spells.get(spell_id, {})
	if d.is_empty():
		return spell_id
	var lines := PackedStringArray()
	lines.append(String(d.get("name", spell_id)))
	var words := String(d.get("words", ""))
	if words != "":
		lines.append("“%s”" % words)
	lines.append("Mana: %d · Magic %d" % [int(d.get("mana_cost", 0)), int(d.get("magic_lvl", 1))])
	var cd := float(d.get("cooldown", 0.0))
	if cd > 0.0:
		lines.append("Cooldown: %ss" % String.num(cd, 1))
	return "\n".join(lines)
