extends GutTest
## Smoke-test: tvingar kompilering av entity-script som inte instansieras i andra
## tester (autoloads är registrerade i testkörningen, så identifierare resolvas).

func test_player_script_compiles() -> void:
	var s := load("res://entities/player/player.gd")
	assert_not_null(s, "player.gd ska kompilera och laddas")

func test_monster_script_compiles() -> void:
	var s := load("res://entities/monster/monster.gd")
	assert_not_null(s, "monster.gd ska kompilera och laddas")
