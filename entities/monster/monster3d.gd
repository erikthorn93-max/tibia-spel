class_name Monster3D
extends Node3D
## 3D-vy för ett monster: samma MonsterSim som 2D-vyn (monster.gd) äger AI,
## rörelse och strid — den här noden ritar kroppen, hp-baren och attack-stöten.
## Monster med mappning i MODELS får sin GLB-modell (assets/models3d,
## normaliserad till 1,0 m höjd med fötterna på y=0); övriga behåller
## platshållarlådan i databasfärg. Spawnas av game3d; loot-drops på marken är
## 2D-bundna och hoppas över i slicen (exp/kills bokförs ändå av simuleringen).

const BAR_W := 0.8

## GLB per monsternamn + världshöjd i meter (modellerna är 1,0 m höga).
## Meshy-modeller för karaktärerna, procedurala kreatur (creature_*, byggda
## av tools/build_creature_models.py) för spindlar/ormar/fåglar/paddor/
## krabbor. Bara naturliga matchningar; resten får platshållarlåda.
const MODELS := {
	"Råtta":           {"file": "rat", "h": 0.5},
	"Fältmus":         {"file": "rat", "h": 0.3},
	"Vildkanin":       {"file": "rabbit", "h": 0.4},
	"Varg":            {"file": "wolf", "h": 0.8},
	"Skogsvargen":     {"file": "wolf", "h": 1.0},
	"Frostvarg":       {"file": "wolf", "h": 0.85},
	"Rimtass":         {"file": "wolf", "h": 0.6},
	"Skogsbjörn":      {"file": "bear", "h": 1.2},
	"Skelett":         {"file": "skeleton", "h": 1.6},
	"Skelettkrigare":  {"file": "skeleton", "h": 1.7},
	"Gravväktare":     {"file": "skeleton", "h": 1.8},
	"Ghoul":           {"file": "zombie", "h": 1.6},
	"Drunknad sjöman": {"file": "zombie", "h": 1.6},
	"Ökenmumie":       {"file": "zombie", "h": 1.6},
	"Ghulkungen":      {"file": "zombie", "h": 2.0},
	"Ork":             {"file": "orc", "h": 1.7},
	"Orkshamanen":     {"file": "orc", "h": 1.7},
	"Orköverherre":    {"file": "orc", "h": 2.1},
	"Goblin":          {"file": "orc", "h": 1.1},
	"Goblinsoldat":    {"file": "orc", "h": 1.2},
	"Bandit":          {"file": "middle_aged_man", "h": 1.7},
	"Pirat":           {"file": "middle_aged_man", "h": 1.7},
	"Pirat Skytt":     {"file": "middle_aged_man", "h": 1.7},
	"Piratkapten Svartöga": {"file": "middle_aged_man", "h": 1.8},
	"Spindel":         {"file": "creature_spider_brown", "h": 0.5},
	"Jättespindel":    {"file": "creature_spider_brown", "h": 0.9},
	"Grottspindel":    {"file": "creature_spider_dark", "h": 0.6},
	"Skuggspindel":    {"file": "creature_spider_dark", "h": 0.55},
	"Giftvävare":      {"file": "creature_spider_green", "h": 0.6},
	"Spindeldrottningen Morwena": {"file": "creature_spider_dark", "h": 1.1},
	"Orm":             {"file": "creature_snake_green", "h": 0.35},
	"Sumpkräla":       {"file": "creature_snake_green", "h": 0.4},
	"Sandorm":         {"file": "creature_snake_sand", "h": 0.5},
	"Sjöorm":          {"file": "creature_snake_blue", "h": 0.7},
	"Djupål":          {"file": "creature_snake_blue", "h": 0.4},
	"Avgrundsorm":     {"file": "creature_snake_dark", "h": 0.9},
	"Tomkrälare":      {"file": "creature_snake_dark", "h": 0.4},
	"Glödmask":        {"file": "creature_snake_ember", "h": 0.35},
	"Åkerkråka":       {"file": "creature_bird_dark", "h": 0.45},
	"Askhök":          {"file": "creature_bird_dark", "h": 0.5},
	"Frostörn":        {"file": "creature_bird_white", "h": 0.6},
	"Snöuggla":        {"file": "creature_bird_white", "h": 0.5},
	"Ökengam":         {"file": "creature_bird_brown", "h": 0.55},
	"Giftpadda":       {"file": "creature_toad_green", "h": 0.4},
	"Strandkrabba":    {"file": "creature_crab_red", "h": 0.35},
	"Pansarkrabba":    {"file": "creature_crab_dark", "h": 0.5},
	"Lavavarelse":     {"file": "creature_blob_lava", "h": 0.9},
	"Smältkonungen":   {"file": "creature_blob_lava", "h": 1.4},
	"Isvarelse":       {"file": "creature_blob_ice", "h": 0.9},
	"Sumpvarelse":     {"file": "creature_blob_swamp", "h": 0.9},
	"Träskdjävul":     {"file": "creature_blob_swamp", "h": 1.1},
	"Sotdemon":        {"file": "creature_blob_dark", "h": 1.0},
	"Sporling":        {"file": "creature_mushroom_green", "h": 0.5},
	"Svampvätte":      {"file": "creature_mushroom_brown", "h": 0.8},
	"Mykonidäldste":   {"file": "creature_mushroom_purple", "h": 1.2},
	"Sporkungen Myzandros": {"file": "creature_mushroom_purple", "h": 1.6},
	"Fantom":          {"file": "creature_ghost_pale", "h": 1.3},
	"Sandvålnad":      {"file": "creature_ghost_sand", "h": 1.3},
	"Tånggast":        {"file": "creature_ghost_kelp", "h": 1.2},
	"Isväktare":       {"file": "creature_golem_ice", "h": 1.6},
	"Glaciärjätte":    {"file": "creature_golem_ice", "h": 2.2},
	"Frostmonarken Hrimnir": {"file": "creature_golem_ice", "h": 2.4},
	"Istroll":         {"file": "creature_golem_ice", "h": 1.4},
	"Kristallväktaren": {"file": "creature_golem_crystal", "h": 1.8},
	"Korallväktare":   {"file": "creature_golem_coral", "h": 1.6},
	"Stenkungen Brokk": {"file": "creature_golem_stone", "h": 2.0},
	"Urskogsvältaren": {"file": "creature_golem_wood", "h": 2.0},
	"Revhaj":          {"file": "creature_fish_shark", "h": 0.8},
	"Mörkersimmare":   {"file": "creature_fish_dark", "h": 0.6},
	"Lyktfisk":        {"file": "creature_fish_lantern", "h": 0.5},
	"Glödskorpion":    {"file": "creature_scorpion_ember", "h": 0.5},
	"Sandskarabé":     {"file": "creature_beetle_sand", "h": 0.4},
	"Djupkraken":      {"file": "creature_kraken_deep", "h": 1.6},
	"Sjökungen Nautilex": {"file": "creature_kraken_deep", "h": 2.0},
	"Urtidskväljaren": {"file": "creature_kraken_dark", "h": 1.4},
	"Avgrundsöga":     {"file": "creature_eye_dark", "h": 1.0},
	"Urguden Nyxoth":  {"file": "creature_eye_elder", "h": 1.8},
	"Lysfluga":        {"file": "creature_firefly_glow", "h": 0.35},
	"Sandvaranen":     {"file": "creature_lizard_sand", "h": 0.5},
	"Farao Khem-Ra":   {"file": "zombie", "h": 1.8},
	"Solkonungen Akh-Mortis": {"file": "skeleton", "h": 1.9},
	"Leviatanen Abyssos": {"file": "creature_snake_blue", "h": 1.3},
	"Troll":           {"file": "creature_brute_green", "h": 1.6},
	"Trollhövding":    {"file": "creature_brute_green", "h": 1.9},
	"Minotaur":        {"file": "creature_brute_horned", "h": 1.9},
	"MinotaurVakt":    {"file": "creature_brute_horned", "h": 2.0},
	"MinotaurKungen":  {"file": "creature_brute_horned", "h": 2.3},
	"Dvärg":           {"file": "creature_dwarf_miner", "h": 1.1},
	"DvärgenSmeden":   {"file": "creature_dwarf_iron", "h": 1.15},
	"Dvärgsoldat":     {"file": "creature_dwarf_iron", "h": 1.1},
	"Dvärggeomant":    {"file": "creature_dwarf_purple", "h": 1.1},
	"Vampyr":          {"file": "creature_robed_vampire", "h": 1.7},
	"VampyrHerre":     {"file": "creature_robed_vampire", "h": 1.8},
	"Nekromant":       {"file": "creature_robed_necro", "h": 1.7},
	"Lich":            {"file": "creature_robed_lich", "h": 1.8},
	"Elddraken":       {"file": "creature_dragon_fire", "h": 2.2},
	"Isdraken":        {"file": "creature_dragon_ice", "h": 2.0},
	"Ärkedemonen":     {"file": "creature_demon_arch", "h": 2.4},
	"Vildsvin":        {"file": "creature_boar_brown", "h": 0.6},
}

