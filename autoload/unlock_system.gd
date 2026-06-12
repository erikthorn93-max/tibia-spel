extends Node
## Autoload: UnlockSystem. Minimalt unlock-set — M5 bygger vidare.

signal unlock_added(id: String)

var unlocked: Dictionary = {}   # id -> true (set-semantik)

func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	unlock_added.emit(id)

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)
