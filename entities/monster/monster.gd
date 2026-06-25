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
var enraged := false       # publik — enrage-fas aktiv
var _breath_t := 0.0       # idle-andning, slumpad fas
var _sprite_base_y := 0.0  # spritens vilo-y (för gång-studs)
var _attacking := false    # pausar livs-anim medan attack-stöten spelas
var _status_aura: CPUParticles2D = null   # gift/brand-partiklar

@onready var _hp_bar: ColorRect  = $HpBar
@onready var _name_lbl: Label    = $NameLabel
@onready var _click_area: Area2D = $ClickArea
@onready var _sprite: Sprite2D   = $Sprite2D

## Namn → sprite-filnamn (utan .png). Används i _load_sprite().
const SPRITE_MAP: Dictionary = {
	"Råtta":                   "ratta",
	"Orm":                     "orm",
	"Spindel":                 "spindel",
	"Skelett":                 "skelett",
	"Skogsvargen":             "skogsvargen",
	"Skogsbjörn":              "skogsbjorn",
	"Ghoul":                   "ghoul",
	"Pirat":                   "pirat",
	"Pirat Skytt":             "pirat_skytt",
	"Strandkrabba":            "strandkrabba",
	"Giftpadda":               "giftpadda",
	"Sumpvarelse":             "sumpvarelse",
	"Sumpkräla":               "sumpkrala",
	"Träskdjävul":             "traskdjavul",
	"Isvarelse":               "isvarelse",
	"Istroll":                 "istroll",
	"Isdraken":                "isdraken",
	"Frostörn":                "frostorn",
	"Snöuggla":                "snouggla",
	"Ökengam":                 "okengam",
	"Ökenmumie":               "okenmumie",
	"Sandorm":                 "sandorm",
	"Sandvaranen":             "sandvaranen",
	"Sjöorm":                  "sjoorm",
	"Skelettkrigare":          "skelettkrigare",
	"Glödmask":                "glodmask",
	"Lavavarelse":             "lavavarelse",
	"Sotdemon":                "sotdemon",
	"Askhök":                  "askhok",
	"Fantom":                  "fantom",
	"Jättespindel":            "jattespindel",
	"Drunknad sjöman":         "drunknad_sjoman",
	"Farao Khem-Ra":           "farao_khem-ra",
	"Ghulkungen":              "ghulkungen",
	"Piratkapten Svartöga":    "piratkapten_svartoga",
	"Smältkonungen":           "smaltkonungen",
	"Urskogsvältaren":         "urskogsvaltaren",
	# Nya monster
	"Varg":                    "Varg",
	"Goblin":                  "Goblin",
	"Goblinsoldat":            "Goblinsoldat",
	"Bandit":                  "Bandit",
	"Troll":                   "Troll",
	"Trollhövding":            "Trollhövding",
	"Ork":                     "Ork",
	"Orkshamanen":             "Orkshamanen",
	"Orköverherre":            "Orköverherre",
	"Minotaur":                "Minotaur",
	"MinotaurVakt":            "MinotaurVakt",
	"MinotaurKungen":          "MinotaurKungen",
	"Dvärg":                   "Dvärg",
	"DvärgenSmeden":           "DvärgenSmeden",
	"Vampyr":                  "Vampyr",
	"VampyrHerre":             "VampyrHerre",
	"Nekromant":               "Nekromant",
	"Lich":                    "Lich",
	"Elddraken":               "Elddraken",
	"Ärkedemonen":             "Ärkedemonen",
	# Glödöknen — region bortom öknen
	"Glödskorpion":               "Glödskorpion",
	"Sandskarabé":                "Sandskarabé",
	"Sandvålnad":                 "Sandvålnad",
	"Gravväktare":                "Gravväktare",
	"Solkonungen Akh-Mortis":     "Solkonungen_Akh-Mortis",
	# Spindelgrotta & nybörjarfauna
	"Grottspindel":               "Grottspindel",
	"Giftvävare":                 "Giftvävare",
	"Skuggspindel":               "Skuggspindel",
	"Spindeldrottningen Morwena": "Spindeldrottningen_Morwena",
	"Fältmus":                    "Fältmus",
	"Vildkanin":                  "Vildkanin",
	"Åkerkråka":                  "Åkerkråka",
	"Vildsvin":                   "Vildsvin",
}

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
	_build_status_aura()
	# Klickhantering via Area2D
	_click_area.input_event.connect(_on_click_area_input)

## Partikel-aura som visar pågående status (gift = grön, brand = orange).
func _build_status_aura() -> void:
	_status_aura = CPUParticles2D.new()
	_status_aura.emitting = false
	_status_aura.amount = 8
	_status_aura.lifetime = 0.7
	_status_aura.direction = Vector2(0, -1)
	_status_aura.spread = 25.0
	_status_aura.initial_velocity_min = 10.0
	_status_aura.initial_velocity_max = 22.0
	_status_aura.gravity = Vector2(0, -10)
	_status_aura.scale_amount_min = 1.5
	_status_aura.scale_amount_max = 2.5
	add_child(_status_aura)

