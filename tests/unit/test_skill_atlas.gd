extends GutTest
## Tester för skill-träningsguiden: SkillAtlas-datan + skillpanelens popup.

const SkillPanel = preload("res://ui/skill_panel.gd")

# ── SkillAtlas: datakällor per skill ──

func test_fishing_entries_sorted_with_zones():
	var e := SkillAtlas.entries_for("fishing")
	assert_gt(e.size(), 0, "fishing saknar träningsplatser")
	# sorterad stigande på nivå
	for i in range(1, e.size()):
		assert_true(int(e[i]["level"]) >= int(e[i-1]["level"]), "ej sorterad på nivå")
	# lägsta är Fiskestim nivå 1 i Gamla skogen
	assert_eq(int(e[0]["level"]), 1, "fishing börjar inte på nivå 1")
	assert_true(Array(e[0]["zones"]).has("Gamla skogen"),
		"fiske nivå 1 ska finnas i Gamla skogen, fick %s" % str(e[0]["zones"]))

func test_new_isle_nodes_appear_in_atlas():
	var e := SkillAtlas.entries_for("fishing")
	var labels := []
	for x in e:
		labels.append(String(x["label"]))
	assert_true(labels.has("Tonfiskstim"), "Tonfisk saknas i atlasen")
	# Stormrevet ska listas som zon för tonfisk
	for x in e:
		if String(x["label"]) == "Tonfiskstim":
			assert_true(Array(x["zones"]).has("Stormrevet"), "tonfisk ska finnas på Stormrevet")

func test_crafting_skill_maps_to_station():
	var cook := SkillAtlas.entries_for("cooking")
	var has_stove := false
	for x in cook:
		if String(x["kind"]) == "station" and String(x["label"]) == "Gryta":
			has_stove = true
			assert_true(Array(x["zones"]).size() > 0, "Gryta saknar zon")
	assert_true(has_stove, "cooking mappar inte till Gryta-station")

	var smith := SkillAtlas.entries_for("smithing")
	var has_anvil := false
	for x in smith:
		if String(x["label"]) == "Städ":
			has_anvil = true
	assert_true(has_anvil, "smithing mappar inte till Städ")

func test_cooking_available_in_thais():
	# Frodo's Inn (Thais) ska ha en gryta så cooking går att börja i Thais
	var f := FileAccess.open("res://data/zones/frodo_inn.json", FileAccess.READ)
	var inn: Dictionary = JSON.parse_string(f.get_as_text())
	var has_stove := false
	for ch in inn.get("legend", {}):
		var e: Dictionary = inn["legend"][ch]
		if String(e.get("type", "")) == "station" and String(e.get("station", "")) == "stove":
			has_stove = true
	assert_true(has_stove, "Frodo's Inn saknar gryta")
	# och atlasen listar Frodo's Inn som en cooking-plats
	var zones := []
	for x in SkillAtlas.entries_for("cooking"):
		for z in x["zones"]:
			zones.append(String(z))
	assert_true(zones.has("Frodo's Inn"), "cooking-atlasen saknar Frodo's Inn, fick %s" % str(zones))

func test_combat_skill_has_hint_no_entries():
	assert_eq(SkillAtlas.entries_for("sword").size(), 0, "sword ska sakna nod/station-poster")
	assert_ne(SkillAtlas.hint_for("sword"), "", "sword saknar förklaringstext")
	# gathering-skill med noder ska INTE ha en hint
	assert_eq(SkillAtlas.hint_for("fishing"), "", "fishing ska inte ha hint (den har noder)")

# ── Skillpanelens guide-popup ──

func test_panel_guide_opens_for_fishing():
	var panel = SkillPanel.new()
	add_child_autofree(panel)
	panel.visible = true
	panel._show_guide("fishing")
	assert_true(panel._guide.visible, "guiden öppnades inte")
	assert_gt(panel._guide_body.get_child_count(), 0, "guiden har inga rader")
	# klick på samma skill igen stänger
	panel._show_guide("fishing")
	assert_false(panel._guide.visible, "guiden stängdes inte vid andra klicket")

func test_panel_guide_shows_hint_for_combat_skill():
	var panel = SkillPanel.new()
	add_child_autofree(panel)
	panel.visible = true
	panel._show_guide("sword")
	assert_true(panel._guide.visible, "guiden öppnades inte för sword")
	assert_eq(panel._guide_body.get_child_count(), 1, "combat-skill ska visa en förklaringsrad")
