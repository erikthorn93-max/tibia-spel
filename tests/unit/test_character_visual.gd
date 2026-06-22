extends GutTest
## Tester för rörelse-/andnings-matematiken i CharacterVisual.

const CV = preload("res://entities/player/character_visual.gd")

func test_walk_bob_zero_at_step_ends():
	assert_almost_eq(CV.walk_bob(0.0), 0.0, 0.001)
	assert_almost_eq(CV.walk_bob(1.0), 0.0, 0.01)

func test_walk_bob_peaks_up_mid_step():
	# Mitt i steget ska figuren vara som högst upp (negativ y = uppåt).
	assert_lt(CV.walk_bob(0.5), -1.0)

func test_walk_bob_clamps_out_of_range():
	# Värden utanför 0..1 ska inte ge konstiga utslag.
	assert_almost_eq(CV.walk_bob(-0.5), 0.0, 0.001)
	assert_almost_eq(CV.walk_bob(1.5), 0.0, 0.001)

func test_breath_scale_centered_on_one():
	assert_almost_eq(CV.breath_scale(0.0), 1.0, 0.001)

func test_breath_scale_stays_subtle():
	var lo := 2.0
	var hi := 0.0
	for i in 200:
		var s := CV.breath_scale(i * 0.1)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	assert_gt(lo, 0.9, "andningen ska vara subtil (inte krympa kraftigt)")
	assert_lt(hi, 1.1, "andningen ska vara subtil (inte svälla kraftigt)")
	assert_lt(lo, 1.0)
	assert_gt(hi, 1.0)
