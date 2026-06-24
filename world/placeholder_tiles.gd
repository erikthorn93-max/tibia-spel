class_name PlaceholderTiles
## Bygger ett TileSet från riktiga tile-sprites (assets/sprites/tiles/).
## Terrängtecken → atlas-kolumn matchas via TERRAIN-konstanten.
## Varje terräng får VARIANTS varianter (atlas-rader) med subtil variation så
## stora ytor inte blir enformiga. zone.gd väljer variant per ruta via
## variant_for(). zone.gd:s logik berörs annars inte — byter bara visuellt.

const TILE := 32
const VARIANTS := 3
# atlas-kolumn per terrängtecken
const TERRAIN := {".": 0, ",": 1, "W": 2, "~": 3, "s": 4, "b": 5, "w": 6, "f": 7, "r": 8, "n": 9, "t": 10, "c": 11, "g": 12}

# Terrängtecken → filnamn i assets/sprites/tiles/
const TILE_FILES := {
	".": "grass",
	",": "dirt",
	"W": "wall",
	"~": "water",
	"s": "swamp",
	"b": "beach",
	"w": "window",
	"f": "wooden_floor",
	"r": "roof",
	"n": "stairs",
	"t": "tree",
	"c": "cobblestone",
	"g": "field",
}

# Fallback-färger om filen saknas
const COLORS := {
	".": Color("4a8f3c"), ",": Color("6b5436"),
	"W": Color("6e6e72"), "~": Color("2e5f9e"),
	"s": Color("4f5a2e"), "b": Color("d8c88a"),
	"w": Color("8a9aaa"), "f": Color("7a5530"),
	"r": Color("8b3a1e"), "n": Color("5a5060"),
	"t": Color("2f5a28"), "c": Color("8a8478"), "g": Color("9aa84e"),
}

## Deterministisk variant (0..VARIANTS-1) för en ruta. Samma ruta → samma
## variant varje gång, men grannar skiljer sig så ytan får liv.
static func variant_for(t: Vector2i) -> int:
	var h := (t.x * 73856093) ^ (t.y * 19349663)
	return absi(h) % VARIANTS

## Bygger en overlay-TileSet för strandlinjer: 16 tiles indexerade på en
## bitmask av vilka sidor som vetter mot land (1=N, 2=Ö, 4=S, 8=V). Läggs i
## ett eget lager ovanpå vatten-tiles — påverkar inte gridet/walkability.
const FOAM_N := 1
const FOAM_E := 2
const FOAM_S := 4
const FOAM_W := 8
const FOAM_WIDTH := 6

