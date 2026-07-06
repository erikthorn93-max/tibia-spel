class_name GatherSim
extends RefCounted
## Renderer-agnostisk gathering-kärna (samma mönster som MonsterSim/PlayerSim):
## typdata ur ItemDB.nodes, verktygs-/nivåkrav, chansrull med väderbonus,
## skörd/xp/laddningar och uttömning. Vyerna (gather_node.gd i 2D,
## gather_node3d.gd i 3D) prenumererar på signalerna och ritar feedback.
## Respawn-timern ägs av vyn (RefCounted har inget scenträd): vyn väntar
## `depleted_now`-sekunderna och anropar `respawn()`.

## Hur mycket oväder höjer fångstchansen för fiske ("djupet rörs upp").
const STORM_FISHING_BONUS := 0.15

signal swung(success: bool)                # varje faktiskt försök (ok/miss)
signal harvested(item_id: String, amount: int, storm: bool)
signal xp_only(xp: int)                    # no_yield-nod: bara erfarenhet
signal depleted_now(respawn_seconds: float)
signal respawned

var node_type := ""
var def: Dictionary = {}
var tile := Vector2i.ZERO
var charges := 0
var depleted := false
var _storm_catch := false   # skedde senaste försök med oväders-bonus?

static func success_chance(level: int, req_level: int) -> float:
	return clampf(0.40 + 0.02 * float(level - req_level), 0.05, 0.90)

## Väderbonus till fångstchansen. Oväder rör upp djupet → fisket nappar bättre.
## Ren funktion (testbar): bara fiske under storm påverkas, annars 0.
static func weather_bonus(skill: String, weather: String) -> float:
	if skill == "fishing" and weather == Weather.STORM:
		return STORM_FISHING_BONUS
	return 0.0

## False om nodtypen saknas i data/nodes.json — vyn avgör vad som händer då.
func setup(type: String, t: Vector2i) -> bool:
	node_type = type
	def = ItemDB.nodes.get(type, {})
	if def.is_empty():
		return false
	tile = t
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
	return true

## Ett gather-försök. Vädret skickas in av vyn (2D läser zon-noden, 3D
## zonmodellen) så kärnan förblir ren. Statusar: depleted/no_tool/low_level/
## ok/miss — samma kontrakt som gamla GatherNode.attempt().
func attempt(weather := Weather.CLEAR) -> String:
	if depleted:
		return "depleted"
	var tool_id := String(def.get("tool", ""))
	if tool_id != "" and not GameState.has_tool(tool_id):
		return "no_tool"
	var skill := String(def["skill"])
	var lvl := GameState.effective_skill_level(skill)
	if lvl < int(def["level"]):
		return "low_level"
	var bonus := weather_bonus(skill, weather)
	_storm_catch = bonus > 0.0
	var chance := clampf(success_chance(lvl, int(def["level"])) + bonus, 0.05, 0.95)
	var success := randf() <= chance
	swung.emit(success)
	if success:
		apply_success()
		return "ok"
	return "miss"

## Bokför ett lyckat försök: verktygsförbrukning, skörd/xp, laddning,
## uttömning. Publik så tester kan tvinga fram utfallet deterministiskt.
func apply_success() -> void:
	# Konsumera verktyget om noden kräver det (t.ex. campfire_spot bränner loggar)
	if bool(def.get("consumes_tool", false)):
		var tool_id := String(def.get("tool", ""))
		if tool_id != "":
			GameState.remove_item(tool_id, 1)
	# no_yield: rena XP-noder (t.ex. agility-hinder ger bara erfarenhet).
	if not bool(def.get("no_yield", false)):
		var amt := 1
		if def.has("yield_min"):
			amt = randi_range(int(def["yield_min"]), int(def["yield_max"]))
		GameState.add_item(String(def["yields"]), amt)
		harvested.emit(String(def["yields"]), amt, _storm_catch)
	else:
		xp_only.emit(int(def["xp"]))
	GameState.gain_skill_xp(String(def["skill"]), int(def["xp"]))
	charges -= 1
	if charges <= 0:
		depleted = true
		depleted_now.emit(float(def["respawn"]))

## Noden återhämtar sig (vyn anropar efter respawn-tiden).
func respawn() -> void:
	depleted = false
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
	respawned.emit()
