extends SceneTree


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var presentation: GDScript = load("res://core/use_cases/customer_presentation.gd")
	if presentation == null:
		_fail("customer presentation rule failed to load")
		return
	if not test_profiles_rotate_by_car_type_and_level(presentation):
		return
	print("CORE TESTS PASSED")
	quit(0)


func test_profiles_rotate_by_car_type_and_level(presentation: GDScript) -> bool:
	var cases := [
		{"car_type": "compact", "level_index": 1},
		{"car_type": "sports", "level_index": 2},
		{"car_type": "truck", "level_index": 3},
		{"car_type": "van", "level_index": 4},
		{"car_type": "offroad", "level_index": 5},
	]
	var unique_profiles: Dictionary = {}
	for test_case in cases:
		var car_type := String(test_case["car_type"])
		var level_index := int(test_case["level_index"])
		var first_profile: Dictionary = presentation.profile_for(car_type, level_index)
		var repeated_profile: Dictionary = presentation.profile_for(car_type, level_index)
		if first_profile != repeated_profile:
			_fail("same car type and level index must return the same customer")
			return false
		var signature := "%s|%s|%s|%s" % [
			first_profile["face_hex"],
			first_profile["hair_hex"],
			first_profile["accent_hex"],
			first_profile["accessory"],
		]
		unique_profiles[signature] = true
	if unique_profiles.size() < 3:
		_fail("car type and level rotation must expose at least three customers")
		return false
	var baseline: Dictionary = presentation.profile_for("compact", 1)
	if baseline == presentation.profile_for("sports", 1):
		_fail("changing car type must be able to change the customer")
		return false
	if baseline == presentation.profile_for("compact", 6):
		_fail("changing level index must be able to change the customer")
		return false
	return true


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
