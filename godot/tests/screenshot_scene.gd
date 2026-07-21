extends SceneTree

## Development screenshot capture script.
## xvfb-run -a godot --path godot --script res://tests/screenshot_scene.gd --audio-driver Dummy
## Saves title, tool-specific wash scenes, and completion PNGs to FOAM_SHOT_DIR (default /tmp).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := OS.get_environment("FOAM_SHOT_DIR")
	if out_dir == "":
		out_dir = "/tmp" if DirAccess.dir_exists_absolute("/tmp") else OS.get_user_data_dir()
	elif out_dir.is_relative_path():
		var cwd := DirAccess.open(".")
		var base_dir := cwd.get_current_dir() if cwd != null else OS.get_user_data_dir()
		out_dir = base_dir.path_join(out_dir)
	if not DirAccess.dir_exists_absolute(out_dir):
		var make_error := DirAccess.make_dir_recursive_absolute(out_dir)
		if make_error != OK:
			push_error("failed to create output dir: " + out_dir)
			quit(1)
			return

	OS.set_environment("FOAM_DISABLE_SAVE", "1")
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var node := scene.instantiate()
	get_root().add_child(node)

	get_root().mode = Window.MODE_WINDOWED
	get_root().size = Vector2i(390, 844)

	await _settle(20)
	if not await _capture(out_dir.path_join("shot_title.png")):
		quit(1)
		return
	node.set("skin_water", "coral")
	node.set("skin_air", "violet")
	node.set("skin_soap", "pink")
	node.set("skin_sponge", "lime")
	node.set("selected_car_paint", "paint_violet")
	node.call("_set_car_palette")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_title_hero_customized.png")):
		quit(1)
		return
	node.set("skin_water", "classic")
	node.set("skin_air", "classic")
	node.set("skin_soap", "classic")
	node.set("skin_sponge", "classic")
	node.set("selected_car_paint", "")
	node.call("_set_car_palette")
	node.set("daily_mission_type", "road_grime")
	node.set("daily_mission_target", 8)
	node.set("daily_mission_reward", 85)
	node.set("daily_mission_progress", 3)
	node.set("daily_mission_claimed", false)
	await _settle(2)
	if not await _capture(out_dir.path_join("shot_daily_mission_reward.png")):
		quit(1)
		return
	node.call("configure_daily_mission_for_test", "combo")
	await _settle(2)
	if not await _capture(out_dir.path_join("shot_daily_mission_combo.png")):
		quit(1)
		return
	node.call("_generate_daily_mission", node.call("_today_string"))
	node.set("level_index", 5)
	node.set("best_times", {1: 92.0, 2: 84.0, 3: 78.0, 5: 70.0})
	node.set("best_stars", {1: 2, 2: 3, 3: 1, 5: 3})
	node.set("show_stage_panel", true)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_stage_select.png")):
		quit(1)
		return
	node.set("show_stage_panel", false)
	node.call("set_achievement_state_for_test", {
		"washes_completed": 10,
		"dirt_removed": 62,
		"leaf_removed": 18,
		"stars_collected": 30,
		"combo_peak": 7,
	}, {"wash_rookie": true, "star_collector": true})
	node.set("show_achievement_panel", true)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_achievement_panel.png")):
		quit(1)
		return
	node.set("show_achievement_panel", false)
	node.call("set_achievement_state_for_test", {}, {})
	node.set("show_upgrade_panel", true)
	node.set("coins", 0)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_upgrade_locked_cues.png")):
		quit(1)
		return
	node.set("show_upgrade_panel", false)
	node.set("show_skin_panel", true)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_car_customization.png")):
		quit(1)
		return
	node.set("owned_skins", {
		"water:classic": true,
		"air:classic": true,
		"soap:classic": true,
		"sponge:classic": true,
		"water:gold": true,
	})
	node.set("skin_water", "gold")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_skin_water_gold_owned.png")):
		quit(1)
		return
	node.set("_skin_panel_tab", 1)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_skin_air_gold_locked.png")):
		quit(1)
		return
	node.set("_skin_panel_tab", 4)
	node.set("coins", 500)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_car_paint_customization.png")):
		quit(1)
		return
	node.set("show_skin_panel", false)
	node.set("selected_car_paint", "paint_violet")
	node.call("_set_car_palette")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_car_paint_applied_title.png")):
		quit(1)
		return
	node.set("selected_car_paint", "")
	node.call("_set_car_palette")
	node.call("_select_license_plate", "BUBBLE")
	node.set("level_index", 1)
	node.set("best_times", {})
	node.set("best_stars", {})

	node.call("start_game")
	await _settle(5)
	if not await _capture(out_dir.path_join("shot_tutorial.png")):
		quit(1)
		return
	node.call("_dismiss_tutorial")
	node.set("coins", 0)
	node.call("_handle_tap", node.call("_get_booster_rect").get_center())
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_booster_picker_locked.png")):
		quit(1)
		return
	node.call("_handle_tap", node.call("_booster_close_rect", node.call("_booster_panel_rect")).get_center())
	node.set("coins", 120)
	node.call("_handle_tap", node.call("_get_booster_rect").get_center())
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_booster_picker.png")):
		quit(1)
		return
	node.call("_handle_tap", node.call("_booster_card_rect", node.call("_booster_panel_rect"), 1).get_center())
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_water_boost_active.png")):
		quit(1)
		return
	node.call("reset_game", 1, "booster_screenshot_cleanup")
	node.set("coins", 120)

	await _settle(10)
	if not await _capture(out_dir.path_join("shot_default.png")):
		quit(1)
		return
	node.set("level_time", 130.0)
	for dirty_patch in node.get("dirt_patches"):
		dirty_patch.set("health", dirty_patch.get("max_health"))
	node.call("_update_clean_progress")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_patience_dirty_late.png")):
		quit(1)
		return
	for nearly_clean_patch in node.get("dirt_patches"):
		nearly_clean_patch.set("health", float(nearly_clean_patch.get("max_health")) * 0.1)
	node.call("_update_clean_progress")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_patience_nearly_clean_late.png")):
		quit(1)
		return
	node.call("reset_game", 4, "scaled_combo_gate_screenshot")
	node.set("level_time", 30.0)
	node.set("best_combo", 4)
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_scaled_combo_gate_level4.png")):
		quit(1)
		return
	node.call("reset_game", 1, "balance_screenshot_cleanup")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_wheel_dirt.png")):
		quit(1)
		return
	for wheel_dirt_index in node.call("get_wheel_dirt_indices_for_test"):
		node.get("dirt_patches")[wheel_dirt_index].set("health", 0.0)
	node.call("_update_clean_progress")
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_wheels_clean.png")):
		quit(1)
		return
	node.call("reset_game", 1, "wheel_dirt_screenshot_cleanup")
	await _settle(3)
	if not bool(node.call("set_patch_gold_spot_for_test", 0, true)):
		push_error("gold spot screenshot setup failed")
		quit(1)
		return
	await _settle(3)
	if not await _capture(out_dir.path_join("shot_gold_spot.png")):
		quit(1)
		return
	node.call("_mark_patch_removed", node.get("dirt_patches")[0])
	if not await _capture(out_dir.path_join("shot_gold_spot_reward.png")):
		quit(1)
		return
	node.call("_begin_car_entry", true)
	node.set("_car_transition_elapsed", 0.20)
	if not await _capture(out_dir.path_join("shot_car_entry_transition.png")):
		quit(1)
		return
	node.set("_car_transition_phase", "idle")
	node.set("_car_transition_elapsed", 0.0)
	node.call("apply_body_foam_tool_for_test", "soap", 1.35)
	if not await _capture(out_dir.path_join("shot_body_foam_partial.png")):
		quit(1)
		return
	node.call("reset_game", 1, "foam_bomb_screenshot")
	node.get("particles").clear()
	if not bool(node.call("apply_foam_bomb", true)):
		push_error("foam bomb screenshot setup failed")
		quit(1)
		return
	if not await _capture(out_dir.path_join("shot_foam_bomb_burst.png")):
		quit(1)
		return
	node.get("particles").clear()
	if not await _capture(out_dir.path_join("shot_body_foam_full.png")):
		quit(1)
		return
	node.call("apply_body_foam_tool_for_test", "water", 0.9)
	await _settle(2)
	if not await _capture(out_dir.path_join("shot_body_foam_rinse.png")):
		quit(1)
		return
	node.call("reset_game", 1, "body_foam_screenshot_cleanup")
	_set_clean_progress(node, 0.0)
	if not await _capture(out_dir.path_join("shot_clean_shine_0.png")):
		quit(1)
		return
	_set_clean_progress(node, 0.5)
	if not await _capture(out_dir.path_join("shot_clean_shine_50.png")):
		quit(1)
		return
	_set_clean_progress(node, 0.98)
	if not await _capture(out_dir.path_join("shot_clean_shine_98.png")):
		quit(1)
		return
	if not _isolate_stalled_dirt_patch(node):
		push_error("stalled dirt screenshot setup failed")
		quit(1)
		return
	node.call("simulate_stalled_dirt_highlight_for_test", node.call("get_clean_progress_for_test"), 3.0)
	if not await _capture(out_dir.path_join("shot_stalled_dirt_highlight.png")):
		quit(1)
		return
	node.call("reset_game", 1, "clean_shine_screenshot_cleanup")
	var oil_patch: Variant = _isolate_oil_patch(node, 1.0)
	if oil_patch == null:
		push_error("oil sheen screenshot setup failed")
		quit(1)
		return
	if not await _capture(out_dir.path_join("shot_oil_sheen_full.png")):
		quit(1)
		return
	oil_patch.set("health", float(oil_patch.get("max_health")) * 0.35)
	node.call("_update_clean_progress")
	node.queue_redraw()
	if not await _capture(out_dir.path_join("shot_oil_sheen_faded.png")):
		quit(1)
		return
	node.call("reset_game", 1, "oil_sheen_screenshot_cleanup")
	var sap_patch: Variant = _isolate_sap_patch(node)
	if sap_patch == null:
		push_error("sap screenshot setup failed")
		quit(1)
		return
	if not await _capture(out_dir.path_join("shot_sap_dry.png")):
		quit(1)
		return
	sap_patch.set("soap", 0.75)
	sap_patch.set("looseness", 0.5)
	sap_patch.set("state", "loosened")
	node.queue_redraw()
	await _settle(2)
	if not await _capture(out_dir.path_join("shot_sap_soaped.png")):
		quit(1)
		return
	node.call("reset_game", 1, "sap_screenshot_cleanup")
	node.call("_on_back_pressed")
	node.call("_select_language", "ko")
	await _settle(5)
	if not await _capture(out_dir.path_join("shot_pause.png")):
		quit(1)
		return
	node.call("_select_language", "en")
	if not await _capture(out_dir.path_join("shot_pause_language_en.png")):
		quit(1)
		return
	node.call("_select_language", "ko")
	node.call("_on_back_pressed")

	var wash_points := {
		"water": Vector2(140.0, 510.0),
		"air": Vector2(200.0, 380.0),
		"soap": Vector2(250.0, 590.0),
		"sponge": Vector2(195.0, 520.0),
	}
	for tool_id in ["water", "air", "soap", "sponge"]:
		node.set("selected_tool", tool_id)
		node.set("pointer_position", wash_points[tool_id])
		node.set("is_washing", true)
		await _settle(25)
		var tool_saved: bool = await _capture(out_dir.path_join("shot_%s.png" % tool_id))
		node.set("is_washing", false)
		node.get("particles").clear()
		if not tool_saved:
			quit(1)
			return

	node.set("selected_tool", "water")
	node.set("pointer_position", Vector2(195.0, 520.0))
	node.get("particles").clear()
	node.set("is_washing", true)
	await _settle(4)
	if not await _capture(out_dir.path_join("shot_water_impact.png")):
		quit(1)
		return
	node.set("is_washing", false)
	node.get("particles").clear()
	node.set("combo_count", 1)
	node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	if not await _capture(out_dir.path_join("shot_water_combo_low.png")):
		quit(1)
		return
	node.get("particles").clear()
	node.set("combo_count", 9)
	node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	if not await _capture(out_dir.path_join("shot_water_combo_hot.png")):
		quit(1)
		return
	node.set("combo_count", 0)
	node.get("particles").clear()

	node.set("selected_tool", "water")
	node.set("pointer_position", Vector2(195.0, 520.0))
	for patch in node.get("dirt_patches"):
		if patch.get("position").distance_to(Vector2(195.0, 520.0)) < 120.0:
			patch.set("health", 1.0)
	node.set("is_washing", true)
	await _settle(10)
	var combo_saved: bool = await _capture(out_dir.path_join("shot_combo.png"))
	node.set("is_washing", false)
	node.get("particles").clear()
	if not combo_saved:
		quit(1)
		return
	node.set("combo_count", 4)
	node.set("combo_timer", 2.5)
	node.set("combo_protection_available", true)
	node.set("combo_grace_active", false)
	await _settle(1)
	if not await _capture(out_dir.path_join("shot_combo_protection.png")):
		quit(1)
		return
	node.set("combo_timer", 1.0)
	node.set("combo_protection_available", false)
	node.set("combo_grace_active", true)
	node.set("_combo_grace_flash_time", float(Time.get_ticks_msec()) / 1000.0)
	await _settle(1)
	if not await _capture(out_dir.path_join("shot_combo_grace.png")):
		quit(1)
		return
	node.set("combo_count", 0)
	node.set("combo_timer", 0.0)
	node.set("combo_grace_active", false)

	node.call("reset_game", 1, "perfect_wash_screenshot")
	node.set("level_time", 30.0)
	node.set("best_combo", 4)
	for patch in node.get("dirt_patches"):
		patch.set("health", 0.0)
	await _settle(12)
	if not await _capture(out_dir.path_join("shot_complete.png")):
		quit(1)
		return
	for stars in [1, 2, 3]:
		node.set("earned_stars", stars)
		node.set("_customer_completion_time", float(Time.get_ticks_msec()) / 1000.0)
		await _settle(1)
		if not await _capture(out_dir.path_join("shot_customer_reaction_%d_star.png" % stars)):
			quit(1)
			return

	node.call("reset_game", node.get("level_index"))
	node.get("best_times")[int(node.get("level_index"))] = 30.0
	node.set("level_time", 95.0)
	node.set("level_mistakes", 1)
	for patch in node.get("dirt_patches"):
		patch.set("health", 0.0)
	await _settle(12)
	if not await _capture(out_dir.path_join("shot_complete_record.png")):
		quit(1)
		return

	for level in [2, 3, 4, 5]:
		node.call("reset_game", level)
		await _settle(10)
		var car_name: String = node.call("get_car_type_for_test")
		if not await _capture(out_dir.path_join("shot_car_%s.png" % car_name)):
			quit(1)
			return

	for level in [3, 6, 10]:
		node.call("reset_game", level, "dirt_density_screenshot")
		await _settle(10)
		if not await _capture(out_dir.path_join("shot_density_level_%d.png" % level)):
			quit(1)
			return

	quit(0)


