class_name CharacterMotion3D
extends RefCounted
## Procedurellt karaktärsliv i 3D — samma idiom som 2D:s CharacterVisual:
## gång-studs under ett steg, subtil idle-andning i vila. GLB-modellerna är
## origiggade rekvisita, så livet är rena transformkurvor (headless-testbara)
## som vyerna applicerar per frame utan allokering.

const BOB_AMP := 0.07        # studs-höjd i meter mitt i ett steg
const BREATH_AMP := 0.02     # andnings-amplitud (skala kring 1.0)
const BREATH_SPEED := 2.2    # rad/s — samma takt som 2D:s CharacterVisual

## Vertikal studs (meter, positiv = uppåt) vid stegprogress 0..1. Topp mitt i
## steget, noll vid båda tile-gränserna (kontinuerlig över carry-over-steg).
static func walk_bob(progress: float) -> float:
	return BOB_AMP * sin(clampf(progress, 0.0, 1.0) * PI)

## Subtil andnings-skala kring 1.0 över tid (sekunder).
static func breath_scale(time: float) -> float:
	return 1.0 + BREATH_AMP * sin(time * BREATH_SPEED)
