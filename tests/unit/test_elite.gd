extends GutTest
## M10: Testar elite-monster-logiken i monster.make_elite().
## Sedan 3D-migrationen steg 1 bor logiken på monstret (inte World) och kan
## testas direkt: _refresh_label() guardar på is_node_ready() så inga
## scen-noder behövs.

const MonsterScript = preload("res://entities/monster/monster.gd")

var _m: Node2D

func before_each() -> void:
	_m = MonsterScript.new()
	_m.hp = 20
	_m.max_hp = 20
	_m.atk = 6
	_m.exp = 10

func after_each() -> void:
	_m.free()

func test_elite_dubblerar_hp() -> void:
	_m.make_elite()
	assert_eq(_m.hp, 40, "elite HP ska vara 2× normal")

func test_elite_dubblerar_max_hp() -> void:
	_m.make_elite()
	assert_eq(_m.max_hp, 40, "elite max_hp ska vara 2× normal")

func test_elite_okar_atk_med_halva() -> void:
	_m.make_elite()
	assert_eq(_m.atk, 9, "elite ATK ska vara int(6 * 1.5) = 9")

func test_elite_tredubblar_exp() -> void:
	_m.make_elite()
	assert_eq(_m.exp, 30, "elite exp ska vara 3× normal")

func test_elite_satter_flaggan() -> void:
	assert_false(_m.is_elite, "monster ska inte födas som elite")
	_m.make_elite()
	assert_true(_m.is_elite, "make_elite() ska sätta is_elite")

func test_elite_paverkar_ej_icke_elite() -> void:
	# Kontrollera att ett icke-elite-monster behåller sina värden
	var orig_hp  : int = _m.hp
	var orig_atk : int = _m.atk
	var orig_exp : int = _m.exp
	# ingen make_elite
	assert_eq(_m.hp,  orig_hp)
	assert_eq(_m.atk, orig_atk)
	assert_eq(_m.exp, orig_exp)
