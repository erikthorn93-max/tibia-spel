extends GutTest
## Regressionsvakt: de två tidigare föräldralösa bossarna Elddraken och
## Urskogsvältaren ska nu ha riktiga, nåbara boss-lairs som låses upp via quest.

const ZoneScript = preload("res://world/zone.gd")

func before_each():
	UnlockSystem.unlocked.clear()

func after_each():
	UnlockSystem.unlocked.clear()

func _make_zone(zone_id: String):
	var z = ZoneScript.new()
	add_child_autofree(z)
	z.build(zone_id)
	return z

func _boss_tile(z, boss: String) -> Vector2i:
	for sp in z.spawn_points:
		if String(sp["monster"]) == boss:
			return sp["tile"]
	return Vector2i(-1, -1)

# --- Lair-zonerna laddar och bossen är nåbar från player_start ---

func test_drakboet_loads_and_elddraken_reachable():
	var z = _make_zone("drakboet")
	assert_ne(z.player_start, Vector2i.ZERO, "drakboet saknar player_start")
	var boss := _boss_tile(z, "Elddraken")
	assert_ne(boss, Vector2i(-1, -1), "Elddraken spawnar inte i drakboet")
	assert_true(z.is_walkable(boss), "Elddrakens tile ska vara gångbar")
	var path = z.find_path(z.player_start, boss)
	assert_gt(path.size(), 0, "ingen väg från start till Elddraken")

func test_urskog_loads_and_valtaren_reachable():
	var z = _make_zone("urskogens_hjarta")
	assert_ne(z.player_start, Vector2i.ZERO, "urskogens_hjarta saknar player_start")
	var boss := _boss_tile(z, "Urskogsvältaren")
	assert_ne(boss, Vector2i(-1, -1), "Urskogsvältaren spawnar inte i urskogens_hjarta")
	assert_true(z.is_walkable(boss), "Urskogsvältarens tile ska vara gångbar")
	var path = z.find_path(z.player_start, boss)
	assert_gt(path.size(), 0, "ingen väg från start till Urskogsvältaren")

# --- Lairsen har en återväg till föräldra-zonen ---

func test_lairs_have_return_portal():
	var d = _make_zone("drakboet")
	assert_true(d.portals.values().has("volcano"), "drakboet saknar återväg till volcano")
	var u = _make_zone("urskogens_hjarta")
	assert_true(u.portals.values().has("dimmoren"), "urskogens_hjarta saknar återväg till dimmoren")

# --- Portalerna in i lairsen är låsta tills rätt unlock erhållits ---

func test_volcano_portal_to_drakboet_is_locked_by_default():
	var z = _make_zone("volcano")
	assert_true(z.portals.values().has("drakboet"), "volcano saknar portal till drakboet")
	assert_true(z.portal_locks.values().has("drakboet"), "drakboet-portalen ska vara låst utan unlock")

func test_dimmoren_portal_to_urskog_is_locked_by_default():
	var z = _make_zone("dimmoren")
	assert_true(z.portals.values().has("urskogens_hjarta"), "dimmoren saknar portal till urskogens_hjarta")
	assert_true(z.portal_locks.values().has("urskogens_hjarta"), "urskog-portalen ska vara låst utan unlock")

func test_unlock_opens_drakboet_portal():
	UnlockSystem.unlocked["drakboet"] = true
	var z = _make_zone("volcano")
	assert_false(z.portal_locks.values().has("drakboet"), "drakboet-portalen ska vara öppen efter unlock")

# --- Questkedjorna belönar rätt unlock så portalerna faktiskt kan öppnas ---

func test_quest_drake_1_unlocks_drakboet():
	var q: Dictionary = QuestSystem.quests.get("quest_drake_1", {})
	assert_false(q.is_empty(), "quest_drake_1 saknas")
	assert_true(q.get("rewards", {}).get("unlocks", []).has("drakboet"),
		"quest_drake_1 ska låsa upp drakboet")

func test_quest_urskog_1_unlocks_urskogens_hjarta():
	var q: Dictionary = QuestSystem.quests.get("quest_urskog_1", {})
	assert_false(q.is_empty(), "quest_urskog_1 saknas")
	assert_true(q.get("rewards", {}).get("unlocks", []).has("urskogens_hjarta"),
		"quest_urskog_1 ska låsa upp urskogens_hjarta")

func test_kapstensquesterna_kraver_forsta_steget():
	assert_true(QuestSystem.quests.get("quest_drake_2", {}).get("requires", []).has("quest_drake_1"),
		"quest_drake_2 ska kräva quest_drake_1")
	assert_true(QuestSystem.quests.get("quest_urskog_2", {}).get("requires", []).has("quest_urskog_1"),
		"quest_urskog_2 ska kräva quest_urskog_1")

# --- De tidigare föräldralösa bossarna är nu faktiskt placerade i en zon ---

func test_bossarna_ar_inte_langre_foraldralosa():
	var fyndade := {"Elddraken": false, "Urskogsvältaren": false}
	for fn in DirAccess.get_files_at("res://data/zones"):
		if not fn.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/zones/%s" % fn, FileAccess.READ)
		var z = JSON.parse_string(f.get_as_text()) if f else null
		if not (z is Dictionary):
			continue
		for ch in z.get("legend", {}):
			var e: Dictionary = z["legend"][ch]
			if String(e.get("type", "")) == "spawn" and fyndade.has(String(e.get("monster", ""))):
				fyndade[String(e["monster"])] = true
		for entry in z.get("spawn_table", []):
			if fyndade.has(String(entry.get("monster", ""))):
				fyndade[String(entry["monster"])] = true
	assert_true(fyndade["Elddraken"], "Elddraken placeras inte i någon zon")
	assert_true(fyndade["Urskogsvältaren"], "Urskogsvältaren placeras inte i någon zon")
