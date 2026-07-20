extends SceneTree

const AdService := preload("res://scripts/services/ad_service.gd")
const NativeAds := preload("res://scripts/services/native_ad_config.gd")


class AnalyticsRecorder:
	extends Node

	var events: Array[Dictionary] = []

	func log_event(event_name: String, params: Dictionary = {}) -> void:
		events.append({"name": event_name, "params": params.duplicate(true)})


class RewardRecorder:
	extends RefCounted

	var grants := 0

	func grant() -> void:
		grants += 1


func _initialize() -> void:
	_run_smoke.call_deferred()


func _test_native_ad_contract() -> bool:
	if NativeAds.unit_id("interstitial", "game_over", "Android") != "ca-app-pub-3940256099942544/1033173712":
		_fail("Android native interstitial test ID missing")
		return false
	if NativeAds.unit_id("rewarded", "foam_bomb_free", "iOS") != "ca-app-pub-3940256099942544/1712485313":
		_fail("iOS native rewarded test ID missing")
		return false
	if not NativeAds.uses_non_personalized_ads("iOS"):
		_fail("iOS native ads must default to NPA")
		return false

	var service := AdService.new()
	var analytics_recorder := AnalyticsRecorder.new()
	var dismissed_recorder := RewardRecorder.new()
	get_root().add_child(service)
	service.configure(analytics_recorder)
	service.set("_pending_reward", Callable(dismissed_recorder, "grant"))
	service.set("_rewarded_in_flight", true)
	service.set("_native_reward_placement", "foam_bomb_free")
	if bool(service.show_rewarded("foam_bomb_free", Callable(dismissed_recorder, "grant"))):
		_fail("rewarded in-flight guard must reject a second show")
		return false
	service.call("_finish_native_rewarded", "foam_bomb_free")
	if dismissed_recorder.grants != 0:
		_fail("dismissed native rewarded ad must not grant a reward")
		return false

	var earned_recorder := RewardRecorder.new()
	service.set("_pending_reward", Callable(earned_recorder, "grant"))
	service.set("_rewarded_in_flight", true)
	service.set("_native_reward_placement", "foam_bomb_free")
	service.call("_on_native_reward_earned", null)
	service.call("_on_native_reward_earned", null)
	if earned_recorder.grants != 1:
		_fail("native earned callback must grant exactly once")
		return false
	var granted_events := analytics_recorder.events.filter(
		func(event: Dictionary) -> bool:
			return event.get("name") == "ad_rewarded_granted"
	)
	if granted_events.size() != 1:
		_fail("native reward analytics must log exactly once")
		return false
	var params: Dictionary = granted_events[0].get("params", {})
	if params.get("provider") != "admob" or params.get("placement") != "foam_bomb_free":
		_fail("native reward analytics params mismatch")
		return false
	service.call("_finish_native_rewarded", "foam_bomb_free")
	service.queue_free()
	return true


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
	for method_name in ["get_combo_for_test", "get_best_combo_for_test", "get_level_time_for_test", "calc_stars_for_test", "get_car_type_for_test", "get_license_plate_text_for_test", "get_license_plate_options_for_test", "get_car_transition_phase_for_test", "get_car_transition_offset_for_test"]:
		if not root_node.has_method(method_name):
			_fail("test helper API missing: " + method_name)
			return

	var patch_count: int = root_node.call("get_patch_count_for_test")
	if patch_count < 20:
		_fail("expected at least 20 dirt patches")
		return

	var selected_label: String = root_node.call("get_selected_tool_label_for_test")
	# The default tool is water; its label is localized (ko/en) via the i18n table,
	# so assert against the active locale's TOOL_WATER rather than a fixed string.
	var expected_label := TranslationServer.translate("TOOL_WATER")
	if selected_label.is_empty() or selected_label != expected_label:
		_fail("expected localized default tool label (got '%s', want '%s')" % [selected_label, expected_label])
		return

	var audio_count: int = root_node.call("get_audio_stream_count_for_test")
	if audio_count != 4:
		_fail("expected four tool audio streams")
		return

	var analytics_recorder := AnalyticsRecorder.new()
	root_node.add_child(analytics_recorder)
	root_node.set("analytics", analytics_recorder)
	if String(root_node.get("game_state")) != "title":
		_fail("game should boot to the title screen")
		return
	root_node.call("_go_home")
	root_node.call("_handle_tap", root_node.call("_get_start_rect").get_center())
	if String(root_node.get("game_state")) != "playing":
		_fail("play tap should enter playing state")
		return
	if not bool(root_node.get("show_tutorial")):
		_fail("first run should show the tutorial")
		return
	root_node.call("_dismiss_tutorial")
	if bool(root_node.get("show_tutorial")):
		_fail("tutorial should dismiss")
		return
	if not _test_ftue_entry_and_tutorial_event_order_and_params(analytics_recorder.events):
		return

	analytics_recorder.events.clear()
	root_node.call("reset_game", 2, "smoke_retry")
	if not _test_level_load_event_order_and_params(analytics_recorder.events):
		return

	# Early dirt catalogs grow monotonically and every spawned kind respects the
	# level gate. Repeating level 1 must preserve the seeded spawn sequence.
	var expected_dirt_by_level := {
		1: ["mud", "dust", "leaf"],
		2: ["mud", "dust", "leaf", "oil"],
		3: ["mud", "dust", "leaf", "oil", "bug", "poop"],
		4: ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime"],
	}
	var level_one_sequence: Array[String] = []
	for gated_level in expected_dirt_by_level:
		root_node.call("reset_game", gated_level)
		var spawned: Array[String] = root_node.call("get_spawned_dirt_kinds_for_test")
		for kind in spawned:
			if kind not in expected_dirt_by_level[gated_level]:
				_fail("level %d spawned locked dirt: %s" % [gated_level, kind])
				return
		if gated_level == 1:
			level_one_sequence = spawned.duplicate()
	root_node.call("reset_game", 1)
	if root_node.call("get_spawned_dirt_kinds_for_test") != level_one_sequence:
		_fail("level 1 dirt sequence should be deterministic for the fixed seed")
		return
	if not _test_dirt_spawn_density_contract(root_node):
		return
	if not _test_oil_sheen_contract(root_node):
		return
	root_node.call("reset_game", 1, "dirt_density_smoke_cleanup")

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

	var oil_index: int = root_node.call("spawn_patch_for_test", "oil")
	var oil_initial: float = root_node.call("get_patch_health_for_test", oil_index)
	var oil_after_water: float = root_node.call("apply_tool_to_patch_for_test", "water", oil_index, 1.0)
	var wrong_water_damage := oil_initial - oil_after_water
	if wrong_water_damage <= 0.0 or wrong_water_damage > 0.2:
		_fail("water alone should make only tiny progress on dry oil")
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

	# --- live grade tracker reflects the same criteria during play ---
	for grade_method in ["get_grade_slot_state_for_test", "get_grade_time_to_downgrade_for_test"]:
		if not root_node.has_method(grade_method):
			_fail("grade tracker API missing: " + grade_method)
			return
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	if String(root_node.call("get_grade_slot_state_for_test", 2)) != "earned":
		_fail("fast clear with combo should light the third star live")
		return
	if absf(float(root_node.call("get_grade_time_to_downgrade_for_test")) - 15.0) > 0.001:
		_fail("countdown should report time left before the third star drops")
		return
	root_node.set("best_combo", 2)
	if String(root_node.call("get_grade_slot_state_for_test", 2)) != "target":
		_fail("missing the combo gate should mark the third star as a target")
		return
	root_node.set("level_time", 100.0)
	root_node.set("best_combo", 5)
	if String(root_node.call("get_grade_slot_state_for_test", 2)) != "locked":
		_fail("slow-but-not-slowest clear should lock the third star")
		return
	if String(root_node.call("get_grade_slot_state_for_test", 1)) != "earned":
		_fail("second star should still be earned before the two-star threshold")
		return
	if absf(float(root_node.call("get_grade_time_to_downgrade_for_test")) - 40.0) > 0.001:
		_fail("countdown should track the two-star threshold once the third is lost")
		return
	root_node.set("level_time", 200.0)
	if String(root_node.call("get_grade_slot_state_for_test", 1)) != "locked":
		_fail("very slow clear should lock the second star")
		return
	if float(root_node.call("get_grade_time_to_downgrade_for_test")) >= 0.0:
		_fail("no countdown should remain once only the floor star is left")
		return
	root_node.set("best_combo", 10)

	if int(root_node.call("calc_coin_reward_for_test")) != 44:
		_fail("expected 44 coins for 1-star clear with max combo bonus")
		return
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	if int(root_node.call("calc_coin_reward_for_test")) != 50:
		_fail("expected 50 coins for 3-star clear")
		return

	if String(root_node.call("get_car_type_for_test")) != "compact":
		_fail("level 1 should be a compact car")
		return
	if not _test_expanded_car_roster_and_gameplay(root_node):
		return
	if not _test_new_car_types_reuse_existing_ui_residency(root_node):
		return
	if not _test_gold_spot_contract(root_node):
		return
	if not _test_water_impact_presentation_contract(root_node):
		return
	if not _test_particle_budget_contract(root_node):
		return
	if not _test_body_foam_coverage_contract(root_node):
		return
	if not _test_clean_shine_progression_contract(root_node):
		return
	if not _test_stage_selection_and_retry_contract(root_node):
		return
	if not _test_license_plate_customization(root_node):
		return

	root_node.call("reset_game", 5)
	root_node.set("level_time", 90.0)
	root_node.call("register_best_time_for_test")
	if not bool(root_node.call("is_new_record_for_test")):
		_fail("first clear of a level should be a new record")
		return
	if absf(float(root_node.call("get_best_time_for_test", 5)) - 90.0) > 0.001:
		_fail("best time should store the clear time")
		return
	root_node.set("level_time", 120.0)
	root_node.call("register_best_time_for_test")
	if bool(root_node.call("is_new_record_for_test")):
		_fail("a slower clear should not count as a new record")
		return
	if absf(float(root_node.call("get_best_time_for_test", 5)) - 90.0) > 0.001:
		_fail("a slower clear should not overwrite the best time")
		return
	root_node.set("level_time", 70.0)
	root_node.call("register_best_time_for_test")
	if not bool(root_node.call("is_new_record_for_test")):
		_fail("a faster clear should set a new record")
		return
	if absf(float(root_node.call("get_best_time_for_test", 5)) - 70.0) > 0.001:
		_fail("a faster clear should update the best time")
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
	# Ads absent (headless): no rewarded ad is ready, and the coin path is
	# unaffected — too few coins simply cannot buy a bomb (no ad fallback).
	var ads_node = root_node.get("ads")
	if ads_node != null and bool(ads_node.call("is_rewarded_ready", "foam_bomb_free")):
		_fail("no rewarded ad should be ready in headless")
		return
	root_node.set("coins", 10)  # below BOMB_COST (40)
	if bool(root_node.call("apply_foam_bomb")):
		_fail("foam bomb must not apply below cost when no ad grants it")
		return
	if int(root_node.call("get_coins_for_test")) != 10:
		_fail("failed foam bomb must not change coins")
		return
	if not _test_native_ad_contract():
		return

	# --- contextual "use this tool" hint ---
	for hint_method in ["is_tool_misapplied_for_test", "get_recommended_tool_for_test", "get_patch_hint_time_for_test", "simulate_patch_hint_for_test", "get_patch_count_by_kind_for_test", "spawn_patch_for_test"]:
		if not root_node.has_method(hint_method):
			_fail("hint helper API missing: " + hint_method)
			return
	root_node.call("reset_game", 2)
	var hint_leaf: int = root_node.call("get_patch_index_by_kind_for_test", "leaf")
	var hint_oil: int = root_node.call("get_patch_index_by_kind_for_test", "oil")
	if hint_leaf < 0 or hint_oil < 0:
		_fail("hint test patches missing")
		return
	if not bool(root_node.call("is_tool_misapplied_for_test", "water", hint_leaf)):
		_fail("water on leaf should be flagged as the wrong tool")
		return
	if bool(root_node.call("is_tool_misapplied_for_test", "air", hint_leaf)):
		_fail("air on leaf should not be flagged")
		return
	if String(root_node.call("get_recommended_tool_for_test", hint_leaf)) != "air":
		_fail("leaf should recommend air")
		return
	if String(root_node.call("simulate_patch_hint_for_test", "water", hint_leaf, 0.6)) != "air":
		_fail("rubbing the wrong tool on leaf should surface an air hint")
		return
	if String(root_node.call("get_active_hint_tool_for_test")) != "air":
		_fail("active hint tool should report air while coaching")
		return
	root_node.call("simulate_patch_hint_for_test", "air", hint_leaf, 0.1)
	if float(root_node.call("get_patch_hint_time_for_test", hint_leaf)) > 0.0:
		_fail("switching to the correct tool should clear the hint")
		return
	if String(root_node.call("get_active_hint_tool_for_test")) != "":
		_fail("active hint tool should clear once the hint is gone")
		return
	if String(root_node.call("get_recommended_tool_for_test", hint_oil)) != "soap":
		_fail("dry oil should recommend soap first")
		return
	if not bool(root_node.call("is_tool_misapplied_for_test", "sponge", hint_oil)):
		_fail("sponge on un-soaped oil should be flagged")
		return
	root_node.call("apply_tool_to_patch_for_test", "soap", hint_oil, 0.8)
	if String(root_node.call("get_recommended_tool_for_test", hint_oil)) != "sponge":
		_fail("soaped oil should recommend sponge")
		return
	if bool(root_node.call("is_tool_misapplied_for_test", "sponge", hint_oil)):
		_fail("sponge on soaped oil should not be flagged")
		return

	# Dry mud should coach toward water when scrubbed straight with a sponge.
	root_node.call("reset_game", 3)
	var hint_mud: int = root_node.call("get_patch_index_by_kind_for_test", "mud")
	if hint_mud < 0:
		_fail("mud patch missing for hint test")
		return
	if not bool(root_node.call("is_tool_misapplied_for_test", "sponge", hint_mud)):
		_fail("sponge on dry mud should be flagged")
		return
	if String(root_node.call("get_recommended_tool_for_test", hint_mud)) != "water":
		_fail("dry mud should recommend water")
		return
	if bool(root_node.call("is_tool_misapplied_for_test", "water", hint_mud)):
		_fail("water on mud should not be flagged")
		return

	# Brief stray touches must not accumulate into a hint (resist decays).
	var hint_leaf2: int = root_node.call("get_patch_index_by_kind_for_test", "leaf")
	if float(root_node.call("simulate_choppy_hint_for_test", "water", hint_leaf2, 0.15, 0.15, 3)) > 0.0:
		_fail("short stray rubs should not surface a hint")
		return
	if String(root_node.call("simulate_patch_hint_for_test", "water", hint_leaf2, 0.6)) != "air":
		_fail("sustained wrong rubbing should still surface the hint")
		return

	# --- road grime: pre-rinse first, then sponge removes ---
	var hint_road_grime: int = root_node.call("spawn_patch_for_test", "road_grime")
	if String(root_node.call("get_recommended_tool_for_test", hint_road_grime)) != "water":
		_fail("dry road grime should recommend water")
		return
	if bool(root_node.call("is_tool_misapplied_for_test", "water", hint_road_grime)):
		_fail("water on road grime should not be flagged")
		return
	if not bool(root_node.call("is_tool_misapplied_for_test", "air", hint_road_grime)):
		_fail("air on road grime should be flagged")
		return
	if not bool(root_node.call("is_tool_misapplied_for_test", "sponge", hint_road_grime)):
		_fail("dry sponge scrubbing on road grime should be flagged")
		return
	root_node.call("apply_tool_to_patch_for_test", "water", hint_road_grime, 0.2)
	if String(root_node.call("get_recommended_tool_for_test", hint_road_grime)) != "sponge":
		_fail("pre-rinsed road grime should recommend sponge")
		return
	if bool(root_node.call("is_tool_misapplied_for_test", "sponge", hint_road_grime)):
		_fail("sponge on pre-rinsed road grime should not be flagged")
		return
	var road_grime_health_before: float = float(root_node.call("get_patch_health_for_test", hint_road_grime))
	root_node.call("apply_tool_to_patch_for_test", "sponge", hint_road_grime, 0.5)
	var road_grime_health_after: float = float(root_node.call("get_patch_health_for_test", hint_road_grime))
	if road_grime_health_after >= road_grime_health_before:
		_fail("sponge should reduce pre-rinsed road grime health")
		return
	if String(root_node.call("get_patch_state_for_test", hint_road_grime)) != "loosened":
		_fail("sponge should loosen road grime")
		return

	# --- scrub drag trail builds while washing and fades once the pointer lifts ---
	if not root_node.has_method("get_wash_trail_count_for_test"):
		_fail("wash trail API missing")
		return
	root_node.call("reset_game", 1)
	root_node.set("game_state", "playing")
	root_node.set("show_tutorial", false)
	root_node.set("completed", false)
	root_node.set("is_washing", true)
	# Sweep the pointer across the play area; each frame feeds _update_wash_trail.
	for step in range(8):
		root_node.set("pointer_position", Vector2(120.0 + float(step) * 40.0, 400.0))
		root_node.call("_update_wash_trail", 0.016)
	if int(root_node.call("get_wash_trail_count_for_test")) < 2:
		_fail("scrubbing should build a drag trail")
		return
	# Lift the pointer and let time pass; the streak should age out completely.
	root_node.set("is_washing", false)
	for _i in range(40):
		root_node.call("_update_wash_trail", 0.05)
	if int(root_node.call("get_wash_trail_count_for_test")) != 0:
		_fail("drag trail should fade out after the pointer lifts")
		return

	# --- wash input is gated to the car/dirt band (WASH_AREA_TOP..BOTTOM) so
	# top-HUD/toolbar taps never start washing (iOS button/hint regression) ---
	if not bool(root_node.call("_point_in_wash_area", Vector2(200.0, 500.0))):
		_fail("a car-area point should be inside the wash band")
		return
	if bool(root_node.call("_point_in_wash_area", Vector2(200.0, 150.0))):
		_fail("a top-HUD point must be outside the wash band")
		return
	if bool(root_node.call("_point_in_wash_area", Vector2(200.0, 800.0))):
		_fail("a below-toolbar point must be outside the wash band")
		return
	if bool(root_node.call("_point_in_wash_area", Vector2.ZERO)):
		_fail("the zero/uninitialized pointer must be outside the wash band")
		return
	# A drag update outside the band must not build a wash trail.
	root_node.set("is_washing", true)
	root_node.set("pointer_position", Vector2(200.0, 150.0))
	root_node.call("_update_wash_trail", 0.016)
	if int(root_node.call("get_wash_trail_count_for_test")) != 0:
		_fail("washing above the wash band must not build a trail")
		return
	root_node.set("is_washing", false)

	# --- compact top HUD layout + pause/settings entry ---
	# Stars, customer mood, and mission share one row. Playing HUD exposes exactly
	# one 44px pause entry beside (not inside) the status card; direct sound/help
	# actions only exist on the title screen.
	var status_rect: Rect2 = root_node.call("_get_status_rect")
	var grade_rect: Rect2 = root_node.call("_get_grade_rect")
	var customer_rect: Rect2 = root_node.call("_get_customer_rect")
	var mission_rect: Rect2 = root_node.call("_get_daily_mission_rect")
	if not is_equal_approx(grade_rect.position.y, customer_rect.position.y) or not is_equal_approx(grade_rect.position.y, mission_rect.position.y):
		_fail("stars, customer mood, and mission must share one HUD row")
		return
	if grade_rect.intersects(customer_rect) or customer_rect.intersects(mission_rect) or grade_rect.intersects(mission_rect):
		_fail("compact HUD summary cards must not overlap")
		return
	var mission_bar_rect: Rect2 = root_node.call("_get_daily_mission_bar_rect")
	if mission_bar_rect.position.x - mission_rect.position.x < 8.0 or mission_rect.end.x - mission_bar_rect.end.x < 8.0:
		_fail("daily mission progress bar needs visible horizontal chip padding")
		return
	if mission_rect.end.y - mission_bar_rect.end.y < 6.0:
		_fail("daily mission progress bar needs visible bottom chip padding")
		return
	var pause_entry_rect: Rect2 = root_node.call("_get_pause_entry_rect")
	if pause_entry_rect.size != Vector2(44.0, 44.0):
		_fail("playing HUD must expose one 44px pause/settings entry")
		return
	if status_rect.intersects(pause_entry_rect):
		_fail("pause/settings entry must not overlap the status card")
		return

	# A simulated notch inset moves both status and entry together while keeping
	# them separate and fully below the safe-area boundary.
	OS.set_environment("FOAM_SAFE_AREA_DESIGN_INSETS", "0,42,0,0")
	var safe_status_rect: Rect2 = root_node.call("_get_status_rect")
	var safe_pause_rect: Rect2 = root_node.call("_get_pause_entry_rect")
	OS.set_environment("FOAM_SAFE_AREA_DESIGN_INSETS", "")
	if safe_status_rect.position.y < 50.0 or safe_pause_rect.position.y < 50.0:
		_fail("top HUD must move below the simulated notch inset")
		return
	if safe_status_rect.intersects(safe_pause_rect):
		_fail("safe-area offset must not make pause entry overlap status")
		return

	var pause_panel: Rect2 = root_node.call("_pause_panel")
	for pause_index in range(6):
		if not pause_panel.encloses(root_node.call("_pause_button_rect", pause_index)):
			_fail("pause/settings sheet must contain all six actions")
			return
	var language_rect: Rect2 = root_node.call("_pause_language_rect")
	var language_ko_rect: Rect2 = root_node.call("_pause_language_option_rect", "ko")
	var language_en_rect: Rect2 = root_node.call("_pause_language_option_rect", "en")
	if not pause_panel.encloses(language_rect) or not language_rect.encloses(language_ko_rect) or not language_rect.encloses(language_en_rect) or language_ko_rect.intersects(language_en_rect):
		_fail("pause/settings sheet must contain two separate language options")
		return
	for pause_index in range(6):
		if root_node.call("_pause_button_rect", pause_index).intersects(language_rect):
			_fail("language selector must not overlap pause actions")
			return

	# Keep the implementation contract explicit: these visible strings must stay
	# connected to TranslationServer through tr(), rather than becoming literals.
	var main_script_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_script_source.contains('return tr("PAUSE_TITLE")'):
		_fail("pause/settings title must be sourced from the PAUSE_TITLE i18n key")
		return
	if not main_script_source.contains('tr("GUIDE")'):
		_fail("pause/settings guide action must be sourced from the GUIDE i18n key")
		return
	if not main_script_source.contains('tr("PAUSE_RESTART")'):
		_fail("pause restart action must be sourced from the PAUSE_RESTART i18n key")
		return
	if not main_script_source.contains('config.get_value("settings", "language", "")') or not main_script_source.contains('config.set_value("settings", "language", language_preference)'):
		_fail("manual language preference must load from and save to the main settings file")
		return
	var language_save_path := OS.get_temp_dir().path_join("foam_party_language_smoke.cfg")
	var stored_config := ConfigFile.new()
	root_node.set("language_preference", "en")
	root_node.call("_store_language_preference", stored_config)
	if stored_config.save(language_save_path) != OK:
		_fail("language preference fixture failed to save")
		return
	var reloaded_config := ConfigFile.new()
	if reloaded_config.load(language_save_path) != OK:
		_fail("language preference fixture failed to reload")
		return
	root_node.set("language_preference", "")
	root_node.call("_load_language_preference", reloaded_config)
	DirAccess.remove_absolute(language_save_path)
	if String(root_node.call("get_language_preference_for_test")) != "en":
		_fail("explicit language preference must survive a ConfigFile disk round trip")
		return
	root_node.set("language_preference", "")

	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	var pause_labels_ko: Array = root_node.call("_pause_action_labels")
	if root_node.call("_pause_title_text") != "일시정지 · 설정" or String(pause_labels_ko[1]) != "이 차 다시 세차" or String(pause_labels_ko[3]) != "세차 가이드":
		_fail("pause title, restart, and guide actions must use Korean i18n keys")
		return
	TranslationServer.set_locale("en")
	var pause_labels_en: Array = root_node.call("_pause_action_labels")
	if root_node.call("_pause_title_text") != "Paused · Settings" or String(pause_labels_en[1]) != "Restart Car" or String(pause_labels_en[3]) != "Wash Guide":
		_fail("pause title, restart, and guide actions must use English i18n keys")
		return
	TranslationServer.set_locale(previous_locale)

	# --- one physical tap opens pause; sound/help live inside the sheet ---
	# Touch-to-mouse emulation used to feed _input twice: sound toggled off then
	# back on. Keep the code-level emulated-event guard covered on the sole entry.
	if Input.is_emulating_mouse_from_touch() or Input.is_emulating_touch_from_mouse():
		_fail("pointer-type emulation must stay disabled for dual mouse/touch handlers")
		return
	root_node.set("sound_enabled", true)
	root_node.set("show_tutorial", false)
	root_node.set("show_pause", false)
	root_node.call("_handle_tap", root_node.call("_get_title_sound_rect").get_center())
	root_node.call("_handle_tap", root_node.call("_get_title_help_rect").get_center())
	if not bool(root_node.get("sound_enabled")) or bool(root_node.get("show_tutorial")):
		_fail("playing HUD must not expose direct sound/help actions")
		return
	root_node.call("_update_canvas_transform")
	var input_canvas_origin: Vector2 = root_node.get("canvas_origin")
	var input_canvas_scale: float = float(root_node.get("canvas_scale"))
	var pause_point: Vector2 = input_canvas_origin + pause_entry_rect.get_center() * input_canvas_scale
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.device = 0
	# WKWebView uses opaque, non-zero Touch.identifier values on iOS.
	pause_touch.index = 279624489
	pause_touch.position = pause_point
	pause_touch.pressed = true
	root_node.call("_input", pause_touch)
	if not bool(root_node.get("show_pause")):
		_fail("one physical pause-entry touch should open settings")
		return
	var duplicate_pause_mouse := InputEventMouseButton.new()
	duplicate_pause_mouse.device = InputEvent.DEVICE_ID_EMULATION
	duplicate_pause_mouse.button_index = MOUSE_BUTTON_LEFT
	duplicate_pause_mouse.position = pause_point
	duplicate_pause_mouse.pressed = true
	root_node.call("_input", duplicate_pause_mouse)
	if not bool(root_node.get("show_pause")):
		_fail("emulated mouse duplicate must not close settings")
		return
	if bool(root_node.get("is_washing")):
		_fail("pause-entry touch must stop washing")
		return
	if int(root_node.get("_primary_touch_index")) != pause_touch.index:
		_fail("the first active iOS touch identifier must become the primary touch")
		return
	var pause_release := InputEventScreenTouch.new()
	pause_release.device = 0
	pause_release.index = pause_touch.index
	pause_release.position = pause_point
	pause_release.pressed = false
	root_node.call("_input", pause_release)
	if int(root_node.get("_primary_touch_index")) != -1:
		_fail("releasing the primary touch must clear its opaque identifier")
		return

	# The two language segments stay inside the modal sheet, apply immediately,
	# and persist an explicit preference instead of replacing device fallback by
	# default. Cached tool/car labels must rebuild along with tr() draw sites.
	root_node.call("_handle_tap", language_en_rect.get_center())
	if String(root_node.call("get_active_locale_for_test")) != "en" or String(root_node.call("get_language_preference_for_test")) != "en":
		_fail("English selection must immediately become the explicit preference")
		return
	if root_node.call("_pause_title_text") != "Paused · Settings" or String(root_node.call("get_selected_tool_label_for_test")) != "Jet" or not bool(root_node.get("show_pause")):
		_fail("English selection must redraw dynamic and cached labels without closing settings")
		return
	root_node.call("_handle_tap", language_ko_rect.get_center())
	if String(root_node.call("get_active_locale_for_test")) != "ko" or String(root_node.call("get_language_preference_for_test")) != "ko":
		_fail("Korean selection must immediately become the explicit preference")
		return
	if root_node.call("_pause_title_text") != "일시정지 · 설정" or String(root_node.call("get_selected_tool_label_for_test")) != "고압수":
		_fail("Korean selection must redraw dynamic and cached labels immediately")
		return

	var restart_level: int = int(root_node.get("active_level_index"))
	root_node.set("level_time", 12.5)
	root_node.set("combo_count", 4)
	root_node.set("best_combo", 6)
	root_node.set("clean_progress", 0.75)
	root_node.set("coins", 137)
	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 1).get_center())
	if bool(root_node.get("show_pause")) or int(root_node.get("active_level_index")) != restart_level:
		_fail("pause restart must close the sheet and keep the current level")
		return
	if float(root_node.call("get_level_time_for_test")) != 0.0 or int(root_node.call("get_combo_for_test")) != 0 or int(root_node.call("get_best_combo_for_test")) != 0:
		_fail("pause restart must reset timer and combo state")
		return
	if float(root_node.call("get_clean_progress_for_test")) != 0.0:
		_fail("pause restart must reset wash progress")
		return
	if int(root_node.call("get_coins_for_test")) != 137:
		_fail("pause restart must not grant or spend coins")
		return

	root_node.set("show_pause", true)
	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 2).get_center())
	if bool(root_node.get("sound_enabled")) or not bool(root_node.get("show_pause")):
		_fail("sound toggle must work only inside pause/settings")
		return
	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 3).get_center())
	if not bool(root_node.get("show_tutorial")):
		_fail("guide action inside pause/settings should open the tutorial")
		return
	if bool(root_node.get("show_pause")):
		_fail("guide overlay should replace the pause sheet while visible")
		return
	root_node.call("_dismiss_tutorial")
	if bool(root_node.get("show_tutorial")) or not bool(root_node.get("show_pause")):
		_fail("closing the guide should return to pause/settings")
		return
	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 0).get_center())
	if bool(root_node.get("show_pause")):
		_fail("resume action should close pause/settings")
		return
	if not _test_car_transition_contract(root_node):
		return
	root_node.set("language_preference", "")
	TranslationServer.set_locale(previous_locale)
	root_node.call("_rebuild_i18n_labels")

	print("Foam Party smoke passed: patches=%d progress=%.3f best_combo=%d stars=%d" % [patch_count, progress_after, best_combo, stars])
	get_root().remove_child(root_node)
	root_node.free()
	await process_frame
	quit(0)


