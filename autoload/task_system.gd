extends Node
## Autoload: TaskSystem. Äger tasks, bestiary, Slayer-XP-utdelning och boss-cooldown.
## Slayer-XP delas ENDAST ut via claim_reward och boss-kill.

signal task_taken(id: String)
signal task_progress(id: String)
signal task_completed(id: String)
signal bestiary_changed

const TIER_THRESHOLDS := [100, 400, 1000]
## Charm-poäng som delas ut när ett monster når motsvarande tier-tröskel.
const CHARM_POINTS_PER_TIER := [5, 10, 15]
const TIER_DAMAGE_BONUS := 0.02
const BOSS_COOLDOWN := 3600.0
const BOSS_SLAYER_XP := 2000

var tasks: Dictionary = {}            # task_id -> def (data/tasks.json)
var active: Dictionary = {}           # task_id -> progress (int)
var completed: Dictionary = {}        # task_id -> true (claimad minst en gång)
var bestiary: Dictionary = {}         # monster_name -> kills
var boss_kill_times: Dictionary = {}  # monster_name -> unix-timestamp

func _init() -> void:
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	tasks = parsed if parsed is Dictionary else {}

func _slayer_level() -> int:
	return int(GameState.skills.get("slayer", {"level": 1})["level"])

func slots() -> int:
	var lvl := _slayer_level()
	var s := 1
	if lvl >= 15:
		s += 1
	if lvl >= 30:
		s += 1
	return s

func take_task(id: String) -> bool:
	if not tasks.has(id) or active.has(id):
		return false
	if _slayer_level() < int(tasks[id].get("slayer_level_req", 1)):
		return false
	if active.size() >= slots():
		return false
	active[id] = 0
	task_taken.emit(id)
	return true

func abandon_task(id: String) -> void:
	if active.erase(id):
		task_progress.emit(id)

func record_kill(monster_name: String) -> void:
	var new_kills := int(bestiary.get(monster_name, 0)) + 1
	bestiary[monster_name] = new_kills
	# Charm-poäng delas ut exakt när en tier-tröskel passeras.
	var ti := TIER_THRESHOLDS.find(new_kills)
	if ti != -1:
		CharmSystem.award_points(CHARM_POINTS_PER_TIER[ti])
	bestiary_changed.emit()
	if bool(MonsterDB.monsters.get(monster_name, {}).get("boss", false)):
		boss_kill_times[monster_name] = Time.get_unix_time_from_system()
		GameState.gain_skill_xp("slayer", BOSS_SLAYER_XP)
	for id in active:
		var def: Dictionary = tasks[id]
		if String(def["monster"]) == monster_name and int(active[id]) < int(def["required"]):
			active[id] = int(active[id]) + 1
			task_progress.emit(id)
			if int(active[id]) >= int(def["required"]):
				task_completed.emit(id)

func is_task_done(id: String) -> bool:
	return active.has(id) and int(active[id]) >= int(tasks[id]["required"])

func claim_reward(id: String) -> bool:
	if not is_task_done(id):
		return false
	var def: Dictionary = tasks[id]
	var repeat := completed.has(id)
	var mult: float = 0.5 if repeat else 1.0
	GameState.gain_skill_xp("slayer", int(int(def["reward_slayer_xp"]) * mult))
	GameState.add_item("iron_coin", int(int(def["reward_gold"]) * mult))
	active.erase(id)
	completed[id] = true
	if not repeat and def.has("unlocks"):
		UnlockSystem.unlock(String(def["unlocks"]))
	# M3: bossvillkoret hårdkodat (generaliseras i M7+)
	if completed.has("task_ghoul") and completed.has("task_fantom"):
		UnlockSystem.unlock("bossrummet")
	task_progress.emit(id)
	return true

func tier(monster_name: String) -> int:
	var kills := int(bestiary.get(monster_name, 0))
	var t := 0
	for th in TIER_THRESHOLDS:
		if kills >= int(th):
			t += 1
	return t

func damage_multiplier(monster_name: String) -> float:
	return 1.0 + TIER_DAMAGE_BONUS * tier(monster_name)

func boss_available(monster_name: String) -> bool:
	return boss_cooldown_left(monster_name) <= 0.0

func boss_cooldown_left(monster_name: String) -> float:
	if not boss_kill_times.has(monster_name):
		return 0.0
	return maxf(0.0, BOSS_COOLDOWN - (Time.get_unix_time_from_system() - float(boss_kill_times[monster_name])))

func reset() -> void:
	active.clear()
	completed.clear()
	bestiary.clear()
	boss_kill_times.clear()
