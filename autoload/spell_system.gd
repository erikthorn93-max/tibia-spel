extends Node
## Autoload: SpellSystem.
## Datadriven magi: laddar spells.json, sköter gating (can_cast), cooldowns,
## inlärning (learn_spell) och utfall (resolve_cast) för både instant-spells och
## runor. Ren logik — inget UI. Casters/UI lyssnar på signalerna.

signal spell_learned(spell_id: String)
signal spell_cast(id: String, result: Dictionary)

## Default-räckvidd (Chebyshev) för runor/spells utan eget range-fält.
const DEFAULT_RANGE := 5

var spells: Dictionary = {}        # spell_id -> def (från spells.json)
var _cooldowns: Dictionary = {}    # id -> sekunder kvar

## Vy-agnostisk monsterkälla för attack-utfall: -> Array av objekt med
## tile/dead/take_damage/apply_status (2D-monsternoder eller MonsterSim).
## Sätts av 3D-orkestreraren (game3d); utan källa läses 2D-zonens barn.
var monster_source := Callable()

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open("res://data/spells.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	spells = parsed if parsed is Dictionary else {}

func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)

# ── Normaliserad cast-definition ─────────────────────────────────────────────
## Bygger en enhetlig def från antingen ett spell_id eller ett run-item-id.
## Tom dict = okänt id.
func cast_def(id: String) -> Dictionary:
	if spells.has(id):
		var s: Dictionary = spells[id].duplicate(true)
		s["id"] = id
		s["source"] = "spell"
		s["power"] = int(s.get("base_power", 0))
		s["range"] = int(s.get("range", DEFAULT_RANGE))
		return s
	var item: Dictionary = ItemDB.items.get(id, {})
	if not item.is_empty() and String(item.get("type", "")) == "rune":
		var d: Dictionary = {}
		d["id"] = id
		d["source"] = "rune"
		d["name"] = String(item.get("name", id))
		d["type"] = "heal" if String(item.get("effect", "")) == "heal" else "attack"
		d["target"] = String(item.get("target", "target"))
		d["element"] = String(item.get("element", "physical"))
		d["power"] = int(item.get("rune_power", 0))
		d["mana_cost"] = float(item.get("mana_cost", 0.0))
		d["magic_lvl"] = int(item.get("magic_lvl", 1))
		d["cooldown"] = float(item.get("cooldown", 1.0))
		d["range"] = int(item.get("range", DEFAULT_RANGE))
		d["radius"] = int(item.get("radius", 0))
		if item.has("status"):
			d["status"] = item["status"]
		return d
	return {}

func is_spell(id: String) -> bool:
	return spells.has(id)

func knows_spell(id: String) -> bool:
	return GameState.learned_spells.has(id)

func needs_aim(def: Dictionary) -> bool:
	return String(def.get("target", "self")) in ["target", "area"]

func cooldown_left(id: String) -> float:
	return float(_cooldowns.get(id, 0.0))

## Castbar just nu bortsett från cooldown — krav, mana, runor & reagens.
## Används av hotbaren för att gråtona ikoner man inte har råd med (cooldown
## visas separat via overlayn, så den räknas medvetet inte in här).
func affordable(id: String) -> bool:
	var def := cast_def(id)
	if def.is_empty():
		return false
	if String(def["source"]) == "spell" and not knows_spell(id):
		return false
	if String(def["source"]) == "rune" and int(GameState.inventory.get(id, 0)) < 1:
		return false
	if GameState.effective_skill_level("magic") < int(def.get("magic_lvl", 1)):
		return false
	if GameState.mana < float(def.get("mana_cost", 0.0)):
		return false
	if String(def.get("type", "")) == "conjure":
		var reagent := String(def.get("reagent", ""))
		if reagent != "" and int(GameState.inventory.get(reagent, 0)) < 1:
			return false
	return true

# ── Gating ───────────────────────────────────────────────────────────────────
## Returnerar {ok: bool, reason: String}. reason är tom vid ok.
func can_cast(id: String) -> Dictionary:
	var def := cast_def(id)
	if def.is_empty():
		return {"ok": false, "reason": "Okänd besvärjelse."}
	if String(def["source"]) == "spell" and not knows_spell(id):
		return {"ok": false, "reason": "Du kan inte den besvärjelsen."}
	if String(def["source"]) == "rune" and int(GameState.inventory.get(id, 0)) < 1:
		return {"ok": false, "reason": "Du har inga sådana runor."}
	if GameState.effective_skill_level("magic") < int(def.get("magic_lvl", 1)):
		return {"ok": false, "reason": "Kräver magic %d." % int(def.get("magic_lvl", 1))}
	if cooldown_left(id) > 0.0:
		return {"ok": false, "reason": "Besvärjelsen laddar fortfarande."}
	if GameState.mana < float(def.get("mana_cost", 0.0)):
		return {"ok": false, "reason": "Inte tillräckligt med mana."}
	if String(def.get("type", "")) == "conjure":
		var reagent := String(def.get("reagent", ""))
		if reagent != "" and int(GameState.inventory.get(reagent, 0)) < 1:
			var rname := String(ItemDB.items.get(reagent, {}).get("name", reagent))
			return {"ok": false, "reason": "Du behöver en %s." % rname}
	return {"ok": true, "reason": ""}

