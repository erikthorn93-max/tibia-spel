extends GutTest
## Datavalidering: tasks.json ↔ monsters.json. Gate-koppling testas i test_zone.gd.

var tasks: Dictionary = {}

func before_all():
	var f := FileAccess.open("res://data/tasks.json", FileAccess.READ)
	tasks = JSON.parse_string(f.get_as_text())

func test_thirteen_tasks():
	assert_eq(tasks.size(), 13)

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
