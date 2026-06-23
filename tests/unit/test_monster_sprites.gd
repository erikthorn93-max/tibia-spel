extends GutTest
## Regressionsvakt: varje monster i monsters.json måste ha en sprite
## (SPRITE_MAP-post + existerande PNG), annars blir det osynligt i spelet.

const MonsterScript = preload("res://entities/monster/monster.gd")

func test_alla_monster_har_sprite() -> void:
	var saknar: Array = []
	for mname in MonsterDB.monsters:
		var key := String(MonsterScript.SPRITE_MAP.get(mname, ""))
		if key.is_empty():
			saknar.append("%s (saknar SPRITE_MAP-post)" % mname)
			continue
		var path := "res://assets/sprites/monsters/%s.png" % key
		if not ResourceLoader.exists(path):
			saknar.append("%s (fil saknas: %s)" % [mname, path])
	assert_eq(saknar, [], "alla monster ska ha en sprite")
