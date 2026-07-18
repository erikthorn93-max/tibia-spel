extends GutTest
## Avståndsattacker: monster med "ranged" i MonsterDB skjuter på håll med fri
## sikt (ranged_attack + attack_started), håller positionen i räckvidd och
## jagar när sikten är skymd. Siktlinjen (ZoneModel.has_line_of_sight) och
## ranged-datablocken vaktas här — allt headless, utan noder.

var _zone: ZoneModel
var _sim: MonsterSim

## 10×10 öppen mark med en vertikal mur på x=3 (öppning på y=8).
func _make_zone() -> ZoneModel:
	var z := ZoneModel.new()
	var rows: Array = []
	for y in 10:
		var row := "...W......"
		if y == 8:
			row = ".........."
		rows.append(row)
	z.parse({"name": "Testzon", "tiles": rows}, "test_ranged")
	return z

func before_each() -> void:
	_zone = _make_zone()
	_sim = MonsterSim.new()
	_sim.hp = 50; _sim.max_hp = 50
	_sim.atk = 1
	_sim.speed = 4.0
	_sim.aggro_range = 8
	_sim.attack_range = 4
	_sim.cooldown = 1.0
	_sim.place(Vector2i(5, 5), _zone)

# --- siktlinje (ZoneModel) ---

func test_los_oppen_rak_linje() -> void:
	assert_true(_zone.has_line_of_sight(Vector2i(5, 5), Vector2i(9, 5)),
		"fri sikt över öppen mark")

func test_los_oppen_diagonal() -> void:
	assert_true(_zone.has_line_of_sight(Vector2i(5, 2), Vector2i(9, 6)),
		"fri sikt diagonalt över öppen mark")

func test_los_blockeras_av_vagg() -> void:
	assert_false(_zone.has_line_of_sight(Vector2i(5, 5), Vector2i(1, 5)),
		"muren på x=3 ska blockera sikten")

func test_los_granntile_alltid_fri() -> void:
	assert_true(_zone.has_line_of_sight(Vector2i(5, 5), Vector2i(6, 5)),
		"granntile har inga mellanliggande tiles att blockera")

func test_los_vaggen_sjalv_blockerar_inte_som_andpunkt() -> void:
	assert_true(_zone.has_line_of_sight(Vector2i(4, 5), Vector2i(3, 5)),
		"ändpunkter prövas inte — bara mellanliggande tiles")

# --- ranged-AI ---

func test_skjuter_pa_hall_med_fri_sikt() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(9, 5))              # dist 4, fri sikt
	assert_signal_emitted(_sim, "ranged_attack", "ska avlossa avståndsskott")
	assert_signal_emitted(_sim, "attack_started", "skottet ska rulla träff som vanligt")
	assert_signal_not_emitted(_sim, "moved", "ska stå stilla när den skjuter")
	assert_eq(_sim.tile, Vector2i(5, 5), "skytten ska hålla positionen")

func test_haller_position_under_cooldown() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(9, 5))              # skott 1 → cooldown satt
	_sim.ai_tick(0.016, Vector2i(9, 5))              # för tidigt för skott 2
	assert_signal_emit_count(_sim, "ranged_attack", 1, "cooldown ska hindra skott 2")
	assert_signal_not_emitted(_sim, "moved", "ska vänta i räckvidd, inte jaga")

func test_skjuter_igen_efter_cooldown() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(9, 5))              # skott 1
	_sim.ai_tick(1.1, Vector2i(9, 5))                # cooldown (1.0 s) har passerat
	assert_signal_emit_count(_sim, "ranged_attack", 2, "ska skjuta igen efter cooldown")

func test_jagar_utom_rackvidd() -> void:
	watch_signals(_sim)
	_sim.place(Vector2i(9, 0), _zone)
	_sim.ai_tick(0.016, Vector2i(4, 8))              # dist 8 > attack_range 4
	assert_signal_not_emitted(_sim, "ranged_attack", "utom räckvidd: inget skott")
	assert_signal_emitted(_sim, "moved", "ska jaga tills målet är i räckvidd")

func test_jagar_nar_sikten_ar_skymd() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(1, 5))              # dist 4 men muren emellan
	assert_signal_not_emitted(_sim, "ranged_attack", "ska inte skjuta genom väggen")
	assert_signal_emitted(_sim, "moved", "ska flytta sig för fri sikt i stället")

