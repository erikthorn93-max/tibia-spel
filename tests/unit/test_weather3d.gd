extends GutTest
## Väder i 3D-slicen: nederbördsbatchen (WeatherParticles3D, samma
## Weather-regler som 2D-overlayn), väderdimma/ljusdämpning i miljön
## (vädret äger stämningen över biomdimman) och blixt & dunder vid åska.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_model: ZoneModel
var _saved_weather: String
var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_model = World.zone_model
	_saved_weather = WeatherSystem.current
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	WeatherSystem.current = Weather.CLEAR

func after_each():
	World.zone_model = _saved_model
	WeatherSystem.current = _saved_weather
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

# ── Rena hjälpare ─────────────────────────────────────────────────────────────

func test_vel3_falls_downward():
	assert_lt(WeatherParticles3D.vel3(Weather.RAIN).y, 0.0, "regn faller")
	assert_lt(WeatherParticles3D.vel3(Weather.STORM).y,
		WeatherParticles3D.vel3(Weather.RAIN).y, "åskskyfall faller snabbare")
	assert_lt(WeatherParticles3D.vel3(Weather.SNOW).y, 0.0)
	assert_gt(WeatherParticles3D.vel3(Weather.SNOW).y,
		WeatherParticles3D.vel3(Weather.RAIN).y, "snö dalar långsammare än regn")

func test_count_follows_2d_density():
	assert_gt(WeatherParticles3D.count_for(Weather.STORM),
		WeatherParticles3D.count_for(Weather.RAIN), "skyfallet är tätast")
	assert_gt(WeatherParticles3D.count_for(Weather.RAIN),
		WeatherParticles3D.count_for(Weather.SNOW))
	assert_eq(WeatherParticles3D.count_for(Weather.FOG), 0,
		"dimma har inga partiklar — env-dimman äger den")
	assert_eq(WeatherParticles3D.count_for(Weather.CLEAR), 0)

func test_quad_size_streaks_and_flakes():
	var rain := WeatherParticles3D.quad_size(Weather.RAIN)
	assert_gt(rain.y, rain.x, "regn är en fallstrimma — hög och smal")
	var storm := WeatherParticles3D.quad_size(Weather.STORM)
	assert_gt(storm.y, rain.y, "åskans strimmor är längre")
	var snow := WeatherParticles3D.quad_size(Weather.SNOW)
	assert_eq(snow.x, snow.y, "snöflingan är rund (kvadratisk quad)")

# ── Batchen ───────────────────────────────────────────────────────────────────

func test_rebuild_creates_batch_with_weather_color():
	var w := WeatherParticles3D.new()
	add_child_autofree(w)
	w._rebuild(Weather.RAIN)
	assert_not_null(w._mmi, "en MultiMesh-batch — en draw call")
	assert_eq(w._mmi.multimesh.instance_count,
		WeatherParticles3D.count_for(Weather.RAIN))
	var mat: StandardMaterial3D = (w._mmi.multimesh.mesh as QuadMesh).material
	assert_almost_eq(mat.albedo_color.a, Weather.particle_alpha(Weather.RAIN), 0.001,
		"partikelfärg + alpha ur Weather-hjälparen")

func test_clear_and_fog_have_no_batch():
	var w := WeatherParticles3D.new()
	add_child_autofree(w)
	w._rebuild(Weather.RAIN)
	assert_not_null(w._mmi)
	w._rebuild(Weather.FOG)
	assert_null(w._mmi, "dimma ska riva nederbördsbatchen")

func test_process_resolves_zone_weather_and_falls():
	var m := ZoneModel.new()
	m.zone_id = "ice"
	m.weather = Weather.SNOW
	World.zone_model = m
	var w := WeatherParticles3D.new()
	add_child_autofree(w)
	w._process(0.016)
	assert_eq(w.weather, Weather.SNOW, "zonens fasta väder ska styra")
	w._pos[0] = Vector3(0, 5.0, 0)   # känd startpunkt — ingen wrapp i vägen
	w._process(0.5)
	assert_lt(w._pos[0].y, 5.0, "flingorna ska dala nedåt")

func test_dynamic_zone_follows_ambient_weather():
	var m := ZoneModel.new()
	m.zone_id = "thais_fields"
	m.weather = Weather.DYNAMIC
	World.zone_model = m
	var w := WeatherParticles3D.new()
	add_child_autofree(w)
	WeatherSystem.current = Weather.RAIN
	w._process(0.016)
	assert_eq(w.weather, Weather.RAIN, "dynamisk zon följer omgivningsvädret")
	WeatherSystem.current = Weather.CLEAR
	w._process(0.016)
	assert_eq(w.weather, Weather.CLEAR)
	assert_null(w._mmi, "klart väder ska riva batchen")

# ── game3d: miljö + blixtar ───────────────────────────────────────────────────

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

func test_weather_fog_overrides_biome_fog():
	var g := _boot()
	g.load_zone("dimmoren")   # fast dimväder, träskbiom
	g._update_daylight()
	assert_true(g._env.fog_enabled)
	assert_almost_eq(g._env.fog_density,
		float(Atmosphere3D.WEATHER_FOG[Weather.FOG]["density"]), 0.001,
		"dimvädret ska äga dimman, inte träskbiomet")

func test_storm_darkens_the_world():
	var g := _boot()
	g.load_zone("thais_fields")
	g._update_daylight()
	var clear_energy: float = g._sun.light_energy
	g.load_zone("thais_fishing_isle")   # fast åskväder
	g._flash_t = 99.0   # mät basljuset mellan blixtarna
	g._update_daylight()
	assert_almost_eq(g._sun.light_energy,
		clear_energy * Atmosphere3D.weather_light_scale(Weather.STORM), 0.01,
		"åskan ska dämpa solljuset")

func test_lightning_flash_brightens_and_fades():
	var g := _boot()
	g.load_zone("thais_fishing_isle")
	g._storm = true
	g._strike_in = 0.0   # tvinga nedslag nu
	var flash: float = g._tick_lightning(true, 0.016)
	assert_gt(flash, 0.5, "nedslaget ska ge en skarp blixt")
	assert_gt(g._strike_in, 0.0, "nästa nedslag ska schemaläggas")
	assert_gt(g._thunder_in, 0.0, "dundret ska vänta efter blixten")
	var later: float = g._tick_lightning(true, Weather.FLASH_DUR)
	assert_lt(later, flash, "blixten ska klinga av")

func test_no_lightning_in_clear_weather():
	var g := _boot()
	g.load_zone("thais_fields")
	assert_almost_eq(g._tick_lightning(false, 0.016), 0.0, 0.001,
		"inga blixtar utan åska")

func test_game3d_has_weather_particles():
	var g := _boot()
	assert_not_null(g._weather_fx, "game3d ska ha nederbördsnoden")
	g.load_zone("ice")   # fast snöväder
	g._weather_fx._process(0.016)
	assert_eq(g._weather_fx.weather, Weather.SNOW,
		"snözonen ska ge snöfall i 3D")