var sim: MonsterSim
var player_sim: PlayerSim = null   # sätts av game3d — matar AI:n med spelar-tilen
var fx: FloatingText3D = null      # delad flyttext-pool, sätts av game3d

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _prev_pos := Vector3.ZERO   # position vid förra sim-steget
var _curr_pos := Vector3.ZERO   # position vid senaste sim-steget
var _prev_bob := 0.0            # gång-studs vid förra/senaste sim-steget
var _curr_bob := 0.0
var _breath_t := randf() * TAU  # desynkad start så flocken inte andas i takt
var _attacking := false         # attack-stöten pausar livs-animen (som 2D)
var _visual: Node3D
var _body_root: Node3D             # bär GLB:n/lådan — attack-stöten tweenar denna
var _tint_mat: StandardMaterial3D  # additiv overlay: träff-blink, elite, enrage
var _hp_bar: MeshInstance3D
var _hp_mat: StandardMaterial3D
var _flash_tw: Tween
var _target_ring: MeshInstance3D
var _status_aura: CPUParticles3D   # gift/brand-partiklar (som 2D-vyn)

func _init() -> void:
	sim = MonsterSim.new()
	sim.damaged.connect(_on_sim_damaged)
	sim.charm_damaged.connect(_on_sim_charm_damaged)
	sim.element_reaction.connect(_on_sim_element_reaction)
	sim.moved.connect(_on_sim_moved)
	sim.attack_started.connect(_on_sim_attack_started)
	sim.enrage_started.connect(_on_sim_enraged)
	sim.status_changed.connect(_on_sim_status_changed)
	sim.died.connect(_on_sim_died)

