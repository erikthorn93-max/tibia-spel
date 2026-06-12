extends GutTest
## Referensintegritet: unlocks ↔ zoner ↔ tasks ↔ outfits ↔ skills/quests/monster.

var unlocks: Dictionary
var outfits: Dictionary
var tasks: Dictionary

func before_all():
	unlocks = _load("res://data/unlocks.json")
	outfits = _load("res://data/outfits.json")
	tasks = _load("res://data/tasks.json")

func _load(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

func test_data_files_exist():
	assert_false(unlocks.is_empty(), "unlocks.json saknas/tom")
	assert_false(outfits.is_empty(), "outfits.json saknas/tom")

func test_unlock_defs_valid():
	for id in unlocks:
		var u: Dictionary = unlocks[id]
		assert_true(u.has("name"), "%s: saknar name" % id)
		assert_has(["area", "shortcut", "outfit"], String(u["category"]), "%s: okänd kategori" % id)
		var r: Dictionary = u.get("requires", {})
		if r.has("skill"):
			assert_true(GameState.skill_defs.has(String(r["skill"])), "%s: okänd skill" % id)
			assert_gt(int(r.get("level", 0)), 0, "%s: skill-krav utan level" % id)
		if r.has("quest"):
			assert_true(QuestSystem.quests.has(String(r["quest"])), "%s: okänd quest" % id)
		if r.has("task_completed"):
			assert_true(tasks.has(String(r["task_completed"])), "%s: okänd task" % id)
		if r.has("boss_killed"):
			assert_true(MonsterDB.monsters.has(String(r["boss_killed"])), "%s: okänt monster" % id)
		if r.has("unlock"):
			assert_true(unlocks.has(String(r["unlock"])), "%s: kedjar mot okänd unlock" % id)
		if not r.is_empty():
			assert_true(u.has("hint"), "%s: krav utan hint" % id)

func test_zone_refs_exist_in_unlocks():
	for fn in DirAccess.get_files_at("res://data/zones"):
		if not fn.ends_with(".json"):
			continue
		var zid := fn.trim_suffix(".json")
		var z := _load("res://data/zones/%s.json" % zid)
		assert_false(z.is_empty(), "zon %s saknas" % zid)
		for ch in z.get("legend", {}):
			var e: Dictionary = z["legend"][ch]
			match String(e["type"]):
				"gate", "shortcut":
					assert_true(unlocks.has(String(e["unlock"])), "%s/%s: okänd unlock" % [zid, ch])
				"portal":
					if e.has("unlock"):
						assert_true(unlocks.has(String(e["unlock"])), "%s/%s: okänd portal-unlock" % [zid, ch])
					assert_true(FileAccess.file_exists("res://data/zones/%s.json" % e["to"]), "%s/%s: okänd målzon" % [zid, ch])

func test_task_unlocks_exist():
	for id in tasks:
		if tasks[id].has("unlocks"):
			assert_true(unlocks.has(String(tasks[id]["unlocks"])), "%s: okänd unlock" % id)

func test_outfits_valid():
	assert_true(outfits.has("standard"), "standard-outfit saknas")
	for id in outfits:
		var o: Dictionary = outfits[id]
		assert_true(o.has("name"), "%s: saknar name" % id)
		for key in o.get("colors", {}):
			assert_has(["hair", "shirt", "pants"], String(key), "%s: otillåten färgnyckel %s (skin är skyddad)" % [id, key])
		var uid := String(o.get("unlock", ""))
		if id == "standard":
			assert_eq(uid, "", "standard ska inte ha unlock")
		else:
			assert_true(unlocks.has(uid), "%s: okänd unlock" % id)
			assert_eq(String(unlocks[uid]["category"]), "outfit", "%s: unlock %s har fel kategori" % [id, uid])

func test_every_outfit_unlock_has_an_outfit():
	var used := {}
	for id in outfits:
		if outfits[id].get("unlock", "") != "":
			used[String(outfits[id]["unlock"])] = true
	for id in unlocks:
		if String(unlocks[id]["category"]) == "outfit":
			assert_true(used.has(id), "%s: outfit-unlock utan outfit" % id)
