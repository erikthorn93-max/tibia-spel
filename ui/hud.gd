extends CanvasLayer

@onready var hp_bar: ColorRect = $HpBar
@onready var mana_bar: ColorRect = $ManaBar
@onready var stats: Label = $StatsLabel
@onready var buffs_lbl: Label = $BuffsLabel
@onready var tasks_lbl: Label = $TasksLabel
@onready var quests_lbl: Label = $QuestsLabel
@onready var msg_lbl: Label = $MessageLabel
@onready var inv_panel: PanelContainer = $InventoryPanel
@onready var inv_list: VBoxContainer = $InventoryPanel/InvScroll/InvList
@onready var death_lbl: Label = $DeathLabel

var skill_panel: PanelContainer
var recipe_panel: PanelContainer
var shop_panel: PanelContainer
var bank_panel: PanelContainer
var prayer_panel: PanelContainer
var task_panel: PanelContainer
var bestiary_panel: PanelContainer
var spellbook_panel: PanelContainer
var dialogue_box: PanelContainer
var quest_log: PanelContainer
var wardrobe: PanelContainer
var equipment_panel: PanelContainer
var hotkey_bar: Node
var _msg_timer := 0.0
var _night_overlay: ColorRect  # dag/natt-mörkläggning
var _clock_lbl: Label          # spelklocka HH:MM
var _poison_lbl: Label    # "Giftig!"-chip
var _boss_panel: PanelContainer  # boss HP-bar, synlig under bossfight
var _boss_name_lbl: Label
var _boss_hp_bar: ColorRect
var _boss_hp_bg: ColorRect
# ANIMATIONER
var _levelup_lbl: Label        # "★ LEVEL UP!" popup
var _skillup_lbl: Label        # "+Skill nivå X" popup
var _prev_hp := 150.0          # för att detektera riktning av HP-förändring
var _prev_skill_levels: Dictionary = {}  # skill -> nivå (för level-up-detektion)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # måste fungera när trädet pausas vid död
	World.hud = self
	skill_panel = preload("res://ui/skill_panel.gd").new()
	skill_panel.offset_left = 940.0
	skill_panel.offset_top = 16.0
	add_child(skill_panel)
	recipe_panel = preload("res://ui/recipe_panel.gd").new()
	add_child(recipe_panel)
	shop_panel = preload("res://ui/shop_panel.gd").new()
	add_child(shop_panel)
	bank_panel = preload("res://ui/bank_panel.gd").new()
	add_child(bank_panel)
	prayer_panel = preload("res://ui/prayer_panel.gd").new()
	add_child(prayer_panel)
	task_panel = preload("res://ui/task_panel.gd").new()
	add_child(task_panel)
	bestiary_panel = preload("res://ui/bestiary_panel.gd").new()
	add_child(bestiary_panel)
	spellbook_panel = preload("res://ui/spellbook_panel.gd").new()
	add_child(spellbook_panel)
	dialogue_box = preload("res://ui/dialogue_box.gd").new()
	add_child(dialogue_box)
	quest_log = preload("res://ui/quest_log.gd").new()
	add_child(quest_log)
	wardrobe = preload("res://ui/wardrobe.gd").new()
	add_child(wardrobe)
	equipment_panel = preload("res://ui/equipment_panel.gd").new()
	add_child(equipment_panel)
	hotkey_bar = preload("res://ui/hotkey_bar.gd").new()
	add_child(hotkey_bar)
	var _wdz := preload("res://ui/world_drop_zone.gd").new()
	add_child(_wdz)
	move_child(_wdz, 0)   # bakom allt
	QuestSystem.quest_started.connect(func(_id): _refresh_quests())
	QuestSystem.quest_progress.connect(func(_id): _refresh_quests())
	QuestSystem.step_advanced.connect(func(_id): _refresh_quests())
	QuestSystem.quest_completed.connect(func(id):
		_refresh_quests()
		show_message("Quest klar: %s!" % QuestSystem.quests[id]["name"]))
	add_child(preload("res://ui/minimap.gd").new())
	add_child(preload("res://ui/debug_console.gd").new())
	add_child(preload("res://ui/death_screen.gd").new())
	_build_boss_bar()
	_build_night_overlay()
	_build_levelup_labels()
	TimeOfDay.hour_changed.connect(_on_hour_changed)
	GameState.equipment_changed.connect(_update_night_overlay)   # ljuskälla på/av
	TaskSystem.task_taken.connect(func(_id): _refresh_tasks())
	TaskSystem.task_progress.connect(func(_id): _refresh_tasks())
	TaskSystem.task_completed.connect(func(_id): _refresh_tasks())
	UnlockSystem.unlock_added.connect(func(id): show_message("%s har öppnats!" % UnlockSystem.display_name(id)))
	GameState.hp_changed.connect(func(h, m): _refresh(); _on_hp_changed_anim(h, m))
	GameState.mana_changed.connect(func(_v, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.skill_changed.connect(func(s): _refresh(); _on_skill_changed_anim(s))
	GameState.level_up.connect(_on_level_up_anim)
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.inventory_changed.connect(func(): if hotkey_bar: hotkey_bar._refresh_all())
	GameState.status_changed.connect(_refresh_status)
	_build_status_chips()
	GameState.buffs_changed.connect(_refresh_buffs)
	GameState.player_died.connect(_on_death)
	_refresh()
	_refresh_inv()
	_refresh_buffs()
	_refresh_tasks()
	_refresh_quests()

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			msg_lbl.visible = false
	if not GameState.active_buffs.is_empty():
		_refresh_buffs()   # nedräkning
	_refresh_boss_bar()
	_update_night_overlay()

func show_message(text: String) -> void:
	msg_lbl.text = text
	msg_lbl.visible = true
	_msg_timer = 2.5

func open_recipes(station_type: String) -> void:
	shop_panel.visible = false
	recipe_panel.open(station_type)

func open_shop() -> void:
	recipe_panel.visible = false
	task_panel.visible = false
	shop_panel.open()

func open_bank() -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.visible = false
	bank_panel.open()

func open_prayer_altar() -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.visible = false
	bank_panel.visible = false
	prayer_panel.open()

func open_tasks() -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.open()

func open_spellbook(learn_mode := false) -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.visible = false
	spellbook_panel.open(learn_mode)

func open_dialogue(npc_id: String) -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.visible = false
	dialogue_box.open(npc_id)

func _refresh_tasks() -> void:
	var parts: Array = []
	for id in TaskSystem.active:
		var def: Dictionary = TaskSystem.tasks[id]
		parts.append("%s %d/%d" % [def["monster"], int(TaskSystem.active[id]), int(def["required"])])
	tasks_lbl.text = " · ".join(parts)

func _refresh() -> void:
	hp_bar.size.x = 200.0 * (GameState.health / GameState.max_health)
	mana_bar.size.x = 200.0 * (GameState.mana / GameState.max_mana)
	var wskill := GameState.weapon_skill()
	stats.text = "Lv %d  XP %d/%d  Guld %d  %s %d" % [
		GameState.level, GameState.experience, GameState.xp_to_next, GameState.gold,
		GameState.skill_defs[wskill]["name"], GameState.effective_skill_level(wskill)]
func _refresh_buffs() -> void:
	var parts: Array = []
	for b in GameState.active_buffs:
		parts.append("%s +%d (%ds)" % [String(b["stat"]).trim_prefix("skill:"), int(b["amount"]), int(ceil(b["time_left"]))])
	buffs_lbl.text = "  ".join(parts)

func _refresh_quests() -> void:
	if QuestSystem.active.is_empty():
		quests_lbl.text = ""
		return
	var id: String = QuestSystem.active.keys().back()   # senast startade
	quests_lbl.text = "%s — %s" % [QuestSystem.quests[id]["name"], QuestSystem.hint(id)]

func _refresh_inv() -> void:
	for c in inv_list.get_children():
		c.queue_free()
	for id in GameState.inventory:
		var d: Dictionary = ItemDB.items.get(id, {})
		if d.is_empty():
			continue
		var qty := int(GameState.inventory[id])
		if d.has("slot"):
			var slot := String(d["slot"])
			inv_list.add_child(_inv_row(id, qty, "Utrusta", func(): GameState.equip(slot, id)))
		elif d.has("heal") or d.has("mana") or d.has("buff") or d.get("usable", false):
			inv_list.add_child(_inv_row(id, qty, "Använd", func(): GameState.use_item(id)))
		else:
			inv_list.add_child(_inv_row(id, qty, "", Callable()))

func _load_item_sprite(item_id: String) -> Texture2D:
	var path := "res://assets/sprites/items/%s.png" % item_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _make_drag_preview(item_id: String) -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(40, 40)
	var t := TextureRect.new()
	t.texture = _load_item_sprite(item_id)
	t.custom_minimum_size = Vector2(40, 40)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(t)
	return p

func _inv_row(id: String, qty: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var _row_id := id
	row.mouse_entered.connect(func():
		ItemTooltip.show_for(_row_id, row.get_global_rect().position + Vector2(row.size.x + 4, 0)))
	row.mouse_exited.connect(func(): ItemTooltip.hide_tooltip())
	# Sprite (drag-källa)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(36, 36)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = _load_item_sprite(id)
	tex.mouse_filter = Control.MOUSE_FILTER_STOP
	var _id := id; var _qty := qty
	tex.set_drag_forwarding(
		func(_pos: Vector2):
			tex.set_drag_preview(_make_drag_preview(_id))
			return {"item_id": _id, "qty": _qty, "source": "inventory"},
		func(_pos, _data) -> bool: return false,
		func(_pos, _data): pass
	)
	row.add_child(tex)
	# Namn + antal
	var lbl := Label.new()
	var d: Dictionary = ItemDB.items.get(id, {})
	lbl.text = "%s  x%d" % [String(d.get("name", id)), qty]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	if action != "":
		var btn := Button.new()
		btn.text = action
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(cb)
		row.add_child(btn)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inv_panel.visible = not inv_panel.visible
	elif event.is_action_pressed("toggle_skills"):
		skill_panel.visible = not skill_panel.visible
	elif event.is_action_pressed("toggle_bestiary"):
		bestiary_panel.toggle()
	elif event.is_action_pressed("hotkey_1"):
		if not GameState.use_item("health_potion"):
			show_message("Ingen hälsodryck.")
	elif event.is_action_pressed("toggle_quest_log"):
		quest_log.toggle()
	elif event.is_action_pressed("toggle_wardrobe"):
		wardrobe.toggle()
	elif event.is_action_pressed("toggle_equipment"):
		equipment_panel.toggle()
	elif event.is_action_pressed("toggle_spellbook"):
		spellbook_panel.toggle()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		recipe_panel.visible = false
		shop_panel.visible = false
		task_panel.visible = false
		bestiary_panel.visible = false
		dialogue_box.close()
		quest_log.visible = false
		wardrobe.visible = false
		equipment_panel.visible = false
		spellbook_panel.visible = false

## Bygger gift/stun-status chip (övre högra hörnet)
func _build_status_chips() -> void:
	_poison_lbl = Label.new()
	_poison_lbl.text = "☠ Giftig!"
	_poison_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	_poison_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_poison_lbl.offset_left   = -160.0
	_poison_lbl.offset_top    =   80.0
	_poison_lbl.offset_right  =   -8.0
	_poison_lbl.offset_bottom =  100.0
	_poison_lbl.visible = false
	add_child(_poison_lbl)

func _refresh_status() -> void:
	if _poison_lbl:
		_poison_lbl.visible = GameState.has_status("poison")

func _on_death() -> void:
	pass   # DeathScreen hanterar sin egen synlighet via player_died-signalen

## Bygger boss HP-bar längst ner i mitten — dold tills target är en boss
func _build_night_overlay() -> void:
	_night_overlay = ColorRect.new()
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_overlay.color = Color(0.02, 0.04, 0.18, 0.0)
	add_child(_night_overlay)
	move_child(_night_overlay, 1)   # precis ovanför world_drop_zone
	_clock_lbl = Label.new()
	_clock_lbl.add_theme_font_size_override("font_size", 11)
	_clock_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.62))
	_clock_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_lbl.offset_left = -120.0
	_clock_lbl.offset_top  = 130.0
	_clock_lbl.offset_right = -6.0
	_clock_lbl.offset_bottom = 148.0
	_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock_lbl)
	_update_night_overlay()

