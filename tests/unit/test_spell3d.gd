extends GutTest
## Spellcasting i 3D-slicen: SpellSystems pluggbara monsterkälla, Player3D:s
## cast-flöde (self-spells direkt, target-spells mot auto-attack-målet inom
## räckvidd) och hotbarens caster-omkoppling till Player3D.

const Game3DScene = preload("res://world/game3d.tscn")

class FakeSim:
	extends RefCounted
	var tile := Vector2i.ZERO
	var dead := false
	var hits := 0
	func take_damage(_d: float, _c := false, _element := "") -> void:
		hits += 1
	func apply_status(_a: String, _b: float, _c: float) -> void:
		pass

var _saved_zone: String
var _saved_tile: Vector2i
var _saved_hud
var _saved_model
var _saved_source: Callable
var _saved_mana: float
var _saved_max_mana: float
var _saved_health: float
var _saved_learned: Array
var _saved_magic: Dictionary

func before_each() -> void:
	_saved_zone = GameState.current_zone
	_saved_tile = GameState.player_tile
	_saved_hud = World.hud
	_saved_model = World.zone_model
	_saved_source = SpellSystem.monster_source
	_saved_mana = GameState.mana
	_saved_max_mana = GameState.max_mana
	_saved_health = GameState.health
	_saved_learned = GameState.learned_spells.duplicate()
	_saved_magic = GameState.skills.get("magic", {"level": 1, "xp": 0}).duplicate(true)
	SpellSystem._cooldowns.clear()
	# Baslinje: kan allt, full mana.
	GameState.max_mana = 2000.0
	GameState.mana = 2000.0
	GameState.learned_spells = ["light_healing", "energy_strike"]
	GameState.skills["magic"] = {"level": 50, "xp": 0}

func after_each() -> void:
	GameState.current_zone = _saved_zone
	GameState.player_tile = _saved_tile
	World.hud = _saved_hud
	World.zone_model = _saved_model
	SpellSystem.monster_source = _saved_source
	GameState.mana = _saved_mana
	GameState.max_mana = _saved_max_mana
	GameState.health = _saved_health
	GameState.learned_spells = _saved_learned
	GameState.skills["magic"] = _saved_magic
	SpellSystem._cooldowns.clear()

func _boot() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

## Ett levande monster i startzonen, med simmens tile flyttad intill spelaren.
func _target_near_player(g: Node3D, dist := 2) -> MonsterSim:
	for m in g._monsters_root.get_children():
		if m is Monster3D and not m.sim.dead:
			m.sim.tile = g.player.sim.tile + Vector2i(dist, 0)
			return m.sim
	return null

# ── SpellSystem: pluggbar monsterkälla ────────────────────────────────────────

func test_monster_source_used_for_attack_pool() -> void:
	var s := FakeSim.new()
	s.tile = Vector2i(4, 4)
	SpellSystem.monster_source = func() -> Array: return [s]
	var hit := SpellSystem._monsters_in_radius(Vector2i(4, 4), 0)
	assert_eq(hit.size(), 1, "källans sim inom radien ska träffas")
	var missed := SpellSystem._monsters_in_radius(Vector2i(20, 20), 0)
	assert_eq(missed.size(), 0, "utanför radien ska ingen träffas")

func test_stale_monster_source_is_ignored() -> void:
	# Källa bunden till en fri-ad nod får inte krascha — poolen faller
	# tillbaka till 2D-standarden (tom utan zon).
	var owner := Node.new()
	SpellSystem.monster_source = Callable(owner, "get_name")
	owner.free()
	var pool := SpellSystem._monster_pool()
	assert_eq(pool.size(), 0, "fri-ad källa ska ignoreras utan krasch")

func test_game3d_wires_and_clears_monster_source() -> void:
	var g := _boot()
	assert_true(SpellSystem.monster_source.is_valid(),
		"game3d ska koppla in sin monsterkälla")
	assert_eq(SpellSystem.monster_source.get_object(), g)
	var pool: Array = SpellSystem._monster_pool()
	assert_gt(pool.size(), 0, "startzonen ska ge levande simmar i poolen")
	assert_true(pool[0] is MonsterSim, "poolen ska bestå av MonsterSim")

# ── Player3D.cast_spell ───────────────────────────────────────────────────────

func test_self_heal_casts_directly() -> void:
	var g := _boot()
	GameState.health = 30.0
	g.player.cast_spell("light_healing")
	assert_gt(GameState.health, 30.0, "exura ska hela direkt utan sikte")
	assert_gt(SpellSystem.cooldown_left("light_healing"), 0.0)

func test_blocked_cast_shows_reason() -> void:
	var g := _boot()
	GameState.mana = 0.0
	g.player.cast_spell("light_healing")
	assert_string_contains(g.hud._msg_lbl.text, "mana",
		"blockerad cast ska visa can_cast-orsaken i HUD:en")

func test_target_spell_without_target_denied() -> void:
	var g := _boot()
	g.player.sim.target = null
	var mana_before: float = GameState.mana
	g.player.cast_spell("energy_strike")
	assert_eq(GameState.mana, mana_before, "utan mål ska ingen mana förbrukas")
	assert_string_contains(g.hud._msg_lbl.text, "mål")

func test_target_spell_out_of_range_denied() -> void:
	var g := _boot()
	var t := _target_near_player(g, 9)   # energy_strike har range 5
	assert_not_null(t, "startzonen ska ha ett monster")
	g.player.sim.target = t
	var mana_before: float = GameState.mana
	g.player.cast_spell("energy_strike")
	assert_eq(GameState.mana, mana_before, "utom räckvidd ska ingen mana förbrukas")
	assert_string_contains(g.hud._msg_lbl.text, "långt bort")

func test_target_spell_hits_target_in_range() -> void:
	var g := _boot()
	var t := _target_near_player(g, 2)
	assert_not_null(t, "startzonen ska ha ett monster")
	g.player.sim.target = t
	var hp_before: float = t.hp
	g.player.cast_spell("energy_strike")
	assert_lt(t.hp, hp_before, "målet inom räckvidd ska ta skada")
	assert_gt(SpellSystem.cooldown_left("energy_strike"), 0.0)

# ── Hotbaren i 3D ─────────────────────────────────────────────────────────────

func test_hotkey_bar_casts_via_player3d() -> void:
	var g := _boot()
	assert_not_null(g.hud.hotkey_bar, "3D-HUD:en ska ha hotbaren")
	assert_eq(g.hud.hotkey_bar.caster, g.player,
		"hotbarens caster ska vara Player3D")
	GameState.health = 30.0
	g.hud.hotkey_bar._slots[0]["spell_id"] = "light_healing"
	g.hud.hotkey_bar._slots[0]["item_id"] = ""
	g.hud.hotkey_bar._use_slot(0)
	assert_gt(GameState.health, 30.0,
		"hotbar-slot med spell ska kasta via Player3D")
