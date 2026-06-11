extends CanvasLayer

@onready var hp_bar: ColorRect = $HpBar
@onready var mana_bar: ColorRect = $ManaBar
@onready var stats: Label = $StatsLabel
@onready var inv_panel: PanelContainer = $InventoryPanel
@onready var inv_list: Label = $InventoryPanel/InvList
@onready var death_lbl: Label = $DeathLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # måste fungera när trädet pausas vid död
	GameState.hp_changed.connect(func(_h, _m): _refresh())
	GameState.exp_changed.connect(func(_x, _n, _l): _refresh())
	GameState.gold_changed.connect(func(_g): _refresh())
	GameState.inventory_changed.connect(_refresh_inv)
	GameState.player_died.connect(_on_death)
	_refresh()
	_refresh_inv()

func _refresh() -> void:
	hp_bar.size.x = 200.0 * (GameState.health / GameState.max_health)
	mana_bar.size.x = 200.0 * (GameState.mana / GameState.max_mana)
	stats.text = "Lv %d  XP %d/%d  Guld %d  Svärd %d  Sköld %d" % [
		GameState.level, GameState.experience, GameState.xp_to_next, GameState.gold,
		GameState.skills["sword"]["level"], GameState.skills["shielding"]["level"]]

func _refresh_inv() -> void:
	var lines: Array = []
	for id in GameState.inventory:
		lines.append("%s x%d" % [ItemDB.items[id]["name"], GameState.inventory[id]])
	inv_list.text = "\n".join(lines) if lines else "(tomt)"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inv_panel.visible = not inv_panel.visible
	elif event.is_action_pressed("hotkey_1"):
		if GameState.remove_item("health_potion", 1):
			GameState.heal(float(ItemDB.items["health_potion"]["heal"]))
	elif death_lbl.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_respawn()

func _on_death() -> void:
	death_lbl.visible = true
	get_tree().paused = true

func _respawn() -> void:
	get_tree().paused = false
	death_lbl.visible = false
	GameState.health = GameState.max_health
	GameState.experience = int(GameState.experience * 0.9)   # Tibia: XP-förlust vid död
	World.start_game("town")
