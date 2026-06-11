extends GutTest

var idb
var mdb

func before_each():
	idb = load("res://autoload/item_db.gd").new()
	idb._load()
	mdb = load("res://autoload/monster_db.gd").new()
	mdb._load()

func after_each():
	idb.free(); mdb.free()

func test_items_loaded():
	assert_true(idb.items.has("health_potion"))
	assert_eq(idb.items["health_potion"]["heal"], 60)

func test_monsters_loaded():
	assert_true(mdb.monsters.has("Ghoul"))
	assert_eq(int(mdb.monsters["Ghoul"]["hp"]), 95)

func test_roll_loot_returns_valid_items():
	for i in 20:
		for entry in idb.roll_loot(mdb.monsters["Skelett"]["loot"]):
			assert_true(idb.items.has(entry["item"]))
			assert_gt(int(entry["qty"]), 0)
