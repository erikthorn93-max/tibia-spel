class_name GatherNode
extends Node2D
## Generisk gathering-nod. Typdata från ItemDB.nodes (data/nodes.json).

var node_type := ""
var def: Dictionary = {}
var tile := Vector2i.ZERO
var charges := 0
var depleted := false

@onready var body: Polygon2D = $Body
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

static func success_chance(level: int, req_level: int) -> float:
	return clampf(0.40 + 0.02 * float(level - req_level), 0.05, 0.90)

func setup(type: String, t: Vector2i) -> void:
	node_type = type
	def = ItemDB.nodes[type]
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
	body.color = Color(String(def["color"]))
	name_lbl.text = String(def["label"])

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		World.player.set_gather_target(self)

func attempt() -> String:
	if depleted:
		return "depleted"
	var tool_id := String(def.get("tool", ""))
	if tool_id != "" and int(GameState.inventory.get(tool_id, 0)) < 1:
		return "no_tool"
	if GameState.effective_skill_level(String(def["skill"])) < int(def["level"]):
		return "low_level"
	if randf() <= success_chance(GameState.effective_skill_level(String(def["skill"])), int(def["level"])):
		_on_success()
		return "ok"
	return "miss"

func _on_success() -> void:
	# Konsumera verktyget om noden kräver det (t.ex. campfire_spot bränner loggar)
	if bool(def.get("consumes_tool", false)):
		var tool_id := String(def.get("tool", ""))
		if tool_id != "":
			GameState.remove_item(tool_id, 1)
	GameState.add_item(String(def["yields"]), 1)
	GameState.gain_skill_xp(String(def["skill"]), int(def["xp"]))
	charges -= 1
	if charges <= 0:
		_deplete()

func _deplete() -> void:
	depleted = true
	modulate = Color(0.45, 0.45, 0.45)
	if is_inside_tree():
		get_tree().create_timer(float(def["respawn"])).timeout.connect(_respawn)

func _respawn() -> void:
	depleted = false
	modulate = Color.WHITE
	charges = randi_range(int(def["charges"][0]), int(def["charges"][1]))
