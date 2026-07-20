extends SceneTree


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var rule: GDScript = load("res://core/use_cases/stalled_dirt_highlight.gd")
	if rule == null:
		_fail("stalled dirt highlight rule failed to load")
		return
	if not test_progress_and_idle_boundaries(rule):
		return
	if not test_cleaning_resumed_epsilon(rule):
		return
	print("CORE TESTS PASSED")
	quit(0)


func test_progress_and_idle_boundaries(rule: GDScript) -> bool:
	if absf(float(rule.PROGRESS_THRESHOLD) - 0.90) > 0.0001:
		_fail("progress threshold should stay at 90 percent")
		return false
	if absf(float(rule.IDLE_SECONDS_THRESHOLD) - 3.0) > 0.0001:
		_fail("idle threshold should stay at 3 seconds")
		return false
	if bool(rule.should_show(0.8999, 10.0)):
		_fail("highlight must stay off below 90 percent")
		return false
	if bool(rule.should_show(0.90, 2.999)):
		_fail("highlight must stay off before 3 seconds")
		return false
	if not bool(rule.should_show(0.90, 3.0)):
		_fail("highlight should turn on at both exact boundaries")
		return false
	return true


func test_cleaning_resumed_epsilon(rule: GDScript) -> bool:
	if not bool(rule.cleaning_resumed(0.92, 0.921)):
		_fail("meaningful progress should report resumed cleaning")
		return false
	if bool(rule.cleaning_resumed(0.92, 0.920001)):
		_fail("floating-point noise must not report resumed cleaning")
		return false
	return true


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
