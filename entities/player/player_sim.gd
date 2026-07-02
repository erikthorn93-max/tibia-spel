class_name PlayerSim
extends RefCounted
## Ren simulering för spelaren: gridsteg med frame-budget (carry-over över
## tile-gränser), auto-walk via A*, facing, bump-unlock, agility-progression
## samt auto-attack och kraftslag mot MonsterSim-mål. Gathering och spells
## ligger kvar i vyn tills nästa migrationssteg.
##
## Ingen rendering, inga noder — headless-testbar och delbar mellan 2D-vyn
## (player.gd) och en framtida 3D-vy. Vyn läser move_progress för
## interpolation och prenumererar på signalerna.
##
## Beroenden: rena autoloads (GameState, QuestSystem, UnlockSystem, ItemDB,
## CombatFormulas, CombatStance, CharmSystem, TaskSystem).

signal moved(from: Vector2i, to: Vector2i)   # steg påbörjat (move_progress 0→1)
signal step_completed(t: Vector2i)           # landade på t — vyn portal-checkar
signal facing_changed(dir: Vector2i)         # vyn vänder karaktärsvisualen
signal message(text: String)                 # "Kan inte nå dit." / unlock-hints
signal attack_swung(dir: Vector2i)           # sving utförd (träff eller miss)
signal healed(amount: float)                 # leech-charm läkte — vyn visar +N
signal spec_flash(t: Vector2i)               # kraftslags-nedslag på tile t
signal spec_denied()                         # kraftslag nekades — vyn spelar ljud
signal spec_released()                       # kraftslag utlöst — vyn spelar ljud

const ATTACK_COOLDOWN := 1.0

var zone: ZoneModel = null            # speglas in av vyn vid zonladdning
var tile := Vector2i.ZERO
var facing := Vector2i.DOWN
var move_progress := 1.0              # 0..1; <1 = mitt i ett steg, 1 = stilla
var move_speed := 4.0                 # tiles/sek (höjs av agility-nivåer)
var auto_path: Array = []             # Vector2i-lista mot klick-/gather-mål
var target: MonsterSim = null         # auto-attack-mål (null = inget)
var _attack_timer := 0.0

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

# ── Auto-attack ───────────────────────────────────────────────────────────────
## Frame-tick för auto-attack mot target. Närstrid eller bågskytte beroende på
## utrustat vapen; träffrull, crit, charm- och giftvapen-procs, skill-xp och
## spec-laddning. Vyn spelar svingen via attack_swung.
func attack_tick(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if target == null or target.dead or _attack_timer > 0.0:
		return
	var wskill := GameState.weapon_skill()
	var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
	var weapon_range := int(weapon.get("range", 1))
	var dist := chebyshev(target.tile)
	if dist > weapon_range:
		return   # utom räckvidd
	_attack_timer = ATTACK_COOLDOWN / (1.0 + GameState.total_speed_bonus())
	# Vänd dig mot målet inför slaget (gäller både närstrid och bågskytte)
	set_facing(Vector2i(signi(target.tile.x - tile.x), signi(target.tile.y - tile.y)))
	var dmg: float
	if weapon_range > 1:
		# Bågskjutning: kräver ammunition i inventory
		var ammo_id := String(weapon.get("ammo", ""))
		if ammo_id != "" and not GameState.has_ammo(ammo_id):
			message.emit("Inga pilar kvar!")
			return
		if ammo_id != "":
			GameState.consume_ammo(ammo_id)
		if not _rolls_hit(wskill):
			_attack_missed(wskill)
			return
		dmg = CombatFormulas.roll_ranged(
			GameState.effective_skill_level(wskill),
			int(weapon.get("atk", 5)) + GameState.total_atk_bonus()) \
			* TaskSystem.damage_multiplier(target.monster_name) \
			* CombatStance.damage_mult(GameState.combat_stance)
	else:
		# Närstrid
		if dist > 1:
			return
		if not _rolls_hit(wskill):
			_attack_missed(wskill)
			return
		dmg = CombatFormulas.roll_melee(GameState.level,
			GameState.effective_skill_level(wskill),
			int(weapon.get("atk", 5)) + GameState.total_atk_bonus()) \
			* TaskSystem.damage_multiplier(target.monster_name) \
			* CombatStance.damage_mult(GameState.combat_stance)   # bestiary-tier + ställning
	var crit := CombatFormulas.roll_crit(
		GameState.effective_skill_level(wskill), GameState.total_crit_bonus())
	if crit:
		dmg *= CombatFormulas.CRIT_MULTIPLIER
	target.take_damage(dmg, crit)
	_apply_offense_charm(target)
	_apply_weapon_ability(target)
	GameState.gain_skill_xp(wskill, 1)
	GameState.add_spec(CombatFormulas.SPEC_GAIN)   # ladda kraftslaget
	attack_swung.emit(facing)

## Slår om det aktuella slaget träffar målet (spelarens accuracy mot monstrets
## undvikande). Garanterar inget — högt golv håller tidig spelning förlåtande.
func _rolls_hit(wskill: String) -> bool:
	var acc := CombatFormulas.accuracy(GameState.level, GameState.effective_skill_level(wskill))
	var eva := CombatFormulas.monster_evasion(float(target.speed))
	return CombatFormulas.roll_hit(acc, eva)

## Ett bommat slag: svingen syns, "miss" visas och skickligheten tränas ändå
## (förlåtande), men ingen skada, charm-effekt eller spec-laddning sker.
func _attack_missed(wskill: String) -> void:
	attack_swung.emit(facing)
	target.note("miss")
	GameState.gain_skill_xp(wskill, 1)

## Slår vapnets giftbeläggning mot målet vid en landad träff. Giftvapen
## (venom_blade m.fl.) bär ability {type:poison, ...}; proccar den får monstret
## en gift-DoT — spegelbilden av hur monstergift drabbar spelaren.
func _apply_weapon_ability(m: MonsterSim) -> void:
	if m == null or m.dead:
		return
	var ability: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {}).get("ability", {})
	var proc := CombatFormulas.weapon_poison_proc(ability, randf())
	if not proc.get("apply", false):
		return
	m.apply_status("poison", float(proc["duration"]), float(proc["tick_dmg"]))
	m.note("poisoned")

