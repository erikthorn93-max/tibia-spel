extends GutTest
## Testar den procedurella ljudsyntesen (ren matematik, ingen uppspelning).

const Sfx = preload("res://autoload/sfx.gd")

func test_synth_length_matches_notes():
	# Två toner à 0.1 s i stereo → 2 * (0.1 * mix_rate) frames.
	var buf: PackedVector2Array = Sfx.synth([440.0, 880.0], 0.1)
	var per := int(0.1 * Sfx.MIX_RATE)
	assert_eq(buf.size(), per * 2)

func test_synth_values_in_range_and_nonzero():
	var buf: PackedVector2Array = Sfx.synth([440.0], 0.05)
	var maxv := 0.0
	var out_of_range := false
	for fr in buf:
		if fr.x < -1.0 or fr.x > 1.0:
			out_of_range = true
		maxv = maxf(maxv, absf(fr.x))
	assert_false(out_of_range, "alla sampel ska ligga inom [-1, 1]")
	assert_gt(maxv, 0.0, "vågformen ska inte vara helt tyst")

func test_synth_envelope_decays():
	# Envelopen klingar av: första toppen ska vara starkare än slutet.
	var buf: PackedVector2Array = Sfx.synth([440.0], 0.1)
	var head := 0.0
	var tail := 0.0
	var n := buf.size()
	for i in range(n):
		var a := absf(buf[i].x)
		if i < n / 10:
			head = maxf(head, a)
		elif i > n - n / 10:
			tail = maxf(tail, a)
	assert_gt(head, tail, "starten ska vara ljudligare än slutet (avklingning)")

func test_empty_freqs_gives_empty_buffer():
	var buf: PackedVector2Array = Sfx.synth([], 0.1)
	assert_eq(buf.size(), 0)

func test_sound_methods_callable_without_error():
	# Instansiera autoloaden och spela varje ljud — får inte krascha (headless).
	var sfx = add_child_autofree(Sfx.new())
	sfx.level_up()
	sfx.skill_up()
	sfx.quest_done()
	sfx.unlock()
	sfx.denied()
	for ctype in ["heal", "support", "conjure", "attack", ""]:
		sfx.cast(ctype)
	sfx.hit()
	sfx.shot()
	sfx.monster_die()
	sfx.player_hurt()
	sfx.player_died()
	sfx.thunder()
	pass_test("alla ljudmetoder gick att anropa")

func test_thunder_is_low_and_in_range():
	# Åskan ska vara en icke-tom vågform inom [-1, 1] och deterministisk per seed.
	var a: PackedVector2Array = Sfx.synth_thunder(42)
	var b: PackedVector2Array = Sfx.synth_thunder(42)
	assert_gt(a.size(), 0, "åska ska ge ljud")
	assert_eq(a.size(), b.size(), "samma seed → samma längd")
	var out_of_range := false
	var maxv := 0.0
	for fr in a:
		if fr.x < -1.0 or fr.x > 1.0:
			out_of_range = true
		maxv = maxf(maxv, absf(fr.x))
	assert_false(out_of_range, "alla sampel ska ligga inom [-1, 1]")
	assert_gt(maxv, 0.0, "åskan ska inte vara tyst")

func test_thunder_seed_varies_waveform():
	var a: PackedVector2Array = Sfx.synth_thunder(1)
	var b: PackedVector2Array = Sfx.synth_thunder(2)
	assert_true(a != b, "olika seed → olika muller")

func test_hit_is_throttled():
	# Två träffar tätt inpå varandra ska inte båda passera throttlen.
	var sfx = add_child_autofree(Sfx.new())
	sfx._last_hit_ms = 0
	sfx.hit()
	var after_first: int = sfx._last_hit_ms
	sfx.hit()                      # direkt igen → ska throttlas (samma tidsstämpel)
	assert_eq(int(sfx._last_hit_ms), after_first, "tät andra-träff ska ignoreras av throttlen")

func test_shot_is_throttled():
	# Två skott tätt inpå varandra ska inte båda passera throttlen.
	var sfx = add_child_autofree(Sfx.new())
	sfx._last_shot_ms = 0
	sfx.shot()
	var after_first: int = sfx._last_shot_ms
	sfx.shot()                     # direkt igen → ska throttlas
	assert_eq(int(sfx._last_shot_ms), after_first, "tätt andra-skott ska ignoreras av throttlen")

func test_cast_and_denied_produce_audio():
	# Cast- och denial-vågformerna ska vara icke-tomma.
	assert_gt(Sfx.synth([523.25, 659.25, 880.0], 0.10, 0.20).size(), 0, "heal-cast ska ge ljud")
	assert_gt(Sfx.synth([349.23, 261.63, 196.0], 0.07, 0.20).size(), 0, "denied ska ge ljud")
