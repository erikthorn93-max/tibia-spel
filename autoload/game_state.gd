extends Node
## Spelarens globala tillstånd. Autoload: GameState.

signal hp_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)
signal exp_changed(xp: int, xp_next: int, level: int)
signal gold_changed(gold: int)
signal inventory_changed
signal level_up(new_level: int)
signal player_died
signal player_hit(dmg: float, dmg_type: String)
signal skill_changed(skill: String)
signal skill_leveled(skill: String, new_level: int)
signal crafted(item_id: String, skill: String)
signal item_used(item_id: String)
signal buffs_changed
signal appearance_changed
signal equipment_changed
signal player_respawned
signal status_changed
signal satiation_changed(seconds: float, max_seconds: float)
signal blessings_changed(count: int)
signal stance_changed(stance: String)
signal spec_changed(energy: float)
signal charm_feedback(text: String, color: Color)   # defensiv charm parerade — vyn visar floating text

const SKILL_XP_BASE := 50.0
const SKILL_XP_GROWTH := 1.1
const EQUIPMENT_SLOTS := ["weapon", "body", "helmet", "legs", "boots", "offhand",
	"amulet", "ring", "ring2", "ammo", "tool", "light", "backpack"]
## Andel av varje stack som tappas vid död utan ryggsäck.
const BASE_DEATH_DROP := 0.30
## Max antal välsignelser man kan bära (Tibia-stil). Förbrukas vid död.
const MAX_BLESSINGS := 5
## Mättnad (satiation): mat ger sekunder av passiv regenerering, Tibia-stil.
const REGEN_INTERVAL := 3.0          # hur ofta HP/mana regenereras medan mätt
const SECONDS_PER_NUTRITION := 4.0   # mättnadssekunder per näringsvärde i maten
const MAX_SATIATION := 600.0         # tak på lagrad mättnad
## Slots vars föremål ligger kvar i ryggsäcken — sloten är bara en aktiv-markör
## (du behåller dina verktyg/pilar och använder dem därifrån).
const REFERENCE_SLOTS := ["ammo", "tool"]

var player_name := "Hjälte"
var level := 1
var experience := 0
var xp_to_next := 100
var health := 150.0
var max_health := 150.0
var mana := 100.0
var max_mana := 100.0
var gold := 0
var inventory: Dictionary = {}        # item_id -> qty
## 6 utrustningsplatser. weapon startar med rusty_sword (gratis startitem).
var equipment: Dictionary = {
	"weapon": "rusty_sword", "body": "", "helmet": "", "legs": "", "boots": "", "offhand": "",
	"amulet": "", "ring": "", "ring2": "", "ammo": "", "tool": "", "light": "", "backpack": ""
}
## Bakåtkompatibel property: läser/skriver equipment["weapon"].
var equipped_weapon: String:
	get: return String(equipment.get("weapon", ""))
	set(v): equipment["weapon"] = v
var appearance := {                   # character creation (M1: färger)
	"skin": "#e0b894", "hair": "#332211", "shirt": "#2e4dc0", "pants": "#1a1a52",
}
var appearance_base: Dictionary = {}  # originalfärgerna — fångas vid första outfit-bytet
var outfit_equipped := "standard"
var outfit_defs: Dictionary = {}      # data/outfits.json
var skills: Dictionary = {}
var skill_defs: Dictionary = {}
var current_zone := "town"
var player_tile := Vector2i.ZERO
var home_zone := "town"               # hempunkt: dit man återuppstår vid död
var home_tile := Vector2i(-1, -1)     # (-1,-1) = zonens player_start
var blessings := 0                    # aktiva välsignelser; mildrar dödsstraff
var grave_zone := ""                  # zon där döds-looten ligger ("" = ingen grav)
var grave_tile := Vector2i(-1, -1)    # tile där lootpåsen ligger
var grave_drops: Array = []           # [{item, qty}] som väntar på upphämtning
var active_buffs: Array = []   # [{stat, amount, time_left}]
var active_rune := ""          # DEPRECERAD: gamla run-spåret, migreras bort
var learned_spells: Array = [] # id:n för inlärda instant-spells (SpellSystem)
var status_effects: Dictionary = {}  # id -> {tick_dmg, time_left, tick_acc}
var bank: Dictionary = {}            # item_id -> qty (bankförvar, sparas i save)
var combat_stance := CombatStance.DEFAULT   # offensiv/balanserad/defensiv (sparas)
var spec_energy := 0.0                       # specialattack-laddning 0..100 (sparas)
var satiation := 0.0                 # sekunder av kvarvarande mättnad/regen
var _regen_acc := 0.0                # ackumulator för regen-intervallet

