extends Control
## Minimap i Tibia-stil.
## Liten vy alltid synlig i övre högra hörnet.
## Tryck M för en större, detaljerad hel-karta med hela zonen.
## Fullkartan: scrollhjul = zoom in/ut, vänster musknapp + dra = panorera.

const MINI_TILE   := 3          # pixlar per tile i minivyn
const MINI_RADIUS := 18         # tiles-radius → 37×37 tiles = 111×111 px
const PANEL_PAD   := 5          # inre marginal
const FULL_MAX_W  := 680.0      # max bredd för fullkartan
const FULL_MAX_H  := 540.0      # max höjd för fullkartan

# Zoom-intervall för fullkartan
const ZOOM_MIN    := 1
const ZOOM_MAX    := 12
const ZOOM_STEP   := 1

# Terränggfärger – anpassade för kartvy (något mörkare än spelvärld)
const T_COLORS : Dictionary = {
	".": Color(0.22, 0.47, 0.17),   # gräs
	",": Color(0.35, 0.28, 0.18),   # sand/jord
	"W": Color(0.24, 0.24, 0.27),   # vägg/sten
	"~": Color(0.11, 0.28, 0.56),   # vatten
	"s": Color(0.19, 0.25, 0.11),   # sump
	"b": Color(0.68, 0.62, 0.40),   # strand
	"t": Color(0.18, 0.35, 0.16),   # träd
	"c": Color(0.54, 0.52, 0.47),   # kullersten-väg
	"g": Color(0.60, 0.66, 0.31),   # åker
}
const COL_UNKNOWN  := Color(0.07, 0.07, 0.09)
const COL_PLAYER   := Color(1.00, 1.00, 0.78)
const COL_MONSTER  := Color(0.90, 0.12, 0.12)
const COL_PORTAL   := Color(0.62, 0.32, 0.94)
const COL_DUNGEON  := Color(0.85, 0.68, 0.14)
const COL_LOOT     := Color(0.91, 0.78, 0.18)
const COL_GRAVE    := Color(0.85, 0.85, 0.85)
const COL_QUEST_START  := Color(1.00, 0.85, 0.10)   # gul ! — startbar quest
const COL_QUEST_ACTIVE := Color(0.70, 0.75, 0.85)   # grå ? — pågående quest
const COL_BG       := Color(0.05, 0.05, 0.08, 0.90)
const COL_BORDER   := Color(0.46, 0.46, 0.64, 0.88)
const COL_TITLE    := Color(0.90, 0.82, 0.52)

var _full_open  := false
var _blink_t    := 0.0
var _last_zone  : Node2D = null
## Förberäknad tile-färgkarta för aktuell zon: Vector2i → Color
var _tile_cache : Dictionary = {}
## Portaltile → visningsnamn på målzonen (byggs om vid zonbyte)
var _portal_names : Dictionary = {}
## Redan ritade etikett-rutor denna frame (för kollisionsundvikning)
var _label_rects : Array[Rect2] = []

# Hur många tiles piltangenterna panorerar fullkartan per tryck
const PAN_STEP_TILES := 4.0

# Fullkarta: zoom och panorering
var _full_zoom   : int     = 4          # pixlar per tile (börjar på 4)
var _pan_offset  : Vector2 = Vector2.ZERO   # pan i tile-koordinater
var _panning     : bool    = false
var _pan_moved   : bool    = false          # rörde musen sig under tryck (=drag, inte klick)
var _pan_start_mouse : Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

# Panelgeometri (beräknas i _draw_full_overlay, används i input)
var _full_map_origin : Vector2 = Vector2.ZERO  # pixel-pos för tile (0,0) i fullkartan
var _full_panel_rect : Rect2   = Rect2()

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
	_portal_names.clear()
	if zone == null:
		return
	for t: Vector2i in zone._walkable:
		_tile_cache[t] = _read_tile_color(zone, t)
	# Slå upp målzonens namn en gång per portal (inte varje frame)
	for t: Vector2i in zone.portals:
		_portal_names[t] = _lookup_zone_name(String(zone.portals[t]))

