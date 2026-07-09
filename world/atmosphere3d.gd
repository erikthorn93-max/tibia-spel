class_name Atmosphere3D
## Stämnings-hjälpare för 3D-slicen: dygnsstyrt solljus/himmel + biomdimma.
## 3D-motsvarigheten till ui/atmosphere.gd — rena funktioner (inga bieffekter)
## så de kan enhetstestas headless; game3d applicerar värdena på sin
## DirectionalLight3D och Environment. Bara billiga medel enligt prestanda-
## kraven: skalära ljus-/miljöparametrar och exponentiell djupdimma —
## ingen volymetrisk dimma, inga post-effekter.

## Solens energi vid middag resp. midnatt (natten behåller ett svagt
## "månsken" så spelet aldrig blir beckmörkt — samma tanke som 2D:s
## NIGHT_FLOOR i Atmosphere.canvas_tint).
const DAY_SUN := 1.2
const NIGHT_SUN := 0.14
const DAY_AMBIENT := 0.7
const NIGHT_AMBIENT := 0.22
const NIGHT_SKY := 0.06     # himlens energi vid midnatt (nästan släckt)

## Mörkerfaktor ur dygnsfraktionen: 1 vid midnatt (frac 0), 0 vid middag
## (frac 0.5) — samma kurva som 2D:s Atmosphere.
static func darkness(day_fraction: float) -> float:
	return (cos(day_fraction * TAU) + 1.0) * 0.5

## Skymningsfaktor: 1 vid soluppgång/solnedgång, 0 vid middag och midnatt.
static func twilight(day_fraction: float) -> float:
	return clampf(1.0 - absf(darkness(day_fraction) - 0.5) * 2.0, 0.0, 1.0)

static func sun_energy(day_fraction: float) -> float:
	return lerpf(DAY_SUN, NIGHT_SUN, darkness(day_fraction))

## Solens färg: neutral mitt på dagen, varmt gyllene i gryning/skymning,
## svalt blåblekt månsken på natten.
static func sun_color(day_fraction: float) -> Color:
	var d := darkness(day_fraction)
	var t := twilight(day_fraction)
	var day_col := Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.72, 0.45), t)
	return day_col.lerp(Color(0.55, 0.65, 0.92), d)

static func ambient_energy(day_fraction: float) -> float:
	return lerpf(DAY_AMBIENT, NIGHT_AMBIENT, darkness(day_fraction))

## Himlens energimultiplikator: full dager vid middag, nästan släckt vid
## midnatt (ambient följer himlen → natten blir genuint mörk, som 2D:s
## CanvasModulate-natt).
static func sky_energy(day_fraction: float) -> float:
	return lerpf(1.0, NIGHT_SKY, darkness(day_fraction))

## Biomdimma: {color, density} för tematiska biom, {} = ingen dimma.
## Träsket ligger i sjukligt grön dis, grottor i tätt mörker, vulkanlandet
## i rödbrun aska, isen i blekt frostdis och öknen i lätt hetta-dis.
## Densiteterna är låga — dimman är en stämningsnyans, aldrig en filt.
static func fog_for(biome: String) -> Dictionary:
	match biome:
		Biome.SWAMP:   return {"color": Color(0.45, 0.55, 0.40), "density": 0.035}
		Biome.CAVE:    return {"color": Color(0.10, 0.12, 0.18), "density": 0.05}
		Biome.VOLCANO: return {"color": Color(0.45, 0.25, 0.15), "density": 0.03}
		Biome.ICE:     return {"color": Color(0.75, 0.82, 0.90), "density": 0.025}
		Biome.DESERT:  return {"color": Color(0.80, 0.70, 0.50), "density": 0.012}
		_:             return {}

## Himmelstak per biom: grottor ser aldrig dagsljus — himlen hålls nersläckt
## oavsett klockslag. Övriga biom följer dygnet fullt ut.
static func sky_cap(biome: String) -> float:
	return 0.15 if biome == Biome.CAVE else 1.0

# ── Väderstämning (3D-motsvarigheten till Weather.tint-tvätten i 2D) ──────────

## Väderdimma: när väder pågår äger det stämningen och ersätter biomdimman —
## samma företrädesregel som 2D-overlayerna. Dimväder är tätast, snö en ljus
## slöja, regn/åska en sval mörkning.
const WEATHER_FOG := {
	Weather.FOG:   {"color": Color(0.62, 0.66, 0.70), "density": 0.065},
	Weather.SNOW:  {"color": Color(0.80, 0.85, 0.92), "density": 0.02},
	Weather.RAIN:  {"color": Color(0.30, 0.36, 0.44), "density": 0.015},
	Weather.STORM: {"color": Color(0.16, 0.20, 0.30), "density": 0.028},
}

## Ljusdämpning per väder (multipliceras in i sol/ambient/himmel): åskan är
## tung och mörk, regnet kyler, snö och dis bara dämpar lätt. Klart = 1.0.
const WEATHER_LIGHT := {
	Weather.RAIN: 0.75, Weather.STORM: 0.5,
	Weather.FOG: 0.8, Weather.SNOW: 0.9,
}

static func weather_fog(wx: String) -> Dictionary:
	return WEATHER_FOG.get(wx, {})

static func weather_light_scale(wx: String) -> float:
	return float(WEATHER_LIGHT.get(wx, 1.0))