## _init (inte _ready): skills måste finnas direkt vid .new() i tester,
## och innan andra autoloads läser GameState.skills.
func _init() -> void:
	_load_skills()
	_load_outfits()

func _load_outfits() -> void:
	var f := FileAccess.open("res://data/outfits.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	outfit_defs = parsed if parsed is Dictionary else {}


func equip_outfit(id: String) -> bool:
	if not outfit_defs.has(id):
		return false
	var uid := String(outfit_defs[id].get("unlock", ""))
	if uid != "" and not UnlockSystem.is_unlocked(uid):
		return false
	if appearance_base.is_empty():
		appearance_base = appearance.duplicate()
	appearance = appearance_base.duplicate()
	for key in outfit_defs[id].get("colors", {}):
		if key != "skin":   # skin kommer alltid från character creation
			appearance[key] = outfit_defs[id]["colors"][key]
	outfit_equipped = id
	appearance_changed.emit()
	return true

func _load_skills() -> void:
	var f := FileAccess.open("res://data/skills.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	skill_defs = parsed if parsed is Dictionary else {}
	ensure_all_skills()

func ensure_all_skills() -> void:
	for id in skill_defs:
		if not skills.has(id):
			skills[id] = {"level": int(skill_defs[id].get("start_level", 1)), "xp": 0}

func xp_for_level(lvl: int) -> int:
	return 50 * lvl * (lvl + 1)

func skill_xp_next(skill_level: int, skill_id := "") -> int:
	var base := SKILL_XP_BASE
	var growth := SKILL_XP_GROWTH
	if skill_defs.has(skill_id):
		base = float(skill_defs[skill_id].get("xp_base", SKILL_XP_BASE))
		growth = float(skill_defs[skill_id].get("xp_growth", SKILL_XP_GROWTH))
	return int(base * pow(growth, skill_level))

## ── Skill-XP-avläsning (för OSRS-stil XP-bar + hover) ──

func skill_base_level(skill_id: String) -> int:
	return int(skills.get(skill_id, {}).get("level", 1))

## XP intjänad inom nuvarande nivå (nollställs vid level-up).
func skill_xp_in_level(skill_id: String) -> int:
	return int(skills.get(skill_id, {}).get("xp", 0))

## XP kvar tills nästa nivå.
func skill_xp_to_next(skill_id: String) -> int:
	if not skills.has(skill_id):
		return 0
	var need := skill_xp_next(skill_base_level(skill_id), skill_id)
	return maxi(need - skill_xp_in_level(skill_id), 0)

## Andel av vägen till nästa nivå (0.0–1.0).
func skill_xp_progress(skill_id: String) -> float:
	if not skills.has(skill_id):
		return 0.0
	var need := skill_xp_next(skill_base_level(skill_id), skill_id)
	return clampf(float(skill_xp_in_level(skill_id)) / float(need), 0.0, 1.0) if need > 0 else 0.0

## Total ackumulerad XP i skillen (summan över alla klarade nivåer + nuvarande).
func skill_total_xp(skill_id: String) -> int:
	if not skills.has(skill_id):
		return 0
	var start := int(skill_defs.get(skill_id, {}).get("start_level", 1))
	var total := skill_xp_in_level(skill_id)
	for l in range(start, skill_base_level(skill_id)):
		total += skill_xp_next(l, skill_id)
	return total

func gain_exp(amount: int) -> void:
	experience += amount
	while experience >= xp_to_next:
		experience -= xp_to_next
		level += 1
		xp_to_next = xp_for_level(level)
		max_health += 25.0
		health = max_health
		max_mana += 12.0
		mana = max_mana
		level_up.emit(level)
	exp_changed.emit(experience, xp_to_next, level)

func gain_skill_xp(skill: String, amount: int) -> void:
	if not skills.has(skill):
		return
	var s: Dictionary = skills[skill]
	s["xp"] += amount
	while s["xp"] >= skill_xp_next(s["level"], skill):
		s["xp"] -= skill_xp_next(s["level"], skill)
		s["level"] += 1
		skill_leveled.emit(skill, int(s["level"]))
	skill_changed.emit(skill)

func take_damage(dmg: float, dmg_type: String = "physical") -> void:
	# Redan död: liket tar inte mer stryk. Utan vakten re-emittas player_died
	# för varje slag mot liket — dubbla döds-flöden, och det andra
	# drop_death_loot-anropet ser tomt inventory och raderar graven.
	if health <= 0.0:
		return
	# Defensiv charm kan mildra eller helt undvika slaget innan det landar.
	var d := CharmSystem.roll_defense(dmg)
	if d.get("triggered", false):
		dmg = maxf(dmg - float(d["prevented"]), 0.0)
		_show_charm_block(String(d["id"]), dmg <= 0.0)
	health = maxf(health - dmg, 0.0)
	hp_changed.emit(health, max_health)
	player_hit.emit(dmg, dmg_type)
	gain_skill_xp("constitution", 1)   # skada tränar constitution
	# Träff-blink ägs av vyn: player.gd lyssnar på player_hit och blinkar
	# vid fysiska slag (medvetet inte vid DoT-ticks).
	Sfx.player_hurt()
	# Adrenalin-charm: överlever du slaget med lågt HP kan farten skjuta i höjden.
	if health > 0.0 and max_health > 0.0:
		var a := CharmSystem.roll_adrenaline(health / max_health)
		if a.get("triggered", false):
			apply_buff("speed", float(a["speed"]), float(a["duration"]))
			_show_charm_block(String(a["id"]), false)
	if health <= 0.0:
		Sfx.player_died()
		player_died.emit()

## Ljud + signal när en defensiv charm parerar eller helt undviker ett slag.
## Floating text spawnas av vyn (player.gd) — GameState rör inte scenträdet.
func _show_charm_block(charm_id: String, fully_avoided: bool) -> void:
	Sfx.charm_block()
	var cname := String(CharmSystem.charms.get(charm_id, {}).get("name", "Charm"))
	var text := cname + "!" if fully_avoided else cname
	var color := Color(0.5, 0.95, 1.0) if fully_avoided else Color(0.7, 0.85, 1.0)
	charm_feedback.emit(text, color)

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	hp_changed.emit(health, max_health)

## Drar mana. Returnerar false om otillräcklig mana (inget dras av).
func use_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	mana_changed.emit(mana, max_mana)
	return true

## Återställer mana, clampar på max_mana.
func restore_mana(amount: float) -> void:
	mana = minf(mana + amount, max_mana)
	mana_changed.emit(mana, max_mana)

## Tappar mana (monster-förmåga "drain"). Tar överskottet från HP om manan
## tar slut, så effekten biter även när spelaren är tom på mana.
func drain_mana(amount: float) -> void:
	var from_mana := minf(mana, maxf(amount, 0.0))
	mana -= from_mana
	mana_changed.emit(mana, max_mana)
	var remainder := amount - from_mana
	if remainder > 0.0:
		take_damage(remainder, "drain")

## Sätter hempunkten (dit man återuppstår vid död). Tile (-1,-1) = zonens start.
func set_home(zone: String, tile := Vector2i(-1, -1)) -> void:
	home_zone = zone
	home_tile = tile

## True om det finns en grav med oupphämtad loot.
func has_grave() -> bool:
	return grave_zone != "" and not grave_drops.is_empty()

## Lägger en grav (döds-loot) som väntar på upphämtning i en viss zon.
func set_grave(zone: String, tile: Vector2i, drops: Array) -> void:
	grave_zone = zone
	grave_tile = tile
	grave_drops = drops

## Rensar graven — anropas när looten plockats upp.
func clear_grave() -> void:
	grave_zone = ""
	grave_tile = Vector2i(-1, -1)
	grave_drops = []

## Köper så många välsignelser som har råd, upp till MAX_BLESSINGS.
## Returnerar antalet köpta välsignelser (0 om fullt välsignad eller utan råd).
func buy_blessings(cost_each: int) -> int:
	var missing := MAX_BLESSINGS - blessings
	if missing <= 0:
		return 0
	@warning_ignore("integer_division")
	var affordable := (gold / cost_each) if cost_each > 0 else missing
	var n := mini(missing, affordable)
	if n <= 0:
		return 0
	gold -= n * cost_each
	blessings += n
	gold_changed.emit(gold)
	blessings_changed.emit(blessings)
	return n

## XP-strafffaktor vid död: varje välsignelse mildrar förlusten med 8 %.
func bless_xp_penalty_mult() -> float:
	return clampf(1.0 - 0.08 * blessings, 0.0, 1.0)

## Tibia-stil dödsåterkomst: 50% XP-förlust (mildras av välsignelser),
## full HP/mana, tillbaka till hempunkten. Välsignelser förbrukas vid död.
func respawn() -> void:
	var penalty := int(float(xp_to_next) * 0.5 * bless_xp_penalty_mult())
	experience = maxi(experience - penalty, 0)
	health = max_health
	mana = max_mana
	current_zone = home_zone
	player_tile = home_tile
	if blessings > 0:
		blessings = 0
		blessings_changed.emit(blessings)
	hp_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	player_respawned.emit()

func add_item(item_id: String, qty: int) -> void:
	# Valutaslag (järnmynt, guldmynt …) går direkt till guld efter sitt värde.
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if String(d.get("type", "")) == "currency":
		gold += qty * int(d.get("value", 1))
		gold_changed.emit(gold)
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + qty
	inventory_changed.emit()

func remove_item(item_id: String, qty: int) -> bool:
	if int(inventory.get(item_id, 0)) < qty:
		return false
	inventory[item_id] -= qty
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true

## Thieving: försök att bestjäla. spec: {level, xp, gold:[min,max], item?,
## item_chance?, item_count?}. Tränar thieving så fort försöket är tillåtet
## (nivåkravet uppfyllt). Returnerar true om bytet faktiskt togs.
func attempt_steal(spec: Dictionary) -> bool:
	var req := int(spec.get("level", 1))
	var lvl := effective_skill_level("thieving")
	if lvl < req:
		return false   # för svår måltavla — inget försök, ingen XP
	gain_skill_xp("thieving", int(spec.get("xp", 10)))
	var chance: float = clampf(0.45 + 0.04 * float(lvl - req), 0.45, 0.95)
	if randf() > chance:
		return false   # ertappad — inget byte
	var g: Array = spec.get("gold", [])
	if g.size() == 2:
		add_item("iron_coin", randi_range(int(g[0]), int(g[1])))
	if spec.has("item") and randf() < float(spec.get("item_chance", 1.0)):
		add_item(String(spec["item"]), int(spec.get("item_count", 1)))
	return true

## Applicerar en statuseffekt.
## DoT-effekter (tick_dmg > 0, t.ex. poison/burn) får INTE förnyas till full
## duration av varje ny proc — det gjorde gift permanent när snabba monster
## träffade om och om igen. En redan aktiv DoT uppdateras bara om den nya är
## STARKARE (högre tick_dmg); lika/svagare procs ignoreras och låter den
## pågående effekten ticka ut. Icke-DoT (stun/slow, tick_dmg 0) förnyas som förr.
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
	if tick_dmg > 0.0 and status_effects.has(id) \
			and tick_dmg <= float(status_effects[id]["tick_dmg"]):
		return
	status_effects[id] = {"tick_dmg": tick_dmg, "time_left": duration, "tick_acc": 0.0}
	status_changed.emit()

## Tar bort en statuseffekt (t.ex. motgift tar bort "poison").
func clear_status(id: String) -> void:
	if status_effects.erase(id):
		status_changed.emit()

func has_status(id: String) -> bool:
	return status_effects.has(id)

func _process(delta: float) -> void:
	_tick_buffs(delta)
	_tick_statuses(delta)
	_tick_regen(delta)

## HP/mana-regen per intervall medan spelaren är mätt. Mättnaden tickar ned
## i realtid; regenereringen sker i diskreta steg om REGEN_INTERVAL.
func _tick_regen(delta: float) -> void:
	if satiation <= 0.0:
		return
	satiation = maxf(satiation - delta, 0.0)
	_regen_acc += delta
	while _regen_acc >= REGEN_INTERVAL:
		_regen_acc -= REGEN_INTERVAL
		if health < max_health:
			heal(float(hp_regen_amount()))
		if mana < max_mana:
			restore_mana(float(mp_regen_amount()))
	satiation_changed.emit(satiation, MAX_SATIATION)

## HP som regenereras per intervall — skalar med constitution + regen-gear.
func hp_regen_amount() -> int:
	@warning_ignore("integer_division")
	return 1 + effective_skill_level("constitution") / 15 + total_regen()

## Mana som regenereras per intervall — skalar med magic-skill.
func mp_regen_amount() -> int:
	@warning_ignore("integer_division")
	return 1 + effective_skill_level("magic") / 8

## Lägg till mättnadssekunder (från mat). Clampas på MAX_SATIATION.
func feed(seconds: float) -> void:
	satiation = minf(satiation + seconds, MAX_SATIATION)
	satiation_changed.emit(satiation, MAX_SATIATION)

## Vila på värdshus: betalar guld, återställer HP/mana fullt och toppar mättnad.
## Returnerar false (utan att ändra något) om spelaren inte har råd.
func rest_at_inn(cost: int, satiation_secs := 0.0) -> bool:
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	health = max_health
	mana = max_mana
	hp_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	if satiation_secs > 0.0:
		feed(satiation_secs)
	return true

func _tick_statuses(delta: float) -> void:
	if status_effects.is_empty():
		return
	var changed := false
	for id in status_effects.keys():
		var s: Dictionary = status_effects[id]
		s["time_left"] -= delta
		s["tick_acc"]  += delta
		if s["tick_acc"] >= 1.0:   # en tick per sekund
			s["tick_acc"] -= 1.0
			take_damage(s["tick_dmg"], id)   # id = "poison", "burn" etc.
		if s["time_left"] <= 0.0:
			status_effects.erase(id)
			changed = true
	if changed:
		status_changed.emit()

func apply_buff(stat: String, amount: float, duration: float) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i]["stat"] == stat:
			active_buffs.remove_at(i)
	active_buffs.append({"stat": stat, "amount": amount, "time_left": duration})
	buffs_changed.emit()

func _tick_buffs(delta: float) -> void:
	var changed := false
	for i in range(active_buffs.size() - 1, -1, -1):
		var b: Dictionary = active_buffs[i]
		if b["stat"] == "regen":
			heal(float(b["amount"]) * delta)
		b["time_left"] -= delta
		if b["time_left"] <= 0.0:
			active_buffs.remove_at(i)
			changed = true
	if changed:
		buffs_changed.emit()

func effective_skill_level(skill: String) -> int:
	var lvl := int(skills.get(skill, {"level": 1})["level"])
	for b in active_buffs:
		if String(b["stat"]) == "skill:" + skill:
			lvl += int(b["amount"])
	return lvl

func use_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) < 1:
		return false
	var d: Dictionary = ItemDB.items.get(item_id, {})
	var used := false
	var is_food := String(d.get("type", "")) == "food"
	if d.has("heal"):
		if is_food:
			# Mat helar inte direkt — den ger mättnad som driver passiv regen.
			var nutrition := maxi(int(d["heal"]), 10)
			feed(nutrition * SECONDS_PER_NUTRITION)
		else:
			heal(float(d["heal"]))
		used = true
	if d.has("mana"):
		mana = minf(mana + float(d["mana"]), max_mana)
		mana_changed.emit(mana, max_mana)
		used = true
	if d.has("buff"):
		var b: Dictionary = d["buff"]
		apply_buff(String(b["stat"]), float(b["amount"]), float(b["duration"]))
		used = true
	if d.has("clears_poison"):
		clear_status("poison")
		used = true
	if d.get("usable", false):
		used = true
	if used:
		remove_item(item_id, 1)
		QuestSystem.record_use(item_id)
		item_used.emit(item_id)
	return used