## Läser visningsnamnet för en zon-id ur dess JSON (en gång, cachat ovan).
func _lookup_zone_name(id: String) -> String:
	var f := FileAccess.open("res://data/zones/%s.json" % id, FileAccess.READ)
	if f == null:
		return id
	var d = JSON.parse_string(f.get_as_text())
	return String(d["name"]) if d is Dictionary and d.has("name") else id

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
			var col: Color = _tile_cache.get(t, COL_UNKNOWN)
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

	# Ground loot (gula prickar)
	for gi in _ground_items(zone):
		_mini_dot(gi.tile, pt, ox, oy, COL_LOOT, 2)

	# Gravsten (vit prick) om spelaren dog i denna zon
	if GameState.grave_zone == zone.zone_id and GameState.grave_tile.x >= 0:
		_mini_dot(GameState.grave_tile, pt, ox, oy, COL_GRAVE, 3)

	# Quest-markörer (gul/grå prickar)
	for q in _quest_givers(zone):
		_mini_dot(q["tile"], pt, ox, oy,
			COL_QUEST_START if q["status"] == "start" else COL_QUEST_ACTIVE, 3)

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

	var ft  := _full_zoom
	var title_h := 26.0
	var pad     := 12.0

	# Synlig kartyta = tillgängligt fönster minus margins
	var canvas_w := minf(float(gs.x * ft), FULL_MAX_W)
	var canvas_h := minf(float(gs.y * ft), FULL_MAX_H)
	var panel_w  := canvas_w + pad * 2.0
	var panel_h  := canvas_h + pad * 2.0 + title_h
	var panel_x  := (vp.x - panel_w) * 0.5
	var panel_y  := (vp.y - panel_h) * 0.5

	# Spara geometri för input-hantering
	_full_panel_rect = Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))

	# Klippa till canvas-ytan
	var mx := panel_x + pad
	var my := panel_y + title_h + pad

	# Pan i pixlar
	var pan_px := _pan_offset * float(ft)

	# Tile (0,0) ritas vid:
	_full_map_origin = Vector2(mx - pan_px.x, my - pan_px.y)

	# Dimma bakgrunden
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.50))

	# Kartpanel
	draw_rect(_full_panel_rect, Color(0.05, 0.05, 0.08, 0.97))
	draw_rect(_full_panel_rect, COL_BORDER, false, 2.0)

	# Titel
	draw_string(font,
		Vector2(panel_x + pad, panel_y + title_h - 7.0),
		"Karta — " + zone.zone_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_TITLE)

	# Stäng-hint + zoom-info
	draw_string(font,
		Vector2(panel_x + panel_w - 160.0, panel_y + title_h - 7.0),
		"Scroll=zoom  Drag/Piltgr=panorera  [M] Stäng",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.48, 0.48, 0.48))

	# Separator
	draw_line(
		Vector2(panel_x + 6.0,          panel_y + title_h),
		Vector2(panel_x + panel_w - 6.0, panel_y + title_h),
		COL_BORDER, 1.0)

	# ─── Klippregion (rita bara inom kartytans bounds) ───
	# Vi simulerar klipp med scissor via draw_rect+CLIP_CONTENTS … men i
	# Godot 4 CanvasItem-draw finns inte scissor. Vi filtrerar istället vilka
	# tiles som är synliga.
	var clip := Rect2(Vector2(mx, my), Vector2(canvas_w, canvas_h))
	var tx_min := int((pan_px.x)                / ft)
	var ty_min := int((pan_px.y)                / ft)
	var tx_max := int((pan_px.x + canvas_w)     / ft) + 1
	var ty_max := int((pan_px.y + canvas_h)     / ft) + 1
	tx_min = clampi(tx_min, 0, gs.x)
	ty_min = clampi(ty_min, 0, gs.y)
	tx_max = clampi(tx_max, 0, gs.x)
	ty_max = clampi(ty_max, 0, gs.y)

	# Terräng (bara synliga tiles)
	for ty in range(ty_min, ty_max):
		for tx in range(tx_min, tx_max):
			var t   := Vector2i(tx, ty)
			var col : Color = _tile_cache.get(t, COL_UNKNOWN)
			var pr  := Rect2(
				Vector2(_full_map_origin.x + tx * ft,
						_full_map_origin.y + ty * ft),
				Vector2(ft, ft))
			if clip.intersects(pr):
				draw_rect(pr.intersection(clip), col)

	# Portaler
	for t: Vector2i in zone.portals:
		_full_dot_clipped(t, clip, COL_PORTAL, ft)

	# Dungeon-ingångar
	for t: Vector2i in zone.dungeon_entrances:
		_full_dot_clipped(t, clip, COL_DUNGEON, ft)

	# Portalnamn (destinationszon) — ritas ovanpå prickarna
	_label_rects.clear()
	for t: Vector2i in zone.portals:
		_draw_full_portal_label(t, clip, ft, font)

	# Monster
	for mn in _monsters(zone):
		_full_dot_clipped(mn.tile, clip, COL_MONSTER, ft)

	# Ground loot
	for gi in _ground_items(zone):
		_full_dot_clipped(gi.tile, clip, COL_LOOT, ft)

	# Gravsten
	if GameState.grave_zone == zone.zone_id and GameState.grave_tile.x >= 0:
		_full_dot_clipped(GameState.grave_tile, clip, COL_GRAVE, ft)

	# Quest-markörer (gul ! = startbar, grå ? = pågående) — ovanpå allt annat
	for q in _quest_givers(zone):
		_full_quest_marker(q["tile"], clip, ft, font, String(q["status"]))

	# Spelare (blinkar)
	var pt    := _player_tile()
	var blink := 1.0 if fmod(_blink_t, 1.0) < 0.65 else 0.35
	var ps    := maxi(ft + 1, 3)
	var pp    := Vector2(_full_map_origin.x + pt.x * ft - 1.0,
						 _full_map_origin.y + pt.y * ft - 1.0)
	if clip.has_point(pp):
		draw_rect(Rect2(pp, Vector2(ps, ps)),
				  Color(COL_PLAYER.r, COL_PLAYER.g, COL_PLAYER.b, blink))

	# Statusrad
	draw_string(font,
		Vector2(panel_x + pad, panel_y + panel_h - 4.0),
		"Pos (%d, %d)   Zonsstorlek %d×%d   Zoom ×%d" % [pt.x, pt.y, gs.x, gs.y, ft],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.38, 0.38, 0.44))

	# Teckenförklaring
	_draw_legend(panel_x + panel_w - 122.0, panel_y + panel_h - 130.0)

