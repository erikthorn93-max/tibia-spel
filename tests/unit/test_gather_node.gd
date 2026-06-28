extends GutTest

const GatherNodeScript = preload("res://entities/gather_node.gd")

func test_success_chance_formula():
	assert_almost_eq(GatherNodeScript.success_chance(1, 1), 0.40, 0.001)
	assert_almost_eq(GatherNodeScript.success_chance(11, 1), 0.60, 0.001)
	assert_almost_eq(GatherNodeScript.success_chance(99, 1), 0.90, 0.001)  # tak
	assert_almost_eq(GatherNodeScript.success_chance(1, 30), 0.05, 0.001)  # golv

const Weather = preload("res://ui/weather.gd")

func test_weather_bonus_only_for_fishing_in_storm():
	assert_almost_eq(GatherNodeScript.weather_bonus("fishing", Weather.STORM),
		GatherNodeScript.STORM_FISHING_BONUS, 0.001)

func test_weather_bonus_zero_for_fishing_in_calm():
	assert_eq(GatherNodeScript.weather_bonus("fishing", Weather.CLEAR), 0.0)
	assert_eq(GatherNodeScript.weather_bonus("fishing", Weather.RAIN), 0.0)

func test_weather_bonus_zero_for_other_skills():
	# Endast fisket gynnas av ovädret — gruvbrytning m.m. påverkas inte.
	assert_eq(GatherNodeScript.weather_bonus("mining", Weather.STORM), 0.0)
	assert_eq(GatherNodeScript.weather_bonus("woodcutting", Weather.STORM), 0.0)

func test_storm_raises_fishing_chance_within_cap():
	# Bonusen lyfter chansen men aldrig över 0.95-taket.
	var base := GatherNodeScript.success_chance(1, 1)
	var boosted: float = clampf(base + GatherNodeScript.weather_bonus("fishing", Weather.STORM), 0.05, 0.95)
	assert_gt(boosted, base)
	assert_lte(boosted, 0.95)

func _make_node() -> Node2D:
	var n: Node2D = preload("res://entities/gather_node.tscn").instantiate()
	add_child_autofree(n)
	n.def = {"skill": "mining", "level": 1, "tool": "pickaxe", "yields": "copper_ore",
		"xp": 15, "charges": [3, 5], "respawn": 30, "color": "#b87333", "label": "Kopparådra"}
	n.charges = 3
	return n

func test_attempt_requires_tool():
	var n = _make_node()
	GameState.inventory.erase("pickaxe")
	assert_eq(n.attempt(), "no_tool")

func test_attempt_requires_level():
	var n = _make_node()
	GameState.add_item("pickaxe", 1)
	n.def["level"] = 99
	assert_eq(n.attempt(), "low_level")
	GameState.remove_item("pickaxe", 1)

func test_success_grants_yield_xp_and_consumes_charge():
	var n = _make_node()
	var ore0 = int(GameState.inventory.get("copper_ore", 0))
	var lvl0 = int(GameState.skills["mining"]["level"])
	var xp0 = int(GameState.skills["mining"]["xp"])
	n._on_success()
	assert_eq(int(GameState.inventory.get("copper_ore", 0)), ore0 + 1)
	assert_true(int(GameState.skills["mining"]["xp"]) > xp0 or int(GameState.skills["mining"]["level"]) > lvl0)
	assert_eq(n.charges, 2)
	GameState.remove_item("copper_ore", 1)

func test_depletes_at_zero_charges():
	var n = _make_node()
	n.charges = 1
	n._on_success()
	assert_true(n.depleted)
	assert_eq(n.attempt(), "depleted")
	GameState.remove_item(n.def["yields"], 1)
