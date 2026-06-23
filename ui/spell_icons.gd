extends RefCounted
class_name SpellIcons
## Procedurella 16×16-ikoner för besvärjelser, härledda ur spelldefinitionens
## type (heal/support/attack/conjure) + element (fire/ice/energy/death/holy/…).
## Inga spell-sprites finns på disk, så detta ger både spellbook och hotbar
## en visuell representation. Färgkodas per element; conjure får en run-ram.

const SIZE := 16
const _OL := Color(0.04, 0.03, 0.06, 0.95)
const _CLEAR := Color(0, 0, 0, 0)

# Elementfärger
const C_FIRE   := Color(0.97, 0.48, 0.12)
const C_ICE    := Color(0.55, 0.82, 1.00)
const C_ENERGY := Color(0.70, 0.45, 0.97)
const C_DEATH  := Color(0.62, 0.40, 0.70)
const C_HOLY   := Color(0.50, 0.92, 0.55)
const C_PHYS   := Color(0.92, 0.40, 0.34)
const C_LIGHT  := Color(1.00, 0.86, 0.36)
const C_HASTE  := Color(0.46, 0.86, 0.96)
const C_SHIELD := Color(0.42, 0.66, 0.96)

static var _cache: Dictionary = {}            # spell_id -> ImageTexture

## Ikon för en besvärjelse. def hämtas normalt från SpellSystem.spells.
static func texture(spell_id: String, def: Dictionary) -> ImageTexture:
	if _cache.has(spell_id):
		return _cache[spell_id]
	var r := _resolve(def)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_CLEAR)
	_draw(String(r[0]), Color(r[1]), bool(r[2]), img)
	PixelDraw.outline(img, _OL)
	var tex := ImageTexture.create_from_image(img)
	_cache[spell_id] = tex
	return tex

## Returnerar [glyph, färg, run_ram?] utifrån type/element/buff.
static func _resolve(def: Dictionary) -> Array:
	var t := String(def.get("type", "attack"))
	var el := String(def.get("element", "none"))
	match t:
		"heal":
			return ["cross", C_HOLY, false]
		"support":
			var stat := String(def.get("buff", {}).get("stat", ""))
			if stat == "light":
				return ["sun", C_LIGHT, false]
			if stat.contains("agility"):
				return ["wing", C_HASTE, false]
			if stat.contains("shielding"):
				return ["shield", C_SHIELD, false]
			return ["sun", C_LIGHT, false]
		"conjure":
			return [_element_glyph(el), _element_color(el), true]
		_:
			if el == "physical":
				return ["burst", C_PHYS, false]
			return [_element_glyph(el), _element_color(el), false]

static func _element_glyph(el: String) -> String:
	match el:
		"fire":   return "flame"
		"ice":    return "shard"
		"energy": return "bolt"
		"death":  return "skull"
		"holy":   return "cross"
		_:        return "burst"

static func _element_color(el: String) -> Color:
	match el:
		"fire":   return C_FIRE
		"ice":    return C_ICE
		"energy": return C_ENERGY
		"death":  return C_DEATH
		"holy":   return C_HOLY
		_:        return C_PHYS

# ── Glyfer ──

