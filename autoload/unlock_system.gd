extends Node
## Autoload: UnlockSystem. Unlock-set + kravdrivna unlocks från data/unlocks.json.
## Tomma krav = unlocken ges av extern källa (t.ex. task-claim) och kan inte själv-upplåsas.

signal unlock_added(id: String)

var defs: Dictionary = {}       # id -> def (data/unlocks.json)
var unlocked: Dictionary = {}   # id -> true (set-semantik)

func _init() -> void:
	var f := FileAccess.open("res://data/unlocks.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	defs = parsed if parsed is Dictionary else {}

func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	unlock_added.emit(id)

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func can_unlock(id: String) -> bool:
	var r: Dictionary = defs.get(id, {}).get("requires", {})
	if r.is_empty():
		return false
	if r.has("skill") and GameState.effective_skill_level(String(r["skill"])) < int(r.get("level", 1)):
		return false
	if r.has("quest") and not QuestSystem.completed.has(String(r["quest"])):
		return false
	if r.has("all_quests") and bool(r["all_quests"]) and not QuestSystem.all_completed():
		return false
	if r.has("task_completed") and not TaskSystem.completed.has(String(r["task_completed"])):
		return false
	if r.has("boss_killed") and not TaskSystem.boss_kill_times.has(String(r["boss_killed"])):
		return false
	if r.has("unlock") and not is_unlocked(String(r["unlock"])):
		return false
	return true

func try_unlock(id: String) -> bool:
	if is_unlocked(id):
		return true
	if not can_unlock(id):
		return false
	unlock(id)
	return true

## Försöker låsa upp alla krav-drivna unlocks vars villkor nu är uppfyllda.
## Anropas t.ex. när en quest slutförs så belöningar syns direkt.
func try_unlock_all() -> void:
	for id in defs:
		try_unlock(String(id))

func display_name(id: String) -> String:
	return String(defs.get(id, {}).get("name", id))

func hint_for(id: String) -> String:
	return String(defs.get(id, {}).get("hint", ""))
