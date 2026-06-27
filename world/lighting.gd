## Hjälpare för äkta 2D-ljus. Bygger PointLight2D-noder med en mjuk radiell
## textur (vit i mitten → genomskinlig kant) så att ljusets `color` blir tonen.
## Texturen byggs en gång och delas mellan alla ljus.

const TEX_SIZE := 256

static var _tex: Texture2D = null

## Mjuk vit radiell ljustextur (cachad). Kvadrerad falloff → naturlig kant utan
## hård ring. PointLight2D tonar den med sin egen färg.
static func radial_texture() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var c := TEX_SIZE * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var dx := (x + 0.5) - c
			var dy := (y + 0.5) - c
			var t := clampf(sqrt(dx * dx + dy * dy) / c, 0.0, 1.0)
			var a := 1.0 - smoothstep(0.0, 1.0, t)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex

## Bygger ett PointLight2D. radius_px är hur långt skenet når (texturen skalas
## så TEX_SIZE/2 motsvarar radien). energy och color sätter styrka och ton.
static func make_light(color: Color, energy: float, radius_px: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.texture_scale = radius_px / (TEX_SIZE * 0.5)
	light.color = color
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	return light
