class_name CombatFormulas
## Statiska skadeformler. Tibia-inspirerade, medvetet enkla.

## Kritisk träff: skadan multipliceras med detta vid crit.
const CRIT_MULTIPLIER := 1.5
const CRIT_BASE_CHANCE := 0.05    # grundchans innan skill/utrustning
const CRIT_PER_SKILL   := 0.002   # +0,2 %-enheter per nivå i stridsskillen
const CRIT_MAX_CHANCE  := 0.50    # tak så crit aldrig blir garanterat

## Kritträff-chans (0–1): grundchans + skill-skalning + utrustningsbonus.
static func crit_chance(skill: int, bonus := 0.0) -> float:
	return clampf(CRIT_BASE_CHANCE + skill * CRIT_PER_SKILL + bonus, 0.0, CRIT_MAX_CHANCE)

## Slår om en attack blir kritisk.
static func roll_crit(skill: int, bonus := 0.0) -> bool:
	return randf() < crit_chance(skill, bonus)

static func max_melee(level: int, skill: int, weapon_atk: int) -> int:
	return maxi(int(weapon_atk * (skill + 4) / 28.0 + level / 10.0), 1)

static func roll_melee(level: int, skill: int, weapon_atk: int) -> int:
	return randi_range(0, max_melee(level, skill, weapon_atk))

static func roll_monster(monster_atk: int) -> int:
	return randi_range(0, monster_atk)

static func mitigate(raw_dmg: int, shielding: int, armor: int) -> int:
	var reduction := randi_range(armor / 2, armor) + shielding / 3
	return maxi(raw_dmg - reduction, 0)

## Magiskada: runans kraft + magic-skill skalning, ±15% variation.
static func roll_magic(magic_level: int, rune_power: int) -> float:
	var base := rune_power + magic_level * 0.5
	return base * randf_range(0.85, 1.15)
## Bågskjutning: distance-skill + vapnets ATK, ±15% variation.
static func roll_ranged(distance_level: int, weapon_atk: int) -> float:
	var base := weapon_atk + distance_level * 0.4
	return base * randf_range(0.85, 1.15)
