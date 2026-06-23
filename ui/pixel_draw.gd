extends RefCounted
class_name PixelDraw
## Delade pixel-rit-primitiver för de procedurella ikon-generatorerna
## (SkillIcons, EquipIcons, SpellIcons). Opererar på en RGBA8-Image; bounds
## klampas mot bildens egen storlek så samma kod funkar oavsett canvas-mått.

static func p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

static func rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			p(img, x, y, c)

static func disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
		for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
			if Vector2(x, y).distance_to(Vector2(cx, cy)) <= r:
				p(img, x, y, c)

static func ring(img: Image, cx: float, cy: float, r_out: float, r_in: float, c: Color) -> void:
	for y in range(int(floor(cy - r_out)), int(ceil(cy + r_out)) + 1):
		for x in range(int(floor(cx - r_out)), int(ceil(cx + r_out)) + 1):
			var d := Vector2(x, y).distance_to(Vector2(cx, cy))
			if d <= r_out and d >= r_in:
				p(img, x, y, c)

static func line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		p(img, x, y, c)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

## Dunkel kontur: tomma pixlar intill en fylld blir färgade (silhuett-kant).
static func outline(img: Image, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var edge: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and nx < w and ny >= 0 and ny < h and img.get_pixel(nx, ny).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for e in edge:
		img.set_pixel(e.x, e.y, color)