func weapon_skill() -> String:
	var w: Dictionary = ItemDB.items.get(String(equipment.get("weapon", "")), {})
	return String(w.get("skill", "fist"))

## Utrusta ett föremål i given slot. Kräver att item finns i inventory och
## att item.slot matchar slot-argumentet. Eventuellt befintligt föremål i
## sloten returneras till inventory automatiskt.
func equip(slot: String, item_id: String) -> bool:
	if not EQUIPMENT_SLOTS.has(slot):
		return false
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if d.is_empty():
		return false
	if not slot_accepts(slot, String(d.get("slot", ""))):
		return false
	if int(inventory.get(item_id, 0)) < 1:
		return false
	# Markör-slots (verktyg/pilar): föremålet stannar i ryggsäcken.
	if slot in REFERENCE_SLOTS:
		equipment[slot] = item_id
		equipment_changed.emit()
		return true
	# Returnera eventuellt befintligt föremål
	var current := String(equipment.get(slot, ""))
	if current != "":
		add_item(current, 1)
	remove_item(item_id, 1)
	equipment[slot] = item_id
	equipment_changed.emit()
	inventory_changed.emit()
	return true

## Ta av föremål i given slot och lägg tillbaka i inventory.
func unequip(slot: String) -> void:
	if not EQUIPMENT_SLOTS.has(slot):
		return
	var current := String(equipment.get(slot, ""))
	if current == "":
		return
	equipment[slot] = ""
	if slot not in REFERENCE_SLOTS:   # markör-slots tog aldrig något ur ryggsäcken
		add_item(current, 1)
	equipment_changed.emit()

