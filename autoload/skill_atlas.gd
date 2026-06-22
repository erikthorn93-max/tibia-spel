class_name SkillAtlas
extends RefCounted
## Beräknar "var tränar jag den här skillen?"-data genom att skanna data/zones/.
## Mappar varje skill till de noder/stationer som tränar den + i vilka zoner de finns.
## Används av skillpanelen för att visa en träningsguide. Cachas statiskt.

const ZONES_DIR := "res://data/zones"

# Stationstyp → visningsnamn (speglar crafting_station.gd LABELS)
const STATION_LABELS := {
	"anvil": "Städ", "stove": "Gryta", "alchemy_table": "Alkemibord",
	"rune_altar": "Runaltare", "crafting_bench": "Hantverksbänk",
	"prayer_altar": "Bönealtare", "workbench": "Arbetsbänk",
}

# Skills som inte tränas via nod/station — kort textförklaring istället.
const SKILL_HINTS := {
	"sword":        "Tränas i strid — anfall monster med ett svärd.",
	"axe":          "Tränas i strid — anfall monster med en yxa.",
	"club":         "Tränas i strid — anfall monster med ett trubbigt vapen.",
	"fist":         "Tränas i strid — slåss utan vapen.",
	"distance":     "Tränas i strid — anfall på avstånd med pilbåge/kastvapen.",
	"shielding":    "Tränas i strid — höjs när du blockerar och tar träffar.",
	"constitution": "Höjs automatiskt när du tar och delar ut skada i strid.",
	"agility":      "Höjs automatiskt medan du går och springer i världen.",
	"magic":        "Kasta runor mot fiender. Runor tillverkas vid Runaltaret.",
	"prayer":       "Tränas vid ett Bönealtare genom att begrava ben.",
	"thieving":     "Tränas genom att bestjäla NPC:er du möter.",
	"slayer":       "Tränas genom att döda monster från Slaktmästarens uppdrag.",
}

# Skills som tränas vid en station men saknar recept i data (manuell koppling).
const SKILL_STATION_FALLBACK := {
	"prayer": "prayer_altar",
}

static var _node_zones: Dictionary = {}      # node_type -> Array[String] zonnamn
static var _station_zones: Dictionary = {}   # station -> Array[String] zonnamn
static var _built := false

## Returnerar träningskällor för en skill, sorterade på nivåkrav.
## Varje post: { "level": int, "label": String, "zones": Array, "kind": "node"|"station" }
static func entries_for(skill_id: String) -> Array:
	_ensure_built()
	var out: Array = []

	# Gathering-noder för denna skill
	for nt in ItemDB.nodes:
		var d: Dictionary = ItemDB.nodes[nt]
		if String(d.get("skill", "")) != skill_id:
			continue
		out.append({
			"level": int(d.get("level", 1)),
			"label": String(d.get("label", nt)),
			"zones": _node_zones.get(nt, []),
			"kind": "node",
		})

	# Crafting-stationer för denna skill (lägsta receptnivå = startnivå)
	var stations := _stations_for_skill(skill_id)
	for st in stations:
		out.append({
			"level": _min_recipe_level(st, skill_id),
			"label": STATION_LABELS.get(st, st),
			"zones": _station_zones.get(st, []),
			"kind": "station",
		})

	out.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]))
	return out

## Kort textförklaring för skills som tränas i strid/aktivt (annars "").
static func hint_for(skill_id: String) -> String:
	return String(SKILL_HINTS.get(skill_id, ""))

# ── Intern uppbyggnad ──

static func _stations_for_skill(skill_id: String) -> Array:
	var out: Array = []
	for st in ItemDB.recipes:
		for r in ItemDB.recipes[st]:
			if String(r.get("skill", "")) == skill_id:
				out.append(st)
				break
	if SKILL_STATION_FALLBACK.has(skill_id):
		var fb := String(SKILL_STATION_FALLBACK[skill_id])
		if not out.has(fb):
			out.append(fb)
	return out

static func _min_recipe_level(station: String, skill_id: String) -> int:
	var best := 1
	var found := false
	for r in ItemDB.recipes.get(station, []):
		if String(r.get("skill", "")) != skill_id:
			continue
		var lv := int(r.get("level", 1))
		if not found or lv < best:
			best = lv
			found = true
	return best

static func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var dir := DirAccess.open(ZONES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			_scan_zone(ZONES_DIR + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()

static func _scan_zone(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	var zone_name := String(data.get("name", path.get_file()))
	var legend: Dictionary = data.get("legend", {})
	for ch in legend:
		var e: Dictionary = legend[ch]
		match String(e.get("type", "")):
			"node":
				_add(_node_zones, String(e.get("node", "")), zone_name)
			"station":
				_add(_station_zones, String(e.get("station", "")), zone_name)

static func _add(dict: Dictionary, key: String, zone_name: String) -> void:
	if key == "":
		return
	if not dict.has(key):
		dict[key] = []
	if not dict[key].has(zone_name):
		dict[key].append(zone_name)
