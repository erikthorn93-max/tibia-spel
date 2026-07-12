class_name Station3D
extends Node3D
## 3D-vy för hantverksstationer (städ/gryta/alkemibord/runaltare/bänkar/
## bönaltare) ur zonens station-punkter. Klick intill (1 ruta — samma
## räckviddsregel som 2D:s CraftingStation) → receptpanelen för stationstypen;
## bönaltaret öppnar prayer-panelen. Varje typ har en procedural GLB-modell
## (assets/models3d/station_*.glb, byggd av tools/build_station_models.py,
## världsskala med fötterna på y=0); saknas filen faller vyn tillbaka till
## den färgade platshållarlådan, samma regel som omappade monster.

## Etiketterna delas med 2D-vyn (crafting_station.gd) — en källa.
const LABELS := CraftingStation.LABELS
const COLORS := {
	"anvil": "#5a5a62", "stove": "#8a4a2a", "alchemy_table": "#4a7a5a",
	"rune_altar": "#6a4a8a", "crafting_bench": "#8a6a3a",
	"prayer_altar": "#d4b84a", "workbench": "#7a5a2a",
}

var station_type := ""
var tile := Vector2i.ZERO

func setup(type: String, t: Vector2i) -> void:
	station_type = type
	tile = t
	position = Zone3D.tile_to_world3(t)
	_build_visual()

func display_name() -> String:
	return String(LABELS.get(station_type, station_type))

## Klick från game3d — samma regler som 2D:s _on_click (1 rutas räckvidd).
func interact() -> void:
	if World.hud == null:
		return
	var pdist := maxi(absi(GameState.player_tile.x - tile.x),
		absi(GameState.player_tile.y - tile.y))
	if pdist > 1:
		World.hud.show_message("Gå närmare %s." % display_name())
		return
	if station_type == "prayer_altar":
		World.hud.open_prayer_altar()
	else:
		World.hud.open_recipes(station_type)

func _build_visual() -> void:
	var path := "res://assets/models3d/station_%s.glb" % station_type
	if ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		add_child(inst)
	else:
		# Platshållarlåda i stationens signaturfärg (som innan GLB-steget).
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.7, 0.8)
		body.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(String(COLORS.get(station_type, "#888888")))
		body.material_override = mat
		body.position.y = 0.35
		add_child(body)
	var l := Label3D.new()
	l.text = display_name()
	l.modulate = Color(0.92, 0.88, 0.72)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 36
	l.outline_size = 10
	l.pixel_size = 0.01
	l.position.y = 1.05
	add_child(l)
