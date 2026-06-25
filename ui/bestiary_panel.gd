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
			# Element-svagheter/resistenser (charm-element) om monstret har några
			var etext := _element_text(MonsterDB.monsters[mname].get("element_mod", {}))
			if etext != "":
				var elbl := Label.new()
				elbl.text = "   " + etext
				elbl.add_theme_font_size_override("font_size", 10)
				elbl.modulate = Color(0.6, 0.8, 0.95)
				_list.add_child(elbl)

const _ELEM_NAMES := {"fire": "Eld", "energy": "Energi", "death": "Död", "physical": "Fysisk"}

## Formaterar element_mod till t.ex. "Svag: Eld · Tål: Död" för bestiariet.
func _element_text(mods) -> String:
	if not (mods is Dictionary) or mods.is_empty():
		return ""
	var weak: Array = []
	var resist: Array = []
	var immune: Array = []
	for el in mods:
		var m := float(mods[el])
		var nm := String(_ELEM_NAMES.get(el, el))
		if m <= 0.0: immune.append(nm)
		elif m < 1.0: resist.append(nm)
		elif m > 1.0: weak.append(nm)
	var parts: Array = []
	if not weak.is_empty(): parts.append("Svag: " + ", ".join(weak))
	if not immune.is_empty(): parts.append("Immun: " + ", ".join(immune))
	if not resist.is_empty(): parts.append("Tål: " + ", ".join(resist))
	return "  ".join(parts)

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
		var head := String(def.get("name", id))
		if CharmSystem.is_unlocked(String(id)):
			head += "  " + "◆".repeat(CharmSystem.rank(String(id)))   # rank-diamanter
		else:
			head += " (%d p)" % int(def.get("cost", 0))
		info.text = "%s\n%s" % [head, def.get("desc", "")]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		row.add_child(_charm_button(String(id), def))
		if CharmSystem.is_unlocked(String(id)) and CharmSystem.rank(String(id)) < CharmSystem.MAX_RANK:
			row.add_child(_upgrade_button(String(id)))
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

func _upgrade_button(id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 0)
	btn.text = "Rank↑ (%d p)" % CharmSystem.upgrade_cost(id)
	btn.disabled = not CharmSystem.can_upgrade(id)
	btn.pressed.connect(func(): CharmSystem.upgrade(id))
	return btn
