extends Control
## Minimap i Tibia-stil.
## Liten vy alltid synlig i övre högra hörnet.
## Tryck M för en större, detaljerad hel-karta med hela zonen.

const MINI_TILE   := 3          # pixlar per tile i minivyn
const MINI_RADIUS := 18         # tiles-radius → 37×37 tiles = 111×111 px
const PANEL_PAD   := 5          # inre marginal
const FULL_MAX_W  := 680.0      # max bredd för fullkartan
const FULL_MAX_H  := 540.0      # max höjd för fullkartan

# Terränggfärger – anpassade för kartvy (något mörkare än spelvärld)
const T_COLORS : Dictionary = {
	".": Color(0.22, 0.47, 0.17),   # gräs
	",": Color(0.35, 0.28, 0.18),   # sand/jord
	"W": Color(0.24, 0.24, 0.27),   # vägg/sten
	"~": Color(0.11, 0.28, 0.56),   # vatten
	"s": Color(0.19, 0.25, 0.11),   # sump
	"b": Color(0.68, 0.62, 0.40),   # strand
}
const COL_UNKNOWN  := Color(0.07, 0.07, 0.09)
const COL_PLAYER   := Color(1.00, 1.00, 0.78)
const COL_MONSTER  := Color(0.90, 0.12, 0.12)
const COL_PORTAL   := Color(0.62, 0.32, 0.94)
const COL_DUNGEON  := Color(0.85, 0.68, 0.14)
const COL_BG       := Color(0.05, 0.05, 0.08, 0.90)
const COL_BORDER   := Color(0.46, 0.46, 0.64, 0.88)
const COL_TITLE    := Color(0.90, 0.82, 0.52)

var _full_open  := false
var _blink_t    := 0.0
var _last_zone  : Node2D = null
## Förberäknad tile-färgkarta för aktuell zon: Vector2i → Color
var _tile_cache : Dictionary = {}

# ──────────────────────────────── Setup ────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_blink_t += delta
	_maybe_rebuild_cache()
	queue_redraw()

# ─────────────────────────── Tile-färgcache ────────────────────────────

func _maybe_rebuild_cache() -> void:
	var zone := _zone()
	if zone == _last_zone:
		return
	_last_zone = zone
	_tile_cache.clear()
	if zone == null:
		return
	for t: Vector2i in zone._walkable:
		_tile_cache[t] = _read_tile_color(zone, t)

func _read_tile_color(zone: Node2D, t: Vector2i) -> Color:
	var coords : Vector2i = zone.tilemap.get_cell_atlas_coords(t)
	if coords.x < 0:
		return COL_UNKNOWN
	for ch: String in PlaceholderTiles.TERRAIN:
		if PlaceholderTiles.TERRAIN[ch] == coords.x:
			return T_COLORS.get(ch, COL_UNKNOWN)
	return COL_UNKNOWN

# ─────────────────────────────── Ritning ───────────────────────────────

func _draw() -> void:
	_draw_mini()
	if _full_open:
		_draw_full_overlay()

# ────────────── Minimap (alltid synlig) ────────────────

