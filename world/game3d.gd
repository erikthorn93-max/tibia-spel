extends Node3D
## Startscen för 3D-slicen (steg 4): laddar en zon som ZoneModel och visar den
## genom Zone3D + Player3D — exakt samma simlager som 2D-spelet. Kör scenen
## direkt (F6 på game3d.tscn) för att gå runt i zonen med piltangenter/WASD.
##
## Prestandaramar härifrån och framåt: ingen SSIL/dyra post-effekter,
## MultiMesh för terräng, ett delat material per batch-typ.

const START_ZONE := "thais_fields"

var model: ZoneModel
var zone_view: Zone3D
var player: Player3D

func _ready() -> void:
	var f := FileAccess.open("res://data/zones/%s.json" % START_ZONE, FileAccess.READ)
	model = ZoneModel.new()
	model.parse(JSON.parse_string(f.get_as_text()), START_ZONE)
	GameState.current_zone = START_ZONE

	zone_view = Zone3D.new()
	add_child(zone_view)
	zone_view.build(model)

	player = Player3D.new()
	add_child(player)
	player.sim.zone = model
	player.snap_to(model.player_start)

	_setup_camera()
	_setup_light()

## 3/4-kamera som barn av spelaren → följer med utan egen following-kod.
func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9.0, 6.0)
	cam.rotation_degrees.x = -56.0
	cam.fov = 45.0
	player.add_child(cam)
	cam.make_current()

func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
