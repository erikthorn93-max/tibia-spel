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

static func build() -> TileSet:
	# Atlas: TERRAIN.size() kolumner × VARIANTS rader.
	var img := Image.create(TILE * TERRAIN.size(), TILE * VARIANTS, false, Image.FORMAT_RGBA8)

	for ch in TERRAIN:
		var col: int = TERRAIN[ch]
		var base := _base_tile(ch, col)
		for v in VARIANTS:
			var tile_img := base if v == 0 else _vary(base, ch, v)
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

## Ritar ett tydligt träd-tile: gräsbotten, brun stam och en bullig krona
## med mörk konturkant. Den höga, mörka silhuetten skiljer sig klart från
## det ljusa, platta gräset så spelaren ser var det inte går att gå.
static func _make_tree_tile() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)

	# Gräsbotten så trädet sitter i miljön
	var grass := Color("4a8f3c")
	for y in TILE:
		for x in TILE:
			var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13)) * 43758.5, 1.0)
			img.set_pixel(x, y, Color(grass.r * n, grass.g * n, grass.b * n))

	# Stam (centrerad, nedre delen)
	var trunk := Color("5b3a1a")
	var trunk_dark := Color("3f2812")
	for y in range(20, 30):
		for x in range(14, 18):
			img.set_pixel(x, y, trunk_dark if x >= 16 else trunk)

	# Krona: bullig cirkel med mörk kant och ljus topp-vänster
	var cx := 16.0
	var cy := 12.0
	var canopy := Color("1f5a23")
	var canopy_hi := Color("327f37")
	var canopy_lo := Color("123d18")
	for y in TILE:
		for x in TILE:
			var dx := float(x) - cx
			var dy := (float(y) - cy) * 1.15
			var d := sqrt(dx * dx + dy * dy)
			var edge := 11.0 + 1.5 * sin(atan2(dy, dx) * 5.0)  # bullig kant
			if d <= edge:
				var shade := canopy
				if d > edge - 2.0:
					shade = canopy_lo          # mörk kontur
				elif dx < -2.0 and dy < -2.0:
					shade = canopy_hi          # ljus topp-vänster
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
