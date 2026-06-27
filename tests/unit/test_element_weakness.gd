extends GutTest
## Regressionsvakt för charm-elementtaktiken: monstrens "element_mod" måste hålla
## sig till de fyra giltiga charm-elementen, och varje boss måste ha minst en
## svaghet (>1) så att eld/energi/död/fysisk-taktiken alltid biter på höjdpunkterna.

const GILTIGA := ["fire", "energy", "death", "physical"]

func test_element_mod_anvander_bara_giltiga_element() -> void:
	# En felstavad nyckel (t.ex. "ice") tystas annars: element_modifier faller
	# tillbaka på 1.0 och svagheten försvinner spårlöst. Fånga det här.
	var ogiltiga: Array = []
	for mname in MonsterDB.monsters:
		var mods = MonsterDB.monsters[mname].get("element_mod", {})
		if mods is Dictionary:
			for el in mods.keys():
				if not GILTIGA.has(String(el)):
					ogiltiga.append("%s: %s" % [mname, el])
	assert_eq(ogiltiga, [], "ogiltiga element_mod-nycklar: %s" % str(ogiltiga))

func test_element_mod_varden_ar_rimliga() -> void:
	# Multiplikatorer ska ligga i ett vettigt spann; >3 eller negativt är ett
	# datafel snarare än balansval (0 = immun är tillåtet med flit).
	var orimliga: Array = []
	for mname in MonsterDB.monsters:
		var mods = MonsterDB.monsters[mname].get("element_mod", {})
		if mods is Dictionary:
			for el in mods.keys():
				var v := float(mods[el])
				if v < 0.0 or v > 3.0:
					orimliga.append("%s.%s=%s" % [mname, el, str(v)])
	assert_eq(orimliga, [], "orimliga element_mod-värden: %s" % str(orimliga))

func test_alla_bossar_har_en_svaghet() -> void:
	# Bossar är questmål — utan en svaghet (>1) saknar charm-taktiken mening mot
	# dem och vissa kan bli onödigt sega.
	var utan_svaghet: Array = []
	for mname in MonsterDB.monsters:
		var d = MonsterDB.monsters[mname]
		if not bool(d.get("boss", false)):
			continue
		var mods = d.get("element_mod", {})
		var har_svaghet := false
		if mods is Dictionary:
			for el in mods.keys():
				if float(mods[el]) > 1.0:
					har_svaghet = true
					break
		if not har_svaghet:
			utan_svaghet.append(mname)
	assert_eq(utan_svaghet, [], "bossar utan svaghet (>1): %s" % str(utan_svaghet))

func test_element_modifier_laser_data_korrekt() -> void:
	# Sanity: hjälparen ska returnera monstrets värde och 1.0 för okänt element.
	var cs = load("res://autoload/charm_system.gd")
	var def := {"element_mod": {"fire": 1.5, "death": 0.3}}
	assert_eq(cs.element_modifier(def, "fire"), 1.5)
	assert_eq(cs.element_modifier(def, "death"), 0.3)
	assert_eq(cs.element_modifier(def, "energy"), 1.0)
	assert_eq(cs.element_modifier({}, "fire"), 1.0)
