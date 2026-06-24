extends CanvasLayer

const Atmosphere = preload("res://ui/atmosphere.gd")
const Biome = preload("res://ui/biome.gd")

var hp_bar: Panel       # fyllnad (anchor_right driver nivån) — byggs i _build_bars()
var mana_bar: Panel
var _hp_val: Label
var _mana_val: Label
var _hp_pulse_t := 0.0
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
var _vignette: TextureRect     # mjuk kantmörkläggning (filmisk inramning)
var _light_glow: TextureRect   # varmt fackelsken runt spelaren (skärmens mitt)
var _weather_overlay: Control  # regn/snö/dimma per zon
var _ambient_overlay: Control  # eldflugor/damm/glödflagor per biom
var _biome_overlay: ColorRect  # biom-färggradering (stämningston per platstyp)
var _glow_t := 0.0             # tidsackumulator för fackelskenets flimmer
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
		Sfx.quest_done()
		show_message("Quest klar: %s!" % QuestSystem.quests[id]["name"]))
	add_child(preload("res://ui/minimap.gd").new())
	add_child(preload("res://ui/debug_console.gd").new())
	add_child(preload("res://ui/death_screen.gd").new())
	_build_bars()
	_build_boss_bar()
	_build_night_overlay()
	_build_weather_overlay()
	_build_levelup_labels()
	TimeOfDay.hour_changed.connect(_on_hour_changed)
	GameState.equipment_changed.connect(_update_night_overlay)   # ljuskälla på/av
	TaskSystem.task_taken.connect(func(_id): _refresh_tasks())
	TaskSystem.task_progress.connect(func(_id): _refresh_tasks())
	TaskSystem.task_completed.connect(func(_id): _refresh_tasks())
	UnlockSystem.unlock_added.connect(func(id):
		Sfx.unlock()
		show_message("%s har öppnats!" % UnlockSystem.display_name(id)))
	GameState.hp_changed.connect(func(h, m): _refresh(); _on_hp_changed_anim(h, m))
	GameState.mana_changed.connect(func(_v, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.skill_changed.connect(func(_s): _refresh())
	GameState.skill_leveled.connect(_on_skill_leveled)
	GameState.crafted.connect(_on_crafted)
	GameState.item_used.connect(_on_item_used)
	GameState.level_up.connect(_on_level_up_anim)
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.inventory_changed.connect(func(): if hotkey_bar: hotkey_bar._refresh_all())
	GameState.status_changed.connect(_refresh_status)
	_build_status_chips()
	GameState.buffs_changed.connect(_refresh_buffs)
	GameState.player_died.connect(_on_death)
	_build_fade_overlay()   # sist → överst, täcker hela HUD vid zon-fade
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
	_glow_t += delta
	_update_night_overlay()
	# Kritiskt låg HP: fyllningen pulserar varnande
	if hp_bar:
		var crit := GameState.max_health > 0.0 and (GameState.health / GameState.max_health) < 0.3
		if crit:
			_hp_pulse_t += delta * 6.0
			var g := 0.75 + 0.25 * sin(_hp_pulse_t)
			hp_bar.self_modulate = Color(1.0, g, g)
		elif hp_bar.self_modulate != Color.WHITE:
			hp_bar.self_modulate = Color.WHITE

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
	var hp_ratio := clampf(GameState.health / GameState.max_health, 0.0, 1.0)
	var mp_ratio := clampf(GameState.mana / GameState.max_mana, 0.0, 1.0)
	if hp_bar:
		hp_bar.anchor_right = hp_ratio
		_hp_val.text = "%d / %d" % [roundi(GameState.health), roundi(GameState.max_health)]
	if mana_bar:
		mana_bar.anchor_right = mp_ratio
		_mana_val.text = "%d / %d" % [roundi(GameState.mana), roundi(GameState.max_mana)]
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
	return ItemIcons.texture(item_id)

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
var _fade_rect: ColorRect   # svart heltäckande overlay för zon-övergångar

func _build_fade_overlay() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0.0)
	add_child(_fade_rect)   # läggs sist → ritas överst

## Zon-övergång: tona till svart, kör om-byggnaden, tona tillbaka in.
func transition(rebuild: Callable) -> void:
	if _fade_rect == null:
		rebuild.call_deferred()
		return
	_fade_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	tw.tween_callback(rebuild)
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.28)

