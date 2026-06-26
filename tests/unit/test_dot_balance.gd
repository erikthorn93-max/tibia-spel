extends GutTest
## Balansvakt för DoT-förmågor (poison/burn) efter monster-rebalanseringen.
## DoT-skada ignorerar rustning och har hög uptime, så trash-mobs hålls inom
## strama tak och bossar inom rimliga. Skyddar mot framtida regressioner där en
## lågnivå-mob (t.ex. ormar) åter blir hårdare än mycket högre monster.

func _dot_monsters() -> Array:
	var out: Array = []
	for name in MonsterDB.monsters:
		var ab: Dictionary = MonsterDB.monsters[name].get("ability", {})
		if String(ab.get("type", "")) == "poison" or String(ab.get("type", "")) == "burn":
			out.append(name)
	return out

func test_det_finns_dot_monster() -> void:
	assert_gt(_dot_monsters().size(), 0, "minst ett DoT-monster ska finnas")

func test_trash_dot_inom_tak() -> void:
	for name in _dot_monsters():
		var d: Dictionary = MonsterDB.monsters[name]
		if bool(d.get("boss", false)):
			continue
		var ab: Dictionary = d["ability"]
		assert_lte(float(ab["tick_dmg"]), 4.0, "%s: trash-DoT tick_dmg för hög" % name)
		assert_lte(float(ab["chance"]), 0.2, "%s: trash-DoT procchans för hög" % name)
		assert_lte(float(ab["duration"]), 6.0, "%s: trash-DoT duration för lång" % name)

func test_boss_dot_inom_tak() -> void:
	for name in _dot_monsters():
		var d: Dictionary = MonsterDB.monsters[name]
		if not bool(d.get("boss", false)):
			continue
		var ab: Dictionary = d["ability"]
		assert_lte(float(ab["tick_dmg"]), 14.0, "%s: boss-DoT tick_dmg för hög" % name)
		assert_lte(float(ab["chance"]), 0.35, "%s: boss-DoT procchans för hög" % name)
		assert_lte(float(ab["duration"]), 6.0, "%s: boss-DoT duration för lång" % name)

func test_lagniva_orm_ar_tam() -> void:
	# Direkt regressionsvakt mot den rapporterade buggen: startzonens orm ska
	# inte längre ticka oproportionerlig, rustnings-ignorerande gift.
	var ab: Dictionary = MonsterDB.monsters["Orm"]["ability"]
	assert_lte(float(ab["tick_dmg"]), 1.0, "Orm-gift ska vara tämjt")
	assert_lte(float(ab["chance"]), 0.12, "Orm-procchans ska vara låg")