func _on_hour_changed(_h: int) -> void:
	_update_night_overlay()

func _update_night_overlay() -> void:
	if _night_overlay == null or _clock_lbl == null:
		return
	var h := TimeOfDay.hour
	var frac := TimeOfDay.day_fraction   # 0.0–1.0
	# Beräkna alpha: max mörkhet 0.52 klockan 00:00, 0.0 klockan 12:00
	# Sinuskurva: mörkt 22:00–06:00, ljust 08:00–20:00
	var angle := frac * TAU   # 0 = midnatt, PI = middag
	var raw_alpha := (-cos(angle) + 1.0) * 0.5   # 0..1, topp vid midnatt
	var alpha := raw_alpha * 0.52
	# Utrustad ljuskälla (fackla/lykta) lättar upp mörkret runt spelaren.
	alpha *= clampf(1.0 - GameState.light_level(), 0.15, 1.0)
	_night_overlay.color = Color(0.02, 0.04, 0.18, alpha)
	# Klocka + ikon
	var icon := "☀" if not TimeOfDay.is_night else "🌙"
	_clock_lbl.text = "%s %02d:00" % [icon, h]

func _build_boss_bar() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_panel.offset_left   =  300.0
	_boss_panel.offset_right  = -300.0
	_boss_panel.offset_top    =  -70.0
	_boss_panel.offset_bottom =   -8.0
	_boss_panel.visible = false
	add_child(_boss_panel)
	var vbox := VBoxContainer.new()
	_boss_panel.add_child(vbox)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_boss_name_lbl)
	_boss_hp_bg = ColorRect.new()
	_boss_hp_bg.color = Color(0.15, 0.05, 0.05)
	_boss_hp_bg.custom_minimum_size = Vector2(0.0, 14.0)
	vbox.add_child(_boss_hp_bg)
	_boss_hp_bar = ColorRect.new()
	_boss_hp_bar.color = Color(0.85, 0.1, 0.1)
	_boss_hp_bar.anchor_left   = 0.0
	_boss_hp_bar.anchor_top    = 0.0
	_boss_hp_bar.anchor_bottom = 1.0
	_boss_hp_bar.anchor_right  = 1.0
	_boss_hp_bg.add_child(_boss_hp_bar)

