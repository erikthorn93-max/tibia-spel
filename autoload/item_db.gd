extends Node
## Autoload: ItemDB

var items: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	items = JSON.parse_string(f.get_as_text())

func roll_loot(loot_table: Array) -> Array:
	var result: Array = []
	for entry in loot_table:
		if randf() <= float(entry["chance"]):
			result.append({"item": entry["item"], "qty": randi_range(int(entry["min"]), int(entry["max"]))})
	return result