func _test_ftue_entry_and_tutorial_event_order_and_params(events: Array[Dictionary]) -> bool:
	var actual_names: Array[String] = []
	for event in events:
		actual_names.append(String(event["name"]))
	var expected_names: Array[String] = [
		"title_screen_view",
		"play_tap",
		"game_start",
		"level_start",
		"tutorial_step_view",
		"tutorial_complete",
	]
	if actual_names != expected_names:
		_fail("FTUE event order changed: " + str(actual_names))
		return false
	if events[0]["params"] != {"entry": "pause_home"}:
		_fail("title screen entry params changed: " + str(events[0]))
		return false
	if events[1]["params"] != {"level": "1"}:
		_fail("play tap params changed: " + str(events[1]))
		return false
	if events[4]["params"] != {"step": "overview", "source": "first_run"}:
		_fail("tutorial view params changed: " + str(events[4]))
		return false
	if events[5]["params"] != {"step": "overview", "source": "first_run"}:
		_fail("tutorial completion params changed: " + str(events[5]))
		return false
	print("FTUE analytics smoke passed: " + " -> ".join(expected_names))
	return true


func _test_license_plate_customization(root_node: Node) -> bool:
	var panel: Rect2 = root_node.call("_skin_panel_rect")
	var options: Array = root_node.call("get_license_plate_options_for_test")
	if options.size() != 5 or String(root_node.call("get_license_plate_text_for_test")) != "FOAM":
		_fail("license plate customization should expose five safe presets and default to FOAM")
		return false
	for choice_index in range(options.size()):
		if not panel.encloses(root_node.call("_license_plate_choice_rect", panel, choice_index)):
			_fail("license plate choices must stay inside the customization sheet")
			return false
	root_node.call("_handle_skin_panel_tap", root_node.call("_license_plate_choice_rect", panel, 2).get_center())
	if String(root_node.call("get_license_plate_text_for_test")) != "WASH":
		_fail("selecting a license plate preset should update the rendered value")
		return false
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains('config.set_value("customization", "license_plate", license_plate_text)') \
			or not main_source.contains('config.get_value("customization", "license_plate"'):
		_fail("license plate selection must be wired to progress save and load")
		return false
	if not main_source.contains('tr("PLATE_TITLE")'):
		_fail("license plate editor label must use its i18n key")
		return false
	return true


