class_name Biome
## Biom-hjälpare: klassar en zon utifrån dess id och beskriver dess stämning —
## färggradering (en subtil heltäckande ton) och vilka ambient-partiklar som
## ger platsen liv (eldflugor, damm, glödflagor). Rena, testbara funktioner;
## ui/biome_grade och ui/ambient_overlay renderar utifrån dem.

const DEFAULT  := "default"
const TOWN     := "town"
const FOREST   := "forest"
const CAVE     := "cave"      # grottor, gruvor, kryptor, fängelser — svalt sten
const SWAMP    := "swamp"
const DESERT   := "desert"
const ICE      := "ice"
const VOLCANO  := "volcano"
const INTERIOR := "interior"  # gillen, värdshus, tempel — neutralt inomhus

## Klassar ett zon-id till ett biom. Substräng-matchning med tydlig företräde:
## de starkast tematiska biomen testas först.
static func classify(zone_id: String) -> String:
	var z := zone_id.to_lower()
	if z.begins_with("dungeon:"):
		return CAVE
	if "volcano" in z or "demon" in z or "rift" in z:
		return VOLCANO
	if "swamp" in z or "dimmoren" in z:
		return SWAMP
	if "ice" in z:
		return ICE
	if "desert" in z:
		return DESERT
	if "cave" in z or "mine" in z or "cavern" in z or "crypt" in z \
		or "maze" in z or "jail" in z:
		return CAVE
	if "guild" in z or "inn" in z or "temple" in z or "depot" in z:
		return INTERIOR
	if "forest" in z or "wilds" in z or "heights" in z or "fields" in z:
		return FOREST
	if "town" in z or "coast" in z or "castle" in z or "docks" in z:
		return TOWN
	return DEFAULT

## Subtil heltäckande färgton för biomet (alpha låg → bara en stämningsnyans,
## aldrig en filt). "default"/"town" → osynlig så vanlig mark förblir neutral.
static func grade(biome: String) -> Color:
	match biome:
		CAVE:     return Color(0.10, 0.13, 0.22, 0.22)   # svalt blågrått, instängt
		SWAMP:    return Color(0.16, 0.22, 0.12, 0.20)   # sjukligt grönt
		DESERT:   return Color(0.40, 0.30, 0.10, 0.16)   # torrt varmt bärnsten
		ICE:      return Color(0.55, 0.68, 0.80, 0.16)   # blekt iskallt cyan
		VOLCANO:  return Color(0.34, 0.08, 0.04, 0.22)   # glödande aska
		FOREST:   return Color(0.10, 0.18, 0.10, 0.10)   # mild lövgrön svalka
		INTERIOR: return Color(0.18, 0.14, 0.08, 0.14)   # dämpat fackelvarmt inomhus
		_:        return Color(0, 0, 0, 0.0)

## Vilken ambient-partikeltyp platsen har. Vissa biom är levande dygnet runt
## (grottdamm, glödflagor), andra bara nattetid (eldflugor ute).
## → "none" | "fireflies" | "dust" | "embers"
static func ambient_kind(biome: String, is_night: bool) -> String:
	match biome:
		VOLCANO: return "embers"
		CAVE:    return "dust"
		FOREST, SWAMP, TOWN:
			return "fireflies" if is_night else "none"
		_:
			return "none"

## Ambient-partikelfärg per typ.
static func ambient_color(kind: String) -> Color:
	match kind:
		"fireflies": return Color(0.85, 0.95, 0.45, 1.0)   # varmt gulgrönt sken
		"embers":    return Color(1.0, 0.55, 0.18, 1.0)    # orange glöd
		"dust":      return Color(0.70, 0.72, 0.78, 1.0)   # blekt grått stoft
		_:           return Color(1, 1, 1, 1)

## Drivhastighet (px/s) för ambient-partiklar. Eldflugor svävar nästan still,
## damm sjunker sakta, glödflagor stiger uppåt.
static func ambient_velocity(kind: String) -> Vector2:
	match kind:
		"fireflies": return Vector2(6.0, -4.0)
		"embers":    return Vector2(-8.0, -46.0)
		"dust":      return Vector2(4.0, 14.0)
		_:           return Vector2.ZERO

## Hur många ambient-partiklar ett område på `area` px² ska ha (gles → stämning,
## inte snöstorm).
static func ambient_count(kind: String, area: float) -> int:
	match kind:
		"fireflies": return int(area / 14000.0)
		"embers":    return int(area / 9000.0)
		"dust":      return int(area / 11000.0)
		_:           return 0

## Om partikeln "andas" (pulserande opacitet) — eldflugor blinkar, glöd pulserar.
static func ambient_twinkles(kind: String) -> bool:
	return kind == "fireflies" or kind == "embers"
