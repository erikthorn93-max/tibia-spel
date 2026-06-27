extends GutTest
## Guildhusens questkedjor: de tidigare questlösa guildmästarna Gregor, Elane,
## Galuna och Muriel ger nu riktiga prov med outfit-belöning. Tematiska men
## ÖPPNA för alla — inga klasslås. Vakt mot regression till "tom lärar-NPC".

func _json(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null

var quests: Dictionary
var dlg: Dictionary
var outfits: Dictionary
var unlocks: Dictionary

func before_all():
	quests = _json("res://data/quests.json")
	dlg = _json("res://data/dialogue.json")
	outfits = _json("res://data/outfits.json")
	unlocks = _json("res://data/unlocks.json")

const GUILD := {
	"quest_guild_knight":   "npc_knight_guild_master",
	"quest_guild_marksman": "npc_elane",
	"quest_guild_paladin":  "npc_galuna",
	"quest_guild_sorcerer": "npc_muriel",
}

func test_alla_guildquests_finns_med_ratt_givare():
	for qid in GUILD:
		assert_true(quests.has(qid), "guildquest saknas: %s" % qid)
		assert_eq(String(quests[qid]["giver"]), GUILD[qid], "%s: fel givare" % qid)

func test_varje_kedja_slutar_med_talk_to_givaren():
	# Sista steget måste vara talk_to givaren — det är så advance_quest i
	# dialogen kan slutföra questen och dela ut belöningen.
	for qid in GUILD:
		var steps: Array = quests[qid]["steps"]
		var last: Dictionary = steps[steps.size() - 1]
		assert_eq(String(last["type"]), "talk_to", "%s: sista steg ej talk_to" % qid)
		assert_eq(String(last["npc"]), GUILD[qid], "%s: rapporterar till fel npc" % qid)

func test_paladinkedjan_kraver_bagskyttet_forst():
	# Galunas övre hall är gated bakom Elanes prov ("earn your way up there").
	assert_eq(quests["quest_guild_paladin"]["requires"], ["quest_guild_marksman"],
		"paladinkedjan saknar krav på marksman-questen")

func test_guildmastarna_erbjuder_och_avslutar_i_dialog():
	# Varje guildmästares root måste både ERBJUDA (quest_available) och kunna
	# AVSLUTA (advance_quest på sista steget) sin quest.
	var root_of := {
		"quest_guild_knight": "gregor_root",
		"quest_guild_marksman": "elane_root",
		"quest_guild_paladin": "galuna_root",
		"quest_guild_sorcerer": "muriel_root",
	}
	for qid in root_of:
		var root: Dictionary = dlg[root_of[qid]]
		var offers := false
		var completes := false
		for c in root.get("choices", []):
			for cond in c.get("conditions", []):
				if String(cond.get("type", "")) == "quest_available" and String(cond.get("quest", "")) == qid:
					offers = true
			for a in c.get("actions", []):
				if String(a.get("type", "")) == "advance_quest" and String(a.get("quest", "")) == qid:
					completes = true
		assert_true(offers, "%s erbjuds inte i %s" % [qid, root_of[qid]])
		assert_true(completes, "%s avslutas inte i %s" % [qid, root_of[qid]])

func test_guildquests_startas_via_dialog():
	var started := {}
	for nid in dlg:
		for c in dlg[nid].get("choices", []):
			for a in c.get("actions", []):
				if String(a.get("type", "")) == "start_quest":
					started[String(a["quest"])] = true
	for qid in GUILD:
		assert_true(started.has(qid), "%s startas aldrig i någon dialog" % qid)

func test_tre_guildoutfits_belonas_av_kedjorna():
	var by_quest := {
		"quest_guild_knight": "outfit_knight",
		"quest_guild_paladin": "outfit_paladin",
		"quest_guild_sorcerer": "outfit_sorcerer",
	}
	for qid in by_quest:
		var oid: String = by_quest[qid]
		assert_true(outfits.has(oid), "outfit saknas: %s" % oid)
		assert_true(unlocks.has(oid), "unlock-def saknas: %s" % oid)
		var rew_unlocks: Array = quests[qid].get("rewards", {}).get("unlocks", [])
		assert_true(rew_unlocks.has(oid), "%s delar inte ut %s" % [qid, oid])
		# Tom requires => beviljas direkt av questen (ingen self-unlock-konflikt).
		assert_true((unlocks[oid].get("requires", {}) as Dictionary).is_empty(),
			"%s borde ha tom requires (extern gåva)" % oid)

func test_marksman_ger_bagutrustning_men_ingen_outfit():
	# Elanes prov är ett mellansteg — utrustning, inte capstone-outfit.
	var rew: Dictionary = quests["quest_guild_marksman"]["rewards"]
	assert_true((rew.get("items", {}) as Dictionary).has("oak_bow"), "marksman saknar bågbelöning")
	assert_false(rew.has("unlocks"), "marksman ska inte dela ut outfit (det gör Galuna)")
