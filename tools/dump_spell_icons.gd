extends SceneTree
## Engångsverktyg: renderar alla spell-ikoner uppskalade → PNG.
## Kör: godot --headless -s tools/dump_spell_icons.gd

func _init() -> void:
	var f := FileAccess.open("res://data/spells.json", FileAccess.READ)
	var spells: Dictionary = JSON.parse_string(f.get_as_text())
	var ids := spells.keys()
	var cols := 4
	var scale := 6
	var cell := 16 * scale + 8
	var rows := int(ceil(ids.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.10, 0.18))
	for i in ids.size():
		var id: String = ids[i]
		var tex := SpellIcons.texture(id, spells[id])
		var src := tex.get_image()
		var ox := (i % cols) * cell + 4
		var oy := (i / cols) * cell + 4
		for y in 16:
			for x in 16:
				var px := src.get_pixel(x, y)
				if px.a <= 0.0:
					continue
				for sy in scale:
					for sx in scale:
						sheet.set_pixel(ox + x * scale + sx, oy + y * scale + sy, px)
	var out := "user://spell_icons_sheet.png"
	sheet.save_png(out)
	print("SHEET: ", ProjectSettings.globalize_path(out))
	print("ORDER: ", ", ".join(PackedStringArray(ids)))
	quit()
