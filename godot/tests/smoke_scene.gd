extends SceneTree

const AdService := preload("res://scripts/services/ad_service.gd")
const GameConfig := preload("res://core/domain/game_config.gd")
const Economy := preload("res://core/use_cases/economy.gd")
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


func _test_economy_balance_hud_residency(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var original_level_time := float(root_node.get("level_time"))
	var original_best_combo := int(root_node.get("best_combo"))
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 15)
	var reward := int(root_node.call("calc_coin_reward_for_test"))
	root_node.set("level_time", original_level_time)
	root_node.set("best_combo", original_best_combo)
	if reward != 70:
		_fail("economy residency fixture must execute the combo-15 reward path")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("economy balance must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("economy balance must keep the existing top HUD residency unchanged")
		return false
	return true


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


func _test_achievement_contract(root_node: Node) -> bool:
	var definitions: Array[Dictionary] = root_node.call("get_achievement_definitions_for_test")
	if definitions.size() != 5:
		_fail("achievement sheet must expose five local lifetime goals")
		return false
	var original_state := {
		"counters": root_node.call("get_achievement_counters_for_test"),
		"claimed": root_node.call("get_achievement_claimed_for_test"),
		"coins": root_node.get("coins"),
		"game_state": root_node.get("game_state"),
		"active_level": root_node.call("get_active_level_for_test"),
		"selected_tool": root_node.get("selected_tool"),
		"main_save_dirty": root_node.get("_main_save_dirty"),
		"daily_type": root_node.get("daily_mission_type"),
		"daily_progress": root_node.get("daily_mission_progress"),
		"daily_claimed": root_node.get("daily_mission_claimed"),
	}
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	# AC-2: drive the real local gameplay hook. One removed leaf is also one
	# removed dirt spot and the first observed combo peak; no analytics input or
	# external value is supplied to the achievement state.
	root_node.call("reset_game", 1, "achievement_local_counter_smoke")
	root_node.set("daily_mission_claimed", true)
	root_node.call("set_achievement_state_for_test", {}, {})
	var leaf_index := int(root_node.call("get_patch_index_by_kind_for_test", "leaf"))
	if leaf_index < 0:
		_fail("local achievement smoke needs a leaf patch")
		return false
	root_node.call("_mark_patch_removed", (root_node.get("dirt_patches") as Array)[leaf_index])
	var local_counters: Dictionary = root_node.call("get_achievement_counters_for_test")
	if int(local_counters.get("dirt_removed", 0)) != 1 \
			or int(local_counters.get("leaf_removed", 0)) != 1 \
			or int(local_counters.get("combo_peak", 0)) != 1:
		_fail("real leaf removal must feed only local dirt, leaf, and combo counters")
		return false

	root_node.call("set_achievement_state_for_test", {}, {})
	root_node.set("coins", 0)
	var expected_coins := 0
	for definition in definitions:
		var counter_key := String(definition["counter"])
		var achievement_id := String(definition["id"])
		var target := int(definition["target"])
		var reward := int(definition["reward"])
		if int(root_node.call("record_achievement_progress_for_test", counter_key, target - 1)) != 0:
			_fail("achievement reward must stay locked below target: " + achievement_id)
			return false
		if bool((root_node.call("get_achievement_claimed_for_test") as Dictionary).get(achievement_id, false)):
			_fail("achievement completed below target: " + achievement_id)
			return false
		if int(root_node.call("record_achievement_progress_for_test", counter_key, target)) != reward:
			_fail("achievement threshold reward mismatch: " + achievement_id)
			return false
		expected_coins += reward
		if int(root_node.get("coins")) != expected_coins:
			_fail("achievement reward must add exactly once: " + achievement_id)
			return false
		if int(root_node.call("record_achievement_progress_for_test", counter_key, target + 100)) != 0 \
				or int(root_node.get("coins")) != expected_coins:
			_fail("completed achievement paid twice: " + achievement_id)
			return false
	var completed_counters: Dictionary = root_node.call("get_achievement_counters_for_test")
	var completed_claimed: Dictionary = root_node.call("get_achievement_claimed_for_test")
	var saved_achievements := ConfigFile.new()
	root_node.call("_store_achievement_progress", saved_achievements)
	root_node.call("set_achievement_state_for_test", {}, {})
	root_node.call("_load_achievement_progress", saved_achievements)
	if root_node.call("get_achievement_counters_for_test") != completed_counters \
			or root_node.call("get_achievement_claimed_for_test") != completed_claimed \
			or int(root_node.get("coins")) != expected_coins:
		_fail("achievement counters, claims, and paid coins must round-trip without regrant")
		return false

	var achievement_button: Rect2 = root_node.call("_get_achievement_btn_rect")
	for other_button in [
		root_node.call("_get_start_rect"),
		root_node.call("_get_upgrade_btn_rect"),
		root_node.call("_get_skin_btn_rect"),
		root_node.call("_get_stage_btn_rect"),
	]:
		if achievement_button.intersects(other_button):
			_fail("achievement title entry must not overlap an existing button")
			return false
	# AC-5: the same title-button coordinate must not open the sheet while the
	# game is playing. The title branch is the only runtime entry point.
	root_node.set("game_state", "playing")
	root_node.set("show_achievement_panel", false)
	root_node.call("_handle_tap", achievement_button.get_center())
	if bool(root_node.get("show_achievement_panel")):
		_fail("achievement sheet must not open from the playing HUD")
		return false
	root_node.call("_go_home")
	root_node.call("_handle_tap", achievement_button.get_center())
	if not bool(root_node.get("show_achievement_panel")) or String(root_node.get("game_state")) != "title":
		_fail("title achievement button must open a modal sheet")
		return false
	var panel: Rect2 = root_node.call("_achievement_panel_rect")
	var previous_row := Rect2()
	for row_index in range(definitions.size()):
		var row: Rect2 = root_node.call("_achievement_row_rect", panel, row_index)
		if not panel.encloses(row) or (row_index > 0 and previous_row.intersects(row)):
			_fail("achievement progress rows must fit inside the title sheet")
			return false
		previous_row = row
	root_node.call("_handle_achievement_panel_tap", root_node.call("_achievement_close_rect", panel).get_center())
	if bool(root_node.get("show_achievement_panel")):
		_fail("achievement sheet close button must dismiss the modal")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var core_source := FileAccess.get_file_as_string("res://core/use_cases/achievement_progress.gd")
	if not main_source.contains('config.get_value("achievements", "counters"') \
			or not main_source.contains('config.get_value("achievements", "claimed"') \
			or not main_source.contains('config.set_value("achievements", "counters"') \
			or not main_source.contains('config.set_value("achievements", "claimed"'):
		_fail("achievement counters and one-shot claims must round-trip in the local save")
		return false
	for required_hook in [
		"AchievementProgress.COUNTER_DIRT",
		"AchievementProgress.COUNTER_LEAF",
		"AchievementProgress.COUNTER_COMBO",
		"AchievementProgress.COUNTER_WASHES",
		"AchievementProgress.COUNTER_STARS",
	]:
		if not main_source.contains(required_hook):
			_fail("local gameplay achievement hook missing: " + required_hook)
			return false
	for forbidden_dependency in ["GA4", "Firebase", "AnalyticsPort", "JavaScriptBridge"]:
		if core_source.contains(forbidden_dependency):
			_fail("achievement rules must remain local-only: " + forbidden_dependency)
			return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("achievement sheet must not add or move persistent gameplay HUD")
		return false
	root_node.call("set_achievement_state_for_test", original_state["counters"], original_state["claimed"])
	root_node.set("coins", original_state["coins"])
	root_node.call("reset_game", original_state["active_level"], "achievement_smoke_cleanup")
	root_node.set("game_state", original_state["game_state"])
	root_node.set("selected_tool", original_state["selected_tool"])
	root_node.set("_main_save_dirty", original_state["main_save_dirty"])
	root_node.set("daily_mission_type", original_state["daily_type"])
	root_node.set("daily_mission_progress", original_state["daily_progress"])
	root_node.set("daily_mission_claimed", original_state["daily_claimed"])
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
	for method_name in ["get_combo_for_test", "is_combo_protection_available_for_test", "is_combo_grace_active_for_test", "get_best_combo_for_test", "get_level_time_for_test", "get_level_mistakes_for_test", "get_perfect_wash_bonus_for_test", "get_water_boost_remaining_for_test", "get_water_boost_cost_for_test", "get_tool_radius_for_test", "get_reach_upgrade_level_for_test", "set_reach_upgrade_level_for_test", "get_tool_power_multiplier_for_test", "get_power_upgrade_level_for_test", "set_power_upgrade_level_for_test", "activate_water_boost", "calc_stars_for_test", "get_star3_combo_requirement_for_test", "is_star3_combo_unlocked_for_test", "get_last_grade_tracker_text_for_test", "get_car_type_for_test", "get_car_color_for_test", "get_selected_car_paint_for_test", "get_car_paint_options_for_test", "get_title_skin_swatch_colors_for_test", "get_title_hero_rect_for_test", "get_wheel_specs_for_test", "get_wheel_dirt_indices_for_test", "get_initial_dirt_total_for_test", "get_initial_dirt_snapshot_for_test", "get_completion_reveal_progress_for_test", "set_completion_reveal_age_for_test", "get_customer_profile_for_test", "get_customer_reaction_strength_for_test", "get_completion_customer_rect_for_test", "get_customer_patience_for_test", "get_customer_patience_zone_for_test", "get_customer_patience_pattern_for_test", "should_customer_patience_warn_for_test", "get_achievement_definitions_for_test", "get_achievement_counters_for_test", "get_achievement_claimed_for_test", "set_achievement_state_for_test", "record_achievement_progress_for_test", "get_daily_mission_reward_for_test", "prepare_daily_mission_for_test", "configure_daily_mission_for_test", "claim_daily_mission_for_test", "grant_daily_mission_retroactive_for_test", "get_license_plate_text_for_test", "get_license_plate_options_for_test", "get_car_transition_phase_for_test", "get_car_transition_offset_for_test"]:
		if not root_node.has_method(method_name):
			_fail("test helper API missing: " + method_name)
			return
	for method_name in [
		"get_completion_base_reward_for_test",
		"is_completion_reward_reduced_for_test",
		"get_completion_star_improvement_for_test",
		"is_milestone_reward_claimed_for_test",
	]:
		if not root_node.has_method(method_name):
			_fail("rewash reward test helper API missing: " + method_name)
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
	if not _test_wash_guide_contract(root_node):
		return
	if not _test_text_scale_accessibility_contract(root_node):
		return
	if not _test_audio_bus_contract(root_node):
		return
	if not _test_reduce_motion_accessibility_contract(root_node):
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
		5: ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime", "sap"],
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
	if not _test_dirt_health_cap_contract(root_node):
		return
	if not _test_wheel_dirt_contract(root_node):
		return
	if not await _test_completion_reveal_contract(root_node):
		return
	if not _test_customer_patience_contract(root_node):
		return
	if not _test_customer_tip_contract(root_node):
		return
	if not _test_non_color_accessibility_cues(root_node):
		return
	if not await _test_upgrade_panel_residency(root_node):
		return
	if not await _test_air_power_upgrade_contract(root_node):
		return
	if not await _test_reach_upgrade_contract(root_node):
		return
	if not _test_achievement_contract(root_node):
		return
	if not _test_scaled_star3_combo_gate_contract(root_node):
		return
	if not await _test_scaled_grade_tracker_prompt_contract(root_node):
		return
	if not _test_oil_sheen_contract(root_node):
		return
	if not _test_sap_dirt_contract(root_node):
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

	if not await _test_combo_protection_contract(root_node):
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
	if not _test_economy_balance_hud_residency(root_node):
		return

	if int(root_node.call("calc_coin_reward_for_test")) != 44:
		_fail("expected 44 coins for 1-star clear at combo 10")
		return
	root_node.set("best_combo", 15)
	if int(root_node.call("calc_coin_reward_for_test")) != 54:
		_fail("expected 54 coins for 1-star clear at the combo 15 reward cap")
		return
	root_node.set("best_combo", 20)
	if int(root_node.call("calc_coin_reward_for_test")) != 54:
		_fail("1-star reward must stay capped after combo 15")
		return
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 5)
	if int(root_node.call("calc_coin_reward_for_test")) != 50:
		_fail("expected 50 coins for 3-star clear")
		return
	if not _test_perfect_wash_contract(root_node, analytics_recorder):
		return
	if not _test_rewash_reward_contract(root_node):
		return
	if not _test_daily_mission_reward_contract(root_node, analytics_recorder):
		return
	if not _test_daily_mission_style_contract(root_node, analytics_recorder):
		return

	if String(root_node.call("get_car_type_for_test")) != "compact":
		_fail("level 1 should be a compact car")
		return
	if not _test_compact_city_dirt_profile(root_node):
		return
	if not await _test_customer_completion_contract(root_node):
		return
	if not _test_expanded_car_roster_and_gameplay(root_node):
		return
	if not _test_new_car_types_reuse_existing_ui_residency(root_node):
		return
	if not _test_gold_spot_contract(root_node):
		return
	if not _test_water_impact_presentation_contract(root_node):
		return
	if not await _test_surface_droplet_contract(root_node):
		return
	if not _test_particle_budget_contract(root_node):
		return
	if not _test_body_foam_coverage_contract(root_node):
		return
	if not _test_clean_shine_progression_contract(root_node):
		return
	if not _test_stage_selection_and_retry_contract(root_node):
		return
	if not _test_tool_scoped_skin_ownership(root_node):
		return
	if not _test_title_hero_customization(root_node):
		return
	if not _test_license_plate_customization(root_node):
		return
	if not _test_car_paint_customization(root_node):
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

	root_node.set("coins", 160)
	var bomb_oil_index: int = root_node.call("get_patch_index_by_kind_for_test", "oil")
	if bomb_oil_index < 0:
		_fail("level 2 oil patch missing")
		return
	root_node.call("apply_foam_bomb")
	if int(root_node.call("get_coins_for_test")) != 160 - 80:
		_fail("foam bomb should cost 80 coins")
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
	root_node.set("coins", 10)  # below BOMB_COST (80)
	if bool(root_node.call("apply_foam_bomb")):
		_fail("foam bomb must not apply below cost when no ad grants it")
		return
	if int(root_node.call("get_coins_for_test")) != 10:
		_fail("failed foam bomb must not change coins")
		return
	if not _test_booster_picker_and_water_boost(root_node):
		return
	if not _test_native_ad_contract():
		return
	for stalled_method in ["get_stalled_dirt_highlight_for_test", "get_stalled_dirt_progress_threshold_for_test", "get_stalled_dirt_idle_seconds_for_test", "simulate_stalled_dirt_highlight_for_test", "simulate_cleaning_resumed_for_test"]:
		if not root_node.has_method(stalled_method):
			_fail("stalled dirt helper API missing: " + stalled_method)
			return
	if absf(float(root_node.call("get_stalled_dirt_progress_threshold_for_test")) - 0.90) > 0.0001:
		_fail("stalled dirt progress threshold mismatch")
		return
	if absf(float(root_node.call("get_stalled_dirt_idle_seconds_for_test")) - 3.0) > 0.0001:
		_fail("stalled dirt idle threshold mismatch")
		return
	if bool(root_node.call("simulate_stalled_dirt_highlight_for_test", 0.89, 8.0)):
		_fail("stalled dirt highlight must stay off below 90 percent")
		return
	if bool(root_node.call("simulate_stalled_dirt_highlight_for_test", 0.95, 2.9)):
		_fail("stalled dirt highlight must stay off before 3 idle seconds")
		return
	if not bool(root_node.call("simulate_stalled_dirt_highlight_for_test", 0.95, 3.0)):
		_fail("stalled dirt highlight should activate for a late cleaning stall")
		return
	if bool(root_node.call("simulate_cleaning_resumed_for_test", 0.001)):
		_fail("resumed cleaning must clear the stalled dirt highlight")
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
	var music_pause_rect: Rect2 = root_node.call("_pause_audio_option_rect", "music")
	var sfx_pause_rect: Rect2 = root_node.call("_pause_audio_option_rect", "sfx")
	if not root_node.call("_pause_button_rect", 2).encloses(music_pause_rect) \
			or not root_node.call("_pause_button_rect", 2).encloses(sfx_pause_rect) \
			or music_pause_rect.intersects(sfx_pause_rect):
		_fail("music and SFX controls must split one non-overlapping pause row")
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
	root_node.set("music_enabled", true)
	root_node.set("sfx_enabled", true)
	root_node.set("show_tutorial", false)
	root_node.set("show_pause", false)
	root_node.call("_handle_tap", root_node.call("_get_title_music_rect").get_center())
	root_node.call("_handle_tap", root_node.call("_get_title_sfx_rect").get_center())
	root_node.call("_handle_tap", root_node.call("_get_title_help_rect").get_center())
	if not bool(root_node.get("music_enabled")) or not bool(root_node.get("sfx_enabled")) or bool(root_node.get("show_tutorial")):
		_fail("playing HUD must not expose direct audio/help actions")
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
	root_node.call("_handle_tap", music_pause_rect.get_center())
	if bool(root_node.get("music_enabled")) or not bool(root_node.get("sfx_enabled")) or not bool(root_node.get("show_pause")):
		_fail("pause music toggle must not change SFX or close settings")
		return
	root_node.call("_handle_tap", sfx_pause_rect.get_center())
	if bool(root_node.get("music_enabled")) or bool(root_node.get("sfx_enabled")) or not bool(root_node.get("show_pause")):
		_fail("pause SFX toggle must not change music or close settings")
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
	root_node.set("music_enabled", true)
	root_node.set("sfx_enabled", true)
	root_node.call("_apply_audio_settings")
	root_node.set("language_preference", "")
	TranslationServer.set_locale(previous_locale)
	root_node.call("_rebuild_i18n_labels")

	print("Foam Party smoke passed: patches=%d progress=%.3f best_combo=%d stars=%d" % [patch_count, progress_after, best_combo, stars])
	get_root().remove_child(root_node)
	root_node.free()
	await process_frame
	quit(0)


