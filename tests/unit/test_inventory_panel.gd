extends GutTest
## InventoryPanel (utbruten ur hud.gd): raderna byggs ur GameState.inventory,
## uppdateras via inventory_changed och okända föremål hoppas över. Panelen
## delas mellan 2D-HUD:en och 3D-slicens HUD-brygga.

const InventoryPanelScript = preload("res://ui/inventory_panel.gd")

var panel
var _saved_inv: Dictionary

func before_each():
	_saved_inv = GameState.inventory.duplicate(true)
	panel = InventoryPanelScript.new()
	add_child_autofree(panel)

func after_each():
	GameState.inventory = _saved_inv

## Gamla rader queue_free:as vid refresh men är kvar i trädet till nästa frame
## — räkna bara de levande.
func _rows() -> Array:
	return panel._list.get_children().filter(
		func(c): return not c.is_queued_for_deletion())

func test_refresh_builds_row_per_item():
	GameState.inventory = {"health_potion": 3}
	panel.refresh()
	assert_eq(_rows().size(), 1, "ett föremål ska ge en rad")

func test_inventory_changed_signal_refreshes():
	GameState.inventory = {"health_potion": 1}
	GameState.inventory_changed.emit()
	assert_eq(_rows().size(), 1, "panelen ska prenumerera på inventory_changed")

func test_unknown_items_skipped():
	GameState.inventory = {"__finns_inte__": 5}
	panel.refresh()
	assert_eq(_rows().size(), 0, "föremål utan ItemDB-post ska hoppas över")

func test_toggle_shows_and_hides():
	assert_false(panel.visible, "panelen ska starta dold")
	panel.toggle()
	assert_true(panel.visible)
	panel.toggle()
	assert_false(panel.visible)
