extends GutTest

var db

func before_each():
	db = load("res://autoload/item_db.gd").new()
	db._load()

func after_each():
	db.free()

func test_recipes_loaded_for_all_station_types():
	for station in ["anvil", "stove", "alchemy_table", "rune_altar"]:
		assert_true(db.recipes.has(station), station)
		assert_gt(db.recipes[station].size(), 0, station)

func test_all_recipe_outputs_and_ingredients_exist_as_items():
	for station in db.recipes:
		for r in db.recipes[station]:
			assert_true(db.items.has(r["id"]), "saknat resultat-item: " + str(r["id"]))
			for ing in r["ingredients"]:
				assert_true(db.items.has(ing), "saknad ingrediens: " + str(ing))

func test_all_node_yields_and_tools_exist_as_items():
	for nid in db.nodes:
		assert_true(db.items.has(db.nodes[nid]["yields"]), nid)
		assert_true(db.items.has(db.nodes[nid]["tool"]), nid)

func test_weapons_have_skill_field():
	for id in db.items:
		if db.items[id].get("type") == "weapon":
			assert_true(db.items[id].has("skill"), id)

func _recipe(level := 5, ingredients := {"copper_ore": 3}) -> Dictionary:
	return {"id": "copper_plate", "level": level, "skill": "smithing", "ingredients": ingredients, "xp": 20}

func test_can_craft_true_when_level_and_ingredients_ok():
	assert_true(Recipes.can_craft(_recipe(), {"copper_ore": 3}, 5))

func test_can_craft_false_on_low_level():
	assert_false(Recipes.can_craft(_recipe(5), {"copper_ore": 3}, 4))

func test_can_craft_false_on_missing_ingredients():
	assert_false(Recipes.can_craft(_recipe(), {"copper_ore": 2}, 99))

func test_missing_ingredients_lists_shortfall():
	var missing = Recipes.missing_ingredients(_recipe(), {"copper_ore": 1})
	assert_eq(missing, {"copper_ore": 2})

func test_coast_fishing_nodes_loaded():
	for nid in ["deep_sea_spot", "swordfish_spot", "lobster_pot"]:
		assert_true(db.nodes.has(nid), "saknar nod: " + nid)
		assert_eq(db.nodes[nid]["skill"], "fishing")
		assert_eq(db.nodes[nid]["tool"], "fishing_rod")
