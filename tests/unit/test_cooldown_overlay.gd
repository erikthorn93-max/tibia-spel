extends GutTest
## Smoke-test för cooldown-overlayn: set_cooldown ska tåla att anropas i och ur
## trädet utan att krascha, och nollställning ska vara idempotent.

func test_set_cooldown_kraschar_inte() -> void:
	var ov := CooldownOverlay.new()
	ov.size = Vector2(36, 36)
	add_child_autofree(ov)
	ov.set_cooldown(2.0, 4.0)     # halvvägs
	ov.set_cooldown(0.0, 1.0)     # klar
	ov.set_cooldown(0.0, 1.0)     # idempotent nollställning
	assert_true(is_instance_valid(ov), "overlayn ska överleva upprepade set_cooldown")

func test_overlay_ar_mus_genomslapplig() -> void:
	var ov := CooldownOverlay.new()
	add_child_autofree(ov)
	assert_eq(ov.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"overlayn får inte stjäla klick från hotbar-sloten under sig")
