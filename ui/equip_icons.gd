extends RefCounted
class_name EquipIcons
## Tonade silhuett-ikoner för tomma utrustningsplatser (hjälm, svärd, sköld …),
## i samma pixel-stil som SkillIcons. Visar visuellt vad som hör hemma i en slot
## utan text — slotnamnet ligger kvar i tooltip vid hover.

const SIZE := 16
const FILL := Color(0.46, 0.39, 0.28, 0.55)   # dämpad, halvgenomskinlig
const OL   := Color(0.22, 0.17, 0.10, 0.70)   # mörk detalj/kontur
const _CLEAR := Color(0, 0, 0, 0)

static var _cache: Dictionary = {}            # slot -> ImageTexture

## Returnerar (och cachar) en silhuett-textur för en utrustningsslot.
static func silhouette(slot: String) -> ImageTexture:
	if _cache.has(slot):
		return _cache[slot]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_CLEAR)
	_draw(slot, img)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[slot] = tex
	return tex

# ── Rit-primitiver (delegerar till delade PixelDraw) ──

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	PixelDraw.p(img, x, y, c)

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	PixelDraw.rect(img, x0, y0, x1, y1, c)

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	PixelDraw.disc(img, cx, cy, r, c)

static func _ring(img: Image, cx: float, cy: float, r_out: float, r_in: float, c: Color) -> void:
	PixelDraw.ring(img, cx, cy, r_out, r_in, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	PixelDraw.line(img, x0, y0, x1, y1, c)

## Dunkel kontur runt silhuetten (tomma kant-pixlar intill fylld).
static func _outline(img: Image) -> void:
	PixelDraw.outline(img, OL)

# ── Per-slot silhuett ──

static func _draw(slot: String, img: Image) -> void:
	var f := FILL
	match slot:
		"amulet":
			_ring(img, 7.5, 5.0, 3.2, 2.0, f)     # kedja/ögla
			_disc(img, 7.5, 11.0, 3.0, f)         # hänge
			_disc(img, 7.5, 11.0, 1.2, _CLEAR)
		"helmet":
			_disc(img, 7.5, 8.0, 5.5, f)          # kupol
			for y in range(9, 15):                # ansiktsöppning
				for x in range(4, 11):
					if Vector2(x, y).distance_to(Vector2(7.5, 9.5)) <= 3.6:
						_p(img, x, y, _CLEAR)
			_rect(img, 2, 8, 13, 10, f)           # brätte
			_rect(img, 7, 9, 8, 13, f)            # nässkydd
		"backpack":
			_rect(img, 3, 4, 12, 14, f)           # väska
			_rect(img, 5, 2, 6, 5, f)             # remmar
			_rect(img, 9, 2, 10, 5, f)
			_rect(img, 3, 7, 12, 7, OL)           # locklinje
			_p(img, 7, 9, OL); _p(img, 8, 9, OL)  # spänne
		"weapon":
			_p(img, 7, 1, f); _p(img, 8, 1, f); _p(img, 8, 2, f)   # udd
			_rect(img, 7, 3, 8, 10, f)            # blad
			_rect(img, 5, 11, 10, 11, f)          # parerstång
			_rect(img, 7, 12, 8, 14, f)           # handtag
		"body":
			_rect(img, 3, 4, 12, 6, f)            # axlar
			for y in range(6, 14):                # avsmalnande bål
				var t := float(y - 6) / 8.0
				var half := 5.0 - t * 1.5
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			_rect(img, 6, 4, 9, 5, _CLEAR)        # halsöppning
			_rect(img, 7, 7, 8, 13, OL)           # mittsöm
		"offhand":
			for y in range(2, 14):                # sköld
				var t := float(y - 2) / 11.0
				var half := 4.5 * (1.0 - t) + 0.5
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			_rect(img, 7, 5, 8, 9, OL)            # emblem
		"tool":
			_line(img, 4, 13, 10, 7, f)           # skiftnyckel-skaft
			_line(img, 5, 13, 11, 8, f)
			_ring(img, 11.0, 5.0, 3.0, 1.6, f)    # käft
			_rect(img, 10, 2, 14, 4, _CLEAR)      # öppning i käften
		"legs":
			_rect(img, 4, 3, 11, 5, f)            # midja
			_rect(img, 4, 5, 6, 14, f)            # vänster ben
			_rect(img, 9, 5, 11, 14, f)           # höger ben
		"ammo":
			_line(img, 3, 14, 8, 4, f)            # pil 1
			_rect(img, 7, 3, 9, 5, f)
			_line(img, 7, 14, 12, 4, f)           # pil 2
			_rect(img, 11, 3, 13, 5, f)
		"ring", "ring2":
			_ring(img, 7.5, 9.5, 4.2, 2.4, f)     # ring
			_rect(img, 6, 3, 9, 6, f)             # sten
		"boots":
			_rect(img, 5, 2, 8, 9, f)             # skaft
			_rect(img, 5, 9, 12, 12, f)           # fot
			_rect(img, 5, 12, 7, 13, f)           # klack
		"light":
			_ring(img, 7.5, 3.0, 2.0, 1.0, f)     # bygel
			_rect(img, 5, 5, 10, 13, f)           # lykt-hölje
			_rect(img, 6, 7, 9, 11, OL)           # glas
			_rect(img, 4, 13, 11, 14, f)          # bas
		_:
			_ring(img, 7.5, 7.5, 5.0, 3.0, f)     # fallback: enkel ring
