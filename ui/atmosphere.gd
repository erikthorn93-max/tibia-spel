class_name Atmosphere
## Stämnings-hjälpare: dygnsfärgning + vinjett. Rena funktioner (inga
## bieffekter) så de kan enhetstestas. Används av hud.gd för dag/natt-känsla.

const COOL := Color(0.03, 0.05, 0.20)   # natt: svalt blått
const WARM := Color(0.34, 0.13, 0.04)   # gryning/skymning: varmt
const MAX_DARK := 0.55                   # max mörkläggnings-alpha (midnatt)

## Färg + alpha för mörkläggnings-overlayt vid en given dygnsfraktion
## (0.0 = midnatt, 0.5 = middag). Mörkast mitt i natten, varm i övergångarna,
## i princip osynlig mitt på dagen.
static func overlay_color(day_fraction: float) -> Color:
	var darkness := (cos(day_fraction * TAU) + 1.0) * 0.5   # 1 midnatt (frac 0) .. 0 middag (frac 0.5)
	var alpha := darkness * MAX_DARK
	# Skymningsfaktor: 1 vid soluppgång/nedgång (darkness≈0.5), 0 vid
	# middag & midnatt → varm ton bara i övergångarna.
	var twilight := clampf(1.0 - absf(darkness - 0.5) * 2.0, 0.0, 1.0)
	var rgb := COOL.lerp(WARM, twilight)
	return Color(rgb.r, rgb.g, rgb.b, alpha)

## Bygger en radiell vinjett-textur: klar i mitten, mörk mot hörnen.
## Mjuk smoothstep-kant så den ramar bilden utan hård ring.
static func make_vignette(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	var max_d := sqrt(cx * cx + cy * cy)
	var edge := Color(0.0, 0.0, 0.02)
	for y in h:
		for x in w:
			var dx := (x + 0.5) - cx
			var dy := (y + 0.5) - cy
			var t := sqrt(dx * dx + dy * dy) / max_d   # 0 mitt .. 1 hörn
			# Börjar mörkna först ~55% ut, mjuk kant
			var a := smoothstep(0.55, 1.0, t) * 0.7
			img.set_pixel(x, y, Color(edge.r, edge.g, edge.b, a))
	return ImageTexture.create_from_image(img)

## Vinjettens styrka (modulate-alpha) vid en dygnsfraktion: alltid lite för
## inramning, kraftigare på natten.
static func vignette_strength(day_fraction: float) -> float:
	var darkness := (cos(day_fraction * TAU) + 1.0) * 0.5
	return 0.4 + darkness * 0.4
