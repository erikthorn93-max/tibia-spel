class_name PlaceholderTiles
## Bygger ett TileSet från riktiga tile-sprites (assets/sprites/tiles/).
## Terrängtecken → atlas-kolumn matchas via TERRAIN-konstanten.
## zone.gd berörs inte — byter bara visuellt.

const TILE := 32
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

static func build() -> TileSet:
	# Bygg en bred atlas-bild: TERRAIN.size() kolumner × TILE px
	var img := Image.create(TILE * TERRAIN.size(), TILE, false, Image.FORMAT_RGBA8)

	for ch in TERRAIN:
		var col: int = TERRAIN[ch]
		var fname: String = TILE_FILES.get(ch, "")
		var tile_img: Image = null

		if fname != "":
			var path := "res://assets/sprites/tiles/%s.png" % fname
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path) as Texture2D
				if tex != null:
					tile_img = tex.get_image()
					tile_img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)

		# Träd har ingen sprite → rita ett tydligt hinder (stam + krona med mörk kant)
		# så det inte förväxlas med gångbart gräs.
		if tile_img == null and ch == "t":
			tile_img = _make_tree_tile()

		if tile_img == null:
			# Fallback: enfärgad med brusstruktur
			var base: Color = COLORS.get(ch, Color("888888"))
			tile_img = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
			for y in TILE:
				for x in TILE:
					var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13 + col * 31)) * 43758.5, 1.0)
					tile_img.set_pixel(x, y, Color(base.r * n, base.g * n, base.b * n))

		# Kopiera in i atlas
		for y in TILE:
			for x in TILE:
				img.set_pixel(col * TILE + x, y, tile_img.get_pixel(x, y))

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for col in TERRAIN.size():
		src.create_tile(Vector2i(col, 0))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts

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