func _test_car_transition_contract(root_node: Node) -> bool:
	root_node.call("reset_game", 2, "car_transition_smoke")
	root_node.set("game_state", "playing")
	root_node.set("show_tutorial", false)
	root_node.set("show_pause", false)
	root_node.set("show_quit_confirm", false)
	root_node.call("_begin_car_entry", true)
	if String(root_node.call("get_car_transition_phase_for_test")) != "entering":
		_fail("forced car entry should begin in the entering phase")
		return false
	var entry_start: Vector2 = root_node.call("get_car_transition_offset_for_test")
	if absf(entry_start.x - 450.0) > 0.001 or entry_start.y != 0.0:
		_fail("car entry must start outside the right edge")
		return false
	root_node.set("is_washing", false)
	root_node.call("_update_canvas_transform")
	var entry_touch := InputEventScreenTouch.new()
	entry_touch.device = 0
	entry_touch.index = 169
	entry_touch.position = root_node.get("canvas_origin") + Vector2(195.0, 520.0) * float(root_node.get("canvas_scale"))
	entry_touch.pressed = true
	root_node.call("_input", entry_touch)
	if bool(root_node.get("is_washing")):
		_fail("car entry must swallow wash-area input")
		return false
	entry_touch.pressed = false
	root_node.call("_input", entry_touch)
	root_node.set("level_time", 5.0)
	root_node.call("_process", 0.10)
	if absf(float(root_node.call("get_level_time_for_test")) - 5.0) > 0.001:
		_fail("car entry must pause the scored level timer")
		return false
	root_node.call("_update_car_transition", 0.16)
	var entry_mid: Vector2 = root_node.call("get_car_transition_offset_for_test")
	if entry_mid.x <= 0.0 or entry_mid.x >= entry_start.x:
		_fail("car entry offset must move toward the settled position")
		return false
	root_node.call("_update_car_transition", 0.30)
	if String(root_node.call("get_car_transition_phase_for_test")) != "idle" or root_node.call("get_car_transition_offset_for_test") != Vector2.ZERO:
		_fail("car entry must settle after about half a second")
		return false

	root_node.set("completed", true)
	root_node.call("_advance_to_next_level", true)
	if String(root_node.call("get_car_transition_phase_for_test")) != "exiting" or int(root_node.get("active_level_index")) != 2:
		_fail("next-car action must start exit before replacing the active level")
		return false
	root_node.call("_update_car_transition", 0.24)
	var exit_mid: Vector2 = root_node.call("get_car_transition_offset_for_test")
	if exit_mid.x >= 0.0 or exit_mid.x <= -450.0:
		_fail("car exit offset must move toward the left edge")
		return false
	root_node.call("_update_car_transition", 0.25)
	if int(root_node.get("active_level_index")) != 3 or String(root_node.call("get_car_transition_phase_for_test")) != "idle":
		_fail("next level must load only after the exit finishes in headless mode")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("_set_gameplay_draw_transform(transition_offset)") \
			or not main_source.contains("_set_design_draw_transform(transition_offset)"):
		_fail("car, dirt, and particles must share one transition offset")
		return false
	root_node.call("reset_game", 1, "car_transition_smoke_cleanup")
	return true


