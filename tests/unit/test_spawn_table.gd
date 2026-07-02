extends GutTest
## M10: Testar spawn_table-logiken — sedan 3D-migrationen steg 2 bor den i
## ZoneModel (RefCounted) och testas helt headless utan noder.

var _model: ZoneModel

func before_each() -> void:
	_model = ZoneModel.new()
	# Minimal _walkable och player_start utan att köra parse()
	_model.player_start = Vector2i(0, 0)

# Hjälpfunktion: fyll en enkel walkable-grid
func _setup_grid(size: int) -> void:
	for x in size:
		for y in size:
			_model._walkable[Vector2i(x, y)] = true

# --- _fill_spawn_table ---

func test_spawn_table_placerar_ratt_antal() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([{"monster": "Råtta", "count": 3, "respawn": 30.0}])
	assert_eq(_model.spawn_points.size(), 3, "ska spawna 3 råttor")

func test_spawn_table_respekterar_monster_namn() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([{"monster": "Skelett", "count": 2, "respawn": 40.0}])
	for sp in _model.spawn_points:
		assert_eq(String(sp["monster"]), "Skelett")

func test_spawn_table_respekterar_respawn_tid() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([{"monster": "Orm", "count": 1, "respawn": 55.0}])
	assert_almost_eq(float(_model.spawn_points[0]["respawn"]), 55.0, 0.01)

func test_spawn_table_undviker_player_start() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([{"monster": "Råtta", "count": 20, "respawn": 30.0}])
	for sp in _model.spawn_points:
		var t: Vector2i = sp["tile"]
		var dist := maxi(absi(t.x), absi(t.y))   # Chebyshev från (0,0)
		assert_gte(dist, 4, "monster ska spawnas minst 4 tiles från player_start")

func test_spawn_table_inga_duplikata_tiles() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([{"monster": "Spindel", "count": 8, "respawn": 30.0}])
	var tiles: Array = []
	for sp in _model.spawn_points:
		var t: Vector2i = sp["tile"]
		assert_false(tiles.has(t), "tile %s ska inte förekomma två gånger" % str(t))
		tiles.append(t)

func test_spawn_table_flera_monster_typer() -> void:
	_setup_grid(10)
	_model._fill_spawn_table([
		{"monster": "Råtta",   "count": 2, "respawn": 30.0},
		{"monster": "Skelett", "count": 2, "respawn": 40.0},
	])
	assert_eq(_model.spawn_points.size(), 4)
	var names: Array = _model.spawn_points.map(func(sp): return sp["monster"])
	assert_true(names.has("Råtta"))
	assert_true(names.has("Skelett"))

func test_spawn_table_over_max_tiles_ger_inte_error() -> void:
	# 6×6 grid med start (0,0): ~20 giltiga kandidat-tiles (Chebyshev ≥4)
	# Ber om 50 → ska inte krascha, fyller bara det som finns
	_setup_grid(6)
	_model._fill_spawn_table([{"monster": "Ghoul", "count": 50, "respawn": 30.0}])
	assert_gt(_model.spawn_points.size(), 0, "ska ha placerat åtminstone ett monster")
	assert_lte(_model.spawn_points.size(), 50, "kan inte ha fler monster än tillgängliga tiles")
