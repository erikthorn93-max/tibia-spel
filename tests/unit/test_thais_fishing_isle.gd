extends GutTest
## Tester för Fiskemästar-kedjan: Stormrevet (thais_fishing_isle),
## båt-portal i hamnen, dual-gate unlock, quest och högnivå-fiskenoder.

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

# ── Region ──

func test_isle_loads_and_returns():
	var z = _make_zone("thais_fishing_isle")
	assert_true(z.portals.values().has("thais_docks"), "Stormrevet saknar retur till hamnen")
	assert_ne(z.player_start, Vector2i.ZERO, "Stormrevet player_start saknas")
	assert_true(z.is_walkable(z.player_start), "Stormrevet player_start ej gångbar")

func test_isle_has_high_level_fishing_nodes():
	var z = _make_zone("thais_fishing_isle")
	var node_ids := []
	for np in z.node_points:
		node_ids.append(String(np["node"]))
	for n in ["lobster_pot", "swordfish_spot", "tuna_spot", "shark_spot"]:
		assert_true(node_ids.has(n), "Stormrevet saknar fiskenod %s" % n)

func test_isle_has_stove_and_fishmaster():
	var z = _make_zone("thais_fishing_isle")
	var stations := []
	for sp in z.station_points:
		stations.append(String(sp["station"]))
	assert_true(stations.has("stove"), "Stormrevet saknar stekplats (stove)")
	assert_eq(String(DialogueDB.npcs["npc_fishmaster"]["zone"]), "thais_fishing_isle",
		"fiskemästaren hör inte hemma på Stormrevet")

func test_isle_nodes_reachable():
	var z = _make_zone("thais_fishing_isle")
	for np in z.node_points:
		var path = z.find_path_adjacent(z.player_start, np["tile"])
		assert_gt(path.size(), 0, "nod %s vid %s ej nåbar" % [np["node"], str(np["tile"])])

# ── Hamnens båt-portal: låst tills Stormrevet låses upp ──

func test_docks_has_locked_isle_portal():
	var z = _make_zone("thais_docks")   # fiskeon ej upplåst i before_each
	assert_true(z.portals.values().has("thais_fishing_isle"), "hamnen saknar båt-portal till Stormrevet")
	assert_true(z.portal_locks.values().has("fiskeon"), "båt-portalen är inte låst bakom fiskeon")

func test_docks_isle_portal_unlocks():
	UnlockSystem.unlock("fiskeon")
	var z = _make_zone("thais_docks")
	assert_true(z.portals.values().has("thais_fishing_isle"), "hamnen saknar båt-portal")
	assert_false(z.portal_locks.values().has("fiskeon"), "båt-portalen ska vara olåst när fiskeon är upplåst")

# ── Dual-gate unlock: quest + Fishing 40 ──

func test_fiskeon_requires_quest_and_skill():
	assert_true(UnlockSystem.defs.has("fiskeon"), "unlock fiskeon saknas")
	var r: Dictionary = UnlockSystem.defs["fiskeon"]["requires"]
	assert_eq(String(r["quest"]), "quest_fiskemastaren", "fiskeon ska kräva quest_fiskemastaren")
	assert_eq(String(r["skill"]), "fishing", "fiskeon ska kräva fishing-skill")
	assert_eq(int(r["level"]), 40, "fiskeon ska kräva Fishing 40")

func test_fiskeon_locked_without_both_gates():
	# Bara quest klarad, men för låg skill → fortfarande låst
	QuestSystem.completed["quest_fiskemastaren"] = true
	assert_false(UnlockSystem.can_unlock("fiskeon"), "fiskeon ska kräva BÅDE quest och skill 40")
	QuestSystem.completed.erase("quest_fiskemastaren")

# ── Quest ──

func test_fishing_master_quest_chain():
	assert_true(QuestSystem.quests.has("quest_fiskemastaren"), "quest_fiskemastaren saknas")
	var q: Dictionary = QuestSystem.quests["quest_fiskemastaren"]
	assert_eq(String(q["giver"]), "npc_captain", "fel quest-givare")
	assert_true(Array(q["requires"]).has("quest_sjovagen"), "ska bygga på quest_sjovagen")
	# stegen samlar fisk och rapporterar till kaptenen
	var types := []
	for s in q["steps"]:
		types.append(String(s["type"]))
	assert_true(types.has("collect"), "saknar collect-steg")
	assert_eq(String(q["steps"][-1]["type"]), "talk_to", "sista steget ska vara talk_to")

# ── Noder & items ──

func test_new_fishing_nodes_defined():
	# noder laddas via data/nodes.json → läs direkt
	var f := FileAccess.open("res://data/nodes.json", FileAccess.READ)
	var nodes: Dictionary = JSON.parse_string(f.get_as_text())
	assert_eq(String(nodes["tuna_spot"]["skill"]), "fishing")
	assert_eq(int(nodes["tuna_spot"]["level"]), 40)
	assert_eq(String(nodes["shark_spot"]["skill"]), "fishing")
	assert_eq(int(nodes["shark_spot"]["level"]), 50)

func test_new_fish_items_and_recipes():
	for id in ["raw_tuna", "raw_shark", "cooked_tuna", "cooked_shark"]:
		assert_true(ItemDB.items.has(id), "item %s saknas" % id)
	# kok-recept för de nya fiskarna
	var f := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	var recipes: Dictionary = JSON.parse_string(f.get_as_text())
	var stove_outputs := []
	for r in recipes["stove"]:
		stove_outputs.append(String(r["id"]))
	assert_true(stove_outputs.has("cooked_tuna"), "saknar recept cooked_tuna")
	assert_true(stove_outputs.has("cooked_shark"), "saknar recept cooked_shark")