func _build_night_overlay() -> void:
	# Biom-färggradering: subtil stämningston för platstypen, under allt annat
	# atmosfär-lager så den tonar marken innan natt/vinjett läggs på.
	_biome_overlay = ColorRect.new()
	_biome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_biome_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_overlay.color = Color(0, 0, 0, 0.0)
	add_child(_biome_overlay)
	move_child(_biome_overlay, 1)   # precis ovanför world_drop_zone
	_night_overlay = ColorRect.new()
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_overlay.color = Color(0.02, 0.04, 0.18, 0.0)
	add_child(_night_overlay)
	move_child(_night_overlay, 2)
	# Vinjett: mjuk kantmörkläggning ovanpå dygns-tonen, under HUD-widgets.
	_vignette = TextureRect.new()
	_vignette.texture = Atmosphere.make_vignette(256, 144)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	move_child(_vignette, 3)
	# Fackelsken: additivt, centrerat på spelaren (kameran centrerar honom).
	_light_glow = TextureRect.new()
	_light_glow.texture = Atmosphere.make_light_glow(384)
	_light_glow.set_anchors_preset(Control.PRESET_CENTER)
	_light_glow.pivot_offset = Vector2(192, 192)
	_light_glow.position = -_light_glow.pivot_offset
	_light_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light_glow.material = glow_mat
	_light_glow.modulate.a = 0.0
	add_child(_light_glow)
	move_child(_light_glow, 4)
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

func _build_weather_overlay() -> void:
	_weather_overlay = preload("res://ui/weather_overlay.gd").new()
	add_child(_weather_overlay)
	# Ovanför dag/natt-atmosfären (glow ligger på index 4) men under panelerna.
	move_child(_weather_overlay, 5)
	_ambient_overlay = preload("res://ui/ambient_overlay.gd").new()
	add_child(_ambient_overlay)
	move_child(_ambient_overlay, 6)

func _on_hour_changed(_h: int) -> void:
	_update_night_overlay()

func _update_night_overlay() -> void:
	if _night_overlay == null or _clock_lbl == null:
		return
	var h := TimeOfDay.hour
	var frac := TimeOfDay.day_fraction   # 0.0 = midnatt, 0.5 = middag
	# Dygnsfärgning: varm gryning/skymning, sval natt, klar middag.
	var sky := Atmosphere.overlay_color(frac)
	# Utrustad ljuskälla (fackla/lykta) lättar upp mörkret runt spelaren.
	var light_factor := clampf(1.0 - GameState.light_level(), 0.15, 1.0)
	_night_overlay.color = Color(sky.r, sky.g, sky.b, sky.a * light_factor)
	# Vinjetten följer dygnet (mörkare hörn på natten) och ljuskällan.
	if _vignette:
		_vignette.modulate.a = Atmosphere.vignette_strength(frac) * light_factor
	# Lokalt fackelsken: lyser bara upp när det är mörkt och spelaren bär ljus.
	# Ett organiskt flimmer ovanpå gör lågan levande istället för en platt cirkel.
	if _light_glow:
		var glow := Atmosphere.glow_strength(GameState.light_level(), frac)
		_light_glow.modulate.a = glow * Atmosphere.flicker(_glow_t)
	# Biom-färggradering: stämningston för den aktuella platstypen.
	if _biome_overlay:
		var zid: String = World.current_zone.zone_id if World.current_zone != null \
			and is_instance_valid(World.current_zone) and "zone_id" in World.current_zone else ""
		_biome_overlay.color = Biome.grade(Biome.classify(zid))
	# Klocka + ikon
	var icon := "☀" if not TimeOfDay.is_night else "🌙"
	_clock_lbl.text = "%s %02d:00" % [icon, h]

