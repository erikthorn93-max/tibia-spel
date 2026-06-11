extends Node
## Autoload: MonsterDB

var monsters: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open("res://data/monsters.json", FileAccess.READ)
	monsters = JSON.parse_string(f.get_as_text())
