extends Node
## Autoload: QuestSystem. Äger queststate: start, stegprogression, belöningar.
## talk_to avanceras ENDAST via advance_talk (dialog-action); övriga stegtyper automatiskt.

signal quest_started(id: String)
signal quest_progress(id: String)
signal step_advanced(id: String)
signal quest_completed(id: String)

var quests: Dictionary = {}     # quest_id -> def (data/quests.json)
var active: Dictionary = {}     # quest_id -> {"step": int, "progress": int}
var completed: Dictionary = {}  # quest_id -> true

func _init() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	quests = parsed if parsed is Dictionary else {}

func _ready() -> void:
	GameState.inventory_changed.connect(_check_collect)

func can_start(id: String) -> bool:
	if not quests.has(id) or active.has(id) or completed.has(id):
		return false
	for req in quests[id].get("requires", []):
		if not completed.has(String(req)):
			return false
	return true

## Quest-markörstatus för en NPC-givare (OSRS-stil):
##  "start"  = har en startbar quest här (gul !)
##  "active" = har en pågående quest att återvända till (grå ?)
##  ""       = ingen markör (inget att göra / allt slutfört)
func giver_marker(npc_id: String) -> String:
	var has_active := false
	for id in quests:
		if String(quests[id].get("giver", "")) != npc_id:
			continue
		if can_start(id):
			return "start"
		if active.has(id):
			has_active = true
	return "active" if has_active else ""

func start(id: String) -> bool:
	if not can_start(id):
		return false
	active[id] = {"step": 0, "progress": 0}
	quest_started.emit(id)
	_check_collect()   # collect-steg kan redan vara uppfyllt
	return true

func current_step(id: String) -> Dictionary:
	if not active.has(id):
		return {}
	return quests[id]["steps"][int(active[id]["step"])]

func hint(id: String) -> String:
	return String(current_step(id).get("hint", ""))

func record_kill(monster_name: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "kill" and String(s["monster"]) == monster_name:
			active[id]["progress"] = int(active[id]["progress"]) + 1
			if int(active[id]["progress"]) >= int(s["count"]):
				_advance(id)
			else:
				quest_progress.emit(id)

func record_explore(zone_id: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "explore" and String(s["zone"]) == zone_id and not s.has("tile"):
			_advance(id)

func record_position(zone_id: String, t: Vector2i) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "explore" and String(s["zone"]) == zone_id and s.has("tile"):
			var target := Vector2i(int(s["tile"][0]), int(s["tile"][1]))
			if maxi(absi(t.x - target.x), absi(t.y - target.y)) <= int(s.get("radius", 0)):
				_advance(id)

func record_use(item_id: String) -> void:
	for id in active.keys():
		var s := current_step(id)
		if s.get("type") == "use_item" and String(s["item"]) == item_id:
			_advance(id)

func advance_talk(id: String, npc_id: String) -> bool:
	var s := current_step(id)
	if s.get("type") == "talk_to" and String(s["npc"]) == npc_id:
		_advance(id)
		return true
	return false

func _check_collect() -> void:
	for id in active.keys():
		if not active.has(id):   # kan ha avancerat/slutförts under loopen
			continue
		var s := current_step(id)
		if s.get("type") != "collect":
			continue
		var have := mini(int(GameState.inventory.get(String(s["item"]), 0)), int(s["count"]))
		if have >= int(s["count"]):
			_advance(id)
		elif have != int(active[id]["progress"]):
			active[id]["progress"] = have
			quest_progress.emit(id)

func _advance(id: String) -> void:
	var steps: Array = quests[id]["steps"]
	var next := int(active[id]["step"]) + 1
	if next >= steps.size():
		_complete(id)
		return
	active[id] = {"step": next, "progress": 0}
	step_advanced.emit(id)
	_check_collect()   # nästa steg kan redan vara uppfyllt

func _complete(id: String) -> void:
	var r: Dictionary = quests[id].get("rewards", {})
	GameState.gain_exp(int(r.get("xp", 0)))
	if r.has("gold"):
		GameState.add_item("iron_coin", int(r["gold"]))
	for item_id in r.get("items", {}):
		GameState.add_item(String(item_id), int(r["items"][item_id]))
	# Skill-XP-belöning: driver upp skillnivåer direkt.
	for sk in r.get("skill_xp", {}):
		GameState.gain_skill_xp(String(sk), int(r["skill_xp"][sk]))
	# Unlock-belöning: låser upp content (områden/outfits) vid slutförande.
	for uid in r.get("unlocks", []):
		UnlockSystem.unlock(String(uid))
	active.erase(id)
	completed[id] = true
	quest_completed.emit(id)

func reset() -> void:
	active.clear()
	completed.clear()
