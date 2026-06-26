extends GutTest
## Datavalidering: tasks.json ↔ monsters.json. Gate-koppling testas i test_zone.gd.

var tasks: Dictionary = {}

func before_all():
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	tasks = JSON.parse_string(f.get_as_text())

func test_task_count():
	assert_eq(tasks.size(), 46)

func test_endgame_region_tasks_present():
	# Slayer-täckning för de nyare/tematiska regionerna (tidigare helt otäckta).
	var krav := {
		"task_mykonid": "Mykonidäldste",       # svampgrottan
		"task_okenmumie": "Ökenmumie",         # öken
		"task_glaciarjatte": "Glaciärjätte",   # is/frost
		"task_sotdemon": "Sotdemon",           # vulkan
		"task_djupkraken": "Djupkraken",       # korallavgrunden
		"task_avgrundsorm": "Avgrundsorm",     # lysdjupet
		"task_urtidskvaljaren": "Urtidskväljaren",  # urdjupet
	}
	for id in krav:
		assert_true(tasks.has(id), "saknar task: " + id)
		assert_eq(String(tasks[id]["monster"]), krav[id], id)

func test_slayer_progression_naar_endgame():
	var max_req := 0
	for id in tasks:
		max_req = maxi(max_req, int(tasks[id]["slayer_level_req"]))
	assert_gte(max_req, 50, "slayer-tasks ska sträcka sig till endgame (nivå 50)")

func test_low_level_tasks_present():
	for id in ["task_faltmus", "task_krakor", "task_vildsvin"]:
		assert_true(tasks.has(id), "saknar task: " + id)
	# Nybörjarvänliga: slayer-krav 1
	assert_eq(int(tasks["task_faltmus"]["slayer_level_req"]), 1)

func test_spider_slayer_tasks_present():
	for id in ["task_grottspindel", "task_giftvavare", "task_skuggspindel"]:
		assert_true(tasks.has(id), "saknar task: " + id)
	assert_eq(String(tasks["task_skuggspindel"]["monster"]), "Skuggspindel")

func test_sea_tasks_present():
	for id in ["task_krabbor", "task_sjoormar", "task_pirater"]:
		assert_true(tasks.has(id), "saknar task: " + id)
	assert_eq(String(tasks["task_pirater"]["monster"]), "Pirat")

func test_task_monsters_exist_in_monsterdb():
	for id in tasks:
		assert_true(MonsterDB.monsters.has(String(tasks[id]["monster"])),
			"%s: monstret '%s' saknas i MonsterDB" % [id, tasks[id]["monster"]])

func test_required_fields_present():
	for id in tasks:
		for field in ["monster", "required", "slayer_level_req", "reward_slayer_xp", "reward_gold", "repeatable"]:
			assert_true(tasks[id].has(field), "%s saknar fältet %s" % [id, field])

func test_rewards_positive():
	for id in tasks:
		assert_gt(int(tasks[id]["required"]), 0, id)
		assert_gt(int(tasks[id]["reward_slayer_xp"]), 0, id)
		assert_gt(int(tasks[id]["reward_gold"]), 0, id)
