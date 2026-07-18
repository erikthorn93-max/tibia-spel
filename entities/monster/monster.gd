extends Node2D
## Vy för ett monster. Spawnas av World._spawn_monsters().
## All stridslogik (skada, status, enrage, död) bor i MonsterSim — den här
## noden ritar, animerar och låter, och delegerar bakåtkompatibelt så
## befintliga anropare (player.gd, spell_system, world.gd) är oförändrade.
## AI/rörelse ligger kvar här tills nästa migrationssteg.

const TILE_SIZE := 32
const BAR_W := 28.0   # bredden på HpBar i tscn (-14 .. +14)
const SpriteFx = preload("res://world/sprite_fx.gd")

var sim: MonsterSim
var respawn_time := -1.0
var zone: Node2D

var _from := Vector2.ZERO
var _to   := Vector2.ZERO
var _breath_t := 0.0       # idle-andning, slumpad fas
var _sprite_base_y := 0.0  # spritens vilo-y (för gång-studs)
var _attacking := false    # pausar livs-anim medan attack-stöten spelas
var _status_aura: CPUParticles2D = null   # gift/brand-partiklar

# ── Delegation till simuleringen (bakåtkompatibelt API) ───────────────────────
var monster_name: String:
	get: return sim.monster_name
	set(v): sim.monster_name = v
var tile: Vector2i:
	get: return sim.tile
	set(v): sim.tile = v
var hp: int:
	get: return sim.hp
	set(v): sim.hp = v
var max_hp: int:
	get: return sim.max_hp
	set(v): sim.max_hp = v
var atk: int:
	get: return sim.atk
	set(v): sim.atk = v
var exp: int:
	get: return sim.exp
	set(v): sim.exp = v
var aggro_range: int:
	get: return sim.aggro_range
	set(v): sim.aggro_range = v
var speed: float:
	get: return sim.speed
	set(v): sim.speed = v
var cooldown: float:
	get: return sim.cooldown
	set(v): sim.cooldown = v
var dead: bool:            # publik — läses av player.gd
	get: return sim.dead
	set(v): sim.dead = v
var enraged: bool:         # publik — enrage-fas aktiv
	get: return sim.enraged
	set(v): sim.enraged = v
var is_elite: bool:        # publik — elite-variant (dubbla stats, se make_elite)
	get: return sim.is_elite
	set(v): sim.is_elite = v
var status_effects: Dictionary:
	get: return sim.status_effects

func has_status(id: String) -> bool: return sim.has_status(id)
func poison_immune() -> bool: return sim.poison_immune()
func apply_status(id: String, duration: float, tick_dmg: float) -> void:
	sim.apply_status(id, duration, tick_dmg)
func take_damage(dmg: float, crit := false, element := "") -> void:
	sim.take_damage(dmg, crit, element)
func take_charm_damage(dmg: float, element: String) -> int:
	return sim.take_charm_damage(dmg, element)
func make_elite() -> void:
	sim.make_elite()
	_refresh_label()