## Ritar en quest-markör (! / ?) med mörk bakgrund vid en NPC-tile på fullkartan.
func _full_quest_marker(tile: Vector2i, clip: Rect2, ft: int, font: Font, status: String) -> void:
	var p := Vector2(_full_map_origin.x + tile.x * ft, _full_map_origin.y + tile.y * ft)
	if not clip.has_point(p):
		return
	var col   := COL_QUEST_START if status == "start" else COL_QUEST_ACTIVE
	var glyph := "!" if status == "start" else "?"
	var fs    := 14
	var size  := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	# Centrera glyfen över tilen men håll den innanför kartytan
	var gx := clampf(p.x + ft * 0.5 - size.x * 0.5,
					 clip.position.x + 1.0, clip.position.x + clip.size.x - size.x - 1.0)
	var gy := clampf(p.y - 2.0,
					 clip.position.y + size.y, clip.position.y + clip.size.y - 2.0)
	var bg := Rect2(Vector2(gx - 3.0, gy - size.y - 1.0).round(), Vector2(size.x + 6.0, size.y + 5.0).round())
	draw_rect(bg, Color(0.04, 0.03, 0.07, 0.88))
	draw_rect(bg, col, false, 1.0)
	draw_string(font, Vector2(roundf(gx), roundf(gy)), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _full_dot_clipped(tile: Vector2i, clip: Rect2, col: Color, ft: int) -> void:
	var ds  := maxi(ft - 1, 1)
	var off := float(ft - ds) * 0.5
	var p   := Vector2(
		_full_map_origin.x + tile.x * ft + off,
		_full_map_origin.y + tile.y * ft + off)
	if clip.has_point(p):
		draw_rect(Rect2(p, Vector2(ds, ds)), col)

## Ritar målzonens namn vid en portalprick i fullkartan (med skugga, klippt).
func _draw_full_portal_label(tile: Vector2i, clip: Rect2, ft: int, font: Font) -> void:
	var name_str : String = _portal_names.get(tile, "")
	if name_str == "":
		return
	var p := Vector2(_full_map_origin.x + tile.x * ft,
					 _full_map_origin.y + tile.y * ft)
	if not clip.has_point(p):
		return
	var fs     := 10
	var size   := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var line_h := size.y + 3.0
	# Centrera texten över portalpricken men håll den inom kartytan.
	var tx := clampf(p.x + ft * 0.5 - size.x * 0.5,
					 clip.position.x + 1.0, clip.position.x + clip.size.x - size.x - 1.0)
	var ty := clampf(p.y - 4.0,
					 clip.position.y + size.y, clip.position.y + clip.size.y - 2.0)
	# Stapla neråt tills rutan inte krockar med en redan ritad etikett.
	var bg := _label_bg_rect(tx, ty, size)
	var tries := 0
	while _label_collides(bg) and tries < 8:
		ty += line_h
		if ty + size.y > clip.position.y + clip.size.y:
			return   # slut på plats nedåt — hoppa över denna etikett
		bg = _label_bg_rect(tx, ty, size)
		tries += 1
	if _label_collides(bg):
		return
	_label_rects.append(bg)
	# Avrunda till heltalspixlar — annars blir texten suddig på sub-pixel-pos.
	# Mörk bakgrundsruta i stället för skugg-text (rutor skalas rent, inget spöke).
	draw_rect(Rect2(bg.position.round(), bg.size.round()), Color(0.04, 0.03, 0.07, 0.82))
	draw_string(font, Vector2(roundf(tx), roundf(ty)), name_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.88, 0.78, 1.0))

