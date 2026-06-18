extends SceneTree
## Engångs: läser nuvarande town.json och skriver dess tile-rader till
## _thais_core.txt (stadskärnans källa för generatorn). Kör EN gång innan
## town.json regenereras.
## Körs headless: godot --headless --path <proj> -s res://tools/extract_core.gd

func _init() -> void:
	var f := FileAccess.open("res://data/zones/town.json", FileAccess.READ)
	assert(f != null, "town.json saknas")
	var d = JSON.parse_string(f.get_as_text())
	assert(d is Dictionary and d.has("tiles"), "town.json saknar tiles")
	var rows: Array = d["tiles"]
	var out := FileAccess.open("res://data/zones/_thais_core.txt", FileAccess.WRITE)
	for r in rows:
		out.store_line(String(r))
	out.close()
	print("extract_core: skrev %d rader (bredd %d)" % [rows.size(), String(rows[0]).length()])
	quit()
