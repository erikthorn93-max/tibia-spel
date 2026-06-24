extends GutTest
## Tester för vädersystemet (ui/weather.gd): typvalidering, färgtoner,
## partikelegenskaper och kantåtervinning.

const Weather = preload("res://ui/weather.gd")

# ── Typvalidering ──

func test_normalize_keeps_valid_types():
	for w in Weather.TYPES:
		assert_eq(Weather.normalize(w), w)

func test_normalize_falls_back_to_clear():
	assert_eq(Weather.normalize("blizzard"), Weather.CLEAR)
	assert_eq(Weather.normalize(""), Weather.CLEAR)

func test_from_zone_data_reads_field():
	assert_eq(Weather.from_zone_data({"weather": "rain"}), Weather.RAIN)

func test_from_zone_data_defaults_clear():
	assert_eq(Weather.from_zone_data({"name": "X"}), Weather.CLEAR)

func test_from_zone_data_sanitizes_garbage():
	assert_eq(Weather.from_zone_data({"weather": "??"}), Weather.CLEAR)

func test_from_zone_data_allows_dynamic():
	assert_eq(Weather.from_zone_data({"weather": "dynamic"}), Weather.DYNAMIC)

func test_render_normalize_rejects_dynamic():
	# Overlayn ritar aldrig "dynamic" direkt — den måste lösas upp först.
	assert_eq(Weather.normalize(Weather.DYNAMIC), Weather.CLEAR)

# ── Upplösning (dynamic → omgivningsväder) ──

func test_resolve_dynamic_follows_ambient():
	assert_eq(Weather.resolve(Weather.DYNAMIC, Weather.RAIN), Weather.RAIN)
	assert_eq(Weather.resolve(Weather.DYNAMIC, Weather.CLEAR), Weather.CLEAR)

func test_resolve_fixed_ignores_ambient():
	assert_eq(Weather.resolve(Weather.FOG, Weather.RAIN), Weather.FOG)
	assert_eq(Weather.resolve(Weather.SNOW, Weather.CLEAR), Weather.SNOW)

# ── Omgivningsvädrets övergångar ──

func test_ambient_rain_clears_on_low_roll():
	assert_eq(Weather.next_ambient(Weather.RAIN, 0.0), Weather.CLEAR)

func test_ambient_rain_persists_on_high_roll():
	assert_eq(Weather.next_ambient(Weather.RAIN, 0.99), Weather.RAIN)

func test_ambient_clear_can_start_raining():
	assert_eq(Weather.next_ambient(Weather.CLEAR, 0.0), Weather.RAIN)

func test_ambient_clear_usually_stays_clear():
	assert_eq(Weather.next_ambient(Weather.CLEAR, 0.99), Weather.CLEAR)

func test_ambient_pool_is_temperate():
	# Dynamiskt väder ska aldrig ge dimma eller snö.
	assert_false(Weather.SNOW in Weather.AMBIENT_POOL)
	assert_false(Weather.FOG in Weather.AMBIENT_POOL)

# ── Nederbörd ──

func test_precip_only_rain_and_snow():
	assert_true(Weather.has_precip(Weather.RAIN))
	assert_true(Weather.has_precip(Weather.SNOW))
	assert_false(Weather.has_precip(Weather.FOG))
	assert_false(Weather.has_precip(Weather.CLEAR))

# ── Färgtvätt ──

func test_clear_tint_invisible():
	assert_eq(Weather.tint(Weather.CLEAR).a, 0.0)

func test_rain_tint_is_cool_and_visible():
	var c := Weather.tint(Weather.RAIN)
	assert_gt(c.a, 0.0, "regn ska synas")
	assert_gt(c.b, c.r, "regn ska vara svalt (blå > röd)")

func test_fog_tint_is_pale_and_strongest():
	var fog := Weather.tint(Weather.FOG)
	assert_gt(fog.r + fog.g + fog.b, 1.5, "dimma ska vara blek/ljus")
	assert_gt(fog.a, Weather.tint(Weather.RAIN).a, "dimma ska vara tätast")
	assert_gt(fog.a, Weather.tint(Weather.SNOW).a)

func test_snow_tint_is_bright_and_subtle():
	var c := Weather.tint(Weather.SNOW)
	assert_gt(c.r + c.g + c.b, 2.0, "snö-dis ska vara ljust")
	assert_lt(c.a, 0.2, "snö-dis ska vara subtilt")

# ── Partiklar ──

func test_particle_count_scales_with_area():
	assert_gt(Weather.particle_count(Weather.RAIN, 1_000_000.0),
		Weather.particle_count(Weather.RAIN, 100_000.0))

func test_clear_and_fog_have_no_particles():
	assert_eq(Weather.particle_count(Weather.CLEAR, 1_000_000.0), 0)
	assert_eq(Weather.particle_count(Weather.FOG, 1_000_000.0), 0)

func test_rain_is_denser_than_snow():
	var area := 1_000_000.0
	assert_gt(Weather.particle_count(Weather.RAIN, area),
		Weather.particle_count(Weather.SNOW, area))

func test_rain_falls_faster_and_steeper_than_snow():
	var rain := Weather.velocity(Weather.RAIN)
	var snow := Weather.velocity(Weather.SNOW)
	assert_gt(rain.y, snow.y, "regn ska falla snabbare")
	assert_gt(rain.y, 0.0, "nederbörd ska falla nedåt")

func test_clear_has_no_velocity():
	assert_eq(Weather.velocity(Weather.CLEAR), Vector2.ZERO)

func test_rain_has_streak_snow_is_dot():
	assert_gt(Weather.streak_length(Weather.RAIN), 0.0)
	assert_eq(Weather.streak_length(Weather.SNOW), 0.0)

func test_snow_more_opaque_than_rain():
	assert_gt(Weather.particle_alpha(Weather.SNOW), Weather.particle_alpha(Weather.RAIN))

# ── Kantåtervinning ──

func test_wrap_below_bottom_returns_to_top():
	var p := Weather.wrap(Vector2(50, 110), 200, 100)
	assert_lt(p.y, 0.0, "partikel under botten ska hamna ovanför toppen")

func test_wrap_left_edge_enters_from_right():
	var p := Weather.wrap(Vector2(-20, 50), 200, 100)
	assert_gt(p.x, 180.0, "partikel utanför vänsterkant ska komma in från höger")

func test_wrap_leaves_inside_particle_untouched():
	var inside := Vector2(100, 50)
	assert_eq(Weather.wrap(inside, 200, 100), inside)
