extends GutTest
## Använder de RIKTIGA autoloadsen QuestSystem/DialogueDB — reset i before_each.

func before_each():
	QuestSystem.reset()
	GameState.inventory.clear()
	GameState.gold = 0

func _texts(node_id: String) -> Array:
	return DialogueDB.visible_choices(node_id).map(func(c): return String(c["text"]))

func test_loads_data():
	assert_false(DialogueDB.npcs.is_empty())
	assert_false(DialogueDB.nodes.is_empty())

func test_unconditioned_choices_visible():
	assert_has(_texts("blacksmith_root"), "Who are you?")
	assert_has(_texts("blacksmith_root"), "Goodbye.")

func test_quest_step_choice_hidden_by_default():
	assert_does_not_have(_texts("blacksmith_root"), "I have your iron ore.")

func test_quest_available_condition():
	assert_does_not_have(_texts("blacksmith_root"), "Need any help?")   # kräver quest_welcome klar
	QuestSystem.completed["quest_welcome"] = true
	assert_has(_texts("blacksmith_root"), "Need any help?")

func test_quest_step_and_has_item():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_lost_ore")
	assert_does_not_have(_texts("blacksmith_root"), "I have your iron ore.")
	GameState.add_item("iron_ore", 3)   # collect-steget avancerar till steg 1
	assert_has(_texts("blacksmith_root"), "I have your iron ore.")

func test_not_negation_on_has_item():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_crypt")
	QuestSystem.active["quest_crypt"]["step"] = 1   # simulera: framme vid kryptan, ljuset tappat
	assert_has(_texts("scholar_root"), "I lost the candle you gave me.")
	GameState.add_item("warding_candle", 1)
	assert_does_not_have(_texts("scholar_root"), "I lost the candle you gave me.")

func test_run_actions_start_and_give():
	QuestSystem.completed["quest_welcome"] = true
	DialogueDB.run_actions([
		{"type": "start_quest", "quest": "quest_crypt"},
		{"type": "give_item", "item": "warding_candle", "count": 1}
	], "npc_scholar")
	assert_true(QuestSystem.active.has("quest_crypt"))
	assert_eq(int(GameState.inventory.get("warding_candle", 0)), 1)

func test_run_actions_take_and_advance_completes():
	QuestSystem.completed["quest_welcome"] = true
	QuestSystem.start("quest_lost_ore")
	GameState.add_item("iron_ore", 3)    # → steg 1 (talk_to)
	DialogueDB.run_actions([
		{"type": "take_item", "item": "iron_ore", "count": 3},
		{"type": "advance_quest", "quest": "quest_lost_ore"}
	], "npc_blacksmith")
	assert_true(QuestSystem.completed.has("quest_lost_ore"))
	assert_eq(int(GameState.inventory.get("iron_ore", 0)), 0)
