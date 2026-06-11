class_name Monster
extends Node2D
## Monster: aggro -> A*-jakt -> melee. Fryser AI när spelaren är långt borta.

const FREEZE_DIST := 30        # tiles; bortom detta: ingen AI alls
const TILE := 32

var monster_name := ""
var hp := 0.0
var max_hp := 0.0
var atk := 0
var speed := 2.0               # tiles/sek
var cooldown := 1.5
var aggro_range := 6
var exp_reward := 0
var loot_table: Array = []
var respawn_time := -1.0
var home_tile := Vector2i.ZERO

var zone: Node2D
var tile := Vector2i.ZERO
var _move_t := 1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _atk_timer := 0.0
var _path: Array = []
var dead := false

@onready var body: Polygon2D = $Body
@onready var hp_bar: ColorRect = $HpBar
@onready var name_lbl: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea

func setup(mname: String, t: Vector2i, z: Node2D, respawn := -1.0) -> void:
	monster_name = mname
	zone = z
	home_tile = t
	respawn_time = respawn
	var d: Dictionary = MonsterDB.monsters[mname]
	max_hp = float(d["hp"]); hp = max_hp
	atk = int(d["atk"]); exp_reward = int(d["exp"])
	speed = float(d["speed"]); cooldown = float(d["cooldown"])
	aggro_range = int(d["aggro"]); loot_table = d["loot"]
	tile = t
	position = zone.tile_to_world(t)
	body.color = Color(d["color"])
	name_lbl.text = mname
	_update_hp_bar()

func _ready() -> void:
	click_area.input_event.connect(_on_click)

func _on_click(_vp, event: InputEvent, _shape) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dead:
			World.player.set_target(self)

func _process(delta: float) -> void:
	if dead or World.player == null:
		return
	var player_tile: Vector2i = GameState.player_tile
	var dist := maxi(absi(player_tile.x - tile.x), absi(player_tile.y - tile.y))
	if dist > FREEZE_DIST:
		return                                       # prestanda: frys helt
	_atk_timer = maxf(_atk_timer - delta, 0.0)

	if _move_t < 1.0:                                # pågående steg
		_move_t = minf(_move_t + delta * speed, 1.0)
		position = _from.lerp(_to, _move_t)
		return

	if dist <= 1:                                    # intill: slå
		if _atk_timer <= 0.0:
			_atk_timer = cooldown
			var raw := CombatFormulas.roll_monster(atk)
			var dmg := CombatFormulas.mitigate(raw, GameState.effective_skill_level("shielding"), 2)
			if dmg > 0:
				GameState.take_damage(dmg)
				GameState.gain_skill_xp("shielding", 1)
		return

	if dist <= aggro_range:                          # jaga
		_path = zone.find_path(tile, player_tile)
		if _path.size() > 1:
			var next: Vector2i = _path[1]
			if next != player_tile and zone.is_walkable(next):
				_step_to(next)

func _step_to(next: Vector2i) -> void:
	tile = next
	_from = position
	_to = zone.tile_to_world(next)
	_move_t = 0.0

func take_damage(dmg: float) -> void:
	if dead:
		return
	hp = maxf(hp - dmg, 0.0)
	_update_hp_bar()
	if hp <= 0.0:
		_die()

func _update_hp_bar() -> void:
	hp_bar.size.x = 28.0 * (hp / max_hp)
	hp_bar.color = Color.GREEN if hp / max_hp > 0.5 else (Color.YELLOW if hp / max_hp > 0.25 else Color.RED)

func _die() -> void:
	dead = true
	GameState.gain_exp(exp_reward)
	var drops: Array = ItemDB.roll_loot(loot_table)
	if not drops.is_empty():
		var gi := preload("res://entities/ground_item.gd").new()
		zone.add_child(gi)
		gi.setup(drops, tile)
	if respawn_time > 0.0:
		var t := get_tree().create_timer(respawn_time)
		var mname := monster_name
		var ht := home_tile
		var rt := respawn_time
		t.timeout.connect(func(): if is_instance_valid(zone): World.spawn_monster(mname, ht, rt))
	if World.player and World.player.target == self:
		World.player.set_target(null)
	queue_free()
