extends Control
## Transparent drop-zon som täcker spelvärlden.
## Items som dras hit hamnar på marken vid spelarens position — som i Tibia.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS   # passera klick till världen
	z_index = -1   # bakom alla UI-panel er

func _can_drop_data(_at: Vector2, data) -> bool:
	return data is Dictionary and data.has("item_id")

func _drop_data(_at: Vector2, data: Dictionary) -> void:
	var item_id: String = String(data.get("item_id", ""))
	var qty: int = int(data.get("qty", 1))
	if item_id.is_empty():
		return
	# Ta bort från ursprungskällan om inventory (equipment sköts av sin panel)
	var source: String = String(data.get("source", "inventory"))
	if source == "equipment":
		var slot: String = String(data.get("source_slot", ""))
		if slot != "":
			GameState.unequip(slot)
			World.drop_item(item_id, qty)
		return
	World.drop_item(item_id, qty)
	World.hud.show_message("Du tappade %s på marken." % item_id)
