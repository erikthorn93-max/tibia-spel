extends PanelContainer
## Bestiary-panel (B): kills, tier-stjärnor och skadebonus per monster.
## Odödade monster visas som "???".

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(340, 0)
	offset_left = 580.0
	offset_top = 16.0
	_list = VBoxContainer.new()
	add_child(_list)
	TaskSystem.bestiary_changed.connect(func(): if visible: _rebuild())

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Bestiary  (tiers vid 100/400/1000 kills)"
	title.add_theme_font_size_override("font_size", 14)
	_list.add_child(title)
	for mname in MonsterDB.monsters:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		var kills := int(TaskSystem.bestiary.get(mname, 0))
		if kills <= 0:
			lbl.text = "???"
			lbl.modulate = Color(0.5, 0.5, 0.5)
		else:
			var t := TaskSystem.tier(mname)
			lbl.text = "%s   %d kills   %s   +%d %% skada" % [mname, kills, "★".repeat(t), t * 2]
		_list.add_child(lbl)