func _draw_mini() -> void:
	var zone := _zone()
	if zone == null:
		return
	var vp   := get_viewport().get_visible_rect().size
	var side := float((MINI_RADIUS * 2 + 1) * MINI_TILE + PANEL_PAD * 2)
	var px   := vp.x - side - 6.0
	var py   := 6.0
	var panel := Rect2(Vector2(px, py), Vector2(side, side))

	# Bakgrundspanel
	draw_rect(panel, COL_BG)
	draw_rect(panel, COL_BORDER, false, 1.5)

	var ox := px + PANEL_PAD
	var oy := py + PANEL_PAD
	var pt := _player_tile()

	# Terräng
	for dy in range(-MINI_RADIUS, MINI_RADIUS + 1):
		for dx in range(-MINI_RADIUS, MINI_RADIUS + 1):
			var t := Vector2i(pt.x + dx, pt.y + dy)
			var col := _tile_cache.get(t, COL_UNKNOWN)
			draw_rect(
				Rect2(Vector2(ox + (dx + MINI_RADIUS) * MINI_TILE,
				              oy + (dy + MINI_RADIUS) * MINI_TILE),
				      Vector2(MINI_TILE, MINI_TILE)),
				col)

	# Portaler
	for t: Vector2i in zone.portals:
		_mini_dot(t, pt, ox, oy, COL_PORTAL, 2)

	# Dungeon-ingångar
	for t: Vector2i in zone.dungeon_entrances:
		_mini_dot(t, pt, ox, oy, COL_DUNGEON, 2)

	# Monster (röda prickar)
	for mn in _monsters(zone):
		_mini_dot(mn.tile, pt, ox, oy, COL_MONSTER, 2)

	# Spelare – blinkar (vit prick i mitten)
	var blink := 1.0 if fmod(_blink_t, 1.0) < 0.65 else 0.0
	draw_rect(
		Rect2(Vector2(ox + MINI_RADIUS * MINI_TILE,
		              oy + MINI_RADIUS * MINI_TILE),
		      Vector2(MINI_TILE, MINI_TILE)),
		Color(COL_PLAYER.r, COL_PLAYER.g, COL_PLAYER.b, blink))

	# Kompassrosa – liten "N" längst upp
	var font := ThemeDB.fallback_font
	draw_string(font,
		Vector2(px + side * 0.5 - 3.0, py + PANEL_PAD + 1.0),
		"N", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		Color(0.78, 0.72, 0.50, 0.75))

	# [M] hint längst ner i panelen
	draw_string(font,
		Vector2(px + 3.0, py + side - 2.0),
		"[M]", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		Color(0.45, 0.45, 0.55, 0.70))

func _mini_dot(tile: Vector2i, player_tile: Vector2i,
               ox: float, oy: float, col: Color, size: int) -> void:
	var dx := tile.x - player_tile.x
	var dy := tile.y - player_tile.y
	if absi(dx) > MINI_RADIUS or absi(dy) > MINI_RADIUS:
		return
	var off := float(MINI_TILE - size) * 0.5
	draw_rect(
		Rect2(Vector2(ox + (dx + MINI_RADIUS) * MINI_TILE + off,
		              oy + (dy + MINI_RADIUS) * MINI_TILE + off),
		      Vector2(size, size)),
		col)

# ────────────── Fullskärmskarta (M-tangent) ────────────────

