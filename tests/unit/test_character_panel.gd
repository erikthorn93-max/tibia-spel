extends GutTest
## Tester för karaktärspanelen (C): nya slots (halsband/ring/pilar/verktyg),
## armor-bonus, markör-slot-beteende och panelens uppbyggnad.

const EquipmentPanel = preload("res://ui/equipment_panel.gd")

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# ── Nya slots ──

func test_new_slots_exist() -> void:
	for slot in ["amulet", "ring", "ring2", "ammo", "tool", "light", "backpack"]:
		assert_true(gs.equipment.has(slot), "saknar slot %s" % slot)

func test_new_slots_start_empty() -> void:
	for slot in ["amulet", "ring", "ring2", "ammo", "tool", "light", "backpack"]:
		assert_eq(String(gs.equipment.get(slot, "")), "", "slot %s ska vara tom vid start" % slot)

# ── Ryggsäck: skyddar loot vid död ──

func test_death_drop_fraction_default() -> void:
	assert_almost_eq(gs.death_drop_fraction(), 0.30, 0.001, "utan ryggsäck tappas 30 %")

func test_backpack_reduces_death_drop() -> void:
	gs.inventory["leather_backpack"] = 1
	assert_true(gs.equip("backpack", "leather_backpack"))
	assert_almost_eq(gs.death_drop_fraction(), 0.20, 0.001, "lädersäck → 20 %")
	gs.inventory["explorer_backpack"] = 1
	gs.equip("backpack", "explorer_backpack")
	assert_almost_eq(gs.death_drop_fraction(), 0.10, 0.001, "äventyrarsäck → 10 %")

func test_death_drop_never_below_floor() -> void:
	# Hypotetiskt överskydd ska klampas till minst 5 %
	gs.inventory["explorer_backpack"] = 1
	gs.equip("backpack", "explorer_backpack")
	assert_gte(gs.death_drop_fraction(), 0.05)

# ── Två ringar: samma ring-item passar i båda slotarna och rustning stackar ──

func test_ring_fits_in_both_ring_slots() -> void:
	assert_true(gs.slot_accepts("ring", "ring"))
	assert_true(gs.slot_accepts("ring2", "ring"), "ringar ska passa i ring2")
	assert_false(gs.slot_accepts("ring2", "amulet"), "halsband ska inte passa i ring2")

func test_two_rings_stack_armor() -> void:
	gs.inventory["ring_of_protection"] = 1
	gs.inventory["ring_of_vigor"] = 1
	assert_true(gs.equip("ring", "ring_of_protection"))
	assert_true(gs.equip("ring2", "ring_of_vigor"))
	assert_eq(gs.total_armor(), 6, "2 (skydd) + 4 (kraft)")

# ── Ljuskälla ──

func test_light_slot_equip_and_level() -> void:
	gs.inventory["torch"] = 1
	assert_true(gs.equip("light", "torch"))
	assert_eq(String(gs.equipment["light"]), "torch")
	assert_almost_eq(gs.light_level(), 0.55, 0.001)

func test_light_level_zero_without_source() -> void:
	assert_eq(gs.light_level(), 0.0)

# ── Halsband/ring ger rustning ──

func test_equip_amulet_adds_armor() -> void:
	gs.inventory["bronze_amulet"] = 1
	var ok: bool = gs.equip("amulet", "bronze_amulet")
	assert_true(ok, "kunde inte utrusta halsband")
	assert_eq(String(gs.equipment["amulet"]), "bronze_amulet")
	assert_false(gs.inventory.has("bronze_amulet"), "halsbandet ska tas ur ryggsäcken")
	assert_eq(gs.total_armor(), 3, "bronshalsband ger 3 rustning")

func test_amulet_and_ring_armor_stacks() -> void:
	gs.inventory["bronze_amulet"] = 1
	gs.inventory["ring_of_protection"] = 1
	gs.equip("amulet", "bronze_amulet")
	gs.equip("ring", "ring_of_protection")
	assert_eq(gs.total_armor(), 5, "3 (halsband) + 2 (ring)")

# ── Verktygs- och pilslot = markör (föremålet ligger kvar i ryggsäcken) ──

func test_tool_slot_keeps_item_in_inventory() -> void:
	gs.inventory["pickaxe"] = 1
	var ok: bool = gs.equip("tool", "pickaxe")
	assert_true(ok)
	assert_eq(String(gs.equipment["tool"]), "pickaxe")
	assert_eq(int(gs.inventory.get("pickaxe", 0)), 1, "verktyget ska ligga kvar i ryggsäcken")
	assert_true(gs.has_tool("pickaxe"))

func test_has_tool_via_slot_when_not_in_inventory() -> void:
	gs.inventory["pickaxe"] = 1
	gs.equip("tool", "pickaxe")
	gs.inventory.erase("pickaxe")
	assert_true(gs.has_tool("pickaxe"), "utrustat verktyg ska räcka även utan i ryggsäcken")

func test_unequip_reference_slot_does_not_duplicate() -> void:
	gs.inventory["pickaxe"] = 1
	gs.equip("tool", "pickaxe")
	gs.unequip("tool")
	assert_eq(String(gs.equipment["tool"]), "")
	assert_eq(int(gs.inventory.get("pickaxe", 0)), 1, "verktyget får inte dupliceras")

func test_ammo_reference_and_consume() -> void:
	gs.inventory["wooden_arrow"] = 3
	var ok: bool = gs.equip("ammo", "wooden_arrow")
	assert_true(ok)
	assert_eq(int(gs.inventory.get("wooden_arrow", 0)), 3, "pilarna ligger kvar i ryggsäcken")
	assert_true(gs.has_ammo("wooden_arrow"))
	assert_true(gs.consume_ammo("wooden_arrow"))
	assert_eq(int(gs.inventory.get("wooden_arrow", 0)), 2, "en pil ska förbrukas")
	assert_eq(String(gs.equipment["ammo"]), "wooden_arrow", "markören kvar så länge pilar finns")

func test_ammo_slot_clears_when_depleted() -> void:
	gs.inventory["wooden_arrow"] = 1
	gs.equip("ammo", "wooden_arrow")
	gs.consume_ammo("wooden_arrow")
	assert_eq(int(gs.inventory.get("wooden_arrow", 0)), 0)
	assert_eq(String(gs.equipment["ammo"]), "", "pilsloten töms när sista pilen skjuts")

# ── Panelens uppbyggnad ──

func test_panel_builds_all_thirteen_slots() -> void:
	var panel = EquipmentPanel.new()
	add_child_autofree(panel)
	assert_eq(panel._icons.size(), 13, "panelen ska ha 13 utrustningsslots")
	for slot in ["amulet", "helmet", "backpack", "weapon", "body", "offhand",
			"tool", "legs", "ammo", "ring", "boots", "ring2", "light"]:
		assert_true(panel._icons.has(slot), "panelen saknar slot %s" % slot)