func _test_booster_picker_and_water_boost(root_node: Node) -> bool:
	var persistent_hud_before := _capture_persistent_hud_state(root_node)
	var original_level := int(root_node.call("get_active_level_for_test"))
	var original_coins := int(root_node.call("get_coins_for_test"))
	var original_tool := String(root_node.get("selected_tool"))
	var boost_cost := int(root_node.call("get_water_boost_cost_for_test"))
	if boost_cost != 60:
		_fail("water boost cost must come from the 60-coin GameConfig constant")
		return false

	# AC-2: compare the same deterministic mud patch before and after purchase so
	# both the enlarged cursor reach and the real WashRules power path are covered.
	root_node.call("reset_game", 1, "water_boost_baseline_smoke")
	var baseline_radius := float(root_node.call("get_tool_radius_for_test", "water"))
	var baseline_power := float(root_node.call("get_tool_power_multiplier_for_test", "water"))
	var mud_index := int(root_node.call("get_patch_index_by_kind_for_test", "mud"))
	var baseline_health := float(root_node.call("get_patch_health_for_test", mud_index))
	var baseline_after := float(root_node.call("apply_tool_to_patch_for_test", "water", mud_index, 0.3))
	var baseline_damage := baseline_health - baseline_after
	if baseline_damage <= 0.0:
		_fail("baseline water path must clean the deterministic mud fixture")
		return false

	root_node.call("reset_game", 1, "water_boost_picker_smoke")
	root_node.set("coins", boost_cost)
	root_node.set("level_time", 5.0)
	root_node.set("is_washing", true)
	root_node.call("_handle_tap", root_node.call("_get_booster_rect").get_center())
	if not bool(root_node.get("show_booster_panel")) or bool(root_node.get("is_washing")):
		_fail("the existing booster entry must open a modal picker and stop washing")
		return false
	var panel: Rect2 = root_node.call("_booster_panel_rect")
	var foam_card: Rect2 = root_node.call("_booster_card_rect", panel, 0)
	var water_card: Rect2 = root_node.call("_booster_card_rect", panel, 1)
	if not panel.encloses(foam_card) or not panel.encloses(water_card) or foam_card.intersects(water_card):
		_fail("both booster cards must fit as separate choices inside the modal")
		return false
	root_node.call("_process", 1.0)
	if absf(float(root_node.call("get_level_time_for_test")) - 5.0) > 0.001:
		_fail("the booster modal must pause the active level clock")
		return false

	root_node.call("_handle_tap", water_card.get_center())
	var boost_remaining := float(root_node.call("get_water_boost_remaining_for_test"))
	if bool(root_node.get("show_booster_panel")) \
			or int(root_node.call("get_coins_for_test")) != 0 \
			or String(root_node.get("selected_tool")) != "water" \
			or boost_remaining < 9.99:
		_fail("an affordable water boost must deduct once, activate, select water, and close the modal")
		return false
	var boosted_radius := float(root_node.call("get_tool_radius_for_test", "water"))
	var boosted_power := float(root_node.call("get_tool_power_multiplier_for_test", "water"))
	if boosted_radius < baseline_radius * 1.49 or boosted_power < baseline_power * 1.49:
		_fail("active water boost must visibly increase both reach and power by 1.5x")
		return false
	mud_index = int(root_node.call("get_patch_index_by_kind_for_test", "mud"))
	var boosted_health := float(root_node.call("get_patch_health_for_test", mud_index))
	var boosted_after := float(root_node.call("apply_tool_to_patch_for_test", "water", mud_index, 0.3))
	var boosted_damage := boosted_health - boosted_after
	if boosted_damage < baseline_damage * 1.25:
		_fail("water boost power must reach the live mud cleaning path: %.3f -> %.3f" % [baseline_damage, boosted_damage])
		return false

	# While active, another purchase is rejected without spending, and reopening
	# the modal freezes the boost countdown until gameplay resumes.
	root_node.set("coins", 100)
	if bool(root_node.call("activate_water_boost")) or int(root_node.call("get_coins_for_test")) != 100:
		_fail("an active water boost must reject duplicate spending")
		return false
	root_node.call("_handle_tap", root_node.call("_get_booster_rect").get_center())
	var paused_remaining := float(root_node.call("get_water_boost_remaining_for_test"))
	root_node.call("_process", 1.0)
	if absf(float(root_node.call("get_water_boost_remaining_for_test")) - paused_remaining) > 0.001:
		_fail("water boost duration must freeze while its modal is open")
		return false
	root_node.call("_handle_tap", root_node.call("_booster_close_rect", panel).get_center())
	root_node.call("_process", 1.0)
	if float(root_node.call("get_water_boost_remaining_for_test")) >= paused_remaining:
		_fail("water boost duration must count down during active gameplay")
		return false

	# AC-3: insufficient coins cannot activate or mutate the balance.
	root_node.call("reset_game", 1, "water_boost_insufficient_smoke")
	root_node.set("coins", boost_cost - 1)
	if bool(root_node.call("activate_water_boost")) \
			or int(root_node.call("get_coins_for_test")) != boost_cost - 1 \
			or float(root_node.call("get_water_boost_remaining_for_test")) > 0.0:
		_fail("insufficient water boost purchase must preserve coins and stay inactive")
		return false

	# AC-1 and AC-4: drawing stays in the existing gameplay entry plus a modal,
	# and all pricing/tuning references the GameConfig-backed aliases.
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not source.contains("_draw_booster_button()") \
			or not source.contains("_draw_booster_panel()") \
			or source.contains("_draw_bomb_button()") \
			or not source.contains("const WATER_BOOST_COST := GameConfig.WATER_BOOST_COST"):
		_fail("booster UI and tuning must use the reused entry, modal picker, and GameConfig seam")
		return false
	if _capture_persistent_hud_state(root_node) != persistent_hud_before:
		_fail("booster picker must not add a persistent Control or move top HUD residency")
		return false

	root_node.call("reset_game", original_level, "water_boost_smoke_cleanup")
	root_node.set("coins", original_coins)
	root_node.set("selected_tool", original_tool)
	root_node.set("show_booster_panel", false)
	return true


func _test_perfect_wash_contract(root_node: Node, analytics_recorder: AnalyticsRecorder) -> bool:
	var persistent_hud_before := _capture_persistent_hud_state(root_node)
	var original_state := {
		"active_level": root_node.call("get_active_level_for_test"),
		"level_index": root_node.get("level_index"),
		"coins": root_node.get("coins"),
		"total_stars": root_node.get("total_stars"),
		"best_times": root_node.get("best_times").duplicate(true),
		"best_stars": root_node.get("best_stars").duplicate(true),
	}
	var original_daily := {
		"type": root_node.get("daily_mission_type"),
		"label": root_node.get("daily_mission_label"),
		"target": root_node.get("daily_mission_target"),
		"requirement": root_node.get("daily_mission_requirement"),
		"reward": root_node.get("daily_mission_reward"),
		"progress": root_node.get("daily_mission_progress"),
		"claimed": root_node.get("daily_mission_claimed"),
		"date": root_node.get("daily_mission_date"),
	}

	# AC-2 and AC-4: only a sustained wrong-tool coach activation counts, and
	# each dirt patch contributes at most one mistake until the level resets.
	root_node.call("reset_game", 1, "perfect_wash_mistake_smoke")
	if int(root_node.call("get_level_mistakes_for_test")) != 0:
		_fail("level mistakes must reset to zero")
		return false
	var leaf_index := int(root_node.call("get_patch_index_by_kind_for_test", "leaf"))
	if leaf_index < 0 or String(root_node.call("simulate_patch_hint_for_test", "water", leaf_index, 0.6)) != "air":
		_fail("sustained wrong-tool use should activate the existing coaching hint")
		return false
	if int(root_node.call("get_level_mistakes_for_test")) != 1:
		_fail("a patch's first coaching hint must record one level mistake")
		return false
	root_node.call("simulate_patch_hint_for_test", "water", leaf_index, 0.6)
	root_node.call("simulate_patch_hint_for_test", "air", leaf_index, 0.1)
	root_node.call("simulate_patch_hint_for_test", "water", leaf_index, 0.6)
	if int(root_node.call("get_level_mistakes_for_test")) != 1:
		_fail("repeated coaching hints on one patch must not add mistakes")
		return false
	var second_leaf := int(root_node.call("spawn_patch_for_test", "leaf"))
	root_node.call("simulate_patch_hint_for_test", "water", second_leaf, 0.6)
	if int(root_node.call("get_level_mistakes_for_test")) != 2:
		_fail("a second patch's first coaching hint must add one mistake")
		return false
	root_node.call("reset_game", 1, "perfect_wash_reset_smoke")
	if int(root_node.call("get_level_mistakes_for_test")) != 0:
		_fail("retrying a level must clear the mistake counter")
		return false

	# Keep the completion reward comparison isolated from completion-style daily
	# missions, which can legitimately grant their own coins on the same frame.
	root_node.call("configure_daily_mission_for_test", "road_grime")
	analytics_recorder.events.clear()
	root_node.set("coins", 0)
	root_node.set("best_stars", {})
	root_node.set("total_stars", 0)
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	var perfect_reward := int(root_node.get("coin_reward"))
	if int(root_node.get("earned_stars")) != 3 \
			or int(root_node.call("get_perfect_wash_bonus_for_test")) != 20 \
			or int(root_node.call("get_coins_for_test")) != perfect_reward:
		_fail("a zero-mistake three-star clear must grant the 20-coin perfect bonus")
		return false

	root_node.call("reset_game", 1, "imperfect_wash_reward_smoke")
	root_node.call("configure_daily_mission_for_test", "road_grime")
	root_node.set("coins", 0)
	root_node.set("best_stars", {})
	root_node.set("total_stars", 0)
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	leaf_index = int(root_node.call("get_patch_index_by_kind_for_test", "leaf"))
	root_node.call("simulate_patch_hint_for_test", "water", leaf_index, 0.6)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	var imperfect_reward := int(root_node.get("coin_reward"))
	if int(root_node.call("get_level_mistakes_for_test")) != 1 \
			or int(root_node.call("get_perfect_wash_bonus_for_test")) != 0 \
			or perfect_reward - imperfect_reward != 20 \
			or int(root_node.call("get_coins_for_test")) != imperfect_reward:
		_fail("any recorded mistake must suppress only the perfect-wash bonus")
		return false

	# AC-3: the completion-only badge reuses the milestone chip and fits beside
	# both existing completion chips without adding a resident HUD Control.
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var completion_start := main_source.find("func _draw_completion_panel() -> void:")
	var completion_end := main_source.find("\nfunc _completion_panel_rect() -> Rect2:", completion_start)
	var completion_body := main_source.substr(completion_start, completion_end - completion_start)
	if not completion_body.contains("if level_mistakes == 0 and _perfect_wash_bonus > 0:") \
			or not completion_body.contains('tr("PERFECT_CHIP")') \
			or not completion_body.contains('_style("milestone_chip"'):
		_fail("completion must gate the perfect label and reuse the milestone-chip style")
		return false
	root_node.set("_level_milestone_bonus", 75)
	var panel: Rect2 = root_node.call("_completion_panel_rect")
	var perfect_chip: Rect2 = root_node.call("_perfect_chip_rect", panel)
	var milestone_chip := Rect2(panel.position.x + 10.0, panel.position.y - 14.0, 106.0, 30.0)
	var reward_chip := Rect2(panel.position.x + panel.size.x - 106.0, panel.position.y - 14.0, 96.0, 30.0)
	if perfect_chip.intersects(milestone_chip) or perfect_chip.intersects(reward_chip):
		_fail("perfect badge must fit between the milestone and reward chips")
		return false

	root_node.call("reset_game", int(original_state["active_level"]), "perfect_wash_smoke_cleanup")
	root_node.set("level_index", original_state["level_index"])
	root_node.set("coins", original_state["coins"])
	root_node.set("total_stars", original_state["total_stars"])
	root_node.set("best_times", original_state["best_times"])
	root_node.set("best_stars", original_state["best_stars"])
	for key in original_daily:
		root_node.set("daily_mission_" + key, original_daily[key])
	analytics_recorder.events.clear()
	if _capture_persistent_hud_state(root_node) != persistent_hud_before:
		_fail("perfect-wash reward must not add a persistent Control or move HUD residency")
		return false
	return true


func _test_rewash_reward_contract(root_node: Node) -> bool:
	var original_state := {
		"active_level": root_node.call("get_active_level_for_test"),
		"level_index": root_node.get("level_index"),
		"game_state": root_node.get("game_state"),
		"coins": root_node.get("coins"),
		"total_stars": root_node.get("total_stars"),
		"best_times": root_node.get("best_times").duplicate(true),
		"best_stars": root_node.get("best_stars").duplicate(true),
		"milestones": root_node.get("milestone_rewards_claimed").duplicate(true),
		"achievement_counters": root_node.call("get_achievement_counters_for_test"),
		"achievement_claimed": root_node.call("get_achievement_claimed_for_test"),
		"main_save_dirty": root_node.get("_main_save_dirty"),
		"double_offer": root_node.get("_double_offer_shown"),
	}
	var original_daily := {
		"type": root_node.get("daily_mission_type"),
		"label": root_node.get("daily_mission_label"),
		"target": root_node.get("daily_mission_target"),
		"requirement": root_node.get("daily_mission_requirement"),
		"reward": root_node.get("daily_mission_reward"),
		"progress": root_node.get("daily_mission_progress"),
		"claimed": root_node.get("daily_mission_claimed"),
		"date": root_node.get("daily_mission_date"),
	}
	var saturated_counters := {
		"washes_completed": 999,
		"dirt_removed": 999,
		"leaf_removed": 999,
		"stars_collected": 999,
		"combo_peak": 999,
	}
	var saturated_claims := {}
	for definition in root_node.call("get_achievement_definitions_for_test"):
		saturated_claims[String(definition["id"])] = true
	root_node.call("set_achievement_state_for_test", saturated_counters, saturated_claims)
	root_node.call("configure_daily_mission_for_test", "road_grime")
	root_node.set("best_times", {})
	root_node.set("best_stars", {})
	root_node.set("milestone_rewards_claimed", {})
	root_node.set("total_stars", 0)
	root_node.set("coins", 0)

	_complete_rewash_fixture(root_node, 1, 60.0, 5)
	var first_clear_coins := int(root_node.get("coins"))
	if int(root_node.call("get_completion_base_reward_for_test")) != 50 \
			or bool(root_node.call("is_completion_reward_reduced_for_test")) \
			or int(root_node.call("get_best_stars_for_test", 1)) != 3 \
			or int(root_node.get("total_stars")) != 3:
		_fail("first clear must grant the full base reward and record only its level best stars")
		return false

	_complete_rewash_fixture(root_node, 1, 60.0, 5)
	var same_star_rewash_coins := int(root_node.get("coins")) - first_clear_coins
	if int(root_node.call("get_completion_base_reward_for_test")) != 25 \
			or not bool(root_node.call("is_completion_reward_reduced_for_test")) \
			or same_star_rewash_coins >= first_clear_coins \
			or int(root_node.get("total_stars")) != 3:
		_fail("same-star rewashing must halve its base payout without increasing total stars")
		return false

	root_node.set("best_times", {})
	root_node.set("best_stars", {1: 1})
	root_node.set("total_stars", 1)
	root_node.set("coins", 0)
	_complete_rewash_fixture(root_node, 1, 60.0, 5)
	if int(root_node.call("get_completion_base_reward_for_test")) != 33 \
			or int(root_node.call("get_completion_star_improvement_for_test")) != 2 \
			or int(root_node.call("get_best_stars_for_test", 1)) != 3 \
			or int(root_node.get("total_stars")) != 3:
		_fail("rewash star improvement must pay both new stars in full and refresh the best sum")
		return false

	root_node.set("best_times", {})
	root_node.set("best_stars", {})
	root_node.set("milestone_rewards_claimed", {})
	root_node.set("total_stars", 0)
	root_node.set("coins", 0)
	_complete_rewash_fixture(root_node, 5, 60.0, 5)
	if int(root_node.get("_level_milestone_bonus")) != 75 \
			or not bool(root_node.call("is_milestone_reward_claimed_for_test", 5)):
		_fail("level 5 must grant and remember its milestone reward on first clear")
		return false
	_complete_rewash_fixture(root_node, 5, 60.0, 5)
	if int(root_node.get("_level_milestone_bonus")) != 0:
		_fail("a claimed level milestone must not pay on rewashing")
		return false
	root_node.set("best_times", {})
	root_node.set("best_stars", {})
	root_node.set("milestone_rewards_claimed", {})
	root_node.set("total_stars", 0)
	root_node.set("coins", 0)
	_complete_rewash_fixture(root_node, 10, 60.0, 7)
	if int(root_node.get("_level_milestone_bonus")) != 100 \
			or not bool(root_node.call("is_milestone_reward_claimed_for_test", 10)):
		_fail("level 10 must grant and remember its milestone reward on first clear")
		return false
	_complete_rewash_fixture(root_node, 10, 60.0, 7)
	if int(root_node.get("_level_milestone_bonus")) != 0:
		_fail("the level 10 milestone must not pay on rewashing")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains('config.get_value("game", "best_stars"') \
			or not main_source.contains('config.set_value("game", "best_stars"') \
			or not main_source.contains('config.get_value("game", "milestone_rewards_claimed"') \
			or not main_source.contains('config.set_value("game", "milestone_rewards_claimed"'):
		_fail("best stars and milestone claims must both load and save")
		return false
	var history_config := ConfigFile.new()
	history_config.set_value("game", "milestone_rewards_claimed", {5: true, 10: true})
	root_node.call("_load_milestone_reward_history", history_config)
	if not bool(root_node.call("is_milestone_reward_claimed_for_test", 5)) \
			or not bool(root_node.call("is_milestone_reward_claimed_for_test", 10)):
		_fail("saved milestone claims must restore for every claimed level")
		return false
	var completion_start := main_source.find("func _draw_completion_panel() -> void:")
	var completion_end := main_source.find("\nfunc _draw_completion_reveal_cards", completion_start)
	var completion_body := main_source.substr(completion_start, completion_end - completion_start)
	if not completion_body.contains('_completion_reward_reduced') \
			or not completion_body.contains('tr("REWASH_REWARD")'):
		_fail("the completion reward chip must label the reduced rewashing payout")
		return false

	root_node.call("reset_game", int(original_state["active_level"]), "rewash_reward_smoke_cleanup")
	root_node.set("level_index", original_state["level_index"])
	root_node.set("game_state", original_state["game_state"])
	root_node.set("coins", original_state["coins"])
	root_node.set("total_stars", original_state["total_stars"])
	root_node.set("best_times", original_state["best_times"])
	root_node.set("best_stars", original_state["best_stars"])
	root_node.set("milestone_rewards_claimed", original_state["milestones"])
	root_node.call("set_achievement_state_for_test",
		original_state["achievement_counters"], original_state["achievement_claimed"])
	root_node.set("_main_save_dirty", original_state["main_save_dirty"])
	root_node.set("_double_offer_shown", original_state["double_offer"])
	for key in original_daily:
		root_node.set("daily_mission_" + key, original_daily[key])
	return true


