extends Node
## Autoload: CharmSystem. Charm-poäng tjänas när bestiarie-tiers fylls (TaskSystem)
## och spenderas på passiva charms. En offensiv + en defensiv charm kan bäras åt gången.
## Offensiva charms triggar bonusskada på träff; defensiva mildrar inkommande skada.

signal points_changed(points: int)
signal charms_changed

## Charms kan uppgraderas i rank 1–3; högre rank ökar effektens styrka (value).
const MAX_RANK := 3
## Multiplikator på charmens value per rank (index = rank, 0 oanvänd).
const RANK_VALUE_MULT := [0.0, 1.0, 1.6, 2.4]

var charms: Dictionary = {}        # id -> def (data/charms.json)
var points := 0                    # ospenderade charm-poäng
var unlocked: Dictionary = {}      # id -> true (köpta charms)
var ranks: Dictionary = {}         # id -> rank (1..MAX_RANK), sätts vid köp
var equipped_offense := ""         # aktiv offensiv charm-id ("" = ingen)
var equipped_defense := ""         # aktiv defensiv charm-id ("" = ingen)

func _init() -> void:
	var f := FileAccess.open("res://data/charms.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	charms = parsed if parsed is Dictionary else {}

## Färg på den flytande skadesiffran per element (charm-träff).
static func element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.45, 0.1)
		"energy": return Color(0.4, 0.8, 1.0)
		"death": return Color(0.62, 0.32, 0.82)
		_: return Color(0.85, 0.85, 0.85)

## Tilldelar charm-poäng (kallas av TaskSystem vid tier-fyllnad).
func award_points(n: int) -> void:
	if n <= 0:
		return
	points += n
	points_changed.emit(points)

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func can_afford(id: String) -> bool:
	return charms.has(id) and points >= int(charms[id].get("cost", 0))

## Köper en charm permanent. Returnerar false om okänd, redan köpt eller för dyr.
func unlock(id: String) -> bool:
	if not charms.has(id) or is_unlocked(id) or not can_afford(id):
		return false
	points -= int(charms[id].get("cost", 0))
	unlocked[id] = true
	ranks[id] = 1
	points_changed.emit(points)
	charms_changed.emit()
	return true

## Nuvarande rank för en charm (1 om köpt utan lagrad rank, clampad mot MAX_RANK).
func rank(id: String) -> int:
	return clampi(int(ranks.get(id, 1)), 1, MAX_RANK)

## Poängkostnad för att höja en charm till nästa rank (skalar med nuvarande rank).
func upgrade_cost(id: String) -> int:
	if not charms.has(id):
		return 0
	return int(charms[id].get("cost", 0)) * rank(id)

func can_upgrade(id: String) -> bool:
	return is_unlocked(id) and rank(id) < MAX_RANK and points >= upgrade_cost(id)

## Höjer en köpt charm en rank. Returnerar false om max-rank eller för få poäng.
func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	points -= upgrade_cost(id)
	ranks[id] = rank(id) + 1
	points_changed.emit(points)
	charms_changed.emit()
	return true

## Andel av utdelad charm-skada som läker spelaren (0 = ingen leech).
func lifesteal(id: String) -> float:
	if not charms.has(id):
		return 0.0
	return float(charms[id].get("lifesteal", 0.0))

## Charmens value efter rank-skalning (rank 1 = oförändrat).
func effective_value(id: String) -> float:
	if not charms.has(id):
		return 0.0
	return float(charms[id].get("value", 0.0)) * RANK_VALUE_MULT[rank(id)]

## Bär en köpt charm i rätt slot (offense/defense efter dess typ).
func equip(id: String) -> bool:
	if not is_unlocked(id):
		return false
	match String(charms[id].get("type", "")):
		"offense": equipped_offense = id
		"defense": equipped_defense = id
		_: return false
	charms_changed.emit()
	return true

func unequip_offense() -> void:
	equipped_offense = ""
	charms_changed.emit()

func unequip_defense() -> void:
	equipped_defense = ""
	charms_changed.emit()

## Monsterns multiplikator mot ett charm-element (1.0 = normal, <1 = resistent,
## 0 = immun, >1 = svag). Läses ur monsterdefinitionens "element_mod".
static func element_modifier(monster_def: Dictionary, element: String) -> float:
	var mods = monster_def.get("element_mod", {})
	if mods is Dictionary and mods.has(element):
		return float(mods[element])
	return 1.0

## Charm-skada efter att monsterns element-resistens tillämpats.
## Immunt (mod 0) ger 0; annars minst 1 så en träff alltid känns.
static func resisted_damage(base: int, modifier: float) -> int:
	if modifier <= 0.0:
		return 0
	return maxi(int(round(float(base) * modifier)), 1)

## Bonusskada en offensiv charm gör mot ett mål med givet max-HP (avrundat, minst 1).
func offense_damage(id: String, target_max_hp: float) -> int:
	if not charms.has(id):
		return 0
	return maxi(int(round(target_max_hp * effective_value(id))), 1)

## Skada som en defensiv charm mildrar bort från ett inkommande slag (rank-skalad).
func defense_reduction(id: String, incoming: float) -> float:
	if not charms.has(id):
		return 0.0
	return maxf(incoming, 0.0) * effective_value(id)

## Slår den bärna offensiva charmen mot ett mål.
## Returnerar {triggered, amount, element, id}.
func roll_offense(target_max_hp: float) -> Dictionary:
	var id := equipped_offense
	if id == "" or not charms.has(id):
		return {"triggered": false, "amount": 0, "element": "", "id": ""}
	if randf() >= float(charms[id].get("chance", 0.0)):
		return {"triggered": false, "amount": 0, "element": "", "id": id}
	return {
		"triggered": true,
		"amount": offense_damage(id, target_max_hp),
		"element": String(charms[id].get("element", "physical")),
		"id": id,
	}

## Slår den bärna defensiva charmen mot ett inkommande slag.
## Returnerar {triggered, prevented, id}.
func roll_defense(incoming: float) -> Dictionary:
	var id := equipped_defense
	if id == "" or not charms.has(id):
		return {"triggered": false, "prevented": 0.0, "id": ""}
	if randf() >= float(charms[id].get("chance", 0.0)):
		return {"triggered": false, "prevented": 0.0, "id": id}
	return {
		"triggered": true,
		"prevented": defense_reduction(id, incoming),
		"id": id,
	}

func reset() -> void:
	points = 0
	unlocked.clear()
	ranks.clear()
	equipped_offense = ""
	equipped_defense = ""
	points_changed.emit(points)
	charms_changed.emit()
