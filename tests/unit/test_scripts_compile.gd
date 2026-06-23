extends GutTest
## Smoke-test: tvingar kompilering av script som inte instansieras i andra
## tester (autoloads är registrerade i testkörningen, så identifierare resolvas).

var _paths := [
	"res://entities/player/player.gd",
	"res://entities/monster/monster.gd",
	"res://entities/gather_node.gd",
	"res://entities/crafting_station.gd",
	"res://entities/floating_text.gd",
	"res://entities/spell_fx.gd",
	"res://entities/damage_number.gd",
	"res://ui/recipe_panel.gd",
	"res://ui/hud.gd",
]

func test_entity_and_ui_scripts_compile() -> void:
	for p in _paths:
		assert_not_null(load(p), "%s ska kompilera och laddas" % p)