func _complete_rewash_fixture(root_node: Node, level: int, elapsed: float, combo: int) -> void:
	root_node.call("reset_game", level, "rewash_reward_smoke")
	root_node.set("level_time", elapsed)
	root_node.set("best_combo", combo)
	root_node.set("level_mistakes", 1)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")


func _test_daily_mission_reward_contract(root_node: Node, analytics_recorder: AnalyticsRecorder) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var original_state := {
		"type": root_node.get("daily_mission_type"),
		"label": root_node.get("daily_mission_label"),
		"target": root_node.get("daily_mission_target"),
		"reward": root_node.get("daily_mission_reward"),
		"progress": root_node.get("daily_mission_progress"),
		"claimed": root_node.get("daily_mission_claimed"),
		"date": root_node.get("daily_mission_date"),
		"coins": root_node.get("coins"),
	}
	analytics_recorder.events.clear()
	root_node.set("coins", 200)
	root_node.call("prepare_daily_mission_for_test", "road_grime")
	var reward := int(root_node.call("get_daily_mission_reward_for_test"))
	if reward != 85:
		_fail("road grime daily mission should pay 85 coins")
		return false
	if not bool(root_node.call("claim_daily_mission_for_test")):
		_fail("prepared daily mission should grant its reward")
		return false
	if int(root_node.call("get_coins_for_test")) != 200 + reward:
		_fail("daily mission coin increase must match the mission reward")
		return false
	if bool(root_node.call("claim_daily_mission_for_test")) or int(root_node.call("get_coins_for_test")) != 200 + reward:
		_fail("claimed daily mission must not grant coins twice")
		return false
	var claim_events := analytics_recorder.events.filter(
		func(event: Dictionary) -> bool:
			return event.get("name") == "daily_mission_claim"
	)
	if claim_events.size() != 1 or String(claim_events[0]["params"].get("reward", "")) != str(reward):
		_fail("daily mission analytics must receive the granted reward")
		return false
	root_node.set("coins", 300)
	var retroactive_reward := int(root_node.call("grant_daily_mission_retroactive_for_test", "road_grime"))
	if retroactive_reward != reward or int(root_node.call("get_coins_for_test")) != 300 + reward:
		_fail("retroactive daily mission grant must use the same mission reward")
		return false
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains('tr("DM_REWARD") % daily_mission_reward'):
		_fail("title mission card must display the actual mission reward")
		return false
	if not main_source.contains("_grant_daily_mission_coins()"):
		_fail("live and retroactive daily mission paths must share the coin grant")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("daily mission reward must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("daily mission reward must keep existing HUD residency unchanged")
		return false
	for key in original_state:
		if key == "coins":
			root_node.set("coins", original_state[key])
		else:
			root_node.set("daily_mission_" + key, original_state[key])
	analytics_recorder.events.clear()
	return true


func _test_daily_mission_style_contract(root_node: Node, analytics_recorder: AnalyticsRecorder) -> bool:
	# AC-1 and AC-2: combo, fast, and perfect3 missions advance only from their
	# real gameplay events and reuse the existing one-shot claim path.
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var original_daily := {
		"type": root_node.get("daily_mission_type"),
		"label": root_node.get("daily_mission_label"),
		"target": root_node.get("daily_mission_target"),
		"requirement": root_node.get("daily_mission_requirement"),
		"reward": root_node.get("daily_mission_reward"),
		"progress": root_node.get("daily_mission_progress"),
		"claimed": root_node.get("daily_mission_claimed"),
		"date": root_node.get("daily_mission_date"),
	}
	var original_progress := {
		"active_level": root_node.call("get_active_level_for_test"),
		"coins": root_node.get("coins"),
		"total_stars": root_node.get("total_stars"),
		"best_times": root_node.get("best_times").duplicate(true),
		"best_stars": root_node.get("best_stars").duplicate(true),
	}
	var previous_locale := TranslationServer.get_locale()

	# AC-3: every new mission label resolves through the ko/en translation table.
	var localized_labels := {
		"combo": {"ko": "한 판에서 콤보 x8 달성", "en": "Reach combo x8 in one wash"},
		"fast": {"ko": "75초 이내 세차 완료", "en": "Finish a wash within 75 seconds"},
		"perfect3": {"ko": "별 3개 세차 2회", "en": "Earn 3 stars on 2 washes"},
	}
	var localized_done := {"ko": "완료!", "en": "Done!"}
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		if TranslationServer.translate("DM_DONE") != String(localized_done[locale]):
			_fail("daily mission completion state must be localized for %s" % locale)
			return false
		for mission_type in localized_labels:
			root_node.call("configure_daily_mission_for_test", mission_type)
			var actual_label := String(root_node.call("_daily_mission_display_label"))
			if actual_label != String(localized_labels[mission_type][locale]):
				_fail("style daily mission label must be localized for %s/%s" % [locale, mission_type])
				return false

	TranslationServer.set_locale("ko")
	root_node.call("reset_game", 1, "daily_combo_mission_smoke")
	root_node.set("coins", 0)
	root_node.call("configure_daily_mission_for_test", "combo")
	var combo_patches: Array = root_node.get("dirt_patches")
	for patch_index in range(7):
		root_node.call("_mark_patch_removed", combo_patches[patch_index])
	if int(root_node.get("daily_mission_progress")) != 0 or bool(root_node.get("daily_mission_claimed")):
		_fail("combo mission must stay pending below combo x8")
		return false
	var coins_before_combo := int(root_node.get("coins"))
	root_node.call("_mark_patch_removed", combo_patches[7])
	if int(root_node.get("daily_mission_progress")) != 1 \
			or not bool(root_node.get("daily_mission_claimed")) \
			or int(root_node.get("coins")) != coins_before_combo + 90 + int(GameConfig.COMBO_BONUS_AMOUNTS[8]):
		_fail("combo x8 must grant its milestone bonus and claim the mission reward exactly once")
		return false
	var coins_after_combo_claim := int(root_node.get("coins"))
	root_node.call("_mark_patch_removed", combo_patches[8])
	if int(root_node.get("coins")) != coins_after_combo_claim:
		_fail("claimed combo mission must not grant its reward twice")
		return false

	root_node.call("reset_game", 1, "daily_fast_mission_miss_smoke")
	root_node.call("configure_daily_mission_for_test", "fast")
	root_node.set("level_time", 76.0)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if int(root_node.get("daily_mission_progress")) != 0 or bool(root_node.get("daily_mission_claimed")):
		_fail("76-second clear must not advance the 75-second fast mission")
		return false

	root_node.call("reset_game", 1, "daily_fast_mission_success_smoke")
	root_node.set("coins", 0)
	root_node.call("configure_daily_mission_for_test", "fast")
	root_node.set("level_time", 75.0)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if int(root_node.get("daily_mission_progress")) != 1 \
			or not bool(root_node.get("daily_mission_claimed")) \
			or int(root_node.get("coins")) != int(root_node.get("coin_reward")) + 95:
		_fail("75-second clear must claim the fast mission and add its reward once")
		return false
	var coins_after_fast_claim := int(root_node.get("coins"))
	root_node.call("_update_clean_progress")
	if int(root_node.get("coins")) != coins_after_fast_claim:
		_fail("completed fast mission must not grant its reward twice")
		return false

	root_node.call("reset_game", 1, "daily_perfect3_mission_first_smoke")
	root_node.set("coins", 0)
	root_node.call("configure_daily_mission_for_test", "perfect3")
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if int(root_node.get("earned_stars")) != 3 \
			or int(root_node.get("daily_mission_progress")) != 1 \
			or bool(root_node.get("daily_mission_claimed")):
		_fail("first three-star clear must advance perfect3 to one of two without claiming")
		return false
	root_node.call("reset_game", 1, "daily_perfect3_mission_second_smoke")
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	var coins_before_perfect_claim := int(root_node.get("coins"))
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if int(root_node.get("daily_mission_progress")) != 2 \
			or not bool(root_node.get("daily_mission_claimed")) \
			or int(root_node.get("coins")) != coins_before_perfect_claim + int(root_node.get("coin_reward")) + 100:
		_fail("second three-star clear must claim perfect3 and add its reward once")
		return false

	# AC-4: the same title card and top HUD chip remain the only resident mission UI.
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("style daily missions must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("style daily missions must reuse the existing title card and HUD chip residency")
		return false
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var claim_start := main_source.find("func _claim_daily_mission_reward() -> bool:")
	var claim_end := main_source.find("\nfunc ", claim_start + 1)
	var claim_body := main_source.substr(claim_start, claim_end - claim_start)
	if not claim_body.contains("_save_daily()") or not claim_body.contains("_save_progress()"):
		_fail("all daily mission types must persist the shared one-shot claim")
		return false

	root_node.call("reset_game", int(original_progress["active_level"]), "daily_style_mission_smoke_cleanup")
	root_node.set("coins", original_progress["coins"])
	root_node.set("total_stars", original_progress["total_stars"])
	root_node.set("best_times", original_progress["best_times"])
	root_node.set("best_stars", original_progress["best_stars"])
	for key in original_daily:
		root_node.set("daily_mission_" + key, original_daily[key])
	TranslationServer.set_locale(previous_locale)
	analytics_recorder.events.clear()
	return true


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


func _test_tool_scoped_skin_ownership(root_node: Node) -> bool:
	# AC-1 through AC-4: each tool owns and pays for gold independently while
	# every tool keeps its free classic skin.
	var persistent_hud_before := _capture_persistent_hud_state(root_node)
	var original_coins := int(root_node.get("coins"))
	var original_owned: Dictionary = root_node.get("owned_skins").duplicate(true)
	var original_skins := {
		"water": root_node.get("skin_water"),
		"air": root_node.get("skin_air"),
		"soap": root_node.get("skin_soap"),
		"sponge": root_node.get("skin_sponge"),
	}
	var original_tab := int(root_node.get("_skin_panel_tab"))
	var tools := ["water", "air", "soap", "sponge"]
	var clean_config := ConfigFile.new()
	root_node.call("_load_nozzle_skin_customization", clean_config)
	for tool in tools:
		if not bool(root_node.call("_is_nozzle_skin_owned", tool, "classic")) \
				or bool(root_node.call("_is_nozzle_skin_owned", tool, "gold")):
			_fail("classic must be free and gold must start locked for %s" % tool)
			return false

	root_node.set("coins", 149)
	root_node.call("_try_buy_or_select_skin", "air", 3)
	if int(root_node.get("coins")) != 149 \
			or bool(root_node.call("_is_nozzle_skin_owned", "air", "gold")) \
			or String(root_node.get("skin_air")) != "classic":
		_fail("denied skin intent must not spend coins, grant ownership, or change selection")
		return false

	root_node.set("coins", 600)
	for tool_index in range(tools.size()):
		var tool := String(tools[tool_index])
		root_node.call("_try_buy_or_select_skin", tool, 3)
		if int(root_node.get("coins")) != 600 - (tool_index + 1) * 150 \
				or not bool(root_node.call("_is_nozzle_skin_owned", tool, "gold")):
			_fail("each tool gold purchase must charge exactly 150 coins for %s" % tool)
			return false
		for other_index in range(tool_index + 1, tools.size()):
			if bool(root_node.call("_is_nozzle_skin_owned", String(tools[other_index]), "gold")):
				_fail("purchased gold must not unlock a later tool")
				return false
	if int(root_node.get("coins")) != 0:
		_fail("owning gold for all four tools must cost 600 coins total")
		return false
	root_node.call("_try_buy_or_select_skin", "water", 0)
	if int(root_node.get("coins")) != 0 or String(root_node.get("skin_water")) != "classic":
		_fail("selecting an owned skin must not charge coins")
		return false
	root_node.call("_try_buy_or_select_skin", "water", 3)
	if int(root_node.get("coins")) != 0 or String(root_node.get("skin_water")) != "gold":
		_fail("reselecting a purchased skin must not charge coins")
		return false

	# AC-5: scoped ownership and selections round-trip through the same config
	# helpers used by user:// progress persistence.
	var scoped_save := ConfigFile.new()
	root_node.call("_store_nozzle_skin_customization", scoped_save)
	var stored_owned: Dictionary = scoped_save.get_value("skins", "owned", {})
	if stored_owned.has("classic") or stored_owned.has("gold") \
			or not stored_owned.has("water:gold") or not stored_owned.has("air:gold") \
			or not stored_owned.has("soap:gold") or not stored_owned.has("sponge:gold"):
		_fail("new saves must persist only tool-scoped nozzle ownership keys")
		return false
	root_node.call("_load_nozzle_skin_customization", clean_config)
	root_node.call("_load_nozzle_skin_customization", scoped_save)
	for tool in tools:
		if not bool(root_node.call("_is_nozzle_skin_owned", tool, "gold")) \
				or String(root_node.get("skin_" + tool)) != "gold":
			_fail("tool-scoped gold ownership must survive save and load for %s" % tool)
			return false

	# Legacy flat ids: unique skins retain their only tool; shared paid gold is
	# granted only to tools that had it selected. Classic remains free everywhere.
	var legacy_save := ConfigFile.new()
	legacy_save.set_value("skins", "water", "gold")
	legacy_save.set_value("skins", "air", "classic")
	legacy_save.set_value("skins", "soap", "pink")
	legacy_save.set_value("skins", "sponge", "classic")
	legacy_save.set_value("skins", "owned", {"classic": true, "gold": true, "pink": true})
	root_node.call("_load_nozzle_skin_customization", legacy_save)
	if not bool(root_node.call("_is_nozzle_skin_owned", "water", "gold")) \
			or bool(root_node.call("_is_nozzle_skin_owned", "air", "gold")) \
			or bool(root_node.call("_is_nozzle_skin_owned", "sponge", "gold")) \
			or not bool(root_node.call("_is_nozzle_skin_owned", "soap", "pink")):
		_fail("legacy flat ownership must migrate shared and unique ids safely")
		return false
	for tool in tools:
		if not bool(root_node.call("_is_nozzle_skin_owned", tool, "classic")):
			_fail("legacy migration must retain free classic for every tool")
			return false

	# AC-6 and AC-7: the existing panel reads the scoped helper and no resident UI
	# or HUD geometry changes are introduced.
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("else _is_nozzle_skin_owned(tool_key, sid)"):
		_fail("skin panel must render tool-scoped ownership state")
		return false
	if not main_source.contains("_load_nozzle_skin_customization(config)") \
			or not main_source.contains("_store_nozzle_skin_customization(config)"):
		_fail("progress persistence must use tool-scoped nozzle save helpers")
		return false
	var purchase_start := main_source.find("func _try_buy_or_select_skin(tool_key: String, skin_idx: int) -> void:")
	var purchase_end := main_source.find("\nfunc ", purchase_start + 1)
	var purchase_body := main_source.substr(purchase_start, purchase_end - purchase_start)
	var buy_guard := purchase_body.find('if action != "buy":')
	var coin_mutation := purchase_body.find("coins -= cost")
	if buy_guard < 0 or coin_mutation < buy_guard:
		_fail("skin coin mutation must stay behind an explicit buy-intent guard")
		return false
	if not purchase_body.contains("Economy intent already validates ownership and affordability"):
		_fail("skin mutation must document the validated Economy intent boundary")
		return false
	var select_branch := purchase_body.find('if action == "select":')
	var select_save_failure := purchase_body.find("if _save_progress() != OK:", select_branch)
	var select_restore := purchase_body.find("skin_water = prev_sid", select_save_failure)
	var buy_save_failure := purchase_body.find("if _save_progress() != OK:", buy_guard)
	var buy_refund := purchase_body.find("coins += cost", buy_save_failure)
	var buy_ownership_rollback := purchase_body.find("owned_skins.erase(ownership_key)", buy_refund)
	var buy_selection_restore := purchase_body.find("skin_water = prev_sid", buy_ownership_rollback)
	if select_branch < 0 or select_save_failure < select_branch or select_restore < select_save_failure \
			or buy_save_failure < coin_mutation or buy_refund < buy_save_failure \
			or buy_ownership_rollback < buy_refund or buy_selection_restore < buy_ownership_rollback:
		_fail("skin select and buy paths must preserve their save-failure rollbacks")
		return false
	if not _assert_persistent_hud_unchanged(root_node, persistent_hud_before):
		return false

	root_node.set("coins", original_coins)
	root_node.set("owned_skins", original_owned)
	root_node.set("skin_water", original_skins["water"])
	root_node.set("skin_air", original_skins["air"])
	root_node.set("skin_soap", original_skins["soap"])
	root_node.set("skin_sponge", original_skins["sponge"])
	root_node.set("_skin_panel_tab", original_tab)
	return true


func _test_title_hero_customization(root_node: Node) -> bool:
	var persistent_hud_before := _capture_persistent_hud_state(root_node)
	var original_skins := {
		"water": root_node.get("skin_water"),
		"air": root_node.get("skin_air"),
		"soap": root_node.get("skin_soap"),
		"sponge": root_node.get("skin_sponge"),
	}
	root_node.set("skin_water", "coral")
	root_node.set("skin_air", "violet")
	root_node.set("skin_soap", "pink")
	root_node.set("skin_sponge", "lime")
	var swatch_colors: Array = root_node.call("get_title_skin_swatch_colors_for_test")
	var expected_colors := [
		Color(1.0, 0.42, 0.32),
		Color(0.62, 0.22, 0.90),
		Color(1.0, 0.58, 0.78),
		Color(0.42, 0.90, 0.28),
	]
	if swatch_colors.size() != expected_colors.size():
		_fail("title must expose one equipped-skin swatch for every tool")
		return false
	for color_index in range(expected_colors.size()):
		if not (swatch_colors[color_index] as Color).is_equal_approx(expected_colors[color_index]):
			_fail("title skin swatch must use the equipped tool skin color")
			return false

	var hero_rect: Rect2 = root_node.call("get_title_hero_rect_for_test")
	if hero_rect.intersects(Rect2(18.0, 382.0, 354.0, 82.0)) \
			or hero_rect.intersects(root_node.call("_get_start_rect")):
		_fail("title hero car and swatches must stay above existing mission and start surfaces")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var hero_start := main_source.find("func _draw_title_hero_car() -> void:")
	var hero_end := main_source.find("\nfunc ", hero_start + 1)
	var title_start := main_source.find("func _draw_title_screen() -> void:")
	var title_end := main_source.find("\nfunc ", title_start + 1)
	if hero_start < 0 or hero_end < 0 or title_start < 0 or title_end < 0:
		_fail("title hero draw functions must remain discoverable")
		return false
	var hero_body := main_source.substr(hero_start, hero_end - hero_start)
	var title_body := main_source.substr(title_start, title_end - title_start)
	if not hero_body.contains("_draw_car()") \
			or not title_body.contains("_draw_title_hero_car()") \
			or not title_body.contains("_draw_title_skin_swatches()"):
		_fail("title must reuse the existing car renderer and draw equipped skin swatches in-place")
		return false

	root_node.set("skin_water", original_skins["water"])
	root_node.set("skin_air", original_skins["air"])
	root_node.set("skin_soap", original_skins["soap"])
	root_node.set("skin_sponge", original_skins["sponge"])
	if _capture_persistent_hud_state(root_node) != persistent_hud_before:
		_fail("title hero preview must not add a persistent Control or move gameplay HUD residency")
		return false
	return true


func _capture_persistent_hud_state(root_node: Node) -> Dictionary:
	return {
		"control_count": root_node.find_children("*", "Control", true, false).size(),
		"status_rect": root_node.call("_get_status_rect"),
		"grade_rect": root_node.call("_get_grade_rect"),
		"customer_rect": root_node.call("_get_customer_rect"),
		"mission_rect": root_node.call("_get_daily_mission_rect"),
	}


func _assert_persistent_hud_unchanged(root_node: Node, before: Dictionary) -> bool:
	# AC-7: compare the complete persistent Control count and every resident HUD
	# slot before and after all tool-scoped purchase, save, load, and panel checks.
	var after := _capture_persistent_hud_state(root_node)
	if after != before:
		_fail("tool-scoped skin ownership must keep the persistent HUD unchanged: %s -> %s" % [before, after])
		return false
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


func _test_car_paint_customization(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var panel: Rect2 = root_node.call("_skin_panel_rect")
	var previous_tab := Rect2()
	for tab_index in range(5):
		var tab: Rect2 = root_node.call("_skin_tab_rect", panel, tab_index)
		if not panel.encloses(tab) or (tab_index > 0 and previous_tab.intersects(tab)):
			_fail("five car customization tabs must fit without overlap inside the existing sheet")
			return false
		previous_tab = tab
	var paints: Array = root_node.call("get_car_paint_options_for_test")
	if paints.size() != 4:
		_fail("car customization tab must expose auto plus three fixed paint cards")
		return false
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("Economy.resolve_flat_item_purchase(_car_paints, CAR_PAINT_TOOL"):
		_fail("car paint purchase and selection must call the shared economy resolver")
		return false
	var draw_start := main_source.find("func _draw() -> void:")
	var draw_end := main_source.find("\nfunc ", draw_start + 1)
	var car_draw_start := main_source.find("func _draw_car(")
	var car_draw_end := main_source.find("\nfunc ", car_draw_start + 1)
	if draw_start < 0 or draw_end < 0 or car_draw_start < 0 or car_draw_end < 0:
		_fail("shared car render functions must remain discoverable")
		return false
	var draw_body := main_source.substr(draw_start, draw_end - draw_start)
	var car_draw_body := main_source.substr(car_draw_start, car_draw_end - car_draw_start)
	var title_hero_start := main_source.find("func _draw_title_hero_car() -> void:")
	var title_hero_end := main_source.find("\nfunc ", title_hero_start + 1)
	var title_hero_body := main_source.substr(title_hero_start, title_hero_end - title_hero_start)
	if draw_body.count("_draw_car()") != 1 \
			or title_hero_body.count("_draw_car()") != 1 \
			or not car_draw_body.contains("draw_colored_polygon(silhouette, car_color)"):
		_fail("title hero, gameplay, and completion must share the same car_color render path")
		return false
	for paint_index in range(paints.size()):
		if not panel.encloses(root_node.call("_skin_card_rect", panel, paint_index)):
			_fail("car paint cards must stay inside the existing customization sheet")
			return false

	var original_coins := int(root_node.get("coins"))
	var original_owned: Dictionary = root_node.get("owned_car_paints").duplicate(true)
	var original_selection := String(root_node.call("get_selected_car_paint_for_test"))
	root_node.set("coins", 500)
	root_node.set("owned_car_paints", {"auto": true})
	root_node.set("selected_car_paint", "")
	root_node.set("_skin_panel_tab", 4)
	var coral_buy_rect: Rect2 = root_node.call("_skin_buy_rect", root_node.call("_skin_card_rect", panel, 1))
	root_node.call("_handle_skin_panel_tap", coral_buy_rect.get_center())
	if String(root_node.call("get_selected_car_paint_for_test")) != "paint_coral" \
			or int(root_node.get("coins")) != 400 \
			or not (root_node.call("get_car_color_for_test") as Color).is_equal_approx(Color("#ff6f61")):
		_fail("buying a car paint must charge once, select it, and update the shared car color")
		return false

	root_node.call("reset_game", 2, "car_paint_fixed_color_smoke")
	var sports_color: Color = root_node.call("get_car_color_for_test")
	var sports_type := String(root_node.call("get_car_type_for_test"))
	root_node.call("reset_game", 5, "car_paint_fixed_color_smoke")
	var offroad_color: Color = root_node.call("get_car_color_for_test")
	var offroad_type := String(root_node.call("get_car_type_for_test"))
	if sports_type != "sports" or offroad_type != "offroad" \
			or not sports_color.is_equal_approx(Color("#ff6f61")) \
			or not offroad_color.is_equal_approx(Color("#ff6f61")):
		_fail("fixed paint must preserve the existing car-type test hook across level resets")
		return false

	var saved_customization := ConfigFile.new()
	root_node.call("_store_car_paint_customization", saved_customization)
	root_node.set("selected_car_paint", "")
	root_node.set("owned_car_paints", {"auto": true})
	root_node.call("_load_car_paint_customization", saved_customization)
	if String(root_node.call("get_selected_car_paint_for_test")) != "paint_coral" \
			or not bool((root_node.get("owned_car_paints") as Dictionary).get("paint_coral", false)):
		_fail("selected and owned car paints must round-trip through progress persistence")
		return false

	var auto_select_rect: Rect2 = root_node.call("_skin_buy_rect", root_node.call("_skin_card_rect", panel, 0))
	root_node.call("_handle_skin_panel_tap", auto_select_rect.get_center())
	if String(root_node.call("get_selected_car_paint_for_test")) != "":
		_fail("selecting auto must restore the backward-compatible empty persisted selection")
		return false
	root_node.call("reset_game", 1, "car_paint_auto_color_smoke")
	var compact_auto: Color = root_node.call("get_car_color_for_test")
	root_node.call("reset_game", 2, "car_paint_auto_color_smoke")
	var sports_auto: Color = root_node.call("get_car_color_for_test")
	if not compact_auto.is_equal_approx(Color.from_hsv(0.10, 0.62, 1.0)) \
			or not sports_auto.is_equal_approx(Color.from_hsv(0.28, 0.85, 1.0)) \
			or compact_auto.is_equal_approx(sports_auto):
		_fail("auto car paint must retain the existing per-level and per-car color rotation")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("car paint customization must not add a new HUD or modal node")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("car paint customization must keep existing HUD residency unchanged")
		return false

	root_node.set("coins", original_coins)
	root_node.set("owned_car_paints", original_owned)
	root_node.set("selected_car_paint", original_selection)
	root_node.call("_set_car_palette")
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


func _test_combo_protection_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	root_node.set("combo_count", 0)
	root_node.set("combo_timer", 0.0)
	root_node.set("combo_protection_available", false)
	root_node.set("combo_grace_active", false)
	root_node.call("_register_combo_removal")
	if int(root_node.call("get_combo_for_test")) != 1 or not bool(root_node.call("is_combo_protection_available_for_test")):
		_fail("starting a combo should charge one protection")
		return false
	root_node.call("_register_combo_removal")
	root_node.set("combo_timer", 0.0001)
	await process_frame
	if int(root_node.call("get_combo_for_test")) != 2 or bool(root_node.call("is_combo_protection_available_for_test")) or not bool(root_node.call("is_combo_grace_active_for_test")):
		_fail("first combo timeout should consume protection and preserve the streak")
		return false
	if float(root_node.get("combo_timer")) <= 0.0 or float(root_node.get("combo_timer")) > 1.0:
		_fail("first combo timeout should enter the one-second grace window")
		return false
	root_node.call("_register_combo_removal")
	if int(root_node.call("get_combo_for_test")) != 3 or bool(root_node.call("is_combo_protection_available_for_test")) or bool(root_node.call("is_combo_grace_active_for_test")):
		_fail("removal during grace should continue the combo without recharging protection")
		return false
	root_node.set("combo_timer", 0.0001)
	await process_frame
	if int(root_node.call("get_combo_for_test")) != 0 or float(root_node.get("combo_timer")) != 0.0:
		_fail("second combo timeout should reset the streak")
		return false
	root_node.call("_register_combo_removal")
	if int(root_node.call("get_combo_for_test")) != 1 or not bool(root_node.call("is_combo_protection_available_for_test")):
		_fail("the next newly started combo should recharge protection")
		return false
	root_node.call("reset_game", 1, "combo_protection_smoke_cleanup")
	if int(root_node.call("get_combo_for_test")) != 0 or bool(root_node.call("is_combo_protection_available_for_test")) or bool(root_node.call("is_combo_grace_active_for_test")):
		_fail("reset_game should clear combo protection and grace state")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("combo protection must stay inside the existing badge without new HUD controls")
		return false
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
		var wheel_indices: Array[int] = root_node.call("get_wheel_dirt_indices_for_test")
		var minimum_distance: float = root_node.call("get_dirt_spawn_min_center_distance_for_test")
		for first_index in range(centers.size()):
			if not bool(root_node.call("_point_in_wash_area", centers[first_index])):
				_fail("level %d spawned dirt outside the washable area" % level)
				return false
			for second_index in range(first_index + 1, centers.size()):
				if first_index in wheel_indices or second_index in wheel_indices:
					continue
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


func _test_dirt_health_cap_contract(root_node: Node) -> bool:
	var baseline_control_count: int = root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	if absf(float(root_node.call("get_dirt_health_scale_for_test", 1)) - 1.0) > 0.0001 \
			or absf(float(root_node.call("get_dirt_health_scale_for_test", 9)) - 1.48) > 0.0001:
		_fail("actual dirt health scale must preserve level 1 through 9 tuning")
		return false
	var capped_scaled_health := -1.0
	var capped_wheel_health := -1.0
	var wheel_specs: Array[Dictionary] = root_node.call("get_wheel_specs_for_test")
	var gameplay_scale: float = root_node.call("_gameplay_length", 1.0)
	var first_wheel_radius: float = float(wheel_specs[0]["radius"]) / gameplay_scale
	var first_wheel_base_health := 88.0 + first_wheel_radius * 0.3
	for level in [10, 20, 50]:
		if absf(float(root_node.call("get_dirt_health_scale_for_test", level)) - 1.5) > 0.0001:
			_fail("actual dirt health scale must stop at 1.5 in late levels")
			return false
		var scaled_health: float = root_node.call("get_scaled_dirt_health_for_test", "oil", 100.0, level)
		if capped_scaled_health < 0.0:
			capped_scaled_health = scaled_health
		elif absf(scaled_health - capped_scaled_health) > 0.0001:
			_fail("same oil base health must remain identical across capped levels")
			return false
		root_node.call("reset_game", level, "dirt_health_cap_smoke")
		var wheel_indices: Array[int] = root_node.call("get_wheel_dirt_indices_for_test")
		if wheel_indices.is_empty():
			_fail("late-level health cap fixture must spawn wheel mud")
			return false
		var wheel_health: float = root_node.call("get_patch_health_for_test", wheel_indices[0])
		var expected_wheel_health: float = root_node.call(
			"get_scaled_dirt_health_for_test", "mud", first_wheel_base_health, level
		)
		if absf(wheel_health - expected_wheel_health) > 0.0001:
			_fail("actual wheel mud must use the shared capped dirt health rule")
			return false
		if capped_wheel_health < 0.0:
			capped_wheel_health = wheel_health
		elif absf(wheel_health - capped_wheel_health) > 0.0001:
			_fail("actual same-car wheel mud health must stay capped across late levels")
			return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_count \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("dirt health cap must not add or move a gameplay HUD element")
		return false
	root_node.call("reset_game", 1, "dirt_health_cap_cleanup")
	return true


func _test_wheel_dirt_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var original_coins := int(root_node.get("coins"))
	var original_total_stars := int(root_node.get("total_stars"))
	var original_best_times: Dictionary = root_node.get("best_times").duplicate(true)
	var original_best_stars: Dictionary = root_node.get("best_stars").duplicate(true)
	root_node.call("reset_game", 1, "wheel_dirt_smoke")
	var wheel_specs: Array = root_node.call("get_wheel_specs_for_test")
	var wheel_indices: Array[int] = root_node.call("get_wheel_dirt_indices_for_test")
	var patches: Array = root_node.get("dirt_patches")
	if wheel_specs.size() != 2 or wheel_indices.size() != 2 or wheel_indices[0] == wheel_indices[1]:
		_fail("each of the two rendered wheels must own one distinct mud patch")
		return false
	var total_health := 0.0
	var non_wheel_mud_count := 0
	for patch_index in range(patches.size()):
		var current_patch = patches[patch_index]
		total_health += float(current_patch.get("max_health"))
		if String(current_patch.get("kind")) == "mud" and patch_index not in wheel_indices:
			non_wheel_mud_count += 1
	if absf(float(root_node.call("get_initial_dirt_total_for_test")) - total_health) > 0.001:
		_fail("wheel mud max health must be included in initial_dirt_total")
		return false
	if int(root_node.call("get_patch_count_by_kind_for_test", "mud")) != non_wheel_mud_count + 2:
		_fail("mud count must include both dedicated wheel patches")
		return false
	var centers: Array[Vector2] = root_node.call("get_patch_centers_for_test")
	for wheel_index in range(2):
		var patch_index := wheel_indices[wheel_index]
		var wheel_patch = patches[patch_index]
		var wheel: Dictionary = wheel_specs[wheel_index]
		if String(wheel_patch.get("kind")) != "mud" \
				or centers[patch_index].distance_to(wheel["center"]) > 0.01 \
				or float(wheel_patch.get("radius")) <= float(wheel["radius"]) * 0.48 \
				or bool(wheel_patch.get("is_gold_spot")):
			_fail("wheel dirt must be centered over and visibly cover each clean hub")
			return false

	var left_index := wheel_indices[0]
	var right_index := wheel_indices[1]
	if not bool(root_node.call("is_tool_misapplied_for_test", "air", left_index)) \
			or String(root_node.call("simulate_patch_hint_for_test", "air", left_index, 0.6)) != "water" \
			or not bool(root_node.call("is_tool_misapplied_for_test", "sponge", right_index)):
		_fail("wheel mud must reuse existing air and dry-sponge coaching")
		return false
	if bool(root_node.call("is_tool_misapplied_for_test", "soap", right_index)):
		_fail("wheel mud must preserve the existing valid soap preparation path")
		return false
	var progress_before := float(root_node.call("get_clean_progress_for_test"))
	root_node.call("apply_tool_to_patch_for_test", "water", left_index, 1.5)
	root_node.call("apply_tool_to_patch_for_test", "water", right_index, 0.25)
	root_node.call("apply_tool_to_patch_for_test", "sponge", right_index, 2.0)
	if float(root_node.call("get_patch_health_for_test", left_index)) > 0.0 \
			or float(root_node.call("get_patch_health_for_test", right_index)) > 0.0 \
			or float(root_node.call("get_clean_progress_for_test")) <= progress_before:
		_fail("water and prepared sponge paths must remove wheel mud and advance cleanliness")
		return false
	for remaining_patch in patches:
		remaining_patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if not bool(root_node.get("completed")) or float(root_node.call("get_clean_progress_for_test")) < 0.999:
		_fail("cleaned wheel mud must allow full cleanliness and level completion")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var draw_start := main_source.find("func _draw() -> void:")
	var draw_end := main_source.find("\nfunc ", draw_start + 1)
	var draw_body := main_source.substr(draw_start, draw_end - draw_start)
	var car_start := main_source.find("func _draw_car(")
	var car_end := main_source.find("\nfunc ", car_start + 1)
	var car_body := main_source.substr(car_start, car_end - car_start)
	if draw_body.find("_draw_dirt()") <= draw_body.find("_draw_car()") \
			or not car_body.contains('Color("#cfd8dc")') \
			or not main_source.contains('_gameplay_point(wheel["center"])'):
		_fail("wheel mud must render above the clean hub at gameplay-transformed wheel centers")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("wheel washing must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("wheel washing must keep existing HUD residency unchanged")
		return false
	root_node.set("coins", original_coins)
	root_node.set("total_stars", original_total_stars)
	root_node.set("best_times", original_best_times)
	root_node.set("best_stars", original_best_stars)
	root_node.call("reset_game", 1, "wheel_dirt_smoke_cleanup")
	return true


func _test_completion_reveal_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.call("reset_game", 1, "completion_reveal_snapshot_smoke")
	var level_one_snapshot: Array[Dictionary] = root_node.call("get_initial_dirt_snapshot_for_test")
	var level_one_patches: Array = root_node.get("dirt_patches")
	if level_one_snapshot.size() != level_one_patches.size() or level_one_snapshot.is_empty():
		_fail("initial dirt snapshot must contain every freshly spawned patch")
		return false
	for index in range(level_one_patches.size()):
		var patch = level_one_patches[index]
		var snapshot := level_one_snapshot[index]
		var expected_position: Vector2 = root_node.call("_gameplay_local_point", patch.get("position"))
		if String(snapshot["kind"]) != String(patch.get("kind")) \
				or (snapshot["position"] as Vector2).distance_to(expected_position) > 0.001 \
				or absf(float(root_node.call("_gameplay_length", snapshot["radius"])) - float(patch.get("radius"))) > 0.001 \
				or absf(float(snapshot["max_health"]) - float(patch.get("max_health"))) > 0.001:
			_fail("completion snapshot must preserve kind, local position, radius, and max health")
			return false

	root_node.call("reset_game", 2, "completion_reveal_snapshot_refresh_smoke")
	var level_two_snapshot: Array[Dictionary] = root_node.call("get_initial_dirt_snapshot_for_test")
	if level_two_snapshot.size() != root_node.get("dirt_patches").size() \
			or level_two_snapshot.size() == level_one_snapshot.size():
		_fail("reset_game must replace the completion snapshot with the new level spawn")
		return false

	var progress_at_completion := float(root_node.call("get_completion_reveal_progress_for_test", 0.0))
	var progress_during_wipe := float(root_node.call("get_completion_reveal_progress_for_test", 0.52))
	var progress_after_wipe := float(root_node.call("get_completion_reveal_progress_for_test", 1.0))
	if progress_at_completion != 0.0 or progress_during_wipe <= 0.0 \
			or progress_during_wipe >= 1.0 or progress_after_wipe != 1.0:
		_fail("completion before-to-after reveal must start within one second and finish after 0.8 seconds")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var snapshot_draw_start := main_source.find("func _draw_initial_dirt_snapshot() -> void:")
	var snapshot_draw_end := main_source.find("\nfunc ", snapshot_draw_start + 1)
	var snapshot_draw_body := main_source.substr(snapshot_draw_start, snapshot_draw_end - snapshot_draw_start)
	for dirt_kind in ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime", "sap"]:
		if not snapshot_draw_body.contains('kind == "' + dirt_kind + '"'):
			_fail("completion before card renderer missing dirt kind: " + dirt_kind)
			return false
	if not snapshot_draw_body.contains("for snapshot in initial_dirt_snapshot"):
		_fail("completion before card must render exactly from the captured snapshot")
		return false
	var save_start := main_source.find("func _save_progress() -> Error:")
	var save_end := main_source.find("\nfunc ", save_start + 1)
	if main_source.substr(save_start, save_end - save_start).contains("initial_dirt_snapshot"):
		_fail("runtime completion snapshot must not change the persisted save payload")
		return false

	root_node.call("reset_game", 1, "completion_reveal_draw_smoke")
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	if not bool(root_node.get("completed")):
		_fail("completion reveal fixture must enter the real completion state")
		return false
	root_node.call("set_completion_reveal_age_for_test", 0.52)
	root_node.queue_redraw()
	await process_frame
	await process_frame
	var completion_panel: Rect2 = root_node.call("_completion_panel_rect")
	var before_card: Rect2 = root_node.call("_completion_card_rect", completion_panel, 0)
	var after_card: Rect2 = root_node.call("_completion_card_rect", completion_panel, 1)
	if not completion_panel.encloses(before_card) or not completion_panel.encloses(after_card) \
			or before_card.intersects(after_card):
		_fail("both completion reveal cards must fit side by side inside the existing panel")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("completion reveal must not add or move a persistent playing HUD element")
		return false
	root_node.call("reset_game", 1, "completion_reveal_smoke_cleanup")
	return true


func _test_customer_patience_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	for elapsed_seconds in [0.0, 35.0, 70.0, 130.0, 140.0, 210.0]:
		var expected := clampf(1.0 - elapsed_seconds / 140.0, 0.0, 1.0)
		if absf(float(root_node.call("get_customer_patience_for_test", elapsed_seconds, 0.0)) - expected) > 0.0001:
			_fail("zero-progress customer patience must retain the original time-only curve")
			return false
	var dirty_late := float(root_node.call("get_customer_patience_for_test", 130.0, 0.0))
	var nearly_clean_late := float(root_node.call("get_customer_patience_for_test", 130.0, 0.9))
	if nearly_clean_late <= dirty_late or nearly_clean_late <= 0.5:
		_fail("high cleaning progress must visibly relieve patience loss at the same elapsed time")
		return false
	if int(root_node.call("get_customer_patience_zone_for_test", 130.0, 0.0)) != 0 \
			or int(root_node.call("get_customer_patience_zone_for_test", 130.0, 0.9)) != 2:
		_fail("patience value, face, mood label, and gauge color must share the new zone model")
		return false
	var previous_zone := 2
	var warning_count := 0
	for current_zone in [2, 1, 1, 2, 2]:
		if bool(root_node.call("should_customer_patience_warn_for_test", previous_zone, current_zone)):
			warning_count += 1
		previous_zone = current_zone
	if warning_count != 1:
		_fail("one patience downgrade must trigger exactly one warning")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var draw_start := main_source.find("func _draw_customer_patience() -> void:")
	var draw_end := main_source.find("\nfunc ", draw_start + 1)
	var draw_body := main_source.substr(draw_start, draw_end - draw_start)
	if not draw_body.contains("var patience := _current_customer_patience()") \
			or not draw_body.contains("var patience_zone := CustomerPatience.zone(patience)") \
			or draw_body.count("patience_zone ==") < 5 \
			or main_source.contains("clampf(1.0 - level_time / STAR2_TIME"):
		_fail("customer face, mood label, gauge, and warning paths must use the shared progress-aware value")
		return false
	var warning_guard := main_source.find("if CustomerPatience.should_warn(_prev_patience_zone, _pzone):")
	var warning_call := main_source.find("audio.play_patience_warn()", warning_guard)
	var warning_state_update := main_source.find("_prev_patience_zone = _pzone", warning_call)
	if warning_guard < 0 or warning_call < warning_guard or warning_state_update < warning_call:
		_fail("patience warning must remain guarded by one downgrade transition before state sync")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("progress-aware patience must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("progress-aware patience must keep the existing HUD residency unchanged")
		return false
	return true


func _test_customer_tip_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var original_state := {
		"active_level": root_node.call("get_active_level_for_test"),
		"game_state": root_node.get("game_state"),
		"level_index": root_node.get("level_index"),
		"coins": root_node.get("coins"),
		"total_stars": root_node.get("total_stars"),
		"best_times": root_node.get("best_times").duplicate(true),
		"best_stars": root_node.get("best_stars").duplicate(true),
		"achievement_counters": root_node.call("get_achievement_counters_for_test"),
		"achievement_claimed": root_node.call("get_achievement_claimed_for_test"),
		"main_save_dirty": root_node.get("_main_save_dirty"),
		"double_offer": root_node.get("_double_offer_shown"),
		"daily_type": root_node.get("daily_mission_type"),
		"daily_label": root_node.get("daily_mission_label"),
		"daily_target": root_node.get("daily_mission_target"),
		"daily_requirement": root_node.get("daily_mission_requirement"),
		"daily_reward": root_node.get("daily_mission_reward"),
		"daily_progress": root_node.get("daily_mission_progress"),
		"daily_claimed": root_node.get("daily_mission_claimed"),
	}

	# AC-1/2: the same progress-aware patience curve feeds a named linear rule.
	# A later clear must pay less, zero patience pays zero, and full patience is
	# capped even before a future rewashing ratio is applied.
	var fast_tip := int(root_node.call("calc_customer_tip_for_test", 30.0, 1.0))
	var late_tip := int(root_node.call("calc_customer_tip_for_test", 140.0, 1.0))
	var exhausted_tip := int(root_node.call("calc_customer_tip_for_test", 500.0, 1.0))
	if fast_tip != 11 or late_tip != 7 or not (fast_tip > late_tip and late_tip > exhausted_tip) \
			or exhausted_tip != 0 \
			or int(root_node.call("calc_customer_tip_for_test", 0.0, 0.0)) != GameConfig.PATIENCE_TIP_MAX_COINS:
		_fail("completion tip must follow remaining patience from the named 12-coin cap to zero")
		return false
	if int(root_node.call("calc_customer_tip_for_test", 0.0, 0.0, 0.5)) != 6:
		_fail("customer tip must expose the same 50 percent ratio needed by rewashing rewards")
		return false

	# Execute the real completion path at high and exhausted patience. Keep daily
	# and achievement rewards inert so every observed coin belongs to completion.
	root_node.call("reset_game", 1, "customer_tip_fast_smoke")
	root_node.call("configure_daily_mission_for_test", "road_grime")
	root_node.set("daily_mission_claimed", true)
	root_node.call("set_achievement_state_for_test", {}, {})
	root_node.set("coins", 0)
	root_node.set("best_stars", {})
	root_node.set("total_stars", 0)
	root_node.set("level_time", 30.0)
	root_node.set("best_combo", 4)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	var fast_completion_tip := int(root_node.call("get_customer_tip_reward_for_test"))
	var fast_expected_reward := int(Economy.calc_coin_reward(3, 4)) + int(Economy.perfect_wash_bonus(3)) + fast_completion_tip
	if fast_completion_tip != fast_tip \
			or int(root_node.get("coin_reward")) != fast_expected_reward \
			or int(root_node.call("get_coins_for_test")) != fast_expected_reward:
		_fail("fast real completion must add the latched patience tip exactly once")
		return false

	root_node.call("reset_game", 1, "customer_tip_exhausted_smoke")
	root_node.call("configure_daily_mission_for_test", "road_grime")
	root_node.set("daily_mission_claimed", true)
	root_node.call("set_achievement_state_for_test", {}, {})
	root_node.set("coins", 0)
	root_node.set("best_stars", {})
	root_node.set("total_stars", 0)
	root_node.set("level_time", 500.0)
	root_node.set("best_combo", 4)
	for patch in root_node.get("dirt_patches"):
		patch.set("health", 0.0)
	root_node.call("_update_clean_progress")
	var exhausted_expected_reward := int(Economy.calc_coin_reward(1, 4)) + int(Economy.perfect_wash_bonus(1))
	if int(root_node.call("get_customer_tip_reward_for_test")) != 0 \
			or int(root_node.get("coin_reward")) != exhausted_expected_reward \
			or int(root_node.call("get_coins_for_test")) != exhausted_expected_reward:
		_fail("exhausted real completion must grant no customer tip")
		return false

	# AC-4/5: the tip is a fixed chip inside the existing completion panel. The
	# optional ad row and action buttons stay disjoint, and the playing HUD keeps
	# its existing four resident rects and Control count.
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var completion_start := main_source.find("func _draw_completion_panel() -> void:")
	var completion_end := main_source.find("\nfunc _completion_panel_rect() -> Rect2:", completion_start)
	var completion_body := main_source.substr(completion_start, completion_end - completion_start)
	if not completion_body.contains('tr("PATIENCE_TIP_CHIP") % customer_tip_reward') \
			or not completion_body.contains('var tip_chip := _customer_tip_chip_rect(panel)'):
		_fail("completion panel must render the latched customer tip in its own chip")
		return false
	root_node.set("_double_offer_shown", true)
	var completion_panel: Rect2 = root_node.call("_completion_panel_rect")
	var tip_chip: Rect2 = root_node.call("_customer_tip_chip_rect", completion_panel)
	var double_rect: Rect2 = root_node.call("_get_double_rect")
	var retry_rect: Rect2 = root_node.call("_get_retry_rect")
	var next_rect: Rect2 = root_node.call("_get_next_rect")
	if not completion_panel.encloses(tip_chip) \
			or tip_chip.intersects(double_rect) \
			or tip_chip.intersects(retry_rect) \
			or tip_chip.intersects(next_rect) \
			or double_rect.intersects(retry_rect) \
			or double_rect.intersects(next_rect):
		_fail("customer tip chip and existing completion actions must remain inside one non-overlapping panel")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("completion-only customer tip must not add or move a persistent playing HUD element")
		return false

	root_node.call("reset_game", int(original_state["active_level"]), "customer_tip_smoke_cleanup")
	root_node.set("game_state", original_state["game_state"])
	root_node.set("level_index", original_state["level_index"])
	root_node.set("coins", original_state["coins"])
	root_node.set("total_stars", original_state["total_stars"])
	root_node.set("best_times", original_state["best_times"])
	root_node.set("best_stars", original_state["best_stars"])
	root_node.call("set_achievement_state_for_test", original_state["achievement_counters"], original_state["achievement_claimed"])
	root_node.set("_main_save_dirty", original_state["main_save_dirty"])
	root_node.set("_double_offer_shown", original_state["double_offer"])
	root_node.set("daily_mission_type", original_state["daily_type"])
	root_node.set("daily_mission_label", original_state["daily_label"])
	root_node.set("daily_mission_target", original_state["daily_target"])
	root_node.set("daily_mission_requirement", original_state["daily_requirement"])
	root_node.set("daily_mission_reward", original_state["daily_reward"])
	root_node.set("daily_mission_progress", original_state["daily_progress"])
	root_node.set("daily_mission_claimed", original_state["daily_claimed"])
	return true


func _test_non_color_accessibility_cues(root_node: Node) -> bool:
	# AC-1 and AC-2: every unavailable purchase surface shares one lock glyph,
	# while all four patience zones resolve to distinct non-color patterns.
	var expected_patterns := ["dots", "ticks", "crosses", "alert"]
	var actual_patterns: Array[String] = []
	for patience in [0.9, 0.5, 0.2, 0.0]:
		actual_patterns.append(String(root_node.call("get_customer_patience_pattern_for_test", patience)))
	if actual_patterns != expected_patterns:
		_fail("patience zones must expose distinct non-color patterns: %s" % [actual_patterns])
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if main_source.count("_draw_unaffordable_lock(") < 5:
		_fail("booster cards, upgrade, and skin purchase surfaces must all draw the shared lock glyph")
		return false
	if not main_source.contains("_draw_patience_tier_pattern(bar, fill_rect, patience_zone)") \
			or not main_source.contains("_draw_patience_tier_pattern(bar, Rect2(bar.position, Vector2.ZERO), patience_zone)"):
		_fail("patience gauge must draw a pattern for filled and empty critical states")
		return false

	# AC-3: every cue receives the rect of its existing purchase surface or gauge;
	# no separate accessibility control is needed in the persistent HUD.
	if not main_source.contains("_draw_unaffordable_lock(foam_card, foam_available") \
			or not main_source.contains("_draw_unaffordable_lock(water_card, water_available") \
			or main_source.count("_draw_unaffordable_lock(buy_rect, affordable") != 2 \
			or not main_source.contains("_draw_patience_tier_pattern(bar, fill_rect"):
		_fail("non-color accessibility cues must stay inside existing surface rects")
		return false
	return true


func _test_text_scale_accessibility_contract(root_node: Node) -> bool:
	# AC-1/3: the title control cycles every persisted option and changes the
	# shared font-size helper immediately without waiting for a scene reload.
	var original_game_state := String(root_node.get("game_state"))
	root_node.call("set_text_scale_for_test", 1.0)
	var scale_rect: Rect2 = root_node.call("_get_title_text_scale_rect")
	var design_rect := Rect2(Vector2.ZERO, Vector2(390.0, 844.0))
	if not design_rect.encloses(scale_rect) \
			or scale_rect.intersects(root_node.call("_get_title_music_rect")) \
			or scale_rect.intersects(root_node.call("_get_title_sfx_rect")) \
			or scale_rect.intersects(root_node.call("_get_title_help_rect")):
		_fail("text-scale control must fit the title and stay separate from audio/help")
		return false
	root_node.set("game_state", "title")
	root_node.set("show_tutorial", false)
	root_node.call("_handle_tap", scale_rect.get_center())
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.25) \
			or int(root_node.call("get_scaled_font_size_for_test", 24)) != 30:
		_fail("one title text-scale tap must apply 125% immediately")
		return false
	root_node.call("_handle_tap", scale_rect.get_center())
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.5):
		_fail("second title text-scale tap must apply 150% immediately")
		return false

	# AC-2/5: every named core surface uses the same scale/fit helpers. The
	# representative 150% strings grow but remain within their existing max width.
	var core_samples := [
		["Foam Party", 44, 374.0],
		[TranslationServer.translate("TUT_TITLE"), 22, 278.0],
		["100%", 15, 70.0],
		["고압수 · 오물을 씻어요", 13, 236.0],
		[TranslationServer.translate("COMPLETE_TITLE"), 24, 218.0],
	]
	for sample in core_samples:
		var sample_text := String(sample[0])
		var base_size := int(sample[1])
		var max_width := float(sample[2])
		var scaled_size := int(root_node.call(
			"get_scaled_font_size_for_test", base_size, sample_text, max_width
		))
		var fitted_width := float(root_node.call(
			"get_fitted_text_width_for_test", sample_text, base_size, max_width
		))
		if scaled_size <= base_size or fitted_width > max_width + 0.01:
			_fail("150% core text must grow and fit its existing surface: %s" % sample_text)
			return false
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for required_call in [
		"_fit_fs(title_text, 44",
		"_fit_fs(tutorial_title, 22",
		"_fit_fs(progress_text, 15",
		"_fit_fs(hint_text, 13",
		"_fit_fs(complete_title, 24",
	]:
		if not main_source.contains(required_call):
			_fail("core readable text must use the shared scale helper: " + required_call)
			return false

	# AC-1/4: ConfigFile disk round trip preserves 150%; a legacy settings file
	# with no key resolves to the 100% default. Invalid values snap to an option.
	var scale_save_path := OS.get_temp_dir().path_join("foam_party_text_scale_smoke.cfg")
	var stored_config := ConfigFile.new()
	root_node.call("_store_text_scale_setting", stored_config)
	if stored_config.save(scale_save_path) != OK:
		_fail("text-scale fixture failed to save")
		return false
	var reloaded_config := ConfigFile.new()
	if reloaded_config.load(scale_save_path) != OK:
		_fail("text-scale fixture failed to reload")
		return false
	root_node.call("set_text_scale_for_test", 1.0)
	root_node.call("_load_text_scale_setting", reloaded_config)
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.5):
		_fail("text scale must survive a ConfigFile disk round trip")
		return false
	root_node.set("game_state", "title")
	root_node.call("_handle_tap", scale_rect.get_center())
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.0):
		_fail("text-scale title control must wrap from 150% back to 100%")
		return false
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("settings", "sound", true)
	var reloaded_legacy_config := ConfigFile.new()
	if legacy_config.save(scale_save_path) != OK or reloaded_legacy_config.load(scale_save_path) != OK:
		_fail("legacy text-scale fixture failed its ConfigFile disk round trip")
		return false
	root_node.call("set_text_scale_for_test", 1.5)
	root_node.call("_load_text_scale_setting", reloaded_legacy_config)
	DirAccess.remove_absolute(scale_save_path)
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.0):
		_fail("legacy settings without text_scale must default to 100%")
		return false
	root_node.call("set_text_scale_for_test", 1.42)
	if not is_equal_approx(float(root_node.call("get_text_scale_for_test")), 1.5):
		_fail("unsupported text scale must normalize to the nearest persisted option")
		return false

	# AC-6: at 100% all helper outputs are the original literals, so existing
	# positions and max-width contracts render unchanged.
	root_node.call("set_text_scale_for_test", 1.0)
	for base_size in [10, 13, 15, 16, 22, 24, 44]:
		if int(root_node.call("get_scaled_font_size_for_test", base_size)) != base_size:
			_fail("100% text scale must preserve every existing base font size")
			return false
	root_node.set("game_state", original_game_state)
	return true


