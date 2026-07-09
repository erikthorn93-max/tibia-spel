class_name Chest3D
extends Node3D
## 3D-vy för skattkistor ur zonens chest-punkter. Samma engångsloot som 2D:s
## TreasureChest — loot-rullen (open_loot) delas därifrån. Klick inom 1 ruta
## öppnar (den generiska interactable-routern i game3d); öppnad kista sjunker
## ihop och grånar skylten, samma idiom som en uttömd gathering-nod.

const MODEL := {"file": "treasure_chest", "h": 0.55}
const INTERACT_RANGE := 1   # Chebyshev-distans, som 2D-kistan
const OPENED_SCALE := 0.7

var tile := Vector2i.ZERO
var opened := false
var _theme_id := ""
var _visual: Node3D
var _label: Label3D
var _base_scale := Vector3.ONE

func setup(t: Vector2i, theme_id: String) -> void:
	tile = t
	_theme_id = theme_id
	position = Zone3D.tile_to_world3(t)
	_build_visual()

func display_name() -> String:
	return "Skattkista"

## Klick från game3d — samma räckviddsregel och engångslogik som 2D:s _on_click.
func interact() -> void:
	if opened:
		return
	var dist := maxi(absi(GameState.player_tile.x - tile.x),
		absi(GameState.player_tile.y - tile.y))
	if dist > INTERACT_RANGE:
		if World.hud != null:
			World.hud.show_message("Gå intill kistan.")
		return
	opened = true
	var msg := TreasureChest.open_loot(_theme_id)
	if World.hud != null:
		World.hud.show_message(msg)
	_apply_opened_look()

# ── Visuellt ──────────────────────────────────────────────────────────────────
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var path := "res://assets/models3d/%s.glb" % String(MODEL["file"])
	if ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		_visual.add_child(inst)
		_base_scale = Vector3.ONE * float(MODEL["h"])
	else:
		# Platshållare: guldbrun låda, samma regel som omappade stationer.
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.5, 0.5)
		body.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.60, 0.40, 0.15)
		body.material_override = mat
		body.position.y = 0.25
		_visual.add_child(body)
	_visual.scale = _base_scale
	_label = Label3D.new()
	_label.text = display_name()
	_label.modulate = Color(0.90, 0.78, 0.20)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 9
	_label.pixel_size = 0.01
	_label.position.y = maxf(_base_scale.y, 0.5) + 0.4
	add_child(_label)

## Öppnad: sjunk ihop och gråna skylten (2D:s gråtoning i 3D-idiom).
func _apply_opened_look() -> void:
	if _visual != null:
		var tw := create_tween()
		tw.tween_property(_visual, "scale", _base_scale * OPENED_SCALE, 0.22) \
			.set_ease(Tween.EASE_OUT)
	if _label != null:
		_label.modulate = Color(0.5, 0.5, 0.5)
