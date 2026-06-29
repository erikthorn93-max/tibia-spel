extends GutTest
## Smoke-test för bestiary-panelen: den ska byggas utan fel och visa
## giftimmunitet för upptäckta giftimmuna monster.

var panel
var _saved_bestiary: Dictionary

func before_each():
	# Isolera den delade autoload-staten så testerna blir deterministiska.
	_saved_bestiary = TaskSystem.bestiary.duplicate(true)
	TaskSystem.bestiary.clear()
	panel = preload("res://ui/bestiary_panel.gd").new()
	add_child_autofree(panel)

func after_each():
	TaskSystem.bestiary = _saved_bestiary

func _label_texts() -> Array:
	# Plocka all synlig etikettext i panelen (rekursivt).
	var out: Array = []
	var stack: Array = [panel]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label:
			out.append(n.text)
		for c in n.get_children():
			stack.append(c)
	return out

func test_panelen_byggs_utan_fel():
	panel._rebuild()   # ska inte krascha
	assert_gt(_label_texts().size(), 0, "panelen ska producera etiketter")

func test_giftimmunt_upptackt_monster_visar_immunrad():
	TaskSystem.bestiary["Skelett"] = 50   # upptäckt
	panel._rebuild()
	var hit := false
	for t in _label_texts():
		if String(t).findn("giftimmun") != -1:
			hit = true
			break
	assert_true(hit, "ett upptäckt, giftimmunt monster ska visa giftimmun-raden")

func test_oupptackt_monster_visar_inte_immunrad():
	# Tom bestiary (allt "???") → ingen immunrad ska avslöjas.
	panel._rebuild()
	for t in _label_texts():
		assert_eq(String(t).findn("giftimmun"), -1,
			"oupptäckt monster ska inte avslöja giftimmunitet")