func _test_audio_bus_contract(root_node: Node) -> bool:
	# AC-1: runtime setup creates dedicated buses and routes exactly one BGM plus
	# every current one-shot and loop player. Silent headless nodes keep all 17
	# SFX routes observable without starting playback.
	var bus_state: Dictionary = root_node.call("get_audio_bus_state_for_test")
	if int(bus_state.get("music_index", -1)) < 0 or int(bus_state.get("sfx_index", -1)) < 0:
		_fail("dedicated Music and SFX buses must exist")
		return false
	var player_buses: Dictionary = root_node.call("get_audio_player_bus_map_for_test")
	if player_buses.size() != 18 or String(player_buses.get("BackgroundMusic", "")) != "Music":
		_fail("audio routing must expose one Music player and 17 SFX players")
		return false
	for player_name in player_buses:
		if player_name == "BackgroundMusic":
			continue
		if String(player_buses[player_name]) != "SFX":
			_fail("effect player must route to SFX: " + String(player_name))
			return false

	# AC-2/5: muting either channel changes only its own bus and never Master.
	root_node.set("music_enabled", false)
	root_node.set("sfx_enabled", true)
	root_node.call("_apply_audio_settings")
	bus_state = root_node.call("get_audio_bus_state_for_test")
	if not bool(bus_state["music_muted"]) or bool(bus_state["sfx_muted"]) or bool(bus_state["master_muted"]):
		_fail("music OFF must leave SFX and Master audible")
		return false
	root_node.set("music_enabled", true)
	root_node.set("sfx_enabled", false)
	root_node.call("_apply_audio_settings")
	bus_state = root_node.call("get_audio_bus_state_for_test")
	if bool(bus_state["music_muted"]) or not bool(bus_state["sfx_muted"]) or bool(bus_state["master_muted"]):
		_fail("SFX OFF must leave Music and Master audible")
		return false

	# AC-3/6: new keys survive a disk round trip. A legacy save containing only
	# the old Master-mute key migrates both missing channels to ON.
	var save_path := OS.get_temp_dir().path_join("foam_party_audio_bus_smoke.cfg")
	var stored_config := ConfigFile.new()
	root_node.call("_store_audio_settings", stored_config)
	if stored_config.save(save_path) != OK:
		_fail("audio settings fixture failed to save")
		return false
	var reloaded_config := ConfigFile.new()
	if reloaded_config.load(save_path) != OK:
		_fail("audio settings fixture failed to reload")
		return false
	root_node.set("music_enabled", false)
	root_node.set("sfx_enabled", true)
	root_node.call("_load_audio_settings", reloaded_config)
	if not bool(root_node.call("get_music_enabled_for_test")) or bool(root_node.call("get_sfx_enabled_for_test")):
		_fail("independent audio states must survive a ConfigFile disk round trip")
		return false
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("settings", "sound", false)
	root_node.call("_load_audio_settings", legacy_config)
	DirAccess.remove_absolute(save_path)
	if not bool(root_node.call("get_music_enabled_for_test")) or not bool(root_node.call("get_sfx_enabled_for_test")):
		_fail("legacy sound-only saves must default both new channels to ON")
		return false

	# AC-4: title exposes two independent, non-overlapping controls and their taps
	# update the same localized state projected by the pause controls.
	var original_game_state := String(root_node.get("game_state"))
	var music_rect: Rect2 = root_node.call("_get_title_music_rect")
	var sfx_rect: Rect2 = root_node.call("_get_title_sfx_rect")
	var help_rect: Rect2 = root_node.call("_get_title_help_rect")
	if music_rect.intersects(sfx_rect) or music_rect.intersects(help_rect) or sfx_rect.intersects(help_rect):
		_fail("title music, SFX, and help controls must not overlap")
		return false
	root_node.set("game_state", "title")
	root_node.set("show_tutorial", false)
	root_node.call("_handle_tap", music_rect.get_center())
	if bool(root_node.call("get_music_enabled_for_test")) \
			or not bool(root_node.call("get_sfx_enabled_for_test")) \
			or root_node.call("_pause_audio_label", "music") != TranslationServer.translate("MUSIC_OFF"):
		_fail("title music control must update only the music state")
		return false
	root_node.call("_handle_tap", sfx_rect.get_center())
	if bool(root_node.call("get_music_enabled_for_test")) \
			or bool(root_node.call("get_sfx_enabled_for_test")) \
			or root_node.call("_pause_audio_label", "sfx") != TranslationServer.translate("SFX_OFF"):
		_fail("title SFX control must update only the SFX state")
		return false

	root_node.set("music_enabled", true)
	root_node.set("sfx_enabled", true)
	root_node.call("_apply_audio_settings")
	root_node.set("game_state", original_game_state)
	return true


