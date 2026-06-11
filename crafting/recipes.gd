class_name Recipes
extends RefCounted
## Statisk receptlogik — ren och testbar. UI:t kopplar mot GameState.

static func can_craft(recipe: Dictionary, inventory: Dictionary, skill_level: int) -> bool:
	if skill_level < int(recipe["level"]):
		return false
	return missing_ingredients(recipe, inventory).is_empty()

static func missing_ingredients(recipe: Dictionary, inventory: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for ing in recipe["ingredients"]:
		var need := int(recipe["ingredients"][ing])
		var have := int(inventory.get(ing, 0))
		if have < need:
			missing[ing] = need - have
	return missing
