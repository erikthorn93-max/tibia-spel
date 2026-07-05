class_name Npc3D
extends Node3D
## 3D-vy för NPC:er i slicen: dialog-NPC:er (DialogueDB) och service-NPC:er
## (handlare/bankir/taskmästare/magiker från zonens legend-punkter). Klick
## intill → rätt HUD-panel via World.hud (Hud3D), samma räckviddsregler som
## 2D-entiteterna (dialog 2 rutor, service 1). Quest-markör (!/?) över
## dialog-NPC:er, uppdaterad via QuestSystem-signalerna.

## Civila GLB-modeller (assets/models3d, 1,0 m höga) + världshöjd i meter.
const MODEL_HEIGHTS := {
	"middle_aged_man": 1.7, "young_woman": 1.65, "boy": 1.2, "king": 1.75,
}
const CIVILIAN_MODELS := ["middle_aged_man", "young_woman", "boy"]
## NPC:er med given gestalt; övriga får deterministisk civilmodell per id.
const SPECIAL_MODELS := {"npc_tibianus": "king"}
## Service-NPC:ernas gestalt + visningsnamn.
const KIND_MODELS := {
	"shop": "middle_aged_man", "bank": "young_woman",
	"taskmaster": "middle_aged_man", "spell_teacher": "young_woman",
}
const KIND_NAMES := {
	"shop": "Handlaren", "bank": "Bankiren",
	"taskmaster": "Taskmästaren", "spell_teacher": "Magikern",
}

var kind := ""       # "dialogue" | "shop" | "bank" | "taskmaster" | "spell_teacher"
var npc_id := ""
var tile := Vector2i.ZERO

var _quest_marker: Label3D
var _model_h := 1.7

func setup(k: String, t: Vector2i, id := "") -> void:
	kind = k
	tile = t
	npc_id = id
	position = Zone3D.tile_to_world3(t)
	_build_visual()
	_build_name_label()
	if kind == "dialogue":
		_build_quest_marker()
		QuestSystem.quest_started.connect(_on_quest_state_changed)
		QuestSystem.step_advanced.connect(_on_quest_state_changed)
		QuestSystem.quest_completed.connect(_on_quest_state_changed)
		_refresh_quest_marker()

func display_name() -> String:
	if kind == "dialogue":
		return String(DialogueDB.npcs.get(npc_id, {}).get("name", npc_id))
	return String(KIND_NAMES.get(kind, "NPC"))

## Klick från game3d: räckviddskontroll + rätt panel — samma regler som
## 2D-entiteternas _on_click (npc.gd/shop_npc.gd m.fl.).
func interact() -> void:
	if World.hud == null:
		return
	var reach := 2 if kind == "dialogue" else 1
	var pdist := maxi(absi(GameState.player_tile.x - tile.x),
		absi(GameState.player_tile.y - tile.y))
	if pdist > reach:
		World.hud.show_message("Gå närmare %s." % display_name())
		return
	match kind:
		"dialogue":      World.hud.open_dialogue(npc_id)
		"shop":          World.hud.open_shop()
		"bank":          World.hud.open_bank()
		"taskmaster":    World.hud.open_tasks()
		"spell_teacher": World.hud.open_spellbook(true)

# ── Visual ────────────────────────────────────────────────────────────────────
func _model_file() -> String:
	if kind != "dialogue":
		return String(KIND_MODELS.get(kind, "middle_aged_man"))
	if SPECIAL_MODELS.has(npc_id):
		return String(SPECIAL_MODELS[npc_id])
	return String(CIVILIAN_MODELS[absi(hash(npc_id)) % CIVILIAN_MODELS.size()])

## GLB-gestalt (samma konventioner som Monster3D: 1,0 m-normaliserad modell,
## glTF-framåt +Z → inre PI-rotation) med platshållarlåda som fallback.
func _build_visual() -> void:
	var file := _model_file()
	_model_h = float(MODEL_HEIGHTS.get(file, 1.7))
	var path := "res://assets/models3d/%s.glb" % file
	if ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		inst.scale = Vector3.ONE * _model_h
		inst.rotation.y = PI
		add_child(inst)
		return
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.4, 0.5)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.65, 0.85)
	body.material_override = mat
	body.position.y = 0.7
	add_child(body)
	_model_h = 1.4

func _make_label(text: String, y: float, color: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.01
	l.position.y = y
	add_child(l)
	return l

func _build_name_label() -> void:
	_make_label(display_name(), _model_h + 0.25, Color(0.85, 0.95, 1.0), 40)

func _build_quest_marker() -> void:
	_quest_marker = _make_label("!", _model_h + 0.55, Color(1.0, 0.85, 0.1), 64)
	_quest_marker.visible = false

func _on_quest_state_changed(_id: String) -> void:
	_refresh_quest_marker()

## Gul ! (startbar quest) eller grå ? (pågående att återvända till) — samma
## semantik som 2D-vyns quest-markör.
func _refresh_quest_marker() -> void:
	if _quest_marker == null:
		return
	match QuestSystem.giver_marker(npc_id):
		"start":
			_quest_marker.text = "!"
			_quest_marker.modulate = Color(1.0, 0.85, 0.1)
			_quest_marker.visible = true
		"active":
			_quest_marker.text = "?"
			_quest_marker.modulate = Color(0.7, 0.75, 0.85)
			_quest_marker.visible = true
		_:
			_quest_marker.visible = false
