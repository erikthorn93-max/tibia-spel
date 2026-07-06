class_name GatherNode
extends Node2D
## 2D-vy för en gathering-nod. Logiken (krav, chansrull, skörd, laddningar)
## bor i GatherSim — den här noden ritar sprite/label, squash-tween, gnistor,
## flyttext och gråtoning, och äger respawn-timern. Bakåtkompatibel: def/
## charges/depleted/attempt() delegerar till simmen.

## Delas med simmen (en källa) — behålls här för gamla referenser.
const STORM_FISHING_BONUS := GatherSim.STORM_FISHING_BONUS

var sim := GatherSim.new()
var node_type: String:
	get: return sim.node_type
	set(v): sim.node_type = v
var def: Dictionary:
	get: return sim.def
	set(v): sim.def = v
var tile: Vector2i:
	get: return sim.tile
	set(v): sim.tile = v
var charges: int:
	get: return sim.charges
	set(v): sim.charges = v
var depleted: bool:
	get: return sim.depleted
	set(v): sim.depleted = v

@onready var _sprite: Sprite2D = $Sprite2D
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

static func success_chance(level: int, req_level: int) -> float:
	return GatherSim.success_chance(level, req_level)

static func weather_bonus(skill: String, weather: String) -> float:
	return GatherSim.weather_bonus(skill, weather)

func _init() -> void:
	sim.swung.connect(react)
	sim.harvested.connect(_on_harvested)
	sim.xp_only.connect(_on_xp_only)
	sim.depleted_now.connect(_on_depleted)
	sim.respawned.connect(_on_respawned)

func setup(type: String, t: Vector2i) -> void:
	if not sim.setup(type, t):
		push_error("GatherNode: okänd nodtyp '%s' — saknas i data/nodes.json" % type)
		queue_free()
		return
	position = Vector2(t) * 32 + Vector2(16, 16)
	name_lbl.text = String(def["label"])
	# Ladda Tibia-stil sprite för denna nodtyp
	var tex_path := "res://assets/sprites/nodes/%s.png" % type
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	else:
		# Fallback: färgad Polygon2D om sprite saknas
		var fb := Polygon2D.new()
		fb.polygon = PackedVector2Array([Vector2(0,-13), Vector2(12,0), Vector2(0,13), Vector2(-12,0)])
		fb.color = Color(String(def["color"]))
		add_child(fb)

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		World.player.set_gather_target(self)

func attempt() -> String:
	return sim.attempt(_current_weather())

## Bakåtkompatibel ingång (tester tvingar fram lyckade försök via den här).
func _on_success() -> void:
	sim.apply_success()

## Det upplösta vädret i nodens zon just nu (för väderbonusen).
func _current_weather() -> String:
	var z := World.current_zone
	if z != null and is_instance_valid(z) and "weather" in z:
		return Weather.resolve(z.weather, WeatherSystem.current)
	return Weather.CLEAR

## Visuell reaktion på en sving: noden squashar till, och vid lyckat
## försök sprutar en liten gnistskur i nodens färg.
func react(success: bool) -> void:
	if _sprite != null and _sprite.texture != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.18, 0.82), 0.06).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.13).set_ease(Tween.EASE_IN_OUT)
	if success:
		_spark()

func _spark() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.initial_velocity_min = 28.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Color(String(def.get("color", "#ffffff"))).lightened(0.3)
	add_child(p)
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

## Flytande "+N namn"/xp-text ovanför noden.
func _spawn_float(text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	var parent := get_parent() if get_parent() != null else self
	parent.add_child(ft)
	ft.global_position = global_position + Vector2(randf_range(-4, 4), -14)
	ft.setup(text, color, 12)

func _on_harvested(item_id: String, amount: int, storm: bool) -> void:
	var yname := String(ItemDB.items.get(item_id, {}).get("name", item_id))
	if storm:
		# Oväders-fångst: stormblå text med blixt markerar bonus-nappet.
		_spawn_float("+%d %s ⚡" % [amount, yname], Color(0.62, 0.80, 1.0))
	else:
		_spawn_float("+%d %s" % [amount, yname], Color(0.96, 0.94, 0.55))   # mjukt guld

func _on_xp_only(xp: int) -> void:
	_spawn_float("+%d xp" % xp, Color(0.6, 0.85, 1.0))   # ljusblå

func _on_depleted(respawn_seconds: float) -> void:
	modulate = Color(0.45, 0.45, 0.45)
	# Krymp ihop noden lite så uttömning syns tydligt
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(0.7, 0.7), 0.22).set_ease(Tween.EASE_OUT)
	if is_inside_tree():
		get_tree().create_timer(respawn_seconds).timeout.connect(sim.respawn)

func _on_respawned() -> void:
	modulate = Color.WHITE
	# Studsa tillbaka i full storlek när noden återhämtat sig
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
