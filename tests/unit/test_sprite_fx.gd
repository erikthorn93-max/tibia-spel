extends GutTest
## Varelse-grafik: markskuggans textur och det delade kontur-materialet.

const SpriteFx = preload("res://world/sprite_fx.gd")

func test_shadow_texture_soft_center_to_edge() -> void:
	# Mjuk ellips: tätare i mitten, genomskinlig mot kanten.
	var tex := SpriteFx.shadow_texture()
	var img := tex.get_image()
	var cx := int(tex.get_width() / 2.0)
	var cy := int(tex.get_height() / 2.0)
	assert_gt(img.get_pixel(cx, cy).a, 0.2, "mitten ska vara mörkast")
	assert_lt(img.get_pixel(0, 0).a, 0.05, "hörnet ska vara genomskinligt")

func test_shadow_texture_is_cached() -> void:
	# Delas mellan alla varelser → samma instans varje gång.
	assert_same(SpriteFx.shadow_texture(), SpriteFx.shadow_texture())

func test_make_shadow_sits_behind_at_feet() -> void:
	var s := SpriteFx.make_shadow(13.0)
	assert_eq(s.z_index, -1, "skuggan ska ligga bakom spriten")
	assert_almost_eq(s.position.y, 13.0, 0.01, "skuggan ska sitta vid fötterna")
	assert_not_null(s.texture)
	s.free()

func test_outline_material_has_shader_and_is_cached() -> void:
	var m := SpriteFx.outline_material()
	assert_true(m is ShaderMaterial, "kontur-materialet ska vara ett ShaderMaterial")
	assert_not_null(m.shader, "materialet ska ha en shader")
	assert_same(m, SpriteFx.outline_material(), "materialet ska delas (cachat)")
