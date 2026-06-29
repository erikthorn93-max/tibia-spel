extends GutTest
## Test för den vågbaserade gladiatorarenan (Knight's Arena, Arena Master Torben).
##  ArenaSystem driver vågprogression/kill-räkning/belöning frikopplat från
##  spawning; World lyssnar på wave_started. Här testas logiken headless plus
##  dialog-kopplingen (start_arena-action, arena_active-villkor) och givaren.

const NPC_ID := "npc_arena_master"
const REWARD_ID := "triumph_blade"

func before_each():
	ArenaSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0
	UnlockSystem.unlocked.erase(ArenaSystem.CHAMPION_UNLOCK)

func after_each():
	UnlockSystem.unlocked.erase(ArenaSystem.CHAMPION_UNLOCK)

func _total_monsters() -> int:
	var n := 0
	for w in ArenaSystem.waves:
		for s in w.get("spawns", []):
			n += int(s.get("count", 0))
	return n

func _wave_count(i: int) -> int:
	var n := 0
	for s in ArenaSystem.waves[i].get("spawns", []):
		n += int(s.get("count", 0))
	return n

func _zone_data(zone_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/zones/%s.json" % zone_id, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	return parsed if parsed is Dictionary else {}

# ── Data ──────────────────────────────────────────────────────────────────────

func test_arenan_har_vagor_och_giltig_data():
	assert_gt(ArenaSystem.wave_count(), 0, "arenan ska ha minst en våg")
	for w in ArenaSystem.waves:
		for s in w.get("spawns", []):
			assert_true(MonsterDB.monsters.has(String(s["monster"])),
				"arenavåg refererar okänt monster %s" % s["monster"])
			assert_gt(int(s.get("count", 0)), 0, "varje spawn ska ha count > 0")

func test_beloningen_ar_ett_giltigt_vapen():
	assert_true(ItemDB.items.has(REWARD_ID), "Triumfklingan saknas")
	var it: Dictionary = ItemDB.items[REWARD_ID]
	assert_eq(String(it["type"]), "weapon")
	assert_true(REWARD_ID in ArenaSystem.reward.get("items", {}),
		"Triumfklingan ska ingå i arenans belöning")

# ── Start / vågprogression ──────────────────────────────────────────────────

func test_start_borjar_pa_forsta_vagen():
	watch_signals(ArenaSystem)
	assert_true(ArenaSystem.start(), "start() ska lyckas från viloläge")
	assert_true(ArenaSystem.is_active())
	assert_eq(ArenaSystem.current_wave, 0)
	assert_eq(ArenaSystem.remaining(), _wave_count(0), "fel antal fiender i våg 1")
	assert_signal_emitted(ArenaSystem, "wave_started")

func test_start_nekas_nar_omgang_redan_pagar():
	assert_true(ArenaSystem.start())
	assert_false(ArenaSystem.start(), "två samtidiga omgångar ska inte tillåtas")

func test_kill_rakanar_ned_och_gar_till_nasta_vag():
	watch_signals(ArenaSystem)
	ArenaSystem.start()
	var first := _wave_count(0)
	for i in range(first):
		ArenaSystem.record_kill("dummy")
	assert_signal_emitted(ArenaSystem, "wave_cleared")
	assert_eq(ArenaSystem.current_wave, 1, "ska ha avancerat till våg 2")
	assert_eq(ArenaSystem.remaining(), _wave_count(1))

# ── Full genomspelning ──────────────────────────────────────────────────────

func test_alla_vagor_klaras_och_ger_beloning():
	watch_signals(ArenaSystem)
	ArenaSystem.start()
	for i in range(_total_monsters()):
		ArenaSystem.record_kill("dummy")
	assert_signal_emitted(ArenaSystem, "arena_won")
	assert_false(ArenaSystem.is_active(), "arenan ska vara avslutad")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "Triumfklingan ska delas ut")

func test_unik_klinga_bara_forsta_segern_sedan_repeat_reward():
	# Första segern: unika klingan + champion-unlock.
	ArenaSystem.start()
	for _i in range(_total_monsters()):
		ArenaSystem.record_kill("dummy")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 1, "första segern ska ge klingan")
	assert_true(UnlockSystem.is_unlocked(ArenaSystem.CHAMPION_UNLOCK),
		"första segern ska sätta arena_champion-unlock")
	# Andra segern: ingen ny klinga, men omspelsbelöning (guld) delas ut.
	# (Guld är valuta → GameState.gold, inte inventory.)
	GameState.inventory.clear()
	var gold_before := GameState.gold
	ArenaSystem.reset()
	ArenaSystem.start()
	for _i in range(_total_monsters()):
		ArenaSystem.record_kill("dummy")
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 0, "omspel ska inte ge ny klinga")
	assert_gt(GameState.gold, gold_before, "omspel ska ge guld (repeat_reward)")

func test_kill_utan_aktiv_omgang_ignoreras():
	ArenaSystem.record_kill("dummy")  # ska inte krascha eller starta något
	assert_false(ArenaSystem.is_active())
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 0)

# ── Avbrott ───────────────────────────────────────────────────────────────────

func test_abort_avslutar_utan_beloning():
	watch_signals(ArenaSystem)
	ArenaSystem.start()
	ArenaSystem.record_kill("dummy")
	ArenaSystem.abort()
	assert_signal_emitted(ArenaSystem, "arena_failed")
	assert_false(ArenaSystem.is_active())
	assert_eq(int(GameState.inventory.get(REWARD_ID, 0)), 0, "avbrott ska inte ge belöning")

# ── Dialog-koppling ───────────────────────────────────────────────────────────

func test_dialog_action_startar_arenan():
	DialogueDB.run_actions([{"type": "start_arena"}], NPC_ID)
	assert_true(ArenaSystem.is_active(), "start_arena-action ska starta arenan")

func test_arena_active_villkor_speglar_tillstand():
	assert_false(DialogueDB.eval_condition({"type": "arena_active"}))
	ArenaSystem.start()
	assert_true(DialogueDB.eval_condition({"type": "arena_active"}))

func test_torben_har_start_och_status_val():
	assert_true(DialogueDB.nodes.has("arena_master_begin"), "arena_master_begin saknas")
	assert_true(DialogueDB.nodes.has("arena_master_status"), "arena_master_status saknas")
	# begin-noden ska bära start_arena-action någonstans
	var has_action := false
	for c in DialogueDB.nodes["arena_master_begin"].get("choices", []):
		for a in c.get("actions", []):
			if String(a.get("type", "")) == "start_arena":
				has_action = true
	assert_true(has_action, "arena_master_begin ska ha en start_arena-action")

# ── Givare ────────────────────────────────────────────────────────────────────

func test_torben_star_pa_gangbar_ruta_i_arenan():
	assert_true(DialogueDB.npcs.has(NPC_ID), "%s saknas" % NPC_ID)
	var nd: Dictionary = DialogueDB.npcs[NPC_ID]
	assert_eq(String(nd["zone"]), ArenaSystem.ARENA_ZONE)
	var pos: Array = nd["position"]
	var z = preload("res://world/zone.gd").new()
	z.build_from_data(_zone_data(ArenaSystem.ARENA_ZONE), ArenaSystem.ARENA_ZONE)
	assert_true(z.is_walkable(Vector2i(int(pos[0]), int(pos[1]))),
		"Torben står på en ogångbar ruta %s i arenan" % str(pos))
	z.free()
