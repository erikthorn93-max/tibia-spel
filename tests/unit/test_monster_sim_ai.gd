extends GutTest
## 3D-steg 3: MonsterSim äger AI-tick och rörelse-intent — jakt, attack,
## stun och kollision testas nu helt headless mot en ZoneModel, utan noder.

var _zone: ZoneModel
var _sim: MonsterSim

func before_each() -> void:
	_zone = ZoneModel.new()
	var rows: Array = []
	for y in 10:
		rows.append("..........")
	_zone.parse({"name": "Testzon", "tiles": rows}, "test_ai")
	_sim = MonsterSim.new()
	_sim.hp = 50; _sim.max_hp = 50
	_sim.atk = 1
	_sim.speed = 4.0
	_sim.aggro_range = 5
	_sim.cooldown = 1.0
	_sim.place(Vector2i(5, 5), _zone)

# --- place / occupancy ---

func test_place_registrerar_tilen() -> void:
	assert_true(_zone.is_occupied(Vector2i(5, 5)), "place() ska occupera tilen")

# --- jakt ---

func test_jagar_spelaren_inom_aggro() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(2, 5))
	assert_eq(_sim.tile, Vector2i(4, 5), "ska ta ett steg mot spelaren")
	assert_signal_emitted(_sim, "moved")
	assert_eq(_sim.move_progress, 0.0, "nytt steg ska nolla move_progress")

func test_steg_flyttar_kollisionen() -> void:
	_sim.ai_tick(0.016, Vector2i(2, 5))
	assert_false(_zone.is_occupied(Vector2i(5, 5)), "gamla tilen ska frigöras")
	assert_true(_zone.is_occupied(Vector2i(4, 5)), "nya tilen ska occuperas")

func test_star_stilla_utanfor_aggro() -> void:
	watch_signals(_sim)
	_sim.aggro_range = 2
	_sim.ai_tick(0.016, Vector2i(0, 5))   # Chebyshev-avstånd 5 > 2
	assert_eq(_sim.tile, Vector2i(5, 5), "ska inte jaga utanför aggro_range")
	assert_signal_not_emitted(_sim, "moved")

func test_undviker_upptagen_tile() -> void:
	_zone.occupy(Vector2i(4, 5), RefCounted.new())   # annan enhet i vägen
	_sim.ai_tick(0.016, Vector2i(2, 5))
	assert_eq(_sim.tile, Vector2i(5, 5), "ska vänta när nästa tile är upptagen")

func test_move_progress_avancerar_med_speed() -> void:
	_sim.ai_tick(0.016, Vector2i(2, 5))              # påbörja steget
	_sim.ai_tick(0.1, Vector2i(2, 5))                # mitt i steget
	assert_almost_eq(_sim.move_progress, 0.4, 0.001, "0.1 s × speed 4.0 = 0.4")
	assert_eq(_sim.tile, Vector2i(4, 5), "inget nytt steg förrän det pågående är klart")

# --- attack ---

func test_attackerar_intill() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(5, 6))              # spelare på granntile
	assert_signal_emitted(_sim, "attack_started", "ska inleda attack intill spelaren")
	assert_signal_not_emitted(_sim, "moved", "ska inte flytta när den slår")

func test_attack_respekterar_cooldown() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(5, 6))              # attack 1 → cooldown satt
	_sim.ai_tick(0.016, Vector2i(5, 6))              # för tidigt för attack 2
	assert_signal_emit_count(_sim, "attack_started", 1, "cooldown ska hindra attack 2")

func test_attack_efter_cooldown() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(5, 6))              # attack 1
	_sim.ai_tick(1.1, Vector2i(5, 6))                # cooldown (1.0 s) har passerat
	assert_signal_emit_count(_sim, "attack_started", 2, "ska slå igen efter cooldown")

# --- stun & statusar ---

func test_stun_blockerar_attack_och_jakt() -> void:
	watch_signals(_sim)
	_sim.apply_status("stun", 5.0, 0.0)
	_sim.ai_tick(0.016, Vector2i(5, 6))
	_sim.ai_tick(0.016, Vector2i(2, 5))
	assert_signal_not_emitted(_sim, "attack_started", "bedövad ska inte slå")
	assert_signal_not_emitted(_sim, "moved", "bedövad ska inte jaga")

func test_statusar_tickar_utan_spelare() -> void:
	_sim.apply_status("burn", 8.0, 4.0)
	_sim.ai_tick(1.1, null)                          # ingen spelare i zonen
	assert_eq(_sim.hp, 46, "burn ska ticka även när AI:n står stilla")
