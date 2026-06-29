extends GutTest
## Testar gift-immunitet på monster: den rena regeln i CombatFormulas samt att
## datan taggar rätt varelser (odöda/elementarer + självgiftande).

const CF = preload("res://combat/combat_formulas.gd")

# --- monster_poison_immune: ren regel ---

func test_vanligt_monster_ar_inte_immunt():
	assert_false(CF.monster_poison_immune({"hp": 50, "atk": 8}),
		"ett vanligt levande monster ska kunna förgiftas")

func test_explicit_flagga_ger_immunitet():
	assert_true(CF.monster_poison_immune({"poison_immune": true}),
		"poison_immune=true ska ge immunitet")

func test_egen_gift_ability_ger_immunitet():
	# En varelse som själv utsöndrar gift kan inte förgiftas av gift.
	var data := {"ability": {"type": "poison", "chance": 0.2, "tick_dmg": 3}}
	assert_true(CF.monster_poison_immune(data),
		"självgiftande varelse ska vara immun mot gift")

func test_annan_ability_ger_inte_immunitet():
	var data := {"ability": {"type": "burn", "chance": 0.2, "tick_dmg": 3}}
	assert_false(CF.monster_poison_immune(data),
		"en brand-varelse ska inte vara giftimmun")

func test_tom_data_ar_inte_immun():
	assert_false(CF.monster_poison_immune({}))

# --- Dataintegritet: rätt monster är taggade ---

func test_ododa_ar_giftimmuna():
	for name in ["Skelett", "Ghoul", "Lich", "Vampyr", "Ökenmumie", "Nekromant"]:
		assert_true(MonsterDB.monsters.has(name), "%s saknas i monsterdatan" % name)
		assert_true(CF.monster_poison_immune(MonsterDB.monsters[name]),
			"%s (odöd) ska vara giftimmun" % name)

func test_elementarer_ar_giftimmuna():
	for name in ["Lavavarelse", "Isvarelse", "Kristallväktaren", "Ärkedemonen"]:
		assert_true(MonsterDB.monsters.has(name), "%s saknas i monsterdatan" % name)
		assert_true(CF.monster_poison_immune(MonsterDB.monsters[name]),
			"%s (elementar/konstruktion) ska vara giftimmun" % name)

func test_giftvarelser_ar_immuna_via_egen_ability():
	for name in ["Giftpadda", "Giftvävare", "Sumpvarelse"]:
		assert_true(CF.monster_poison_immune(MonsterDB.monsters[name]),
			"%s utsöndrar gift och ska därför vara giftimmun" % name)

func test_vanliga_djur_kan_forgiftas():
	# Råtta, varg m.fl. ska fortfarande bita på giftvapen.
	for name in ["Råtta", "Varg", "Skogsbjörn"]:
		assert_false(CF.monster_poison_immune(MonsterDB.monsters[name]),
			"%s ska kunna förgiftas" % name)
