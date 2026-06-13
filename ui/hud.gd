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
var task_panel: PanelContainer
var bestiary_panel: PanelContainer
var dialogue_box: PanelContainer
var quest_log: PanelContainer
var wardrobe: PanelContainer
var equipment_panel: PanelContainer
var _msg_timer := 0.0
var _qs_rune_lbl: Label   # visar aktiv runa + qty i quickslot
var _qs_pot_lbl: Label    # visar health_potion qty i quickslot
var _poison_lbl: Label    # "Giftig!"-chip

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
	task_panel = preload("res://ui/task_panel.gd").new()
	add_child(task_panel)
	bestiary_panel = preload("res://ui/bestiary_panel.gd").new()
	add_child(bestiary_panel)
	dialogue_box = preload("res://ui/dialogue_box.gd").new()
	add_child(dialogue_box)
	quest_log = preload("res://ui/quest_log.gd").new()
	add_child(quest_log)
	wardrobe = preload("res://ui/wardrobe.gd").new()
	add_child(wardrobe)
	equipment_panel = preload("res://ui/equipment_panel.gd").new()
	add_child(equipment_panel)
	QuestSystem.quest_started.connect(func(_id): _refresh_quests())
	QuestSystem.quest_progress.connect(func(_id): _refresh_quests())
	QuestSystem.step_advanced.connect(func(_id): _refresh_quests())
	QuestSystem.quest_completed.connect(func(id):
		_refresh_quests()
		show_message("Quest klar: %s!" % QuestSystem.quests[id]["name"]))
	add_child(preload("res://ui/debug_console.gd").new())
	add_child(preload("res://ui/death_screen.gd").new())
	_build_quickslots()
	TaskSystem.task_taken.connect(func(_id): _refresh_tasks())
	TaskSystem.task_progress.connect(func(_id): _refresh_tasks())
	TaskSystem.task_completed.connect(func(_id): _refresh_tasks())
	UnlockSystem.unlock_added.connect(func(id): show_message("%s har öppnats!" % UnlockSystem.display_name(id)))
	GameState.hp_changed.connect(func(_h, _m): _refresh())
	GameState.mana_changed.connect(func(_v, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.skill_changed.connect(func(_s): _refresh())
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.inventory_changed.connect(_refresh_quickslots)
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

func open_tasks() -> void:
	recipe_panel.visible = false
	shop_panel.visible = false
	task_panel.open()

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
			# Vapentyp/rustning/sköld — utrusta i korrekt slot
			var slot := String(d["slot"])
			inv_list.add_child(_inv_row(id, qty, "Utrusta", func(): GameState.equip(slot, id)))
		elif d.has("heal") or d.has("mana") or d.has("buff") or d.get("usable", false):
			inv_list.add_child(_inv_row(id, qty, "Använd", func(): GameState.use_item(id)))
		else:
			inv_list.add_child(_inv_row(id, qty, "", Callable()))

func _inv_row(id: String, qty: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "%s x%d" % [ItemDB.items.get(id, {}).get("name", id), qty]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
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
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		recipe_panel.visible = false
		shop_panel.visible = false
		task_panel.visible = false
		bestiary_panel.visible = false
		dialogue_box.close()
		quest_