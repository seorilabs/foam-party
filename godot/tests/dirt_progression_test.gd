extends SceneTree


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var DirtProgression: GDScript = load("res://core/use_cases/dirt_progression.gd")
	var GameConfig: GDScript = load("res://core/domain/game_config.gd")
	if DirtProgression == null or GameConfig == null:
		_fail("dirt progression scripts failed to load")
		return
	if not test_unlock_curve(DirtProgression, GameConfig):
		return
	if not test_car_bias_filtering(DirtProgression):
		return
	print("CORE TESTS PASSED")
	quit(0)


func test_unlock_curve(DirtProgression: GDScript, GameConfig: GDScript) -> bool:
	var expected_dirt_by_level := {
		1: ["mud", "dust", "leaf"],
		2: ["mud", "dust", "leaf", "oil"],
		3: ["mud", "dust", "leaf", "oil", "bug", "poop"],
		4: ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime"],
		5: ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime", "sap"],
	}
	var previous_count := 0
	for level in expected_dirt_by_level:
		var actual: Array[String] = DirtProgression.allowed_types_for_level(level)
		if actual != expected_dirt_by_level[level]:
			_fail("unexpected dirt unlocks at level %d: %s" % [level, actual])
			return false
		if actual.size() < previous_count:
			_fail("dirt unlock count must not shrink at level %d" % level)
			return false
		previous_count = actual.size()
	if DirtProgression.allowed_types_for_level(5) != GameConfig.DIRT_TYPES:
		_fail("level 5 must converge to the full dirt catalog")
		return false
	return true


func test_car_bias_filtering(DirtProgression: GDScript) -> bool:
	var sports_pool := ["oil", "dust", "oil", "road_grime", "leaf", "bug", "mud"]
	var gated_sports: Array[String] = DirtProgression.filter_pool_for_level(sports_pool, 2)
	if gated_sports != ["oil", "dust", "oil", "leaf", "mud"]:
		_fail("level 2 sports weights or gate changed: " + str(gated_sports))
		return false
	var truck_pool := ["mud", "mud", "bug", "poop", "road_grime", "leaf"]
	var gated_truck: Array[String] = DirtProgression.filter_pool_for_level(truck_pool, 3)
	if gated_truck != ["mud", "mud", "bug", "poop", "leaf"]:
		_fail("level 3 truck weights or gate changed: " + str(gated_truck))
		return false
	return true


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
