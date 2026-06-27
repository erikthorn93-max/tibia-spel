extends GutTest
## Regressionsvakt: varje monster i monsters.json måste ha en bestiarie-text
## (desc), annars står det tomt när spelaren upptäcker det i bestiarien.

func test_alla_monster_har_desc() -> void:
	var saknar: Array = []
	for mname in MonsterDB.monsters:
		var desc := String(MonsterDB.monsters[mname].get("desc", "")).strip_edges()
		if desc.is_empty():
			saknar.append(mname)
	assert_eq(saknar, [], "monster utan bestiarie-text: %s" % str(saknar))

func test_desc_har_rimlig_langd() -> void:
	# Fånga platshållare/stympade beskrivningar — riktig lore är minst en mening.
	var korta: Array = []
	for mname in MonsterDB.monsters:
		var desc := String(MonsterDB.monsters[mname].get("desc", "")).strip_edges()
		if desc.length() < 20:
			korta.append("%s (%d tecken)" % [mname, desc.length()])
	assert_eq(korta, [], "för korta beskrivningar: %s" % str(korta))

func test_bossar_har_desc() -> void:
	# Bossar förtjänar lore i synnerhet — de är questmål och höjdpunkter.
	var saknar: Array = []
	for mname in MonsterDB.monsters:
		if bool(MonsterDB.monsters[mname].get("boss", false)):
			if String(MonsterDB.monsters[mname].get("desc", "")).strip_edges().is_empty():
				saknar.append(mname)
	assert_eq(saknar, [], "bossar utan lore: %s" % str(saknar))
