extends GutTest
## Äkta 2D-ljus: den delade radiella ljustexturen och PointLight2D-bygget.

const Lighting = preload("res://world/lighting.gd")

func test_radial_texture_bright_center_clear_edge() -> void:
	var tex := Lighting.radial_texture()
	var img := tex.get_image()
	var c := int(tex.get_width() / 2.0)
	assert_gt(img.get_pixel(c, c).a, 0.8, "mitten ska lysa")
	assert_lt(img.get_pixel(0, 0).a, 0.05, "kanten ska vara genomskinlig")

func test_radial_texture_is_cached() -> void:
	assert_same(Lighting.radial_texture(), Lighting.radial_texture())

func test_make_light_additive_with_color_and_energy() -> void:
	var l := Lighting.make_light(Color(1.0, 0.8, 0.5), 1.2, 96.0)
	assert_eq(l.blend_mode, Light2D.BLEND_MODE_ADD, "ljus ska adderas ovanpå mörkret")
	assert_almost_eq(l.energy, 1.2, 0.01)
	assert_almost_eq(l.color.r, 1.0, 0.01)
	assert_not_null(l.texture)
	# radius 96 → texture_scale = 96 / (256/2) = 0.75
	assert_almost_eq(l.texture_scale, 0.75, 0.01, "texture_scale ska följa önskad radie")
	l.free()
