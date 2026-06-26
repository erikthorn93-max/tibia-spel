extends GutTest
## Regressionsvakt: varje outfit i outfits.json måste vara ÅTKOMLIG — annars
## blir den en "föräldralös" kosmetisk belöning som spelaren aldrig kan låsa upp.
## Samma sorts lucka som onåbara items/bossar en gång var.
##
## En outfit räknas som åtkomlig om dess unlock-token kan beviljas via:
##   1. egen-upplåsning: unlocks.json-post med icke-tomma, uppfyllbara krav
##      (try_unlock driver den när villkoret nås), ELLER
##   2. extern gåva: en quest-rewards.unlocks-array, ELLER
##   3. extern gåva: ett task-defs .unlocks-fält.
## "standard" är basoutfiten och kräver ingen upplåsning.

func _json(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null

var outfits: Dictionary
var unlocks: Dictionary
var quests: Dictionary
var tasks: Dictionary

func before_all():
	outfits = _json("res://data/outfits.json")
	unlocks = _json("res://data/unlocks.json")
	quests = _json("res://data/quests.json")
	tasks = _json("res://data/tasks.json")

func test_data_laddad():
	assert_false(outfits.is_empty(), "outfits.json saknas/tom")
	assert_false(unlocks.is_empty(), "unlocks.json saknas/tom")

## Mängden unlock-id:n som NÅGON källa faktiskt kan bevilja.
func _grantable() -> Dictionary:
	var src := {}
	# 1. Egen-upplåsbara: icke-tomma krav => can_unlock kan bli sant.
	for uid in unlocks:
		var req: Dictionary = unlocks[uid].get("requires", {})
		if not req.is_empty():
			src[uid] = true
	# 2. Quest-belöningar som låser upp content.
	for qid in quests:
		for uid in quests[qid].get("rewards", {}).get("unlocks", []):
			src[String(uid)] = true
	# 3. Task-belöningar som låser upp content.
	for tid in tasks:
		if tasks[tid].has("unlocks"):
			src[String(tasks[tid]["unlocks"])] = true
	return src

func test_alla_outfits_atkomliga():
	var grantable := _grantable()
	var orphans := []
	for oid in outfits:
		if oid == "standard":
			continue
		var token := String(outfits[oid].get("unlock", ""))
		if token == "" or not grantable.has(token):
			orphans.append(oid)
	assert_eq(orphans, [], "outfits utan upplåsningskälla (onåbara): %s" % str(orphans))

func test_varje_outfit_har_unlock_def():
	# unlock-token måste peka på en faktisk post i unlocks.json,
	# annars vet equip-flödet (is_unlocked) aldrig om outfiten.
	var saknar := []
	for oid in outfits:
		if oid == "standard":
			continue
		var token := String(outfits[oid].get("unlock", ""))
		if token == "" or not unlocks.has(token):
			saknar.append(oid)
	assert_eq(saknar, [], "outfits vars unlock-token saknar def i unlocks.json: %s" % str(saknar))

func test_egenupplasbara_krav_pekar_pa_riktiga_mal():
	# Varje icke-tomt krav måste referera något som verkligen finns,
	# annars går villkoret aldrig att uppfylla.
	var trasiga := []
	for uid in unlocks:
		var req: Dictionary = unlocks[uid].get("requires", {})
		if req.has("quest") and not quests.has(String(req["quest"])):
			trasiga.append("%s: okänd quest %s" % [uid, req["quest"]])
		if req.has("task_completed") and not tasks.has(String(req["task_completed"])):
			trasiga.append("%s: okänd task %s" % [uid, req["task_completed"]])
		if req.has("boss_killed") and not MonsterDB.monsters.has(String(req["boss_killed"])):
			trasiga.append("%s: okänd boss %s" % [uid, req["boss_killed"]])
	assert_eq(trasiga, [], "unlock-krav mot okända mål: %s" % str(trasiga))

func test_outfit_unlocks_beviljas_inte_dubbelt():
	# En outfit ska INTE både ha egna krav OCH delas ut som quest/task-gåva.
	# Det vore tvetydigt: self-unlock + extern gåva samtidigt.
	var external := {}
	for qid in quests:
		for uid in quests[qid].get("rewards", {}).get("unlocks", []):
			external[String(uid)] = true
	for tid in tasks:
		if tasks[tid].has("unlocks"):
			external[String(tasks[tid]["unlocks"])] = true
	var konflikt := []
	for oid in outfits:
		if oid == "standard":
			continue
		var token := String(outfits[oid].get("unlock", ""))
		var req: Dictionary = unlocks.get(token, {}).get("requires", {})
		if not req.is_empty() and external.has(token):
			konflikt.append(oid)
	assert_eq(konflikt, [], "outfits med både egna krav och extern gåva: %s" % str(konflikt))