## Summan av armor-värden från body/helmet/legs/boots + halsband/ringar.
func total_armor() -> int:
	var total := 0
	for slot in ["body", "helmet", "legs", "boots", "amulet", "ring", "ring2"]:
		var id := String(equipment.get(slot, ""))
		if id != "":
			total += int(ItemDB.items.get(id, {}).get("armor", 0))
	return total

## True om ett föremål med item_slot får utrustas i slot.
## Ringar passar i både "ring" och "ring2".
func slot_accepts(slot: String, item_slot: String) -> bool:
	if item_slot == slot:
		return true
	return slot == "ring2" and item_slot == "ring"

## Ljusstyrka från utrustad ljuskälla (0.0 = ingen). Minskar nattmörkret.
func light_level() -> float:
	var id := String(equipment.get("light", ""))
	if id == "":
		return 0.0
	return float(ItemDB.items.get(id, {}).get("light", 0.0))

## Andel av varje stack som tappas vid död. En utrustad ryggsäck skyddar
## innehållet (drop_protection) och sänker andelen, dock aldrig under 5 %.
func death_drop_fraction() -> float:
	# Full uppsättning välsignelser skyddar allt löst gods.
	if blessings >= MAX_BLESSINGS:
		return 0.0
	var id := String(equipment.get("backpack", ""))
	var protection := float(ItemDB.items.get(id, {}).get("drop_protection", 0.0)) if id != "" else 0.0
	var base := clampf(BASE_DEATH_DROP - protection, 0.05, BASE_DEATH_DROP)
	# Varje välsignelse skyddar ytterligare 18 % av det som annars tappas.
	return base * clampf(1.0 - 0.18 * blessings, 0.0, 1.0)

