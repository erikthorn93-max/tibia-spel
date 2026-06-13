extends GutTest
## Outfitsystem: färgscheman ovanpå appearance-basen. Skin är alltid skyddad.
## Använder den RIKTIGA GameState-autoloaden — återställ i after_each.

var _saved_appearance: Dictionary
var _saved_base: Dictionary
var _saved_outfit: String

func before_each():
	_saved_appearance = GameState.appearance.duplicate()
	_saved_base = GameState.appearance_base.duplicate()
	_saved_outfit = GameState.outfit_equipped
	GameState.appearance = {"skin": "#aabbcc", "hair": "#111111", "shirt": "#222222", "pants": "#333333"}
	GameState.appearance_base = {}
	GameState.outfit_equipped = "standard"
	UnlockSystem.unlocked.clear()

func after_each():
	GameState.appearance = _saved_appearance
	GameState.appearance_base = _saved_base
	GameState.outfit_equipped = _saved_outfit
	UnlockSystem.unlocked.clear()

func test_outfit_defs_loaded():
	assert_true(GameState.outfit_defs.has("standard"))
	assert_true(GameState.outfit_defs.has("outfit_slayer"))

func test_equip_unknown_fails():
	assert_false(GameState.equip_outfit("outfit_drake"))

func test_equip_locked_fails():
	assert_false(GameState.equip_outfit("outfit_slayer"))
	assert_eq(GameState.outfit_equipped, "standard")

func test_equip_changes_colors_but_not_skin():
	UnlockSystem.unlocked["outfit_slayer"] = true
	watch_signals(GameState)
	assert_true(GameState.equip_outfit("outfit_slayer"))
	assert_eq(GameState.outfit_equipped, "outfit_slayer")
	assert_eq(String(GameState.appearance["shirt"]), "#5a1f1f")
	assert_eq(String(GameState.appearance["pants"]), "#1a1a1a")
	assert_eq(String(GameState.appearance["skin"]), "#aabbcc")   # skyddad
	assert_eq(String(GameState.appearance["hair"]), "#111111")   # slayer sätter inte hair
	assert_signal_emitted(GameState, "appearance_changed")

func test_base_captured_lazily_on_first_equip():
	UnlockSystem.unlocked["outfit_slayer"] = true
	GameState.equip_outfit("outfit_slayer")
	assert_eq(String(GameState.appearance_base["shirt"]), "#222222")

func test_standard_restores_base():
	UnlockSystem.unlocked["outfit_slayer"] = true
	GameState.equip_outfit("outfit_slayer")
	assert_true(GameState.equip_outfit("standard"))
	assert_eq(String(GameState.appearance["shirt"]), "#222222")
	assert_eq(String(GameState.appearance["pants"]), "#333333")
	assert_eq(GameState.outfit_equipped, "standard")

func test_outfit_ignores_skin_in_colors():
	# även om en outfit-def skulle innehålla skin får den inte slå igenom
	UnlockSystem.unlocked["outfit_slayer"] = true
	GameState.outfit_defs["outfit_slayer"]["colors"]["skin"] = "#ff0000"
	GameState.equip_outfit("outfit_slayer")
	assert_eq(String(GameState.appearance["skin"]), "#aabbcc")
	GameState.outfit_defs["outfit_slayer"]["colors"].erase("skin")

func test_pirate_outfit_unlockable_via_boss_kill():
	assert_true(GameState.outfit_defs.has("outfit_pirate"), "outfit saknas")
	assert_false(GameState.equip_outfit("outfit_pirate"))
	TaskSystem.boss_kill_times["Piratkapten Svartöga"] = 1.0
	UnlockSystem.try_unlock("outfit_pirate")
	assert_true(GameState.equip_outfit("outfit_pirate"))
	assert_eq(String(GameState.appearance["skin"]), "#aabbcc")
	TaskSystem.boss_kill_times.clear()
