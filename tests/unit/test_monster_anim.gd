extends GutTest
## Testar monstrens karaktärsliv: gång-studs under steg, idle-andning i vila.
## Mockar _update_life_anim-logiken (delar CharacterVisual-matematiken med spelaren).

const CV = preload("res://entities/player/character_visual.gd")

## Mock som replikerar monster.gd:s animationslogik utan scene-/zonberoenden.
class MockMonster:
	var _sprite := Sprite2D.new()
	var _breath_t := 0.0
	var _sprite_base_y := 0.0
	var _move_t := 1.0

	func _update_life_anim(delta: float) -> void:
		if _sprite == null:
			return
		_breath_t += delta
		if _move_t < 1.0:
			_sprite.position.y = _sprite_base_y + CV.walk_bob(_move_t)
			_sprite.scale.y = 1.0
		else:
			_sprite.position.y = _sprite_base_y
			_sprite.scale.y = CV.breath_scale(_breath_t)

var _m: MockMonster

func before_each() -> void:
	_m = MockMonster.new()

func after_each() -> void:
	_m._sprite.free()

# --- gång-studs ---

func test_studs_lyfter_spriten_mitt_i_steget() -> void:
	_m._move_t = 0.5                       # mitt i ett steg
	_m._update_life_anim(0.016)
	assert_lt(_m._sprite.position.y, _m._sprite_base_y, "spriten ska lyftas (studsa) mitt i steget")

func test_ingen_skala_under_gang() -> void:
	_m._move_t = 0.5
	_m._update_life_anim(0.016)
	assert_almost_eq(_m._sprite.scale.y, 1.0, 0.001, "ingen andnings-skala medan monstret går")

func test_studs_aterstaller_y_vid_stegslut() -> void:
	_m._move_t = 1.0                       # steget klart → tillbaka i vila
	_m._update_life_anim(0.0)
	assert_almost_eq(_m._sprite.position.y, _m._sprite_base_y, 0.01, "y ska återställas i vila")

# --- idle-andning ---

func test_andning_skalar_spriten_i_vila() -> void:
	_m._move_t = 1.0
	var saw_above := false
	var saw_below := false
	for i in 200:
		_m._update_life_anim(0.05)
		if _m._sprite.scale.y > 1.0: saw_above = true
		if _m._sprite.scale.y < 1.0: saw_below = true
	assert_true(saw_above and saw_below, "andningen ska pulsera kring 1.0 i vila")