## True om verktyget är tillgängligt — antingen i ryggsäcken eller i verktygssloten.
func has_tool(tool_id: String) -> bool:
	if tool_id == "":
		return true
	return int(inventory.get(tool_id, 0)) >= 1 or String(equipment.get("tool", "")) == tool_id

## True om ammunitionen finns — i ryggsäcken eller i pilsloten.
func has_ammo(ammo_id: String) -> bool:
	if ammo_id == "":
		return true
	return int(inventory.get(ammo_id, 0)) >= 1 or String(equipment.get("ammo", "")) == ammo_id

## Förbrukar en ammunition från ryggsäcken. Töms pilsloten-markören när sista
## pilen av den typen skjuts. Returnerar true om något förbrukades.
func consume_ammo(ammo_id: String) -> bool:
	if ammo_id == "":
		return true
	if int(inventory.get(ammo_id, 0)) < 1:
		return false
	remove_item(ammo_id, 1)
	if int(inventory.get(ammo_id, 0)) < 1 and String(equipment.get("ammo", "")) == ammo_id:
		equipment["ammo"] = ""
		equipment_changed.emit()
	return true

## shielding_bonus från offhand (sköld).
func total_shielding_bonus() -> int:
	var id := String(equipment.get("offhand", ""))
	if id == "":
		return 0
	return int(ItemDB.items.get(id, {}).get("shielding_bonus", 0))

