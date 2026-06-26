extends GutTest
## Magisystem: gating (can_cast), inlärning, conjure, AoE, magic-XP, cast_def.
## Använder de globala autoloaderna (SpellSystem/GameState) och återställer
## allt globalt tillstånd i after_each.

class FakeMonster:
	extends Node2D
	var tile := Vector2i.ZERO
	var dead := false
	var hits := 0
	func take_damage(_d: float, _c := false) -> void:
		hits += 1
	func apply_status(_a: String, _b: float, _c: float) -> void:
		pass

var _gold; var _mana; var _max_mana; var _inv; var _learned; var _magic_skill; var _buffs; var _zone
var _fake_zone: Node2D = null

func before_each() -> void:
	_gold = GameState.gold
	_mana = GameState.mana
	_max_mana = GameState.max_mana
	_inv = GameState.inventory.duplicate(true)
	_learned = GameState.learned_spells.duplicate()
	_magic_skill = GameState.skills.get("magic", {"level": 1, "xp": 0}).duplicate(true)
	_buffs = GameState.active_buffs.duplicate(true)
	_zone = World.current_zone
	SpellSystem._cooldowns.clear()
	# Baslinje: rik, full mana, hög magic, inget i väskan, inget inlärt.
	GameState.gold = 100000
	GameState.max_mana = 2000.0
	GameState.mana = 2000.0
	GameState.inventory = {}
	GameState.learned_spells = []
	GameState.active_buffs = []
	GameState.skills["magic"] = {"level": 50, "xp": 0}

func after_each() -> void:
	GameState.gold = _gold
	GameState.mana = _mana
	GameState.max_mana = _max_mana
	GameState.inventory = _inv
	GameState.learned_spells = _learned
	GameState.skills["magic"] = _magic_skill
	GameState.active_buffs = _buffs
	World.current_zone = _zone
	SpellSystem._cooldowns.clear()
	if _fake_zone != null:
		_fake_zone.free()
		_fake_zone = null

func _set_magic(lvl: int) -> void:
	GameState.skills["magic"] = {"level": lvl, "xp": 0}

# ── Laddning ─────────────────────────────────────────────────────────────────
func test_spells_loaded() -> void:
	assert_eq(SpellSystem.spells.size(), 18, "18 spells ska laddas från spells.json")
	assert_true(SpellSystem.spells.has("light_healing"))
	assert_true(SpellSystem.spells.has("energy_wave"))
	assert_true(SpellSystem.spells.has("death_wave"))

func test_cast_def_for_rune() -> void:
	var d := SpellSystem.cast_def("fire_rune")
	assert_false(d.is_empty(), "fire_rune ska ge en cast_def")
	assert_eq(String(d["source"]), "rune")
	assert_eq(String(d["target"]), "target")

func test_cast_def_unknown_is_empty() -> void:
	assert_true(SpellSystem.cast_def("inte_en_spell").is_empty())

func test_needs_aim() -> void:
	assert_true(SpellSystem.needs_aim(SpellSystem.cast_def("flame_strike")), "target-spell kräver sikte")
	assert_false(SpellSystem.needs_aim(SpellSystem.cast_def("light_healing")), "self-spell kräver inte sikte")
	assert_false(SpellSystem.needs_aim(SpellSystem.cast_def("berserk")), "area_self kräver inte sikte")

# ── can_cast-gating ──────────────────────────────────────────────────────────
func test_can_cast_blocks_unknown_spell() -> void:
	var r := SpellSystem.can_cast("flame_strike")
	assert_false(r["ok"], "ej inlärd spell ska blockeras")

func test_can_cast_blocks_low_magic() -> void:
	GameState.learned_spells = ["flame_strike"]
	_set_magic(1)
	var r := SpellSystem.can_cast("flame_strike")
	assert_false(r["ok"])
	assert_string_contains(String(r["reason"]), "magic")

func test_can_cast_blocks_low_mana() -> void:
	GameState.learned_spells = ["light_healing"]
	GameState.mana = 0.0
	var r := SpellSystem.can_cast("light_healing")
	assert_false(r["ok"])

func test_can_cast_blocks_active_cooldown() -> void:
	GameState.learned_spells = ["light_healing"]
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	var r := SpellSystem.can_cast("light_healing")
	assert_false(r["ok"], "spell på cooldown ska blockeras")

