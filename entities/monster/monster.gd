extends Node2D
## Monster-entity. Spawnas av World._spawn_monsters().

const TILE_SIZE := 32
const BAR_W := 28.0   # bredden på HpBar i tscn (-14 .. +14)

var monster_name := ""
var hp := 10
var max_hp := 10
var atk := 3
var exp := 5
var aggro_range := 5
var speed := 3.0
var cooldown := 1.0
var respawn_time := -1.0
var zone: Node2D
var tile := Vector2i.ZERO

var _path: Array = []
var _atk_timer := 0.0
var _move_t := 1.0
var _from := Vector2.ZERO
var _to   := Vector2.ZERO
var dead := false          # publik — läses av player.gd
var status_effects: Dictionary = {}  # id -> {tick_dmg, time_left, tick_acc}
var _burn_pulse := 0.0    # 0..1 för orange puls under burn

@onready var _hp_bar: ColorRect  = $HpBar
@onready var _name_lbl: Label    = $NameLabel
@onready var _click_area: Area2D = $ClickArea

func _ready() -> void:
	# Lägg till bakgrundsbar direkt bakom HpBar
	var bg := ColorRect.new()
	bg.offset_left   = -14.0
	bg.offset_top    = -20.0
	bg.offset_right  =  14.0
	bg.offset_bottom = -17.0
	bg.color = Color(0.3, 0.07, 0.07)
	add_child(bg)
	move_child(bg, _hp_bar.get_index())   # bakgrunden hamnar BAKOM hp_bar
	# Klickhantering via Area2D
	_click_area.input_event.connect(_on_click_area_input)

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if World.player != null and not dead:
			World.player.set_target(self)

func setup(mname: String, t: Vector2i, z: Node2D, respawn := -1.0) -> void:
	monster_name = mname
	tile = t
	zone = z
	respawn_time = respawn
	var d: Dictionary = MonsterDB.monsters.get(mname, {})
	hp = int(d.get("hp", 10)); max_hp = hp
	atk = int(d.get("atk", 3))
	exp = int(d.get("exp", 5))
	aggro_range = int(d.get("aggro_range", 5))
	speed = float(d.get("speed", 3.0))
	cooldown = float(d.get("cooldown", 1.0))
	position = zone.tile_to_world(tile)
	_from = position; _to = position; _move_t = 1.0
	_refresh_label()

func _refresh_label() -> void:
	if not is_node_ready():
		return
	_name_lbl.text = monster_name
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar.offset_right = -14.0 + BAR_W * ratio
	# Färg: orange puls under burn, annars grön/gul/röd
	if has_status("burn"):
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.5 + 0.5 * sin(t * 6.0)   # 3 Hz puls
		_hp_bar.color = Color(1.0, 0.45 + pulse * 0.25, 0.0)
	elif ratio > 0.5:
		_hp_bar.color = Color(0.18, 0.78, 0.18)
	elif ratio > 0.25:
		_hp_bar.color = Color(0.85, 0.72, 0.1)
	else:
		_hp_bar.color = Color(0.85, 0.12, 0.12)

func _process(delta: float) -> void:
	if dead:
		return
	_atk_timer = maxf(_atk_timer - delta, 0.0)
	_tick_statuses(delta)

	if not is_instance_valid(zone) or World.player == null:
		return
	var player_tile: Vector2i = World.player.tile
	var dist := maxi(absi(tile.x - player_tile.x), absi(tile.y - player_tile.y))

	if _move_t < 1.0:                                # pågående steg
		_move_t = minf(_move_t + delta * speed, 1.0)
		position = _from.lerp(_to, _move_t)
		return

	if dist <= 1:                                    # intill: slå
		if _atk_timer <= 0.0:
			_atk_timer = cooldown
			var raw := CombatFormulas.roll_monster(atk)
			var dmg := CombatFormulas.mitigate(raw,
				GameState.effective_skill_level("shielding") + GameState.total_shielding_bonus(),
				GameState.total_armor())
			if dmg > 0:
				GameState.take_damage(dmg)
				GameState.gain_skill_xp("shielding", 1)
			_try_apply_ability()
		return

	if dist <= aggro_range:                          # jaga
		_path = zone.find_path(tile, player_tile)
		if _path.size() > 1:
			var next: Vector2i = _path[1]
			if next != player_tile and zone.is_walkable(next):
				_step_to(next)

## Applicerar en statuseffekt på monstret (skriver över om samma id redan finns).
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
	status_effects[id] = {"tick_dmg": tick_dmg, "time_left": duration, "tick_acc": 0.0}

func has_status(id: String) -> bool:
	return status_effects.has(id)

## Tickar burn/andra statuseffekter på monstret (1 tick/s).
func _tick_statuses(delta: float) -> void:
	if status_effects.is_empty():
		return
	var burn_active_before := has_status("burn")
	for id in status_effects.keys():
		var s: Dictionary = status_effects[id]
		s["time_left"] -= delta
		s["tick_acc"]  += delta
		if s["tick_acc"] >= 1.0:
			s["tick_acc"] -= 1.0
			take_damage(float(s["tick_dmg"]))
		if s["time_left"] <= 0.0:
			status_effects.erase(id)
	# Uppdatera HP-baren om burn-status ändrades (puls → normal)
	if burn_active_before != has_status("burn"):
		_refresh_label()

## Försöker applicera monsterets ability-effekt på spelaren.
func _try_apply_ability() -> void:
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	var ab: Dictionary = d.get("ability", {})
	if ab.is_empty():
		return
	if randf() >= float(ab.get("chance", 0.0)):
		return
	match String(ab.get("type", "")):
		"poison":
			GameState.apply_status("poison",
				float(ab.get("duration", 10.0)),
				float(ab.get("tick_dmg", 3.0)))

func _step_to(next: Vector2i) -> void:
	tile = next
	_from = position
	_to = zone.tile_to_world(next)
	_move_t = 0.0

func take_damage(dmg: float) -> void:
	if dead:
		return
	hp = maxi(hp - int(dmg), 0)
	_refresh_label()
	if hp <= 0:
		_die()

func _die() -> void:
	dead = true
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	GameState.gain_exp(exp)
	var wskill := GameState.weapon_skill()
	GameState.gain_skill_xp(wskill, exp)
	var loot_table: Array = d.get("loot", [])
	for entry in loot_table:
		if randf() < float(entry.get("chance", 0.0)):
			var qty := int(entry.get("qty", 1))
			GameState.add_item(String(entry["item"]), qty)
	TaskSystem.record_kill(monster_name)
	QuestSystem.record_kill(monster_name)
	if respawn_time > 0.0:
		var t := tile
		var mn := monster_name
		var rt := respawn_time
		var zref := zone
		get_tree().create_timer(rt).timeout.connect(
			func(): if is_instance_valid(zref): World.spawn_monster(mn, t, rt))
	queue_free()
