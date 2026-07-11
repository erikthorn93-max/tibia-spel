class_name Player3D
extends Node3D
## 3D-vy för spelaren: samma PlayerSim som 2D-vyn (player.gd) driver
## gridrörelsen — den här noden läser bara input-intent och vrider visualen
## efter facing. Simuleringen tickas i fasta steg av game3d (sim_tick);
## renderingen interpolerar mellan de två senaste stegen (render_interpolate).
## Ingen spellogik här. Kroppen är GLB-hjälten; kapseln finns kvar som
## fallback om modellen inte är importerad. Outfiten (garderoben) läses som
## en färgton i tröjfärgen via en delad additiv material_overlay — GLB:n har
## en bakad textur utan färgzoner, så per-plagg-färger är inte möjliga.

const MODEL_PATH := "res://assets/models3d/middle_aged_man.glb"
const MODEL_HEIGHT := 1.7   # modellen är normaliserad till 1,0 m
const GATHER_INTERVAL := 2.0   # sekunder mellan gather-försök (som 2D)

var sim := PlayerSim.new()
var fx: FloatingText3D = null   # delad flyttext-pool, sätts av game3d
var gather_target: GatherNode3D = null
var _gather_timer := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _intent_latch := Vector2i.ZERO   # fångar korta tryck mellan sim-stegen
var _prev_pos := Vector3.ZERO        # position vid förra sim-steget
var _curr_pos := Vector3.ZERO        # position vid senaste sim-steget
var _visual: Node3D
var _outfit_mat: StandardMaterial3D   # delad outfit-tint (skapas EN gång)

## SpellSystem.resolve_cast läser caster.tile (fx-center för self/area_self).
var tile: Vector2i:
	get: return sim.tile

func _init() -> void:
	sim.moved.connect(_on_sim_moved)
	sim.facing_changed.connect(_on_facing_changed)
	sim.attack_swung.connect(_on_attack_swung)
	sim.healed.connect(_on_healed)
	# Kraftslagets ljud — samma kopplingar som 2D:s player.gd.
	sim.spec_denied.connect(func(): Sfx.denied())
	sim.spec_released.connect(func(): Sfx.crit())

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_build_body()
	# Outfit-tint: samma idiom som Monster3D:s elite/enrage — EN additiv
	# overlay över kroppens meshar, bara albedo-färgen ändras vid outfit-byte.
	_outfit_mat = StandardMaterial3D.new()
	_outfit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outfit_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_apply_overlay(_visual)
	_apply_outfit()
	GameState.appearance_changed.connect(_apply_outfit)

func _build_body() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var inst: Node3D = (load(MODEL_PATH) as PackedScene).instantiate()
		inst.scale = Vector3.ONE * MODEL_HEIGHT
		inst.rotation.y = PI   # glTF-framåt är +Z; Godot-framåt är −Z
		_visual.add_child(inst)
		return
	# Fallback: platshållarkapsel med "näsa" framåt (−Z) så facing syns.
	var body := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.3
	caps.height = 1.2
	body.mesh = caps
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.70, 0.50)
	body.material_override = mat
	body.position.y = 0.6
	_visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nbox := BoxMesh.new()
	nbox.size = Vector3(0.12, 0.12, 0.2)
	nose.mesh = nbox
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.6, 0.35, 0.25)
	nose.material_override = nmat
	nose.position = Vector3(0, 0.9, -0.32)
	_visual.add_child(nose)

