extends SceneTree
## Engångsverktyg: renderar alla skill-ikoner uppskalade i ett rutnät → PNG,
## för visuell granskning. Kör: godot --headless -s tools/dump_skill_icons.gd

func _init() -> void:
	var ids := [
		"sword", "constitution", "mining",
		"axe", "agility", "smithing",
		"shielding", "herbalism", "fishing",
		"distance", "thieving", "cooking",
		"prayer", "crafting", "firemaking",
		"magic", "fletching", "woodcutting",
		"runecrafting", "slayer", "farming",
		"construction", "hunting", "alchemy",
		"club", "fist",
	]
	var colors := {
		"sword": Color(0.80, 0.15, 0.10), "constitution": Color(0.80, 0.10, 0.10),
		"mining": Color(0.50, 0.55, 0.55), "axe": Color(0.60, 0.30, 0.08),
		"agility": Color(0.91, 0.30, 0.24), "smithing": Color(0.70, 0.75, 0.75),
		"shielding": Color(0.16, 0.50, 0.73), "herbalism": Color(0.09, 0.63, 0.40),
		"fishing": Color(0.10, 0.74, 0.61), "distance": Color(0.15, 0.68, 0.38),
		"thieving": Color(0.85, 0.68, 0.05), "cooking": Color(0.95, 0.61, 0.07),
		"prayer": Color(0.80, 0.80, 0.50), "crafting": Color(0.70, 0.55, 0.35),
		"firemaking": Color(0.95, 0.45, 0.05), "magic": Color(0.56, 0.27, 0.68),
		"fletching": Color(0.35, 0.65, 0.35), "woodcutting": Color(0.18, 0.70, 0.35),
		"runecrafting": Color(0.20, 0.60, 0.86), "slayer": Color(0.60, 0.10, 0.10),
		"farming": Color(0.30, 0.70, 0.20), "construction": Color(0.70, 0.60, 0.40),
		"hunting": Color(0.40, 0.55, 0.20), "alchemy": Color(0.70, 0.35, 0.80),
		"club": Color(0.45, 0.28, 0.18), "fist": Color(0.90, 0.48, 0.10),
	}
	var cols := 3
	var scale := 6
	var cell := 16 * scale + 6
	var rows := int(ceil(ids.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.10, 0.07, 0.03))
	for i in ids.size():
		var id: String = ids[i]
		var tex := SkillIcons.texture(id, colors.get(id, Color.WHITE))
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
	var out := "user://skill_icons_sheet.png"
	sheet.save_png(out)
	print("SHEET: ", ProjectSettings.globalize_path(out))
	quit()