## Slår på/av auran utifrån aktiv status.
func _update_status_aura() -> void:
	if _status_aura == null:
		return
	if has_status("poison"):
		_status_aura.color = Color(0.40, 0.95, 0.35)
		_status_aura.emitting = true
	elif has_status("burn"):
		_status_aura.color = Color(1.0, 0.50, 0.12)
		_status_aura.emitting = true
	else:
		_status_aura.emitting = false

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if World.player != null and not dead:
			World.player.set_target(self)

func _load_sprite() -> void:
	var key: String = str(SPRITE_MAP.get(monster_name, ""))
	var tex: Texture2D = null
	if not key.is_empty():
		var path := "res://assets/sprites/monsters/%s.png" % key
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
	if tex != null:
		_sprite.texture = tex
	else:
		_add_fallback_shape()   # säkerställ att monstret aldrig blir osynligt

## Färgad diamant (monstrets color-fält) när en sprite saknas — fallback så
## att även framtida monster utan grafik fortfarande syns.
func _add_fallback_shape() -> void:
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	var col := Color(String(d.get("color", "#aa3333")))
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(11, 0), Vector2(0, 12), Vector2(-11, 0)])
	poly.color = col
	add_child(poly)
	push_warning("Monster sprite saknas (%s) — använder fallback-form" % monster_name)

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
	# Natt-buff: +20 % atk och exp vid spawn under natten
	if TimeOfDay.is_night:
		atk = int(float(atk) * 1.2)
		exp = int(float(exp) * 1.2)
	position = zone.tile_to_world(tile)
	_from = position; _to = position; _move_t = 1.0
	zone.occupy(tile, self)
	_load_sprite()
	_breath_t = randf() * 10.0        # slumpad fas så monster inte andas i takt
	if _sprite != null:
		_sprite_base_y = _sprite.position.y
	_refresh_label()

func _refresh_label() -> void:
	if not is_node_ready():
		return
	_name_lbl.text = monster_name
	if enraged:
		_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	else:
		_name_lbl.remove_theme_color_override("font_color")
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar.offset_right = -14.0 + BAR_W * ratio
	# Färg: orange puls under burn, annars grön/gul/röd
	if has_status("burn"):
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.5 + 0.5 * sin(t * 6.0)   # 3 Hz puls
		_hp_bar.color = Color(1.0, 0.45 + pulse * 0.25, 0.0)
	elif enraged:
		_hp_bar.color = Color(1.0, 0.2, 0.2)
	elif ratio > 0.5:
		_hp_bar.color = Color(0.18, 0.78, 0.18)
	elif ratio > 0.25:
		_hp_bar.color = Color(0.85, 0.72, 0.1)
	else:
		_hp_bar.color = Color(0.85, 0.12, 0.12)

func _process(delta: float) -> void:
	if dead:
		return
	_update_life_anim(delta)
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
			play_attack(player_tile - tile)
			var raw := CombatFormulas.roll_monster(atk)
			var dmg := CombatFormulas.mitigate(raw,
				GameState.effective_skill_level("shielding") + GameState.total_shielding_bonus(),
				GameState.total_armor() + GameState.total_def_bonus())
			if dmg > 0:
				GameState.take_damage(dmg)
				GameState.gain_skill_xp("shielding", 1)
			_try_apply_ability()
		return

	if dist <= aggro_range:                          # jaga
		_path = zone.find_path(tile, player_tile)
		if _path.size() > 1:
			var next: Vector2i = _path[1]
			if next != player_tile and zone.is_walkable(next) and not zone.is_occupied(next):
				_step_to(next)

## Karaktärsliv: gång-studs under ett steg, annars subtil idle-andning.
## Delar hjälpfunktioner med spelare/NPC via CharacterVisual.
func _update_life_anim(delta: float) -> void:
	if _sprite == null or _attacking:
		return
	_breath_t += delta
	if _move_t < 1.0:                       # mitt i ett steg → studsa
		_sprite.position.y = _sprite_base_y + CharacterVisual.walk_bob(_move_t)
		_sprite.scale.y = 1.0
	else:                                   # stillastående → andas
		_sprite.position.y = _sprite_base_y
		_sprite.scale.y = CharacterVisual.breath_scale(_breath_t)

