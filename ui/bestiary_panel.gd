extends DraggablePanelContainer
## Bestiary-panel (B): kills, tier-stjärnor och skadebonus per monster.
## Odödade monster visas som "???". Överst: charm-poäng och köp/bär av charms.

var _list: VBoxContainer

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(340, 0)
	offset_left = 580.0
	offset_top = 16.0
	_list = VBoxContainer.new()
	add_child(_list)
	TaskSystem.bestiary_changed.connect(func(): if visible: _rebuild())
	CharmSystem.charms_changed.connect(func(): if visible: _rebuild())
	CharmSystem.points_changed.connect(func(_p): if visible: _rebuild())

func toggle() -> void:
	visible = not visible
	if visible:
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_build_charms()
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
			_list.add_child(lbl)
		else:
			var t := TaskSystem.tier(mname)
			lbl.text = "%s   %d kills   %s   +%d %% skada" % [mname, kills, "★".repeat(t), t * 2]
			_list.add_child(lbl)
			# Bestiary-text visas när monstret väl är upptäckt
			var desc := String(MonsterDB.monsters[mname].get("desc", ""))
			if desc != "":
				var dlbl := Label.new()
				dlbl.text = "   " + desc
				dlbl.add_theme_font_size_override("font_size", 10)
				dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dlbl.custom_minimum_size = Vector2(330, 0)
				dlbl.modulate = Color(0.75, 0.72, 0.6)
				_list.add_child(dlbl)

## Charm-sektion: poängsaldo och en rad per charm med köp/bär-knapp.
func _build_charms() -> void:
	var header := Label.new()
	header.text = "Charms — %d poäng" % CharmSystem.points
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color(1.0, 0.85, 0.4)
	_list.add_child(header)
	for id in CharmSystem.charms:
		var def: Dictionary = CharmSystem.charms[id]
		var row := HBoxContainer.new()
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 11)
		info.custom_minimum_size = Vector2(240, 0)
		info.text = "%s (%d p)\n%s" % [def.get("name", id), int(def.get("cost", 0)), def.get("desc", "")]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		row.add_child(_charm_button(String(id), def))
		_list.add_child(row)
	var sep := HSeparator.new()
	_list.add_child(sep)

func _charm_button(id: String, def: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 0)
	var equipped: bool = (CharmSystem.equipped_offense == id) or (CharmSystem.equipped_defense == id)
	if not CharmSystem.is_unlocked(id):
		btn.text = "Köp"
		btn.disabled = not CharmSystem.can_afford(id)
		btn.pressed.connect(func(): CharmSystem.unlock(id))
	elif equipped:
		btn.text = "Bärs ✓"
		var is_offense: bool = String(def.get("type", "")) == "offense"
		btn.pressed.connect(func():
			if is_offense: CharmSystem.unequip_offense()
			else: CharmSystem.unequip_defense())
	else:
		btn.text = "Bär"
		btn.pressed.connect(func(): CharmSystem.equip(id))
	return btn
