extends GutTest
## Dödsflödet i 3D: dödsvakten i GameState (liket tar inte mer stryk — utan
## den re-emittas player_died per slag och det andra drop_death_loot-anropet
## raderar graven), dödsskärmen i HUD-bryggan och respawn-knappen som bygger
## om hemzonen bakom faden (ingen auto-respawn längre).

const Game3DScene = preload("res://world/game3d.tscn")
const DeathScreenScript = preload("res://ui/death_screen.gd")

var _saved: Dictionary

func before_each():
	_saved = {
		"zone": GameState.current_zone,
		"tile": GameState.player_tile,
		"health": GameState.health,
		"mana": GameState.mana,
		"xp": GameState.experience,
		"home_zone": GameState.home_zone,
		"home_tile": GameState.home_tile,
		"grave_zone": GameState.grave_zone,
		"grave_tile": GameState.grave_tile,
		"grave_drops": GameState.grave_drops.duplicate(true),
		"inventory": GameState.inventory.duplicate(true),
		"blessings": GameState.blessings,
		"hud": World.hud,
	}
	GameState.health = GameState.max_health
	GameState.blessings = 0   # döds-droppen ska inte skyddas bort i testerna

func after_each():
	GameState.current_zone = _saved["zone"]
	GameState.player_tile = _saved["tile"]
	GameState.health = _saved["health"]
	GameState.mana = _saved["mana"]
	GameState.experience = _saved["xp"]
	GameState.home_zone = _saved["home_zone"]
	GameState.home_tile = _saved["home_tile"]
	GameState.grave_zone = _saved["grave_zone"]
	GameState.grave_tile = _saved["grave_tile"]
	GameState.grave_drops = _saved["grave_drops"]
	GameState.inventory = _saved["inventory"]
	GameState.blessings = _saved["blessings"]
	World.hud = _saved["hud"]

func _boot_game3d() -> Node3D:
	var g: Node3D = Game3DScene.instantiate()
	add_child_autofree(g)
	return g

# ── Dödsvakten i GameState ────────────────────────────────────────────────────

func test_corpse_takes_no_further_damage():
	var deaths := []
	var handler := func(): deaths.append(true)
	GameState.player_died.connect(handler)
	GameState.take_damage(GameState.max_health + 999.0)
	GameState.take_damage(50.0)   # slag mot liket
	GameState.player_died.disconnect(handler)
	assert_eq(deaths.size(), 1,
		"player_died ska emittas EN gång — liket tar inte mer stryk")
	assert_eq(GameState.health, 0.0, "hälsan ska stanna på noll")

func test_grave_survives_corpse_hits_in_3d():
	var g := _boot_game3d()
	assert_not_null(g)
	GameState.inventory = {"gold_nugget": 4}
	GameState.take_damage(GameState.max_health + 999.0)   # game3d bokför graven
	assert_true(GameState.has_grave(), "döden ska lämna en grav")
	var drops_before: Array = GameState.grave_drops.duplicate(true)
	GameState.take_damage(50.0)   # slag mot liket — utan vakten raderas graven
	assert_true(GameState.has_grave(), "graven ska överleva slag mot liket")
	assert_eq(GameState.grave_drops, drops_before,
		"gravens innehåll ska vara orört efter slag mot liket")

# ── Dödsskärmen i HUD-bryggan ─────────────────────────────────────────────────

func _death_screen(g: Node3D) -> CanvasLayer:
	for c in g.hud.get_children():
		if c.get_script() == DeathScreenScript:
			return c
	return null

func test_hud3d_bears_death_screen():
	var g := _boot_game3d()
	var screen := _death_screen(g)
	assert_not_null(screen, "HUD-bryggan ska bära 2D:ns dödsskärm")
	assert_false(screen.visible, "dödsskärmen ska starta dold")
	GameState.take_damage(GameState.max_health + 999.0)
	assert_true(screen.visible, "spelardöd ska visa dödsskärmen")

func test_death_does_not_auto_respawn():
	var g := _boot_game3d()
	assert_not_null(g)
	GameState.take_damage(GameState.max_health + 999.0)
	await wait_seconds(1.8)   # gamla flödet auto-respawnade efter 1,5 s
	assert_eq(GameState.health, 0.0,
		"ingen auto-respawn — dödsskärmens knapp äger återuppståndelsen")

func test_respawn_rebuilds_home_zone_in_3d():
	var g := _boot_game3d()
	GameState.set_home("town")   # hem = town, zonens startruta
	GameState.take_damage(GameState.max_health + 999.0)
	GameState.respawn()          # = dödsskärmens knapp
	await wait_seconds(0.4)      # zonbygget kör bakom faden
	assert_eq(g.model.zone_id, "town", "respawn ska bygga om hemzonen i 3D")
	assert_eq(GameState.health, GameState.max_health, "full HP efter respawn")
	var screen := _death_screen(g)
	assert_false(screen.visible, "dödsskärmen ska döljas vid respawn")