func _test_dirt_spawn_density_contract(root_node: Node) -> bool:
	for method_name in ["get_patch_centers_for_test", "get_dirt_spawn_pool_size_for_test", "get_dirt_spawn_min_center_distance_for_test"]:
		if not root_node.has_method(method_name):
			_fail("dirt density helper API missing: " + method_name)
			return false
	var expected_counts := {1: 20, 2: 22, 3: 24, 4: 26, 5: 28, 6: 30, 10: 38, 30: 40}
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	for level in expected_counts:
		root_node.call("reset_game", level, "dirt_density_smoke")
		var count: int = root_node.call("get_patch_count_for_test")
		if count != expected_counts[level]:
			_fail("level %d dirt count changed: got %d, want %d" % [level, count, expected_counts[level]])
			return false
		if int(root_node.call("get_dirt_spawn_pool_size_for_test")) < 40:
			_fail("level %d car silhouette must retain the 40-slot density cap" % level)
			return false
		var centers: Array[Vector2] = root_node.call("get_patch_centers_for_test")
		var minimum_distance: float = root_node.call("get_dirt_spawn_min_center_distance_for_test")
		for first_index in range(centers.size()):
			if not bool(root_node.call("_point_in_wash_area", centers[first_index])):
				_fail("level %d spawned dirt outside the washable area" % level)
				return false
			for second_index in range(first_index + 1, centers.size()):
				if centers[first_index].distance_to(centers[second_index]) < minimum_distance - 0.01:
					_fail("level %d dirt centers violated the overlap guard" % level)
					return false

	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("dirt density must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("dirt density must not change top HUD residency")
		return false
	return true


func _test_expanded_car_roster_and_gameplay(root_node: Node) -> bool:
	var expected_new_cars := {4: "van", 5: "offroad"}
	var car_shapes: Dictionary = root_node.get("car_shapes")
	var car_labels: Dictionary = root_node.get("car_type_labels")
	for level in expected_new_cars:
		root_node.call("reset_game", level, "car_roster_smoke")
		var expected_type: String = expected_new_cars[level]
		if String(root_node.call("get_car_type_for_test")) != expected_type:
			_fail("level %d should restore the %s car" % [level, expected_type])
			return false
		if not car_shapes.has(expected_type):
			_fail("missing procedural shape for car type: " + expected_type)
			return false
		if String(car_labels.get(expected_type, "")).is_empty():
			_fail("missing localized label for car type: " + expected_type)
			return false
		if int(root_node.call("get_patch_count_for_test")) < 20:
			_fail("new car type did not spawn the expected dirt count: " + expected_type)
			return false
		for raw_patch in root_node.get("dirt_patches"):
			if float(raw_patch.get("max_health")) <= 0.0:
				_fail("new car type spawned invalid dirt health: " + expected_type)
				return false
		root_node.set("level_time", 60.0)
		root_node.set("best_combo", 5)
		if int(root_node.call("calc_stars_for_test")) < 1:
			_fail("new car type did not integrate with star scoring: " + expected_type)
			return false
	root_node.call("reset_game", 1, "car_roster_smoke_cleanup")
	return true


func _test_new_car_types_reuse_existing_ui_residency(root_node: Node) -> bool:
	var hud_rect_methods := [
		"_get_status_rect",
		"_get_grade_rect",
		"_get_customer_rect",
		"_get_daily_mission_rect",
		"_get_pause_entry_rect",
	]
	var baseline_rects: Dictionary = {}
	for method_name in hud_rect_methods:
		baseline_rects[method_name] = root_node.call(method_name)
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	for level in [4, 5]:
		root_node.call("reset_game", level, "car_ui_residency_smoke")
		for method_name in hud_rect_methods:
			if root_node.call(method_name) != baseline_rects[method_name]:
				_fail("car type must not change top HUD residency: " + method_name)
				return false
		if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
			_fail("new car types must not add persistent HUD controls")
			return false
	root_node.call("reset_game", 1, "car_ui_residency_smoke_cleanup")
	return true


func _test_gold_spot_contract(root_node: Node) -> bool:
	var required_methods := [
		"get_gold_spot_count_for_test",
		"get_gold_spot_index_for_test",
		"get_gold_spot_rewards_granted_for_test",
		"get_gold_spot_pop_amount_for_test",
		"set_patch_gold_spot_for_test",
	]
	for method_name in required_methods:
		if not root_node.has_method(method_name):
			_fail("gold spot helper API missing: " + method_name)
			return false

	var original_coins: int = root_node.call("get_coins_for_test")
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}

	root_node.call("reset_game", 2, "gold_spot_seed_smoke")
	if int(root_node.call("get_gold_spot_count_for_test")) != 1:
		_fail("configured level 2 seed should spawn exactly one gold spot")
		return false
	var first_index: int = root_node.call("get_gold_spot_index_for_test")
	var first_kinds: Array[String] = root_node.call("get_spawned_dirt_kinds_for_test")
	root_node.call("reset_game", 2, "gold_spot_seed_retry")
	if int(root_node.call("get_gold_spot_count_for_test")) != 1 or int(root_node.call("get_gold_spot_index_for_test")) != first_index:
		_fail("gold spot retry must reproduce the deterministic target index")
		return false
	if root_node.call("get_spawned_dirt_kinds_for_test") != first_kinds:
		_fail("gold spot selection must not change the underlying dirt sequence")
		return false

	root_node.call("reset_game", 1, "gold_spot_reward_smoke")
	for raw_patch in root_node.get("dirt_patches"):
		raw_patch.set("is_gold_spot", false)
	root_node.set("coins", 0)
	if not bool(root_node.call("set_patch_gold_spot_for_test", 0, true)):
		_fail("gold spot test target setup failed")
		return false
	root_node.call("_mark_patch_removed", root_node.get("dirt_patches")[0])
	if int(root_node.call("get_coins_for_test")) != 8 or int(root_node.call("get_gold_spot_rewards_granted_for_test")) != 1:
		_fail("first gold spot removal should grant the capped +8 reward")
		return false
	if int(root_node.call("get_gold_spot_pop_amount_for_test")) != 8:
		_fail("gold spot reward should create a local transient coin pop")
		return false

	root_node.call("set_patch_gold_spot_for_test", 0, false)
	root_node.call("set_patch_gold_spot_for_test", 1, true)
	root_node.call("_mark_patch_removed", root_node.get("dirt_patches")[1])
	if int(root_node.call("get_coins_for_test")) != 8 or int(root_node.call("get_gold_spot_rewards_granted_for_test")) != 1:
		_fail("a second gold flag must not bypass the per-level reward cap")
		return false

	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("gold spot presentation must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("gold spot presentation must not change HUD residency")
		return false

	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var marker_start := source.find("func _draw_gold_spot_marker(")
	if marker_start < 0:
		_fail("gold spot marker renderer is missing")
		return false
	var marker_end := source.find("\nfunc ", marker_start + 1)
	var marker_body := source.substr(marker_start, marker_end - marker_start)
	if marker_body.find("draw_arc") < 0 or marker_body.find("PackedVector2Array") < 0:
		_fail("gold spot marker must combine an outline with a non-color sparkle shape")
		return false
	if source.find("func _draw_gold_spot_reward_pop()") < 0:
		_fail("gold spot reward must stay in a transient local popup renderer")
		return false

	root_node.set("coins", original_coins)
	root_node.call("reset_game", 1, "gold_spot_smoke_cleanup")
	return true


func _test_water_impact_presentation_contract(root_node: Node) -> bool:
	root_node.call("reset_game", 1, "water_impact_smoke")
	var particles: Array = root_node.get("particles")
	var impact_point := Vector2(195.0, 520.0)
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	var baseline_coins: int = root_node.call("get_coins_for_test")
	var baseline_stars: int = root_node.call("calc_stars_for_test")

	particles.clear()
	root_node.call("_spawn_water_particles", impact_point)
	if _particle_style_count(particles, "spray_fan") < 1:
		_fail("water impact should spawn a spray fan")
		return false
	if _particle_style_count(particles, "splash") < 2:
		_fail("water impact should spawn an immediate splash burst")
		return false
	if _particle_style_count(particles, "mist") < 1:
		_fail("water impact should spawn a mist cloud")
		return false

	for index in range(100):
		root_node.call("_spawn_water_particles", impact_point)
	var water_count: int = root_node.call("get_water_effect_particle_count_for_test")
	var water_cap: int = root_node.call("get_water_effect_particle_cap_for_test")
	if water_count != water_cap:
		_fail("water impact particles should stay at the explicit cap")
		return false

	particles.clear()
	root_node.set("combo_count", 1)
	root_node.call("_spawn_water_removal_splash", impact_point, 18.0)
	var low_combo_splashes := _particle_style_count(particles, "splash")
	var low_combo_mist := _particle_style_count(particles, "mist")
	particles.clear()
	root_node.set("combo_count", 9)
	root_node.call("_spawn_water_removal_splash", impact_point, 18.0)
	if _particle_style_count(particles, "splash") <= low_combo_splashes:
		_fail("water removal splash should scale with combo")
		return false
	if _particle_style_count(particles, "mist") <= low_combo_mist:
		_fail("water removal mist should scale with combo")
		return false

	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("water impact presentation must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("water impact presentation must not change top HUD residency")
		return false
	if int(root_node.call("get_coins_for_test")) != baseline_coins or int(root_node.call("calc_stars_for_test")) != baseline_stars:
		_fail("water impact presentation must not change economy or star rules")
		return false

	particles.clear()
	root_node.set("combo_count", 0)
	return true


func _particle_style_count(particles: Array, style: String) -> int:
	var count := 0
	for raw_particle in particles:
		if String(raw_particle.get("style")) == style:
			count += 1
	return count


func _test_particle_budget_contract(root_node: Node) -> bool:
	var required_methods := [
		"get_particle_count_for_test",
		"get_particle_cap_for_test",
		"get_water_effect_particle_cap_for_test",
		"get_foam_effect_particle_cap_for_test",
	]
	for method_name in required_methods:
		if not root_node.has_method(method_name):
			_fail("particle budget helper API missing: " + method_name)
			return false

	var particles: Array = root_node.get("particles")
	var particle_cap: int = root_node.call("get_particle_cap_for_test")
	var style_cap_sum: int = int(root_node.call("get_water_effect_particle_cap_for_test")) + int(root_node.call("get_foam_effect_particle_cap_for_test"))
	if particle_cap <= style_cap_sum:
		_fail("global particle cap should leave headroom above water and foam caps")
		return false

	particles.clear()
	for index in range(100):
		root_node.call("_spawn_air_particles", Vector2(195.0, 520.0))
	if int(root_node.call("get_particle_count_for_test")) != particle_cap:
		_fail("continuous tool input should stop at the global particle cap")
		return false
	var oldest_particle: Variant = particles[0]
	root_node.call("_spawn_air_particles", Vector2(195.0, 520.0))
	if particles.size() != particle_cap or particles.has(oldest_particle):
		_fail("global particle overflow should evict the oldest particle")
		return false

	particles.clear()
	for index in range(100):
		var point := Vector2(120.0 + float(index % 4) * 50.0, 480.0)
		root_node.call("_spawn_water_particles", point)
		root_node.call("_spawn_soap_particles", point)
		root_node.call("_spawn_air_particles", point)
	if particles.size() != particle_cap:
		_fail("mixed effect stress should remain exactly at the global particle cap")
		return false
	if int(root_node.call("get_water_effect_particle_count_for_test")) > int(root_node.call("get_water_effect_particle_cap_for_test")):
		_fail("global particle budget must preserve the water effect cap")
		return false
	if int(root_node.call("get_foam_effect_particle_count_for_test")) > int(root_node.call("get_foam_effect_particle_cap_for_test")):
		_fail("global particle budget must preserve the foam effect cap")
		return false

	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if source.count("particles.append(") != 2:
		_fail("all transient particles must enter through the bounded append helpers")
		return false

	particles.clear()
	return true


func _test_body_foam_coverage_contract(root_node: Node) -> bool:
	var required_methods := [
		"get_body_foam_coverage_for_test",
		"get_body_foam_runoff_for_test",
		"get_body_foam_spot_count_for_test",
		"get_foam_bomb_burst_count_for_test",
		"get_foam_effect_particle_count_for_test",
		"get_foam_effect_particle_cap_for_test",
		"apply_body_foam_tool_for_test",
	]
	for method_name in required_methods:
		if not root_node.has_method(method_name):
			_fail("body foam helper API missing: " + method_name)
			return false

	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	for level in [1, 2, 3, 4, 5]:
		root_node.call("reset_game", level, "body_foam_roster_smoke")
		if int(root_node.call("get_body_foam_spot_count_for_test")) < 18:
			_fail("body foam coverage should fit the full level %d car silhouette" % level)
			return false

	root_node.call("reset_game", 1, "body_foam_smoke")
	root_node.call("apply_body_foam_tool_for_test", "soap", 1.0)
	var soap_coverage: float = root_node.call("get_body_foam_coverage_for_test")
	if soap_coverage < 0.3 or soap_coverage >= 1.0:
		_fail("soap should build partial body-wide foam coverage")
		return false
	root_node.call("apply_body_foam_tool_for_test", "water", 0.25)
	if float(root_node.call("get_body_foam_coverage_for_test")) >= soap_coverage:
		_fail("water should rinse body-wide foam coverage")
		return false
	if float(root_node.call("get_body_foam_runoff_for_test")) <= 0.0:
		_fail("water rinse should leave a short-lived foam runoff read")
		return false

	# Level 5 fills the 24-position pool, so its 72 patch bubbles deliberately
	# exceed the cap before the full-body burst is appended.
	root_node.call("reset_game", 5, "body_foam_cap_smoke")
	root_node.get("particles").clear()
	root_node.set("coins", 100)
	var burst_before: int = root_node.call("get_foam_bomb_burst_count_for_test")
	if not bool(root_node.call("apply_foam_bomb")):
		_fail("affordable foam bomb should apply")
		return false
	if float(root_node.call("get_body_foam_coverage_for_test")) < 0.999:
		_fail("foam bomb should cover the full car body immediately")
		return false
	if int(root_node.call("get_foam_bomb_burst_count_for_test")) != burst_before + 1:
		_fail("successful foam bomb should emit exactly one full-body burst")
		return false
	var foam_particle_count: int = root_node.call("get_foam_effect_particle_count_for_test")
	var foam_particle_cap: int = root_node.call("get_foam_effect_particle_cap_for_test")
	if foam_particle_count <= 0 or foam_particle_count > foam_particle_cap:
		_fail("foam effects must stay inside their particle cap")
		return false
	if int(root_node.call("get_particle_count_for_test")) > int(root_node.call("get_particle_cap_for_test")):
		_fail("foam bomb must stay inside the global particle cap")
		return false
	root_node.set("coins", 0)
	if bool(root_node.call("apply_foam_bomb")) or int(root_node.call("get_foam_bomb_burst_count_for_test")) != burst_before + 1:
		_fail("failed foam bomb must not emit another burst")
		return false

	root_node.set("body_foam_coverage", 0.75)
	root_node.set("body_foam_runoff", 0.5)
	for raw_patch in root_node.get("dirt_patches"):
		raw_patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if not bool(root_node.get("completed")) or float(root_node.call("get_body_foam_coverage_for_test")) > 0.001 or float(root_node.call("get_body_foam_runoff_for_test")) > 0.001:
		_fail("level completion should clear persistent foam and runoff")
		return false

	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("body foam presentation must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("body foam presentation must not change top HUD residency")
		return false

	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var car_start := source.find("func _draw_car() -> void:")
	var car_end := source.find("\nfunc ", car_start + 1)
	var car_body := source.substr(car_start, car_end - car_start)
	if car_body.find("_draw_body_foam(silhouette)") < 0:
		_fail("body foam must stay inside the car silhouette render pass")
		return false

	root_node.call("reset_game", 1, "body_foam_smoke_cleanup")
	if float(root_node.call("get_body_foam_coverage_for_test")) > 0.001 or float(root_node.call("get_body_foam_runoff_for_test")) > 0.001:
		_fail("level reset should clear body foam state")
		return false
	return true


func _test_clean_shine_progression_contract(root_node: Node) -> bool:
	root_node.call("reset_game", 1, "clean_shine_smoke")
	var sample_progress := [0.0, 0.25, 0.5, 0.75, 1.0]
	var previous_alpha := -1.0
	for progress in sample_progress:
		var alpha: float = root_node.call("get_clean_shine_alpha_for_test", progress)
		if alpha <= previous_alpha:
			_fail("clean shine alpha should increase continuously with progress")
			return false
		previous_alpha = alpha
	if float(root_node.call("get_clean_shine_alpha_for_test", 0.0)) > 0.001:
		_fail("zero progress should keep the car matte")
		return false
	if float(root_node.call("get_clean_shine_alpha_for_test", 1.0)) < 0.4:
		_fail("near-complete progress should produce a clear shine")
		return false
	if float(root_node.call("get_clean_shine_intensity_scale_for_test")) <= 0.0:
		_fail("clean shine needs a single positive intensity scale hook")
		return false

	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.set("clean_progress", 0.5)
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("clean shine must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("clean shine must not change top HUD residency")
		return false

	# Source-order contract: shine is part of the car pass, while all dirt is
	# painted later and therefore masks the reflection over remaining patches.
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var draw_start := source.find("func _draw() -> void:")
	var draw_end := source.find("\nfunc ", draw_start + 1)
	var draw_body := source.substr(draw_start, draw_end - draw_start)
	if draw_body.find("_draw_car()") < 0 or draw_body.find("_draw_dirt()") <= draw_body.find("_draw_car()"):
		_fail("dirt must render after the car shine so grime masks reflection")
		return false
	var car_start := source.find("func _draw_car() -> void:")
	var car_end := source.find("\nfunc ", car_start + 1)
	var car_body := source.substr(car_start, car_end - car_start)
	if car_body.find("_draw_clean_shine()") < 0:
		_fail("clean shine must stay inside the car render pass")
		return false

	var near_complete_alpha: float = root_node.call("get_clean_shine_alpha_for_test", 0.98)
	for raw_patch in root_node.get("dirt_patches"):
		raw_patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if not bool(root_node.get("completed")) or float(root_node.get("_gleam_time")) < 0.0:
		_fail("completion should start the existing gleam sweep")
		return false
	if float(root_node.call("get_clean_shine_alpha_for_test", root_node.get("clean_progress"))) < near_complete_alpha:
		_fail("static clean shine should remain continuous into completion gleam")
		return false

	root_node.call("reset_game", 1, "clean_shine_smoke_cleanup")
	if float(root_node.call("get_clean_progress_for_test")) > 0.001 or float(root_node.call("get_clean_shine_alpha_for_test", root_node.call("get_clean_progress_for_test"))) > 0.001:
		_fail("level reset should return clean shine to matte")
		return false
	return true


func _test_oil_sheen_contract(root_node: Node) -> bool:
	for method_name in ["get_oil_sheen_band_count_for_test", "get_oil_sheen_alpha_for_test", "get_oil_sheen_saturation_for_test"]:
		if not root_node.has_method(method_name):
			_fail("oil sheen test helper API missing: " + method_name)
			return false

	var band_count: int = root_node.call("get_oil_sheen_band_count_for_test")
	if band_count != 5 or band_count > 6:
		_fail("oil sheen must keep a small, fixed band budget")
		return false
	var zero_alpha: float = root_node.call("get_oil_sheen_alpha_for_test", 0.0)
	var faded_alpha: float = root_node.call("get_oil_sheen_alpha_for_test", 0.35)
	var full_alpha: float = root_node.call("get_oil_sheen_alpha_for_test", 1.0)
	if zero_alpha > 0.001 or faded_alpha <= zero_alpha or full_alpha <= faded_alpha:
		_fail("oil sheen alpha must fade monotonically with patch strength")
		return false
	var faded_saturation: float = root_node.call("get_oil_sheen_saturation_for_test", 0.35)
	var full_saturation: float = root_node.call("get_oil_sheen_saturation_for_test", 1.0)
	if faded_saturation <= 0.0 or full_saturation <= faded_saturation or full_saturation > 1.0:
		_fail("oil sheen saturation must fade with patch strength")
		return false

	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var oil_start := source.find("func _draw_oil_patch(")
	var oil_end := source.find("\nfunc ", oil_start + 1)
	var oil_body := source.substr(oil_start, oil_end - oil_start)
	var sheen_start := source.find("func _draw_oil_sheen(")
	var sheen_end := source.find("\nfunc ", sheen_start + 1)
	var sheen_body := source.substr(sheen_start, sheen_end - sheen_start)
	var bug_start := source.find("func _draw_bug_patch(")
	var bug_end := source.find("\nfunc ", bug_start + 1)
	var bug_body := source.substr(bug_start, bug_end - bug_start)
	if oil_body.find("_draw_oil_sheen(") < 0 or sheen_body.find("Color.from_hsv") < 0 or sheen_body.find("draw_arc") < 0:
		_fail("oil renderer must contain HSV film bands and a shaped gloss arc")
		return false
	if bug_body.find("_draw_oil_sheen") >= 0:
		_fail("oil sheen must stay isolated from bug rendering")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("oil sheen must not add persistent HUD controls")
		return false
	return true


func _test_stage_selection_and_retry_contract(root_node: Node) -> bool:
	var original_unlocked: int = root_node.call("get_unlocked_level_for_test")
	var original_best_times: Dictionary = root_node.get("best_times").duplicate(true)
	var original_best_stars: Dictionary = root_node.get("best_stars").duplicate(true)
	root_node.set("level_index", 5)
	root_node.set("best_times", {1: 90.0, 2: 84.0, 4: 76.0})
	root_node.set("best_stars", {1: 2, 2: 3, 4: 1})
	root_node.call("_go_home")

	var stage_button: Rect2 = root_node.call("_get_stage_btn_rect")
	for other_rect in [root_node.call("_get_start_rect"), root_node.call("_get_upgrade_btn_rect"), root_node.call("_get_skin_btn_rect")]:
		if stage_button.intersects(other_rect):
			_fail("stage title button must not overlap existing title actions")
			return false
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.call("_handle_tap", stage_button.get_center())
	if not bool(root_node.get("show_stage_panel")) or String(root_node.get("game_state")) != "title":
		_fail("stage button should open a title-only sheet")
		return false
	var cards: Array[Dictionary] = root_node.call("get_stage_cards_for_test", 0)
	if cards.size() != 6 or int(cards[0]["level"]) != 1 or not bool(cards[4]["unlocked"]) or bool(cards[5]["unlocked"]):
		_fail("stage sheet should expose levels 1-5 and lock level 6")
		return false
	if absf(float(cards[1]["best_time"]) - 84.0) > 0.001 or int(cards[1]["best_stars"]) != 3:
		_fail("stage sheet should project per-level time and stars")
		return false
	if float(cards[2]["best_time"]) != 0.0 or int(cards[2]["best_stars"]) != 0:
		_fail("stage sheet should keep missing records empty")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("stage sheet must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("stage sheet must not change gameplay HUD residency")
		return false

	var panel: Rect2 = root_node.call("_stage_panel_rect")
	root_node.call("_handle_stage_panel_tap", root_node.call("_stage_card_rect", panel, 0).get_center())
	if String(root_node.get("game_state")) != "playing" or int(root_node.call("get_active_level_for_test")) != 1:
		_fail("unlocked stage card should start that level")
		return false
	if int(root_node.call("get_unlocked_level_for_test")) != 5:
		_fail("stage retry must preserve highest unlocked progression")
		return false
	var first_seed_sequence: Array[String] = root_node.call("get_spawned_dirt_kinds_for_test")
	root_node.call("reset_game", 1, "stage_seed_repeat")
	if root_node.call("get_spawned_dirt_kinds_for_test") != first_seed_sequence:
		_fail("stage retry should reproduce the deterministic level seed")
		return false

	root_node.set("level_time", 70.0)
	root_node.set("earned_stars", 3)
	root_node.call("register_best_time_for_test")
	if absf(float(root_node.call("get_best_time_for_test", 1)) - 70.0) > 0.001 or int(root_node.call("get_best_stars_for_test", 1)) != 3:
		_fail("faster stage retry should update time and best stars")
		return false
	root_node.set("level_time", 100.0)
	root_node.set("earned_stars", 2)
	root_node.call("register_best_time_for_test")
	if absf(float(root_node.call("get_best_time_for_test", 1)) - 70.0) > 0.001 or int(root_node.call("get_best_stars_for_test", 1)) != 3:
		_fail("slower retry must not overwrite stage records")
		return false
	if int(root_node.call("get_unlocked_level_for_test")) != 5:
		_fail("record updates must not roll back unlocked progression")
		return false

	root_node.call("_go_home")
	root_node.call("_handle_tap", stage_button.get_center())
	root_node.call("_handle_stage_panel_tap", root_node.call("_stage_card_rect", panel, 5).get_center())
	if not bool(root_node.get("show_stage_panel")) or int(root_node.call("get_active_level_for_test")) != 1:
		_fail("locked stage card must not start a level")
		return false
	root_node.call("_on_back_pressed")
	if bool(root_node.get("show_stage_panel")) or String(root_node.get("game_state")) != "title" or bool(root_node.get("show_quit_confirm")):
		_fail("back should close only the stage sheet and return to title")
		return false

	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not source.contains('config.get_value("game", "best_stars"') or not source.contains('config.set_value("game", "best_stars"'):
		_fail("stage best stars must be loaded and saved")
		return false

	root_node.set("level_index", original_unlocked)
	root_node.set("best_times", original_best_times)
	root_node.set("best_stars", original_best_stars)
	root_node.call("reset_game", 1, "stage_smoke_cleanup")
	root_node.call("start_game", 1, "stage_smoke_cleanup")
	return true


func _test_level_load_event_order_and_params(events: Array[Dictionary]) -> bool:
	var actual_names: Array[String] = []
	for event in events:
		actual_names.append(String(event["name"]))
	if actual_names != ["level_load_start", "level_load_complete", "level_start"]:
		_fail("level load event order changed: " + str(actual_names))
		return false
	if events[0]["params"] != {"level": "2", "reason": "smoke_retry"}:
		_fail("level load start params changed: " + str(events[0]))
		return false
	var load_complete_params: Dictionary = events[1]["params"]
	if String(load_complete_params.get("level", "")) != "2" or String(load_complete_params.get("reason", "")) != "smoke_retry" or String(load_complete_params.get("car_type", "")).is_empty():
		_fail("level load complete params changed: " + str(load_complete_params))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
