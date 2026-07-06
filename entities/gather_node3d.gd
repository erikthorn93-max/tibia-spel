class_name GatherNode3D
extends Node3D
## 3D-vy för gathering-noder ur zonens node-punkter. Samma GatherSim som
## 2D-vyn äger logiken; den här noden ritar kroppen (GLB per skill där en
## naturlig modell finns, annars platshållarlåda i nodens signaturfärg —
## samma regel som stationer/omappade monster), squash-tween vid sving,
## flyttext ur den delade poolen vid skörd och krympning vid uttömning.
## Klick routas av game3d till Player3D.set_gather_target (2 s-ticken och
## räckviddsregeln bor hos spelaren, precis som i 2D).

## GLB per skill — konservativ mappning (naturliga matchningar); resten får
## platshållarlåda. Modellerna är normaliserade till 1,0 m → "h" är världshöjd.
const SKILL_MODELS := {
	"mining":      {"file": "mossy_rock", "h": 0.7},
	"woodcutting": {"file": "fir_tree_short", "h": 1.7},
	"herbalism":   {"file": "wildflower", "h": 0.5},
	"farming":     {"file": "fern", "h": 0.45},
}
## Krympfaktor för en uttömd nod (2D:s gråtoning motsvaras av hopsjunkenhet).
const DEPLETED_SCALE := 0.55

var sim := GatherSim.new()
var fx: FloatingText3D = null   # delad flyttext-pool, sätts av game3d
var _visual: Node3D
var _label: Label3D
var _base_scale := Vector3.ONE   # GLB-modeller bär höjden i visual-skalan

var tile: Vector2i:
	get: return sim.tile
var def: Dictionary:
	get: return sim.def
var depleted: bool:
	get: return sim.depleted

func _init() -> void:
	sim.swung.connect(_on_swung)
	sim.harvested.connect(_on_harvested)
	sim.xp_only.connect(_on_xp_only)
	sim.depleted_now.connect(_on_depleted)
	sim.respawned.connect(_on_respawned)

func setup(type: String, t: Vector2i) -> void:
	if not sim.setup(type, t):
		push_error("GatherNode3D: okänd nodtyp '%s' — saknas i data/nodes.json" % type)
		queue_free()
		return
	position = Zone3D.tile_to_world3(t)
	_build_visual()

func display_name() -> String:
	return String(sim.def.get("label", sim.node_type))

## Försök från Player3D:s gather-tick — vädret läses ur zonmodellen.
func attempt() -> String:
	return sim.attempt(current_weather())

## Zonens upplösta väder (storm-fisket) ur ZoneModel — 3D-motsvarigheten
## till 2D-nodens World.current_zone.weather.
static func current_weather() -> String:
	var m: ZoneModel = World.zone_model
	if m != null:
		return Weather.resolve(m.weather, WeatherSystem.current)
	return Weather.CLEAR

# ── Visuellt ──────────────────────────────────────────────────────────────────
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var skill := String(sim.def.get("skill", ""))
	var m: Dictionary = SKILL_MODELS.get(skill, {})
	var path := ""
	if not m.is_empty():
		path = "res://assets/models3d/%s.glb" % String(m["file"])
	if path != "" and ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		_visual.add_child(inst)
		_base_scale = Vector3.ONE * float(m["h"])
	else:
		# Platshållare: låda i nodens signaturfärg (material skapas EN gång).
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.6, 0.7)
		body.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(String(sim.def.get("color", "#888888")))
		body.material_override = mat
		body.position.y = 0.3
		_visual.add_child(body)
	_visual.scale = _base_scale
	_label = Label3D.new()
	_label.text = display_name()
	_label.modulate = Color(0.92, 0.88, 0.72)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 9
	_label.pixel_size = 0.01
	_label.position.y = maxf(_base_scale.y, 0.6) + 0.4
	add_child(_label)

## Sving (träff eller miss): squash-tween — ingen allokering per försök.
func _on_swung(_success: bool) -> void:
	if _visual == null:
		return
	var squash := _base_scale * Vector3(1.15, 0.82, 1.15)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", squash, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", _base_scale, 0.13).set_ease(Tween.EASE_IN_OUT)

func _float_pos() -> Vector3:
	return position + Vector3(0, maxf(_base_scale.y, 0.6), 0)

func _on_harvested(item_id: String, amount: int, storm: bool) -> void:
	if fx == null:
		return
	var yname := String(ItemDB.items.get(item_id, {}).get("name", item_id))
	if storm:
		# Oväders-fångst: stormblå text med blixt markerar bonus-nappet.
		fx.show_text(_float_pos(), "+%d %s ⚡" % [amount, yname], Color(0.62, 0.80, 1.0))
	else:
		fx.show_text(_float_pos(), "+%d %s" % [amount, yname], Color(0.96, 0.94, 0.55))

func _on_xp_only(xp: int) -> void:
	if fx != null:
		fx.show_text(_float_pos(), "+%d xp" % xp, Color(0.6, 0.85, 1.0))

## Uttömd: sjunk ihop och gråna skylten; respawn-timern ägs av vyn.
func _on_depleted(respawn_seconds: float) -> void:
	if _visual != null:
		var tw := create_tween()
		tw.tween_property(_visual, "scale", _base_scale * DEPLETED_SCALE, 0.22) \
			.set_ease(Tween.EASE_OUT)
	if _label != null:
		_label.modulate = Color(0.5, 0.5, 0.5)
	if is_inside_tree():
		get_tree().create_timer(respawn_seconds).timeout.connect(sim.respawn)

func _on_respawned() -> void:
	if _visual != null:
		var tw := create_tween()
		tw.tween_property(_visual, "scale", _base_scale, 0.25).set_ease(Tween.EASE_OUT)
	if _label != null:
		_label.modulate = Color(0.92, 0.88, 0.72)
