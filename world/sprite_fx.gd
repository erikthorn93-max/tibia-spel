## Hjälpare för varelse-grafik: en mjuk markskugga och en kontur-shader som får
## sprites att lyfta från bakgrunden. Texturen och shadermaterialet byggs en gång
## och delas mellan alla varelser (skuggan är en enkel tonad ellips).

const SHADOW_W := 26
const SHADOW_H := 12

static var _shadow_tex: Texture2D = null
static var _outline_mat: ShaderMaterial = null

## Mjuk mörk ellips (cachad) att lägga vid en varelses fötter.
static func shadow_texture() -> Texture2D:
	if _shadow_tex != null:
		return _shadow_tex
	var img := Image.create(SHADOW_W, SHADOW_H, false, Image.FORMAT_RGBA8)
	var cx := SHADOW_W * 0.5
	var cy := SHADOW_H * 0.5
	for y in SHADOW_H:
		for x in SHADOW_W:
			# Normaliserat avstånd i en ellips → mjuk falloff mot kanten.
			var nx := ((x + 0.5) - cx) / cx
			var ny := ((y + 0.5) - cy) / cy
			var d := sqrt(nx * nx + ny * ny)
			var a := (1.0 - smoothstep(0.35, 1.0, d)) * 0.45
			img.set_pixel(x, y, Color(0.0, 0.0, 0.02, a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex

## En Sprite2D-skugga klar att läggas under en varelse. feet_y är skuggans
## y-position (vid fötterna); skuggan ligger still medan spriten studsar ovanför.
static func make_shadow(feet_y: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = shadow_texture()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # mjuk, inte pixlig
	s.position = Vector2(0.0, feet_y)
	s.z_index = -1   # alltid bakom varelsens sprite
	return s

## Delat kontur-shadermaterial (cachat). Appliceras på en varelses Sprite2D.
static func outline_material() -> ShaderMaterial:
	if _outline_mat != null:
		return _outline_mat
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/outline.gdshader")
	_outline_mat = mat
	return _outline_mat
