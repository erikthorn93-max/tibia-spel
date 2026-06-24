extends Node
## Autoload: WeatherSystem. Globalt omgivningsväder som långsamt skiftar mellan
## klart och regn. Zoner med "weather": "dynamic" följer detta; tematiska zoner
## (dimma/snö) har fast väder och berörs inte. Övergångsregeln ligger i
## ui/weather.gd (Weather.next_ambient) så den är testbar.

const Weather = preload("res://ui/weather.gd")

signal weather_changed(type: String)

## Aktuellt omgivningsväder ("clear" eller "rain").
var current := Weather.CLEAR

## Realsekunder mellan väderrullningar (~en skiftchans varannan minut).
const ROLL_INTERVAL := 120.0

var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_t += delta
	if _t < ROLL_INTERVAL:
		return
	_t = 0.0
	var nxt := Weather.next_ambient(current, _rng.randf())
	if nxt != current:
		current = nxt
		weather_changed.emit(current)
