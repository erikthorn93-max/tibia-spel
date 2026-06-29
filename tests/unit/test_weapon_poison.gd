extends GutTest
## Testar vapnens giftbeläggning: proc-logiken i CombatFormulas samt att
## giftvapnen i datan bär giltiga ability-block som faktiskt kan förgifta.

const CF = preload("res://combat/combat_formulas.gd")

# --- weapon_poison_proc: ren proc-logik ---

func test_icke_giftvapen_proccar_aldrig():
	var res := CF.weapon_poison_proc({}, 0.0)
	assert_false(res.get("apply", false), "vapen utan ability ska aldrig förgifta")

func test_fel_ability_typ_proccar_inte():
	var res := CF.weapon_poison_proc({"type": "stun", "chance": 1.0}, 0.0)
	assert_false(res.get("apply", false), "endast type=poison ska kunna förgifta")

func test_proc_traffar_under_chansen():
	var ability := {"type": "poison", "chance": 0.25, "duration": 6.0, "tick_dmg": 6.0}
	var res := CF.weapon_poison_proc(ability, 0.10)   # roll < chance
	assert_true(res["apply"], "roll under chansen ska proca")
	assert_almost_eq(float(res["duration"]), 6.0, 0.01)
	assert_almost_eq(float(res["tick_dmg"]), 6.0, 0.01)

func test_proc_missar_over_chansen():
	var ability := {"type": "poison", "chance": 0.25, "duration": 6.0, "tick_dmg": 6.0}
	var res := CF.weapon_poison_proc(ability, 0.40)   # roll >= chance
	assert_false(res["apply"], "roll över chansen ska missa")

func test_proc_pa_exakt_chansen_missar():
	# roll == chance ska INTE proca (>= räknas som miss) — definierat beteende.
	var ability := {"type": "poison", "chance": 0.30, "duration": 5.0, "tick_dmg": 4.0}
	assert_false(CF.weapon_poison_proc(ability, 0.30)["apply"])

func test_proc_anvander_default_om_falt_saknas():
	var res := CF.weapon_poison_proc({"type": "poison", "chance": 1.0}, 0.0)
	assert_true(res["apply"])
	assert_almost_eq(float(res["duration"]), 5.0, 0.01, "default duration")
	assert_almost_eq(float(res["tick_dmg"]), 4.0, 0.01, "default tick_dmg")

# --- Dataintegritet: giftvapnen i item-databasen ---

func test_giftvapnen_har_giltig_poison_ability():
	for wid in ["venom_blade", "venomfang_blade"]:
		assert_true(ItemDB.items.has(wid), "%s saknas i item-databasen" % wid)
		var ab: Dictionary = ItemDB.items[wid].get("ability", {})
		assert_eq(String(ab.get("type", "")), "poison", "%s ska ha poison-ability" % wid)
		assert_gt(float(ab.get("chance", 0.0)), 0.0, "%s måste ha proc-chans > 0" % wid)
		assert_gt(float(ab.get("tick_dmg", 0.0)), 0.0, "%s måste göra giftskada" % wid)
		assert_gt(float(ab.get("duration", 0.0)), 0.0, "%s gift måste vara > 0s" % wid)

func test_uppgraderat_giftvapen_ar_starkare():
	# Gifthuggsklingan ska sticka hårdare än Giftklingan på alla axlar.
	var basic: Dictionary = ItemDB.items["venom_blade"]["ability"]
	var upgr: Dictionary = ItemDB.items["venomfang_blade"]["ability"]
	assert_gt(float(upgr["chance"]), float(basic["chance"]), "högre proc-chans")
	assert_gt(float(upgr["tick_dmg"]), float(basic["tick_dmg"]), "hårdare gift")