func _init() -> void:
	sim = MonsterSim.new()
	sim.damaged.connect(_on_sim_damaged)
	sim.charm_damaged.connect(_on_sim_charm_damaged)
	sim.element_reaction.connect(_on_sim_element_reaction)
	sim.status_changed.connect(_on_sim_status_changed)
	sim.enrage_started.connect(_on_sim_enraged)
	sim.died.connect(_on_sim_died)
	sim.moved.connect(_on_sim_moved)
	sim.attack_started.connect(_on_sim_attack_started)
	sim.ranged_attack.connect(_on_sim_ranged_attack)
	sim.player_dodged.connect(_on_sim_player_dodged)

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
	"Dvärgsoldat":             "Dvärgsoldat",
	"Dvärggeomant":            "Dvärggeomant",
	"Stenkungen Brokk":        "Stenkungen_Brokk",
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
	# Svampgrottan — lysande mykonid-fauna
	"Sporling":                   "Sporling",
	"Lysfluga":                   "Lysfluga",
	"Svampvätte":                 "Svampvätte",
	"Mykonidäldste":              "Mykonidäldste",
	"Sporkungen Myzandros":       "Sporkungen_Myzandros",
	# Frostavgrunden — frusen avgrund bortom Is-zonen
	"Rimtass":                    "Rimtass",
	"Frostvarg":                  "Frostvarg",
	"Isväktare":                  "Isväktare",
	"Glaciärjätte":               "Glaciärjätte",
	"Frostmonarken Hrimnir":      "Frostmonarken_Hrimnir",
	# Korallavgrunden — sjunken stad under Saltviks hamn
	"Revhaj":                     "Revhaj",
	"Tånggast":                   "Tånggast",
	"Korallväktare":              "Korallväktare",
	"Djupkraken":                 "Djupkraken",
	"Sjökungen Nautilex":         "Sjökungen_Nautilex",
	# Lysdjupet — bioluminescent undervattensgrotta bortom Korallavgrunden
	"Lyktfisk":                   "Lyktfisk",
	"Djupål":                     "Djupål",
	"Pansarkrabba":               "Pansarkrabba",
	"Avgrundsorm":                "Avgrundsorm",
	"Leviatanen Abyssos":         "Leviatanen_Abyssos",
	# Urdjupet — eldritch void-avgrund på världens botten
	"Tomkrälare":                 "Tomkrälare",
	"Mörkersimmare":              "Mörkersimmare",
	"Avgrundsöga":                "Avgrundsöga",
	"Urtidskväljaren":            "Urtidskväljaren",
	"Urguden Nyxoth":             "Urguden_Nyxoth",
	# Kristallgrottan — kristallväktare delar den isiga väktarens sprite
	"Kristallväktaren":           "Isväktare",
}

func _ready() -> void:
	# Markskugga vid fötterna (z bakom spriten) → monstret lyfter från marken.
	add_child(SpriteFx.make_shadow(13.0))
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
		_sprite.material = SpriteFx.outline_material()   # tunn kontur → läsbarhet
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
	# Natt-buff: +20 % atk och exp vid spawn under natten
	sim.init_stats(mname, TimeOfDay.is_night)
	zone = z
	respawn_time = respawn
	sim.place(t, z.model)
	position = zone.tile_to_world(t)
	_from = position; _to = position
	_load_sprite()
	_breath_t = randf() * 10.0        # slumpad fas så monster inte andas i takt
	if _sprite != null:
		_sprite_base_y = _sprite.position.y
	_refresh_label()

func _refresh_label() -> void:
	if not is_node_ready():
		return
	_name_lbl.text = ("★ " + monster_name) if is_elite else monster_name
	if enraged:
		_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	elif is_elite:
		_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
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

## Vyns tick: livs-anim + vidarebefordran till simuleringens AI-tick.
## Positionen interpoleras ur sim.move_progress (1.0 = vilande på _to).
func _process(delta: float) -> void:
	if dead:
		return
	_update_life_anim(delta)
	var player_tile: Variant = null
	if is_instance_valid(zone) and World.player != null:
		player_tile = World.player.tile
	sim.ai_tick(delta, player_tile)
	position = _from.lerp(_to, sim.move_progress)

## Karaktärsliv: gång-studs under ett steg, annars subtil idle-andning.
## Delar hjälpfunktioner med spelare/NPC via CharacterVisual.
func _update_life_anim(delta: float) -> void:
	if _sprite == null or _attacking:
		return
	_breath_t += delta
	if sim.move_progress < 1.0:             # mitt i ett steg → studsa
		_sprite.position.y = _sprite_base_y + CharacterVisual.walk_bob(sim.move_progress)
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

# ── Reaktioner på simuleringens signaler (rent visuellt + ljud) ───────────────
## Steg påbörjat: sätt interpolationsmål och vänd spriten mot riktningen.
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	if _sprite != null and to.x != from.x:
		_sprite.scale.x = -1.0 if to.x < from.x else 1.0
	_from = position
	_to = zone.tile_to_world(to)

## Attack inledd (före träffrull): spela lunge-stöten mot spelaren.
func _on_sim_attack_started(dir: Vector2i) -> void:
	play_attack(dir)

