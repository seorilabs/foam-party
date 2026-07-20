extends SceneTree

# Pure unit tests for packages/product-core rules, loaded through the res://core
# symlink. Mirrors the known-value expectations that smoke_scene.gd asserts on
# the live Main node, but exercises the extracted functions in isolation.
# On any failure: print "CORE TEST FAIL: ..." and quit(1). Otherwise quit(0).

func _initialize() -> void:
	_run_core_tests.call_deferred()


func _run_core_tests() -> void:
	var Scoring: GDScript = load("res://core/use_cases/scoring.gd")
	var Economy: GDScript = load("res://core/use_cases/economy.gd")
	var Coaching: GDScript = load("res://core/use_cases/coaching.gd")
	var DailyMission: GDScript = load("res://core/use_cases/daily_mission.gd")
	var BestTime: GDScript = load("res://core/use_cases/best_time.gd")
	var StageSelection: GDScript = load("res://core/use_cases/stage_selection.gd")
	var DirtSpawnPlan: GDScript = load("res://core/use_cases/dirt_spawn_plan.gd")
	var GoldSpot: GDScript = load("res://core/use_cases/gold_spot.gd")
	var LicensePlate: GDScript = load("res://core/use_cases/license_plate.gd")
	var DirtPatch: GDScript = load("res://core/domain/dirt_patch.gd")
	var GameConfig: GDScript = load("res://core/domain/game_config.gd")
	var I18n: GDScript = load("res://scripts/services/i18n.gd")
	if Scoring == null or Economy == null or Coaching == null or DailyMission == null or BestTime == null or StageSelection == null or DirtSpawnPlan == null or GoldSpot == null or LicensePlate == null or DirtPatch == null or GameConfig == null or I18n == null:
		_fail("core scripts failed to load through res://core symlink")
		return
	if not _test_car_roster_and_saved_level_mapping(GameConfig):
		return
	if not _test_new_car_localized_labels(I18n):
		return
	if not _test_language_resolution(I18n):
		return
	if not _test_dirt_spawn_plan(DirtSpawnPlan):
		return
	if not _test_gold_spot_rules(GoldSpot, GameConfig):
		return
	if not _test_license_plate_rules(LicensePlate):
		return

	# --- Scoring: star boundaries (matches smoke_scene 3/2/1-star cases) ---
	if int(Scoring.star_time_threshold(3, 1)) != 75:
		_fail("3-star threshold at level 1 should be 75s")
		return
	if int(Scoring.calc_stars(60.0, 5, 1)) != 3:
		_fail("fast clear with combo should be 3 stars")
		return
	if int(Scoring.calc_stars(60.0, 2, 1)) != 2:
		_fail("missing the combo gate should be 2 stars")
		return
	if int(Scoring.calc_stars(200.0, 10, 1)) != 1:
		_fail("slow clear should be 1 star")
		return

	# --- Scoring: live grade tracker slots + countdown ---
	if String(Scoring.grade_slot_state(2, 60.0, 5, 1, "earned", "target", "locked")) != "earned":
		_fail("fast clear with combo should earn the third star slot")
		return
	if String(Scoring.grade_slot_state(2, 60.0, 2, 1, "earned", "target", "locked")) != "target":
		_fail("missing combo gate should mark third star as target")
		return
	if String(Scoring.grade_slot_state(2, 100.0, 5, 1, "earned", "target", "locked")) != "locked":
		_fail("slow-but-not-slowest clear should lock the third star")
		return
	if String(Scoring.grade_slot_state(1, 200.0, 5, 1, "earned", "target", "locked")) != "locked":
		_fail("very slow clear should lock the second star")
		return
	if absf(float(Scoring.grade_time_to_downgrade(60.0, 1)) - 15.0) > 0.001:
		_fail("countdown should report 15s before the third star drops")
		return
	if absf(float(Scoring.grade_time_to_downgrade(100.0, 1)) - 40.0) > 0.001:
		_fail("countdown should track the two-star threshold at 40s")
		return
	if float(Scoring.grade_time_to_downgrade(200.0, 1)) >= 0.0:
		_fail("no countdown should remain once only the floor star is left")
		return
	if int(Scoring.grade_at_risk_slot(60.0, 1)) != 2:
		_fail("third star should be at risk while still fast")
		return
	if int(Scoring.grade_at_risk_slot(200.0, 1)) != -1:
		_fail("no slot should be at risk once only the floor star is left")
		return

	# --- Economy: coin rewards, upgrade costs, purchase judgement ---
	if int(Economy.calc_coin_reward(1, 0)) != 24:
		_fail("1-star clear without combo should pay 24 coins")
		return
	if int(Economy.calc_coin_reward(1, 10)) != 44:
		_fail("1-star clear with max combo bonus should pay 44 coins")
		return
	if int(Economy.calc_coin_reward(3, 5)) != 50:
		_fail("3-star clear should pay 50 coins")
		return
	if int(Economy.calc_coin_reward(3, 10)) != 60 or int(Economy.calc_coin_reward(3, 99)) != 60:
		_fail("3-star reward should cap at 60 coins after combo 10")
		return
	if int(Economy.calc_level_milestone_bonus(5)) != 75:
		_fail("level 5 milestone bonus should be 75")
		return
	if int(Economy.calc_level_milestone_bonus(3)) != 0:
		_fail("non-milestone level should give no bonus")
		return
	if int(Economy.upgrade_cost(0, 0)) != 90 or int(Economy.upgrade_cost(0, 2)) != 320:
		_fail("upgrade costs should read from the config table")
		return
	if not bool(Economy.can_buy_upgrade(0, 0, 90)):
		_fail("90 coins should afford the first upgrade tier")
		return
	if bool(Economy.can_buy_upgrade(0, 0, 89)):
		_fail("89 coins should not afford the first upgrade tier")
		return
	if bool(Economy.can_buy_upgrade(0, 3, 9999)):
		_fail("a maxed upgrade should never be buyable")
		return
	if absf(float(Economy.upgrade_mult(0)) - 1.0) > 0.0001 or absf(float(Economy.upgrade_mult(3)) - 2.0) > 0.0001:
		_fail("upgrade multipliers should map level to the config table")
		return

	# --- Economy: skin purchase intents ---
	var SkinCatalog: GDScript = load("res://core/domain/skin_catalog.gd")
	var catalog: Dictionary = SkinCatalog.catalog()
	var owned: Dictionary = {"classic": true}
	var buy_intent: Dictionary = Economy.resolve_skin_purchase(catalog, "water", 1, owned, 200)
	if String(buy_intent["action"]) != "buy" or int(buy_intent["cost"]) != 80 or String(buy_intent["id"]) != "coral":
		_fail("affording an unowned skin should yield a buy intent")
		return
	var deny_intent: Dictionary = Economy.resolve_skin_purchase(catalog, "water", 1, owned, 10)
	if String(deny_intent["action"]) != "deny":
		_fail("insufficient coins should deny the skin purchase")
		return
	var select_intent: Dictionary = Economy.resolve_skin_purchase(catalog, "water", 0, owned, 0)
	if String(select_intent["action"]) != "select" or String(select_intent["id"]) != "classic":
		_fail("an owned skin should yield a select intent")
		return

	# --- Coaching: recommendations and misapplied flags on real patches ---
	var leaf = DirtPatch.new("leaf", Vector2.ZERO, 18.0, 100.0, 0.5)
	if String(Coaching.recommended_tool(leaf)) != "air":
		_fail("leaf should recommend air")
		return
	if not bool(Coaching.tool_misapplied("water", leaf)):
		_fail("water on leaf should be flagged")
		return
	if bool(Coaching.tool_misapplied("air", leaf)):
		_fail("air on leaf should not be flagged")
		return
	var oil = DirtPatch.new("oil", Vector2.ZERO, 18.0, 100.0, 0.5)
	if String(Coaching.recommended_tool(oil)) != "soap":
		_fail("dry oil should recommend soap")
		return
	oil.soap = 0.5
	if String(Coaching.recommended_tool(oil)) != "sponge":
		_fail("soaped oil should recommend sponge")
		return
	var road_grime = DirtPatch.new("road_grime", Vector2.ZERO, 18.0, 100.0, 0.5)
	if String(Coaching.recommended_tool(road_grime)) != "water":
		_fail("dry road grime should recommend a pre-rinse")
		return
	if not bool(Coaching.tool_misapplied("sponge", road_grime)):
		_fail("dry road grime should reject direct sponge scrubbing")
		return
	road_grime.wetness = 0.4
	if String(Coaching.recommended_tool(road_grime)) != "sponge":
		_fail("pre-rinsed road grime should recommend sponge")
		return
	if not bool(Coaching.is_light_dirt("leaf")) or bool(Coaching.is_light_dirt("oil")):
		_fail("light-dirt classification is wrong")
		return
	if absf(float(Coaching.tool_radius("air")) - 68.0) > 0.001 or absf(float(Coaching.tool_radius("sponge")) - 38.0) > 0.001:
		_fail("tool radii should match the tuning table")
		return
	if String(Coaching.active_hint_tool(null, true)) != "":
		_fail("a null hint patch should report no active hint")
		return

	# --- Daily mission: deterministic in the date string ---
	var mission: Dictionary = DailyMission.mission_for("2026-07-06")
	var mission_again: Dictionary = DailyMission.mission_for("2026-07-06")
	if mission != mission_again:
		_fail("daily mission must be deterministic for a fixed date")
		return
	if String(mission["type"]) != "dust" or int(mission["target"]) != 20 or String(mission["label"]) != "먼지 20개 제거하기":
		_fail("daily mission for 2026-07-06 changed: " + str(mission))
		return

	# --- Best time records ---
	if not bool(BestTime.is_new_record(0.0, 90.0)):
		_fail("first clear should be a new record")
		return
	if bool(BestTime.is_new_record(90.0, 120.0)):
		_fail("a slower clear should not be a new record")
		return
	if not bool(BestTime.is_new_record(90.0, 70.0)):
		_fail("a faster clear should be a new record")
		return
	if absf(float(BestTime.best_time({5: 90.0}, 5)) - 90.0) > 0.001:
		_fail("stored best time should be returned")
		return
	if absf(float(BestTime.best_time({}, 3)) - 0.0) > 0.001:
		_fail("missing level should report zero best time")
		return

	# --- Stage selection projection ---
	var first_page: Array[Dictionary] = StageSelection.cards(1, {1: 82.5}, {1: 2}, 0)
	if first_page.size() != 6 or not bool(first_page[0]["unlocked"]) or bool(first_page[1]["unlocked"]):
		_fail("stage page should expose level 1 and lock the future preview")
		return
	if absf(float(first_page[0]["best_time"]) - 82.5) > 0.001 or int(first_page[0]["best_stars"]) != 2:
		_fail("stage cards should project persisted time and stars")
		return
	if int(StageSelection.page_count(7)) != 2:
		_fail("seven unlocked levels plus preview should require two pages")
		return
	var second_page: Array[Dictionary] = StageSelection.cards(7, {7: 70.0}, {7: 3}, 99)
	if int(second_page[0]["level"]) != 7 or not bool(second_page[0]["unlocked"]) or int(second_page[1]["level"]) != 8 or bool(second_page[1]["unlocked"]):
		_fail("stage page should clamp and preserve the next locked preview")
		return
	var improved_stars: Dictionary = StageSelection.record_best_stars({3: 1}, 3, 3)
	var preserved_stars: Dictionary = StageSelection.record_best_stars(improved_stars, 3, 2)
	if int(improved_stars[3]) != 3 or int(preserved_stars[3]) != 3:
		_fail("stage best stars should improve monotonically")
		return

	# --- Wash rules: deterministic patch mutation (lift/mult injected) ---
	var WashRules: GDScript = load("res://core/use_cases/wash_rules.gd")
	if WashRules == null:
		_fail("wash_rules failed to load through res://core symlink")
		return
	if not _test_wash_tuning_profiles(GameConfig):
		return
	var mud = DirtPatch.new("mud", Vector2(100.0, 100.0), 20.0, 100.0, 0.5)
	WashRules.apply_water(mud, 0.5, 1.0, 1.0)
	if mud.health >= 100.0 or mud.wetness <= 0.0:
		_fail("water on mud should reduce health and wet it")
		return
	if String(mud.state) != "runoff" and String(mud.state) != "wet":
		_fail("water on mud should move it to a wet/runoff state")
		return
	var road_grime2 = DirtPatch.new("road_grime", Vector2(100.0, 100.0), 20.0, 100.0, 0.5)
	WashRules.apply_water(road_grime2, 0.2, 1.0, 1.0)
	var road_grime_health_after_rinse: float = road_grime2.health
	WashRules.apply_sponge(road_grime2, 0.5, Vector2(100.0, 100.0), 1.0, 1.0)
	if road_grime2.health >= road_grime_health_after_rinse or String(road_grime2.state) != "loosened":
		_fail("pre-rinsed road grime should loosen and clean with sponge")
		return
	var leaf2 = DirtPatch.new("leaf", Vector2(100.0, 100.0), 18.0, 100.0, 0.5)
	WashRules.apply_air(leaf2, 0.5, Vector2(100.0, 140.0), 1.0, 0.0)
	if String(leaf2.state) != "flying" or leaf2.health >= 100.0:
		_fail("air on leaf should send it flying and reduce health")
		return
	if absf(float(WashRules.runoff_cleanup_rate(mud)) - (0.42 + mud.wetness * 0.25)) > 0.0001:
		_fail("mud runoff cleanup rate formula changed")
		return
	var fresh = DirtPatch.new("dust", Vector2.ZERO, 10.0, 100.0, 0.1)
	if bool(WashRules.is_patch_removed(fresh)):
		_fail("a full-health patch should not be removed")
		return
	fresh.health = 0.0
	if not bool(WashRules.is_patch_removed(fresh)):
		_fail("a zero-health patch should be removed")
		return
	if not _test_misapplied_tool_damage(WashRules, Coaching, DirtPatch):
		return
	if not _test_correct_wash_snapshots(WashRules, DirtPatch):
		return

	# --- Analytics seam: port no-op contract + adapter buffer/flush (no Firebase) ---
	var AnalyticsPort: GDScript = load("res://core/ports/analytics_port.gd")
	if AnalyticsPort == null:
		_fail("analytics_port failed to load through res://core symlink")
		return
	var port = AnalyticsPort.new()
	port.log_event("noop_check", {"a": "1"})  # base contract: must not raise
	var FirebaseAdapter: GDScript = load("res://scripts/services/firebase_analytics_adapter.gd")
	if FirebaseAdapter == null:
		_fail("firebase_analytics_adapter failed to load")
		return
	var adapter = FirebaseAdapter.new()
	# Firebase not running (headless): log_event must be a TRUE no-op — no buffering.
	adapter.log_event("headless_event", {})
	if not adapter._pending.is_empty():
		_fail("adapter must not buffer when Firebase runtime is disabled")
		adapter.free()
		return
	# Firebase running but analytics not yet initialized: events buffer...
	adapter._firebase_runtime_enabled = true
	adapter.log_event("buffered_event", {"k": "v"})
	if adapter._pending.size() != 1:
		_fail("adapter should buffer events before analytics init")
		adapter.free()
		return
	# ...and the buffer is flushed+cleared once analytics reports ready.
	adapter._on_firebase_analytics_initialized(true)
	if not adapter._pending.is_empty():
		_fail("adapter should clear its buffer after init")
		adapter.free()
		return
	adapter.free()

	# --- Content events: catalog builders produce locked {name, params} schema ---
	var ContentEvents: GDScript = load("res://core/analytics/content_events.gd")
	if ContentEvents == null:
		_fail("content_events failed to load through res://core symlink")
		return
	var e_start: Dictionary = ContentEvents.game_start(3)
	if String(e_start["name"]) != "game_start" or String(e_start["params"]["level"]) != "3":
		_fail("game_start event schema changed: " + str(e_start))
		return
	var e_complete: Dictionary = ContentEvents.level_complete(7, 3, 62, 5, 60, true)
	if String(e_complete["name"]) != "level_complete":
		_fail("level_complete event name changed")
		return
	var cp: Dictionary = e_complete["params"]
	if String(cp["level"]) != "7" or String(cp["stars"]) != "3" or String(cp["time_sec"]) != "62" \
			or String(cp["best_combo"]) != "5" or String(cp["coins_earned"]) != "60" or String(cp["new_record"]) != "true":
		_fail("level_complete params changed: " + str(cp))
		return
	var e_bomb_ad: Dictionary = ContentEvents.foam_bomb_use(4, true, 40)
	if String(e_bomb_ad["params"]["source"]) != "ad" or String(e_bomb_ad["params"]["cost"]) != "0":
		_fail("ad-sourced foam bomb should report source=ad and cost 0: " + str(e_bomb_ad))
		return
	var e_bomb_coin: Dictionary = ContentEvents.foam_bomb_use(4, false, 40)
	if String(e_bomb_coin["params"]["source"]) != "coins" or String(e_bomb_coin["params"]["cost"]) != "40":
		_fail("coin-sourced foam bomb should report source=coins and its coin cost: " + str(e_bomb_coin))
		return
	var e_mission: Dictionary = ContentEvents.daily_mission_claim("dust", 50)
	if String(e_mission["params"]["mission_type"]) != "dust" or String(e_mission["params"]["reward"]) != "50":
		_fail("daily_mission_claim params changed: " + str(e_mission))
		return
	var e_upgrade: Dictionary = ContentEvents.upgrade_purchase("water", 2, 160)
	if String(e_upgrade["params"]["tool"]) != "water" or String(e_upgrade["params"]["level"]) != "2" or String(e_upgrade["params"]["cost"]) != "160":
		_fail("upgrade_purchase params changed: " + str(e_upgrade))
		return
	var e_skin: Dictionary = ContentEvents.skin_purchase("water", "coral", 80)
	if String(e_skin["params"]["skin_id"]) != "coral" or String(e_skin["params"]["cost"]) != "80":
		_fail("skin_purchase params changed: " + str(e_skin))
		return
	var e_double: Dictionary = ContentEvents.reward_double_coins(9, 60)
	if String(e_double["name"]) != "reward_double_coins" or String(e_double["params"]["level"]) != "9" or String(e_double["params"]["bonus"]) != "60":
		_fail("reward_double_coins params changed: " + str(e_double))
		return
	# Every built event name must be declared in the ALL catalog (backoffice contract).
	for built in [e_start, e_complete, e_bomb_ad, e_mission, e_upgrade, e_skin, e_double]:
		if not ContentEvents.ALL.has(String(built["name"])):
			_fail("event not registered in ContentEvents.ALL: " + String(built["name"]))
			return

	# --- FTUE events: title -> load -> play -> tutorial funnel contract ---
	var FtueEvents: GDScript = load("res://core/analytics/ftue_events.gd")
	if FtueEvents == null:
		_fail("ftue_events failed to load through res://core symlink")
		return
	if not _test_ftue_release_attribution_and_shared_native_path(FtueEvents):
		return
	var e_title: Dictionary = FtueEvents.title_screen_view("cold_start")
	var e_play: Dictionary = FtueEvents.play_tap(2)
	var e_load_start: Dictionary = FtueEvents.level_load_start(2, "cold_start")
	var e_load_complete: Dictionary = FtueEvents.level_load_complete(2, "sports", "cold_start")
	var e_tutorial_view: Dictionary = FtueEvents.tutorial_step_view("overview", "first_run")
	var e_tutorial_complete: Dictionary = FtueEvents.tutorial_complete("overview", "first_run")
	if e_title != {"name": "title_screen_view", "params": {"entry": "cold_start"}}:
		_fail("title_screen_view event schema changed: " + str(e_title))
		return
	if e_play != {"name": "play_tap", "params": {"level": "2"}}:
		_fail("play_tap event schema changed: " + str(e_play))
		return
	if e_load_start != {"name": "level_load_start", "params": {"level": "2", "reason": "cold_start"}}:
		_fail("level_load_start event schema changed: " + str(e_load_start))
		return
	if e_load_complete != {"name": "level_load_complete", "params": {"level": "2", "car_type": "sports", "reason": "cold_start"}}:
		_fail("level_load_complete event schema changed: " + str(e_load_complete))
		return
	if e_tutorial_view != {"name": "tutorial_step_view", "params": {"step": "overview", "source": "first_run"}}:
		_fail("tutorial_step_view event schema changed: " + str(e_tutorial_view))
		return
	if e_tutorial_complete != {"name": "tutorial_complete", "params": {"step": "overview", "source": "first_run"}}:
		_fail("tutorial_complete event schema changed: " + str(e_tutorial_complete))
		return
	for built in [e_title, e_play, e_load_start, e_load_complete, e_tutorial_view, e_tutorial_complete]:
		if not FtueEvents.ALL.has(String(built["name"])):
			_fail("event not registered in FtueEvents.ALL: " + String(built["name"]))
			return

	print("CORE TESTS PASSED")
	quit(0)


