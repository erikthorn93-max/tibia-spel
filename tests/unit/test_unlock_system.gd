extends GutTest

var us

func before_each():
	us = load("res://autoload/unlock_system.gd").new()

func after_each():
	us.free()

func test_starts_empty():
	assert_eq(us.unlocked.size(), 0)
	assert_false(us.is_unlocked("spindelhalan"))

func test_unlock_sets_and_emits():
	watch_signals(us)
	us.unlock("spindelhalan")
	assert_true(us.is_unlocked("spindelhalan"))
	assert_signal_emitted_with_parameters(us, "unlock_added", ["spindelhalan"])

func test_unlock_idempotent():
	watch_signals(us)
	us.unlock("kryptan")
	us.unlock("kryptan")
	assert_signal_emit_count(us, "unlock_added", 1)
	assert_eq(us.unlocked.size(), 1)
