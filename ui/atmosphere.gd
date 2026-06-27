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

const GLOW := Color(1.0, 0.78, 0.42)   # varmt fackelsken

## Bygger en varm radiell ljussken-textur: ljus i mitten, mjukt uttonande.
## Ritas additivt ovanpå mörkret → lyser upp lokalt runt spelaren.
static func make_light_glow(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var dx := (x + 0.5) - c
			var dy := (y + 0.5) - c
			var t := clampf(sqrt(dx * dx + dy * dy) / c, 0.0, 1.0)
			# Mjuk falloff: ljusast i mitten, 0 vid radien. Kvadrerad för naturlig kant.
			var a := (1.0 - smoothstep(0.0, 1.0, t))
			a = a * a
			img.set_pixel(x, y, Color(GLOW.r, GLOW.g, GLOW.b, a))
	return ImageTexture.create_from_image(img)

## Ljusskenets styrka (modulate-alpha) givet utrustad ljuskälla och tid:
## syns bara när det är mörkt OCH spelaren bär ljus. Dagtid → 0.
static func glow_strength(light_level: float, day_fraction: float) -> float:
	var darkness := (cos(day_fraction * TAU) + 1.0) * 0.5
	return clampf(light_level, 0.0, 1.0) * darkness

## Organiskt lågflimmer för fackelskenet: en multiplikator nära 1.0 som
## skälver lätt. Två osammanhängande sinusvågor → oregelbunden, levande låga
## utan synlig periodicitet. Aldrig så lågt att skenet "slocknar".
static func flicker(t: float) -> float:
	var f := sin(t * 11.0) * 0.5 + sin(t * 6.3 + 1.7) * 0.5
	return clampf(0.9 + f * 0.1, 0.78, 1.0)

# ── Äkta 2D-ljus (CanvasModulate + PointLight2D) ──────────────────────────────
# Ersätter det gamla skärm-overlayt: CanvasModulate mörklägger hela världen
# (även sprites/tiles), riktiga PointLight2D-noder lägger tillbaka ljus → natten
# blir genuint mörk med lokala ljusöar runt facklor, spelaren och spells.

const NIGHT_FLOOR := 0.30   # hur mörk världen blir vid midnatt (0=svart, 1=ingen)

## Multiplikator-färg för en CanvasModulate vid given dygnsfraktion. Vit mitt på
## dagen (ingen påverkan), mörk och sval mot midnatt, varmt tonad i gryning och
## skymning. RGB skalas runt en ljusstyrka; alpha alltid 1 (CanvasModulate
## multiplicerar färgen rakt på scenen).
static func canvas_tint(day_fraction: float) -> Color:
	var darkness := (cos(day_fraction * TAU) + 1.0) * 0.5   # 1 midnatt .. 0 middag
	var bright := lerpf(1.0, NIGHT_FLOOR, darkness)
	var twilight := clampf(1.0 - absf(darkness - 0.5) * 2.0, 0.0, 1.0)
	# Hyfsat neutral vid middag; blå dragning på natten, varm i övergångarna.
	var r := bright * (1.0 + 0.22 * twilight - 0.06 * darkness)
	var g := bright * (1.0 + 0.04 * twilight - 0.02 * darkness)
	var b := bright * (1.0 - 0.06 * twilight + 0.12 * darkness)
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), 1.0)

## Hur starkt världens ljuskällor (facklor, spelarsken, spells) ska lysa vid en
## dygnsfraktion: 0 mitt på dagen (annars överexponeras additivt ljus mot den
## ljusa scenen), upp mot 1 vid midnatt. Mjuk kurva så facklor tänds i skymningen.
static func light_energy(day_fraction: float) -> float:
	var darkness := (cos(day_fraction * TAU) + 1.0) * 0.5
	return smoothstep(0.12, 0.85, darkness)