## Summerar ett numeriskt bonusfält över all utrustad gear.
func _sum_equip_field(field: String) -> float:
	var total := 0.0
	for slot in equipment:
		var id := String(equipment.get(slot, ""))
		if id != "":
			total += float(ItemDB.items.get(id, {}).get(field, 0))
	return total

## Total attack-bonus (atk_bonus) från all utrustning — adderas till vapnets ATK.
func total_atk_bonus() -> int:
	return int(_sum_equip_field("atk_bonus"))

## Total defense-bonus (def_bonus) från all utrustning — adderas till rustning vid mitigering.
func total_def_bonus() -> int:
	return int(_sum_equip_field("def_bonus"))

## Total attackhastighetsbonus (speed_bonus) — kortar ner attackens cooldown (andel).
## Summerar utrustning + tillfälliga "speed"-buffar (t.ex. adrenalin-charm).
func total_speed_bonus() -> float:
	var v := _sum_equip_field("speed_bonus")
	for b in active_buffs:
		if String(b["stat"]) == "speed":
			v += float(b["amount"])
	return v

## Total kritträff-bonus (crit_chance) från utrustning — adderas till crit-chansen.
func total_crit_bonus() -> float:
	return _sum_equip_field("crit_chance")

## Total regen-bonus (regen) från utrustning — adderas till passiv HP-regen.
func total_regen() -> int:
	return int(_sum_equip_field("regen"))

