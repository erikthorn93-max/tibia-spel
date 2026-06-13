class_name PlaceholderTiles
## Genererar ett TileSet med enfärgade 32x32-tiles + svag brusstruktur.
## Byts mot riktigt tileset (LPC) i senare milstolpe — zone.gd berörs inte.

const TILE := 32
# atlas-kolumn per terrängtecken
const TERRAIN := {".": 0, ",": 1, "W": 2, "~": 3, "s": 4, "b": 5}
const COLORS := {
	".": Color("4a8f3c"), ",": Color("6b5436"),
	"W": Color("6e6e72"), "~": Color("2e5f9e"),
	"s": Color("4f5a2e"),   # sumpmark (Träsket)
	"b": Color("d8c88a"),   # strand (Saltvik)
}

static func build() -> TileSet:
	var img := Image.create(TILE * TERRAIN.size(), TILE, false, Image.FORMAT_RGBA8)
	for ch in TERRAIN:
		var base: Color = COLORS[ch]
		var col: int = TERRAIN[ch]
		for y in TILE:
			for x in TILE:
				var n := 0.93 + 0.07 * fmod(sin(float(x * 7 + y * 13 + col * 31)) * 43758.5, 1.0)
				img.set_pixel(col * TILE + x, y, Color(base.r * n, base.g * n, base.b * n))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for col in TERRAIN.size():
		src.create_tile(Vector2i(col, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts
