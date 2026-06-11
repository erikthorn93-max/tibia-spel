extends Node
## Autoload: ItemDB. Laddar items, recept och gathering-nodtyper.

var items: Dictionary = {}
var recipes: Dictionary = {}
var nodes: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	items = _read_json("res://data/items.json")
	recipes = _read_json("res://data/recipes.json")
	nodes = _read_json("res://data/nodes.json")

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func roll_loot(loot_table: Array) -> Array:
	var result: Array = []
	for entry in loot_table:
		if randf() <= float(entry["chance"]):
			result.append({"item": entry["item"], "qty": randi_range(int(entry["min"]), int(entry["max"]))})
	return result