static func build_overlay() -> TileSet:
	var img := Image.create(TILE * 16, TILE, false, Image.FORMAT_RGBA8)
	for mask in range(1, 16):
		img.blit_rect(make_foam_tile(mask), Rect2i(0, 0, TILE, TILE), Vector2i(mask * TILE, 0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for mask in range(1, 16):
		src.create_tile(Vector2i(mask, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

## Ritar en transparent skum-tile: ljus skumremsa längs varje landvänd kant,
## mest opak ytterst och uttonande inåt. Hörn tar max-alpha av sina två kanter.
static func make_foam_tile(mask: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var foam := Color(0.86, 0.94, 1.0)
	for y in TILE:
		for x in TILE:
			var a := 0.0
			if mask & FOAM_N:
				a = maxf(a, _foam_alpha(y))
			if mask & FOAM_S:
				a = maxf(a, _foam_alpha(TILE - 1 - y))
			if mask & FOAM_W:
				a = maxf(a, _foam_alpha(x))
			if mask & FOAM_E:
				a = maxf(a, _foam_alpha(TILE - 1 - x))
			if a > 0.0:
				img.set_pixel(x, y, Color(foam.r, foam.g, foam.b, a))
	return img

## Alpha för ett avstånd (i px) från en kant: opak ytterst, 0 bortom remsan.
static func _foam_alpha(dist_from_edge: int) -> float:
	if dist_from_edge >= FOAM_WIDTH:
		return 0.0
	return 0.7 * (1.0 - float(dist_from_edge) / float(FOAM_WIDTH))

## ── Gräsfrans: mjukar upp kanten där väg/jord möter gräs ──
## Som strandskummet men grön och oregelbunden — gräset "kryper" in över
## vägkanten. Bitmask 1=N, 2=Ö, 4=S, 8=V mot gräs. Eget lager, grid orört.
const FRINGE_MAX := 6

static func build_fringe() -> TileSet:
	var img := Image.create(TILE * 16, TILE, false, Image.FORMAT_RGBA8)
	for mask in range(1, 16):
		img.blit_rect(make_fringe_tile(mask), Rect2i(0, 0, TILE, TILE), Vector2i(mask * TILE, 0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for mask in range(1, 16):
		src.create_tile(Vector2i(mask, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

## Ritar en transparent grästofs-frans längs varje gräsvänd kant. Djupet
## varierar per position (deterministiskt på mask) så kanten blir ojämn som
## riktiga grässtrån, inte en rak remsa.
static func make_fringe_tile(mask: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grass := Color("4a8f3c")
	var grass_hi := Color("63a84a")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + mask
	# Per kant: slumpa ett djup per kolumn/rad och fyll inåt.
	if mask & FOAM_N:
		for x in TILE:
			var d := rng.randi_range(2, FRINGE_MAX)
			for y in d:
				_put(img, x, y, grass_hi if y == d - 1 else grass)
	if mask & FOAM_S:
		for x in TILE:
			var d := rng.randi_range(2, FRINGE_MAX)
			for k in d:
				var y := TILE - 1 - k
				_put(img, x, y, grass_hi if k == d - 1 else grass)
	if mask & FOAM_W:
		for y in TILE:
			var d := rng.randi_range(2, FRINGE_MAX)
			for x in d:
				_put(img, x, y, grass_hi if x == d - 1 else grass)
	if mask & FOAM_E:
		for y in TILE:
			var d := rng.randi_range(2, FRINGE_MAX)
			for k in d:
				var x := TILE - 1 - k
				_put(img, x, y, grass_hi if k == d - 1 else grass)
	return img

## ── Naturdetaljer: glesa dekaler (blommor, tuvor, sten) ovanpå mark ──
## Rent visuellt overlay-lager. Dekal-index per ruta är deterministiskt så
## kartan ser likadan ut varje gång men inte rutmönstrad.
const DECOR_NONE := -1
# 0 gul blomma · 1 röd · 2 grästuva · 3 vit blomma · 4 småsten · 5 stenflisa
# 6 svamp · 7 vass · 8 näckros · 9 snäckor
const DECOR_TILES := 10
const DECOR_DENSITY := 15     # ~% av dekorbara rutor som får en dekal
# Vilka dekaler som passar på vilken terräng
const DECOR_BY_TERRAIN := {
	".": [0, 1, 2, 3, 6],   # gräs: blommor, tuva, svamp
	",": [4, 5],            # jord: små stenar
	"g": [0, 3],            # åker: enstaka blommor i kanten
	"s": [7, 8, 6],         # träsk: vass, näckros, svamp
	"b": [9, 4],            # strand: snäckor, småsten
}

## Returnerar dekal-index (0..DECOR_TILES-1) för en ruta, eller DECOR_NONE.
static func decor_for(t: Vector2i, terrain: String) -> int:
	if not DECOR_BY_TERRAIN.has(terrain):
		return DECOR_NONE
	var opts: Array = DECOR_BY_TERRAIN[terrain]
	var h := absi((t.x * 374761393) ^ (t.y * 668265263))
	if h % 100 >= DECOR_DENSITY:
		return DECOR_NONE
	return int(opts[(h / 100) % opts.size()])

static func build_decor() -> TileSet:
	var img := Image.create(TILE * DECOR_TILES, TILE, false, Image.FORMAT_RGBA8)
	for i in DECOR_TILES:
		img.blit_rect(_make_decor_tile(i), Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in DECOR_TILES:
		src.create_tile(Vector2i(i, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

## Ritar en transparent dekal. Motivet placeras något off-center och fröas på
## index så de olika dekalerna inte ser identiska ut.
static func _make_decor_tile(idx: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + idx
	var ox := 10 + rng.randi_range(0, 12)
	var oy := 12 + rng.randi_range(0, 10)
	# Mjuk kontaktskugga vid motivets fot — jordar dekalen mot marken.
	_decor_shadow(img, ox, oy + 2, 4.0, 1.7)
	match idx:
		0: _draw_flower(img, ox, oy, Color("f2d23a"), Color("c79a12"))   # gul
		1: _draw_flower(img, ox, oy, Color("e0533a"), Color("a32f1c"))   # röd
		2: _draw_tuft(img, ox, oy)                                       # grästuva
		3: _draw_flower(img, ox, oy, Color("eef0f4"), Color("9aa6c0"))   # vit
		4: _draw_pebbles(img, ox, oy, 3)                                 # småsten
		5: _draw_pebbles(img, ox, oy, 2)                                 # stenflisa
		6: _draw_mushroom(img, ox, oy)                                   # svamp
		7: _draw_reeds(img, ox, oy)                                      # vass
		8: _draw_lily(img, ox, oy)                                       # näckros
		9: _draw_shells(img, ox, oy)                                     # snäckor
	return img

## Halvgenomskinlig mörk ellips — kontaktskugga under en dekal.
static func _decor_shadow(img: Image, cx: int, cy: int, rx: float, ry: float) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				_put(img, x, y, Color(0.0, 0.0, 0.0, 0.22 * (1.0 - d)))

static func _draw_flower(img: Image, cx: int, cy: int, petal: Color, center: Color) -> void:
	# Stjälk
	var stem := Color("2f6b2a")
	for y in range(cy, mini(cy + 6, TILE)):
		_put(img, cx, y, stem)
	# Fyllig 3×3-blomma: kronblad i kors + diagonaler, mitt i annan färg
	var hy := cy - 3
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, -1), Vector2i(1, -1)]:
		_put(img, cx + d.x, hy + d.y, petal)
	_put(img, cx, hy, center)

static func _draw_tuft(img: Image, cx: int, cy: int) -> void:
	# Tydlig tuva: mörka strån i botten, ljusa toppar — sticker ut mot graset.
	var blade := Color("2a5a22")
	var blade_hi := Color("6cc24f")
	for off in [-2, -1, 0, 1, 2]:
		var h := 4 - absi(off)               # mittstrået högst
		for k in range(h):
			var c := blade_hi if k == h - 1 else blade
			_put(img, cx + off, cy - k, c)

static func _draw_pebbles(img: Image, cx: int, cy: int, count: int) -> void:
	var stone := Color("9a948a")
	var stone_lo := Color("6f6a61")
	var spots := [Vector2i(0, 0), Vector2i(3, 1), Vector2i(-2, 2)]
	for i in count:
		var p: Vector2i = spots[i]
		_put(img, cx + p.x, cy + p.y, stone)
		_put(img, cx + p.x + 1, cy + p.y, stone)
		_put(img, cx + p.x, cy + p.y + 1, stone_lo)

## Liten röd flugsvamp med vita prickar — passar gräs och träsk.
static func _draw_mushroom(img: Image, cx: int, cy: int) -> void:
	var stem := Color("e8e2d2")
	var stem_lo := Color("c8c0ad")
	_put(img, cx, cy, stem); _put(img, cx, cy - 1, stem); _put(img, cx + 1, cy, stem_lo)
	var cap := Color("c43a2e")
	var cap_hi := Color("e0573a")
	for dx in [-2, -1, 0, 1, 2]:
		_put(img, cx + dx, cy - 2, cap)
	_put(img, cx - 1, cy - 3, cap); _put(img, cx, cy - 3, cap_hi); _put(img, cx + 1, cy - 3, cap)
	_put(img, cx, cy - 4, cap_hi)
	_put(img, cx - 1, cy - 2, Color("f3ead5")); _put(img, cx + 1, cy - 3, Color("f3ead5"))

## Vass/kaveldun: höga strån med brun kolv — träskkanter.
static func _draw_reeds(img: Image, cx: int, cy: int) -> void:
	var blade := Color("3f7d3a")
	var blade_hi := Color("5fa84a")
	for off in [-2, 0, 2]:
		var h := 8 - absi(off)
		for k in range(h):
			_put(img, cx + off, cy - k, blade_hi if k == h - 1 else blade)
	var cat := Color("6b4a2a")        # kolv på mittstrået
	for k in range(3, 6):
		_put(img, cx, cy - k, cat)
	_put(img, cx, cy - 6, Color("8a6238"))

## Näckrosblad med litet blomfäste — flyter på träsk.
static func _draw_lily(img: Image, cx: int, cy: int) -> void:
	var pad := Color("3a7d4a")
	var pad_hi := Color("4e9a5c")
	for y in range(-2, 3):
		for x in range(-3, 4):
			if float(x * x) / 9.0 + float(y * y) / 4.0 <= 1.0:
				_put(img, cx + x, cy + y, pad)
	_put(img, cx - 1, cy - 1, pad_hi); _put(img, cx, cy - 1, pad_hi)
	_put(img, cx + 2, cy, Color(0, 0, 0, 0))      # kilskåra i bladet
	_put(img, cx + 3, cy, Color(0, 0, 0, 0))
	_put(img, cx, cy - 2, Color("f0e6f4"))        # liten blomma

## Ett par snäckor i sanden — strandkanter.
static func _draw_shells(img: Image, cx: int, cy: int) -> void:
	var sh := Color("e7d3b0")
	var sh_lo := Color("c9ad84")
	_put(img, cx, cy - 2, sh)
	_put(img, cx - 1, cy - 1, sh); _put(img, cx, cy - 1, sh_lo); _put(img, cx + 1, cy - 1, sh)
	_put(img, cx - 1, cy, sh_lo); _put(img, cx, cy, sh); _put(img, cx + 1, cy, sh_lo)
	_put(img, cx + 3, cy + 1, sh); _put(img, cx + 3, cy, sh_lo)   # liten andra snäcka

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < TILE and y < TILE:
		img.set_pixel(x, y, c)

static func build() -> TileSet:
	# Atlas: TERRAIN.size() kolumner × VARIANTS rader.
	var img := Image.create(TILE * TERRAIN.size(), TILE * VARIANTS, false, Image.FORMAT_RGBA8)

	for ch in TERRAIN:
		var col: int = TERRAIN[ch]
		var base := _base_tile(ch, col)
		for v in VARIANTS:
			var tile_img: Image
			if ch == "t":
				tile_img = _make_tree_tile(v)   # äkta formvariation, inte bara ton
			elif v == 0:
				tile_img = base
			else:
				tile_img = _vary(base, ch, v)
			img.blit_rect(tile_img, Rect2i(0, 0, TILE, TILE), Vector2i(col * TILE, v * TILE))

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for col in TERRAIN.size():
		for v in VARIANTS:
			src.create_tile(Vector2i(col, v))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

## Bas-tilen för ett terrängtecken: riktig sprite om den finns, annars
## procedurell textur (träd/kullersten/åker) eller enfärgad fallback.
static func _base_tile(ch: String, col: int) -> Image:
	var fname: String = TILE_FILES.get(ch, "")
	if fname != "":
		var path := "res://assets/sprites/tiles/%s.png" % fname
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				var tile_img := tex.get_image()
				tile_img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
				if tile_img.get_format() != Image.FORMAT_RGBA8:
					tile_img.convert(Image.FORMAT_RGBA8)
				return tile_img

	match ch:
		"t": return _make_tree_tile()
		"c": return _make_cobblestone_tile()
		"g": return _make_field_tile()

	# Fallback: enfärgad med brusstruktur
	var base: Color = COLORS.get(ch, Color("888888"))
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13 + col * 31)) * 43758.5, 1.0)
			img.set_pixel(x, y, Color(base.r * n, base.g * n, base.b * n))
	return img

## Skapar en varierad kopia av en tile: subtil ljus-jitter + några ströpixlar,
## deterministiskt utifrån terräng + variant-index. Håller det diskret så
## kartan känns naturlig, inte brusig.
static func _vary(src_img: Image, ch: String, seed_v: int) -> Image:
	var img := src_img.duplicate() as Image
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ch) * 31 + seed_v
	# Global ton: ±5% ljusstyrka över hela tilen
	var tone := 1.0 + rng.randf_range(-0.05, 0.05)
	# Strukturella tiles ska hålla skarp form → mindre jitter
	var structural := ch in ["W", "r", "w", "n", "f"]
	var speck_amount := 4 if structural else 10
	for y in TILE:
		for x in TILE:
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(
				clampf(p.r * tone, 0.0, 1.0),
				clampf(p.g * tone, 0.0, 1.0),
				clampf(p.b * tone, 0.0, 1.0), p.a))
	# Strö in några ljusare/mörkare flagor
	for i in speck_amount:
		var sx := rng.randi_range(0, TILE - 1)
		var sy := rng.randi_range(0, TILE - 1)
		var p := img.get_pixel(sx, sy)
		var f := rng.randf_range(0.82, 1.18)
		img.set_pixel(sx, sy, Color(
			clampf(p.r * f, 0.0, 1.0),
			clampf(p.g * f, 0.0, 1.0),
			clampf(p.b * f, 0.0, 1.0), p.a))
	return img

## Ritar ett träd-tile: gräsbotten, brun stam och en bullig krona med mörk
## konturkant. Den höga, mörka silhuetten skiljer sig klart från det ljusa,
## platta gräset. `variant` (0..2) ger genuint olika form/storlek/färg så
## skogar inte blir en upprepad stämpel.
static func _make_tree_tile(variant := 0) -> Image:
	var presets := [
		# radius, cx, cy, höjdfaktor, krona, ljus, mörk, bump-frekvens, stam-höjd
		{"r": 11.0, "cx": 16.0, "cy": 12.0, "sq": 1.15, "c": Color("1f5a23"), "hi": Color("327f37"), "lo": Color("123d18"), "bf": 5.0, "th": 10},
		{"r": 13.0, "cx": 16.0, "cy": 11.0, "sq": 1.05, "c": Color("1a5530"), "hi": Color("2f8a4a"), "lo": Color("0e3a1e"), "bf": 4.0, "th": 11},
		{"r": 9.0,  "cx": 15.0, "cy": 14.0, "sq": 1.25, "c": Color("2c6b2a"), "hi": Color("4a9a3a"), "lo": Color("17401a"), "bf": 7.0, "th": 8},
	]
	var p: Dictionary = presets[variant % presets.size()]

	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)

	# Gräsbotten — identisk mellan varianter så trädet sitter i miljön
	var grass := Color("4a8f3c")
	for y in TILE:
		for x in TILE:
			var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13)) * 43758.5, 1.0)
			img.set_pixel(x, y, Color(grass.r * n, grass.g * n, grass.b * n))

	# Markskugga — bred ellips under kronan så trädet sitter i marken, inte svävar
	var sh_cx: float = p["cx"]
	var sh_cy: float = p["cy"] + p["r"] * 0.62
	var sh_rx: float = p["r"] * 0.92
	var sh_ry: float = p["r"] * 0.40
	for y in TILE:
		for x in TILE:
			var sdx := (float(x) - sh_cx) / sh_rx
			var sdy := (float(y) - sh_cy) / sh_ry
			var sd := sdx * sdx + sdy * sdy
			if sd <= 1.0:
				var k := 1.0 - 0.42 * (1.0 - sd)   # mörkast i mitten, tonar ut
				var gp := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(gp.r * k, gp.g * k, gp.b * k, gp.a))

	# Stam (centrerad under kronan, längd från preset)
	var trunk := Color("5b3a1a")
	var trunk_dark := Color("3f2812")
	var tx := int(p["cx"])
	var ty0 := int(p["cy"] + p["r"] * 0.5)
	for y in range(ty0, mini(ty0 + int(p["th"]), TILE)):
		for x in range(tx - 2, tx + 2):
			_put(img, x, y, trunk_dark if x >= tx else trunk)

	# Krona: bullig cirkel med mörk kant och ljus topp-vänster
	var cx: float = p["cx"]
	var cy: float = p["cy"]
	var base_r: float = p["r"]
	for y in TILE:
		for x in TILE:
			var dx := float(x) - cx
			var dy := (float(y) - cy) * float(p["sq"])
			var d := sqrt(dx * dx + dy * dy)
			var edge := base_r + 1.5 * sin(atan2(dy, dx) * float(p["bf"]))  # bullig kant
			if d <= edge:
				var shade: Color = p["c"]
				if d > edge - 2.0:
					shade = p["lo"]            # mörk kontur
				elif dx < -2.0 and dy < -2.0:
					shade = p["hi"]            # ljus topp-vänster
				img.set_pixel(x, y, shade)

	return img

## Kullersten: gråa rundade stenar i mörka fogar — för stadsgator/torg.
static func _make_cobblestone_tile() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var grout := Color("4a463f")
	img.fill(grout)
	# 2×2 rutnät av stenar, varannan rad förskjuten (murförband)
	var stones := [Color("9a958a"), Color("8a857a"), Color("a39d90"), Color("827d72")]
	var k := 0
	for gy in 2:
		var offset := 0 if gy == 0 else 8
		for gx in 3:
			var cx := gx * 16 + offset - 4
			var cy := gy * 16 + 8
			var base: Color = stones[k % stones.size()]
			k += 1
			for y in TILE:
				for x in TILE:
					var dx := float(x - cx)
					var dy := float(y - cy)
					var d := sqrt(dx * dx + dy * dy)
					if d <= 7.0:
						# Ljus topp, mörk botten för rundad känsla
						var sh := 1.0 + clampf(-dy / 14.0, -0.25, 0.25)
						img.set_pixel(x % TILE, y % TILE, Color(
							clampf(base.r * sh, 0, 1),
							clampf(base.g * sh, 0, 1),
							clampf(base.b * sh, 0, 1)))
	return img

## Åker: gyllengröna grödrader med fåror och kornprickar.
static func _make_field_tile() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var soil := Color("6b5a2e")
	var crop := Color("9aa84e")
	var crop_hi := Color("b9c463")
	for y in TILE:
		for x in TILE:
			# Vertikala rader: gröda på raden, mörkare jord i fåran
			var on_row := (x % 6) < 4
			var c := crop if on_row else soil
			# Lätt vågighet längs raden
			if on_row and ((x + y) % 5 == 0):
				c = crop_hi
			img.set_pixel(x, y, c)
	return img
