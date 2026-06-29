extends GutTest
## Integritetstest för de atmosfäriska NPC:er som befolkar tidigare tomma zoner.
## Kontrollerar zon, gångbar position, dialog-root och att alla dialogval pekar
## på noder som faktiskt finns (eller null = avsluta).

# id -> förväntad zon
const NEW_NPCS := {
	"npc_cave_miner": "cave",
	"npc_desert_nomad": "desert",
	"npc_mine_dwarf": "dwarf_mine",
	"npc_ice_hunter": "ice",
	"npc_tomb_seeker": "solgraven",
	"npc_swamp_hermit": "swamp",
	"npc_depot_keeper": "thais_depot_lower",
	"npc_troll_captive": "troll_cave",
}

var _zone_cache: Dictionary = {}

func _zone_data(zone_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

func test_alla_nya_npcer_finns_i_ratt_zon():
	for id in NEW_NPCS:
		assert_true(DialogueDB.npcs.has(id), "%s saknas i npcs.json" % id)
		assert_eq(String(DialogueDB.npcs[id]["zone"]), String(NEW_NPCS[id]),
			"%s ligger i fel zon" % id)

func test_dialog_root_ar_korrekt_lankad():
	for id in NEW_NPCS:
		var root := String(DialogueDB.npcs[id].get("dialogue_root", ""))
		assert_eq(root, id + "_root", "%s ska ha dialog-root %s_root" % [id, id])
		assert_true(DialogueDB.nodes.has(root), "dialognoden %s saknas" % root)

func test_alla_npcer_har_barks():
	for id in NEW_NPCS:
		var barks: Array = DialogueDB.npcs[id].get("barks", [])
		assert_gt(barks.size(), 0, "%s saknar barks" % id)

func test_positioner_ar_gangbara():
	for id in NEW_NPCS:
		var nd: Dictionary = DialogueDB.npcs[id]
		var pos: Array = nd["position"]
		var zone_id := String(nd["zone"])
		var z = preload("res://world/zone.gd").new()
		z.build_from_data(_zone_data(zone_id), zone_id)
		assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
			"%s står på en ogångbar ruta %s i %s" % [id, str(pos), zone_id])
		z.free()

func test_alla_dialognoder_har_giltiga_lankar():
	# Varje "next" i varje ny NPC:s dialogträd ska peka på en nod som finns,
	# eller vara null (avsluta samtalet). Inga brutna länkar.
	for id in NEW_NPCS:
		_assert_node_links_valid(id + "_root", id)

func _assert_node_links_valid(node_id: String, owner: String) -> void:
	assert_true(DialogueDB.nodes.has(node_id), "%s: nod %s saknas" % [owner, node_id])
	var node: Dictionary = DialogueDB.nodes.get(node_id, {})
	assert_eq(String(node.get("speaker", "")), owner,
		"%s: nod %s har fel speaker" % [owner, node_id])
	for c in node.get("choices", []):
		var nxt = c.get("next", null)
		if nxt != null:
			assert_true(DialogueDB.nodes.has(String(nxt)),
				"%s: val '%s' pekar på saknad nod %s" % [owner, c.get("text", "?"), str(nxt)])
