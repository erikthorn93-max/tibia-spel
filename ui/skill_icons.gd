extends RefCounted
class_name SkillIcons
## Procedurella 16×16 pixel-ikoner per skill, i samma stil som HP/mana-ikonerna
## (färgad fyllning i skillens egen färg + mörk kontur). Tooltip ger namnet —
## ikonen ger snabb visuell igenkänning så skillrutan kan vara kompakt utan text.

const SIZE := 16
const _OL := Color(0.05, 0.03, 0.02, 0.95)   # mörk kontur/detalj

static var _cache: Dictionary = {}            # id -> ImageTexture

## Returnerar (och cachar) en ikon-textur för en skill i given färg.
static func texture(id: String, fg: Color) -> ImageTexture:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw(id, img, fg)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
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

## Dunkel kontur: tomma pixlar intill en fylld blir mörka (silhuett-kant).
static func _outline(img: Image) -> void:
	PixelDraw.outline(img, _OL)

# ── Per-skill ritning ──

static func _draw(id: String, img: Image, f: Color) -> void:
	match id:
		"sword", "attack":
			_p(img, 7, 1, f); _p(img, 8, 1, f)    # spetsad udd
			_p(img, 8, 2, f)
			_rect(img, 7, 3, 8, 10, f)            # blad
			_rect(img, 5, 11, 10, 11, f)          # parerstång (smal)
			_rect(img, 7, 12, 8, 14, f)           # handtag
			_p(img, 6, 14, f); _p(img, 9, 14, f)  # knapp
		"axe", "strength":
			_rect(img, 10, 4, 11, 14, f)          # skaft
			_rect(img, 3, 3, 9, 4, f)             # yxhuvud (fjäder)
			_rect(img, 3, 4, 9, 5, f)
			_rect(img, 4, 5, 9, 6, f)
			_rect(img, 5, 6, 9, 8, f)
		"shielding", "defence":
			for y in range(2, 14):
				var t := float(y - 2) / 11.0
				var half := 4.5 * (1.0 - t) + 0.5
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
		"distance", "ranged":
			for y in range(2, 14):                # bågens stav (vänster arc)
				for x in range(2, 8):
					var d := Vector2(x, y).distance_to(Vector2(10.5, 7.5))
					if d <= 7.0 and d >= 5.5:
						_p(img, x, y, f)
			_rect(img, 5, 7, 12, 8, f)            # pil-skaft
			_p(img, 12, 6, f); _p(img, 12, 9, f); _p(img, 13, 7, f); _p(img, 13, 8, f)
		"prayer":
			_disc(img, 7.5, 5.0, 3.0, f)          # ankh-ögla
			_disc(img, 7.5, 5.0, 1.3, Color(0, 0, 0, 0))
			_rect(img, 7, 5, 8, 14, f)            # stam
			_rect(img, 4, 8, 11, 9, f)            # tvärslå
		"magic":
			_rect(img, 7, 2, 8, 13, f)            # sparkle-stjärna
			_rect(img, 2, 7, 13, 8, f)
			_p(img, 4, 4, f); _p(img, 11, 11, f); _p(img, 11, 4, f); _p(img, 4, 11, f)
		"runecrafting", "runecraft":
			for y in range(2, 14):                # diamant/rune
				var half := int(round(6.0 - absf(y - 7.5)))
				if half >= 0:
					_rect(img, 7 - half, y, 8 + half - 1, y, f)
			_rect(img, 7, 5, 8, 10, _OL)          # inristning
		"constitution", "hitpoints":
			for y in SIZE:                        # hjärta
				for x in SIZE:
					var lobe := Vector2(x, y).distance_to(Vector2(5.0, 6.0)) <= 3.2 \
						or Vector2(x, y).distance_to(Vector2(10.0, 6.0)) <= 3.2
					var body := y >= 6 and absf(x - 7.5) <= (14.0 - y) * 0.8
					if lobe or body:
						_p(img, x, y, f)
		"agility":
			_rect(img, 5, 2, 8, 9, f)             # ben
			_rect(img, 5, 9, 12, 12, f)           # fot
			_rect(img, 5, 12, 7, 13, f)           # klack
		"herbalism", "herblore":
			for y in range(2, 14):                # blad längs diagonalen
				for x in range(2, 14):
					var a := (float(x) - 7.5 + float(y) - 7.5) / 2.0
					var b := (float(x) - 7.5 - (float(y) - 7.5)) / 2.0
					if (a * a) / 30.0 + (b * b) / 5.0 <= 1.0:
						_p(img, x, y, f)
			_line(img, 4, 12, 12, 4, _OL)         # mittnerv
		"thieving":
			_rect(img, 2, 5, 13, 9, f)            # rånar-mask
			_rect(img, 4, 6, 6, 8, _OL)           # ögonhål
			_rect(img, 9, 6, 11, 8, _OL)
		"crafting":
			_ring(img, 7.5, 9.5, 4.0, 2.3, f)     # ring
			_rect(img, 6, 2, 9, 5, f)             # ädelsten
		"fletching":
			_line(img, 3, 13, 11, 5, f)           # pil-skaft
			_rect(img, 11, 3, 13, 5, f)           # spets
			_p(img, 2, 12, f); _p(img, 4, 14, f); _p(img, 3, 11, f)   # fjäder
		"slayer":
			_disc(img, 7.5, 6.0, 4.5, f)          # kranium
			_rect(img, 5, 9, 10, 12, f)           # käke
			_rect(img, 4, 5, 6, 7, _OL)           # ögon
			_rect(img, 9, 5, 11, 7, _OL)
			_p(img, 7, 8, _OL); _p(img, 8, 8, _OL)
			_p(img, 6, 11, _OL); _p(img, 8, 11, _OL); _p(img, 10, 11, _OL)
		"farming":
			_rect(img, 4, 11, 11, 14, f)          # jord/kruka
			_rect(img, 7, 5, 8, 11, f)            # stjälk
			_disc(img, 5.0, 6.0, 2.0, f)          # blad
			_disc(img, 10.0, 6.0, 2.0, f)
		"construction":
			_rect(img, 3, 3, 11, 6, f)            # hammarhuvud
			_rect(img, 7, 6, 8, 14, f)            # skaft
		"hunting", "hunter":
			_disc(img, 7.5, 10.0, 3.2, f)         # tass-dyna
			_disc(img, 4.5, 5.0, 1.6, f)          # tår
			_disc(img, 7.5, 4.0, 1.6, f)
			_disc(img, 10.5, 5.0, 1.6, f)
		"alchemy":
			_rect(img, 6, 2, 9, 5, f)             # hals
			_disc(img, 7.5, 10.0, 4.3, f)         # kolv
			_rect(img, 4, 11, 11, 12, _OL)        # vätskeyta
		"mining":
			_rect(img, 7, 5, 8, 14, f)            # skaft
			_line(img, 2, 7, 8, 4, f); _line(img, 8, 4, 13, 7, f)   # hacka
			_line(img, 2, 6, 8, 3, f); _line(img, 8, 3, 13, 6, f)
		"smithing":
			_rect(img, 3, 5, 13, 7, f)            # städ-topp
			_p(img, 2, 6, f); _p(img, 2, 7, f); _p(img, 14, 6, f)    # horn
			_rect(img, 6, 7, 9, 10, f)            # midja
			_rect(img, 4, 10, 11, 12, f)          # bas
		"fishing":
			for y in range(4, 12):                # fisk-kropp
				for x in range(2, 12):
					if pow((x - 6.5) / 5.0, 2.0) + pow((y - 7.5) / 3.0, 2.0) <= 1.0:
						_p(img, x, y, f)
			_line(img, 11, 5, 14, 3, f); _line(img, 11, 10, 14, 12, f)   # stjärt
			_rect(img, 11, 7, 12, 8, f)
			_p(img, 4, 6, _OL)                    # öga
		"cooking":
			_rect(img, 2, 6, 13, 7, f)            # gryt-rand
			for y in range(7, 13):                # gryta
				var t := float(y - 7) / 5.0
				var half := 5.0 - t
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			_p(img, 1, 7, f); _p(img, 14, 7, f)   # öron
		"firemaking":
			for y in range(2, 14):                # låga
				var t := float(y - 2) / 11.0
				var half := 0.5 + 4.5 * t
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			_rect(img, 7, 8, 8, 12, _OL)          # inre flick
		"woodcutting":
			for y in range(5, 11):                # liggande stock
				for x in range(2, 14):
					if pow((x - 7.5) / 6.0, 2.0) + pow((y - 7.5) / 3.0, 2.0) <= 1.0:
						_p(img, x, y, f)
			_rect(img, 3, 6, 4, 9, _OL)           # ändyta
			_p(img, 3, 7, f); _p(img, 4, 8, f)    # årsringar
		"club":
			for y in range(2, 15):                # avsmalnande klubba
				var t := float(y - 2) / 12.0
				var half := 1.0 + 3.0 * (1.0 - t)
				_rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, f)
			_p(img, 6, 4, _OL); _p(img, 9, 5, _OL); _p(img, 7, 6, _OL)   # nitar
		"fist":
			_rect(img, 4, 6, 12, 13, f)           # knytnäve
			_disc(img, 5.0, 6.0, 1.4, f)          # knogar
			_disc(img, 7.5, 5.5, 1.5, f)
			_disc(img, 10.0, 6.0, 1.4, f)
			_rect(img, 3, 9, 5, 12, f)            # tumme
			_p(img, 6, 8, _OL); _p(img, 9, 8, _OL)
		_:
			_disc(img, 7.5, 7.5, 5.0, f)          # fallback: enkel disk
