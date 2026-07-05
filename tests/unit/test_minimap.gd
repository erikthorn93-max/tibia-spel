extends GutTest
## Minimap: POI-tjänster (bank/handlare/lärare/stationer), NPC-markörer och
## kantpilar. Vakt mot att en ny stationstyp saknar glyf/etikett, att _pois
## mappar zon-data till rätt markörer, att terrängcachen byggs ur ZoneModel
## och att 3D-bryggan (game3d/Hud3D) kopplar entitetskällorna.

const Minimap = preload("res://ui/minimap.gd")
const Game3DScene = preload("res://world/game3d.tscn")

# Stub-modell: bara de fält _pois()/_unique_portals() läser.
class StubZone extends Node2D:
	var bank_points: Array = []
	var shop_points: Array = []
	var spell_teacher_points: Array = []
	var station_points: Array = []
	var portals: Dictionary = {}

var mm
var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model

func before_each():
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model
	# .new() utan att lägga i trädet → inget _ready/_process/_draw (rör ej World).
	# autofree → GUT städar vid test-slut (ingen orphan/RID-läcka).
	mm = autofree(Minimap.new())

func after_each():
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model

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

# ── Modellbaserad terrängcache (renderer-agnostisk) ───────────────────────────

func _load_model(zone_id: String) -> ZoneModel:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var m := ZoneModel.new()
	m.parse(JSON.parse_string(f.get_as_text()), zone_id)
	return m

func test_tile_cache_byggs_ur_zone_model():
	var m := _load_model("thais_fields")
	World.zone_model = m
	mm._maybe_rebuild_cache()
	assert_eq(mm._tile_cache.size(), m.grid_size.x * m.grid_size.y,
		"cachen ska täcka hela gridden — utan tilemap")
	var checked := false
	for t in m.terrain:
		if String(m.terrain[t]) == ".":
			assert_eq(mm._tile_cache[t], Minimap.T_COLORS["."],
				"gräsrutor ska få gräsfärgen ur terrängtecknet")
			checked = true
			break
	assert_true(checked, "thais_fields ska ha minst en gräsruta")
	assert_eq(mm._portal_names.size(), m.portals.size(),
		"varje portalruta ska få ett uppslaget destinationsnamn")

func test_cache_byggs_om_vid_modellbyte():
	World.zone_model = _load_model("thais_fields")
	mm._maybe_rebuild_cache()
	var first: ZoneModel = mm._last_model
	World.zone_model = _load_model("town")
	mm._maybe_rebuild_cache()
	assert_ne(mm._last_model, first, "ny modell ska trigga ombyggnad")
	assert_eq(mm._last_model, World.zone_model)

# ── 3D-bryggan: game3d publicerar modellen och kopplar källorna ───────────────

func test_game3d_publicerar_model_och_kopplar_minimapkallor():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	assert_eq(World.zone_model, g.model, "game3d ska publicera sin ZoneModel")
	var mm3: Control = g.hud.minimap
	assert_not_null(mm3, "3D-HUD:en ska ha en minimap")
	assert_eq((mm3.loot_source.call() as Array).size(), 0,
		"ingen markloot i 3D-slicen")
	var expected := 0
	for id in DialogueDB.npcs:
		if String(DialogueDB.npcs[id]["zone"]) == g.model.zone_id:
			expected += 1
	assert_eq((mm3.npc_source.call() as Array).size(), expected,
		"npc-källan ska lista zonens dialog-NPC:er")
	assert_gt((mm3.monsters_source.call() as Array).size(), 0,
		"startzonen ska ha levande monster på kartan")

func test_game3d_zonbyte_uppdaterar_publicerad_modell():
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	var first: ZoneModel = g.model
	g.load_zone("town")
	assert_ne(g.model, first)
	assert_eq(World.zone_model, g.model,
		"zonbytet ska publicera den nya modellen till minimapen")

func test_unique_portals_dedupar_per_destination():
	# Två portalrutor till samma zon ska ge EN etikett (mot plottriga dubbletter).
	var z = autofree(StubZone.new()) as Node2D
	z.portals = {Vector2i(5, 0): "town", Vector2i(6, 0): "town", Vector2i(0, 9): "forest"}
	var uniq: Array = mm._unique_portals(z)
	assert_eq(uniq.size(), 2, "tre rutor men två destinationer → två etiketter")
	var dests := {}
	for t in uniq:
		dests[String(z.portals[t])] = true
	assert_true(dests.has("town") and dests.has("forest"), "båda destinationerna ska representeras")
