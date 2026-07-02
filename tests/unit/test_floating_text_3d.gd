extends GutTest
## Tester för den poolade 3D-flyttexten: fast pool utan per-träff-allokering.

const FtScript = preload("res://world/floating_text_3d.gd")

func _make_pool() -> FloatingText3D:
	var fx: FloatingText3D = FtScript.new()
	add_child_autofree(fx)
	return fx

func test_pool_never_grows():
	var fx := _make_pool()
	assert_eq(fx.get_child_count(), FloatingText3D.POOL_SIZE)
	for i in FloatingText3D.POOL_SIZE + 5:
		fx.show_text(Vector3.ZERO, str(i), Color.WHITE)
	assert_eq(fx.get_child_count(), FloatingText3D.POOL_SIZE,
		"poolen ska återanvändas — aldrig växa (ingen per-träff-allokering)")

func test_show_text_activates_label():
	var fx := _make_pool()
	fx.show_text(Vector3(2, 0, 3), "42", Color(1, 0, 0))
	var visible: Array = []
	for c in fx.get_children():
		if c.visible:
			visible.append(c)
	assert_eq(visible.size(), 1, "exakt en etikett ska tändas")
	assert_eq(visible[0].text, "42")
	assert_gt(visible[0].position.y, 0.0, "texten ska ligga ovanför huvudhöjd")

func test_damage_and_heal_formatting():
	var fx := _make_pool()
	fx.show_damage(Vector3.ZERO, 17, true)
	fx.show_heal(Vector3.ZERO, 8)
	var texts: Array = []
	for c in fx.get_children():
		if c.visible:
			texts.append(c.text)
	assert_has(texts, "17")
	assert_has(texts, "+8", "läkning ska visas med plustecken")

func test_reused_label_resets_alpha():
	var fx := _make_pool()
	fx.show_text(Vector3.ZERO, "a", Color.WHITE)
	# Snurra hela poolen så första etiketten återanvänds mitt i sin tween.
	for i in FloatingText3D.POOL_SIZE:
		fx.show_text(Vector3.ZERO, "b%d" % i, Color.WHITE)
	for c in fx.get_children():
		if c.visible:
			assert_almost_eq(c.modulate.a, 1.0, 0.01,
				"återanvänd etikett ska starta fullt synlig")