func _settle(frames: int) -> void:
	for index in range(frames):
		await process_frame


func _set_clean_progress(node: Node, progress: float) -> void:
	var remaining := 1.0 - clampf(progress, 0.0, 1.0)
	for raw_patch in node.get("dirt_patches"):
		raw_patch.set("health", float(raw_patch.get("max_health")) * remaining)
	node.call("_update_clean_progress")
	node.set("_progress_milestone_hit", 3)
	node.set("_progress_milestone_time", -1.0)


func _isolate_oil_patch(node: Node, strength: float) -> Variant:
	node.call("reset_game", 2, "oil_sheen_screenshot")
	for raw_patch in node.get("dirt_patches"):
		raw_patch.set("state", "removed")
		raw_patch.set("health", 0.0)
	var oil_index: int = node.call("spawn_patch_for_test", "oil")
	if oil_index < 0:
		return null
	var oil_patch: Variant = node.get("dirt_patches")[oil_index]
	oil_patch.set("radius", 34.0)
	oil_patch.set("seed_offset", 0.73)
	oil_patch.set("health", float(oil_patch.get("max_health")) * clampf(strength, 0.0, 1.0))
	node.set("initial_dirt_total", float(oil_patch.get("max_health")))
	node.set("completed", false)
	node.call("_update_clean_progress")
	node.queue_redraw()
	return oil_patch


