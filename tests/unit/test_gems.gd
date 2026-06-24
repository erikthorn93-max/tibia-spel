extends GutTest
## Tester för ädelsten- & smyckesinnehållet: nya items, recept-kedjan,
## gem-ådror och att de placerats i Kristallgrottan.

const ZoneScript = preload("res://world/zone.gd")

var db
func before_each():
	db = load("res://autoload/item_db.gd").new()
	db._load()
func after_each():
	db.free()

const GEMS := ["emerald", "sapphire", "ruby", "diamond", "dragonstone"]

# ── Items ──

func test_dragonstone_added_as_material():
	assert_true(db.items.has("dragonstone"), "draksten saknas")
	assert_eq(db.items["dragonstone"]["type"], "material")

func test_all_gems_exist_as_materials():
	for g in GEMS:
		assert_true(db.items.has(g), g)
		assert_eq(db.items[g]["type"], "material", g)

func test_jewelry_items_have_slot_and_armor():
	for g in GEMS:
		for kind in ["_ring", "_amulet"]:
			var id: String = g + kind
			assert_true(db.items.has(id), id)
			var d: Dictionary = db.items[id]
			assert_eq(d["type"], "armor", id)
			assert_gt(int(d.get("armor", 0)), 0, id + " ska ge armor (funktionellt)")
			assert_true(d["slot"] in ["ring", "amulet"], id)

func test_amulets_give_more_armor_than_rings():
	for g in GEMS:
		assert_gt(int(db.items[g + "_amulet"]["armor"]),
			int(db.items[g + "_ring"]["armor"]), g)

func test_dragonstone_jewelry_is_strongest():
	assert_gt(int(db.items["dragonstone_amulet"]["armor"]),
		int(db.items["emerald_amulet"]["armor"]))

func test_elixirs_have_functional_effects():
	# Varje elixir måste ge minst en effekt som use_item faktiskt applicerar.
	for g in GEMS:
		var d: Dictionary = db.items[g + "_elixir"]
		assert_true(d.has("buff") or d.has("heal") or d.has("mana"),
			g + "_elixir saknar funktionell effekt")

func test_skill_elixirs_buff_real_skills():
	# Buff-stat ska vara "skill:<x>" så effective_skill_level plockar upp den.
	for id in ["sapphire_elixir", "emerald_elixir", "ruby_elixir", "dragonstone_elixir"]:
		assert_eq(String(db.items[id]["buff"]["stat"]).begins_with("skill:"), true, id)

# ── Recept ──

func test_jewelry_recipes_exist_on_crafting_bench():
	var ids: Array = db.recipes["crafting_bench"].map(func(r): return r["id"])
	for g in GEMS:
		assert_true((g + "_ring") in ids, "recept saknas: " + g + "_ring")
		assert_true((g + "_amulet") in ids, "recept saknas: " + g + "_amulet")

func test_jewelry_recipes_consume_gem_and_gold():
	for r in db.recipes["crafting_bench"]:
		if String(r["id"]).ends_with("_ring") and String(r["id"]).split("_")[0] in GEMS:
			var gem: String = String(r["id"]).split("_")[0]
			assert_true(r["ingredients"].has(gem), r["id"] + " ska kräva " + gem)
			assert_true(r["ingredients"].has("gold_ore"), r["id"] + " ska kräva guldmalm")

func test_elixir_recipes_exist_on_alchemy_table():
	var ids: Array = db.recipes["alchemy_table"].map(func(r): return r["id"])
	for g in GEMS:
		assert_true((g + "_elixir") in ids, "elixir-recept saknas: " + g)

# ── Noder (gem-ådror) ──

func test_gem_veins_exist_and_yield_uncut_gems():
	for g in GEMS:
		var id: String = g + "_vein"
		assert_true(db.nodes.has(id), id)
		assert_eq(db.nodes[id]["yields"], "uncut_" + g, id + " ska ge oslipad sten")
		assert_eq(db.nodes[id]["skill"], "mining", id)
		assert_eq(db.nodes[id]["tool"], "pickaxe", id)

func test_uncut_gems_exist_and_cheaper_than_cut():
	for g in GEMS:
		var raw: String = "uncut_" + g
		assert_true(db.items.has(raw), raw)
		assert_eq(db.items[raw]["type"], "material", raw)
		assert_lt(int(db.items[raw]["value"]), int(db.items[g]["value"]),
			raw + " ska vara billigare än slipad")

func test_cutting_recipes_turn_uncut_into_cut():
	for g in GEMS:
		var found := false
		for r in db.recipes["crafting_bench"]:
			if r["id"] == g and r["ingredients"].has("uncut_" + g):
				found = true
				assert_eq(String(r["skill"]), "crafting", g)
		assert_true(found, "slipnings-recept saknas för " + g)

func test_dragonstone_vein_needs_highest_level():
	for g in ["emerald", "sapphire", "ruby", "diamond"]:
		assert_lt(int(db.nodes[g + "_vein"]["level"]),
			int(db.nodes["dragonstone_vein"]["level"]), g)

# ── Placering i Kristallgrottan ──

func test_gem_cavern_has_new_veins_placed():
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build("thais_gemcavern")
	var placed: Array = z.node_points.map(func(n): return n["node"])
	for g in GEMS:
		assert_true((g + "_vein") in placed, "ådra ej placerad i grottan: " + g + "_vein")
