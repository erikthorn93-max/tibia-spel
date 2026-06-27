extends GutTest
## Tester för dygnsfärgning (overlay_color) och vinjett-textur.

const Atmosphere = preload("res://ui/atmosphere.gd")

# ── Dygnsfärgning ──

func test_midday_is_nearly_transparent():
	# frac 0.5 = middag → nästan inget mörker.
	assert_lt(Atmosphere.overlay_color(0.5).a, 0.06)

func test_midnight_is_dark_and_cool():
	# frac 0.0 = midnatt → mörkt och blått (kallt).
	var c := Atmosphere.overlay_color(0.0)
	assert_gt(c.a, 0.4, "midnatt ska vara mörk")
	assert_gt(c.b, c.r, "natten ska vara kall (blå dominerar)")

func test_dawn_is_warm_and_partial():
	# frac 0.25 = 06:00 (soluppgång) → varm ton, måttligt mörk.
	var c := Atmosphere.overlay_color(0.25)
	assert_gt(c.r, c.b, "gryning ska vara varm (röd dominerar)")
	assert_between(c.a, 0.12, 0.4)

func test_dusk_is_warm():
	# frac 0.75 = 18:00 (solnedgång) → varm ton.
	assert_gt(Atmosphere.overlay_color(0.75).r, Atmosphere.overlay_color(0.75).b)

# ── Vinjett ──

func test_vignette_center_clear_corner_dark():
	var tex := Atmosphere.make_vignette(64, 64)
	var img := tex.get_image()
	assert_lt(img.get_pixel(32, 32).a, 0.06, "mitten ska vara klar")
	assert_gt(img.get_pixel(0, 0).a, 0.4, "hörnet ska vara mörkt")

func test_vignette_size():
	var tex := Atmosphere.make_vignette(48, 24)
	assert_eq(tex.get_width(), 48)
	assert_eq(tex.get_height(), 24)

# ── Lokalt ljussken (fackla/lykta) ──

func test_light_glow_warm_center_transparent_edge():
	var tex := Atmosphere.make_light_glow(64)
	var img := tex.get_image()
	var c := img.get_pixel(32, 32)
	assert_gt(c.a, 0.5, "mitten ska lysa")
	assert_gt(c.r, c.b, "ljuset ska vara varmt (rött > blått)")
	assert_lt(img.get_pixel(0, 0).a, 0.05, "kanten ska vara genomskinlig")

func test_glow_strength_zero_without_light():
	assert_eq(Atmosphere.glow_strength(0.0, 0.0), 0.0)

func test_glow_strength_zero_at_midday():
	assert_lt(Atmosphere.glow_strength(0.8, 0.5), 0.05)

func test_glow_strength_positive_at_night_with_light():
	assert_gt(Atmosphere.glow_strength(0.8, 0.0), 0.3)

# ── Fackelsken-flimmer ──

func test_flicker_stays_near_full_brightness():
	# Skenet får skälva men aldrig slockna eller överstyra.
	for i in 200:
		var v := Atmosphere.flicker(float(i) * 0.05)
		assert_between(v, 0.78, 1.0)

func test_flicker_actually_varies():
	# Flimret ska faktiskt röra sig över tid, inte vara konstant.
	var lo := 2.0
	var hi := -2.0
	for i in 200:
		var v := Atmosphere.flicker(float(i) * 0.037)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	assert_gt(hi - lo, 0.05, "flimret ska variera märkbart")

# ── Äkta 2D-ljus: CanvasModulate-ton ──

func test_canvas_tint_midday_is_neutral():
	# Middag → ingen mörkläggning, multiplikator nära vit.
	var c := Atmosphere.canvas_tint(0.5)
	assert_gt(c.r, 0.95, "middag ska vara ljus")
	assert_gt(c.g, 0.95)
	assert_gt(c.b, 0.95)

func test_canvas_tint_midnight_is_dark_and_cool():
	var c := Atmosphere.canvas_tint(0.0)
	assert_lt(c.r, 0.5, "midnatt ska mörklägga världen")
	assert_gt(c.b, c.r, "natten ska vara kall (blå dominerar)")
	assert_gt(c.r, 0.0, "aldrig becksvart — svaga konturer ska synas")

func test_canvas_tint_dusk_is_warm():
	# 18:00 → varm ton (röd > blå) men ändå nedtonad.
	var c := Atmosphere.canvas_tint(0.75)
	assert_gt(c.r, c.b, "skymning ska vara varm")
	assert_lt(c.r, 1.0, "skymningen ska vara nedtonad mot natten")

# ── Äkta 2D-ljus: ljuskällornas styrka över dygnet ──

func test_light_energy_zero_at_midday():
	assert_lt(Atmosphere.light_energy(0.5), 0.05, "ljuskällor ska inte överexponera dagsljus")

func test_light_energy_full_at_midnight():
	assert_gt(Atmosphere.light_energy(0.0), 0.9, "facklor ska lysa starkt på natten")

func test_light_energy_rises_into_night():
	# Skymningen (frac 0.7) ska ge mer ljus än eftermiddagen (frac 0.55).
	assert_gt(Atmosphere.light_energy(0.7), Atmosphere.light_energy(0.55))
