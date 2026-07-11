class_name SimTicker
extends RefCounted
## Fast simuleringstick frikopplad från renderingen (3D-prestandakravet):
## vyerna renderar i skärmens takt medan simuleringen körs i fasta steg om
## SIM_DT. advance() samlar frame-tid och returnerar antal hela sim-steg att
## köra denna frame; alpha() är läget mellan förra och senaste steget (0..1)
## som vyerna interpolerar med — mjuk rörelse oavsett FPS, och GDScript-
## kostnaden för AI/strid följer tick-frekvensen i stället för bildfrekvensen.

const SIM_HZ := 20
const SIM_DT := 1.0 / SIM_HZ
## Tak per frame: efter en frusen frame (fönsterdrag, laddspik) droppas
## sim-skulden hellre än att jagas ikapp i en dödsspiral.
const MAX_STEPS := 5

var _acc := 0.0

func advance(delta: float) -> int:
	_acc += delta
	var steps := int(_acc / SIM_DT)
	if steps > MAX_STEPS:
		_acc = 0.0
		return MAX_STEPS
	_acc -= float(steps) * SIM_DT
	return steps

func alpha() -> float:
	return clampf(_acc / SIM_DT, 0.0, 1.0)
