class_name Weather
## Väder-hjälpare: rena funktioner (inga bieffekter) så de kan enhetstestas.
## Beskriver hur en vädertyp ska tonas, vilka partiklar den har och hur de rör
## sig. ui/weather_overlay.gd renderar utifrån dessa värden; zoner anger sin
## vädertyp via fältet "weather" i data/zones/<id>.json.

const CLEAR := "clear"
const RAIN  := "rain"
const FOG   := "fog"
const SNOW  := "snow"
const DYNAMIC := "dynamic"   # zon-värde: följ WeatherSystem.current (skiftar över tid)
## Vädertyper overlayn faktiskt ritar.
const TYPES := [CLEAR, RAIN, FOG, SNOW]
## Värden en zon får ange i sin JSON (inkl. "dynamic" som löses upp i körtid).
const ZONE_TYPES := [CLEAR, RAIN, FOG, SNOW, DYNAMIC]
## Tempererad pool som det dynamiska vädret pendlar mellan.
const AMBIENT_POOL := [CLEAR, RAIN]

## Säkrar att en sträng är en ritbar vädertyp — annars "clear".
static func normalize(w: String) -> String:
	return w if w in TYPES else CLEAR

## Säkrar att en sträng är ett giltigt zon-värde (tillåter "dynamic").
static func normalize_zone(w: String) -> String:
	return w if w in ZONE_TYPES else CLEAR

## Läser zonens vädertyp ur dess JSON-data (default "clear"; "dynamic" tillåts).
static func from_zone_data(data: Dictionary) -> String:
	return normalize_zone(String(data.get("weather", CLEAR)))

## Löser upp en zons deklarerade väder till en ritbar typ: "dynamic" → det
## globala omgivningsvädret, allt annat → sig självt.
static func resolve(zone_weather: String, ambient: String) -> String:
	if zone_weather == DYNAMIC:
		return normalize(ambient)
	return normalize(zone_weather)

## Ren övergångsregel för det dynamiska omgivningsvädret. `roll` är 0..1.
## Regn klarnar oftare än det börjar → mestadels uppehåll, enstaka skurar.
static func next_ambient(current: String, roll: float) -> String:
	if current == RAIN:
		return CLEAR if roll < 0.6 else RAIN
	return RAIN if roll < 0.35 else CLEAR

## True för väder som faller (regn/snö) och alltså har rörliga partiklar.
static func has_precip(w: String) -> bool:
	return w == RAIN or w == SNOW

## Heltäckande färgtvätt för vädret. Regn kyler & mörkar, dimma bleker &
## sänker kontrasten, snö ger en ljus sval slöja. "clear" → osynlig.
static func tint(w: String) -> Color:
	match w:
		RAIN: return Color(0.20, 0.26, 0.34, 0.16)   # sval grå-blå mörkning
		FOG:  return Color(0.62, 0.66, 0.70, 0.28)   # blek grå slöja
		SNOW: return Color(0.80, 0.85, 0.92, 0.12)   # ljus sval dis
		_:    return Color(0, 0, 0, 0.0)

## Partikelfärg (regndroppe / snöflinga).
static func particle_color(w: String) -> Color:
	match w:
		RAIN: return Color(0.62, 0.72, 0.92, 1.0)
		SNOW: return Color(0.95, 0.97, 1.0, 1.0)
		_:    return Color(1, 1, 1, 1)

## Partikelns opacitet vid ritning.
static func particle_alpha(w: String) -> float:
	match w:
		RAIN: return 0.38
		SNOW: return 0.85
		_:    return 0.0

## Partikelhastighet i pixlar/sekund. Regn: snabbt, brant, lätt snett.
## Snö: långsamt, mjukt sidledes (overlay-noden lägger på sin egen sicksack).
static func velocity(w: String) -> Vector2:
	match w:
		RAIN: return Vector2(-70.0, 540.0)
		SNOW: return Vector2(14.0, 72.0)
		_:    return Vector2.ZERO

## Längd på en regnstrimma (snö ritas som prick → 0).
static func streak_length(w: String) -> float:
	return 13.0 if w == RAIN else 0.0

## Hur många partiklar ett område på `area` px² ska ha.
static func particle_count(w: String, area: float) -> int:
	match w:
		RAIN: return int(area / 950.0)
		SNOW: return int(area / 2400.0)
		_:    return 0

## Flyttar tillbaka en partikel som lämnat skärmen så fältet ser oändligt ut.
## Faller den nedanför botten → upp igen ovanför toppen; driver den ut i sidan
## → in från motsatt kant.
static func wrap(pos: Vector2, width: float, height: float) -> Vector2:
	var p := pos
	if p.y > height + 4.0:
		p.y -= height + 20.0
	if p.x < -16.0:
		p.x += width + 32.0
	elif p.x > width + 16.0:
		p.x -= width + 32.0
	return p
