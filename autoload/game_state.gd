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

const SKILL_XP_BASE := 50.0
const SKILL_XP_GROWTH := 1.1

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
var equipped_weapon := "rusty_sword"
var appearance := {                   # character creation (M1: färger)
	"skin": "#e0b894", "hair": "#332211", "shirt": "#2e4dc0", "pants": "#1a1a52",
}
var skills: Dictionary = {}
var skill_defs: Dictionary = {}
var current_zone := "town"
var player_tile := Vector2i.ZERO

## _init (inte _ready): skills måste finnas direkt vid .new() i tester,
## och innan andra autoloads läser GameState.skills.
func _init() -> void:
	_load_skills()

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
