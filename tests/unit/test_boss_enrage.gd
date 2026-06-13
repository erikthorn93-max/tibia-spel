extends GutTest
## M11: Testar boss-enrage-mekaniken i monster.gd.

## Mock-monster som replikerar enrage-logiken utan scene-beroenden.
class MockMonster:
	var monster_name := "Ghulkungen"
	var hp := 800
	var max_hp := 800
	var atk := 40
	var speed := 1.6
	var dead := false
	var enraged := false

	func _check_enrage() -> void:
		if enraged:
			return
		var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
		if not bool(d.get("enrage", false)):
			return
		if float(hp) > float(max_hp) * 0.5:
			return
		enraged = true
		speed   *= 1.5
		atk      = int(float(atk) * 1.5)

	func take_damage(dmg: float) -> void:
		if dead: return
		hp = maxi(hp - int(dmg), 0)
		_check_enrage()
		if hp <= 0: dead = true

var _m: MockMonster

func before_each() -> void:
	_m = MockMonster.new()

# --- enrage triggeras ---

func test_enrage_ej_aktiv_vid_full_hp() -> void:
	assert_false(_m.enraged, "enrage ska inte vara aktiv vid fullt hp")

func test_enrage_ej_aktiv_vid_51_procent() -> void:
	_m.take_damage(float(_m.max_hp) * 0.49 - 1.0)   # precis ovan 50%
	assert_false(_m.enraged, "ska ej triggas ovan 50% HP")

func test_enrage_triggas_vid_50_procent() -> void:
	_m.take_damage(float(_m.max_hp) * 0.5)   # exakt 50%
	assert_true(_m.enraged, "enrage ska triggas vid ≤50% HP")

func test_enrage_triggas_vid_under_50_procent() -> void:
	_m.take_damage(float(_m.max_hp) * 0.7)
	assert_true(_m.enraged, "enrage ska triggas under 50% HP")

# --- stat-ändringar ---

func test_enrage_okar_speed() -> void:
	var orig_speed := _m.speed
	_m.take_damage(float(_m.max_hp) * 0.6)
	assert_almost_eq(_m.speed, orig_speed * 1.5, 0.001, "speed ska vara 1.5× vid enrage")

func test_enrage_okar_atk() -> void:
	var orig_atk := _m.atk
	_m.take_damage(float(_m.max_hp) * 0.6)
	assert_eq(_m.atk, int(float(orig_atk) * 1.5), "ATK ska vara 1.5× vid enrage")

# --- enrage triggas bara en gång ---

func test_enrage_triggas_ej_dubbelt() -> void:
	_m.take_damage(float(_m.max_hp) * 0.6)   # trigger 1
	var atk_after_first := _m.atk
	var speed_after_first := _m.speed
	_m.take_damage(10.0)   # ytterligare skada — ska INTE multiplicera igen
	assert_eq(_m.atk, atk_after_first, "ATK ska ej multipliceras igen")
	assert_almost_eq(_m.speed, speed_after_first, 0.001, "speed ska ej multipliceras igen")

# --- monster utan enrage-flagga ---

func test_ej_boss_enragar_inte() -> void:
	_m.monster_name = "Råtta"   # Råttor har ej enrage:true
	_m.hp = 100; _m.max_hp = 100
	_m.take_damage(80.0)   # under 50%
	assert_false(_m.enraged, "vanliga monster ska ej enraga")

func test_enrage_flagga_finns_i_monsters_json() -> void:
	var d: Dictionary = MonsterDB.monsters.get("Ghulkungen", {})
	assert_true(bool(d.get("enrage", false)), "Ghulkungen ska ha enrage:true")

func test_urskogsvaltaren_finns_i_monsters_json() -> void:
	var d: Dictionary = MonsterDB.monsters.get("Urskogsvältaren", {})
	assert_false(d.is_empty(), "Urskogsvältaren ska finnas i monsters.json")
	assert_true(bool(d.get("boss", false)), "ska ha boss:true")
	assert_true(bool(d.get("enrage", false)), "ska ha enrage:true")
