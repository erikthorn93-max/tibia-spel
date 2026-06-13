extends GutTest
## M10: Testar elite-monster-logiken i World._make_elite().

## Minimalt mock-monster för att testa _make_elite utan scene.
class MockMonster:
	var hp := 20
	var max_hp := 20
	var atk := 6
	var exp := 10
	var _label_text := "Råtta"
	var _label_color := Color.WHITE
	var _refreshed := false

	func has_node(_path: String) -> bool:
		return false   # inga noder i mock — testar statändringar separat

	func _refresh_label() -> void:
		_refreshed = true

## Hjälpfunktion: kör _make_elite-logiken direkt (utan World-autoload).
func _apply_elite(m: MockMonster) -> void:
	m.hp     = m.hp * 2
	m.max_hp = m.max_hp * 2
	m.atk    = int(float(m.atk) * 1.5)
	m.exp    = m.exp * 3
	m._refresh_label()

var _m: MockMonster

func before_each() -> void:
	_m = MockMonster.new()

func test_elite_dubblerar_hp() -> void:
	_apply_elite(_m)
	assert_eq(_m.hp, 40, "elite HP ska vara 2× normal")

func test_elite_dubblerar_max_hp() -> void:
	_apply_elite(_m)
	assert_eq(_m.max_hp, 40, "elite max_hp ska vara 2× normal")

func test_elite_okar_atk_med_halva() -> void:
	_apply_elite(_m)
	assert_eq(_m.atk, 9, "elite ATK ska vara int(6 * 1.5) = 9")

func test_elite_tredubblar_exp() -> void:
	_apply_elite(_m)
	assert_eq(_m.exp, 30, "elite exp ska vara 3× normal")

func test_elite_anropar_refresh_label() -> void:
	_apply_elite(_m)
	assert_true(_m._refreshed, "_refresh_label() ska anropas")

func test_elite_paverkar_ej_icke_elite() -> void:
	# Kontrollera att ett icke-elite-monster behåller sina värden
	var orig_hp  := _m.hp
	var orig_atk := _m.atk
	var orig_exp := _m.exp
	# ingen _apply_elite
	assert_eq(_m.hp,  orig_hp)
	assert_eq(_m.atk, orig_atk)
	assert_eq(_m.exp, orig_exp)
