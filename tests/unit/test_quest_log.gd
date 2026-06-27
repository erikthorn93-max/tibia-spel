extends GutTest
## Questloggen (J): OSRS-stil statusindelning, kravvisning och belöningstext.
## Använder den RIKTIGA QuestSystem-autoloaden — spara/återställ i before/after.

const QuestLog = preload("res://ui/quest_log.gd")

var _saved_active: Dictionary
var _saved_completed: Dictionary

func before_each():
	_saved_active = QuestSystem.active.duplicate(true)
	_saved_completed = QuestSystem.completed.duplicate(true)
	QuestSystem.active.clear()
	QuestSystem.completed.clear()

func after_each():
	QuestSystem.active = _saved_active
	QuestSystem.completed = _saved_completed

func _panel():
	var p = QuestLog.new()
	add_child_autofree(p)
	return p

# ── Statusindelning ────────────────────────────────────────────────────────

func test_klar_quest_far_status_done():
	QuestSystem.completed["quest_welcome"] = true
	assert_eq(_panel()._status("quest_welcome"), "done")

func test_pagaende_quest_far_status_active():
	QuestSystem.active["quest_guild_knight"] = {"step": 0, "progress": 3}
	assert_eq(_panel()._status("quest_guild_knight"), "active")

func test_kravlos_quest_ar_tillganglig():
	# quest_guild_knight har tom requires => kan startas direkt.
	assert_eq(_panel()._status("quest_guild_knight"), "avail")

func test_quest_med_ouppfyllt_krav_ar_last():
	# paladinkedjan kräver marksman-questen, som inte är klar => låst.
	assert_eq(_panel()._status("quest_guild_paladin"), "locked")

func test_quest_blir_tillganglig_nar_kravet_ar_klart():
	QuestSystem.completed["quest_guild_marksman"] = true
	assert_eq(_panel()._status("quest_guild_paladin"), "avail")

# ── Belöningstext ──────────────────────────────────────────────────────────

func test_reward_text_listar_xp_guld_item_och_outfit():
	var txt: String = _panel()._reward_text("quest_guild_knight")
	assert_string_contains(txt, "700 XP")
	assert_string_contains(txt, "450 guld")
	assert_string_contains(txt, "Stålharnesk")          # item-namn, ej id
	assert_string_contains(txt, "Riddarens rustning")   # outfit-displaynamn

func test_reward_text_visar_antal_for_stack():
	# Runans Mening ger energy_rune ×8.
	var txt: String = _panel()._reward_text("quest_guild_sorcerer")
	assert_string_contains(txt, "×8")

# ── Zon-displaynamn ────────────────────────────────────────────────────────

func test_zone_display_oversatter_id_till_namn():
	var p = _panel()
	# town.json har ett "name"-fält; helpern ska returnera det, inte id:t.
	assert_ne(p._zone_display("town"), "town", "zon-id översattes inte till displaynamn")
	assert_eq(p._zone_display(""), "", "tom zon ger tom sträng")

# ── Bygger för alla quests utan att krascha ────────────────────────────────

func test_rebuild_med_blandade_statusar_kraschar_inte():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.active["quest_guild_knight"] = {"step": 1, "progress": 0}
	var p = _panel()
	p._rebuild()
	# Loggen ska ha producerat noder (rubrik + grupper + rader).
	assert_gt(p._list.get_child_count(), 0, "questloggen byggde inga rader")

func test_expansion_toggle_lagger_till_detaljrader():
	var p = _panel()
	p._rebuild()
	var before: int = p._list.get_child_count()
	p._expanded["quest_guild_paladin"] = true   # låst quest => visar förkrav
	p._rebuild()
	assert_gt(p._list.get_child_count(), before, "utfällning gav inga extra detaljrader")
