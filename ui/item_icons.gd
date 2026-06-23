extends RefCounted
class_name ItemIcons
## Central item-ikonkälla: returnerar disk-spriten om den finns, annars en
## procedurell 16×16-ikon härledd ur ItemDB-defens type/slot/color. Garanterar
## att inget item blir osynligt — alla UI-ytor (hotbar, väska, tooltip,
## utrustning) går via texture() istället för att ladda PNG:n direkt.

const SIZE := 16
const _OL    := Color(0.06, 0.05, 0.04, 0.95)
const _GLASS := Color(0.78, 0.85, 0.92, 0.55)
const _WOOD  := Color(0.42, 0.30, 0.16)
const _CLEAR := Color(0, 0, 0, 0)

static var _cache: Dictionary = {}            # item_id -> Texture2D

## Disk-sprite (cachad) eller procedurell fallback. Aldrig null.
static func texture(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var tex: Texture2D
	var path := "res://assets/sprites/items/%s.png" % item_id
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		tex = procedural(item_id, ItemDB.items.get(item_id, {}))
	_cache[item_id] = tex
	return tex

# ── Procedurell generering ────────────────────────────────────────────────────
## Ritar en ikon enbart ur defen (ingen autoload-åtkomst) så den kan anropas
## även från fristående verktygsskript.
static func procedural(item_id: String, def: Dictionary) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_CLEAR)
	var base := _color(def)
	var dark := base.darkened(0.38)
	match String(def.get("type", "")):
		"weapon":    _weapon(img, def, base, dark)
		"armor":     _armor(img, String(def.get("slot", "")), base, dark)
		"light":     _light(img, base)
		"container": _container(img, base, dark)
		"potion":    _potion(img, base)
		"food":      _food(img, item_id, base, dark)
		"material":  _material(img, base, dark)
		_:           _generic(img, base, dark)
	PixelDraw.outline(img, _OL)
	return ImageTexture.create_from_image(img)

## Defens egen färg (hex) om angiven, annars en vettig per-typ-standard.
static func _color(def: Dictionary) -> Color:
	var s := String(def.get("color", ""))
	if s != "" and Color.html_is_valid(s):
		return Color.html(s)
	match String(def.get("type", "")):
		"weapon":    return Color(0.70, 0.72, 0.78)
		"armor":     return Color(0.60, 0.63, 0.72)
		"light":     return Color(0.96, 0.72, 0.30)
		"container": return Color(0.55, 0.38, 0.20)
		"potion":    return Color(0.62, 0.40, 0.90)
		"food":      return Color(0.82, 0.56, 0.36)
		_:           return Color(0.60, 0.55, 0.50)

# ── Glyfer ────────────────────────────────────────────────────────────────────
static func _weapon(img: Image, def: Dictionary, base: Color, dark: Color) -> void:
	var skill := String(def.get("skill", "sword"))
	if skill == "axe":
		PixelDraw.rect(img, 7, 3, 8, 14, _WOOD)            # skaft
		PixelDraw.disc(img, 6.0, 5.0, 3.6, base)           # yxblad
		PixelDraw.rect(img, 7, 3, 11, 7, base)
		PixelDraw.disc(img, 6.0, 5.0, 1.8, dark)
	elif skill == "club":
		PixelDraw.rect(img, 7, 8, 8, 14, _WOOD)            # skaft
		PixelDraw.disc(img, 7.5, 5.0, 4.0, base)           # klubbhuvud
		PixelDraw.p(img, 6, 4, dark); PixelDraw.p(img, 9, 4, dark)
		PixelDraw.p(img, 6, 6, dark); PixelDraw.p(img, 9, 6, dark)
	elif skill == "ranged":
		PixelDraw.line(img, 4, 2, 4, 14, _WOOD)            # bågstomme
		PixelDraw.line(img, 4, 2, 9, 4, base)
		PixelDraw.line(img, 4, 14, 9, 12, base)
		PixelDraw.line(img, 5, 3, 5, 13, dark)             # sträng
	else:
		PixelDraw.p(img, 7, 1, base)                       # svärdsudd
		PixelDraw.rect(img, 7, 2, 8, 9, base)              # blad
		PixelDraw.line(img, 7, 2, 7, 9, base.lightened(0.35))
		PixelDraw.rect(img, 5, 10, 10, 10, dark)           # parerstång
		PixelDraw.rect(img, 7, 11, 8, 14, _WOOD)           # handtag
		PixelDraw.p(img, 7, 14, base); PixelDraw.p(img, 8, 14, base)

