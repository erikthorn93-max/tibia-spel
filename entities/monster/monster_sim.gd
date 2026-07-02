class_name MonsterSim
extends RefCounted
## Ren stridssimulering för ett monster: stats, skada, elementmodifierare,
## statuseffekter, enrage, elite och död (exp/loot/kill-räkning).
##
## Ingen rendering, inga noder — headless-testbar och delbar mellan 2D-vyn
## (monster.gd) och en framtida 3D-vy. Vyn prenumererar på signalerna och
## sköter allt visuellt (damage numbers, flash, auror, ljud, dödsanimation).
##
## Beroenden: rena autoloads (MonsterDB, GameState, CharmSystem,
## CombatFormulas, TaskSystem, QuestSystem, ArenaSystem).

signal damaged(amount: int, crit: bool)            # hp redan uppdaterat
signal charm_damaged(amount: int, element: String) # elementär charm-bonusskada
signal element_reaction(kind: String)  # "weak" | "resist" | "immune" | "poison_immune"
signal status_changed()                # status lades till eller tickade ut
signal enrage_started()                # enrage-fas aktiverad (speed/atk höjda)
signal died(drops: Array)              # exp/kills bokförda; drops = utrullad loot

var monster_name := ""
var hp := 10
var max_hp := 10
var atk := 3
var exp := 5
var aggro_range := 5
var speed := 3.0
var cooldown := 1.0
var dead := false
var enraged := false
var is_elite := false
var status_effects: Dictionary = {}   # id -> {tick_dmg, time_left, tick_acc}
var _noted_poison_immune := false     # element_reaction("poison_immune") bara en gång

## Läser grundstats ur MonsterDB. night=true ger +20 % atk och exp (natt-buff).
func init_stats(mname: String, night := false) -> void:
	monster_name = mname
	var d: Dictionary = MonsterDB.monsters.get(mname, {})
	hp = int(d.get("hp", 10)); max_hp = hp
	atk = int(d.get("atk", 3))
	exp = int(d.get("exp", 5))
	aggro_range = int(d.get("aggro_range", 5))
	speed = float(d.get("speed", 3.0))
	cooldown = float(d.get("cooldown", 1.0))
	if night:
		atk = int(float(atk) * 1.2)
		exp = int(float(exp) * 1.2)

## Elite-variant: dubbla HP, +50 % atk, 3× exp.
func make_elite() -> void:
	is_elite = true
	hp = hp * 2
	max_hp = max_hp * 2
	atk = int(float(atk) * 1.5)
	exp = exp * 3

## True om monstret står emot gift (odöda, elementarer eller varelser som själva
## utsöndrar gift). Regeln bor i CombatFormulas så den kan testas rent.
func poison_immune() -> bool:
	return CombatFormulas.monster_poison_immune(MonsterDB.monsters.get(monster_name, {}))

func has_status(id: String) -> bool:
	return status_effects.has(id)

## Applicerar en statuseffekt. Speglar GameState.apply_status: en aktiv DoT
## förnyas bara av en starkare proc (högre tick_dmg) — lika/svagare ignoreras
## så att spelarens gift inte blir permanent via spam.
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
	if id == "poison" and poison_immune():
		if not _noted_poison_immune:
			_noted_poison_immune = true
			element_reaction.emit("poison_immune")
		return
	if tick_dmg > 0.0 and status_effects.has(id) \
			and tick_dmg <= float(status_effects[id]["tick_dmg"]):
		return
	status_effects[id] = {"tick_dmg": tick_dmg, "time_left": duration, "tick_acc": 0.0}
	status_changed.emit()

## Tickar statuseffekter (1 skade-tick/s). Emitterar status_changed när någon
## effekt tickar ut, så vyn kan släcka auror och normalisera HP-baren.
func tick_statuses(delta: float) -> void:
	if status_effects.is_empty():
		return
	var expired := false
	for id in status_effects.keys():
		var s: Dictionary = status_effects[id]
		s["time_left"] -= delta
		s["tick_acc"]  += delta
		if s["tick_acc"] >= 1.0:
			s["tick_acc"] -= 1.0
			take_damage(float(s["tick_dmg"]), false)
		if s["time_left"] <= 0.0:
			status_effects.erase(id)
			expired = true
	if expired:
		status_changed.emit()

## Vanlig skada. Med element != "" tillämpas monstrets element_mod (samma
## svaghets-/resistensdata som charm-systemet) så magi väger element mot fiende.
## Tomt element (närstrid utan elementär laddning) ger neutral skada.
func take_damage(dmg: float, crit := false, element := "") -> void:
	if dead:
		return
	var final_dmg := int(dmg)
	if element != "" and element != "none":
		var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
		var modifier := CharmSystem.element_modifier(d, element)
		if modifier != 1.0:
			final_dmg = CharmSystem.resisted_damage(int(dmg), modifier)
			if final_dmg <= 0:
				element_reaction.emit("immune")
				return
			element_reaction.emit("weak" if modifier > 1.0 else "resist")
	hp = maxi(hp - final_dmg, 0)
	_check_enrage()
	damaged.emit(final_dmg, crit)
	if hp <= 0:
		_die()

## Elementär bonusskada från en offensiv charm. Returnerar faktiskt utdelad
## skada (0 vid immunitet) så anroparen kan basera t.ex. leech på den.
func take_charm_damage(dmg: float, element: String) -> int:
	if dead:
		return 0
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	var modifier := CharmSystem.element_modifier(d, element)
	var final_dmg := CharmSystem.resisted_damage(int(dmg), modifier)
	if final_dmg <= 0:
		element_reaction.emit("immune")
		return 0
	hp = maxi(hp - final_dmg, 0)
	_check_enrage()
	charm_damaged.emit(final_dmg, element)
	if hp <= 0:
		_die()
	return final_dmg

## Enrage-fas för bossar (enrage: true i MonsterDB): triggas en gång vid
## ≤50 % HP och ger +50 % speed och atk.
func _check_enrage() -> void:
	if enraged:
		return
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	if not bool(d.get("enrage", false)):
		return
	if float(hp) > float(max_hp) * 0.5:
		return
	enraged = true
	speed = speed * 1.5
	atk = int(float(atk) * 1.5)
	enrage_started.emit()

## Bokför döden (exp, vapenskill-xp, task/quest/arena-kills), rullar loot och
## emitterar died(drops). Vyn sköter dödsanimation, ground items och respawn.
func _die() -> void:
	dead = true
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	GameState.gain_exp(exp)
	GameState.gain_skill_xp(GameState.weapon_skill(), exp)
	var drops: Array = []
	for entry in d.get("loot", []):
		if randf() < float(entry.get("chance", 0.0)):
			var qty_min := int(entry.get("min", int(entry.get("qty", 1))))
			var qty_max := int(entry.get("max", qty_min))
			drops.append({
				"item": String(entry["item"]),
				"qty":  randi_range(qty_min, qty_max)
			})
	TaskSystem.record_kill(monster_name)
	QuestSystem.record_kill(monster_name)
	ArenaSystem.record_kill(monster_name)
	died.emit(drops)