func test_can_cast_rune_needs_inventory() -> void:
	var r := SpellSystem.can_cast("fire_rune")
	assert_false(r["ok"], "utan runor i väskan ska runan blockeras")
	GameState.inventory["fire_rune"] = 1
	assert_true(SpellSystem.can_cast("fire_rune")["ok"])

# ── affordability (hotbar-graying) ───────────────────────────────────────────
func test_affordable_true_when_castable() -> void:
	GameState.learned_spells = ["light_healing"]
	assert_true(SpellSystem.affordable("light_healing"), "inlärd spell med mana ska vara affordable")

func test_affordable_false_without_mana() -> void:
	GameState.learned_spells = ["light_healing"]
	GameState.mana = 0.0
	assert_false(SpellSystem.affordable("light_healing"), "utan mana ska den gråtonas")

func test_affordable_false_for_unknown_spell() -> void:
	assert_false(SpellSystem.affordable("flame_strike"), "ej inlärd spell är inte affordable")

func test_affordable_ignores_cooldown() -> void:
	# Nyckelfall: cooldown visas via overlay, inte via graying — affordable
	# ska förbli sann direkt efter en cast så länge resurserna räcker.
	GameState.learned_spells = ["light_healing"]
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	assert_gt(SpellSystem.cooldown_left("light_healing"), 0.0, "spellen ska vara på cooldown")
	assert_true(SpellSystem.affordable("light_healing"), "cooldown ska inte gråtona ikonen")

func test_affordable_rune_needs_inventory() -> void:
	assert_false(SpellSystem.affordable("fire_rune"), "utan runor är den inte affordable")
	GameState.inventory["fire_rune"] = 1
	assert_true(SpellSystem.affordable("fire_rune"))

# ── Signaler (hotbar-blixt m.m. bygger på dessa) ─────────────────────────────
func test_resolve_cast_emits_spell_cast() -> void:
	GameState.learned_spells = ["light_healing"]
	watch_signals(SpellSystem)
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	assert_signal_emitted(SpellSystem, "spell_cast", "cast ska emittera spell_cast för hotbar-feedback")
	var params = get_signal_parameters(SpellSystem, "spell_cast")
	assert_eq(String(params[0]), "light_healing", "signalen ska bära casten:s id")

# ── Inlärning ────────────────────────────────────────────────────────────────
func test_learn_spell_deducts_gold_and_learns() -> void:
	GameState.gold = 1000
	var price := int(SpellSystem.spells["light_healing"]["price"])
	var r := SpellSystem.learn_spell("light_healing")
	assert_true(r["ok"])
	assert_eq(GameState.gold, 1000 - price)
	assert_true(GameState.learned_spells.has("light_healing"))

func test_learn_spell_blocks_low_gold() -> void:
	GameState.gold = 5
	var r := SpellSystem.learn_spell("light_healing")
	assert_false(r["ok"])
	assert_false(GameState.learned_spells.has("light_healing"))

func test_learn_spell_blocks_low_magic() -> void:
	_set_magic(1)
	GameState.gold = 100000
	var r := SpellSystem.learn_spell("death_strike")
	assert_false(r["ok"])

func test_learn_spell_blocks_double_learn() -> void:
	GameState.learned_spells = ["light_healing"]
	var r := SpellSystem.learn_spell("light_healing")
	assert_false(r["ok"])

# ── Conjure ──────────────────────────────────────────────────────────────────
func test_conjure_consumes_reagent_and_adds_runes() -> void:
	GameState.learned_spells = ["conjure_fire"]
	GameState.inventory["blank_rune"] = 3
	var amount := int(SpellSystem.spells["conjure_fire"]["amount"])
	assert_true(SpellSystem.can_cast("conjure_fire")["ok"])
	SpellSystem.resolve_cast("conjure_fire", null, Vector2i.ZERO)
	assert_eq(int(GameState.inventory.get("blank_rune", 0)), 2, "en blank_rune ska förbrukas")
	assert_eq(int(GameState.inventory.get("fire_rune", 0)), amount, "rätt antal fire_rune ska skapas")

func test_conjure_blocked_without_reagent() -> void:
	GameState.learned_spells = ["conjure_fire"]
	var r := SpellSystem.can_cast("conjure_fire")
	assert_false(r["ok"], "conjure utan blank_rune ska blockeras")

