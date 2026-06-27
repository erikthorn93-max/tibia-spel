extends GutTest
## Minimap: POI-tjänster (bank/handlare/lärare/stationer), NPC-markörer och
## kantpilar. Vakt mot att en ny stationstyp saknar glyf/etikett, samt att
## _pois mappar zon-data till rätt markörer.

const Minimap = preload("res://ui/minimap.gd")

# Stub-zon: bara de fält _pois() läser.
class StubZone extends Node2D:
	var bank_points: Array = []
	var shop_points: Array = []
	var spell_teacher_points: Array = []
	var station_points: Array = []

var mm

func before_each():
	# .new() utan att lägga i trädet → inget _ready/_process/_draw (rör ej World).
	# autofree → GUT städar vid test-slut (ingen orphan/RID-läcka).
	mm = autofree(Minimap.new())

func test_minimap_kompilerar():
	assert_not_null(mm, "minimap-scriptet gick inte att instansiera")

func test_alla_stationstyper_har_glyf_och_etikett():
	# Samla varje station-typ som faktiskt förekommer i någon zon.
	var seen := {}
	var dir := DirAccess.open("res://data/zones")
	for fn in dir.get_files():
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/zones/" + fn, FileAccess.READ)
		var z = JSON.parse_string(f.get_as_text())
		if not (z is Dictionary):
			continue
		for k in z.get("legend", {}):
			var e = z["legend"][k]
			if e is Dictionary and String(e.get("type", "")) == "station":
				seen[String(e.get("station", ""))] = true
	var missing := []
	for st in seen:
		if not Minimap.STATION_GLYPH.has(st) or not Minimap.STATION_LABEL.has(st):
			missing.append(st)
	assert_eq(missing, [], "stationstyper utan glyf/etikett i minimapen: %s" % str(missing))

func test_pois_mappar_bank_shop_larare():
	var z = autofree(StubZone.new()) as Node2D
	z.bank_points = [Vector2i(1, 1)]
	z.shop_points = [Vector2i(2, 2)]
	z.spell_teacher_points = [Vector2i(3, 3)]
	var pois: Array = mm._pois(z)
	var glyphs := {}
	for p in pois:
		glyphs[String(p["glyph"])] = String(p["label"])
	assert_eq(glyphs.get("$", ""), "Bank")
	assert_eq(glyphs.get("H", ""), "Handlare")
	assert_eq(glyphs.get("L", ""), "Runlärare")


func test_pois_mappar_station_till_glyf():
	var z = autofree(StubZone.new()) as Node2D
	z.station_points = [{"tile": Vector2i(4, 4), "station": "anvil"}]
	var pois: Array = mm._pois(z)
	assert_eq(pois.size(), 1)
	assert_eq(String(pois[0]["glyph"]), "A", "anvil ska mappas till glyfen A")
	assert_eq(String(pois[0]["label"]), "Städ")


func test_okand_station_far_fallback_glyf():
	var z = autofree(StubZone.new()) as Node2D
	z.station_points = [{"tile": Vector2i(0, 0), "station": "nonexistent"}]
	var pois: Array = mm._pois(z)
	assert_eq(String(pois[0]["glyph"]), "+", "okänd station ska få fallback-glyfen +")