static func _draw(glyph: String, f: Color, framed: bool, img: Image) -> void:
	# Conjure-glyfer ritas något mindre/centrerade så run-ramen får plats.
	match glyph:
		"flame":
			for y in range(2, 14):
				var t := float(y - 2) / 11.0
				var half := 0.6 + 4.0 * t
				PixelDraw.rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			PixelDraw.rect(img, 7, 8, 8, 12, _OL)        # inre flick
		"shard":
			for y in range(2, 14):                       # iskristall (diamant)
				var half := int(round(4.5 - absf(y - 7.5) * 0.55))
				if half >= 0:
					PixelDraw.rect(img, 7 - half, y, 8 + half - 1, y, f)
			PixelDraw.line(img, 7, 3, 7, 12, _OL)        # facett
			PixelDraw.line(img, 4, 7, 11, 7, f)          # tvärgnista
		"bolt":
			PixelDraw.rect(img, 8, 2, 10, 4, f)          # blixt-zigzag
			PixelDraw.rect(img, 7, 4, 9, 6, f)
			PixelDraw.rect(img, 6, 6, 8, 8, f)
			PixelDraw.rect(img, 7, 7, 11, 8, f)
			PixelDraw.rect(img, 6, 8, 8, 10, f)
			PixelDraw.rect(img, 5, 10, 7, 12, f)
			PixelDraw.rect(img, 4, 12, 6, 14, f)
		"skull":
			PixelDraw.disc(img, 7.5, 6.0, 4.5, f)        # kranium
			PixelDraw.rect(img, 5, 9, 10, 12, f)         # käke
			PixelDraw.rect(img, 4, 5, 6, 7, _OL)         # ögon
			PixelDraw.rect(img, 9, 5, 11, 7, _OL)
			PixelDraw.p(img, 7, 8, _OL); PixelDraw.p(img, 8, 8, _OL)
			PixelDraw.p(img, 6, 11, _OL); PixelDraw.p(img, 8, 11, _OL); PixelDraw.p(img, 10, 11, _OL)
		"cross":
			PixelDraw.rect(img, 6, 2, 9, 13, f)          # läke-kors (tjockt plus)
			PixelDraw.rect(img, 2, 6, 13, 9, f)
		"sun":
			PixelDraw.disc(img, 7.5, 7.5, 3.2, f)        # sol-skiva
			PixelDraw.rect(img, 7, 0, 8, 2, f); PixelDraw.rect(img, 7, 13, 8, 15, f)
			PixelDraw.rect(img, 0, 7, 2, 8, f); PixelDraw.rect(img, 13, 7, 15, 8, f)
			PixelDraw.p(img, 3, 3, f); PixelDraw.p(img, 12, 3, f)
			PixelDraw.p(img, 3, 12, f); PixelDraw.p(img, 12, 12, f)
		"wing":
			PixelDraw.line(img, 3, 4, 13, 4, f)          # haste-chevroner (fart)
			PixelDraw.line(img, 8, 4, 5, 7, f)
			PixelDraw.line(img, 3, 8, 13, 8, f)
			PixelDraw.line(img, 8, 8, 5, 11, f)
			PixelDraw.line(img, 3, 12, 13, 12, f)
			PixelDraw.line(img, 8, 12, 5, 15, f)
		"shield":
			for y in range(2, 14):
				var t := float(y - 2) / 11.0
				var half := 4.5 * (1.0 - t) + 0.5
				PixelDraw.rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			PixelDraw.p(img, 7, 6, _OL); PixelDraw.p(img, 8, 6, _OL)   # gnista-emblem
			PixelDraw.p(img, 6, 7, _OL); PixelDraw.p(img, 9, 7, _OL)
			PixelDraw.p(img, 7, 8, _OL); PixelDraw.p(img, 8, 8, _OL)
		"burst":
			PixelDraw.disc(img, 7.5, 7.5, 2.4, f)        # slag-stjärna
			PixelDraw.line(img, 7, 1, 8, 5, f); PixelDraw.line(img, 7, 10, 8, 14, f)
			PixelDraw.line(img, 1, 7, 5, 8, f); PixelDraw.line(img, 10, 7, 14, 8, f)
			PixelDraw.p(img, 3, 3, f); PixelDraw.p(img, 12, 3, f)
			PixelDraw.p(img, 3, 12, f); PixelDraw.p(img, 12, 12, f)
		_:
			PixelDraw.disc(img, 7.5, 7.5, 4.0, f)

	if framed:
		_rune_frame(img, f)

## Run-ram: hörn-markörer som signalerar "conjure → tillverkar runa".
static func _rune_frame(img: Image, f: Color) -> void:
	for c in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15)]:
		var sx := 1 if c.x == 0 else -1
		var sy := 1 if c.y == 0 else -1
		PixelDraw.p(img, c.x, c.y, f)
		PixelDraw.p(img, c.x + sx * 1, c.y, f)
		PixelDraw.p(img, c.x, c.y + sy * 1, f)
