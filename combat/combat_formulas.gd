class_name CombatFormulas
## Statiska skadeformler. Tibia-inspirerade, medvetet enkla.

static func max_melee(level: int, skill: int, weapon_atk: int) -> int:
	return maxi(int(weapon_atk * (skill + 4) / 28.0 + level / 10.0), 1)

static func roll_melee(level: int, skill: int, weapon_atk: int) -> int:
	return randi_range(0, max_melee(level, skill, weapon_atk))

static func roll_monster(monster_atk: int) -> int:
	return randi_range(0, monster_atk)

static func mitigate(raw_dmg: int, shielding: int, armor: int) -> int:
	var reduction := randi_range(armor / 2, armor) + shielding / 3
	return maxi(raw_dmg - reduction, 0)
