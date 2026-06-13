extends GutTest
## M11: Testar stun-statuseffekt på spelaren — rörelseblockering.

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

func test_stun_apply_och_has() -> void:
	gs.apply_status("stun", 2.0, 0.0)
	assert_true(gs.has_status("stun"), "stun ska finnas efter apply")

func test_stun_ger_ingen_skada() -> void:
	gs.health = 100.0; gs.max_health = 100.0
	gs.apply_status("stun", 2.0, 0.0)
	gs._tick_statuses(1.0)
	assert_almost_eq(gs.health, 100.0, 0.01, "stun (tick_dmg=0) ska ej ge skada")

func test_stun_upphör_efter_duration() -> void:
	gs.apply_status("stun", 2.0, 0.0)
	gs._tick_statuses(2.5)
	assert_false(gs.has_status("stun"), "stun ska ha upphört")

func test_stun_kvar_under_duration() -> void:
	gs.apply_status("stun", 2.0, 0.0)
	gs._tick_statuses(1.0)
	assert_true(gs.has_status("stun"), "stun ska fortfarande vara aktiv")

func test_stun_rensar_manuellt() -> void:
	gs.apply_status("stun", 10.0, 0.0)
	gs.clear_status("stun")
	assert_false(gs.has_status("stun"))

func test_urskogsvaltaren_har_stun_ability() -> void:
	var d: Dictionary = MonsterDB.monsters.get("Urskogsvältaren", {})
	var ab: Dictionary = d.get("ability", {})
	assert_eq(String(ab.get("type", "")), "stun", "ability.type ska vara stun")
	assert_almost_eq(float(ab.get("chance", 0.0)), 0.3, 0.01)
	assert_almost_eq(float(ab.get("duration", 0.0)), 2.0, 0.01)
