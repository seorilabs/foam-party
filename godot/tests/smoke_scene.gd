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
	for pause_index in range(5):
		if not pause_panel.encloses(root_node.call("_pause_button_rect", pause_index)):
			_fail("pause/settings sheet must contain all five actions")
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

	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	var pause_labels_ko: Array = root_node.call("_pause_action_labels")
	if root_node.call("_pause_title_text") != "일시정지 · 설정" or String(pause_labels_ko[2]) != "세차 가이드":
		_fail("pause title and guide action must use Korean i18n keys")
		return
	TranslationServer.set_locale("en")
	var pause_labels_en: Array = root_node.call("_pause_action_labels")
	if root_node.call("_pause_title_text") != "Paused · Settings" or String(pause_labels_en[2]) != "Wash Guide":
		_fail("pause title and guide action must use English i18n keys")
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

	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 1).get_center())
	if bool(root_node.get("sound_enabled")) or not bool(root_node.get("show_pause")):
		_fail("sound toggle must work only inside pause/settings")
		return
	root_node.call("_handle_tap", root_node.call("_pause_button_rect", 2).get_center())
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

	print("Foam Party smoke passed: patches=%d progress=%.3f best_combo=%d stars=%d" % [patch_count, progress_after, best_combo, stars])
	get_root().remove_child(root_node)
	root_node.free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
