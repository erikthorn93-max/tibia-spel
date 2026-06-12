extends PanelContainer
## Dialogruta: NPC-namn, text, valknappar. Spelar nodens röstfil om den finns.

var _npc_id := ""
var _name_lbl: Label
var _text_lbl: Label
var _choices: VBoxContainer
var _audio: AudioStreamPlayer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(540, 0)
	offset_left = 370.0
	offset_top = 470.0
	var v := VBoxContainer.new()
	add_child(v)
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 14)
	_name_lbl.modulate = Color(1.0, 0.85, 0.4)
	v.add_child(_name_lbl)
	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 13)
	v.add_child(_text_lbl)
	_choices = VBoxContainer.new()
	v.add_child(_choices)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)

func open(npc_id: String) -> void:
	_npc_id = npc_id
	_show_node(String(DialogueDB.npcs[npc_id]["dialogue_root"]))

func close() -> void:
	visible = false
	_audio.stop()

func _show_node(node_id: String) -> void:
	var n: Dictionary = DialogueDB.nodes.get(node_id, {})
	if n.is_empty():
		close()
		return
	visible = true
	_name_lbl.text = String(DialogueDB.npcs[_npc_id]["name"])
	_text_lbl.text = String(n["text"])
	_play_voice(node_id)
	for c in _choices.get_children():
		c.queue_free()
	for c in DialogueDB.visible_choices(node_id):
		var b := Button.new()
		b.text = String(c["text"])
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_choice.bind(c))
		_choices.add_child(b)

func _on_choice(c: Dictionary) -> void:
	DialogueDB.run_actions(c.get("actions", []), _npc_id)
	var nxt = c.get("next")
	if nxt == null:
		close()
	else:
		_show_node(String(nxt))

func _play_voice(node_id: String) -> void:
	_audio.stop()
	for ext in ["ogg", "wav"]:
		var p := "res://audio/voice/%s/%s.%s" % [_npc_id, node_id, ext]
		if ResourceLoader.exists(p):
			_audio.stream = load(p)
			_audio.play()
			return
