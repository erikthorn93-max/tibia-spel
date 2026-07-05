class_name Player3D
extends Node3D
## 3D-vy för spelaren: samma PlayerSim som 2D-vyn (player.gd) driver
## gridrörelsen — den här noden läser bara input-intent, interpolerar
## position ur sim.move_progress och vrider visualen efter facing.
## Ingen spellogik här. Kroppen är GLB-hjälten (generisk människa tills
## outfitsystemet bryggas till 3D); kapseln finns kvar som fallback om
## modellen inte är importerad.

const MODEL_PATH := "res://assets/models3d/middle_aged_man.glb"
const MODEL_HEIGHT := 1.7   # modellen är normaliserad till 1,0 m

var sim := PlayerSim.new()
var fx: FloatingText3D = null   # delad flyttext-pool, sätts av game3d
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _visual: Node3D

## SpellSystem.resolve_cast läser caster.tile (fx-center för self/area_self).
var tile: Vector2i:
	get: return sim.tile

func _init() -> void:
	sim.moved.connect(_on_sim_moved)
	sim.facing_changed.connect(_on_facing_changed)
	sim.attack_swung.connect(_on_attack_swung)
	sim.healed.connect(_on_healed)

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
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

## Teleport (zonladdning/respawn) — nollställer interpolationen.
func snap_to(t: Vector2i) -> void:
	sim.snap_to(t)
	position = Zone3D.tile_to_world3(t)
	_from = position
	_to = position

func _process(delta: float) -> void:
	var intent := Vector2i.ZERO
	if Input.is_action_pressed("move_up"): intent = Vector2i.UP
	elif Input.is_action_pressed("move_down"): intent = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"): intent = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"): intent = Vector2i.RIGHT
	sim.advance(delta, intent)
	sim.attack_tick(delta)
	position = _from.lerp(_to, sim.move_progress)

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