func setup(mname: String, t: Vector2i, model: ZoneModel) -> void:
	sim.init_stats(mname, TimeOfDay.is_night)
	sim.place(t, model)
	position = Zone3D.tile_to_world3(t)
	_from = position
	_to = position
	_prev_pos = position
	_curr_pos = position
	_build_visual()

func make_elite() -> void:
	sim.make_elite()
	if _visual != null:
		_visual.scale = Vector3.ONE * 1.2
		_tint_mat.albedo_color = _rest_tint()
	_refresh_hp_bar()

## Kropp (GLB eller platshållarlåda) + hp-bar ovanför. Material skapas EN gång
## här — träffar/enrage tweenar bara parametrar (ingen per-träff-allokering;
## lärdomen från godot_rpg). Blink/elite/enrage görs via en delad additiv
## material_overlay så den fungerar oavsett GLB:ns egna material.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tint_mat.albedo_color = Color.BLACK   # additivt svart = osynlig i vila
	_body_root = Node3D.new()
	_visual.add_child(_body_root)
	var top := _build_body()
	_hp_bar = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(BAR_W, 0.07, 0.07)
	_hp_bar.mesh = bar
	_hp_mat = StandardMaterial3D.new()
	_hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar.material_override = _hp_mat
	_hp_bar.position.y = top + 0.35
	_visual.add_child(_hp_bar)
	# Status-aura (gift/brand) mitt på kroppen — byggs EN gång, togglas bara.
	_status_aura = SpellFx3D.make_status_aura()
	_status_aura.position.y = top * 0.5
	_visual.add_child(_status_aura)
	_refresh_hp_bar()

