class_name Hud3D
extends CanvasLayer
## HUD-bryggan för 3D-slicen: återanvänder 2D-spelets riktiga paneler —
## ryggsäck, färdigheter, besvärjelsebok, bestiarium, questlogg och utrustning —
## ovanpå 3D-vyn. Panelerna pratar bara med autoloads och är därmed
## renderer-agnostiska; bryggan äger toggle-tangenterna (samma actions som 2D)
## och basraden (HP + spec + meddelanden) som tidigare låg i game3d.
##
## Sätter World.hud = self så panelernas show_message-anrop (t.ex. spellbookens
## köpbesked) når 3D-HUD:en utan att panelerna ändras.

var inv_panel: PanelContainer
var skill_panel: PanelContainer
var bestiary_panel: PanelContainer
var spellbook_panel: PanelContainer
var quest_log: PanelContainer
var equipment_panel: PanelContainer
var wardrobe: PanelContainer
var dialogue_box: PanelContainer
var shop_panel: PanelContainer
var bank_panel: PanelContainer
var task_panel: PanelContainer
var recipe_panel: PanelContainer
var prayer_panel: PanelContainer
var minimap: Control
var hotkey_bar: Node

var _hp_lbl: Label
var _spec_lbl: Label
var _msg_lbl: Label
var _msg_tw: Tween
var _arena_lbl: Label
var _fade_rect: ColorRect   # svart overlay för zon-övergångar (som 2D-HUD:en)

func _ready() -> void:
	World.hud = self
	World.world_message.connect(show_message)
	# Drop-zonen först (bakom panelerna): items dragna ur ryggsäck/utrustning
	# hamnar på marken vid spelaren — samma world_drop_zone som 2D-HUD:en.
	add_child(preload("res://ui/world_drop_zone.gd").new())
	# Dödsskärmen (egen CanvasLayer, lager 10 — ovanpå allt): samma överlägg
	# och "Återuppstå"-knapp som 2D; game3d bygger om zonen vid respawn.
	add_child(preload("res://ui/death_screen.gd").new())
	inv_panel = preload("res://ui/inventory_panel.gd").new()
	add_child(inv_panel)
	skill_panel = preload("res://ui/skill_panel.gd").new()
	skill_panel.offset_left = 940.0
	skill_panel.offset_top = 16.0
	add_child(skill_panel)
	bestiary_panel = preload("res://ui/bestiary_panel.gd").new()
	add_child(bestiary_panel)
	spellbook_panel = preload("res://ui/spellbook_panel.gd").new()
	add_child(spellbook_panel)
	quest_log = preload("res://ui/quest_log.gd").new()
	add_child(quest_log)
	equipment_panel = preload("res://ui/equipment_panel.gd").new()
	add_child(equipment_panel)
	wardrobe = preload("res://ui/wardrobe.gd").new()
	add_child(wardrobe)
	dialogue_box = preload("res://ui/dialogue_box.gd").new()
	add_child(dialogue_box)
	shop_panel = preload("res://ui/shop_panel.gd").new()
	add_child(shop_panel)
	bank_panel = preload("res://ui/bank_panel.gd").new()
	add_child(bank_panel)
	task_panel = preload("res://ui/task_panel.gd").new()
	add_child(task_panel)
	recipe_panel = preload("res://ui/recipe_panel.gd").new()
	add_child(recipe_panel)
	prayer_panel = preload("res://ui/prayer_panel.gd").new()
	add_child(prayer_panel)
	minimap = preload("res://ui/minimap.gd").new()
	minimap.loot_source = func() -> Array: return []   # ersätts av attach_minimap
	add_child(minimap)
	hotkey_bar = preload("res://ui/hotkey_bar.gd").new()
	add_child(hotkey_bar)
	GameState.inventory_changed.connect(func(): if hotkey_bar: hotkey_bar._refresh_all())
	_build_labels()
	GameState.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.health, GameState.max_health)
	GameState.spec_changed.connect(_on_spec_changed)
	_on_spec_changed(GameState.spec_energy)
	_build_arena_banner()
	# Fade-overlayen sist → ritas överst vid zon-övergångar.
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0.0)
	add_child(_fade_rect)

## Zon-övergång: tona till svart, kör om-byggnaden, tona tillbaka in —
## samma kurva som 2D-HUD:ens transition.
func transition(rebuild: Callable) -> void:
	if _fade_rect == null:
		rebuild.call_deferred()
		return
	_fade_rect.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	tw.tween_callback(rebuild)
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.28)

## Basraden: HP + spec-mätare + meddelanderad (mini-HUD:en från game3d).
func _build_labels() -> void:
	_hp_lbl = Label.new()
	_hp_lbl.position = Vector2(12, 8)
	add_child(_hp_lbl)
	_spec_lbl = Label.new()
	_spec_lbl.position = Vector2(12, 34)
	add_child(_spec_lbl)
	_msg_lbl = Label.new()
	_msg_lbl.position = Vector2(12, 60)
	_msg_lbl.modulate = Color(1.0, 0.9, 0.5)
	add_child(_msg_lbl)