func _isolate_sap_patch(node: Node) -> Variant:
	node.call("reset_game", 6, "sap_screenshot")
	for raw_patch in node.get("dirt_patches"):
		raw_patch.set("state", "removed")
		raw_patch.set("health", 0.0)
	var sap_index: int = node.call("spawn_patch_for_test", "sap")
	if sap_index < 0:
		return null
	var sap_patch: Variant = node.get("dirt_patches")[sap_index]
	sap_patch.set("radius", 34.0)
	sap_patch.set("seed_offset", 1.37)
	node.set("initial_dirt_total", float(sap_patch.get("max_health")))
	node.set("completed", false)
	node.call("_update_clean_progress")
	node.queue_redraw()
	return sap_patch


func _isolate_stalled_dirt_patch(node: Node) -> bool:
	var target_patch: Variant = null
	for raw_patch in node.get("dirt_patches"):
		if target_patch == null or float(raw_patch.get("max_health")) > float(target_patch.get("max_health")):
			target_patch = raw_patch
	if target_patch == null:
		return false
	for raw_patch in node.get("dirt_patches"):
		if raw_patch == target_patch:
			raw_patch.set("state", "stuck")
			raw_patch.set("health", float(raw_patch.get("max_health")) * 0.08)
		else:
			raw_patch.set("state", "removed")
			raw_patch.set("health", 0.0)
	# A synthetic total keeps the faint isolated patch at exactly 94% overall
	# progress, matching the low-alpha last-sliver manual QA scenario.
	node.set("initial_dirt_total", float(target_patch.get("health")) / 0.06)
	node.set("completed", false)
	node.call("_update_clean_progress")
	node.queue_redraw()
	return absf(float(node.call("get_clean_progress_for_test")) - 0.94) < 0.001


func _capture(path: String) -> bool:
	await process_frame
	var texture := get_root().get_texture()
	if texture == null:
		push_error("viewport texture unavailable for " + path)
		return false
	var image := texture.get_image()
	if image == null:
		push_error("viewport image unavailable for " + path)
		return false
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("failed to save " + path)
		return false
	print("saved ", path)
	return true
