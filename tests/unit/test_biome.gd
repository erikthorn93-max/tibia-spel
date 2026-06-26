extends GutTest
## Tester för biom-klassning, färggradering och ambient-partikelprofiler.

const Biome = preload("res://ui/biome.gd")

# ── Klassning ──

func test_classify_underground_zones_as_cave():
	for z in ["cave", "dwarf_mine", "thais_gemcavern", "spider_crypt",
			"minotaur_maze", "thais_jail", "dungeon:ice_cave"]:
		assert_eq(Biome.classify(z), Biome.CAVE, z)

func test_classify_swamp_and_dimmoren():
	assert_eq(Biome.classify("swamp"), Biome.SWAMP)
	assert_eq(Biome.classify("dimmoren"), Biome.SWAMP)

func test_classify_hot_zones_as_volcano():
	assert_eq(Biome.classify("volcano"), Biome.VOLCANO)
	assert_eq(Biome.classify("demon_temple"), Biome.VOLCANO)
	assert_eq(Biome.classify("orc_rift"), Biome.VOLCANO)
	assert_eq(Biome.classify("drakboet"), Biome.VOLCANO)

func test_classify_ice_and_desert():
	assert_eq(Biome.classify("ice"), Biome.ICE)
	assert_eq(Biome.classify("desert"), Biome.DESERT)

func test_classify_outdoor_nature_as_forest():
	for z in ["forest", "thais_wilds", "thais_heights", "thais_fields", "urskogens_hjarta"]:
		assert_eq(Biome.classify(z), Biome.FOREST, z)

func test_classify_interiors():
	for z in ["knight_guild", "frodo_inn", "tibianus_temple", "thais_depot_int"]:
		assert_eq(Biome.classify(z), Biome.INTERIOR, z)

func test_classify_town_outdoors():
	assert_eq(Biome.classify("town"), Biome.TOWN)
	assert_eq(Biome.classify("coast"), Biome.TOWN)

func test_classify_unknown_is_default():
	assert_eq(Biome.classify("whatever_42"), Biome.DEFAULT)

func test_classify_is_case_insensitive():
	assert_eq(Biome.classify("VOLCANO"), Biome.VOLCANO)

# ── Färggradering ──

func test_default_and_town_grade_invisible():
	assert_eq(Biome.grade(Biome.DEFAULT).a, 0.0)
	assert_eq(Biome.grade(Biome.TOWN).a, 0.0)

func test_grades_are_subtle_never_a_blanket():
	for b in [Biome.CAVE, Biome.SWAMP, Biome.DESERT, Biome.ICE,
			Biome.VOLCANO, Biome.FOREST, Biome.INTERIOR]:
		assert_lt(Biome.grade(b).a, 0.3, "%s ska bara vara en nyans" % b)

func test_cave_grade_is_cool():
	var c := Biome.grade(Biome.CAVE)
	assert_gt(c.b, c.r, "grotta ska vara svalt blå")

func test_volcano_grade_is_hot():
	var c := Biome.grade(Biome.VOLCANO)
	assert_gt(c.r, c.b, "vulkan ska glöda varmt rött")

func test_swamp_grade_is_green():
	var c := Biome.grade(Biome.SWAMP)
	assert_gt(c.g, c.r, "träsk ska vara grönt")
	assert_gt(c.g, c.b)

# ── Ambient-partiklar ──

func test_volcano_embers_always():
	assert_eq(Biome.ambient_kind(Biome.VOLCANO, true), "embers")
	assert_eq(Biome.ambient_kind(Biome.VOLCANO, false), "embers")

func test_cave_dust_always():
	assert_eq(Biome.ambient_kind(Biome.CAVE, false), "dust")

func test_fireflies_only_at_night():
	assert_eq(Biome.ambient_kind(Biome.FOREST, true), "fireflies")
	assert_eq(Biome.ambient_kind(Biome.FOREST, false), "none")

func test_interior_has_no_ambient():
	assert_eq(Biome.ambient_kind(Biome.INTERIOR, true), "none")

func test_embers_rise_dust_falls():
	assert_lt(Biome.ambient_velocity("embers").y, 0.0, "glöd ska stiga")
	assert_gt(Biome.ambient_velocity("dust").y, 0.0, "damm ska sjunka")

func test_ambient_counts_are_sparse():
	# Stämning, inte snöstorm: glesare än regn (regn ~area/950).
	var rain_density := int(100000.0 / 950.0)
	assert_lt(Biome.ambient_count("fireflies", 100000.0), rain_density)

func test_none_kind_has_no_particles_and_no_velocity():
	assert_eq(Biome.ambient_count("none", 1000000.0), 0)
	assert_eq(Biome.ambient_velocity("none"), Vector2.ZERO)

func test_only_fireflies_and_embers_twinkle():
	assert_true(Biome.ambient_twinkles("fireflies"))
	assert_true(Biome.ambient_twinkles("embers"))
	assert_false(Biome.ambient_twinkles("dust"))
