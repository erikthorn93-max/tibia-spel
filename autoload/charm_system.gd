extends Node
## Autoload: CharmSystem. Charm-poäng tjänas när bestiarie-tiers fylls (TaskSystem)
## och spenderas på passiva charms. En offensiv + en defensiv charm kan bäras åt gången.
## Offensiva charms triggar bonusskada på träff; defensiva mildrar inkommande skada.

signal points_changed(points: int)
signal charms_changed

var charms: Dictionary = {}        # id -> def (data/charms.json)
var points := 0                    # ospenderade charm-poäng
var unlocked: Dictionary = {}      # id -> true (köpta charms)
var equipped_offense := ""         # aktiv offensiv charm-id ("" = ingen)
var equipped_defense := ""         # aktiv defensiv charm-id ("" = ingen)

func _init() -> void:
	var f := FileAccess.open("res://data/charms.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	charms = parsed if parsed is Dictionary else {}

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
	points_changed.emit(points)
	charms_changed.emit()
	return true

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

## Bonusskada en offensiv charm gör mot ett mål med givet max-HP (avrundat, minst 1).
func offense_damage(id: String, target_max_hp: float) -> int:
	if not charms.has(id):
		return 0
	return maxi(int(round(target_max_hp * float(charms[id].get("value", 0.0)))), 1)

## Skada som en defensiv charm mildrar bort från ett inkommande slag.
func defense_reduction(id: String, incoming: float) -> float:
	if not charms.has(id):
		return 0.0
	return maxf(incoming, 0.0) * float(charms[id].get("value", 0.0))

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
	equipped_offense = ""
	equipped_defense = ""
	points_changed.emit(points)
	charms_changed.emit()