## Bygger uppfräschade HP/mana-barer: rundad ram med skugga, glansig fyllning
## (sheen-list upptill) och centrerat värde "X / Y". Fyllnadsgraden styrs av
## fyllnadens anchor_right i _refresh().
const _BAR_LEFT := 40.0   # plats för ikon till vänster
const _BAR_W := 200.0
const _BAR_H := 18.0

func _build_bars() -> void:
	_make_stat_icon(14.0, "hp")
	hp_bar = _make_bar(14.0,
		Color(0.86, 0.20, 0.20), Color(0.45, 0.10, 0.10, 0.95))   # rött + mörk kant
	_hp_val = _make_bar_label(14.0)
	_make_stat_icon(34.0, "mana")
	mana_bar = _make_bar(34.0,
		Color(0.26, 0.46, 0.96), Color(0.14, 0.20, 0.50, 0.95))   # blått + mörk kant
	_mana_val = _make_bar_label(34.0)

## Liten pixel-ikon (hjärta / mana-droppe) till vänster om en bar.
func _make_stat_icon(top: float, kind: String) -> void:
	var tr := TextureRect.new()
	tr.texture = _heart_texture() if kind == "hp" else _drop_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.offset_left = 13.0
	tr.offset_top = top - 1.0
	tr.offset_right = 35.0
	tr.offset_bottom = top + 19.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

## Bygger en 16×16-ikon ur en mask-funktion, med mörk kontur + ljus glansprick.
func _icon_tex(mask: Callable, fill: Color, outline: Color, hi: Color, hi_px: Array) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			if mask.call(x, y):
				img.set_pixel(x, y, fill)
	# Konturpass: tomma pixlar intill en fylld blir mörk kant
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var edge: Array = []
	for y in 16:
		for x in 16:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in dirs:
				var nx: int = int(x) + d.x
				var ny: int = int(y) + d.y
				if nx >= 0 and nx < 16 and ny >= 0 and ny < 16 and img.get_pixel(nx, ny).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixel(p.x, p.y, outline)
	for p in hi_px:
		if img.get_pixel(p.x, p.y).a > 0.0:
			img.set_pixel(p.x, p.y, hi)
	return ImageTexture.create_from_image(img)

func _heart_texture() -> ImageTexture:
	var mask := func(x: int, y: int) -> bool:
		var fx := float(x)
		var fy := float(y)
		var lobe := Vector2(fx, fy).distance_to(Vector2(4.5, 5.5)) <= 3.4 \
			or Vector2(fx, fy).distance_to(Vector2(10.5, 5.5)) <= 3.4
		var body := fy >= 5.0 and absf(fx - 7.5) <= (13.5 - fy) * 0.78
		return lobe or body
	return _icon_tex(mask, Color(0.90, 0.22, 0.22), Color(0.20, 0.03, 0.03),
		Color(1.0, 0.62, 0.62), [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)])

func _drop_texture() -> ImageTexture:
	var mask := func(x: int, y: int) -> bool:
		var fx := float(x)
		var fy := float(y)
		var bulb := Vector2(fx, fy).distance_to(Vector2(7.5, 10.0)) <= 4.3
		var tip := fy <= 10.0 and absf(fx - 7.5) <= maxf(0.0, fy - 1.0) * 0.46
		return bulb or tip
	return _icon_tex(mask, Color(0.30, 0.55, 1.0), Color(0.05, 0.12, 0.40),
		Color(0.72, 0.86, 1.0), [Vector2i(6, 7), Vector2i(6, 8), Vector2i(5, 8)])

