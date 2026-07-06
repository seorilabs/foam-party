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

	print("CORE TESTS PASSED")
	quit(0)


func _fail(message: String) -> void:
	print("CORE TEST FAIL: " + message)
	quit(1)
