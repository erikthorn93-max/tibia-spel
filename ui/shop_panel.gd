extends DraggablePanelContainer
## Butikspanel: köp basvaror, sälj inventory för halva värdet.

const STOCK := ["pickaxe", "hatchet", "fishing_rod", "sickle", "bronze_axe", "wooden_club", "empty_vial",
	"bronze_amulet", "ring_of_protection", "torch", "leather_backpack",
	"health_potion", "mana_potion", "antidote_potion", "great_health_potion", "venom_brew", "blank_rune"]

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(360, 0)
	offset_left = 300.0
	offset_top = 120.0
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	GameState.inventory_changed.connect(func(): if visible: _rebuild())
	GameState.gold_changed.connect(func(_g): if visible: _rebuild())

func open() -> void:
	visible = true
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Handlare — guld: %d" % GameState.gold
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	var buy_hdr := Label.new()
	buy_hdr.text = "— Köp —"
	_list.add_child(buy_hdr)
	for id in STOCK:
		_list.add_child(_trade_row(id, int(ItemDB.items[id]["value"]), "Köp",
			func(): if not GameState.buy_item(id): World.hud.show_message("För lite guld.")))
	var sell_hdr := Label.new()
	sell_hdr.text = "— Sälj —"
	_list.add_child(sell_hdr)
	for id in GameState.inventory:
		_list.add_child(_trade_row(id, int(int(ItemDB.items[id]["value"]) * 0.5), "Sälj",
			func(): GameState.sell_item(id)))

func _trade_row(id: String, price: int, action: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var _row_id := id
	row.mouse_entered.connect(func():
		var tip_pos := row.get_global_rect().position + Vector2(row.size.x + 4, 0)
		ItemTooltip.show_for(_row_id, tip_pos))
	row.mouse_exited.connect(func(): ItemTooltip.hide_tooltip())
	var lbl := Label.new()
	var qty := int(GameState.inventory.get(id, 0))
	var qty_txt := " x%d" % qty if action == "Sälj" else ""
	lbl.text = "%s%s — %d guld" % [ItemDB.items[id]["name"], qty_txt, price]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = action
	btn.pressed.connect(cb)
	row.add_child(btn)
	return row
