extends Node
## Autoload: DialogueDB. Laddar dialogue.json + npcs.json,
## utvärderar val-villkor och kör dialog-actions. UI:t renderar bara.

var npcs: Dictionary = {}
var nodes: Dictionary = {}

func _init() -> void:
	npcs = _load_json("res://data/npcs.json")
	nodes = _load_json("res://data/dialogue.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

func visible_choices(node_id: String) -> Array:
	var out: Array = []
	for c in nodes.get(node_id, {}).get("choices", []):
		if _conditions_met(c.get("conditions", [])):
			out.append(c)
	return out

func _conditions_met(conds: Array) -> bool:
	for c in conds:
		if not eval_condition(c):
			return false
	return true

func eval_condition(c: Dictionary) -> bool:
	var ok := false
	match String(c["type"]):
		"quest_available":
			ok = QuestSystem.can_start(String(c["quest"]))
		"quest_active":
			ok = QuestSystem.active.has(String(c["quest"]))
		"quest_step":
			ok = QuestSystem.active.has(String(c["quest"])) \
				and int(QuestSystem.active[String(c["quest"])]["step"]) == int(c["step"])
		"quest_completed":
			ok = QuestSystem.completed.has(String(c["quest"]))
		"has_item":
			ok = int(GameState.inventory.get(String(c["item"]), 0)) >= int(c.get("count", 1))
		"skill_level":
			ok = GameState.effective_skill_level(String(c["skill"])) >= int(c["level"])
		"unlock":
			ok = UnlockSystem.is_unlocked(String(c["id"]))
		"gold":
			ok = GameState.gold >= int(c["amount"])
	return not ok if bool(c.get("not", false)) else ok

func run_actions(actions: Array, npc_id: String) -> void:
	for a in actions:
		match String(a["type"]):
			"start_quest":
				QuestSystem.start(String(a["quest"]))
			"advance_quest":
				QuestSystem.advance_talk(String(a["quest"]), npc_id)
			"give_item":
				GameState.add_item(String(a["item"]), int(a.get("count", 1)))
			"take_item":
				GameState.remove_item(String(a["item"]), int(a.get("count", 1)))
			"steal":
				var who := String(npcs.get(npc_id, {}).get("name", "någon"))
				if GameState.effective_skill_level("thieving") < int(a.get("level", 1)):
					if World.hud: World.hud.show_message("Du är inte skicklig nog att bestjäla %s." % who)
				elif GameState.attempt_steal(a):
					if World.hud: World.hud.show_message("Du lyckas bestjäla %s!" % who)
				else:
					if World.hud: World.hud.show_message("%s ertappar dig!" % who)
			"rest":
				var cost := int(a.get("cost", 0))
				if GameState.rest_at_inn(cost, float(a.get("satiation", 0.0))):
					Sfx.rest()
					if World.hud: World.hud.show_message("Du vilar ut. HP och mana är fyllda.")
				else:
					if World.hud: World.hud.show_message("Du har inte råd med ett rum (%d guld)." % cost)