func _test_reduce_motion_accessibility_contract(root_node: Node) -> bool:
	# AC-1: legacy saves default OFF. The new row stays inside the existing modal,
	# separate from language and all six action hit targets.
	root_node.call("set_reduce_motion_for_test", false)
	if bool(root_node.call("get_reduce_motion_for_test")):
		_fail("reduced motion must default to OFF")
		return false
	var panel: Rect2 = root_node.call("_pause_panel")
	var motion_rect: Rect2 = root_node.call("_pause_reduce_motion_rect")
	var language_rect: Rect2 = root_node.call("_pause_language_rect")
	if not panel.encloses(motion_rect) or motion_rect.intersects(language_rect):
		_fail("reduced-motion row must fit the pause sheet below language")
		return false
	for action_index in range(6):
		if motion_rect.intersects(root_node.call("_pause_button_rect", action_index)):
			_fail("reduced-motion row must not overlap pause actions")
			return false

	# One real modal tap applies immediately and keeps the sheet open.
	root_node.set("show_pause", true)
	root_node.call("_handle_tap", motion_rect.get_center())
	if not bool(root_node.call("get_reduce_motion_for_test")) \
			or not bool(root_node.get("show_pause")) \
			or root_node.call("_pause_reduce_motion_label") != TranslationServer.translate("REDUCE_MOTION_ON"):
		_fail("pause toggle must enable reduced motion without closing settings")
		return false

	# AC-1/5: persist ON through an actual ConfigFile disk round trip. A legacy
	# file with no key must restore the documented OFF default.
	var save_path := OS.get_temp_dir().path_join("foam_party_reduce_motion_smoke.cfg")
	var stored_config := ConfigFile.new()
	root_node.call("_store_reduce_motion_setting", stored_config)
	if stored_config.save(save_path) != OK:
		_fail("reduced-motion fixture failed to save")
		return false
	var reloaded_config := ConfigFile.new()
	if reloaded_config.load(save_path) != OK:
		_fail("reduced-motion fixture failed to reload")
		return false
	root_node.call("set_reduce_motion_for_test", false)
	root_node.call("_load_reduce_motion_setting", reloaded_config)
	if not bool(root_node.call("get_reduce_motion_for_test")):
		_fail("reduced motion must survive a ConfigFile disk round trip")
		return false
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("settings", "sound", true)
	root_node.call("_load_reduce_motion_setting", legacy_config)
	DirAccess.remove_absolute(save_path)
	if bool(root_node.call("get_reduce_motion_for_test")):
		_fail("legacy settings without reduce_motion must default to OFF")
		return false

	# AC-6: OFF is the exact current policy: all 90 completion particles and both
	# overlay paths remain enabled.
	if int(root_node.call("get_effect_particle_count_for_test", 90)) != 90 \
			or not bool(root_node.call("get_combo_flash_visuals_enabled_for_test")) \
			or not bool(root_node.call("get_completion_gleam_enabled_for_test")):
		_fail("OFF must preserve the existing particle, flash, and gleam visuals")
		return false
	root_node.get("particles").clear()
	root_node.set("completion_burst_done", false)
	root_node.set("is_new_record", false)
	root_node.set("level_time", 0.0)
	root_node.call("_spawn_completion_burst")
	var normal_completion_count := int(root_node.call("get_particle_count_for_test"))
	if normal_completion_count != 90:
		_fail("normal completion burst must retain its existing 90 particles")
		return false

	root_node.get("particles").clear()
	root_node.set("combo_count", 6)
	root_node.set("selected_tool", "water")
	root_node.get("rng").seed = 7501
	root_node.call("_spawn_removal_burst", Vector2(195.0, 520.0), 18.0)
	root_node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	var normal_removal_count := int(root_node.call("get_particle_count_for_test"))

	# AC-2/3/4: ON removes flash/edge/gleam, retains the localized fanfare and
	# keeps visible removal/completion feedback at no more than half normal count.
	root_node.call("set_reduce_motion_for_test", true)
	if bool(root_node.call("get_combo_flash_visuals_enabled_for_test")) \
			or bool(root_node.call("get_completion_gleam_enabled_for_test")):
		_fail("ON must suppress combo flash, edge glow, and completion gleam")
		return false
	root_node.call("_trigger_combo_milestone_flash", 8)
	if String(root_node.get("_combo_milestone_fanfare")).is_empty() \
			or int(root_node.get("_combo_milestone_count")) != 8:
		_fail("reduced motion must retain combo fanfare text")
		return false

	root_node.get("particles").clear()
	root_node.set("completion_burst_done", false)
	root_node.call("_spawn_completion_burst")
	var reduced_completion_count := int(root_node.call("get_particle_count_for_test"))
	if reduced_completion_count <= 0 \
			or reduced_completion_count > int(floor(float(normal_completion_count) * 0.5)):
		_fail("reduced completion particles must stay visible at no more than 50%")
		return false
	root_node.get("particles").clear()
	root_node.get("rng").seed = 7501
	root_node.call("_spawn_removal_burst", Vector2(195.0, 520.0), 18.0)
	root_node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	var reduced_removal_count := int(root_node.call("get_particle_count_for_test"))
	if reduced_removal_count <= 0 \
			or reduced_removal_count > int(floor(float(normal_removal_count) * 0.5)):
		_fail("reduced removal particles must stay visible at no more than 50%")
		return false
	if float(root_node.call("get_completion_reveal_progress_for_test", 0.5)) <= 0.0:
		_fail("reduced motion must retain completion star reveal progress")
		return false

	root_node.call("set_reduce_motion_for_test", false)
	root_node.set("show_pause", false)
	root_node.get("particles").clear()
	root_node.set("completion_burst_done", false)
	return true