## Sätter stridsställning (validerad) och meddelar lyssnare om den ändrades.
func set_combat_stance(stance: String) -> void:
	var s := CombatStance.normalize(stance)
	if s == combat_stance:
		return
	combat_stance = s
	stance_changed.emit(s)

## Växlar till nästa ställning i cykeln. Returnerar den nya ställningen.
func cycle_combat_stance() -> String:
	set_combat_stance(CombatStance.cycle(combat_stance))
	return combat_stance

## Laddar specialattack-mätaren (vid landat vapenslag) och meddelar HUD:en.
func add_spec(amount: float) -> void:
	var e := CombatFormulas.charge_spec(spec_energy, amount)
	if e != spec_energy:
		spec_energy = e
		spec_changed.emit(e)

## Tömmer mätaren om den är full. Returnerar true om kraftslaget fick släppas.
func consume_spec() -> bool:
	if not CombatFormulas.spec_ready(spec_energy):
		return false
	spec_energy = 0.0
	spec_changed.emit(0.0)
	return true

## Bakåtkompatibel wrapper — anropar equip("weapon", item_id).
func equip_weapon(item_id: String) -> bool:
	if String(equipment.get("weapon", "")) == item_id:
		return true   # redan utrustat
	return equip("weapon", item_id)

## Bakåtkompatibel wrapper — anropar unequip("weapon").
func unequip_weapon() -> void:
	unequip("weapon")

func buy_item(item_id: String) -> bool:
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if d.is_empty():
		return false
	var price := int(d["value"])
	if gold < price:
		return false
	gold -= price
	gold_changed.emit(gold)
	add_item(item_id, 1)
	return true

func sell_item(item_id: String) -> bool:
	var d: Dictionary = ItemDB.items.get(item_id, {})
	if d.is_empty():
		return false
	if not remove_item(item_id, 1):
		return false
	gold += int(int(d["value"]) * 0.5)
	gold_changed.emit(gold)
	return true

func craft(recipe: Dictionary) -> bool:
	var skill := String(recipe["skill"])
	if not Recipes.can_craft(recipe, inventory, effective_skill_level(skill)):
		return false
	for ing in recipe["ingredients"]:
		remove_item(ing, int(recipe["ingredients"][ing]))
	add_item(String(recipe["id"]), 1)
	gain_skill_xp(skill, int(recipe["xp"]))
	crafted.emit(String(recipe["id"]), skill)
	return true
