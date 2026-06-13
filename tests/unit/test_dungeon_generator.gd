extends GutTest
## DungeonGenerator: determinism, struktur, konnektivitet, spawntak, temaintegritet.

const Gen = preload("res://world/dungeon_generator.gd")

func _gen(theme := "katakomber", dseed := 12345) -> Dictionary:
	return Gen.generate(theme, dseed)

func _count_in_tiles(tiles: Array, ch: String) -> int:
	var n := 0
	for row in tiles:
		for i in row.length():
			if row[i] == ch:
				n += 1
	return n

func test_deterministic_same_seed():
	assert_eq(_gen("katakomber", 7)["tiles"], _gen("katakomber", 7)["tiles"])

func test_different_seeds_differ():
	assert_ne(_gen("katakomber", 1)["tiles"], _gen("katakomber", 2)["tiles"])

func test_structure_counts():
	for dseed in [1, 99, 4711]:
		var d := _gen("katakomber", dseed)
		assert_eq(_count_in_tiles(d["tiles"], "P"), 1, "seed %d: P" % dseed)
		assert_eq(_count_in_tiles(d["tiles"], "0"), 1, "seed %d: exit" % dseed)
		assert_eq(_count_in_tiles(d["tiles"], "C"), 1, "seed %d: kista" % dseed)

func test_rows_equal_length_and_outer_wall():
	var d := _gen()
	var tiles: Array = d["tiles"]
	var w: int = tiles[0].length()
	for y in tiles.size():
		var row: String = tiles[y]
		assert_eq(row.length(), w, "rad %d" % y)
		assert_eq(row[0], "W", "vänsterkant rad %d" % y)
		assert_eq(row[w - 1], "W", "högerkant rad %d" % y)
	for x in w:
		assert_eq(String(tiles[0])[x], "W")
		assert_eq(String(tiles[tiles.size() - 1])[x], "W")

func test_all_open_tiles_reachable_from_start():
	for dseed in [3, 1337]:
		var d := _gen("katakomber", dseed)
		var tiles: Array = d["tiles"]
		var start := Vector2i(-1, -1)
		var open := {}
		for y in tiles.size():
			var row: String = tiles[y]
			for x in row.length():
				if row[x] != "W":
					open[Vector2i(x, y)] = true
				if row[x] == "P":
					start = Vector2i(x, y)
		# flood fill
		var seen := {start: true}
		var queue := [start]
		while not queue.is_empty():
			var t: Vector2i = queue.pop_front()
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = t + dir
				if open.has(n) and not seen.has(n):
					seen[n] = true
					queue.append(n)
		assert_eq(seen.size(), open.size(), "seed %d: onåbara tiles" % dseed)

func test_spawn_cap_and_pool():
	var d := _gen("sjunkna_graven", 42)
	var legend: Dictionary = d["legend"]
	var pool := ["Giftpadda", "Orm", "Träskdjävul"]
	var spawn_count := 0
	for ch in legend:
		var e: Dictionary = legend[ch]
		if String(e["type"]) == "spawn":
			assert_has(pool, String(e["monster"]), "monster utanför poolen")
			assert_true(MonsterDB.monsters.has(String(e["monster"])))
			spawn_count += _count_in_tiles(d["tiles"], String(ch))
	assert_between(spawn_count, 1, 30)

func test_exit_zone_and_meta():
	var k := _gen("katakomber", 5)
	assert_eq(String(k["exit_zone"]), "cave")
	assert_eq(String(k["theme"]), "katakomber")
	assert_eq(String(k["legend"]["0"]["to"]), "cave")
	var s := _gen("sjunkna_graven", 5)
	assert_eq(String(s["exit_zone"]), "swamp")

func test_chest_in_legend():
	var d := _gen()
	assert_eq(String(d["legend"]["C"]["type"]), "chest")
	assert_false(d["legend"].has("P"), "P hanteras av zone.gd, inte legenden")

func test_themes_integrity():
	var f := FileAccess.open("res://data/dungeon_themes.json", FileAccess.READ)
	var themes: Dictionary = JSON.parse_string(f.get_as_text())
	assert_eq(themes.size(), 3)
	var nodes: Dictionary = JSON.parse_string(FileAccess.open("res://data/nodes.json", FileAccess.READ).get_as_text())
	for tid in themes:
		var th: Dictionary = themes[tid]
		assert_true(FileAccess.file_exists("res://data/zones/%s.json" % th["exit_zone"]), "%s: okänd exit_zone" % tid)
		for m in th["monsters"]:
			assert_true(MonsterDB.monsters.has(String(m[0])), "%s: okänt monster %s" % [tid, m[0]])
			assert_gt(int(m[1]), 0, "%s: vikt" % tid)
		for n in th["nodes"]:
			assert_true(nodes.has(String(n)), "%s: okänd nod %s" % [tid, n])
		for it in th["chest_items"]:
			assert_true(ItemDB.items.has(String(it[0])), "%s: okänt item %s" % [tid, it[0]])
		assert_eq(th["chest_gold"].size(), 2)

func test_sunken_ship_exit_to_coast():
	var d := _gen("sjunket_skepp", 3)
	assert_eq(String(d["exit_zone"]), "coast")

func test_sunken_ship_places_boss_in_end_room():
	var d := _gen("sjunket_skepp", 7)
	assert_true(d["legend"].has("B"), "boss-tile saknas i legenden")
	assert_eq(String(d["legend"]["B"]["type"]), "spawn")
	assert_eq(String(d["legend"]["B"]["monster"]), "Piratkapten Svartöga")
	assert_eq(_count_in_tiles(d["tiles"], "B"), 1)
	assert_true(MonsterDB.monsters.has("Piratkapten Svartöga"))