## Bygger kroppen i _body_root och returnerar dess höjd (för hp-barens läge).
func _build_body() -> float:
	var spec: Dictionary = MODELS.get(sim.monster_name, {})
	var path := "res://assets/models3d/%s.glb" % String(spec.get("file", ""))
	if not spec.is_empty() and ResourceLoader.exists(path):
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		var h := float(spec.get("h", 1.0))
		inst.scale = Vector3.ONE * h
		inst.rotation.y = PI   # glTF-framåt är +Z; Godot-framåt är −Z
		_body_root.add_child(inst)
		_apply_overlay(inst)
		return h
	# Platshållarlåda i monstrets databasfärg (som innan GLB-steget).
	var d: Dictionary = MonsterDB.monsters.get(sim.monster_name, {})
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.9, 0.6)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(d.get("color", "#aa3333")))
	body.material_override = mat
	body.position.y = 0.45
	_body_root.add_child(body)
	_apply_overlay(body)
	return 0.9

## Sätter den delade tint-overlayen på alla mesh-instanser i kroppen.
func _apply_overlay(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = _tint_mat
	for c in n.get_children():
		_apply_overlay(c)

## Tintens viloläge: svart (osynlig), elite-orange eller enrage-röd.
func _rest_tint() -> Color:
	if sim.enraged:
		return Color(0.45, 0.04, 0.04)
	if sim.is_elite:
		return Color(0.32, 0.16, 0.0)
	return Color.BLACK

func _refresh_hp_bar() -> void:
	if _hp_bar == null:
		return
	var ratio := float(sim.hp) / float(sim.max_hp) if sim.max_hp > 0 else 0.0
	_hp_bar.scale.x = maxf(ratio, 0.01)
	if sim.enraged:
		_hp_mat.albedo_color = Color(1.0, 0.2, 0.2)
	elif ratio > 0.5:
		_hp_mat.albedo_color = Color(0.18, 0.78, 0.18)
	elif ratio > 0.25:
		_hp_mat.albedo_color = Color(0.85, 0.72, 0.1)
	else:
		_hp_mat.albedo_color = Color(0.85, 0.12, 0.12)

## Målring under kroppen — visar vilket monster spelaren auto-attackerar.
## Skapas lazy vid första targeteringen och togglas därefter.
func set_targeted(on: bool) -> void:
	if _target_ring == null:
		if not on:
			return
		_target_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.38
		torus.outer_radius = 0.48
		_target_ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.35, 0.25)
		_target_ring.material_override = mat
		_target_ring.position.y = 0.04
		add_child(_target_ring)
	_target_ring.visible = on

## Ett fast simuleringssteg (anropas av game3d i SimTicker-takt): mata AI:n
## med spelar-tilen och bokför prev/curr-position för renderingen.
func sim_tick(dt: float) -> void:
	if sim.dead:
		return
	var pt: Variant = null
	if player_sim != null:
		pt = player_sim.tile
	sim.ai_tick(dt, pt)
	_prev_pos = _curr_pos
	_curr_pos = _from.lerp(_to, sim.move_progress)
	_prev_bob = _curr_bob
	_curr_bob = CharacterMotion3D.walk_bob(sim.move_progress)

## Per frame: mjuk position mellan de två senaste sim-stegen (alpha 0..1)
## + karaktärsliv (gång-studs under steg, annars idle-andning).
func render_interpolate(alpha: float, delta := 0.0) -> void:
	if sim.dead:
		return
	position = _prev_pos.lerp(_curr_pos, alpha)
	if _attacking or _body_root == null:
		return   # attack-stötens tween får styra kroppen ostört (som 2D)
	_breath_t += delta
	if sim.move_progress < 1.0:
		_body_root.position.y = lerpf(_prev_bob, _curr_bob, alpha)
		_body_root.scale.y = 1.0
	else:
		_body_root.position.y = 0.0
		_body_root.scale.y = CharacterMotion3D.breath_scale(_breath_t)

