class_name GroundItem3D
extends Node3D
## Lootpåse på marken i 3D — motsvarigheten till 2D:s GroundItem.
## Klick inom 1 tile = plocka allt (routas via game3d:s _interactable_at,
## samma mönster som NPC:er/stationer). Försvinner efter LIFETIME sekunder
## och blinkar sista BLINK_START sekunderna; grav-loot är persistent och
## rensar GameState-graven vid pickup. Guldromb som platshållarvisual —
## material skapas EN gång vid setup.

## Tider delas med 2D-vyn (en källa).
const LIFETIME := GroundItem.LIFETIME
const BLINK_START := GroundItem.BLINK_START

var contents: Array = []            # [{item: String, qty: int}]
var tile := Vector2i.ZERO
var lifetime_override := -1.0       # om > 0 ersätter LIFETIME
var persistent := false             # true = försvinner aldrig (grav-loot)
var is_grave := false               # true = rensar GameState-graven vid pickup
var fx: FloatingText3D = null       # delad flyttext-pool, sätts av game3d

var _elapsed := 0.0
var _visual: MeshInstance3D

func setup(drops: Array, t: Vector2i) -> void:
	contents = drops
	tile = t
	position = Zone3D.tile_to_world3(t)
	_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.26, 0.26)
	_visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e8c84a")
	mat.emission_enabled = true
	mat.emission = Color("e8c84a")
	mat.emission_energy_multiplier = 0.6
	_visual.material_override = mat
	_visual.rotation_degrees = Vector3(45.0, 0.0, 45.0)   # romb, som 2D-ikonen
	_visual.position.y = 0.3
	add_child(_visual)
	# Pop in när påsen landar
	scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _visual != null:
		_visual.rotation.y += delta * 1.2   # långsam snurr så looten syns
	if persistent:
		return   # grav-loot tickar inte ned och blinkar inte
	_elapsed += delta
	var lifetime := lifetime_override if lifetime_override > 0.0 else LIFETIME
	var time_left := lifetime - _elapsed
	if time_left <= 0.0:
		queue_free()
		return
	if _visual == null:
		return
	# Blinka snabbt under sista BLINK_START sekunder
	if time_left <= BLINK_START:
		_visual.visible = fmod(_elapsed * 5.0, 1.0) < 0.5
	else:
		_visual.visible = true

## Klick från game3d — samma räckviddsregel som 2D:s GroundItem (1 ruta).
func interact() -> void:
	var pt := GameState.player_tile
	if maxi(absi(pt.x - tile.x), absi(pt.y - tile.y)) > 1:
		if World.hud != null:
			World.hud.show_message("För långt bort.")
		return
	_collect()

func _collect() -> void:
	var oy := 0.0
	for d in contents:
		GameState.add_item(String(d["item"]), int(d["qty"]))
		if fx != null:
			var iname := String(ItemDB.items.get(String(d["item"]), {}).get("name", d["item"]))
			fx.show_text(position + Vector3(0, 0.5 + oy, 0),
				"+%d %s" % [int(d["qty"]), iname], Color(0.96, 0.86, 0.42))
			oy += 0.35   # stapla flera föremål uppåt
	if is_grave:
		GameState.clear_grave()   # graven är tömd
	Sfx.pickup()
	queue_free()
