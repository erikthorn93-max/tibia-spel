extends GutTest
## Testar mättnads- & regenereringssystemet: mat ger mättnad (inte direkt heal),
## och mättnad driver passiv HP/mana-regen över tid. Potions helar fortfarande direkt.

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

# --- Mat ger mättnad istället för direkt heal ---

func test_eating_food_grants_satiation() -> void:
	gs.inventory["cooked_trout"] = 1   # heal 40, type food
	gs.use_item("cooked_trout")
	# näring 40 * SECONDS_PER_NUTRITION (4.0) = 160s
	assert_almost_eq(gs.satiation, 160.0, 0.01)

func test_eating_food_does_not_heal_instantly() -> void:
	gs.health = 100.0
	gs.max_health = 200.0
	gs.inventory["cooked_trout"] = 1
	gs.use_item("cooked_trout")
	assert_eq(gs.health, 100.0, "mat ska inte hela direkt")

func test_potion_still_heals_instantly() -> void:
	gs.health = 50.0
	gs.max_health = 200.0
	gs.inventory["health_potion"] = 1
	gs.use_item("health_potion")
	assert_gt(gs.health, 50.0, "potions ska fortfarande hela direkt")

# --- feed() ---

func test_feed_clamps_at_max() -> void:
	gs.feed(gs.MAX_SATIATION + 500.0)
	assert_almost_eq(gs.satiation, gs.MAX_SATIATION, 0.01)

func test_feed_accumulates() -> void:
	gs.feed(50.0)
	gs.feed(30.0)
	assert_almost_eq(gs.satiation, 80.0, 0.01)

# --- _tick_regen() ---

func test_regen_heals_while_satiated() -> void:
	gs.health = 50.0
	gs.max_health = 200.0
	gs.satiation = 100.0
	gs._tick_regen(gs.REGEN_INTERVAL)   # exakt ett regen-steg
	assert_gt(gs.health, 50.0, "mätt spelare ska regenerera HP")
	assert_almost_eq(gs.satiation, 100.0 - gs.REGEN_INTERVAL, 0.01)

func test_regen_does_nothing_when_unsatiated() -> void:
	gs.health = 50.0
	gs.max_health = 200.0
	gs.satiation = 0.0
	gs._tick_regen(gs.REGEN_INTERVAL)
	assert_eq(gs.health, 50.0, "utan mättnad ingen regen")

func test_regen_does_not_overheal() -> void:
	gs.health = 200.0
	gs.max_health = 200.0
	gs.satiation = 100.0
	gs._tick_regen(gs.REGEN_INTERVAL)
	assert_eq(gs.health, 200.0, "regen ska inte överskrida max_health")

# --- regen-mängder skalar ---

func test_hp_regen_scales_with_constitution() -> void:
	var base: int = gs.hp_regen_amount()
	gs.skills["constitution"] = {"level": 60}
	assert_gt(gs.hp_regen_amount(), base, "högre constitution → mer HP-regen")

func test_mp_regen_scales_with_magic() -> void:
	var base: int = gs.mp_regen_amount()
	gs.skills["magic"] = {"level": 40}
	assert_gt(gs.mp_regen_amount(), base, "högre magic → mer mana-regen")

func test_total_regen_zero_with_starting_gear() -> void:
	assert_eq(gs.total_regen(), 0, "ingen startutrustning har regen-fält")