# ── Heal / support ───────────────────────────────────────────────────────────
func test_heal_restores_health() -> void:
	GameState.learned_spells = ["light_healing"]
	GameState.max_health = 500.0
	GameState.health = 100.0
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	assert_gt(GameState.health, 100.0, "heal ska öka HP")

func test_support_applies_buff() -> void:
	GameState.learned_spells = ["haste"]
	SpellSystem.resolve_cast("haste", null, Vector2i.ZERO)
	var found := false
	for b in GameState.active_buffs:
		if String(b["stat"]) == "skill:agility":
			found = true
	assert_true(found, "haste ska lägga till en agility-buff")

# ── Mana / XP ────────────────────────────────────────────────────────────────
func test_cast_consumes_mana() -> void:
	GameState.learned_spells = ["light_healing"]
	GameState.mana = 1000.0
	var cost := float(SpellSystem.spells["light_healing"]["mana_cost"])
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	assert_almost_eq(GameState.mana, 1000.0 - cost, 0.01)

func test_cast_grants_magic_xp() -> void:
	GameState.learned_spells = ["light_healing"]
	GameState.skills["magic"] = {"level": 50, "xp": 0}
	SpellSystem.resolve_cast("light_healing", null, Vector2i.ZERO)
	assert_gt(int(GameState.skills["magic"]["xp"]), 0, "casting ska ge magic-XP")

# ── AoE ──────────────────────────────────────────────────────────────────────
func test_area_hits_monsters_within_radius() -> void:
	_fake_zone = Node2D.new()
	var m1 := FakeMonster.new(); m1.tile = Vector2i(5, 5)   # center → träff
	var m2 := FakeMonster.new(); m2.tile = Vector2i(5, 6)   # cheb 1 → träff
	var m3 := FakeMonster.new(); m3.tile = Vector2i(8, 8)   # cheb 3 → miss
	_fake_zone.add_child(m1); _fake_zone.add_child(m2); _fake_zone.add_child(m3)
	World.current_zone = _fake_zone

	GameState.learned_spells = ["fire_wave"]   # target area, radius 1
	var res := SpellSystem.resolve_cast("fire_wave", null, Vector2i(5, 5))
	assert_eq(int(res["hits"]), 2, "fire_wave (radie 1) ska träffa 2 av 3 monster")
	assert_eq(m1.hits, 1)
	assert_eq(m2.hits, 1)
	assert_eq(m3.hits, 0, "monster utanför radien ska inte träffas")

# ── Dataintegritet ───────────────────────────────────────────────────────────
func test_all_spells_have_required_fields() -> void:
	for id in SpellSystem.spells:
		var d: Dictionary = SpellSystem.spells[id]
		for field in ["name", "words", "type", "target", "mana_cost", "magic_lvl", "price"]:
			assert_true(d.has(field), "%s saknar fältet %s" % [id, field])

func test_conjure_spells_reference_real_items() -> void:
	for id in SpellSystem.spells:
		var d: Dictionary = SpellSystem.spells[id]
		if String(d.get("type", "")) != "conjure":
			continue
		assert_true(ItemDB.items.has(String(d["produces"])), "%s producerar okänt item" % id)
		assert_true(ItemDB.items.has(String(d["reagent"])), "%s kräver okänd reagent" % id)

func test_blank_rune_exists() -> void:
	assert_true(ItemDB.items.has("blank_rune"), "blank_rune ska finnas i items.json")

func test_elemental_waves_complete() -> void:
	# Varje stridselement ska ha både en riktad strike och en AoE-våg.
	var waves := {"fire": "fire_wave", "ice": "ice_wave", "energy": "energy_wave", "death": "death_wave"}
	for elem in waves:
		var id: String = waves[elem]
		var d: Dictionary = SpellSystem.spells.get(id, {})
		assert_false(d.is_empty(), "%s saknas" % id)
		assert_eq(String(d.get("target", "")), "area", "%s ska vara area-target" % id)
		assert_eq(String(d.get("element", "")), elem, "%s ska ha element %s" % [id, elem])
		assert_gt(int(d.get("radius", 0)), 0, "%s ska ha radius" % id)

func test_aoe_runes_have_area_target() -> void:
	for rid in ["fire_bomb_rune", "ice_wave_rune"]:
		var d := SpellSystem.cast_def(rid)
		assert_eq(String(d.get("target", "")), "area", "%s ska vara area-target" % rid)
		assert_gt(int(d.get("radius", 0)), 0, "%s ska ha radius" % rid)