func _test_ftue_release_attribution_and_shared_native_path(FtueEvents: GDScript) -> bool:
	if String(FtueEvents.VERSION_DIMENSION) != "app_info.version":
		_fail("FTUE release dimension must remain GA4 app_info.version")
		return false
	var native_adapter_source := FileAccess.get_file_as_string("res://scripts/services/firebase_analytics_adapter.gd")
	if not native_adapter_source.contains('OS.has_feature("ios")') or not native_adapter_source.contains('OS.has_feature("android")'):
		_fail("Android and iOS must share FirebaseAnalyticsAdapter")
		return false
	if not native_adapter_source.contains("func log_event(event_name: String, params: Dictionary = {})"):
		_fail("native FTUE events must keep the shared AnalyticsPort log_event path")
		return false
	return true


func _test_dirt_spawn_plan(DirtSpawnPlan: GDScript) -> bool:
	var snapshots := {1: 20, 3: 24, 10: 38, 30: 40}
	for level in snapshots:
		var actual: int = DirtSpawnPlan.spawn_count(level)
		if actual != snapshots[level]:
			_fail("dirt count snapshot changed at level %d: %d" % [level, actual])
			return false
	var previous: int = DirtSpawnPlan.spawn_count(2)
	for level in range(3, 11):
		var current: int = DirtSpawnPlan.spawn_count(level)
		if current <= previous:
			_fail("dirt count must grow strictly through level 10")
			return false
		previous = current
	if DirtSpawnPlan.spawn_count(10, 30) != 30:
		_fail("spawn count must respect the validated silhouette slot budget")
		return false
	if absf(float(DirtSpawnPlan.radius_scale_for_count(24)) - 1.0) > 0.001 or absf(float(DirtSpawnPlan.radius_scale_for_count(40)) - 0.72) > 0.001:
		_fail("dense spawn radius scaling snapshots changed")
		return false
	var previous_radius_scale := 1.0
	for patch_count in range(24, 41):
		var radius_scale: float = DirtSpawnPlan.radius_scale_for_count(patch_count)
		if radius_scale > previous_radius_scale + 0.001:
			_fail("dense spawn radius scale must not grow with patch count")
			return false
		previous_radius_scale = radius_scale
	var candidates: Array[Vector2] = DirtSpawnPlan.normalized_candidates()
	if candidates.size() != DirtSpawnPlan.CANDIDATE_COLUMNS * DirtSpawnPlan.CANDIDATE_ROWS or candidates.size() < DirtSpawnPlan.MAX_PATCH_COUNT:
		_fail("normalized spawn candidates must exceed the density cap")
		return false
	for candidate in candidates:
		if candidate.x <= 0.0 or candidate.x >= 1.0 or candidate.y <= 0.0 or candidate.y >= 1.0:
			_fail("normalized dirt candidate escaped the unit bounds")
			return false
	if DirtSpawnPlan.type_pool_for_level("sports", 2) != ["oil", "dust", "oil", "dust", "leaf", "dust", "mud"]:
		_fail("sports dirt weights or level gate changed")
		return false
	if DirtSpawnPlan.type_pool_for_level("offroad", 4).count("mud") != 3:
		_fail("offroad dirt profile should preserve its mud weight")
		return false
	if DirtSpawnPlan.BASE_PATCH_COUNT <= 0 or DirtSpawnPlan.PATCHES_PER_LEVEL <= 0 or DirtSpawnPlan.MAX_PATCH_COUNT < 38 or DirtSpawnPlan.MIN_CENTER_DISTANCE <= 0.0 or DirtSpawnPlan.DENSE_RADIUS_MIN_SCALE <= 0.0:
		_fail("dirt density tuning constants must remain named and positive")
		return false
	return true


