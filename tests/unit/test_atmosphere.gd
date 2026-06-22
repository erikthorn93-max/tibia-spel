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
