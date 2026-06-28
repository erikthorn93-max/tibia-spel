class_name DialogueNpc
extends Node2D
## Dialog-NPC: klick intill → dialogruta. Idle barks vid närhet.

const BARK_COOLDOWN := 30.0
const BARK_SHOW_TIME := 4.0
const BARK_RADIUS := 4
const BARK_GLOBAL_GAP_MS := 8000   # min-tid mellan TVÅ olika NPC:ers barks

static var _global_bark_gate_ms := 0   # delas av alla NPC:er — en i taget

var npc_id := ""
var tile := Vector2i.ZERO
var _bark_timer := 0.0
var _breath_t := 0.0      # idle-andning, slumpad fas så NPC:er inte andas i takt
var _quest_marker: Label
const MARKER_BASE_Y := -56.0
const SpriteFx = preload("res://world/sprite_fx.gd")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $ClickArea
@onready var name_lbl: Label = $NameLabel
@onready var bark_lbl: Label = $BarkLabel
@onready var bark_audio: AudioStreamPlayer2D = $BarkAudio

func setup(id: String, t: Vector2i) -> void:
	npc_id = id
	tile = t
	position = Vector2(t) * 32 + Vector2(16, 16)

func _ready() -> void:
	name_lbl.text = String(DialogueDB.npcs[npc_id]["name"])
	# Ladda NPC-specifik sprite, annars generisk dialogue_npc sprite
	var spec_path := "res://assets/sprites/npcs/%s.png" % npc_id
	if ResourceLoader.exists(spec_path):
		_sprite.texture = load(spec_path)
	else:
		_sprite.texture = load("res://assets/sprites/npcs/dialogue_npc.png")
	_sprite.material = SpriteFx.outline_material()   # kontur → läsbarhet
	add_child(SpriteFx.make_shadow(13.0))             # markskugga
	click_area.input_event.connect(_on_click)
	_breath_t = randf() * 10.0
	_build_quest_marker()
	# Uppdatera markören när questläget ändras (start/progress/slutförd)
	for sig in [QuestSystem.quest_started, QuestSystem.step_advanced, QuestSystem.quest_completed]:
		sig.connect(func(_id): _refresh_quest_marker())
	_refresh_quest_marker()

func _build_quest_marker() -> void:
	_quest_marker = Label.new()
	_quest_marker.offset_left = -16.0
	_quest_marker.offset_right = 16.0
	_quest_marker.offset_top = MARKER_BASE_Y
	_quest_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_marker.add_theme_font_size_override("font_size", 20)
	_quest_marker.add_theme_constant_override("outline_size", 4)
	_quest_marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_quest_marker.visible = false
	_quest_marker.z_index = 5
	_quest_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ska aldrig sluka klick på NPC:n
	add_child(_quest_marker)

## Visar gul ! (startbar quest) eller grå ? (pågående quest att återvända till).
func _refresh_quest_marker() -> void:
	if _quest_marker == null:
		return
	match QuestSystem.giver_marker(npc_id):
		"start":
			_quest_marker.text = "!"
			_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
			_quest_marker.visible = true
		"active":
			_quest_marker.text = "?"
			_quest_marker.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
			_quest_marker.visible = true
		_:
			_quest_marker.visible = false

func _process(delta: float) -> void:
	# Idle-andning så NPC:n inte står helt livlös
	_breath_t += delta
	_sprite.scale.y = CharacterVisual.breath_scale(_breath_t)
	# Mjuk upp/ned-rörelse på quest-markören
	if _quest_marker and _quest_marker.visible:
		_quest_marker.offset_top = MARKER_BASE_Y + sin(Time.get_ticks_msec() / 300.0) * 3.0
	if _bark_timer > 0.0:
		_bark_timer -= delta
		if bark_lbl.visible and _bark_timer < BARK_COOLDOWN - BARK_SHOW_TIME:
			bark_lbl.visible = false
		return
	var pdist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
	if pdist <= BARK_RADIUS and Time.get_ticks_msec() >= _global_bark_gate_ms:
		_bark()

func _bark() -> void:
	_bark_timer = BARK_COOLDOWN
	_global_bark_gate_ms = Time.get_ticks_msec() + BARK_GLOBAL_GAP_MS
	var barks: Array = DialogueDB.npcs[npc_id].get("barks", [])
	if barks.is_empty():
		return
	var i := randi() % barks.size()
	bark_lbl.text = String(barks[i])
	bark_lbl.visible = true
	for ext in ["ogg", "wav"]:
		var p := "res://audio/voice/%s/bark_%d.%s" % [npc_id, i, ext]
		if ResourceLoader.exists(p):
			bark_audio.stream = load(p)
			bark_audio.play()
			return

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pdist := maxi(absi(GameState.player_tile.x - tile.x), absi(GameState.player_tile.y - tile.y))
		if pdist <= 2:
			World.hud.open_dialogue(npc_id)
		else:
			World.hud.show_message("Gå närmare %s." % DialogueDB.npcs[npc_id]["name"])
