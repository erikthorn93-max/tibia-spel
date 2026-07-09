extends GutTest
## Ambient-partiklar i 3D-slicen: samma Biome-regler som 2D-overlayn
## (typ per biom+natt, väder äger stämningen), en MultiMesh-batch,
## drift/wrap i spelarlådan och inkoppling i game3d.

const Game3DScene = preload("res://world/game3d.tscn")

var _saved_model: ZoneModel
var _saved_weather: String
var _saved_elapsed: float
var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud

func before_each():
	_saved_model = World.zone_model
	_saved_weather = WeatherSystem.current
	_saved_elapsed = TimeOfDay._elapsed
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud

func after_each():
	World.zone_model = _saved_model
	WeatherSystem.current = _saved_weather
	TimeOfDay._elapsed = _saved_elapsed
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud

# ── Rena regler ───────────────────────────────────────────────────────────────

func test_resolve_kind_follows_biome_and_night():
	assert_eq(AmbientParticles3D.resolve_kind("volcano_fields", false, Weather.CLEAR),
		"embers", "vulkanen glöder dygnet runt")
	assert_eq(AmbientParticles3D.resolve_kind("dungeon:katakomber", false, Weather.CLEAR),
		"dust", "grottdamm dygnet runt")
	assert_eq(AmbientParticles3D.resolve_kind("thais_fields", true, Weather.CLEAR),
		"fireflies", "skogen får eldflugor om natten")
	assert_eq(AmbientParticles3D.resolve_kind("thais_fields", false, Weather.CLEAR),
		"none", "inga eldflugor på dagen")

func test_weather_owns_the_mood():
	assert_eq(AmbientParticles3D.resolve_kind("thais_fields", true, Weather.RAIN),
		"none", "regn tystar ambientpartiklarna, som 2D")
	assert_eq(AmbientParticles3D.resolve_kind("volcano_fields", false, Weather.SNOW),
		"none")

func test_vel3_directions():
	assert_gt(AmbientParticles3D.vel3("embers").y, 0.0, "glödflagor stiger")
	assert_lt(AmbientParticles3D.vel3("dust").y, 0.0, "damm sjunker")
	assert_eq(AmbientParticles3D.vel3("none"), Vector3.ZERO)

func test_count_is_sparse_but_present():
	for k in ["fireflies", "embers", "dust"]:
		assert_between(AmbientParticles3D.count_for(k), 10, 60,
			"%s: gles stämning, inte snöstorm" % k)
	assert_eq(AmbientParticles3D.count_for("none"), 0)

func test_wrap_local_keeps_particles_in_box():
	var b := AmbientParticles3D.BOX
	var p := AmbientParticles3D.wrap_local(Vector3(b.x, -1.0, -b.z))
	assert_between(p.x, -b.x * 0.5, b.x * 0.5)
	assert_between(p.y, 0.0, b.y)
	assert_between(p.z, -b.z * 0.5, b.z * 0.5)

# ── Batch-bygget ──────────────────────────────────────────────────────────────

func test_rebuild_creates_single_multimesh_batch():
	var a := AmbientParticles3D.new()
	add_child_autofree(a)
	a._rebuild("embers")
	assert_eq(a.kind, "embers")
	assert_not_null(a._mmi, "en MultiMesh-batch — en draw call")
	assert_eq(a._mmi.multimesh.instance_count, AmbientParticles3D.count_for("embers"))
	assert_true(a._mmi.multimesh.use_colors, "twinkle sker via instansfärg")
	assert_eq(a._mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_rebuild_none_clears_batch():
	var a := AmbientParticles3D.new()
	add_child_autofree(a)
	a._rebuild("dust")
	assert_not_null(a._mmi)
	a._rebuild("none")
	assert_null(a._mmi, "'none' ska riva batchen")
	assert_eq(a._pos.size(), 0)

func test_process_resolves_kind_and_drifts():
	var m := ZoneModel.new()
	m.zone_id = "volcano_fields"
	World.zone_model = m
	WeatherSystem.current = Weather.CLEAR
	var a := AmbientParticles3D.new()
	add_child_autofree(a)
	a._process(0.016)
	assert_eq(a.kind, "embers", "zonmodellen ska styra typen")
	a._pos[0] = Vector3.ZERO   # känd startpunkt — ingen wrapp i vägen
	a._process(0.5)
	assert_almost_eq(a._pos[0].y, AmbientParticles3D.vel3("embers").y * 0.5, 0.01,
		"glödflagor stiger uppåt med Biome-farten")
	assert_ne(a._pos[0].x, 0.0, "sidledesvandringen ska ge liv åt driften")

# ── game3d: inkoppling ────────────────────────────────────────────────────────

func test_game3d_has_ambient_particles():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	assert_not_null(g._ambient, "game3d ska ha ambientpartikel-noden")
	WeatherSystem.current = Weather.CLEAR
	TimeOfDay._elapsed = 0.0   # midnatt → natt
	g._ambient._process(0.016)
	assert_eq(g._ambient.kind, "fireflies",
		"thais_fields om natten i klart väder ska ha eldflugor")
