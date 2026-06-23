extends GutTest
## Testar mana-drain (monster-förmåga "drain") i game_state.gd: tappar mana och
## låter överskottet bita på HP när manan tar slut.

var gs

func before_each() -> void:
	gs = load("res://autoload/game_state.gd").new()

func after_each() -> void:
	gs.free()

func test_drain_sanker_mana() -> void:
	gs.mana = 100.0; gs.max_mana = 100.0
	gs.drain_mana(30.0)
	assert_almost_eq(gs.mana, 70.0, 0.01, "30 mana ska tappas")

func test_drain_clampar_pa_noll() -> void:
	gs.mana = 20.0; gs.max_mana = 100.0
	gs.drain_mana(50.0)
	assert_almost_eq(gs.mana, 0.0, 0.01, "mana ska aldrig bli negativ")

func test_drain_overskott_traffar_hp() -> void:
	gs.mana = 20.0; gs.max_mana = 100.0
	gs.health = 100.0; gs.max_health = 100.0
	gs.drain_mana(50.0)   # 20 från mana, 30 kvar → HP
	assert_almost_eq(gs.mana, 0.0, 0.01)
	assert_almost_eq(gs.health, 70.0, 0.01, "30 överskott ska träffa HP")

func test_drain_utan_overskott_ror_inte_hp() -> void:
	gs.mana = 100.0; gs.max_mana = 100.0
	gs.health = 100.0; gs.max_health = 100.0
	gs.drain_mana(40.0)
	assert_almost_eq(gs.health, 100.0, 0.01, "HP ska inte påverkas när mana räcker")

func test_drain_negativt_belopp_ignoreras() -> void:
	gs.mana = 50.0; gs.max_mana = 100.0
	gs.health = 100.0
	gs.drain_mana(-10.0)
	assert_almost_eq(gs.mana, 50.0, 0.01, "negativ drain ska inte ge mana")
	assert_almost_eq(gs.health, 100.0, 0.01)

# --- Regressionsvakt: varje ability-typ i datan måste hanteras i koden ---
# Speglar match-grenarna i monster.gd:_try_apply_ability(). Om någon lägger till
# en ny ability-typ i monsters.json utan kod faller detta test (annars tyst no-op).
const HANDLED_ABILITIES := ["poison", "burn", "drain", "stun", "slow"]

func test_alla_monster_abilities_hanteras() -> void:
	var ohanterade: Array = []
	for mname in MonsterDB.monsters:
		var ab: Dictionary = MonsterDB.monsters[mname].get("ability", {})
		if ab.is_empty():
			continue
		var t := String(ab.get("type", ""))
		if not HANDLED_ABILITIES.has(t):
			ohanterade.append("%s → '%s'" % [mname, t])
	assert_eq(ohanterade, [], "alla ability-typer ska hanteras i monster.gd")
