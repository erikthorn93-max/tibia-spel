extends SceneTree
## Engångsverktyg: renderar alla utrustnings-silhuetter uppskalade → PNG.
## Kör: godot --headless -s tools/dump_equip_icons.gd

func _init() -> void:
	var slots := [
		"amulet", "helmet", "backpack",
		"weapon", "body", "offhand",
		"tool", "legs", "ammo",
		"ring", "boots", "light",
	]
	var cols := 3
	var scale := 7
	var cell := 16 * scale + 6
	var rows := int(ceil(slots.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.12, 0.08))   # samma som slot-bg
	for i in slots.size():
		var tex := EquipIcons.silhouette(slots[i])
		var src := tex.get_image()
		var ox := (i % cols) * cell + 3
		var oy := (i / cols) * cell + 3
		for y in 16:
			for x in 16:
				var px := src.get_pixel(x, y)
				if px.a <= 0.0:
					continue
				for sy in scale:
					for sx in scale:
						sheet.set_pixel(ox + x * scale + sx, oy + y * scale + sy, px)
	var out := "user://equip_icons_sheet.png"
	sheet.save_png(out)
	print("SHEET: ", ProjectSettings.globalize_path(out))
	quit()