func _test_misapplied_tool_damage(WashRules: GDScript, Coaching: GDScript, DirtPatch: GDScript) -> bool:
	var cases := [
		{"kind": "mud", "wrong": "sponge", "correct": "water"},
		{"kind": "dust", "wrong": "soap", "correct": "sponge"},
		{"kind": "leaf", "wrong": "water", "correct": "air"},
		{"kind": "leaf", "wrong": "soap", "correct": "air"},
		{"kind": "leaf", "wrong": "sponge", "correct": "air"},
		{"kind": "oil", "wrong": "water", "correct": "soap"},
		{"kind": "oil", "wrong": "sponge", "correct": "soap"},
		{"kind": "bug", "wrong": "water", "correct": "soap"},
		{"kind": "bug", "wrong": "sponge", "correct": "soap"},
		{"kind": "poop", "wrong": "water", "correct": "soap"},
		{"kind": "poop", "wrong": "sponge", "correct": "soap"},
		{"kind": "road_grime", "wrong": "sponge", "correct": "soap"},
	]
	for test_case in cases:
		var kind := String(test_case["kind"])
		var wrong_tool := String(test_case["wrong"])
		var correct_tool := String(test_case["correct"])
		var flagged_patch = DirtPatch.new(kind, Vector2.ZERO, 18.0, 100.0, 0.5)
		if not bool(Coaching.tool_misapplied(wrong_tool, flagged_patch)):
			_fail("wrong-tool damage case is not flagged: %s/%s" % [kind, wrong_tool])
			return false
		var wrong_damage := _damage_after_one_second(WashRules, DirtPatch, kind, wrong_tool)
		var correct_damage := _damage_after_one_second(WashRules, DirtPatch, kind, correct_tool)
		if wrong_damage <= 0.0:
			_fail("active wrong tool must keep tiny progress: %s/%s" % [kind, wrong_tool])
			return false
		if wrong_damage > correct_damage * 0.05 + 0.0001:
			_fail("wrong tool exceeded 5 percent DPS: %s/%s" % [kind, wrong_tool])
			return false
		if correct_damage < wrong_damage * 10.0:
			_fail("correct tool must be at least 10x faster: %s/%s" % [kind, wrong_tool])
			return false

	for kind in ["mud", "oil", "bug", "poop", "road_grime"]:
		var heavy = DirtPatch.new(kind, Vector2.ZERO, 18.0, 100.0, 0.5)
		WashRules.apply_air(heavy, 1.0, Vector2(0.0, 20.0), 1.0, 20.0)
		if absf(heavy.health - 100.0) > 0.0001:
			_fail("air must keep zero damage on heavy dirt: " + kind)
			return false
	return true


