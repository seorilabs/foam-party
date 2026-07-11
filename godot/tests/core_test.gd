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
	var DirtPatch: GDScript = load("res://core/domain/dirt_patch.gd")
	if Scoring == null or Economy == null or Coaching == null or DailyMission == null or BestTime == null or DirtPatch == null:
		_fail("core scripts failed to load through res://core symlink")
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
	if int(Economy.calc_coin_reward(1, 10)) != 50:
		_fail("1-star clear with max combo bonus should pay 50 coins")
		return
	if int(Economy.calc_coin_reward(3, 5)) != 60:
		_fail("3-star clear should pay 60 coins")
		return
	if int(Economy.calc_level_milestone_bonus(5)) != 75:
		_fail("level 5 milestone bonus should be 75")
		return
	if int(Economy.calc_level_milestone_bonus(3)) != 0:
		_fail("non-milestone level should give no bonus")
		return
	if int(Economy.upgrade_cost(0, 0)) != 80 or int(Economy.upgrade_cost(0, 2)) != 280:
		_fail("upgrade costs should read from the config table")
		return
	if not bool(Economy.can_buy_upgrade(0, 0, 80)):
		_fail("80 coins should afford the first upgrade tier")
		return
	if bool(Economy.can_buy_upgrade(0, 0, 79)):
		_fail("79 coins should not afford the first upgrade tier")
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

	# --- Wash rules: deterministic patch mutation (lift/mult injected) ---
	var WashRules: GDScript = load("res://core/use_cases/wash_rules.gd")
	if WashRules == null:
		_fail("wash_rules failed to load through res://core symlink")
		return
	var mud = DirtPatch.new("mud", Vector2(100.0, 100.0), 20.0, 100.0, 0.5)
	WashRules.apply_water(mud, 0.5, 1.0, 1.0)
	if mud.health >= 100.0 or mud.wetness <= 0.0:
		_fail("water on mud should reduce health and wet it")
		return
	if String(mud.state) != "runoff" and String(mud.state) != "wet":
		_fail("water on mud should move it to a wet/runoff state")
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
	# Every built event name must be declared in the ALL catalog (backoffice contract).
	for built in [e_start, e_complete, e_bomb_ad, e_mission, e_upgrade, e_skin]:
		if not ContentEvents.ALL.has(String(built["name"])):
			_fail("event not registered in ContentEvents.ALL: " + String(built["name"]))
			return

	print("CORE TESTS PASSED")
	quit(0)


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