# ── Reaktioner på simuleringens signaler (rent visuellt) ──────────────────────
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	_from = position
	_to = Zone3D.tile_to_world3(to)
	var d := to - from
	if d != Vector2i.ZERO and _visual != null:
		_visual.rotation.y = atan2(-float(d.x), -float(d.y))

## Attack-stöt: kroppen lutar sig snabbt mot spelaren och studsar tillbaka.
## Pausar livs-animen så tweenen får styra kroppen ostört (som 2D).
func _on_sim_attack_started(dir: Vector2i) -> void:
	if _body_root == null or dir == Vector2i.ZERO:
		return
	var lunge := Vector3(dir.x, 0, dir.y).normalized() * 0.25
	_attacking = true
	var tw := create_tween()
	tw.tween_property(_body_root, "position", lunge, 0.07) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_body_root, "position", Vector3.ZERO, 0.13) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _attacking = false)

## Träff: uppdatera baren + kort vit blink via tint-overlayen (parameter-tween,
## ingen materialallokering).
func _on_sim_damaged(amount: int, crit: bool) -> void:
	_refresh_hp_bar()
	if crit:
		Sfx.crit()
	elif sim.hp > 0:
		Sfx.hit()   # dödsträffen låter via monster_die() istället (som 2D)
	if fx != null:
		fx.show_damage(position, amount, crit)
	if _tint_mat == null:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_tint_mat.albedo_color = Color(1, 1, 1) * (1.0 if crit else 0.6)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_tint_mat, "albedo_color", _rest_tint(), 0.18)

## Elementär charm-bonusskada: violett siffra skild från vapenskadan.
func _on_sim_charm_damaged(amount: int, element: String) -> void:
	_refresh_hp_bar()
	Sfx.charm(element)
	if fx != null:
		fx.show_text(position, str(amount), Color(0.75, 0.45, 1.0))

## Elementreaktion/notering — samma etiketter och färger som 2D-vyn.
func _on_sim_element_reaction(kind: String) -> void:
	if fx == null:
		return
	match kind:
		"weak":          fx.show_text(position, "svag!", Color(1.0, 0.85, 0.2))
		"resist":        fx.show_text(position, "tål", Color(0.6, 0.7, 1.0))
		"immune":        fx.show_text(position, "immun", Color(0.6, 0.6, 0.6))
		"poison_immune": fx.show_text(position, "gift biter ej", Color(0.6, 0.72, 0.6))
		"miss":          fx.show_text(position, "miss", Color(0.72, 0.72, 0.72))
		"poisoned":      fx.show_text(position, "förgiftad", Color(0.4, 0.95, 0.4))
		"stunned":       fx.show_text(position, "bedövad", Color(1.0, 0.9, 0.4))

func _on_sim_enraged() -> void:
	_tint_mat.albedo_color = _rest_tint()
	_refresh_hp_bar()

## Status lades till/tickade ut: toggla gift/brand-auran (som 2D-vyn).
func _on_sim_status_changed() -> void:
	SpellFx3D.update_status_aura(_status_aura,
		sim.has_status("poison"), sim.has_status("burn"))

## Död: simuleringen har bokfört exp/kills och frigjort tilen — dödsskur med
## stil per monstertyp (ben/slem/glöd/is/stoft, samma klassning som 2D-vyn)
## + guldglitter om loot föll, sedan krymp och försvinn. game3d schemalägger
## ev. respawn via died-signalen.
func _on_sim_died(drops: Array) -> void:
	Sfx.monster_die()
	var fx_parent := get_parent()
	if fx_parent != null:
		var d: Dictionary = MonsterDB.monsters.get(sim.monster_name, {})
		var base_col := Color(String(d.get("color", "#aa3333")))
		SpellFx3D.death_burst(fx_parent, position + Vector3(0, 0.4, 0),
			base_col, SpellFx.death_kind(sim.monster_name))
		if not drops.is_empty():
			SpellFx3D.fountain(fx_parent, position, Color(1.0, 0.92, 0.45), 8)
	if _visual == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.25) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
