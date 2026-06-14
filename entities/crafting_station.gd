class_name CraftingStation
extends Node2D
## Klickbar crafting-station. Öppnar receptpanelen för sin stationstyp.

const LABELS := {
	"anvil": "Städ", "stove": "Gryta", "alchemy_table": "Alkemibord",
	"rune_altar": "Runaltare", "crafting_bench": "Hantverksbord", "prayer_altar": "Bönaltare"
}
const COLORS := {
	"anvil": "#5a5a62", "stove": "#8a4a2a", "alchemy_table": "#4a7a5a",
	"rune_altar": "#6a4a8a", "crafting_bench": "#8a6a3a", "prayer_altar": "#d4b84a"
}

var station_type := ""
var tile := Vector2i.ZERO

@onready var body: Polygon2D = $Body
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

func setup(type: String, t: Vector2i) -> void:
	station_type = type
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)
	body.color = Color(String(COLORS[type]))
	name_lbl.text = String(LABELS[type])

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist: int = maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 1:
			if station_type == "prayer_altar":
				World.hud.open_prayer_altar()
			else:
				World.hud.open_recipes(station_type)
		else:
			World.hud.show_message("Gå närmare %s." % LABELS[station_type])
