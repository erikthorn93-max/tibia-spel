class_name CombatStance
## Stridsställningar (OSRS-inspirerat): ett taktiskt val mellan skada och försvar
## i auto-attack-striden. Rena funktioner → testbara och utan bieffekter. Spelaren
## växlar ställning i fält; valet sparas i GameState.combat_stance.
##
## Offensiv  — slår hårdare men gardar sämre (glaskanon).
## Balanserad — neutral (motsvarar spelets tidigare beteende).
## Defensiv  — slår mjukare men tål mer (tank).

const OFFENSIVE := "offensive"
const BALANCED := "balanced"
const DEFENSIVE := "defensive"
const STANCES := [OFFENSIVE, BALANCED, DEFENSIVE]
const DEFAULT := BALANCED

## Säkrar att en sträng är en känd ställning — annars DEFAULT.
static func normalize(s: String) -> String:
	return s if s in STANCES else DEFAULT

## Nästa ställning i cykeln (för växel-knappen): off → bal → def → off …
static func cycle(s: String) -> String:
	var i := STANCES.find(normalize(s))
	return STANCES[(i + 1) % STANCES.size()]

## Multiplikator på spelarens utdelade vapenskada (närstrid + bågskytte).
static func damage_mult(s: String) -> float:
	match normalize(s):
		OFFENSIVE: return 1.15
		DEFENSIVE: return 0.85
		_:         return 1.0

## Rustnings-ekvivalent som adderas (eller dras) vid mitigering av inkommande
## skada. Defensiv gardar bättre; offensiv lämnar en mer öppen.
static func mitigation_bonus(s: String) -> int:
	match normalize(s):
		OFFENSIVE: return -6
		DEFENSIVE: return 10
		_:         return 0

## Kort svenskt namn för HUD-indikatorn.
static func label(s: String) -> String:
	match normalize(s):
		OFFENSIVE: return "Offensiv"
		DEFENSIVE: return "Defensiv"
		_:         return "Balanserad"

## Symbol för HUD-indikatorn.
static func icon(s: String) -> String:
	match normalize(s):
		OFFENSIVE: return "⚔"
		DEFENSIVE: return "🛡"
		_:         return "⚖"
