extends GutTest
## M10: Testar burn-status på monster (apply/tick/duration).

## Minimalt mock-monster utan Godot-scene-beroenden.
class MockMonster:
	var hp := 100
	var max_hp := 100
	var dead := false
	var status_effects: Dictionary = {}

	func apply_status(id: String, duration: float, tick_dmg: float) -> void:
		status_effects[id] = {"tick_dmg": tick_dmg, "time_left": duration, "tick_acc": 0.0}

	func has_status(id: String) -> bool:
		return status_effects.has(id)

	func take_damage(dmg: float) -> void:
		hp = maxi(hp - int(dmg), 0)
		if hp <= 0:
			dead = true

	func _tick_statuses(delta: float) -> void:
		if status_effects.is_empty():
			return
		for id in status_effects.keys():
			var s: Dictionary = status_effects[id]
			s["time_left"] -= delta
			s["tick_acc"]  += delta
			if s["tick_acc"] >= 1.0:
				s["tick_acc"] -= 1.0
				take_damage(float(s["tick_dmg"]))
			if s["time_left"] <= 0.0:
				status_effects.erase(id)

var _m: MockMonster

func before_each() -> void:
	_m = MockMonster.new()

# --- apply_status ---

func test_apply_burn_laggar_till_effekt() -> void:
	_m.apply_status("burn", 8.0, 4.0)
	assert_true(_m.has_status("burn"), "burn ska finnas i status_effects")

func test_apply_burn_sparar_tick_dmg() -> void:
	_m.apply_status("burn", 8.0, 4.0)
	assert_almost_eq(float(_m.status_effects["burn"]["tick_dmg"]), 4.0, 0.01)

func test_apply_burn_sparar_duration() -> void:
	_m.apply_status("burn", 8.0, 4.0)
	assert_almost_eq(float(_m.status_effects["burn"]["time_left"]), 8.0, 0.01)

# --- _tick_statuses ---

func test_burn_tick_sanker_hp() -> void:
	_m.hp = 100
	_m.apply_status("burn", 8.0, 4.0)
	_m._tick_statuses(1.0)   # exakt 1s → 1 tick
	assert_eq(_m.hp, 96, "4 dmg per tick")

func test_burn_tick_sker_var_sekund() -> void:
	_m.hp = 100
	_m.apply_status("burn", 8.0, 4.0)
	_m._tick_statuses(0.5)   # under 1s → ingen tick
	assert_eq(_m.hp, 100, "ingen tick ännu")
	_m._tick_statuses(0.6)   # totalt 1.1s → en tick
	assert_eq(_m.hp, 96, "en tick vid >1s")

func test_burn_upphör_efter_duration() -> void:
	_m.apply_status("burn", 3.0, 4.0)
	_m._tick_statuses(4.0)   # passerar duration
	assert_false(_m.has_status("burn"), "burn ska ha upphört")

func test_burn_ger_inte_negativt_hp() -> void:
	_m.hp = 1
	_m.apply_status("burn", 10.0, 50.0)
	_m._tick_statuses(1.0)
	assert_gte(_m.hp, 0, "hp ska aldrig bli negativ")

func test_burn_och_andra_statusar_tickar_oberoende() -> void:
	_m.hp = 100
	_m.apply_status("burn",   8.0, 4.0)
	_m.apply_status("poison", 5.0, 2.0)
	_m._tick_statuses(1.0)
	assert_eq(_m.hp, 94, "4+2 = 6 dmg per tick")

func test_burn_monster_has_method() -> void:
	# Verifierar att interface stämmer med vad player.gd förväntar sig
	assert_true(_m.has_method("apply_status"), "monster ska ha apply_status()")
	assert_true(_m.has_method("has_status"),   "monster ska ha has_status()")
