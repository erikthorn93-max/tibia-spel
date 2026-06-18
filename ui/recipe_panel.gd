extends DraggablePanelContainer
## Receptpanel: visar stationens recept, craftar via GameState.craft.

var station_type := ""
var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(360, 0)
	offset_left = 300.0
	offset_top = 120.0
	_list = VBoxContainer.new()
	add_child(_list)
	GameState.inventory_changed.connect(func(): if visible: _rebuild())
	GameState.skill_changed.connect(func(_s): if visible: _rebuild())

func open(type: String) -> void:
	station_type = type
	visible = true
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = {
		"anvil": "Städ — Smithing", "stove": "Gryta — Cooking",
		"alchemy_table": "Alkemibord — Alchemy", "rune_altar": "Runaltare — Runecrafting",
		"crafting_bench": "Hantverksbord — Crafting & Fletching",
		"workbench": "Verkstadsbänk — Construction"
	}[station_type]
	title.add_theme_font_size_override("font_size", 16)
	_list.add_child(title)
	for r in ItemDB.recipes[station_type]:
		_list.add_child(_recipe_row(r))

func _recipe_row(r: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "%s  (kräver %s %d)" % [ItemDB.items[r["id"]]["name"], r["skill"], int(r["level"])]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	head.add_child(name_lbl)
	var ok := Recipes.can_craft(r, GameState.inventory, GameState.effective_skill_level(String(r["skill"])))
	var btn := Button.new()
	btn.text = "Crafta"
	btn.disabled = not ok
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func(): GameState.craft(r))
	head.add_child(btn)
	var btn5 := Button.new()
	btn5.text = "x5"
	btn5.disabled = not ok
	btn5.add_theme_font_size_override("font_size", 10)
	btn5.pressed.connect(func():
		for i in 5:
			if not GameState.craft(r):
				break)
	head.add_child(btn5)
	box.add_child(head)
	var ing_lbl := Label.new()
	var parts: Array = []
	for ing in r["ingredients"]:
		var need := int(r["ingredients"][ing])
		var have := int(GameState.inventory.get(ing, 0))
		parts.append("%s %d/%d" % [ItemDB.items[ing]["name"], have, need])
	ing_lbl.text = "   " + ", ".join(parts)
	ing_lbl.add_theme_font_size_override("font_size", 10)
	ing_lbl.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.6)
	box.add_child(ing_lbl)
	return box