func _test_wash_guide_contract(root_node: Node) -> bool:
	var original_game_state: String = String(root_node.get("game_state"))
	var baseline_control_count: int = root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.set("game_state", "title")
	root_node.set("show_tutorial", false)
	root_node.call("_handle_tap", root_node.call("_get_title_help_rect").get_center())
	if not bool(root_node.get("show_tutorial")) or int(root_node.get("_tutorial_tab")) != 0:
		_fail("title help must reopen the wash guide on its tools tab")
		return false
	root_node.call("_handle_tap", root_node.call("_tutorial_tab_rect", 1).get_center())
	if not bool(root_node.get("show_tutorial")) or int(root_node.get("_tutorial_tab")) != 1:
		_fail("wash guide must switch to the dirt catalog inside the same modal")
		return false

	var expected_kinds: Array = GameConfig.DIRT_TYPES
	var entries: Array = root_node.call("get_wash_guide_entries_for_test")
	if entries.size() != expected_kinds.size() or entries.size() != 8:
		_fail("wash guide must cover all eight current dirt types")
		return false
	var panel: Rect2 = root_node.call("_tutorial_panel_rect")
	var previous_row := Rect2()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if String(entry.get("kind", "")) != String(expected_kinds[index]) \
				or (entry.get("primary", []) as Array).is_empty() \
				or String(entry.get("description_key", "")).is_empty():
			_fail("each current dirt must expose an icon row, primary path, and description")
			return false
		var row: Rect2 = root_node.call("_tutorial_dirt_row_rect", index)
		if not panel.encloses(row) or (index > 0 and previous_row.intersects(row)):
			_fail("all dirt guide rows must fit without overlap in the existing guide modal")
			return false
		previous_row = row
	if not panel.encloses(root_node.call("_tutorial_tab_rect", 0)) \
			or not panel.encloses(root_node.call("_tutorial_tab_rect", 1)) \
			or not panel.encloses(root_node.call("_tutorial_done_rect")):
		_fail("wash guide tabs and close action must remain inside the existing modal")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_count \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("wash guide must not add or move a persistent gameplay HUD element")
		return false

	root_node.call("_handle_tap", root_node.call("_tutorial_done_rect").get_center())
	if bool(root_node.get("show_tutorial")) or String(root_node.get("game_state")) != "title":
		_fail("closing the wash guide must return immediately to the prior title screen")
		return false
	root_node.set("game_state", original_game_state)
	return true


