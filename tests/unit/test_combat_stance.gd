extends GutTest
## Tester för stridsställningar (combat/combat_stance.gd) + GameState-integration.

const CombatStanceScript = preload("res://combat/combat_stance.gd")

# ── Validering & cykel ──

func test_normalize_keeps_valid():
	for s in CombatStanceScript.STANCES:
		assert_eq(CombatStanceScript.normalize(s), s)

func test_normalize_falls_back_to_default():
	assert_eq(CombatStanceScript.normalize("berserk"), CombatStanceScript.DEFAULT)
	assert_eq(CombatStanceScript.normalize(""), CombatStanceScript.DEFAULT)

func test_default_is_balanced_neutral():
	# Standard ska motsvara spelets tidigare beteende: ingen skade-/försvarsändring.
	assert_eq(CombatStanceScript.DEFAULT, CombatStanceScript.BALANCED)
	assert_eq(CombatStanceScript.damage_mult(CombatStanceScript.BALANCED), 1.0)
	assert_eq(CombatStanceScript.mitigation_bonus(CombatStanceScript.BALANCED), 0)

func test_cycle_visits_all_then_wraps():
	var seen := {}
	var s := CombatStanceScript.OFFENSIVE
	for i in CombatStanceScript.STANCES.size():
		seen[s] = true
		s = CombatStanceScript.cycle(s)
	assert_eq(seen.size(), CombatStanceScript.STANCES.size(), "cykeln ska besöka alla ställningar")
	assert_eq(s, CombatStanceScript.OFFENSIVE, "cykeln ska vända tillbaka till start")

# ── Avvägningar: skada vs försvar ──

func test_offensive_hits_harder_but_guards_worse():
	assert_gt(CombatStanceScript.damage_mult(CombatStanceScript.OFFENSIVE), 1.0)
	assert_lt(CombatStanceScript.mitigation_bonus(CombatStanceScript.OFFENSIVE), 0)

func test_defensive_guards_better_but_hits_softer():
	assert_lt(CombatStanceScript.damage_mult(CombatStanceScript.DEFENSIVE), 1.0)
	assert_gt(CombatStanceScript.mitigation_bonus(CombatStanceScript.DEFENSIVE), 0)

func test_labels_and_icons_distinct():
	var labels := {}
	var icons := {}
	for s in CombatStanceScript.STANCES:
		labels[CombatStanceScript.label(s)] = true
		icons[CombatStanceScript.icon(s)] = true
	assert_eq(labels.size(), CombatStanceScript.STANCES.size(), "varje ställning unikt namn")
	assert_eq(icons.size(), CombatStanceScript.STANCES.size(), "varje ställning unik symbol")

# ── GameState-integration ──

func test_gamestate_cycle_changes_and_emits():
	GameState.set_combat_stance(CombatStance.BALANCED)
	watch_signals(GameState)
	var nxt := GameState.cycle_combat_stance()
	assert_ne(nxt, CombatStance.BALANCED)
	assert_eq(GameState.combat_stance, nxt)
	assert_signal_emitted(GameState, "stance_changed")

func test_gamestate_set_same_stance_is_noop():
	GameState.set_combat_stance(CombatStance.DEFENSIVE)
	watch_signals(GameState)
	GameState.set_combat_stance(CombatStance.DEFENSIVE)
	assert_signal_not_emitted(GameState, "stance_changed")
	GameState.set_combat_stance(CombatStance.BALANCED)   # städa upp

func test_gamestate_rejects_garbage_stance():
	GameState.set_combat_stance("nonsense")
	assert_eq(GameState.combat_stance, CombatStance.BALANCED)
