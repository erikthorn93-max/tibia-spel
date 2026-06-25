extends Node
## Procedurellt genererade ljudeffekter — inga ljudfiler behövs.
## Syntar korta sinustoner med exponentiellt avklingande envelope och spelar
## dem via en AudioStreamGenerator. Används för level-up-fanfar, skill-up-blip
## m.m. Bufferten pumpas i _process så långa jinglar inte överfyller generatorn.

const MIX_RATE := 44100.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _queue: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.5
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)

func _process(_dt: float) -> void:
	if _queue.is_empty() or _playback == null:
		return
	var n := mini(_playback.get_frames_available(), _queue.size())
	if n <= 0:
		return
	_playback.push_buffer(_queue.slice(0, n))
	_queue = _queue.slice(n)

## Syntar en sekvens av toner (Hz) till en stereo-buffer med avklingande envelope.
## Statisk och bieffektsfri så den kan enhetstestas utan ljuduppspelning.
static func synth(freqs: Array, note_dur: float, vol := 0.3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var per := int(note_dur * MIX_RATE)
	if per <= 0:
		return out
	for f in freqs:
		var freq := float(f)
		for i in range(per):
			var t := float(i) / MIX_RATE
			var env: float = exp(-5.0 * (float(i) / float(per)))   # mjuk avklingning
			var s: float = sin(TAU * freq * t) * env * vol
			out.append(Vector2(s, s))
	return out

func _enqueue(buf: PackedVector2Array) -> void:
	if buf.is_empty():
		return
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	if _playback == null:
		return   # ljud ej tillgängligt (t.ex. headless dummy-driver)
	_queue.append_array(buf)

## Stigande dur-arpeggio (C-E-G-C) — klassiskt "level up!".
func level_up() -> void:
	_enqueue(synth([523.25, 659.25, 783.99, 1046.50], 0.12))

## Kort tvåtons-blip (E-H) för skill-uppgång.
func skill_up() -> void:
	_enqueue(synth([659.25, 987.77], 0.08, 0.22))

## Längre triumferande fanfar (G-C-E-G-C) för avklarad quest.
func quest_done() -> void:
	_enqueue(synth([392.0, 523.25, 659.25, 783.99, 1046.50], 0.14))

## Stigande kvint (C-G) — "något har öppnats".
func unlock() -> void:
	_enqueue(synth([523.25, 783.99], 0.13, 0.25))

## Dovt kort "hack/tick" för gathering-svingar (gruv/hugg/fiske m.m.).
func gather() -> void:
	_enqueue(synth([196.0], 0.05, 0.12))

## Kort positiv ding (D-A) för avklarat hantverk.
func craft() -> void:
	_enqueue(synth([587.33, 880.0], 0.09, 0.18))

## Mjukt "plopp" (A-D) vid upplockning av loot.
func pickup() -> void:
	_enqueue(synth([880.0, 1174.66], 0.05, 0.15))

## Varm, vilsam nedåtgående klang (G-E-C) — utvilad på värdshuset.
func rest() -> void:
	_enqueue(synth([783.99, 659.25, 523.25], 0.16, 0.2))

## Magi-cast — klangfärgen varierar efter besvärjelsetyp.
func cast(ctype: String) -> void:
	match ctype:
		"heal":
			_enqueue(synth([523.25, 659.25, 880.0], 0.10, 0.20))      # mjuk stigande dur
		"support":
			_enqueue(synth([659.25, 880.0, 1108.73], 0.09, 0.18))     # skimrande uppåt
		"conjure":
			_enqueue(synth([440.0, 587.33, 784.0], 0.11, 0.18))       # mystisk treklang
		_:
			_enqueue(synth([1318.51, 880.0], 0.06, 0.22))             # vasst attack-"pew"

## Nekande "wah" nedåt när en cast blockeras (mana/cooldown/krav saknas).
func denied() -> void:
	_enqueue(synth([349.23, 261.63, 196.0], 0.07, 0.20))

var _last_hit_ms := 0

## Kort vasst "thwack" när ett monster tar skada. Throttlad så AoE som träffar
## många monster på samma frame ger ett ljud, inte en kakofoni.
func hit() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < 45:
		return
	_last_hit_ms = now
	_enqueue(synth([261.63, 130.81], 0.035, 0.16))

## Skarp ljus uppåt-figur vid kritisk träff.
func crit() -> void:
	_enqueue(synth([523.25, 783.99], 0.04, 0.22))

## Charm-träff — klangfärgen varierar efter element så den känns "magisk".
func charm(element: String) -> void:
	match element:
		"fire":   _enqueue(synth([880.0, 587.33], 0.05, 0.20))      # fräsande nedåt
		"energy": _enqueue(synth([1318.51, 1760.0], 0.04, 0.20))    # vasst zap uppåt
		"death":  _enqueue(synth([207.65, 155.56], 0.07, 0.22))     # dov mörk klang
		_:        _enqueue(synth([659.25, 987.77], 0.045, 0.18))    # neutral ljus glimt

## Mjukt metalliskt "ting" när en defensiv charm parerar/undviker ett slag.
func charm_block() -> void:
	_enqueue(synth([1244.51, 1661.22], 0.05, 0.18))

## Nedåtgående "besegrad"-figur när ett monster dör.
func monster_die() -> void:
	_enqueue(synth([329.63, 261.63, 174.61], 0.08, 0.20))

## Dovt lågt "ugh" när spelaren tar skada (lägre & strävare än monster-hit).
func player_hurt() -> void:
	_enqueue(synth([155.56, 116.54], 0.05, 0.22))

## Sorgsen lång nedåtfigur vid spelarens död.
func player_died() -> void:
	_enqueue(synth([220.0, 174.61, 130.81, 98.0], 0.18, 0.25))