func _test_upgrade_panel_residency(root_node: Node) -> bool:
	# Issue 116 AC-4: opening and rendering the data-tuned upgrade panel must not
	# create a new UI node or alter any persistent HUD residency rectangle.
	var baseline_node_count := root_node.find_children("*", "Node", true, false).size()
	var baseline_control_count := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	root_node.set("show_upgrade_panel", true)
	root_node.queue_redraw()
	await process_frame
	await process_frame
	var residency_changed: bool = \
		root_node.find_children("*", "Node", true, false).size() != baseline_node_count \
		or root_node.find_children("*", "Control", true, false).size() != baseline_control_count \
		or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
		or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
		or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
		or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]
	root_node.set("show_upgrade_panel", false)
	root_node.queue_redraw()
	if residency_changed:
		_fail("upgrade cost tuning must not create a new UI node or HUD residency")
		return false
	return true


func _test_air_power_upgrade_contract(root_node: Node) -> bool:
	var original_state := {
		"active_level": root_node.call("get_active_level_for_test"),
		"level_index": root_node.get("level_index"),
		"game_state": root_node.get("game_state"),
		"coins": root_node.get("coins"),
		"air": root_node.get("upgrade_air"),
		"water": root_node.get("upgrade_water"),
		"soap": root_node.get("upgrade_soap"),
		"sponge": root_node.get("upgrade_sponge"),
		"reach_air": root_node.get("reach_upgrade_air"),
		"reach_water": root_node.get("reach_upgrade_water"),
		"reach_soap": root_node.get("reach_upgrade_soap"),
		"reach_sponge": root_node.get("reach_upgrade_sponge"),
		"tab": root_node.get("_upgrade_panel_tab"),
		"show": root_node.get("show_upgrade_panel"),
		"main_save_dirty": root_node.get("_main_save_dirty"),
	}

	# AC-1: the actual power-tab transaction rejects insufficient coins, then
	# purchases all three named air tiers for exactly 80 + 160 + 280 coins.
	for tool_key in GameConfig.UPGRADE_KEYS:
		root_node.call("set_power_upgrade_level_for_test", tool_key, 0)
	root_node.set("_upgrade_panel_tab", 0)
	root_node.set("coins", 79)
	root_node.call("_try_buy_upgrade", 0)
	if int(root_node.call("get_power_upgrade_level_for_test", "air")) != 0 \
			or int(root_node.get("coins")) != 79:
		_fail("79 coins must not buy the first air power tier")
		return false
	root_node.set("coins", 520)
	for _tier in range(3):
		root_node.call("_try_buy_upgrade", 0)
	if int(root_node.call("get_power_upgrade_level_for_test", "air")) != 3 \
			or int(root_node.get("coins")) != 0:
		_fail("air power must buy through level three for 80, 160, and 280 coins")
		return false

	# AC-2/3/6: every named level scales damage on a real level-one leaf through
	# apply_tool_to_patch_for_test. A maxed sponge must not leak into air lookup.
	root_node.call("set_power_upgrade_level_for_test", "air", 1)
	root_node.call("set_power_upgrade_level_for_test", "sponge", 3)
	if absf(float(root_node.call("get_tool_power_multiplier_for_test", "air")) - 1.3) > 0.001 \
			or absf(float(root_node.call("get_tool_power_multiplier_for_test", "sponge")) - 2.0) > 0.001:
		_fail("air power lookup must use upgrade_air instead of the sponge level")
		return false
	root_node.call("reset_game", 1, "air_power_upgrade_smoke")
	var leaf_index := int(root_node.call("get_patch_index_by_kind_for_test", "leaf"))
	if leaf_index < 0:
		_fail("air power smoke requires the deterministic level-one leaf")
		return false
	var leaf_patch: Variant = root_node.get("dirt_patches")[leaf_index]
	var initial_health := float(leaf_patch.get("health"))
	var initial_state := String(leaf_patch.get("state"))
	var initial_looseness := float(leaf_patch.get("looseness"))
	var base_damage := 0.0
	for level in range(GameConfig.UPGRADE_MAX_LEVEL + 1):
		root_node.call("set_power_upgrade_level_for_test", "air", level)
		leaf_patch.set("health", initial_health)
		leaf_patch.set("state", initial_state)
		leaf_patch.set("looseness", initial_looseness)
		leaf_patch.set("drift", Vector2.ZERO)
		leaf_patch.set("velocity", Vector2.ZERO)
		# One simulation step keeps proximity identical before the air motion moves
		# the leaf, isolating only the permanent power multiplier.
		var health_after := float(root_node.call("apply_tool_to_patch_for_test", "air", leaf_index, 0.01))
		var damage := initial_health - health_after
		if level == 0:
			base_damage = damage
		var expected_damage := base_damage * float(GameConfig.UPGRADE_MULTS[level])
		if damage <= 0.0 or absf(damage - expected_damage) > 0.01:
			_fail("air power level must scale actual leaf damage by UPGRADE_MULTS")
			return false

	# AC-4: round-trip air beside all existing power/reach keys, then load a
	# legacy config without air and confirm the new level safely defaults to zero.
	root_node.call("set_power_upgrade_level_for_test", "air", 2)
	root_node.call("set_power_upgrade_level_for_test", "water", 1)
	root_node.call("set_power_upgrade_level_for_test", "soap", 2)
	root_node.call("set_power_upgrade_level_for_test", "sponge", 3)
	var stored_config := ConfigFile.new()
	root_node.call("_store_upgrade_progress", stored_config)
	var roundtrip_path := "user://air_power_upgrade_smoke.cfg"
	if stored_config.save(roundtrip_path) != OK:
		_fail("air power smoke could not write its isolated ConfigFile")
		return false
	var loaded_config := ConfigFile.new()
	if loaded_config.load(roundtrip_path) != OK:
		_fail("air power smoke could not reload its isolated ConfigFile")
		return false
	for tool_key in GameConfig.UPGRADE_KEYS:
		root_node.call("set_power_upgrade_level_for_test", tool_key, 0)
	root_node.call("_load_upgrade_progress", loaded_config)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(roundtrip_path))
	if int(root_node.call("get_power_upgrade_level_for_test", "air")) != 2 \
			or int(root_node.call("get_power_upgrade_level_for_test", "water")) != 1 \
			or int(root_node.call("get_power_upgrade_level_for_test", "soap")) != 2 \
			or int(root_node.call("get_power_upgrade_level_for_test", "sponge")) != 3:
		_fail("all four power levels must round-trip through the upgrade save schema")
		return false
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("upgrades", "water", 3)
	legacy_config.set_value("upgrades", "soap", 1)
	legacy_config.set_value("upgrades", "sponge", 2)
	root_node.call("set_power_upgrade_level_for_test", "air", 3)
	root_node.call("_load_upgrade_progress", legacy_config)
	if int(root_node.call("get_power_upgrade_level_for_test", "air")) != 0 \
			or int(root_node.call("get_power_upgrade_level_for_test", "water")) != 3 \
			or int(root_node.call("get_power_upgrade_level_for_test", "soap")) != 1 \
			or int(root_node.call("get_power_upgrade_level_for_test", "sponge")) != 2:
		_fail("legacy power save without air must preserve old levels and default air to zero")
		return false

	# AC-1/5: the localized air row and its buy button fit the existing 520px
	# panel alongside the other three power rows without overlap.
	root_node.set("_upgrade_panel_tab", 0)
	root_node.set("show_upgrade_panel", true)
	root_node.queue_redraw()
	await process_frame
	await process_frame
	if String(root_node.tr("UPG_NAME_AIR")) == "UPG_NAME_AIR":
		_fail("air power row must have a localized label")
		return false
	var panel: Rect2 = root_node.call("_upgrade_panel_rect")
	var previous_row := Rect2()
	for index in range(GameConfig.UPGRADE_KEYS.size()):
		var row_y := float(root_node.call("_upgrade_row_y", panel, index))
		var row := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 78.0)
		var buy_rect: Rect2 = root_node.call("_upgrade_buy_rect", panel, index)
		if not panel.encloses(row) or not row.encloses(buy_rect) \
				or (index > 0 and previous_row.intersects(row)):
			_fail("four power rows and buy buttons must fit without overlap in the existing panel")
			return false
		previous_row = row

	root_node.call("reset_game", int(original_state["active_level"]), "air_power_upgrade_smoke_cleanup")
	root_node.set("level_index", original_state["level_index"])
	root_node.set("game_state", original_state["game_state"])
	root_node.set("coins", original_state["coins"])
	root_node.set("upgrade_air", original_state["air"])
	root_node.set("upgrade_water", original_state["water"])
	root_node.set("upgrade_soap", original_state["soap"])
	root_node.set("upgrade_sponge", original_state["sponge"])
	root_node.set("reach_upgrade_air", original_state["reach_air"])
	root_node.set("reach_upgrade_water", original_state["reach_water"])
	root_node.set("reach_upgrade_soap", original_state["reach_soap"])
	root_node.set("reach_upgrade_sponge", original_state["reach_sponge"])
	root_node.set("_upgrade_panel_tab", original_state["tab"])
	root_node.set("show_upgrade_panel", original_state["show"])
	root_node.set("_main_save_dirty", original_state["main_save_dirty"])
	root_node.queue_redraw()
	return true


func _test_reach_upgrade_contract(root_node: Node) -> bool:
	var tool_keys := ["air", "water", "soap", "sponge"]
	var original_state := {
		"coins": root_node.get("coins"),
		"upgrade_air": root_node.get("upgrade_air"),
		"upgrade_water": root_node.get("upgrade_water"),
		"upgrade_soap": root_node.get("upgrade_soap"),
		"upgrade_sponge": root_node.get("upgrade_sponge"),
		"reach_air": root_node.get("reach_upgrade_air"),
		"reach_water": root_node.get("reach_upgrade_water"),
		"reach_soap": root_node.get("reach_upgrade_soap"),
		"reach_sponge": root_node.get("reach_upgrade_sponge"),
		"tab": root_node.get("_upgrade_panel_tab"),
		"show": root_node.get("show_upgrade_panel"),
	}
	var baseline_control_count := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}

	# AC-1/2: every tool radius executes the same named three-level multiplier
	# curve. Water's temporary booster remains a later multiplier and is covered
	# independently by the existing booster smoke.
	for tool_key in tool_keys:
		root_node.call("set_reach_upgrade_level_for_test", tool_key, 0)
		var base_radius := float(root_node.call("get_tool_radius_for_test", tool_key))
		var previous_radius := base_radius
		for level in range(1, GameConfig.REACH_UPGRADE_MAX_LEVEL + 1):
			root_node.call("set_reach_upgrade_level_for_test", tool_key, level)
			var upgraded_radius := float(root_node.call("get_tool_radius_for_test", tool_key))
			var expected_radius := base_radius * float(GameConfig.REACH_UPGRADE_MULTS[level])
			if upgraded_radius <= previous_radius or absf(upgraded_radius - expected_radius) > 0.001:
				_fail("reach level must monotonically scale the actual %s tool radius" % tool_key)
				return false
			previous_radius = upgraded_radius

	# Execute an actual first-tier air purchase from the reach tab. The existing
	# transaction path must charge its named cost and immediately affect radius.
	for tool_key in tool_keys:
		root_node.call("set_reach_upgrade_level_for_test", tool_key, 0)
	root_node.set("_upgrade_panel_tab", 1)
	root_node.set("coins", 70)
	var air_radius_before := float(root_node.call("get_tool_radius_for_test", "air"))
	root_node.call("_try_buy_upgrade", 0)
	if int(root_node.call("get_reach_upgrade_level_for_test", "air")) != 1 \
			or int(root_node.get("coins")) != 0 \
			or absf(float(root_node.call("get_tool_radius_for_test", "air")) - air_radius_before * 1.12) > 0.001:
		_fail("reach-tab purchase must charge 70 coins and increase the actual air radius")
		return false

	# AC-4/6: round-trip both schemas through an actual ConfigFile. A legacy file
	# without reach keys preserves its existing power levels and defaults every
	# new reach level to zero.
	root_node.set("upgrade_air", 2)
	root_node.set("upgrade_water", 1)
	root_node.set("upgrade_soap", 2)
	root_node.set("upgrade_sponge", 3)
	for index in range(tool_keys.size()):
		root_node.call("set_reach_upgrade_level_for_test", tool_keys[index], (index % 3) + 1)
	var stored_config := ConfigFile.new()
	root_node.call("_store_upgrade_progress", stored_config)
	var roundtrip_path := "user://reach_upgrade_smoke.cfg"
	if stored_config.save(roundtrip_path) != OK:
		_fail("reach upgrade smoke could not write its isolated ConfigFile")
		return false
	var loaded_config := ConfigFile.new()
	if loaded_config.load(roundtrip_path) != OK:
		_fail("reach upgrade smoke could not reload its isolated ConfigFile")
		return false
	root_node.set("upgrade_air", 0)
	root_node.set("upgrade_water", 0)
	root_node.set("upgrade_soap", 0)
	root_node.set("upgrade_sponge", 0)
	for tool_key in tool_keys:
		root_node.call("set_reach_upgrade_level_for_test", tool_key, 0)
	root_node.call("_load_upgrade_progress", loaded_config)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(roundtrip_path))
	if int(root_node.get("upgrade_air")) != 2 \
			or int(root_node.get("upgrade_water")) != 1 \
			or int(root_node.get("upgrade_soap")) != 2 \
			or int(root_node.get("upgrade_sponge")) != 3:
		_fail("existing power upgrade levels must round-trip beside reach levels")
		return false
	for index in range(tool_keys.size()):
		if int(root_node.call("get_reach_upgrade_level_for_test", tool_keys[index])) != (index % 3) + 1:
			_fail("all four reach levels must round-trip through the main save schema")
			return false

	var legacy_config := ConfigFile.new()
	legacy_config.set_value("upgrades", "water", 3)
	legacy_config.set_value("upgrades", "soap", 1)
	legacy_config.set_value("upgrades", "sponge", 2)
	for tool_key in tool_keys:
		root_node.call("set_reach_upgrade_level_for_test", tool_key, 3)
	root_node.call("_load_upgrade_progress", legacy_config)
	if int(root_node.get("upgrade_air")) != 0 \
			or int(root_node.get("upgrade_water")) != 3 \
			or int(root_node.get("upgrade_soap")) != 1 \
			or int(root_node.get("upgrade_sponge")) != 2:
		_fail("legacy save must preserve all existing power upgrade values")
		return false
	for tool_key in tool_keys:
		if int(root_node.call("get_reach_upgrade_level_for_test", tool_key)) != 0:
			_fail("legacy save without reach keys must default new reach levels to zero")
			return false

	# AC-3/5: tap the actual tab inside the existing upgrade panel, render all four
	# rows, and assert that no separate sheet, Control, or HUD residency was added.
	root_node.set("_upgrade_panel_tab", 0)
	root_node.call("_handle_upgrade_panel_tap", root_node.call("_upgrade_tab_rect", 1).get_center())
	if int(root_node.get("_upgrade_panel_tab")) != 1:
		_fail("existing upgrade panel must switch to its reach tab from the real tap path")
		return false
	root_node.set("show_upgrade_panel", true)
	root_node.queue_redraw()
	await process_frame
	await process_frame
	var panel: Rect2 = root_node.call("_upgrade_panel_rect")
	if not panel.encloses(root_node.call("_upgrade_tab_rect", 0)) \
			or not panel.encloses(root_node.call("_upgrade_tab_rect", 1)):
		_fail("power and reach tabs must stay inside the existing upgrade panel")
		return false
	var previous_row := Rect2()
	for index in range(tool_keys.size()):
		var row_y := float(root_node.call("_upgrade_row_y", panel, index))
		var row := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 78.0)
		var buy_rect: Rect2 = root_node.call("_upgrade_buy_rect", panel, index)
		if not panel.encloses(row) or not row.encloses(buy_rect) \
				or (index > 0 and previous_row.intersects(row)):
			_fail("four reach rows and buy buttons must fit without overlap in the existing panel")
			return false
		previous_row = row
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if main_source.contains("show_reach_upgrade_panel") \
			or not main_source.contains('tr("UPG_TAB_REACH")') \
			or not main_source.contains("_store_upgrade_progress(config)") \
			or not main_source.contains("_load_upgrade_progress(config)"):
		_fail("reach upgrades must reuse one panel and remain wired to the main save lifecycle")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_count \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("reach upgrades must not add or move a persistent playing HUD element")
		return false

	root_node.set("coins", original_state["coins"])
	root_node.set("upgrade_air", original_state["upgrade_air"])
	root_node.set("upgrade_water", original_state["upgrade_water"])
	root_node.set("upgrade_soap", original_state["upgrade_soap"])
	root_node.set("upgrade_sponge", original_state["upgrade_sponge"])
	root_node.set("reach_upgrade_air", original_state["reach_air"])
	root_node.set("reach_upgrade_water", original_state["reach_water"])
	root_node.set("reach_upgrade_soap", original_state["reach_soap"])
	root_node.set("reach_upgrade_sponge", original_state["reach_sponge"])
	root_node.set("_upgrade_panel_tab", original_state["tab"])
	root_node.set("show_upgrade_panel", original_state["show"])
	root_node.queue_redraw()
	return true


