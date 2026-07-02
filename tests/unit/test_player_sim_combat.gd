extends GutTest
## 3D-steg 3: PlayerSim äger auto-attack och kraftslag mot MonsterSim-mål —
## räckvidd, cooldown, döda mål och spec-grindarna testas headless utan noder.

var _sim: PlayerSim
var _target: MonsterSim

func before_each() -> void:
	_sim = PlayerSim.new()
	_sim.tile = Vector2i(5, 5)
	GameState.equipped_weapon = ""       # obeväpnad → närstrid, range 1
	_target = MonsterSim.new()
	_target.hp = 100000; _target.max_hp = 100000   # dör inte av testslag
	_target.tile = Vector2i(5, 6)                  # intill spelaren
	_sim.target = _target

# --- auto-attack ---

func test_attack_svingar_intill() -> void:
	watch_signals(_sim)
	_sim.attack_tick(0.016)
	assert_signal_emitted(_sim, "attack_swung", "ska svinga mot mål intill (träff eller miss)")

func test_attack_vander_sig_mot_malet() -> void:
	_sim.attack_tick(0.016)
	assert_eq(_sim.facing, Vector2i.DOWN, "ska vända sig mot målet söderut")

func test_cooldown_hindrar_dubbelsving() -> void:
	watch_signals(_sim)
	_sim.attack_tick(0.016)
	_sim.attack_tick(0.016)   # direkt igen — cooldown aktiv
	assert_signal_emit_count(_sim, "attack_swung", 1, "cooldown ska hindra sving 2")

func test_sving_igen_efter_cooldown() -> void:
	watch_signals(_sim)
	_sim.attack_tick(0.016)
	_sim.attack_tick(1.5)     # mer än ATTACK_COOLDOWN har passerat
	assert_signal_emit_count(_sim, "attack_swung", 2, "ska svinga igen efter cooldown")

func test_utom_rackvidd_svingar_inte() -> void:
	watch_signals(_sim)
	_target.tile = Vector2i(5, 9)   # avstånd 4 > räckvidd 1
	_sim.attack_tick(0.016)
	assert_signal_not_emitted(_sim, "attack_swung", "utom räckvidd → ingen sving")

func test_dott_mal_ignoreras() -> void:
	watch_signals(_sim)
	_target.dead = true
	_sim.attack_tick(0.016)
	assert_signal_not_emitted(_sim, "attack_swung", "dött mål ska inte attackeras")

func test_utan_mal_kraschar_inte() -> void:
	_sim.target = null
	_sim.attack_tick(0.016)
	pass_test("attack_tick utan mål ska vara en no-op")

# --- kraftslag ---

func test_kraftslag_utan_mal_meddelar() -> void:
	watch_signals(_sim)
	_sim.target = null
	_sim.try_special()
	assert_signal_emitted(_sim, "message", "utan mål ska ett meddelande skickas")
	assert_signal_not_emitted(_sim, "spec_released")

func test_kraftslag_utom_rackhall_meddelar() -> void:
	watch_signals(_sim)
	_target.tile = Vector2i(5, 9)
	_sim.try_special()
	assert_signal_emitted(_sim, "message")
	assert_signal_not_emitted(_sim, "spec_released")

func test_kraftslag_utan_laddning_nekas() -> void:
	watch_signals(_sim)
	GameState.spec_energy = 0.0     # mätaren tom
	_sim.try_special()
	assert_signal_emitted(_sim, "spec_denied", "tom mätare ska neka kraftslaget")
	assert_signal_not_emitted(_sim, "spec_released")

func test_kraftslag_med_full_laddning_utloses() -> void:
	watch_signals(_sim)
	GameState.spec_energy = 100.0   # full mätare
	_sim.try_special([_target])
	assert_signal_emitted(_sim, "spec_released", "full mätare ska utlösa kraftslaget")
	assert_signal_emitted(_sim, "spec_flash", "nedslaget ska blixtra på målets tile")
	assert_lt(_target.hp, 100000, "kraftslaget ska göra skada (garanterad träff)")
	assert_eq(GameState.spec_energy, 0.0, "mätaren ska tömmas")