func _refresh_boss_bar() -> void:
	if _boss_panel == null:
		return
	var p: Node2D = World.player
	if p == null or not is_instance_valid(p):
		_boss_panel.visible = false
		return
	var t = p.target
	if t == null or not is_instance_valid(t) or bool(t.get("dead")):
		_boss_panel.visible = false
		return
	var mname: String = String(t.get("monster_name") if t.get("monster_name") != null else "")
	var mdata: Dictionary = MonsterDB.monsters.get(mname, {})
	if not bool(mdata.get("boss", false)):
		_boss_panel.visible = false
		return
	_boss_panel.visible = true
	var hp     := float(t.get("hp")     if t.get("hp")     != null else 0)
	var max_hp := float(t.get("max_hp") if t.get("max_hp") != null else 1)
	var ratio  := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_boss_name_lbl.text    = "%s   %d / %d" % [mname, int(hp), int(max_hp)]
	_boss_hp_bar.anchor_right = ratio

## Bygger level-up och skill-up popup-labels
func _build_levelup_labels() -> void:
	_levelup_lbl = Label.new()
	_levelup_lbl.text = "★ LEVEL UP!"
	_levelup_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_levelup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_levelup_lbl.visible = false
	add_child(_levelup_lbl)
	_skillup_lbl = Label.new()
	_skillup_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_skillup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skillup_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_skillup_lbl.visible = false
	add_child(_skillup_lbl)
	_prev_skill_levels = GameState.skills.duplicate()

func _on_hp_changed_anim(h: float, _m: float) -> void:
	_prev_hp = h

func _on_skill_changed_anim(s: String) -> void:
	var cur := GameState.effective_skill_level(s)
	var prev := int(_prev_skill_levels.get(s, {}).get("level", 0)) if typeof(_prev_skill_levels.get(s)) == TYPE_DICTIONARY else int(_prev_skill_levels.get(s, 0))
	if cur > prev and _skillup_lbl != null:
		_skillup_lbl.text = "+%s nivå %d" % [s.capitalize(), cur]
		_skillup_lbl.visible = true
		var tw := create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(func(): _skillup_lbl.visible = false)
	_prev_skill_levels = GameState.skills.duplicate()

func _on_level_up_anim() -> void:
	if _levelup_lbl == null:
		return
	_levelup_lbl.visible = true
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): _levelup_lbl.visible = false)
