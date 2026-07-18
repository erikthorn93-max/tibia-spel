class_name NpcWanderSim
extends RefCounted
## Strosarsim för dialog-NPC:er: korta kardinalsteg kring hemrutan med
## slumpad paus emellan — staden känns levande utan att NPC:erna springer
## ifrån spelaren. Ingen rendering, inga noder; 2D- och 3D-vyn tickar simmen
## och interpolerar positionen ur move_progress (samma idiom som MonsterSim).
##
## Reglerna: håller sig inom RADIUS från hemrutan, kliver aldrig på portaler/
## trappor/dörrar/nedgångar (förvirrande blockering av zonbyten), på upptagna
## rutor eller på spelarens ruta, och står stilla när spelaren är nära —
## samtal och klick ska inte behöva jaga sitt mål. Occupancy registreras i
## zonmodellen så monster och andra NPC:er inte kliver i samma ruta.

signal moved(from: Vector2i, to: Vector2i)   # steg påbörjat (move_progress 0→1)

const RADIUS := 2                  # max Chebyshev-avstånd från hemrutan
const PAUSE_MIN := 3.0             # s vila mellan steg (slumpat intervall)
const PAUSE_MAX := 8.0
const PLAYER_FREEZE_DIST := 3      # står stilla när spelaren är så här nära
const STEP_SPEED := 1.6            # tiles/s — lugn promenadtakt

var home := Vector2i.ZERO
var tile := Vector2i.ZERO
var zone: ZoneModel = null
var move_progress := 1.0           # 0..1; <1 = mitt i ett steg
var _pause := 0.0

## Placerar NPC:n och registrerar hemrutan i kollisionskartan.
func place(t: Vector2i, z: ZoneModel) -> void:
	home = t
	tile = t
	zone = z
	move_progress = 1.0
	_pause = randf_range(PAUSE_MIN, PAUSE_MAX)
	if zone != null:
		zone.occupy(tile, self)

## Frame-tick från vyn: pågående steg → avancera; annars vila, och när pausen
## löpt ut (och spelaren inte är i närheten) → försök ta ett strosarsteg.
func tick(delta: float, player_tile: Vector2i) -> void:
	if zone == null:
		return
	if move_progress < 1.0:
		move_progress = minf(move_progress + delta * STEP_SPEED, 1.0)
		return
	if maxi(absi(player_tile.x - tile.x), absi(player_tile.y - tile.y)) \
			<= PLAYER_FREEZE_DIST:
		return
	_pause -= delta
	if _pause > 0.0:
		return
	_pause = randf_range(PAUSE_MIN, PAUSE_MAX)
	try_step(player_tile)

## Ett steg till en slumpad fri kardinalgranne inom RADIUS från hemrutan.
## False om ingen kandidat fanns (instängd) — då fortsätter vilan.
func try_step(player_tile: Vector2i) -> bool:
	var dirs: Array = [Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		var n: Vector2i = tile + d
		if maxi(absi(n.x - home.x), absi(n.y - home.y)) > RADIUS:
			continue
		if not zone.is_walkable(n) or zone.is_occupied(n):
			continue
		if n == player_tile:
			continue
		if zone.portals.has(n) or zone.stair_points.has(n) \
				or zone.entrance_points.has(n) or zone.dungeon_entrances.has(n):
			continue
		zone.vacate(tile)
		zone.occupy(n, self)
		var from := tile
		tile = n
		move_progress = 0.0
		moved.emit(from, n)
		return true
	return false
