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
	click_area.input_event.connect(_on_click)

func _process(delta: float) -> void:
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
