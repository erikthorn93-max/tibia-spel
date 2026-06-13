extends Node
## Spelarens globala tillstånd. Autoload: GameState.

signal hp_changed(hp: float, max_hp: float)
signal mana_changed(mana: float, max_mana: float)
signal exp_changed(xp: int, xp_next: int, level: int)
signal gold_changed(gold: int)
signal inventory_changed
signal level_up(new_level: int)
signal player_died
signal skill_changed(skill: String)
signal buffs_changed
signal appearance_changed
signal equipment_changed
signal player_respawned
signal status_changed

const SKILL_XP_BASE := 50.0
const SKILL_XP_GROWTH := 1.1
const EQUIPMENT_SLOTS := ["weapon", "body", "helmet", "legs", "boots", "offhand"]

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
	"weapon": "rusty_sword", "body": "", "helmet": "", "legs": "", "boots": "", "offhand": ""
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
var active_buffs: Array = []   # [{stat, amount, time_left}]
var active_rune := ""          # id för aktiv runa (F1 kastar)
var status_effects: Dictionary = {}  # id -> {tick_dmg, time_left, tick_acc}
var bank: Dictionary = {}            # item_id -> qty (bankförvar, sparas i save)

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
	skill_changed.emit(skill)

func take_damage(dmg: float) -> void:
	health = maxf(health - dmg, 0.0)
	hp_changed.emit(health, max_health)
	if health <= 0.0:
		player_died.emit()

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

## Tibia-stil dödsåterkomst: 50% XP-förlust, full HP/mana, tillbaka till town.
func respawn() -> void:
	var penalty := int(float(xp_to_next) * 0.5)
	experience = maxi(experience - penalty, 0)
	health = max_health
	mana = max_mana
	current_zone = "town"
	player_tile = Vector2i(-1, -1)
	hp_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	player_respawned.emit()

func add_item(item_id: String, qty: int) -> void:
	if item_id == "iron_coin":
		gold += qty
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

## Applicerar en statuseffekt (skriver över om samma id redan finns).
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
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
			take_damage(s["tick_dmg"])
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
	if d.has("heal"):
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
	if String(d.get("slot", "")) != slot:
		return false
	if int(inventory.get(item_id, 0)) < 1:
		return false
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
	add_item(current, 1)
	equipment_changed.emit()

## Summan av armor-värden från body/helmet/legs/boots.
func total_armor() -> int:
	var total := 0
	for slot in ["body", "helmet", "legs", "boots"]:
		var id := String(equipment.get(slot, ""))
		if id != "":
			total += int(ItemDB.items.get(id, {}).get("armor", 0))
	return total

## shielding_bonus från offhand (sköld).
func total_shielding_bonus() -> int:
	var id := String(equipment.get("offhand", ""))
	if id == "":
		return 0
	return int(ItemDB.items.get(id, {}).get("shielding_bonus", 0))

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
	return true