## Slår den bärna offensiva charmen mot målet och lägger på elementär bonusskada.
func _apply_offense_charm(m: MonsterSim) -> void:
	if m == null or m.dead:
		return
	var r := CharmSystem.roll_offense(float(m.max_hp))
	if r.get("triggered", false):
		var dealt: int = m.take_charm_damage(float(r["amount"]), String(r["element"]))
		var ls := CharmSystem.lifesteal(String(r["id"]))
		if ls > 0.0 and dealt > 0 and GameState.health < GameState.max_health:
			var amount := float(dealt) * ls
			GameState.heal(amount)
			healed.emit(amount)

# ── Kraftslag (specialattack) ─────────────────────────────────────────────────
## Släpper kraftslaget mot nuvarande mål om mätaren är full. Ett hårt,
## garanterat kritiskt slag som tömmer mätaren. nearby = MonsterSims inom
## 1 tile från målet (inkl. målet) — används av cleave; vyn samlar in listan.
func try_special(nearby: Array = []) -> void:
	if target == null or target.dead:
		message.emit("Inget mål för kraftslag.")
		return
	var weapon: Dictionary = ItemDB.items.get(GameState.equipped_weapon, {})
	var weapon_range := int(weapon.get("range", 1))
	if chebyshev(target.tile) > weapon_range:
		message.emit("Målet är utom räckhåll.")
		return
	if not CombatFormulas.spec_ready(GameState.spec_energy):
		message.emit("Kraftslaget är inte laddat.")
		spec_denied.emit()
		return
	var wskill := GameState.weapon_skill()
	var atk_total := int(weapon.get("atk", 5)) + GameState.total_atk_bonus()
	var ammo_id := String(weapon.get("ammo", ""))
	var base: float
	if weapon_range > 1:
		if ammo_id != "" and not GameState.has_ammo(ammo_id):
			message.emit("Inga pilar kvar!")
			return
		base = CombatFormulas.max_ranged(GameState.effective_skill_level(wskill), atk_total)
	else:
		base = CombatFormulas.max_melee(GameState.level,
			GameState.effective_skill_level(wskill), atk_total)
	# Allt klart — töm mätaren och slå utifrån vapentypens kraftslag.
	GameState.consume_spec()
	if weapon_range > 1 and ammo_id != "":
		GameState.consume_ammo(ammo_id)
	set_facing(Vector2i(signi(target.tile.x - tile.x), signi(target.tile.y - tile.y)))
	attack_swung.emit(facing)
	var prof := CombatFormulas.spec_profile(wskill)
	var stance_mult := CombatStance.damage_mult(GameState.combat_stance)
	var mult := float(prof["mult"])
	var msg := "Kraftslag!"
	match String(prof["kind"]):
		"cleave":
			msg = "Klyv!"
			# Målet + alla levande fiender intill målet får var sin träff.
			for m in nearby:
				_spec_hit(m, base, mult, stance_mult)
		"crush":
			msg = "Krossa!"
			_spec_hit(target, base, mult, stance_mult)
			if not target.dead:
				target.apply_status("stun", float(prof["stun"]), 0.0)
				target.note("stunned")
		"double":
			msg = "Dubbelskott!"
			_spec_hit(target, base, mult, stance_mult)
			if not target.dead:
				_spec_hit(target, base, mult, stance_mult)
		_:  # power
			_spec_hit(target, base, mult, stance_mult)
	_apply_offense_charm(target)
	_apply_weapon_ability(target)
	GameState.gain_skill_xp(wskill, 2)
	spec_released.emit()
	message.emit(msg)

## En enskild kraftslags-träff på ett mål: skada (garanterad crit) plus en
## guldblixt vid nedslaget (via spec_flash → vyn).
func _spec_hit(m: MonsterSim, base: float, mult: float, stance_mult: float) -> void:
	if m == null or m.dead:
		return
	var dmg := CombatFormulas.spec_damage(base, mult) \
		* TaskSystem.damage_multiplier(m.monster_name) * stance_mult
	var t := m.tile
	m.take_damage(dmg, true)   # crit=true → guldsiffra + kritljud
	spec_flash.emit(t)