## Skapar ram + fyllning + sheen. Returnerar fyllnads-panelen (driver nivån).
func _make_bar(top: float, fill_color: Color, border_color: Color) -> Panel:
	# --- rundad mörk ram med mjuk skugga ---
	var frame := Panel.new()
	frame.offset_left = _BAR_LEFT
	frame.offset_top = top
	frame.offset_right = _BAR_LEFT + _BAR_W
	frame.offset_bottom = top + _BAR_H
	frame.clip_contents = true
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.07, 0.06, 0.07, 0.92)
	fsb.set_corner_radius_all(6)
	fsb.set_border_width_all(1)
	fsb.border_color = border_color
	fsb.shadow_color = Color(0, 0, 0, 0.45)
	fsb.shadow_size = 3
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)
	# --- glansig fyllning (rundad pill, anchor_right = nivå) ---
	var fill := Panel.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = 1.0
	fill.offset_left = 2.0
	fill.offset_top = 2.0
	fill.offset_bottom = -2.0
	fill.offset_right = -2.0
	fill.clip_contents = true
	var fillsb := StyleBoxFlat.new()
	fillsb.bg_color = fill_color
	fillsb.set_corner_radius_all(5)
	fill.add_theme_stylebox_override("panel", fillsb)
	frame.add_child(fill)
	# --- sheen: ljus list över övre halvan för glanseffekt ---
	var sheen := ColorRect.new()
	sheen.color = Color(1, 1, 1, 0.16)
	sheen.anchor_left = 0.0
	sheen.anchor_right = 1.0
	sheen.anchor_top = 0.0
	sheen.anchor_bottom = 0.0
	sheen.offset_left = 2.0
	sheen.offset_right = -2.0
	sheen.offset_top = 1.0
	sheen.offset_bottom = 6.0
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(sheen)
	return fill

## Centrerad värde-etikett över en bar, med svart kontur för läsbarhet.
func _make_bar_label(top: float) -> Label:
	var lbl := Label.new()
	lbl.offset_left = _BAR_LEFT
	lbl.offset_top = top
	lbl.offset_right = _BAR_LEFT + _BAR_W
	lbl.offset_bottom = top + _BAR_H
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl

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
	_skillup_lbl.position.y += 40   # under "★ LEVEL UP!" så de inte överlappar
	_skillup_lbl.visible = false
	add_child(_skillup_lbl)

func _on_hp_changed_anim(h: float, _m: float) -> void:
	_prev_hp = h

func _on_skill_leveled(skill: String, new_level: int) -> void:
	Sfx.skill_up()
	var p := World.player
	if p != null and is_instance_valid(p):
		SpellFx.ring(p.get_parent(), p.global_position, Color(0.7, 0.9, 1.0), 26.0)
	if _skillup_lbl == null:
		return
	var sname: String = String(GameState.skill_defs[skill]["name"]) \
		if skill in GameState.skill_defs else skill.capitalize()
	_skillup_lbl.text = "%s nivå %d!" % [sname, new_level]
	_skillup_lbl.visible = true
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func(): _skillup_lbl.visible = false)

## Hantverk klart: ljud + flytande "+1 <namn>" och en liten studs på spelaren.
func _on_crafted(item_id: String, _skill: String) -> void:
	Sfx.craft()
	var p := World.player
	if p == null or not is_instance_valid(p):
		return
	var iname := String(ItemDB.items.get(item_id, {}).get("name", item_id))
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	p.get_parent().add_child(ft)
	ft.global_position = p.global_position + Vector2(0, -16)
	ft.setup("+1 %s" % iname, Color(0.7, 0.95, 0.7), 12)
	if p.visual != null and p.visual.has_method("play_attack"):
		p.visual.play_attack(p.facing)   # liten hantverks-rörelse

## Förbrukad dryck/föremål: heal-gnistor (grönt) eller mana-skur (blått) vid spelaren.
func _on_item_used(item_id: String) -> void:
	var p := World.player
	if p == null or not is_instance_valid(p):
		return
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if d.has("heal"):
		SpellFx.heal_sparkle(p.get_parent(), p.global_position)
	elif d.has("mana"):
		SpellFx.burst(p.get_parent(), p.global_position, Color(0.45, 0.65, 1.0), 10, 60.0)

func _on_level_up_anim() -> void:
	Sfx.level_up()
	# Guldpelare + ring vid spelaren
	var p := World.player
	if p != null and is_instance_valid(p):
		var gold := Color(1.0, 0.88, 0.3)
		SpellFx.ring(p.get_parent(), p.global_position, gold, 44.0)
		SpellFx.fountain(p.get_parent(), p.global_position, gold, 22)
	if _levelup_lbl == null:
		return
	_levelup_lbl.visible = true
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): _levelup_lbl.visible = false)
