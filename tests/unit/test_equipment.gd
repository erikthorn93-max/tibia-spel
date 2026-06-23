extends GutTest
## M8: Testar equipment-system (equip/unequip, total_armor, shielding_bonus, compat).

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# --- Grundläggande equipment-struktur ---

func test_equipment_has_six_slots() -> void:
	for slot in ["weapon", "body", "helmet", "legs", "boots", "offhand"]:
		assert_true(gs.equipment.has(slot), "Saknar slot: " + slot)

func test_weapon_starts_with_rusty_sword() -> void:
	assert_eq(String(gs.equipment.get("weapon", "")), "rusty_sword")

func test_other_slots_start_empty() -> void:
	for slot in ["body", "helmet", "legs", "boots", "offhand"]:
		assert_eq(String(gs.equipment.get(slot, "")), "",
			"Slot %s borde vara tom vid start" % slot)

# --- equip() ---

func test_equip_body_armor_removes_from_inventory() -> void:
	gs.inventory["copper_plate"] = 1
	var ok: bool = gs.equip("body", "copper_plate")
	assert_true(ok)
	assert_eq(String(gs.equipment["body"]), "copper_plate")
	assert_false(gs.inventory.has("copper_plate"), "copper_plate borde ha tagits ur inventory")

func test_equip_wrong_slot_fails() -> void:
	gs.inventory["copper_plate"] = 1
	var ok: bool = gs.equip("weapon", "copper_plate")  # copper_plate är body-slot
	assert_false(ok)
	assert_eq(int(gs.inventory.get("copper_plate", 0)), 1, "Item borde vara kvar i inventory")

func test_equip_item_not_in_inventory_fails() -> void:
	var ok: bool = gs.equip("body", "copper_plate")
	assert_false(ok)

func test_equip_unknown_item_fails() -> void:
	gs.inventory["fake_item"] = 1
	var ok: bool = gs.equip("body", "fake_item")
	assert_false(ok)

func test_equip_shield_in_offhand() -> void:
	gs.inventory["wooden_shield"] = 1
	var ok: bool = gs.equip("offhand", "wooden_shield")
	assert_true(ok)
	assert_eq(String(gs.equipment["offhand"]), "wooden_shield")

func test_equip_replaces_and_returns_old_item() -> void:
	gs.inventory["copper_plate"] = 1
	gs.inventory["iron_platebody"] = 1
	gs.equip("body", "copper_plate")
	gs.equip("body", "iron_platebody")
	assert_eq(String(gs.equipment["body"]), "iron_platebody")
	assert_eq(int(gs.inventory.get("copper_plate", 0)), 1,
		"Gammalt föremål borde ha återlämnats till inventory")

# --- unequip() ---

func test_unequip_returns_to_inventory() -> void:
	gs.inventory["copper_plate"] = 1
	gs.equip("body", "copper_plate")
	gs.unequip("body")
	assert_eq(String(gs.equipment["body"]), "")
	assert_eq(int(gs.inventory.get("copper_plate", 0)), 1)

func test_unequip_empty_slot_is_noop() -> void:
	gs.unequip("body")   # ska inte krascha
	assert_eq(String(gs.equipment["body"]), "")

# --- total_armor() ---

func test_total_armor_zero_when_no_armor() -> void:
	# Vapen ger ingen rustning
	assert_eq(gs.total_armor(), 0)

func test_total_armor_body_only() -> void:
	gs.inventory["copper_plate"] = 1
	gs.equip("body", "copper_plate")
	assert_eq(gs.total_armor(), 4)

func test_total_armor_multiple_slots() -> void:
	gs.inventory["copper_plate"] = 1
	gs.inventory["copper_helmet"] = 1
	gs.inventory["copper_legs"] = 1
	gs.inventory["copper_boots"] = 1
	gs.equip("body", "copper_plate")
	gs.equip("helmet", "copper_helmet")
	gs.equip("legs", "copper_legs")
	gs.equip("boots", "copper_boots")
	assert_eq(gs.total_armor(), 10)  # 4 + 2 + 3 + 1

func test_total_armor_iron_set() -> void:
	gs.inventory["iron_platebody"] = 1
	gs.inventory["iron_helmet"] = 1
	gs.inventory["iron_legs"] = 1
	gs.inventory["iron_boots"] = 1
	gs.equip("body", "iron_platebody")
	gs.equip("helmet", "iron_helmet")
	gs.equip("legs", "iron_legs")
	gs.equip("boots", "iron_boots")
	assert_eq(gs.total_armor(), 20)  # 8 + 4 + 6 + 2

# --- total_shielding_bonus() ---

func test_total_shielding_bonus_zero_when_no_shield() -> void:
	assert_eq(gs.total_shielding_bonus(), 0)

func test_total_shielding_bonus_wooden_shield() -> void:
	gs.inventory["wooden_shield"] = 1
	gs.equip("offhand", "wooden_shield")
	assert_eq(gs.total_shielding_bonus(), 3)

func test_total_shielding_bonus_steel_shield() -> void:
	gs.inventory["steel_shield"] = 1
	gs.equip("offhand", "steel_shield")
	assert_eq(gs.total_shielding_bonus(), 9)

# --- Bakåtkompatibilitet ---

func test_equipped_weapon_property_returns_equipment_weapon() -> void:
	assert_eq(gs.equipped_weapon, "rusty_sword")

func test_equip_weapon_compat() -> void:
	gs.inventory["iron_sword"] = 1
	var ok: bool = gs.equip_weapon("iron_sword")
	assert_true(ok)
	assert_eq(String(gs.equipment["weapon"]), "iron_sword")
	assert_eq(gs.equipped_weapon, "iron_sword")

func test_unequip_weapon_compat() -> void:
	gs.unequip_weapon()
	assert_eq(String(gs.equipment["weapon"]), "")
	# rusty_sword borde ha lagts i inventory
	assert_eq(int(gs.inventory.get("rusty_sword", 0)), 1)

func test_weapon_skill_reads_equipment() -> void:
	gs.inventory["bronze_axe"] = 1
	gs.equip_weapon("bronze_axe")
	assert_eq(gs.weapon_skill(), "axe")