## Attack-stöt: monstret lutar sig snabbt mot spelaren och studsar tillbaka.
## Pausar idle-/gång-anim så tweenen får styra spriten ostört.
func play_attack(dir: Vector2i) -> void:
	if _sprite == null:
		return
	var d := Vector2(dir.x, dir.y)
	if d == Vector2.ZERO:
		return
	var lunge := d.normalized() * 7.0
	_attacking = true
	var rest := Vector2(0.0, _sprite_base_y)
	var tw := create_tween()
	tw.tween_property(_sprite, "position", rest + lunge, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position", rest, 0.13).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _attacking = false)

## Applicerar en statuseffekt på monstret (skriver över om samma id redan finns).
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
	status_effects[id] = {"tick_dmg": tick_dmg, "time_left": duration, "tick_acc": 0.0}
	_update_status_aura()

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
			take_damage(float(s["tick_dmg"]), false)
		if s["time_left"] <= 0.0:
			status_effects.erase(id)
	# Uppdatera HP-baren om burn-status ändrades (puls → normal)
	if burn_active_before != has_status("burn"):
		_refresh_label()
	_update_status_aura()   # släck/uppdatera auran när status tickar ut

## Kontrollerar om monstret ska gå in i enrage-fas (kallas från take_damage).
func _check_enrage() -> void:
	if enraged:
		return   # enrage kan bara triggas en gång
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	if not bool(d.get("enrage", false)):
		return
	if float(hp) > float(max_hp) * 0.5:
		return
	enraged = true
	speed   *= 1.5
	atk      = int(float(atk) * 1.5)
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
		"burn":
			GameState.apply_status("burn",
				float(ab.get("duration", 6.0)),
				float(ab.get("tick_dmg", 6.0)))
		"drain":
			GameState.drain_mana(float(ab.get("tick_dmg", 10.0)))
		"stun":
			GameState.apply_status("stun",
				float(ab.get("duration", 2.0)), 0.0)
		"slow":
			GameState.apply_status("slow",
				float(ab.get("duration", 3.0)), 0.0)

func _step_to(next: Vector2i) -> void:
	zone.vacate(tile)
	zone.occupy(next, self)
	# Vänd spriten mot rörelseriktningen (vänster/höger)
	if _sprite != null and next.x != tile.x:
		_sprite.scale.x = -1.0 if next.x < tile.x else 1.0
	tile = next
	_from = position
	_to = zone.tile_to_world(next)
	_move_t = 0.0

func _make_elite(m: Node2D) -> void:
	pass   # kallas inte härifrån, finns i world.gd

func take_damage(dmg: float, crit := false) -> void:
	if dead:
		return
	hp = maxi(hp - int(dmg), 0)
	_check_enrage()
	_refresh_label()
	_spawn_damage_number(dmg, crit)
	# --- ANIMATION: röd blink vid träff ---
	_flash_hit()
	if crit:
		Sfx.crit()
	if hp <= 0:
		_die()
	elif not crit:
		Sfx.hit()

## Kort röd blink när monstret tar skada.
func _flash_hit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.3, 0.3), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)

func _spawn_damage_number(dmg: float, crit := false) -> void:
	var dn: Node2D = preload("res://entities/damage_number.gd").new()
	var parent := get_parent() if get_parent() != null else self
	parent.add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-6, 6), -8)
	dn.setup(dmg, crit)

func _die() -> void:
	dead = true
	if is_instance_valid(zone):
		zone.vacate(tile)
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	GameState.gain_exp(exp)
	var wskill := GameState.weapon_skill()
	GameState.gain_skill_xp(wskill, exp)
	# Rulla loot → samla drops, spawna som GroundItem i zonen
	var loot_table: Array = d.get("loot", [])
	var drops: Array = []
	for entry in loot_table:
		if randf() < float(entry.get("chance", 0.0)):
			var qty_min := int(entry.get("min", int(entry.get("qty", 1))))
			var qty_max := int(entry.get("max", qty_min))
			drops.append({
				"item": String(entry["item"]),
				"qty":  randi_range(qty_min, qty_max)
			})
	if not drops.is_empty():
		var gi := preload("res://entities/ground_item.gd").new()
		var parent := get_parent() if get_parent() != null else self
		parent.add_child(gi)
		gi.setup(drops, tile)
	TaskSystem.record_kill(monster_name)
	QuestSystem.record_kill(monster_name)
	# --- DÖDSSKUR: typad effekt (ben/slem/glöd/is/stoft) + glitter om loot föll ---
	var fx_parent := get_parent()
	if fx_parent != null:
		var base_col := Color(String(d.get("color", "#aa3333")))
		var kind := SpellFx.death_kind(monster_name)
		SpellFx.death_burst(fx_parent, global_position, base_col, kind)
		if not drops.is_empty():
			SpellFx.fountain(fx_parent, global_position, Color(1.0, 0.92, 0.45), 8)
	Sfx.monster_die()
	if respawn_time > 0.0:
		var t  := tile
		var mn := monster_name
		var rt := respawn_time
		var zref := zone
		get_tree().create_timer(rt).timeout.connect(
			func(): if is_instance_valid(zref): World.spawn_monster(mn, t, rt))
	# --- ANIMATION: krymper och tonar ut innan queue_free ---
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