## Avståndsskott: projektil från monstret till spelarens ruta i monstrets
## ranged-färg (MonsterDB), med en liten träffskur vid nedslaget.
func _on_sim_ranged_attack(_from_t: Vector2i, to_t: Vector2i) -> void:
	var fx_parent := get_parent()
	if fx_parent == null or zone == null:
		return
	var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
	var rblock: Dictionary = d.get("ranged", {})
	var col := Color(String(rblock.get("color", "#e0d8c0")))
	var to_pos: Vector2 = zone.tile_to_world(to_t)
	SpellFx.projectile(fx_parent, global_position, to_pos, col,
		func(): SpellFx.burst(fx_parent, to_pos, col, 6, 55.0))

## Spelaren väjde: låt spelarens vy visa "undvek"-effekten.
func _on_sim_player_dodged() -> void:
	if World.player != null and World.player.has_method("show_dodge"):
		World.player.show_dodge()

## Träff registrerad: uppdatera bar/label, skadesiffra, röd blink och ljud.
func _on_sim_damaged(amount: int, crit: bool) -> void:
	_refresh_label()
	_spawn_damage_number(amount, crit)
	_flash_hit()
	if crit:
		Sfx.crit()
	elif sim.hp > 0:
		Sfx.hit()   # dödsträffen låter via monster_die() istället

## Elementreaktion/notering: flytande etikett som förklarar vad som hände.
func _on_sim_element_reaction(kind: String) -> void:
	match kind:
		"weak":          _spawn_element_tag("svag!", Color(1.0, 0.85, 0.2))
		"resist":        _spawn_element_tag("tål", Color(0.6, 0.7, 1.0))
		"immune":        _spawn_element_tag("immun", Color(0.6, 0.6, 0.6))
		"poison_immune": _spawn_element_tag("gift biter ej", Color(0.6, 0.72, 0.6))
		"miss":          _spawn_element_tag("miss", Color(0.72, 0.72, 0.72))
		"poisoned":      _spawn_element_tag("förgiftad", Color(0.4, 0.95, 0.4))
		"stunned":       _spawn_element_tag("bedövad", Color(1.0, 0.9, 0.4))

## Status lades till/tickade ut: uppdatera aura och HP-barens burn-puls.
func _on_sim_status_changed() -> void:
	_update_status_aura()
	_refresh_label()

## Enrage: sim har redan höjt speed/atk — vyn visar rött namn + röd bar.
func _on_sim_enraged() -> void:
	_refresh_label()

## Liten flytande etikett ("svag!"/"tål"/"immun") ovanför monstret som förklarar
## varför skadesiffran avviker — gör elementtaktiken läsbar för spelaren.
func _spawn_element_tag(text: String, color: Color) -> void:
	var parent := get_parent() if get_parent() != null else self
	var t: Node2D = preload("res://entities/floating_text.gd").new()
	parent.add_child(t)
	t.global_position = global_position + Vector2(randf_range(-6, 6), -24)
	t.setup(text, color, 11)

## Visar en "miss"-etikett när spelarens slag bommar (träffchans missade).
func show_miss() -> void:
	_spawn_element_tag("miss", Color(0.72, 0.72, 0.72))

## Charm-bonusskada: egen färgad siffra + charm-ljud, så den läses som ett
## separat tillägg ovanpå den vanliga träffen.
func _on_sim_charm_damaged(amount: int, element: String) -> void:
	_refresh_label()
	var dn: Node2D = preload("res://entities/damage_number.gd").new()
	var parent := get_parent() if get_parent() != null else self
	parent.add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-6, 6), -16)
	dn.setup(amount, false, CharmSystem.element_color(element))
	_flash_hit()
	Sfx.charm(element)

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

## Döden är redan bokförd i sim (exp, kills, loot-rull, tilen frigjord) —
## vyn spawnar ground items, spelar dödsskur/ljud, schemalägger respawn
## och tonar ut.
func _on_sim_died(drops: Array) -> void:
	if not drops.is_empty():
		var gi := preload("res://entities/ground_item.gd").new()
		var parent := get_parent() if get_parent() != null else self
		parent.add_child(gi)
		gi.setup(drops, tile)
	# --- DÖDSSKUR: typad effekt (ben/slem/glöd/is/stoft) + glitter om loot föll ---
	var fx_parent := get_parent()
	if fx_parent != null:
		var d: Dictionary = MonsterDB.monsters.get(monster_name, {})
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
