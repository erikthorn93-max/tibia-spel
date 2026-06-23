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
