extends Node
## Autoload: Ambience. En kontinuerlig, procedurell ljudbädd som ger platser och
## väder en ljudmässig stämning — regnsus, vindsus, grottrummel. Egen
## AudioStreamGenerator (skild från Sfx) så bädden kan ligga och spela utan att
## krocka med korta ljudeffekter. Brus formas av ett enkelt lågpassfilter:
## låg cutoff → mörkt rummel, hög → ljust sus.
##
## Volymerna är medvetet lågt satta — bädden ska anas, inte dominera.
## Profil-logiken (profile) är ren och testbar; själva bruset är slump.

const Weather = preload("res://ui/weather.gd")
const Biome = preload("res://ui/biome.gd")

const MIX_RATE := 22050.0
const RAMP := 0.6   # hur snabbt gain glider mot målet (per sekund)

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _lp := 0.0          # lågpassfiltrets tillstånd
var _gain := 0.0        # nuvarande (utjämnade) volym
var _swell := 0.0       # långsam vindsvällning

## Ren funktion: målprofil {gain, cutoff} för en upplöst vädertyp + biom.
## Väder väger tyngst (regn hörs överallt); annars ger biomet rums-ton.
static func profile(weather: String, biome: String) -> Dictionary:
	match weather:
		Weather.RAIN: return {"gain": 0.12, "cutoff": 0.45}   # ljust regnsus
		Weather.SNOW: return {"gain": 0.06, "cutoff": 0.16}   # tunn vind
		Weather.FOG:  return {"gain": 0.05, "cutoff": 0.10}   # dov dis-vind
	match biome:
		Biome.CAVE:    return {"gain": 0.05, "cutoff": 0.05}  # lågt grottrummel
		Biome.VOLCANO: return {"gain": 0.07, "cutoff": 0.04}  # djupt mullrande
		Biome.ICE:     return {"gain": 0.06, "cutoff": 0.18}  # kall vind
		_:             return {"gain": 0.0,  "cutoff": 0.2}   # tyst utomhus i klart väder

func _ready() -> void:
	_rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.3
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)

func _process(delta: float) -> void:
	var prof := _current_profile()
	# Glid mjukt mot målvolymen (inga abrupta hopp vid zon-/väderbyte).
	_gain = move_toward(_gain, float(prof["gain"]), RAMP * delta)
	_swell += delta

	if _gain <= 0.001 and float(prof["gain"]) <= 0.001:
		return
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	if _playback == null:
		return   # ljud ej tillgängligt (headless dummy-driver)

	var cutoff := float(prof["cutoff"])
	var n := _playback.get_frames_available()
	# Långsam svällning ±15 % gör vinden levande istället för platt brus.
	var swell_gain := _gain * (0.85 + 0.15 * sin(_swell * 0.5))
	for i in n:
		var white := _rng.randf() * 2.0 - 1.0
		_lp += cutoff * (white - _lp)         # enpols-lågpass
		var s := _lp * swell_gain
		_playback.push_frame(Vector2(s, s))

## Upplöser aktuell zons väder + biom till en ljudprofil.
func _current_profile() -> Dictionary:
	var zone := World.current_zone
	if zone == null or not is_instance_valid(zone) or not ("zone_id" in zone):
		return {"gain": 0.0, "cutoff": 0.2}
	var wx := Weather.CLEAR
	if "weather" in zone:
		wx = Weather.resolve(zone.weather, WeatherSystem.current)
	return profile(wx, Biome.classify(zone.zone_id))
