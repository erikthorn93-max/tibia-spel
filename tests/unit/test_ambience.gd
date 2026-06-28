extends GutTest
## Tester för ambient-ljudbäddens profil-logik (ren funktion). Själva bruset är
## slumpat och testas inte; vi verifierar volym/klangval per väder & biom.

const Ambience = preload("res://autoload/ambience.gd")
const Weather = preload("res://ui/weather.gd")
const Biome = preload("res://ui/biome.gd")

func test_clear_outdoor_is_silent():
	assert_eq(Ambience.profile(Weather.CLEAR, Biome.TOWN)["gain"], 0.0)
	assert_eq(Ambience.profile(Weather.CLEAR, Biome.FOREST)["gain"], 0.0)

func test_rain_is_audible():
	assert_gt(Ambience.profile(Weather.RAIN, Biome.TOWN)["gain"], 0.0)

func test_storm_is_louder_than_rain():
	# Ovädret ska höras tydligare än vanligt regn — men fortfarande inom taket.
	assert_gt(Ambience.profile(Weather.STORM, Biome.TOWN)["gain"],
		Ambience.profile(Weather.RAIN, Biome.TOWN)["gain"])

func test_storm_overrides_biome():
	# Skyfallet hörs överallt, oavsett bakomliggande biom.
	assert_eq(Ambience.profile(Weather.STORM, Biome.CAVE),
		Ambience.profile(Weather.STORM, Biome.FOREST))

func test_weather_overrides_biome():
	# Regn i en grotta (otroligt men logiskt): vädret vinner ljudbilden.
	assert_eq(Ambience.profile(Weather.RAIN, Biome.CAVE),
		Ambience.profile(Weather.RAIN, Biome.TOWN))

func test_cave_and_volcano_have_room_tone_when_clear():
	assert_gt(Ambience.profile(Weather.CLEAR, Biome.CAVE)["gain"], 0.0)
	assert_gt(Ambience.profile(Weather.CLEAR, Biome.VOLCANO)["gain"], 0.0)

func test_rain_is_brighter_than_cave_rumble():
	# Högre cutoff = ljusare sus; regn ska vara ljusare än grottans rummel.
	assert_gt(Ambience.profile(Weather.RAIN, Biome.TOWN)["cutoff"],
		Ambience.profile(Weather.CLEAR, Biome.CAVE)["cutoff"])

func test_volcano_is_deepest():
	var vol: float = Ambience.profile(Weather.CLEAR, Biome.VOLCANO)["cutoff"]
	var cave: float = Ambience.profile(Weather.CLEAR, Biome.CAVE)["cutoff"]
	assert_lt(vol, cave, "vulkanen ska mullra djupast")

func test_all_gains_stay_low_and_safe():
	# Bädden ska anas, aldrig dominera — inga gain över 0.2.
	for w in Weather.TYPES:
		for b in [Biome.TOWN, Biome.CAVE, Biome.VOLCANO, Biome.ICE, Biome.FOREST]:
			var g: float = Ambience.profile(w, b)["gain"]
			assert_between(g, 0.0, 0.2, "%s/%s" % [w, b])
