extends Node
## Autoload: TimeOfDay. Spelstidens dag/natt-cykel.
##
## 20 minuters realtid = 1 speldag (24 speltimmar).
## Timme 06–21 = dag, timme 22–05 = natt.
## Sänder signal hour_changed(hour: int) vid varje ny spelstimme.

signal hour_changed(hour: int)

## Totalt antal sekunder per speldag (20 min × 60 s = 1200 s)
const DAY_LENGTH_SEC := 1200.0

## Starta dagen vid 08:00 (lite in på morgonen)
var _elapsed := DAY_LENGTH_SEC * (8.0 / 24.0)
var _last_hour := -1

## Aktuell spelstimme 0–23
var hour: int:
	get: return int((_elapsed / DAY_LENGTH_SEC) * 24.0) % 24

## True under timmarna 22, 23, 0–5
var is_night: bool:
	get: return hour >= 22 or hour <= 5

## Normaliserat tidsvärde 0.0–1.0 inom dagen (0.0 = midnatt, 0.5 = middag)
var day_fraction: float:
	get: return fmod(_elapsed / DAY_LENGTH_SEC, 1.0)

func _process(delta: float) -> void:
	_elapsed += delta
	var current_hour := hour
	if current_hour != _last_hour:
		_last_hour = current_hour
		hour_changed.emit(current_hour)