func _test_scaled_star3_combo_gate_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var expected_requirements := {1: 4, 3: 4, 4: 5, 7: 6, 19: 10, 40: 10}
	for level in expected_requirements:
		if int(root_node.call("get_star3_combo_requirement_for_test", level)) != int(expected_requirements[level]):
			_fail("live third-star combo requirement must scale deterministically and cap at ten")
			return false
	root_node.call("reset_game", 4, "scaled_combo_gate_smoke")
	root_node.set("level_time", 60.0)
	root_node.set("best_combo", 4)
	var expected_prompt := TranslationServer.translate("GRADE_COMBO_FOR3") % 5
	var actual_prompt := String(root_node.call("_grade_combo_prompt"))
	if actual_prompt != expected_prompt:
		_fail("existing grade tracker must display the scaled level 4 combo requirement x5")
		return false
	if int(root_node.call("calc_stars_for_test")) != 2 \
			or String(root_node.call("_grade_slot_state", 2)) != "target":
		_fail("level 4 combo four must remain below the scaled third-star gate")
		return false
	var patches: Array = root_node.get("dirt_patches")
	for patch_index in range(4):
		root_node.call("_mark_patch_removed", patches[patch_index])
	if bool(root_node.call("is_star3_combo_unlocked_for_test")):
		_fail("third-star gate sound and haptic must not unlock below the scaled threshold")
		return false
	root_node.call("_mark_patch_removed", patches[4])
	if not bool(root_node.call("is_star3_combo_unlocked_for_test")) \
			or int(root_node.call("get_combo_for_test")) != 5 \
			or int(root_node.call("calc_stars_for_test")) != 3 \
			or String(root_node.call("_grade_slot_state", 2)) != "earned":
		_fail("level 4 combo five must unlock feedback and the third-star gate together")
		return false

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if main_source.contains("STAR3_COMBO") \
			or not main_source.contains("text = _grade_combo_prompt()") \
			or not main_source.contains('text = tr("GRADE_COMBO_URGENT") % [combo_requirement, secs]'):
		_fail("grade tracker text and combo visuals must use the scaled requirement without a fixed threshold")
		return false
	var gate_guard := main_source.find("if combo_count == _star3_combo_requirement() and not _star3_combo_unlocked:")
	var gate_sound := main_source.find("audio.play_star3_gate()", gate_guard)
	var gate_haptic := main_source.find("Input.vibrate_handheld(50)", gate_sound)
	var next_branch := main_source.find("if COMBO_BONUS_AMOUNTS.has(combo_count):", gate_guard)
	if gate_guard < 0 or gate_sound < gate_guard or gate_haptic < gate_sound or next_branch < gate_haptic:
		_fail("scaled combo gate must guard its existing sound and haptic feedback")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("scaled combo gate must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("scaled combo gate must keep the existing grade tracker residency unchanged")
		return false
	root_node.call("reset_game", 1, "scaled_combo_gate_smoke_cleanup")
	return true


func _test_scaled_grade_tracker_prompt_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var expected_prompts := {1: 4, 4: 5, 7: 6, 19: 10}
	for level in expected_prompts:
		var combo_requirement := int(expected_prompts[level])
		root_node.call("reset_game", int(level), "scaled_grade_tracker_prompt_smoke")
		root_node.set("level_time", 20.0)
		root_node.set("best_combo", combo_requirement - 1)
		if String(root_node.call("_grade_slot_state", 2)) != "target":
			_fail("scaled grade tracker prompt requires the third star to remain a reachable target at level %d" % level)
			return false
		var expected_prompt := TranslationServer.translate("GRADE_COMBO_FOR3") % combo_requirement
		root_node.queue_redraw()
		await process_frame
		await process_frame
		var rendered_prompt := String(root_node.call("get_last_grade_tracker_text_for_test"))
		if rendered_prompt != expected_prompt:
			_fail("existing grade tracker draw execution must render scaled level %d combo requirement x%d (got '%s', want '%s')" % [level, combo_requirement, rendered_prompt, expected_prompt])
			return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("scaled grade tracker prompt must not add persistent UI controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("scaled grade tracker prompt must keep existing HUD residency unchanged")
		return false
	root_node.call("reset_game", 1, "scaled_grade_tracker_prompt_smoke_cleanup")
	return true


func _test_customer_completion_contract(root_node: Node) -> bool:
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var profile_signatures: Array[String] = []
	for level in range(1, 6):
		root_node.call("reset_game", level, "customer_profile_smoke")
		var profile: Dictionary = root_node.call("get_customer_profile_for_test")
		var signature := "%s|%s|%s" % [profile["face_hex"], profile["accent_hex"], profile["accessory"]]
		if not profile_signatures.has(signature):
			profile_signatures.append(signature)
	if profile_signatures.size() < 3:
		_fail("the first car rotation should expose at least three customer profiles")
		return false
	root_node.call("reset_game", 3, "customer_profile_repeat_a")
	var repeated_profile: Dictionary = root_node.call("get_customer_profile_for_test")
	root_node.call("reset_game", 4, "customer_profile_separator")
	root_node.call("reset_game", 3, "customer_profile_repeat_b")
	if root_node.call("get_customer_profile_for_test") != repeated_profile:
		_fail("replaying the same level should restore the same customer")
		return false
	var one_star := float(root_node.call("get_customer_reaction_strength_for_test", 1))
	var two_stars := float(root_node.call("get_customer_reaction_strength_for_test", 2))
	var three_stars := float(root_node.call("get_customer_reaction_strength_for_test", 3))
	if not (one_star < two_stars and two_stars < three_stars):
		_fail("completion customer reaction should grow with earned stars")
		return false
	var completion_panel: Rect2 = root_node.call("_completion_panel_rect")
	var reaction_rect: Rect2 = root_node.call("get_completion_customer_rect_for_test")
	if not completion_panel.encloses(reaction_rect):
		_fail("customer reaction must stay inside the completion panel")
		return false
	root_node.set("completed", true)
	root_node.set("_customer_completion_time", float(Time.get_ticks_msec()) / 1000.0)
	for stars in [1, 2, 3]:
		root_node.set("earned_stars", stars)
		root_node.queue_redraw()
		await process_frame
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("_draw_customer_patience()") or not main_source.contains("_draw_completion_customer_reaction(panel, time_now)") or not main_source.contains("_customer_cheer_text"):
		_fail("gameplay customer mood and cheer paths must remain wired beside completion reaction")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children:
		_fail("completion customer reaction must not add persistent HUD controls")
		return false
	if root_node.call("_get_status_rect") != baseline_hud_rects["status"] or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("completion customer reaction must not change gameplay HUD residency")
		return false
	root_node.call("reset_game", 1, "customer_completion_smoke_cleanup")
	return true


func _test_compact_city_dirt_profile(root_node: Node) -> bool:
	root_node.call("reset_game", 6, "compact_city_profile_smoke")
	if String(root_node.call("get_car_type_for_test")) != "compact":
		_fail("level 6 should exercise the full-catalog compact city profile")
		return false
	var city_bias_count := 0
	for kind in ["dust", "leaf", "poop", "road_grime", "sap"]:
		city_bias_count += int(root_node.call("get_patch_count_by_kind_for_test", kind))
	var secondary_count := 0
	for kind in ["mud", "oil", "bug"]:
		secondary_count += int(root_node.call("get_patch_count_by_kind_for_test", kind))
	if city_bias_count <= secondary_count:
		_fail("compact city profile must spawn more themed dirt than secondary dirt")
		return false
	for kind in ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime", "sap"]:
		if int(root_node.call("get_patch_count_by_kind_for_test", kind)) <= 0:
			_fail("compact city profile omitted dirt kind: " + kind)
			return false
	var first_sequence: Array[String] = root_node.call("get_spawned_dirt_kinds_for_test")
	root_node.call("reset_game", 6, "compact_city_profile_repeat")
	if root_node.call("get_spawned_dirt_kinds_for_test") != first_sequence:
		_fail("compact city profile must preserve deterministic level spawning")
		return false
	root_node.call("reset_game", 1, "compact_city_profile_cleanup")
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


func _test_surface_droplet_contract(root_node: Node) -> bool:
	root_node.call("reset_game", 1, "surface_droplet_smoke")
	var baseline_control_children := root_node.find_children("*", "Control", true, false).size()
	var baseline_hud_rects := {
		"status": root_node.call("_get_status_rect"),
		"grade": root_node.call("_get_grade_rect"),
		"customer": root_node.call("_get_customer_rect"),
		"mission": root_node.call("_get_daily_mission_rect"),
	}
	var car_surface_point: Vector2 = root_node.call("_gameplay_point", Vector2(195.0, 520.0))
	for tool_id in ["air", "soap", "sponge"]:
		root_node.set("selected_tool", tool_id)
		root_node.call("_apply_tool_at", car_surface_point, 0.12)
	if int(root_node.call("get_surface_droplet_count_for_test")) != 0:
		_fail("air, soap, and sponge must not create persistent surface droplets")
		return false

	root_node.set("selected_tool", "water")
	root_node.call("_apply_tool_at", car_surface_point, 0.12)
	if int(root_node.call("get_surface_droplet_count_for_test")) <= 0:
		_fail("water drag on the car body must create a persistent surface droplet")
		return false
	if not bool(root_node.call("are_surface_droplets_inside_car_for_test")):
		_fail("surface droplets must stay inside the active car silhouette")
		return false
	root_node.queue_redraw()
	await process_frame

	var droplet_cap := int(root_node.call("get_surface_droplet_cap_for_test"))
	for index in range(droplet_cap * 2):
		if not bool(root_node.call("spawn_surface_droplet_for_test", "water", car_surface_point)):
			_fail("water surface droplet fixture failed inside the car silhouette")
			return false
	if int(root_node.call("get_surface_droplet_count_for_test")) != droplet_cap:
		_fail("surface droplets must evict oldest entries at the explicit cap")
		return false
	if not bool(root_node.call("are_surface_droplets_inside_car_for_test")):
		_fail("capped surface droplets must all remain inside the car silhouette")
		return false
	root_node.queue_redraw()
	await process_frame

	var max_lifetime := float(root_node.call("get_surface_droplet_max_lifetime_for_test"))
	root_node.call("update_surface_droplets_for_test", max_lifetime + 0.01)
	if int(root_node.call("get_surface_droplet_count_for_test")) != 0:
		_fail("released surface droplets must disappear within four seconds")
		return false
	if root_node.find_children("*", "Control", true, false).size() != baseline_control_children \
			or root_node.call("_get_status_rect") != baseline_hud_rects["status"] \
			or root_node.call("_get_grade_rect") != baseline_hud_rects["grade"] \
			or root_node.call("_get_customer_rect") != baseline_hud_rects["customer"] \
			or root_node.call("_get_daily_mission_rect") != baseline_hud_rects["mission"]:
		_fail("surface droplets must stay in the car render layer without changing HUD residency")
		return false
	root_node.call("reset_game", 1, "surface_droplet_smoke_cleanup")
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
	var car_start := source.find("func _draw_car(")
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
	var car_start := source.find("func _draw_car(")
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


func _test_sap_dirt_contract(root_node: Node) -> bool:
	var persistent_hud_before := _capture_persistent_hud_state(root_node)
	var sap_index: int = root_node.call("spawn_patch_for_test", "sap")
	if sap_index < 0:
		_fail("sap test patch failed to spawn")
		return false
	var health_before: float = root_node.call("get_patch_health_for_test", sap_index)
	if String(root_node.call("get_recommended_tool_for_test", sap_index)) != "soap" \
			or not bool(root_node.call("is_tool_misapplied_for_test", "water", sap_index)) \
			or not bool(root_node.call("is_tool_misapplied_for_test", "sponge", sap_index)):
		_fail("dry sap must coach soap before sponge and reject water")
		return false
	var health_after_water: float = root_node.call("apply_tool_to_patch_for_test", "water", sap_index, 1.0)
	if absf(health_after_water - health_before) > 0.0001 \
			or float(root_node.call("get_patch_soap_for_test", sap_index)) > 0.0:
		_fail("water alone must leave sap health and preparation unchanged")
		return false
	root_node.call("apply_tool_to_patch_for_test", "soap", sap_index, 0.5)
	if float(root_node.call("get_patch_soap_for_test", sap_index)) <= 0.25 \
			or String(root_node.call("get_patch_state_for_test", sap_index)) != "loosened" \
			or String(root_node.call("get_recommended_tool_for_test", sap_index)) != "sponge" \
			or bool(root_node.call("is_tool_misapplied_for_test", "sponge", sap_index)):
		_fail("soap must soften sap and switch coaching to sponge")
		return false
	var health_before_sponge: float = root_node.call("get_patch_health_for_test", sap_index)
	var health_after_sponge: float = root_node.call("apply_tool_to_patch_for_test", "sponge", sap_index, 0.5)
	if health_after_sponge >= health_before_sponge:
		_fail("sponge must clean softened sap")
		return false

	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var dirt_start := source.find("func _draw_dirt() -> void:")
	var dirt_end := source.find("\nfunc ", dirt_start + 1)
	var sap_start := source.find("func _draw_sap_patch(")
	var sap_end := source.find("\nfunc ", sap_start + 1)
	if dirt_start < 0 or dirt_end < 0 or sap_start < 0 or sap_end < 0:
		_fail("sap draw functions must remain discoverable")
		return false
	var dirt_body := source.substr(dirt_start, dirt_end - dirt_start)
	var sap_body := source.substr(sap_start, sap_end - sap_start)
	if not dirt_body.contains("_draw_sap_patch(center, patch.radius, strength, patch.seed_offset)") \
			or not sap_body.contains("draw_circle") \
			or not sap_body.contains("draw_line") \
			or not sap_body.contains("draw_arc"):
		_fail("sap must dispatch through the existing dirt pass with a distinct resin renderer")
		return false
	if _capture_persistent_hud_state(root_node) != persistent_hud_before:
		_fail("sap must not add a persistent HUD control or move gameplay HUD residency")
		return false
	root_node.call("reset_game", 1, "sap_contract_cleanup")
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
