extends Node
## Autoload: ArenaSystem. Vågbaserad gladiatorarena (Knight's Arena, Torben).
##
## Logiken (vågprogression, kill-räkning, belöning) är frikopplad från
## spawningen: start()/record_kill() driver tillståndet och avger signaler,
## medan World lyssnar på wave_started och spawnar de faktiska monstren.
## Därmed kan hela arenaflödet enhetstestas headless utan riktiga monster.
##
## Belöningen delas ut med samma fält/semantik som questbelöningar
## (xp/gold/items/skill_xp/unlocks/charm_points) — en källa till sanning.

signal wave_started(index: int, spawns: Array)
signal wave_progress(remaining: int)
signal wave_cleared(index: int)
signal arena_won()
signal arena_failed(at_wave: int)

const ARENA_ZONE := "knight_arena"
## Sätts vid första segern (persisteras via UnlockSystem). Styr att den unika
## belöningen bara delas ut en gång — omspel ger repeat_reward (xp/guld/charm).
const CHAMPION_UNLOCK := "arena_champion"

var waves: Array = []
var reward: Dictionary = {}
var repeat_reward: Dictionary = {}

var active := false
var current_wave := -1
var kills_remaining := 0

func _init() -> void:
	var f := FileAccess.open("res://data/arena.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	var data: Dictionary = parsed if parsed is Dictionary else {}
	waves = data.get("waves", [])
	reward = data.get("reward", {})
	repeat_reward = data.get("repeat_reward", {})

func wave_count() -> int:
	return waves.size()

func is_active() -> bool:
	return active

## Monster kvar att fälla i aktuell våg (0 när ingen våg pågår).
func remaining() -> int:
	return kills_remaining

## Startar en ny arenaomgång från första vågen. Returnerar false om en omgång
## redan pågår eller om inga vågor är definierade.
func start() -> bool:
	if active or waves.is_empty():
		return false
	active = true
	current_wave = -1
	_begin_wave(0)
	return true

func _begin_wave(i: int) -> void:
	current_wave = i
	var spawns: Array = waves[i].get("spawns", [])
	kills_remaining = 0
	for s in spawns:
		kills_remaining += int(s.get("count", 0))
	wave_started.emit(i, spawns)

## Anropas ur monster._die() medan en omgång pågår. Räknar ned vågen och
## startar nästa — eller avslutar arenan med belöning när sista vågen faller.
func record_kill(_monster_name: String) -> void:
	if not active:
		return
	kills_remaining -= 1
	if kills_remaining > 0:
		wave_progress.emit(kills_remaining)
		return
	kills_remaining = 0
	var cleared := current_wave
	wave_cleared.emit(cleared)
	if cleared + 1 < waves.size():
		_begin_wave(cleared + 1)
	else:
		_win()

func _win() -> void:
	active = false
	current_wave = -1
	kills_remaining = 0
	# Den unika klingan delas bara ut första gången; därefter belönar omspel
	# med xp/guld/charm. reward.unlocks sätter CHAMPION_UNLOCK vid första segern.
	var first_clear := not UnlockSystem.is_unlocked(CHAMPION_UNLOCK)
	_grant(reward if first_clear else repeat_reward)
	arena_won.emit()

## Avbryter pågående omgång (spelaren dör eller lämnar arenan). Ingen belöning.
func abort() -> void:
	if not active:
		return
	var w := current_wave
	active = false
	current_wave = -1
	kills_remaining = 0
	arena_failed.emit(w)

## Delar ut belöning — identiska fält och ordning som QuestSystem._complete().
func _grant(r: Dictionary) -> void:
	GameState.gain_exp(int(r.get("xp", 0)))
	if r.has("gold"):
		GameState.add_item("iron_coin", int(r["gold"]))
	for item_id in r.get("items", {}):
		GameState.add_item(String(item_id), int(r["items"][item_id]))
	for sk in r.get("skill_xp", {}):
		GameState.gain_skill_xp(String(sk), int(r["skill_xp"][sk]))
	for uid in r.get("unlocks", []):
		UnlockSystem.unlock(String(uid))
	if r.has("charm_points"):
		CharmSystem.award_points(int(r["charm_points"]))

func reset() -> void:
	active = false
	current_wave = -1
	kills_remaining = 0
