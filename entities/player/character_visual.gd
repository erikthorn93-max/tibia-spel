class_name CharacterVisual
extends Node2D
## Tibia-stil spelare-sprite med Sprite2D. Liv via gång-studs + idle-andning.

const BASE_Y := -4.0       # spritens vilo-y (fotpunkt mitt i tile)
const BOB_AMP := 3.0       # studs-höjd (px) mitt i ett steg
const BREATH_AMP := 0.03   # andnings-amplitud (skala)
const BREATH_SPEED := 2.2

var _sprite: Sprite2D
var _walking := false
var _walk_progress := 0.0
var _breath_t := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = load("res://assets/sprites/player.png") as Texture2D
	if tex:
		_sprite.texture = tex
	# Centrera spriten: origo på spelarens fotpunkt (mitten av tile)
	_sprite.position = Vector2(0, BASE_Y)
	add_child(_sprite)

## Vertikal studs (px, negativ = uppåt) vid en stegprogress 0..1. Topp mitt i.
static func walk_bob(progress: float) -> float:
	return -BOB_AMP * sin(clampf(progress, 0.0, 1.0) * PI)

## Subtil andnings-skala kring 1.0 över tid (sekunder).
static func breath_scale(time: float) -> float:
	return 1.0 + BREATH_AMP * sin(time * BREATH_SPEED)

## Spelaren matar rörelsestatus varje frame: studs under steg, annars andning.
func set_walk(moving: bool, progress: float) -> void:
	_walking = moving
	_walk_progress = progress

func _process(delta: float) -> void:
	if _sprite == null:
		return
	_breath_t += delta
	if _walking:
		_sprite.position.y = BASE_Y + walk_bob(_walk_progress)
		_sprite.scale.y = 1.0
	else:
		_sprite.position.y = BASE_Y
		_sprite.scale.y = breath_scale(_breath_t)

func apply_appearance(_appearance: Dictionary) -> void:
	pass   # reserverat för framtida palette-swap

func face(dir: Vector2i) -> void:
	scale.x = -1.0 if dir.x < 0 else 1.0

## Squish-animation vid attack: sträck ut i attackriktningen, studsa tillbaka.
func play_attack(dir: Vector2i) -> void:
	var sx := 1.3 if dir.x != 0 else 0.75
	var sy := 0.75 if dir.x != 0 else 1.3
	var flip := scale.x   # bevara vänster/höger-riktning
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(flip * sx, sy), 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(flip * 1.0, 1.0), 0.14).set_ease(Tween.EASE_IN_OUT)

## Blink-flash vid skada: röd tona → vit.
func play_hurt() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.4), 0.04)
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