## Beständig arena-status högst upp i mitten — samma banner som 2D-HUD:en.
## Namngivna metod-kopplingar (inte lambdas) så signalerna auto-kopplas bort
## när HUD-bryggan frigörs vid scenbyte.
func _build_arena_banner() -> void:
	_arena_lbl = Label.new()
	_arena_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_arena_lbl.offset_top = 14.0
	_arena_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arena_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arena_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	_arena_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_arena_lbl.add_theme_constant_override("outline_size", 4)
	_arena_lbl.add_theme_font_size_override("font_size", 16)
	_arena_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_lbl.visible = false
	add_child(_arena_lbl)
	ArenaSystem.wave_started.connect(_on_arena_state_changed)
	ArenaSystem.wave_progress.connect(_on_arena_state_changed)
	ArenaSystem.wave_cleared.connect(_on_arena_state_changed)
	ArenaSystem.arena_won.connect(_on_arena_state_changed)
	ArenaSystem.arena_failed.connect(_on_arena_state_changed)
	_refresh_arena_banner()

## Gemensam mottagare för alla arena-signaler (0–2 args via defaults).
func _on_arena_state_changed(_a = null, _b = null) -> void:
	_refresh_arena_banner()

func _refresh_arena_banner() -> void:
	if _arena_lbl == null:
		return
	if not ArenaSystem.is_active():
		_arena_lbl.visible = false
		return
	var label := String(ArenaSystem.waves[ArenaSystem.current_wave].get("name", ""))
	_arena_lbl.visible = true
	_arena_lbl.text = "⚔ Arena — Våg %d/%d%s   •   %d kvar" % [
		ArenaSystem.current_wave + 1, ArenaSystem.wave_count(),
		("  " + label) if label != "" else "", ArenaSystem.remaining()]

func show_message(text: String) -> void:
	_msg_lbl.text = text
	_msg_lbl.modulate.a = 1.0
	if _msg_tw != null and _msg_tw.is_valid():
		_msg_tw.kill()
	_msg_tw = create_tween()
	_msg_tw.tween_interval(2.0)
	_msg_tw.tween_property(_msg_lbl, "modulate:a", 0.0, 0.8)

func _on_hp_changed(h: float, mh: float) -> void:
	_hp_lbl.text = "HP %d/%d" % [int(h), int(mh)]

## Spec-mätaren: procent under laddning, uppmaning när kraftslaget är redo.
func _on_spec_changed(energy: float) -> void:
	if CombatFormulas.spec_ready(energy):
		_spec_lbl.text = "KRAFTSLAG (F)"
		_spec_lbl.modulate = Color(1.0, 0.85, 0.2)
	else:
		_spec_lbl.text = "Spec %d%%" % roundi(energy)
		_spec_lbl.modulate = Color(0.8, 0.8, 0.8)

## Samma toggle-actions som 2D-HUD:en (hud.gd). Kraftslag/dryck ägs av game3d
## som känner till monstren (cleave-kandidater) — inte av bryggan.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inv_panel.toggle()
	elif event.is_action_pressed("toggle_skills"):
		skill_panel.visible = not skill_panel.visible
	elif event.is_action_pressed("toggle_bestiary"):
		bestiary_panel.toggle()
	elif event.is_action_pressed("toggle_quest_log"):
		quest_log.toggle()
	elif event.is_action_pressed("toggle_spellbook"):
		spellbook_panel.toggle()
	elif event.is_action_pressed("toggle_equipment"):
		equipment_panel.toggle()
	elif event.is_action_pressed("toggle_wardrobe"):
		wardrobe.toggle()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_all()

## Kopplar minimapens entitetskällor till 3D-världen (game3d:s rötter).
## Terräng, portaler och POI:er läser minimapen själv ur World.zone_model.
func attach_minimap(monsters: Callable, npcs: Callable, loot: Callable) -> void:
	minimap.monsters_source = monsters
	minimap.npc_source = npcs
	minimap.loot_source = loot

func close_all() -> void:
	inv_panel.visible = false
	skill_panel.visible = false
	bestiary_panel.visible = false
	spellbook_panel.visible = false
	quest_log.visible = false
	equipment_panel.visible = false
	wardrobe.visible = false
	shop_panel.visible = false
	bank_panel.visible = false
	task_panel.visible = false
	recipe_panel.visible = false
	prayer_panel.visible = false
	dialogue_box.close()

# ── NPC-/stationsöppnare (anropas av Npc3D/Station3D via World.hud) — samma
# ömsesidiga uteslutning som 2D-HUD:ens open_*-metoder. ──────────────────────
func open_dialogue(npc_id: String) -> void:
	_close_service_panels()
	dialogue_box.open(npc_id)

func open_shop() -> void:
	_close_service_panels()
	shop_panel.open()

func open_bank() -> void:
	_close_service_panels()
	bank_panel.open()

func open_tasks() -> void:
	_close_service_panels()
	task_panel.open()

func open_spellbook(learn_mode := false) -> void:
	_close_service_panels()
	spellbook_panel.open(learn_mode)

func open_recipes(station_type: String) -> void:
	_close_service_panels()
	recipe_panel.open(station_type)

func open_prayer_altar() -> void:
	_close_service_panels()
	prayer_panel.open()

## En interaktion i taget: stäng alla tjänstepaneler innan nästa öppnas.
func _close_service_panels() -> void:
	shop_panel.visible = false
	bank_panel.visible = false
	task_panel.visible = false
	recipe_panel.visible = false
	prayer_panel.visible = false