## Bakgrundsruta för en etikett med 2px inre marginal.
func _label_bg_rect(tx: float, ty: float, size: Vector2) -> Rect2:
	return Rect2(Vector2(tx - 2.0, ty - size.y), Vector2(size.x + 4.0, size.y + 4.0))

## True om rutan överlappar någon redan ritad etikett denna frame.
func _label_collides(r: Rect2) -> bool:
	for other in _label_rects:
		if r.intersects(other):
			return true
	return false

func _draw_legend(lx: float, ly: float) -> void:
	var font := ThemeDB.fallback_font
	var items : Array = [
		[COL_PLAYER,  "Spelare"],
		[COL_MONSTER, "Monster"],
		[COL_LOOT,    "Föremål"],
		[COL_GRAVE,   "Gravsten"],
		[COL_PORTAL,  "Portal"],
		[COL_DUNGEON, "Dungeonentré"],
		[COL_QUEST_START,  "Quest (! starta)"],
		[COL_QUEST_ACTIVE, "Quest (? pågår)"],
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

# Mushändelser hanteras i _input (INTE _gui_input). Minimapen ligger i en
# CanvasLayer och fick inte mushändelser via _gui_input (varken scroll-zoom
# eller drag svarade). _input körs före GUI-systemet, så zoom/panorering
# fungerar pålitligt oavsett rect/z-order/mouse_filter — och kartan blir modal
# (set_input_as_handled hindrar att klick läcker till spelvärlden under).
# Vi använder get_viewport().get_mouse_position() (canvas-koordinater) så att
# positionerna matchar ritningen även med stretch-läge "canvas_items".
func _input(event: InputEvent) -> void:
	if not _full_open:
		return

	# ── Musknappar: scroll-zoom, starta drag, stäng vid klick utanför ──
	if event is InputEventMouseButton:
		var mb  := event as InputEventMouseButton
		var pos := get_viewport().get_mouse_position()
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(pos, ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(pos, -ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				# Starta alltid en potentiell panorering (stäng inte på tryck —
				# det gjorde att varje klick på kartan stängde den).
				_panning          = true
				_pan_moved        = false
				_pan_start_mouse  = pos
				_pan_start_offset = _pan_offset
				get_viewport().set_input_as_handled()
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var was_panning := _panning
				_panning = false
				# Äkta klick (ingen drag) utanför panelen = stäng kartan.
				if was_panning and not _pan_moved \
						and not _full_panel_rect.has_point(pos):
					_full_open   = false
					mouse_filter = Control.MOUSE_FILTER_IGNORE
				get_viewport().set_input_as_handled()
		return

	# ── Mus-rörelse: panorering ──
	if event is InputEventMouseMotion and _panning:
		var pos   := get_viewport().get_mouse_position()
		var delta := pos - _pan_start_mouse
		if delta.length() > 2.0:
			_pan_moved = true
		var zone  := _zone()
		var gs    : Vector2i = zone.get("grid_size") if zone != null and zone.get("grid_size") != null else Vector2i.ZERO
		var ft    := float(_full_zoom)
		var pan   := _pan_start_offset - delta / ft
		# Klippa panorering till zonens bounds
		var canvas_w := minf(float(gs.x * ft), FULL_MAX_W)
		var canvas_h := minf(float(gs.y * ft), FULL_MAX_H)
		pan.x = clampf(pan.x, 0.0, maxf(0.0, float(gs.x) - canvas_w / ft))
		pan.y = clampf(pan.y, 0.0, maxf(0.0, float(gs.y) - canvas_h / ft))
		_pan_offset = pan
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	# M öppnar/stänger (ej tangentrepetition)
	if key.keycode == KEY_M and not key.echo:
		_full_open = not _full_open
		if _full_open:
			# Centrera vyn kring spelaren när kartan öppnas
			_center_on_player()
			mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_panning     = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().set_input_as_handled()
		return
	# Piltangenter panorerar fullkartan (tangentrepetition tillåten för att hålla)
	if _full_open:
		var dir := Vector2.ZERO
		match key.keycode:
			KEY_LEFT:  dir = Vector2.LEFT
			KEY_RIGHT: dir = Vector2.RIGHT
			KEY_UP:    dir = Vector2.UP
			KEY_DOWN:  dir = Vector2.DOWN
		if dir != Vector2.ZERO:
			_pan_by_tiles(dir * PAN_STEP_TILES)
			get_viewport().set_input_as_handled()

# ────────────── Hjälpfunktioner ────────────────

func _zoom_at(screen_pos: Vector2, step: int) -> void:
	## Zooma och håll screen_pos stabil (world-koordinat under muspekaren ändras inte).
	var old_zoom := _full_zoom
	_full_zoom = clampi(_full_zoom + step, ZOOM_MIN, ZOOM_MAX)
	if _full_zoom == old_zoom:
		return
	# Räkna ut vilken tile som är under muspekaren INNAN zoom
	var tile_under := (screen_pos - _full_map_origin) / float(old_zoom)
	# Beräkna ny pan_offset så att samma tile hamnar under pekaren EFTER zoom
	var zone  := _zone()
	var gs    : Vector2i = zone.get("grid_size") if zone != null and zone.get("grid_size") != null else Vector2i.ZERO
	var ft    := float(_full_zoom)
	var canvas_w := minf(float(gs.x * ft), FULL_MAX_W)
	var canvas_h := minf(float(gs.y * ft), FULL_MAX_H)
	# Panelens inre canvas-origin (px,py + header + pad)
	var vp       := get_viewport().get_visible_rect().size
	var panel_x  := (vp.x - canvas_w - 24.0) * 0.5
	var panel_y  := (vp.y - canvas_h - 24.0 - 26.0) * 0.5
	var mx       := panel_x + 12.0
	var my       := panel_y + 26.0 + 12.0
	_pan_offset  = tile_under - (screen_pos - Vector2(mx, my)) / ft
	_pan_offset.x = clampf(_pan_offset.x, 0.0, maxf(0.0, float(gs.x) - canvas_w / ft))
	_pan_offset.y = clampf(_pan_offset.y, 0.0, maxf(0.0, float(gs.y) - canvas_h / ft))

## Panorerar fullkartan med ett antal tiles och klipper till zonens bounds.
func _pan_by_tiles(delta_tiles: Vector2) -> void:
	var zone := _zone()
	if zone == null:
		return
	var gs  : Vector2i = zone.get("grid_size") if zone.get("grid_size") != null else Vector2i.ZERO
	var ft  := float(_full_zoom)
	var canvas_w := minf(float(gs.x * ft), FULL_MAX_W)
	var canvas_h := minf(float(gs.y * ft), FULL_MAX_H)
	_pan_offset += delta_tiles
	_pan_offset.x = clampf(_pan_offset.x, 0.0, maxf(0.0, float(gs.x) - canvas_w / ft))
	_pan_offset.y = clampf(_pan_offset.y, 0.0, maxf(0.0, float(gs.y) - canvas_h / ft))

func _center_on_player() -> void:
	var zone := _zone()
	if zone == null:
		return
	var gs  : Vector2i = zone.get("grid_size") if zone.get("grid_size") != null else Vector2i.ZERO
	var ft  := float(_full_zoom)
	var canvas_w := minf(float(gs.x * ft), FULL_MAX_W)
	var canvas_h := minf(float(gs.y * ft), FULL_MAX_H)
	var pt  := _player_tile()
	_pan_offset = Vector2(float(pt.x) - canvas_w / ft * 0.5,
						  float(pt.y) - canvas_h / ft * 0.5)
	_pan_offset.x = clampf(_pan_offset.x, 0.0, maxf(0.0, float(gs.x) - canvas_w / ft))
	_pan_offset.y = clampf(_pan_offset.y, 0.0, maxf(0.0, float(gs.y) - canvas_h / ft))

# ─────────────────────────────── Helpers ───────────────────────────────

func _zone() -> Node2D:
	if not is_instance_valid(World.player):
		return null
	return World.player.zone

func _player_tile() -> Vector2i:
	if not is_instance_valid(World.player):
		return Vector2i.ZERO
	return World.player.tile

func _monsters(zone: Node2D) -> Array:
	var out : Array = []
	for child in zone.get_children():
		if child.has_method("take_damage") and child.has_method("setup"):
			if not bool(child.get("dead")):
				out.append(child)
	return out

func _ground_items(zone: Node2D) -> Array:
	var out : Array = []
	for child in zone.get_children():
		if child.get("contents") != null:
			out.append(child)
	return out

## NPC-questgivare med aktiv markör: [{tile, status}] där status = "start"/"active".
func _quest_givers(zone: Node2D) -> Array:
	var out : Array = []
	for child in zone.get_children():
		if child is DialogueNpc:
			var status := QuestSystem.giver_marker(child.npc_id)
			if status != "":
				out.append({"tile": child.tile, "status": status})
	return out
