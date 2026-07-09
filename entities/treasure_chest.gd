class_name TreasureChest
extends Node2D
## Skattkista i dungeon: klick intill → engångsloot (guld + temaloot), gråtonas.
## Loot-rullen (open_loot) är renderer-agnostisk och delas med 3D-vyn (Chest3D).

const TILE := 32
const INTERACT_RANGE := 1   # Chebyshev-distans

var tile := Vector2i.ZERO
var _theme_id := ""
var _opened := false

func setup(t: Vector2i, theme_id: String) -> void:
	tile = t
	_theme_id = theme_id
	position = Vector2(t) * TILE + Vector2(TILE / 2.0, TILE / 2.0)

func _ready() -> void:
	# Kistvisual: brun kropp + gyllene lock
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(12, 10), Vector2(-12, 10)])
	body.color = Color(0.45, 0.28, 0.10)
	add_child(body)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(11, -2), Vector2(-11, -2)])
	lid.color = Color(0.60, 0.40, 0.15)
	add_child(lid)
	var lock := Polygon2D.new()
	lock.polygon = PackedVector2Array([
		Vector2(-3, -5), Vector2(3, -5), Vector2(3, 1), Vector2(-3, 1)])
	lock.color = Color(0.90, 0.78, 0.20)
	add_child(lock)
	var lbl := Label.new()
	lbl.text = "Skattkista"
	lbl.position = Vector2(-40, -28)
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.modulate = Color(0.90, 0.78, 0.20)
	add_child(lbl)
	# Klickyta
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 20)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if _opened:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var dist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
	if dist > INTERACT_RANGE:
		World.hud.show_message("Gå intill kistan.")
		return
	_open()

func _open() -> void:
	_opened = true
	modulate = Color(0.55, 0.55, 0.55)   # gråtona — öppnad
	World.hud.show_message(open_loot(_theme_id))

## Renderer-agnostisk loot-rulle: bokför guld + temaloot i GameState och
## returnerar HUD-beskedet. Delas av 2D-kistan och Chest3D.
static func open_loot(theme_id: String) -> String:
	var themes: Dictionary = _load_themes()
	var th: Dictionary = themes.get(theme_id, {})

	# Guld
	var gold_range: Array = th.get("chest_gold", [50, 150])
	var gold := randi_range(int(gold_range[0]), int(gold_range[1]))
	GameState.gold += gold

	# Items
	var parts := ["Du fick %d guld" % gold]
	for entry in th.get("chest_items", []):
		var item_id := String(entry[0])
		var chance := float(entry[1])
		var max_count := int(entry[2])
		if randf() < chance:
			var count := randi_range(1, max_count)
			GameState.inventory[item_id] = int(GameState.inventory.get(item_id, 0)) + count
			var item_name := String(ItemDB.items.get(item_id, {}).get("name", item_id))
			parts.append("%d × %s" % [count, item_name])
	return "Kistan: " + ", ".join(parts) + "!"

static func _load_themes() -> Dictionary:
	var f := FileAccess.open("res://data/dungeon_themes.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}
