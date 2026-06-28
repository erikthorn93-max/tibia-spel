class_name Weather
## Väder-hjälpare: rena funktioner (inga bieffekter) så de kan enhetstestas.
## Beskriver hur en vädertyp ska tonas, vilka partiklar den har och hur de rör
## sig. ui/weather_overlay.gd renderar utifrån dessa värden; zoner anger sin
## vädertyp via fältet "weather" i data/zones/<id>.json.

const CLEAR := "clear"
const RAIN  := "rain"
const FOG   := "fog"
const SNOW  := "snow"
const STORM := "storm"   # tätt regn + blixt & dunder (mörkare än vanligt regn)
const DYNAMIC := "dynamic"   # zon-värde: följ WeatherSystem.current (skiftar över tid)
## Vädertyper overlayn faktiskt ritar.
const TYPES := [CLEAR, RAIN, FOG, SNOW, STORM]
## Värden en zon får ange i sin JSON (inkl. "dynamic" som löses upp i körtid).
const ZONE_TYPES := [CLEAR, RAIN, FOG, SNOW, STORM, DYNAMIC]
## Tempererad pool som det dynamiska vädret pendlar mellan (klart→regn→åska).
const AMBIENT_POOL := [CLEAR, RAIN, STORM]

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
## Trappa: klart → regn → åska. Åska byggs alltid upp genom regn (aldrig direkt
## ur klart) och avtar tillbaka till regn. Mestadels uppehåll, enstaka skurar och
## sällsynta oväder.
static func next_ambient(current: String, roll: float) -> String:
	match current:
		RAIN:
			if roll < 0.55: return CLEAR    # klarnar oftast
			if roll < 0.85: return RAIN      # håller i sig
			return STORM                      # tilltar till oväder
		STORM:
			return RAIN if roll < 0.6 else STORM   # mojnar mot vanligt regn
		_:  # CLEAR
			return RAIN if roll < 0.35 else CLEAR

## True för väder som faller (regn/snö/åska) och alltså har rörliga partiklar.
static func has_precip(w: String) -> bool:
	return w == RAIN or w == SNOW or w == STORM

## Liten väderikon för HUD-klockan. Klart väder har ingen egen ikon (klockan
## visar redan sol/måne för dygnet) → "".
static func icon(w: String) -> String:
	match w:
		RAIN:  return "🌧"
		STORM: return "⛈"
		SNOW:  return "❄"
		FOG:   return "🌫"
		_:     return ""

## Heltäckande färgtvätt för vädret. Regn kyler & mörkar, dimma bleker &
## sänker kontrasten, snö ger en ljus sval slöja. "clear" → osynlig.
static func tint(w: String) -> Color:
	match w:
		RAIN:  return Color(0.20, 0.26, 0.34, 0.16)   # sval grå-blå mörkning
		STORM: return Color(0.10, 0.13, 0.22, 0.34)   # tung mörk skyfallston
		FOG:   return Color(0.62, 0.66, 0.70, 0.28)   # blek grå slöja
		SNOW:  return Color(0.80, 0.85, 0.92, 0.12)   # ljus sval dis
		_:     return Color(0, 0, 0, 0.0)

## Partikelfärg (regndroppe / snöflinga).
static func particle_color(w: String) -> Color:
	match w:
		RAIN:  return Color(0.62, 0.72, 0.92, 1.0)
		STORM: return Color(0.70, 0.78, 0.95, 1.0)
		SNOW:  return Color(0.95, 0.97, 1.0, 1.0)
		_:     return Color(1, 1, 1, 1)

## Partikelns opacitet vid ritning.
static func particle_alpha(w: String) -> float:
	match w:
		RAIN:  return 0.38
		STORM: return 0.52
		SNOW:  return 0.85
		_:     return 0.0

## Partikelhastighet i pixlar/sekund. Regn: snabbt, brant, lätt snett.
## Åska: ännu snabbare och mer vinddrivet. Snö: långsamt, mjukt sidledes
## (overlay-noden lägger på sin egen sicksack).
static func velocity(w: String) -> Vector2:
	match w:
		RAIN:  return Vector2(-70.0, 540.0)
		STORM: return Vector2(-160.0, 760.0)
		SNOW:  return Vector2(14.0, 72.0)
		_:     return Vector2.ZERO

## Längd på en regnstrimma (snö ritas som prick → 0; åska har längre strimmor).
static func streak_length(w: String) -> float:
	match w:
		RAIN:  return 13.0
		STORM: return 19.0
		_:     return 0.0

## Hur många partiklar ett område på `area` px² ska ha.
static func particle_count(w: String, area: float) -> int:
	match w:
		RAIN:  return int(area / 950.0)
		STORM: return int(area / 520.0)   # tätt skyfall
		SNOW:  return int(area / 2400.0)
		_:     return 0

# ── Blixt & dunder (åska) ────────────────────────────────────────────────────
# Rena funktioner: WeatherSystem schemalägger nedslagen och game_root lyser upp
# CanvasModulate enligt ljusstyrke-kurvan. Dundret kommer efter blixten (ljud
# färdas långsammare än ljus) → fördröjningen skalar med nedslagets "avstånd".

## En blixtcykels längd i sekunder (ljusstyrkan är 0 utanför [0, FLASH_DUR]).
const FLASH_DUR := 0.6
## Min/max sekunder mellan blixtnedslag under ett oväder.
const STRIKE_MIN := 3.5
const STRIKE_MAX := 12.0

## Sekunder till nästa blixt givet ett slumptal 0..1 (jämn spridning i intervallet).
static func next_strike_delay(roll: float) -> float:
	return lerpf(STRIKE_MIN, STRIKE_MAX, clampf(roll, 0.0, 1.0))

## Ljusstyrka 0..1 `t` sekunder efter ett nedslag: skarp blixt som klingar av,
## med ett svagare återsken (dubbelblixt) strax efter. 0 utanför blixtfönstret.
static func lightning_brightness(t: float) -> float:
	if t < 0.0 or t >= FLASH_DUR:
		return 0.0
	var main := exp(-9.0 * t)                       # initialt skarpt sken
	var reflash := 0.45 * exp(-16.0 * absf(t - 0.14))  # svagt återsken
	return clampf(maxf(main, reflash), 0.0, 1.0)

## Fördröjning (sekunder) från blixt till åskknall. `roll` 0..1 → nära/avlägset
## nedslag. Närgånget oväder ger nästan samtidig knall; avlägset ett par sekunder.
static func thunder_delay(roll: float) -> float:
	return lerpf(0.15, 2.5, clampf(roll, 0.0, 1.0))

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
