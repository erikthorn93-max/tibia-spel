class_name PlayerSim
extends RefCounted
## Ren rörelsesimulering för spelaren: gridsteg med frame-budget (carry-over
## över tile-gränser), auto-walk via A*, facing, bump-unlock av gates och
## agility-progression. Attack/gathering/spells ligger kvar i vyn tills
## nästa migrationssteg.
##
## Ingen rendering, inga noder — headless-testbar och delbar mellan 2D-vyn
## (player.gd) och en framtida 3D-vy. Vyn läser move_progress för
## interpolation och prenumererar på signalerna.
##
## Beroenden: rena autoloads (GameState, QuestSystem, UnlockSystem).

signal moved(from: Vector2i, to: Vector2i)   # steg påbörjat (move_progress 0→1)
signal step_completed(t: Vector2i)           # landade på t — vyn portal-checkar
signal facing_changed(dir: Vector2i)         # vyn vänder karaktärsvisualen
signal message(text: String)                 # "Kan inte nå dit." / unlock-hints

var zone: ZoneModel = null            # speglas in av vyn vid zonladdning
var tile := Vector2i.ZERO
var facing := Vector2i.DOWN
var move_progress := 1.0              # 0..1; <1 = mitt i ett steg, 1 = stilla
var move_speed := 4.0                 # tiles/sek (höjs av agility-nivåer)
var auto_path: Array = []             # Vector2i-lista mot klick-/gather-mål

## Teleportera till en tile (zonladdning). Bokför position för quests.
func snap_to(t: Vector2i) -> void:
	tile = t
	move_progress = 1.0
	GameState.player_tile = t
	QuestSystem.record_position(GameState.current_zone, t)

## Frame-tick: förbrukar hela budgeten — avslutar pågående steg och fortsätter
## sömlöst in i nästa (carry-over) så det inte uppstår en stillastående frame
## vid varje tile-gräns. intent_dir != ZERO (manuell input) avbryter auto-walk.
func advance(delta: float, intent_dir := Vector2i.ZERO) -> void:
	if zone == null:
		return
	if GameState.has_status("stun"):
		return   # stun-status: spelaren kan inte röra sig
	var effective_speed := move_speed * (0.5 if GameState.has_status("slow") else 1.0)
	var budget := delta
	while budget > 0.0:
		if move_progress < 1.0:
			var need := (1.0 - move_progress) / effective_speed   # tid kvar för steget
			if budget < need:
				move_progress += budget * effective_speed
				return
			# Steget hinner bli klart denna frame — förbruka exakt så mycket tid.
			budget -= need
			move_progress = 1.0
			var z := zone
			GameState.player_tile = tile
			QuestSystem.record_position(GameState.current_zone, tile)
			step_completed.emit(tile)
			if zone != z:
				return   # zonbyte skedde — ny zon/position hanterar resten
		elif not _begin_next_step(intent_dir):
			return        # ingen input/auto-path — stå stilla

## Väljer nästa rörelseriktning (manuell input > auto-walk). Returnerar true
## om ett steg faktiskt startades.
func _begin_next_step(intent_dir: Vector2i) -> bool:
	if intent_dir != Vector2i.ZERO:
		auto_path = []           # manuell rörelse avbryter auto-walk
		return step(intent_dir)
	if auto_path.size() > 1:     # auto-walk mot klick-/gather-mål
		var next: Vector2i = auto_path[1]
		auto_path.remove_at(0)
		var d := next - tile
		if d != Vector2i.ZERO and zone.is_walkable(next):
			return step(d)
	return false

## Påbörjar ett steg i en riktning. Blockerad tile provar bump-unlock istället.
func step(dir: Vector2i) -> bool:
	set_facing(dir)
	var next := tile + dir
	if not zone.is_walkable(next):
		try_bump_unlock(next)
		return false
	var from := tile
	tile = next
	move_progress = 0.0
	GameState.gain_skill_xp("agility", 1)   # gång tränar agility
	# Agility-bonus: rörelsehastighetsmultiplikator baserad på agility-nivå
	var ag := GameState.effective_skill_level("agility")
	if ag >= 60:
		move_speed = 5.2
	elif ag >= 40:
		move_speed = 4.8
	elif ag >= 20:
		move_speed = 4.4
	else:
		move_speed = 4.0
	moved.emit(from, next)
	return true

func set_facing(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	facing = dir
	facing_changed.emit(dir)

## Klick-för-att-gå: pathfinda till en ruta och auto-walka dit. Returnerar
## false om rutan är onåbar (meddelande/unlock-hint har då redan skickats).
func walk_to(t: Vector2i) -> bool:
	auto_path = []
	if t == tile:
		return true
	if not zone.is_walkable(t):
		# Låst gate/genväg intill? ge hint istället för tyst avbrott.
		if zone.lock_at(t) != "":
			try_bump_unlock(t)
		else:
			message.emit("Kan inte nå dit.")
		return false
	var path: Array = zone.find_path(tile, t)
	if path.is_empty():
		message.emit("Kan inte nå dit.")
		return false
	auto_path = path
	return true

## Auto-walk till en granntile av t (gather-mål). Returnerar false om onåbar.
## Redan intill (Chebyshev ≤ 1) räknas som nåbar utan path.
func walk_adjacent_to(t: Vector2i) -> bool:
	auto_path = zone.find_path_adjacent(tile, t)
	if auto_path.is_empty() and chebyshev(t) > 1:
		message.emit("Kan inte nå dit.")
		return false
	return true

## Gå mot låst gate/genväg: lås upp om kraven är uppfyllda, annars visa hint.
func try_bump_unlock(t: Vector2i) -> void:
	var uid: String = zone.lock_at(t)
	if uid == "":
		return
	if not UnlockSystem.try_unlock(uid):
		message.emit(UnlockSystem.hint_for(uid))

func chebyshev(t: Vector2i) -> int:
	return maxi(absi(t.x - tile.x), absi(t.y - tile.y))
