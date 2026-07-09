extends GutTest
## Dygnsljus + biomstämning i 3D-slicen: Atmosphere3D:s rena kurvor
## (sol/ambient/himmel över dygnet, biomdimma) och game3d:s applicering
## på DirectionalLight3D/Environment vid zonbyte.

const Game3DScene = preload("res://world/game3d.tscn")

const NOON := 0.5
const MIDNIGHT := 0.0
const DAWN := 0.25

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_weather: String

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_weather = WeatherSystem.current
	WeatherSystem.current = Weather.CLEAR   # dygnstesterna vill ha klart väder

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	WeatherSystem.current = _saved_weather

# ── Rena dygnskurvor ──────────────────────────────────────────────────────────

func test_darkness_extremes():
	assert_almost_eq(Atmosphere3D.darkness(MIDNIGHT), 1.0, 0.001)
	assert_almost_eq(Atmosphere3D.darkness(NOON), 0.0, 0.001)
	assert_almost_eq(Atmosphere3D.darkness(DAWN), 0.5, 0.001,
		"gryningen ligger mitt emellan")

func test_sun_energy_follows_daylight():
	assert_almost_eq(Atmosphere3D.sun_energy(NOON), Atmosphere3D.DAY_SUN, 0.001)
	assert_almost_eq(Atmosphere3D.sun_energy(MIDNIGHT), Atmosphere3D.NIGHT_SUN, 0.001)
	assert_gt(Atmosphere3D.sun_energy(MIDNIGHT), 0.0,
		"natten behåller ett svagt månsken — aldrig beckmörkt")

func test_sun_color_moods():
	var noon := Atmosphere3D.sun_color(NOON)
	assert_almost_eq(noon.r, 1.0, 0.01, "middagssolen är neutral")
	assert_almost_eq(noon.b, 1.0, 0.01)
	var dawn := Atmosphere3D.sun_color(DAWN)
	assert_gt(dawn.r, dawn.b, "gryningen är varm — mer rött än blått")
	var night := Atmosphere3D.sun_color(MIDNIGHT)
	assert_gt(night.b, night.r, "månskenet är svalt — mer blått än rött")

func test_sky_energy_nearly_off_at_night():
	assert_almost_eq(Atmosphere3D.sky_energy(NOON), 1.0, 0.001)
	assert_almost_eq(Atmosphere3D.sky_energy(MIDNIGHT), Atmosphere3D.NIGHT_SKY, 0.001)

# ── Biomdimma ─────────────────────────────────────────────────────────────────

func test_fog_only_for_themed_biomes():
	for biome in [Biome.SWAMP, Biome.CAVE, Biome.VOLCANO, Biome.ICE, Biome.DESERT]:
		var fog := Atmosphere3D.fog_for(biome)
		assert_false(fog.is_empty(), "%s ska ha dimma" % biome)
		assert_between(float(fog["density"]), 0.001, 0.1,
			"dimman är en nyans, aldrig en filt")
	for biome in [Biome.DEFAULT, Biome.TOWN, Biome.FOREST, Biome.INTERIOR]:
		assert_true(Atmosphere3D.fog_for(biome).is_empty(),
			"%s ska vara klart väder" % biome)

func test_swamp_fog_is_greenish():
	var c: Color = Atmosphere3D.fog_for(Biome.SWAMP)["color"]
	assert_gt(c.g, c.r, "träskdiset drar åt grönt")
	assert_gt(c.g, c.b)

func test_cave_caps_sky():
	assert_lt(Atmosphere3D.sky_cap(Biome.CAVE), 1.0,
		"grottor ser aldrig dagsljus")
	assert_almost_eq(Atmosphere3D.sky_cap(Biome.FOREST), 1.0, 0.001)

# ── game3d: applicering ───────────────────────────────────────────────────────

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func test_surface_zone_has_clear_weather():
	var g := _boot()
	g.load_zone("thais_fields")
	assert_false(g._env.fog_enabled, "thais_fields (skog) ska vara klart")
	assert_almost_eq(g._sky_cap, 1.0, 0.001)

func test_dungeon_gets_cave_fog_and_dim_sky():
	var g := _boot()
	g.enter_dungeon("katakomber")
	assert_true(g._env.fog_enabled, "dungeon (grotta) ska ha dimma")
	assert_almost_eq(g._env.fog_density, float(Atmosphere3D.fog_for(Biome.CAVE)["density"]), 0.001)
	assert_lt(g._sky_cap, 1.0)
	g.load_zone("thais_fields")
	assert_false(g._env.fog_enabled, "tillbaka på ytan ska dimman släckas")

func test_daylight_applied_to_sun_and_env():
	var g := _boot()
	g._update_daylight()
	var f: float = TimeOfDay.day_fraction
	assert_almost_eq(g._sun.light_energy, Atmosphere3D.sun_energy(f), 0.01)
	assert_almost_eq(g._env.ambient_light_energy, Atmosphere3D.ambient_energy(f), 0.01)
	assert_almost_eq(g._env.background_energy_multiplier,
		Atmosphere3D.sky_energy(f) * g._sky_cap, 0.01)
