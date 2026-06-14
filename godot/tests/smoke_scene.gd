extends SceneTree

func _initialize() -> void:
	_run_smoke.call_deferred()


func _run_smoke() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("main scene failed to load")
		return

	var root_node: Node = scene.instantiate()
	get_root().add_child(root_node)

	await process_frame

	if not root_node.has_method("get_patch_count_for_test"):
		_fail("test API missing")
		return
	for method_name in ["get_combo_for_test", "get_best_combo_for_test", "get_level_time_for_test", "calc_stars_for_test", "get_car_type_for_test"]:
		if not root_node.has_method(method_name):
			_fail("test helper API missing: " + method_name)
			return

	var patch_count: int = root_node.call("get_patch_count_for_test")
	if patch_count < 20:
		_fail("expected at least 20 dirt patches")
		return

	var selected_label: String = root_node.call("get_selected_tool_label_for_test")
	if selected_label != "고압수":
		_fail("expected Korean default tool label")
		return

	var audio_count: int = root_node.call("get_audio_stream_count_for_test")
	if audio_count != 4:
		_fail("expected four tool audio streams")
		return

	if String(root_node.get("game_state")) != "title":
		_fail("game should boot to the title screen")
		return
	root_node.call("start_game")
	if String(root_node.get("game_state")) != "playing":
		_fail("start_game should enter playing state")
		return
	if not bool(root_node.get("show_tutorial")):
		_fail("first run should show the tutorial")
		return
	root_node.call("_dismiss_tutorial")
	if bool(root_node.get("show_tutorial")):
		_fail("tutorial should dismiss")
		return

	var progress_before: float = root_node.call("get_clean_progress_for_test")
	var mud_index: int = root_node.call("get_patch_index_by_kind_for_test", "mud")
	if mud_index < 0:
		_fail("mud patch missing")
		return
	root_node.call("apply_tool_to_patch_for_test", "water", mud_index, 0.7)
	var progress_after: float = root_node.call("get_clean_progress_for_test")
	if progress_after <= progress_before:
		_fail("water did not wash mud")
		return

	var leaf_index: int = root_node.call("get_patch_index_by_kind_for_test", "leaf")
	if leaf_index < 0:
		_fail("leaf patch missing")
		return
	root_node.call("apply_tool_to_patch_for_test", "air", leaf_index, 0.55)
	var leaf_state: String = root_node.call("get_patch_state_for_test", leaf_index)
	var leaf_drift: float = root_node.call("get_patch_drift_length_for_test", leaf_index)
	if leaf_state != "flying" and leaf_state != "removed":
		_fail("air did not make leaf fly")
		return
	if leaf_drift < 12.0:
		_fail("leaf did not visibly drift")
		return

	var oil_index: int = root_node.call("get_patch_index_by_kind_for_test", "oil")
	if oil_index < 0:
		_fail("oil patch missing")
		return
	var oil_initial: float = root_node.call("get_patch_health_for_test", oil_index)
	var oil_after_water: float = root_node.call("apply_tool_to_patch_for_test", "water", oil_index, 1.0)
	if oil_after_water < oil_initial - 12.0:
		_fail("water alone cleaned oil too much")
		return

	root_node.call("apply_tool_to_patch_for_test", "soap", oil_index, 0.8)
	var oil_soap: float = root_node.call("get_patch_soap_for_test", oil_index)
	var oil_state: String = root_node.call("get_patch_state_for_test", oil_index)
	if oil_soap < 0.35 or (oil_state != "soaped" and oil_state != "loosened"):
		_fail("soap did not prepare oil")
		return
	var oil_before_rinse: float = root_node.call("get_patch_health_for_test", oil_index)
	var oil_after_rinse: float = root_node.call("apply_tool_to_patch_for_test", "water", oil_index, 1.2)
	if oil_after_rinse >= oil_before_rinse - 28.0:
		_fail("rinsing soaped oil did not clean enough")
		return

	# Contextual tool guidance: recommend the correct tool when the wrong one is used.
	var mud_guidance_index: int = root_node.call("get_patch_index_by_kind_for_test", "mud")
	if mud_guidance_index >= 0:
		if String(root_node.call("get_recommended_tool_for_test", mud_guidance_index)) != "water":
			_fail("mud should recommend the water tool")
			return
		if bool(root_node.call("is_tool_effective_for_test", "air", mud_guidance_index)):
			_fail("air should be flagged ineffective on mud")
			return
		if not bool(root_node.call("is_tool_effective_for_test", "water", mud_guidance_index)):
			_fail("water should be flagged effective on mud")
			return
	var bug_guidance_index: int = root_node.call("get_patch_index_by_kind_for_test", "bug")
	if bug_guidance_index >= 0:
		if String(root_node.call("get_recommended_tool_for_test", bug_guidance_index)) != "soap":
			_fail("fresh bug stain should recommend soap first")
			return
		if bool(root_node.call("is_tool_effective_for_test", "sponge", bug_guidance_index)):
			_fail("sponge should be ineffective on an un-soaped bug stain")
			return
		root_node.call("apply_tool_to_patch_for_test", "soap", bug_guidance_index, 0.8)
		if String(root_node.call("get_recommended_tool_for_test", bug_guidance_index)) != "sponge":
			_fail("soaked bug stain should recommend the sponge next")
			return

	var best_combo: int = root_node.call("get_best_combo_for_test")
	if best_combo < 1:
		_fail("removals did not register a combo")
		return
	var stars: int = root_node.call("calc_stars_for_test")
	if stars < 1 or stars > 3:
		_fail("star rating out of range")
		return

	root_node.set("combo_count", 3)
	root_node.set("combo_timer", 0.0001)
	await process_frame
	if int(root_node.call("get_combo_for_test")) != 0:
		_fail("combo did not reset after window expired")
		return
	if float(root_node.get("combo_timer")) < 0.0:
		_fail("combo timer went negative")
		return

	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	if int(root_node.call("calc_stars_for_test")) != 3:
		_fail("expected 3 stars for fast clear with combo")
		return
	root_node.set("best_combo", 2)
	if int(root_node.call("calc_stars_for_test")) != 2:
		_fail("expected 2 stars when combo threshold is missed")
		return
	root_node.set("level_time", 200.0)
	root_node.set("best_combo", 10)
	if int(root_node.call("calc_stars_for_test")) != 1:
		_fail("expected 1 star for slow clear")
		return

	if int(root_node.call("calc_coin_reward_for_test")) != 50:
		_fail("expected 50 coins for 1-star clear with max combo bonus")
		return
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	if int(root_node.call("calc_coin_reward_for_test")) != 60:
		_fail("expected 60 coins for 3-star clear")
		return

	if String(root_node.call("get_car_type_for_test")) != "compact":
		_fail("level 1 should be a compact car")
		return

	root_node.call("reset_game", 2)
	if int(root_node.call("get_combo_for_test")) != 0 or float(root_node.call("get_level_time_for_test")) != 0.0:
		_fail("reset did not clear combo state")
		return
	if String(root_node.call("get_car_type_for_test")) != "sports":
		_fail("level 2 should rotate to the sports car")
		return
	if int(root_node.call("get_patch_count_for_test")) < 20:
		_fail("level 2 should respawn dirt patches")
		return

	root_node.set("coins", 100)
	var bomb_oil_index: int = root_node.call("get_patch_index_by_kind_for_test", "oil")
	if bomb_oil_index < 0:
		_fail("level 2 oil patch missing")
		return
	root_node.call("apply_foam_bomb")
	if int(root_node.call("get_coins_for_test")) != 100 - 40:
		_fail("foam bomb should cost 40 coins")
		return
	if float(root_node.call("get_patch_soap_for_test", bomb_oil_index)) < 0.9:
		_fail("foam bomb should soap oil patches")
		return

	print("Foam Party smoke passed: patches=%d progress=%.3f best_combo=%d stars=%d" % [patch_count, progress_after, best_combo, stars])
	get_root().remove_child(root_node)
	root_node.free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