func _damage_after_one_second(WashRules: GDScript, DirtPatch: GDScript, kind: String, tool: String) -> float:
	var patch = DirtPatch.new(kind, Vector2.ZERO, 18.0, 100.0, 0.5)
	match tool:
		"air":
			WashRules.apply_air(patch, 1.0, Vector2(0.0, 20.0), 1.0, 20.0)
		"water":
			WashRules.apply_water(patch, 1.0, 1.0, 1.0)
		"soap":
			WashRules.apply_soap(patch, 1.0, 1.0, 1.0)
		"sponge":
			WashRules.apply_sponge(patch, 1.0, Vector2(0.0, 20.0), 1.0, 1.0)
	return 100.0 - patch.health


func _test_correct_wash_snapshots(WashRules: GDScript, DirtPatch: GDScript) -> bool:
	var mud = DirtPatch.new("mud", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_water(mud, 0.5, 1.0, 1.0)
	if absf(mud.health - 19.0) > 0.001:
		_fail("correct mud rinse timing changed")
		return false
	var dust = DirtPatch.new("dust", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_water(dust, 0.5, 1.0, 1.0)
	if absf(dust.health - 33.4) > 0.001 or absf(dust.wetness - 0.925) > 0.001:
		_fail("correct dust rinse damage or wetness timing changed")
		return false
	var leaf = DirtPatch.new("leaf", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_air(leaf, 0.1, Vector2(0.0, 20.0), 1.0, 0.0)
	if absf(leaf.health - 79.48) > 0.001 or absf(leaf.drift.y + 26.82) > 0.001:
		_fail("correct leaf air damage or motion timing changed")
		return false

	var oil = DirtPatch.new("oil", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_soap(oil, 0.5, 1.0, 1.0)
	WashRules.apply_sponge(oil, 0.5, Vector2(0.0, 20.0), 1.0, 1.0)
	if absf(oil.health - 27.1) > 0.001:
		_fail("correct oil soap-and-sponge timing changed")
		return false

	var poop = DirtPatch.new("poop", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_soap(poop, 0.5, 1.0, 1.0)
	WashRules.apply_water(poop, 0.5, 1.0, 1.0)
	if absf(poop.health - 2.8) > 0.001:
		_fail("correct poop soap-and-rinse timing changed")
		return false
	return true


func _test_wash_tuning_profiles(GameConfig: GDScript) -> bool:
	var profile_tables := [
		GameConfig.RUNOFF_CLEANUP_PROFILES,
		GameConfig.AIR_WASH_PROFILES,
		GameConfig.WATER_WASH_PROFILES,
		GameConfig.SOAP_WASH_PROFILES,
		GameConfig.SPONGE_WASH_PROFILES,
	]
	for table in profile_tables:
		for dirt_kind in GameConfig.DIRT_TYPES:
			if not table.has(dirt_kind):
				_fail("wash tuning profile missing dirt kind: " + dirt_kind)
				return false
	if absf(float(GameConfig.AIR_WASH_PROFILES["dust"]["damage"]) - 2.15) > 0.0001 \
		or absf(float(GameConfig.WATER_WASH_PROFILES["mud"]["damage"]) - 2.25) > 0.0001 \
		or absf(float(GameConfig.SOAP_WASH_PROFILES["oil"]["damage"]) - 0.05) > 0.0001 \
		or absf(float(GameConfig.SPONGE_WASH_PROFILES["road_grime"]["prepared_base"]) - 1.2) > 0.0001 \
		or absf(float(GameConfig.MISAPPLIED_DAMAGE_COEFFICIENT) - 0.002) > 0.0001:
		_fail("central wash tuning values changed during extraction")
		return false
	var wash_source := FileAccess.get_file_as_string("res://core/use_cases/wash_rules.gd")
	for config_name in ["RUNOFF_CLEANUP_PROFILES", "AIR_WASH_PROFILES", "AIR_MOTION_PROFILE", "WATER_WASH_PROFILES", "WATER_LEAF_PUSH_VELOCITY", "SOAP_WASH_PROFILES", "SPONGE_WASH_PROFILES", "SPONGE_MOTION_PROFILE", "MISAPPLIED_DAMAGE_COEFFICIENT"]:
		if not wash_source.contains("GameConfig." + config_name):
			_fail("wash rule does not consume central tuning: " + config_name)
			return false
	var coaching_source := FileAccess.get_file_as_string("res://core/use_cases/coaching.gd")
	if not coaching_source.contains("GameConfig.WATER_WASH_PROFILES") or not coaching_source.contains("GameConfig.SPONGE_WASH_PROFILES"):
		_fail("coaching must share the same preparation thresholds as wash rules")
		return false
	return true


func _test_gold_spot_rules(GoldSpot: GDScript, GameConfig: GDScript) -> bool:
	if int(GameConfig.GOLD_SPOT_SPAWN_PERCENT) != 25 or int(GameConfig.GOLD_SPOT_BONUS_COINS) != 8 or int(GameConfig.GOLD_SPOT_REWARD_CAP_PER_LEVEL) != 1:
		_fail("gold spot balance hooks changed unexpectedly")
		return false
	if int(GoldSpot.spawn_index(1, 0, 42787)) != -1:
		_fail("gold spot cannot spawn without a dirt patch")
		return false

	var spawned_levels := 0
	for level in range(1, 101):
		var patch_count := mini(40, 18 + level * 2)
		var seed := 42690 + level * 97
		var first_index: int = GoldSpot.spawn_index(level, patch_count, seed)
		var retry_index: int = GoldSpot.spawn_index(level, patch_count, seed)
		if first_index != retry_index:
			_fail("gold spot selection must reproduce the level seed")
			return false
		if first_index >= patch_count:
			_fail("gold spot index must stay inside the spawned patch list")
			return false
		if first_index >= 0:
			spawned_levels += 1
	if spawned_levels < 10 or spawned_levels > 40:
		_fail("gold spot should remain a low-probability level event")
		return false

	if int(GoldSpot.reward_for_removal(false, 0)) != 0:
		_fail("ordinary dirt must not grant a gold spot reward")
		return false
	if int(GoldSpot.reward_for_removal(true, 0)) != int(GameConfig.GOLD_SPOT_BONUS_COINS):
		_fail("first gold spot removal should grant the configured bonus")
		return false
	if int(GoldSpot.reward_for_removal(true, GameConfig.GOLD_SPOT_REWARD_CAP_PER_LEVEL)) != 0:
		_fail("gold spot reward must stop at the per-level cap")
		return false
	return true


func _test_car_roster_and_saved_level_mapping(GameConfig: GDScript) -> bool:
	var expected_roster := ["compact", "sports", "truck", "van", "offroad"]
	if Array(GameConfig.CAR_TYPES) != expected_roster:
		_fail("car roster must contain five ordered vehicle types")
		return false
	var saved_level_expectations := {
		1: "compact",
		2: "sports",
		3: "truck",
		4: "van",
		5: "offroad",
		6: "compact",
	}
	for saved_level in saved_level_expectations:
		if String(GameConfig.car_type_for_level(saved_level)) != saved_level_expectations[saved_level]:
			_fail("saved level %d restored the wrong car type" % saved_level)
			return false
	if String(GameConfig.car_type_for_level(0)) != "compact":
		_fail("invalid saved levels must clamp to the first car type")
		return false
	return true


func _test_license_plate_rules(LicensePlate: GDScript) -> bool:
	var options: Array[String] = LicensePlate.options()
	if options.size() < 4 or options[0] != LicensePlate.DEFAULT_TEXT:
		_fail("license plate presets must include the default and multiple choices")
		return false
	for option in options:
		if not bool(LicensePlate.is_safe_text(option)) or option.length() > int(LicensePlate.MAX_LENGTH):
			_fail("license plate preset escaped the character or length whitelist: " + option)
			return false
	if String(LicensePlate.safe_selection(" soap ")) != "SOAP":
		_fail("license plate selection should normalize an allowed preset")
		return false
	for unsafe in ["TOO-LONG", "DROP TABLE", "CUSTOM", "욕설"]:
		if String(LicensePlate.safe_selection(unsafe)) != LicensePlate.DEFAULT_TEXT:
			_fail("unsafe or uncurated plate text must fall back to the default: " + unsafe)
			return false
	return true


func _test_new_car_localized_labels(I18n: GDScript) -> bool:
	if I18n.STRINGS.get("CAR_VAN", []) != ["밴", "Van"]:
		_fail("van must have exact Korean and English labels")
		return false
	if I18n.STRINGS.get("CAR_OFFROAD", []) != ["오프로더", "Off-roader"]:
		_fail("off-roader must have exact Korean and English labels")
		return false
	return true


func _test_language_resolution(I18n: GDScript) -> bool:
	if String(I18n.resolve_locale("ko", "ja")) != "ko":
		_fail("explicit Korean preference must override a non-Korean device")
		return false
	if String(I18n.resolve_locale("en", "ko")) != "en":
		_fail("explicit English preference must override a Korean device")
		return false
	if String(I18n.resolve_locale("", "ko_KR")) != "ko":
		_fail("unset preference must preserve Korean device fallback")
		return false
	if String(I18n.resolve_locale("", "ja_JP")) != "en":
		_fail("unsupported device language must fall back to English")
		return false
	if String(I18n.normalize_preference("fr")) != "":
		_fail("unsupported stored preference must return to automatic fallback")
		return false
	return true


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
