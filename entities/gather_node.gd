class_name GatherNode
extends Node2D
## Generisk gathering-nod. Typdata från ItemDB.nodes (data/nodes.json).

const Weather = preload("res://ui/weather.gd")

## Hur mycket oväder höjer fångstchansen för fiske ("djupet rörs upp").
const STORM_FISHING_BONUS := 0.15

var node_type := ""
var def: Dictionary = {}
var tile := Vector2i.ZERO
var charges := 0
var depleted := false
var _storm_catch := false   # skedde senaste försök med oväders-bonus?

@onready var _sprite: Sprite2D = $Sprite2D
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

static func success_chance(level: int, req_level: int) -> float:
	return clampf(0.40 + 0.02 * float(level - req_level), 0.05, 0.90)

## Väderbonus till fångstchansen. Oväder rör upp djupet → fisket nappar bättre.
## Ren funktion (testbar): bara fiske under storm påverkas, annars 0.
static func weather_bonus(skill: String, weather: String) -> float:
	if skill == "fishing" and weather == Weather.STORM:
		return STORM_FISHING_BONUS
	return 0.0

func setup(type: String, t: Vector2i) -> void:
	node_type = type
	def = ItemDB.nodes.get(type, {})
	if def.is_empty():
		push_error("GatherNode: okänd nodtyp '%s' — saknas i data/nodes.json" % type)
		queue_free()
		return
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
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
	if depleted:
		return "depleted"
	var tool_id := String(def.get("tool", ""))
	if tool_id != "" and not GameState.has_tool(tool_id):
		return "no_tool"
	var skill := String(def["skill"])
	var lvl := GameState.effective_skill_level(skill)
	if lvl < int(def["level"]):
		return "low_level"
	var bonus := weather_bonus(skill, _current_weather())
	_storm_catch = bonus > 0.0
	var chance := clampf(success_chance(lvl, int(def["level"])) + bonus, 0.05, 0.95)
	var success := randf() <= chance
	react(success)
	if success:
		_on_success()
		return "ok"
	return "miss"

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
	var ft: Node2D = preload("res://entities/floating_text.gd").new()
	var parent := get_parent() if get_parent() != null else self
	parent.add_child(ft)
	ft.global_position = global_position + Vector2(randf_range(-4, 4), -14)
	ft.setup(text, color, 12)

func _on_success() -> void:
	# Konsumera verktyget om noden kräver det (t.ex. campfire_spot bränner loggar)
	if bool(def.get("consumes_tool", false)):
		var tool_id := String(def.get("tool", ""))
		if tool_id != "":
			GameState.remove_item(tool_id, 1)
	# no_yield: rena XP-noder (t.ex. agility-hinder ger bara erfarenhet).
	if not bool(def.get("no_yield", false)):
		var amt := 1
		if def.has("yield_min"):
			amt = randi_range(int(def["yield_min"]), int(def["yield_max"]))
		GameState.add_item(String(def["yields"]), amt)
		var yname := String(ItemDB.items.get(String(def["yields"]), {}).get("name", def["yields"]))
		if _storm_catch:
			# Oväders-fångst: stormblå text med blixt markerar bonus-nappet.
			_spawn_float("+%d %s ⚡" % [amt, yname], Color(0.62, 0.80, 1.0))
		else:
			_spawn_float("+%d %s" % [amt, yname], Color(0.96, 0.94, 0.55))   # mjukt guld
	else:
		_spawn_float("+%d xp" % int(def["xp"]), Color(0.6, 0.85, 1.0))   # ljusblå
	GameState.gain_skill_xp(String(def["skill"]), int(def["xp"]))
	charges -= 1
	if charges <= 0:
		_deplete()

func _deplete() -> void:
	depleted = true
	modulate = Color(0.45, 0.45, 0.45)
	# Krymp ihop noden lite så uttömning syns tydligt
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(0.7, 0.7), 0.22).set_ease(Tween.EASE_OUT)
	if is_inside_tree():
		get_tree().create_timer(float(def["respawn"])).timeout.connect(_respawn)

func _respawn() -> void:
	depleted = false
	modulate = Color.WHITE
	# Studsa tillbaka i full storlek när noden återhämtat sig
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