func test_intill_avlossas_ingen_projektil() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(5, 6))              # granntile → reträtt
	assert_signal_not_emitted(_sim, "ranged_attack", "ingen projektil i närkontakt")

func test_stun_blockerar_avstandsskott() -> void:
	watch_signals(_sim)
	_sim.apply_status("stun", 5.0, 0.0)
	_sim.ai_tick(0.016, Vector2i(9, 5))
	assert_signal_not_emitted(_sim, "ranged_attack", "bedövad skytt ska inte skjuta")

# --- kiting (reträtt intill) ---

func test_skytt_backar_nar_spelaren_gar_intill() -> void:
	watch_signals(_sim)
	_sim.ai_tick(0.016, Vector2i(5, 6))              # spelare på granntile
	assert_signal_emitted(_sim, "moved", "skytten ska backa för fri skottlinje")
	assert_signal_not_emitted(_sim, "attack_started", "reträtt i stället för slag")
	var d := maxi(absi(_sim.tile.x - 5), absi(_sim.tile.y - 6))
	assert_gt(d, 1, "reträttsteget ska öka avståndet till spelaren")

func test_instangd_skytt_slar_narstrid() -> void:
	watch_signals(_sim)
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		_zone.occupy(Vector2i(5, 5) + d, RefCounted.new())   # alla flyktvägar tagna
	_sim.ai_tick(0.016, Vector2i(5, 6))
	assert_signal_not_emitted(_sim, "moved", "instängd skytt kan inte backa")
	assert_signal_emitted(_sim, "attack_started", "instängd skytt ska slå i närstrid")

func test_melee_monster_backar_inte() -> void:
	watch_signals(_sim)
	_sim.attack_range = 1
	_sim.ai_tick(0.016, Vector2i(5, 6))
	assert_signal_not_emitted(_sim, "moved", "närstridsmonster ska stå kvar och slå")
	assert_signal_emitted(_sim, "attack_started")

func test_melee_monster_opaverkat() -> void:
	watch_signals(_sim)
	_sim.attack_range = 1
	_sim.ai_tick(0.016, Vector2i(9, 5))              # dist 4
	assert_signal_not_emitted(_sim, "ranged_attack", "närstridsmonster skjuter aldrig")
	assert_signal_emitted(_sim, "moved", "närstridsmonster ska jaga som förut")

# --- data ---

func test_init_stats_laser_ranged_block() -> void:
	var s := MonsterSim.new()
	s.init_stats("Pirat Skytt")
	assert_eq(s.attack_range, 4, "Pirat Skytt ska läsa range 4 ur MonsterDB")

func test_init_stats_default_ar_narstrid() -> void:
	var s := MonsterSim.new()
	s.init_stats("Råtta")
	assert_eq(s.attack_range, 1, "monster utan ranged-block ska vara närstrid")

func test_ranged_datablock_ar_giltiga() -> void:
	var found := 0
	for mname in MonsterDB.monsters:
		var d: Dictionary = MonsterDB.monsters[mname]
		if not d.has("ranged"):
			continue
		found += 1
		var r: Dictionary = d["ranged"]
		var rng := int(r.get("range", 0))
		assert_between(rng, 2, 8, "%s: range ska vara 2..8" % mname)
		var col := String(r.get("color", ""))
		assert_true(Color.html_is_valid(col),
			"%s: ranged.color ska vara giltig hexfärg" % mname)
	assert_gt(found, 0, "minst ett monster ska ha ranged-block")

func test_skyttarna_har_ranged_block() -> void:
	for mname in ["Pirat Skytt", "Orkshamanen", "Nekromant", "Lich",
			"Dvärggeomant", "Avgrundsöga", "Mykonidäldste"]:
		assert_true(MonsterDB.monsters.get(mname, {}).has("ranged"),
			"%s ska ha ett ranged-block" % mname)

## Vakt mot den döda nyckeln "aggro": MonsterSim läser bara aggro_range —
## en post med "aggro" skulle tyst få default-värdet 5 (buggen fixad 2026-07-18).
func test_ingen_dod_aggro_nyckel() -> void:
	for mname in MonsterDB.monsters:
		var d: Dictionary = MonsterDB.monsters[mname]
		assert_false(d.has("aggro"),
			"%s: använd aggro_range, inte den döda nyckeln aggro" % mname)