## Sätter den delade outfit-overlayen på alla mesh-instanser i kroppen.
func _apply_overlay(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = _outfit_mat
	for c in n.get_children():
		_apply_overlay(c)

## Outfitens färgton: standard = svart (osynlig i additiv blend); annars
## tröjfärgen kraftigt dämpad så GLB:ns egna texturfärger läses igenom.
func _apply_outfit() -> void:
	if _outfit_mat == null:
		return
	if GameState.outfit_equipped == "standard":
		_outfit_mat.albedo_color = Color.BLACK
		return
	var shirt := Color(String(GameState.appearance.get("shirt", "#ffffff")))
	_outfit_mat.albedo_color = shirt.darkened(0.7)

## Teleport (zonladdning/respawn) — nollställer interpolationen.
func snap_to(t: Vector2i) -> void:
	sim.snap_to(t)
	position = Zone3D.tile_to_world3(t)
	_from = position
	_to = position
	_prev_pos = position
	_curr_pos = position

## Per frame: latcha bara input-intenten så korta tangenttryck mellan
## sim-stegen inte tappas — simuleringen tickas i fasta steg av game3d
## via sim_tick() (prestandakravet "fast tick frikopplad från renderingen").
func _process(_delta: float) -> void:
	var intent := _read_intent()
	if intent != Vector2i.ZERO:
		_intent_latch = intent

func _read_intent() -> Vector2i:
	if Input.is_action_pressed("move_up"): return Vector2i.UP
	if Input.is_action_pressed("move_down"): return Vector2i.DOWN
	if Input.is_action_pressed("move_left"): return Vector2i.LEFT
	if Input.is_action_pressed("move_right"): return Vector2i.RIGHT
	return Vector2i.ZERO

## Ett fast simuleringssteg (anropas av game3d i SimTicker-takt): rörelse,
## auto-attack och gather. Bokför prev/curr-position för renderingen.
func sim_tick(dt: float) -> void:
	var intent := _read_intent()
	if intent == Vector2i.ZERO:
		intent = _intent_latch
	_intent_latch = Vector2i.ZERO
	if intent != Vector2i.ZERO:
		gather_target = null     # manuell rörelse avbryter gather (som 2D)
	sim.advance(dt, intent)
	sim.attack_tick(dt)
	_update_gather(dt)
	_prev_pos = _curr_pos
	_curr_pos = _from.lerp(_to, sim.move_progress)

## Per frame: mjuk position mellan de två senaste sim-stegen (alpha 0..1).
func render_interpolate(alpha: float) -> void:
	position = _prev_pos.lerp(_curr_pos, alpha)

# ── Gathering (samma regler och besked som player.gd) ─────────────────────────
## Gather ersätter strid: siktet nollas och spelaren auto-walkar intill noden.
## Onåbar nod → inget mål (walk_adjacent_to avgör, som 2D).
func set_gather_target(n: GatherNode3D) -> void:
	sim.target = null
	gather_target = n
	_gather_timer = 0.0
	if n != null and not sim.walk_adjacent_to(n.tile):
		gather_target = null

## Klick-för-att-gå — nollar gather-målet (som 2D:s walk_to).
func walk_to(t: Vector2i) -> void:
	gather_target = null
	sim.walk_to(t)

func _update_gather(delta: float) -> void:
	if gather_target == null or not is_instance_valid(gather_target):
		return
	if maxi(absi(gather_target.tile.x - sim.tile.x),
			absi(gather_target.tile.y - sim.tile.y)) > 1:
		return                    # på väg dit via auto-walk
	_gather_timer -= delta
	if _gather_timer > 0.0:
		return
	_gather_timer = GATHER_INTERVAL
	match gather_target.attempt():
		"no_tool":
			_msg("Du behöver: %s" % ItemDB.items[gather_target.def["tool"]]["name"])
			gather_target = null
		"low_level":
			_msg("Kräver %s %d." % [gather_target.def["skill"], int(gather_target.def["level"])])
			gather_target = null
		"depleted":
			gather_target = null
		_:
			# Faktiskt sving-försök (ok/miss): vänd dig mot noden, stöt, ljud
			var gd := Vector2i(signi(gather_target.tile.x - sim.tile.x),
				signi(gather_target.tile.y - sim.tile.y))
			if gd != Vector2i.ZERO:
				sim.set_facing(gd)   # emittar facing_changed → visualen vrids
			_on_attack_swung(gd)
			Sfx.gather()

## Steg påbörjat: sätt interpolationsmål (positionen läses ur move_progress).
func _on_sim_moved(from: Vector2i, to: Vector2i) -> void:
	_from = Zone3D.tile_to_world3(from)
	_to = Zone3D.tile_to_world3(to)

## Vrid visualen så −Z pekar i gångriktningen (grid-y = världens z).
func _on_facing_changed(dir: Vector2i) -> void:
	if _visual != null:
		_visual.rotation.y = atan2(-float(dir.x), -float(dir.y))

## Sving utförd (träff eller miss): snabb stöt mot slagriktningen.
func _on_attack_swung(dir: Vector2i) -> void:
	if _visual == null or dir == Vector2i.ZERO:
		return
	var lunge := Vector3(dir.x, 0, dir.y).normalized() * 0.22
	var tw := create_tween()
	tw.tween_property(_visual, "position", lunge, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position", Vector3.ZERO, 0.13).set_ease(Tween.EASE_IN_OUT)

## Leech-charm läkte: grön "+N" ovanför spelaren (som 2D-vyn).
func _on_healed(amount: float) -> void:
	if fx != null:
		fx.show_heal(position, int(amount))

# ── Spellcasting ──────────────────────────────────────────────────────────────
## Casting-entrypoint — samma kontrakt som player.gd:s cast_spell (hotbaren
## anropar caster.cast_spell). 2D:s sikt-läge ersätts i 3D av Tibia-regeln:
## target/area-spells löses mot nuvarande auto-attack-mål inom räckvidd.
## Utfallet ägs av SpellSystem; det här är bara input-routing + fx.
func cast_spell(id: String) -> void:
	var def := SpellSystem.cast_def(id)
	if def.is_empty():
		_msg("Inget att kasta.")
		return
	var check := SpellSystem.can_cast(id)
	if not check["ok"]:
		_msg(String(check["reason"]))
		Sfx.denied()
		return
	var center := sim.tile
	if SpellSystem.needs_aim(def):
		var t: MonsterSim = sim.target
		if t == null or t.dead:
			_msg("Inget mål — klicka på ett monster först.")
			Sfx.denied()
			return
		if maxi(absi(t.tile.x - sim.tile.x), absi(t.tile.y - sim.tile.y)) \
				> int(def["range"]):
			_msg("För långt bort.")
			Sfx.denied()
			return
		center = t.tile
	var res := SpellSystem.resolve_cast(id, self, center)
	_play_spell_fx3d(res)
	if String(res.get("message", "")) != "":
		_msg(String(res["message"]))

## Besvärjelse-fx i 3D — medvetet billig: symbol ur den poolade flyttext-
## poolen + en kort ljuspuls (engångshändelse per cast, jfr kraftslaget).
func _play_spell_fx3d(res: Dictionary) -> void:
	var fxd: Dictionary = res.get("fx", {})
	if fxd.is_empty():
		return
	Sfx.cast(String(fxd.get("ctype", "")))
	var color := SpellFx.element_color(String(fxd.get("element", "none")))
	var center: Vector2i = fxd.get("center", sim.tile)
	var pos := Zone3D.tile_to_world3(center)
	if fx != null:
		fx.show_text(pos, "✦", color)
	var parent := get_parent()
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = 2.5 + float(int(fxd.get("radius", 0)))
	light.position = pos + Vector3(0, 0.8, 0)
	parent.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)

func _msg(text: String) -> void:
	if World.hud != null:
		World.hud.show_message(text)