# ── Inlärning ────────────────────────────────────────────────────────────────
## Lär en instant-spell mot guld. Returnerar {ok, reason}.
func learn_spell(id: String) -> Dictionary:
	if not spells.has(id):
		return {"ok": false, "reason": "Okänd besvärjelse."}
	if knows_spell(id):
		return {"ok": false, "reason": "Du kan redan den."}
	var def: Dictionary = spells[id]
	if GameState.effective_skill_level("magic") < int(def.get("magic_lvl", 1)):
		return {"ok": false, "reason": "Kräver magic %d." % int(def.get("magic_lvl", 1))}
	var price := int(def.get("price", 0))
	if GameState.gold < price:
		return {"ok": false, "reason": "Du har inte råd (%d guld)." % price}
	GameState.gold -= price
	GameState.gold_changed.emit(GameState.gold)
	GameState.learned_spells.append(id)
	spell_learned.emit(id)
	return {"ok": true, "reason": ""}

# ── Utfall ───────────────────────────────────────────────────────────────────
## Kastar besvärjelsen. Antar att can_cast redan godkänts av anroparen.
## center_tile används för target/area; ignoreras för self/area_self/conjure.
## Returnerar {ok, message, hits}.
func resolve_cast(id: String, caster: Node, center_tile: Vector2i) -> Dictionary:
	var def := cast_def(id)
	if def.is_empty():
		return {"ok": false, "message": "Okänd besvärjelse.", "hits": 0}

	var magic_lvl := GameState.effective_skill_level("magic")
	var ctype := String(def.get("type", "attack"))
	var result := {"ok": true, "message": "", "hits": 0}

	# Förbruka resurser
	if String(def["source"]) == "rune":
		GameState.remove_item(id, 1)
	if ctype == "conjure":
		var reagent := String(def.get("reagent", ""))
		if reagent != "":
			GameState.remove_item(reagent, 1)
	GameState.use_mana(float(def.get("mana_cost", 0.0)))
	_cooldowns[id] = float(def.get("cooldown", 1.0))

	match ctype:
		"heal":
			var amt := CombatFormulas.roll_magic(magic_lvl, int(def.get("power", 0)))
			GameState.heal(amt)
			result["message"] = "Du helar %.0f HP." % amt
		"support":
			if def.has("buff"):
				var b: Dictionary = def["buff"]
				GameState.apply_buff(String(b["stat"]), float(b["amount"]), float(b["duration"]))
			result["message"] = "%s aktiverad." % String(def.get("name", id))
		"conjure":
			var produces := String(def.get("produces", ""))
			var amount := int(def.get("amount", 1))
			if produces != "":
				GameState.add_item(produces, amount)
			var pname := String(ItemDB.items.get(produces, {}).get("name", produces))
			result["message"] = "Du frammanar %d × %s." % [amount, pname]
		"attack":
			result["hits"] = _resolve_attack(def, caster, center_tile, magic_lvl)
			if result["hits"] == 0:
				result["message"] = "Besvärjelsen missade."

	GameState.gain_skill_xp("magic", _xp_for(def))
	# Effekt-metadata: casters spawnar visuella effekter utifrån detta.
	var target_type := String(def.get("target", "target"))
	var fx_center := center_tile
	if ctype != "attack" or target_type == "area_self" or target_type == "self":
		if caster != null and is_instance_valid(caster):
			fx_center = caster.tile
	result["fx"] = {
		"ctype": ctype,
		"element": String(def.get("element", "none")),
		"target_type": target_type,
		"center": fx_center,
		"radius": int(def.get("radius", 0)),
	}
	spell_cast.emit(id, result)
	return result

## Skadar monster i träffområdet. Returnerar antal träffade.
func _resolve_attack(def: Dictionary, caster: Node, center_tile: Vector2i, magic_lvl: int) -> int:
	var target_type := String(def.get("target", "target"))
	var center := center_tile
	if target_type == "area_self" and caster != null and is_instance_valid(caster):
		center = caster.tile
	var radius := int(def.get("radius", 0))
	var power := int(def.get("power", 0))
	var status: Dictionary = def.get("status", {})

	var element := String(def.get("element", ""))
	var hits := 0
	for m in _monsters_in_radius(center, radius):
		var dmg := CombatFormulas.roll_magic(magic_lvl, power)
		var crit := CombatFormulas.roll_crit(magic_lvl, GameState.total_crit_bonus())
		if crit:
			dmg *= CombatFormulas.CRIT_MULTIPLIER
		m.take_damage(dmg, crit, element)
		if not status.is_empty() and m.has_method("apply_status"):
			m.apply_status(String(status.get("type", "burn")),
				float(status.get("duration", 4.0)), float(status.get("power", 3.0)))
		hits += 1
	return hits

## Alla levande monster vars tile ligger inom Chebyshev-radius av center.
func _monsters_in_radius(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for m in _monster_pool():
		var mt = m.get("tile")
		if mt == null:
			continue
		if maxi(absi(mt.x - center.x), absi(mt.y - center.y)) <= radius:
			out.append(m)
	return out

## Kandidatpool: monster_source om satt (och ägaren lever), annars 2D-zonens
## barn-noder — samma urval som tidigare.
func _monster_pool() -> Array:
	if monster_source.is_valid() and monster_source.get_object() != null:
		return monster_source.call()
	var out: Array = []
	if World.current_zone == null:
		return out
	for child in World.current_zone.get_children():
		if not child.has_method("take_damage") or bool(child.get("dead")):
			continue
		out.append(child)
	return out

## Magic-XP per cast — skalar med manakostnaden så dyra spells tränar mer.
func _xp_for(def: Dictionary) -> int:
	return maxi(2, int(float(def.get("mana_cost", 0.0)) / 8.0))
