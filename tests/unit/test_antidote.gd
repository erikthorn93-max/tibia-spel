extends GutTest
## M10: Testar antidote_potion — rensar gift via use_item().

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()
	# Ge spelaren ett motgift
	gs.inventory["antidote_potion"] = 1

func after_each() -> void:
	gs.free()

func test_antidote_potion_existerar_i_items_json() -> void:
	var d: Dictionary = ItemDB.items.get("antidote_potion", {})
	assert_false(d.is_empty(), "antidote_potion ska finnas i items.json")

func test_antidote_potion_har_clears_poison() -> void:
	var d: Dictionary = ItemDB.items.get("antidote_potion", {})
	assert_true(d.has("clears_poison"), "antidote_potion ska ha clears_poison-fält")

func test_antidote_rensar_poison() -> void:
	gs.apply_status("poison", 10.0, 3.0)
	assert_true(gs.has_status("poison"))
	gs.use_item("antidote_potion")
	assert_false(gs.has_status("poison"), "motgift ska rensa poison")

func test_antidote_forbrukar_ett_i_inventory() -> void:
	gs.apply_status("poison", 10.0, 3.0)
	gs.use_item("antidote_potion")
	assert_eq(int(gs.inventory.get("antidote_potion", 0)), 0, "ska förbruka 1 motgift")

func test_antidote_returnerar_true_nar_gift_aktivt() -> void:
	gs.apply_status("poison", 10.0, 3.0)
	var ok := gs.use_item("antidote_potion")
	assert_true(ok, "use_item ska returnera true")

func test_antidote_returnerar_true_utan_gift_ocksa() -> void:
	# clears_poison → used = true även om inget gift pågår
	var ok := gs.use_item("antidote_potion")
	assert_true(ok, "use_item ska returnera true (item förbrukas)")

func test_antidote_paverkar_inte_andra_statusar() -> void:
	gs.apply_status("burn", 5.0, 2.0)
	gs.apply_status("poison", 10.0, 3.0)
	gs.use_item("antidote_potion")
	assert_true(gs.has_status("burn"), "burn ska vara kvar")
	assert_false(gs.has_status("poison"), "poison ska vara borta")

func test_antidote_recept_finns_i_alchemy_table() -> void:
	var recs: Array = Recipes.all_for_station("alchemy_table")
	var found := false
	for r in recs:
		if String(r.get("id", "")) == "antidote_potion":
			found = true
			break
	assert_true(found, "antidote_potion-recept ska finnas i alchemy_table")