func _draw_full_overlay() -> void:
	var zone := _zone()
	if zone == null:
		return
	var gs  : Vector2i = zone.get("grid_size") if zone.get("grid_size") != null else Vector2i.ZERO
	var vp  := get_viewport().get_visible_rect().size
	var font := ThemeDB.fallback_font

	# Beräkna tile-storlek som ryms i max-dimensionerna
	var ft := int(min(FULL_MAX_W / maxf(float(gs.x), 1.0),
	                  FULL_MAX_H / maxf(float(gs.y), 1.0)))
	ft = clampi(ft, 2, 8)

	var map_w   := gs.x * ft
	var map_h   := gs.y * ft
	var title_h := 26.0
	var pad     := 12.0
	var panel_w := float(map_w) + pad * 2.0
	var panel_h := float(map_h) + pad * 2.0 + title_h
	var panel_x := (vp.x - panel_w) * 0.5
	var panel_y := (vp.y - panel_h) * 0.5

	# Dimma bakgrunden
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.50))

	# Kartpanel
	var panel_rect := Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))
	draw_rect(panel_rect, Color(0.05, 0.05, 0.08, 0.97))
	draw_rect(panel_rect, COL_BORDER, false, 2.0)

	# Titel
	draw_string(font,
		Vector2(panel_x + pad, panel_y + title_h - 7.0),
		"Karta — " + zone.zone_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_TITLE)

	# Stäng-hint
	draw_string(font,
		Vector2(panel_x + panel_w - 85.0, panel_y + title_h - 7.0),
		"[M] Stäng", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.48, 0.48, 0.48))

	# Separator
	draw_line(
		Vector2(panel_x + 6.0,          panel_y + title_h),
		Vector2(panel_x + panel_w - 6.0, panel_y + title_h),
		COL_BORDER, 1.0)

	var mx := panel_x + pad
	var my := panel_y + title_h + pad

	# Terräng (hela zonen)
	for ty in gs.y:
		for tx in gs.x:
			var t := Vector2i(tx, ty)
			draw_rect(
				Rect2(Vector2(mx + tx * ft, my + ty * ft), Vector2(ft, ft)),
				_tile_cache.get(t, COL_UNKNOWN))

	# Portaler
	for t: Vector2i in zone.portals:
		_full_dot(t, mx, my, ft, COL_PORTAL)

	# Dungeon-ingångar
	for t: Vector2i in zone.dungeon_entrances:
		_full_dot(t, mx, my, ft, COL_DUNGEON)

	# Monster
	for mn in _monsters(zone):
		_full_dot(mn.tile, mx, my, ft, COL_MONSTER)

	# Spelare (blinkar, lite större)
	var pt := _player_tile()
	var blink := 1.0 if fmod(_blink_t, 1.0) < 0.65 else 0.35
	var ps := maxi(ft + 1, 3)
	draw_rect(
		Rect2(Vector2(mx + pt.x * ft - 1.0, my + pt.y * ft - 1.0),
		      Vector2(ps, ps)),
		Color(COL_PLAYER.r, COL_PLAYER.g, COL_PLAYER.b, blink))

	# Statusrad längst ner
	draw_string(font,
		Vector2(panel_x + pad, panel_y + panel_h - 4.0),
		"Pos (%d, %d)   Zonsstorlek %d×%d" % [pt.x, pt.y, gs.x, gs.y],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.38, 0.38, 0.44))

	# Teckenförklaring
	_draw_legend(panel_x + panel_w - 92.0, panel_y + panel_h - 76.0)

func _full_dot(tile: Vector2i, mx: float, my: float, ft: int, col: Color) -> void:
	var ds  := maxi(ft - 1, 1)
	var off := float(ft - ds) * 0.5
	draw_rect(
		Rect2(Vector2(mx + tile.x * ft + off, my + tile.y * ft + off),
		      Vector2(ds, ds)),
		col)

func _draw_legend(lx: float, ly: float) -> void:
	var font := ThemeDB.fallback_font
	var items : Array = [
		[COL_PLAYER,  "Spelare"],
		[COL_MONSTER, "Monster"],
		[COL_PORTAL,  "Portal"],
		[COL_DUNGEON, "Dungeonentré"],
	]
	for i in items.size():
		var c   : Color  = items[i][0]
		var lbl : String = items[i][1]
		draw_rect(Rect2(Vector2(lx, ly + i * 15.0), Vector2(7.0, 7.0)), c)
		draw_string(font,
			Vector2(lx + 11.0, ly + i * 15.0 + 8.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.60, 0.60, 0.60))

# ──────────────────────────────── Input ────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	# Klick var som helst stänger fullkartan (mouse_filter är STOP när den är öppen)
	if _full_open and event is InputEventMouseButton and event.pressed:
		_full_open = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		_full_open = not _full_open
		mouse_filter = Control.MOUSE_FILTER_STOP if _full_open else Control.MOUSE_FILTER_IGNORE
		get_viewport().set_input_as_handled()

# ─────────────────────────────── Helpers ───────────────────────────────

func _zone() -> Node2D:
	var p := World.player if World.get("player") != null else null
	if p == null or not is_instance_valid(p):
		return null
	return p.zone

func _player_tile() -> Vector2i:
	var p := World.player if World.get("player") != null else null
	if p == null or not is_instance_valid(p):
		return Vector2i.ZERO
	return p.tile

func _monsters(zone: Node2D) -> Array:
	var out : Array = []
	for child in zone.get_children():
		if child.has_method("take_damage") and child.has_method("setup"):
			if not bool(child.get("dead")):
				out.append(child)
	return out