static func _armor(img: Image, slot: String, base: Color, dark: Color) -> void:
	match slot:
		"amulet":
			PixelDraw.ring(img, 7.5, 5.0, 3.2, 2.0, dark)  # kedja
			PixelDraw.disc(img, 7.5, 11.0, 3.0, base)      # hänge
			PixelDraw.disc(img, 7.5, 11.0, 1.2, base.lightened(0.4))
		"ring", "ring2":
			PixelDraw.ring(img, 7.5, 9.5, 4.2, 2.4, base)  # ring
			PixelDraw.rect(img, 6, 3, 9, 6, base.lightened(0.3))  # sten
		"helmet":
			PixelDraw.disc(img, 7.5, 8.0, 5.5, base)       # kupol
			for y in range(9, 15):
				for x in range(4, 11):
					if Vector2(x, y).distance_to(Vector2(7.5, 9.5)) <= 3.6:
						PixelDraw.p(img, x, y, _CLEAR)
			PixelDraw.rect(img, 2, 8, 13, 10, base)        # brätte
			PixelDraw.rect(img, 7, 9, 8, 13, dark)         # nässkydd
		"body":
			PixelDraw.rect(img, 3, 4, 12, 6, base)         # axlar
			for y in range(6, 14):
				var t := float(y - 6) / 8.0
				var half := 5.0 - t * 1.5
				PixelDraw.rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, base)
			PixelDraw.rect(img, 6, 4, 9, 5, _CLEAR)        # halsöppning
			PixelDraw.rect(img, 7, 7, 8, 13, dark)         # mittsöm
		"legs":
			PixelDraw.rect(img, 4, 3, 11, 5, base)         # midja
			PixelDraw.rect(img, 4, 5, 6, 14, base)         # vänster ben
			PixelDraw.rect(img, 9, 5, 11, 14, base)        # höger ben
			PixelDraw.rect(img, 7, 5, 8, 14, dark)
		"boots":
			PixelDraw.rect(img, 5, 2, 8, 9, base)          # skaft
			PixelDraw.rect(img, 5, 9, 12, 12, base)        # fot
			PixelDraw.rect(img, 5, 12, 7, 13, dark)        # klack
		"shield", "offhand":
			for y in range(2, 14):
				var t := float(y - 2) / 11.0
				var half := 4.5 * (1.0 - t) + 0.5
				PixelDraw.rect(img, int(round(7.5 - half)), y, int(round(7.5 + half)), y, base)
			PixelDraw.rect(img, 7, 5, 8, 9, dark)          # emblem
		_:
			PixelDraw.rect(img, 4, 4, 11, 11, base)        # generell platta
			PixelDraw.rect(img, 6, 6, 9, 9, dark)

static func _light(img: Image, base: Color) -> void:
	PixelDraw.rect(img, 7, 8, 8, 14, _WOOD)               # skaft
	PixelDraw.disc(img, 7.5, 5.0, 3.2, base)              # flamma
	PixelDraw.disc(img, 7.5, 4.0, 1.6, base.lightened(0.45))
	PixelDraw.p(img, 7, 1, base.lightened(0.3))

static func _container(img: Image, base: Color, dark: Color) -> void:
	PixelDraw.rect(img, 3, 5, 12, 14, base)               # väska
	PixelDraw.rect(img, 5, 3, 6, 5, dark)                 # remmar
	PixelDraw.rect(img, 9, 3, 10, 5, dark)
	PixelDraw.rect(img, 3, 8, 12, 8, dark)                # locklinje
	PixelDraw.p(img, 7, 9, dark); PixelDraw.p(img, 8, 9, dark)  # spänne

static func _potion(img: Image, base: Color) -> void:
	PixelDraw.rect(img, 6, 2, 9, 3, _WOOD)                # kork
	PixelDraw.rect(img, 6, 3, 9, 5, _GLASS)              # hals
	PixelDraw.disc(img, 7.5, 10.0, 4.5, _GLASS)          # kolv (glas)
	PixelDraw.disc(img, 7.5, 11.0, 3.6, base)            # vätska
	PixelDraw.disc(img, 6.0, 9.0, 1.0, _GLASS.lightened(0.3))  # glans

static func _food(img: Image, item_id: String, base: Color, dark: Color) -> void:
	var fishy := ["fish", "tuna", "shark", "eel", "trout", "manta", "pike", "crab", "lobster", "anglerfish", "mackerel", "kingfish", "swordfish"]
	var is_fish := false
	for w in fishy:
		if item_id.contains(w):
			is_fish = true
			break
	if is_fish:
		PixelDraw.disc(img, 6.5, 8.0, 4.0, base)          # fiskkropp
		PixelDraw.line(img, 11, 5, 14, 3, base)           # stjärtfena
		PixelDraw.line(img, 11, 11, 14, 13, base)
		PixelDraw.rect(img, 11, 5, 13, 11, base)
		PixelDraw.p(img, 4, 7, dark)                      # öga
	else:
		PixelDraw.disc(img, 8.5, 7.0, 4.2, base)          # köttklump
		PixelDraw.rect(img, 3, 10, 7, 13, Color(0.95, 0.92, 0.85))  # ben
		PixelDraw.disc(img, 3.5, 12.5, 1.4, Color(0.95, 0.92, 0.85))
		PixelDraw.disc(img, 9.0, 5.5, 1.4, base.lightened(0.3))     # glans

static func _material(img: Image, base: Color, dark: Color) -> void:
	PixelDraw.disc(img, 7.5, 9.0, 4.6, base)              # klump
	PixelDraw.disc(img, 6.0, 7.0, 1.8, base.lightened(0.3))  # facett-glans
	PixelDraw.line(img, 5, 11, 9, 12, dark)              # spricka
	PixelDraw.line(img, 9, 7, 11, 10, dark)

static func _generic(img: Image, base: Color, dark: Color) -> void:
	PixelDraw.rect(img, 3, 3, 12, 12, base)
	PixelDraw.rect(img, 5, 5, 10, 10, dark)
	PixelDraw.disc(img, 7.5, 7.5, 2.0, base.lightened(0.3))
