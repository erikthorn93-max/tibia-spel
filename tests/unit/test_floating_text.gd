extends GutTest
## Tester för FloatingText — flytande skill-/craft-text.

const FT = preload("res://entities/floating_text.gd")

func test_setup_bygger_label_med_text() -> void:
	var ft: Node2D = FT.new()
	add_child_autofree(ft)
	ft.setup("+2 Trä", Color(1, 1, 0), 12)
	var lbl: Label = ft.get_node_or_null("Label")
	# Label läggs till som enda barn
	var found: Label = null
	for c in ft.get_children():
		if c is Label:
			found = c
	assert_not_null(found, "FloatingText ska skapa en Label")
	assert_eq(found.text, "+2 Trä")

func test_stiger_uppat_over_tid() -> void:
	var ft: Node2D = FT.new()
	add_child_autofree(ft)
	ft.setup("test")
	var y0 := ft.position.y
	ft._process(0.1)
	assert_lt(ft.position.y, y0, "texten ska stiga uppåt (minskande y)")
