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
	var ComboProtection: GDScript = load("res://core/use_cases/combo_protection.gd")
	var CustomerPresentation: GDScript = load("res://core/use_cases/customer_presentation.gd")
	var CustomerPatience: GDScript = load("res://core/use_cases/customer_patience.gd")
	var StalledDirtHighlight: GDScript = load("res://core/use_cases/stalled_dirt_highlight.gd")
	var DailyMission: GDScript = load("res://core/use_cases/daily_mission.gd")
	var AchievementProgress: GDScript = load("res://core/use_cases/achievement_progress.gd")
	var BestTime: GDScript = load("res://core/use_cases/best_time.gd")
	var StageSelection: GDScript = load("res://core/use_cases/stage_selection.gd")
	var DirtSpawnPlan: GDScript = load("res://core/use_cases/dirt_spawn_plan.gd")
	var GoldSpot: GDScript = load("res://core/use_cases/gold_spot.gd")
	var LicensePlate: GDScript = load("res://core/use_cases/license_plate.gd")
	var CarPaintCatalog: GDScript = load("res://core/domain/car_paint_catalog.gd")
	var DirtPatch: GDScript = load("res://core/domain/dirt_patch.gd")
	var GameConfig: GDScript = load("res://core/domain/game_config.gd")
	var I18n: GDScript = load("res://scripts/services/i18n.gd")
	if Scoring == null or Economy == null or Coaching == null or ComboProtection == null or CustomerPresentation == null or CustomerPatience == null or StalledDirtHighlight == null or DailyMission == null or AchievementProgress == null or BestTime == null or StageSelection == null or DirtSpawnPlan == null or GoldSpot == null or LicensePlate == null or CarPaintCatalog == null or DirtPatch == null or GameConfig == null or I18n == null:
		_fail("core scripts failed to load through res://core symlink")
		return
	if not _test_achievement_progress_rule(AchievementProgress):
		return
	if not _test_combo_protection_rule(ComboProtection, GameConfig):
		return
	if not _test_customer_presentation_rule(CustomerPresentation, GameConfig):
		return
	if not _test_customer_patience_rule(CustomerPatience, GameConfig):
		return
	if not _test_car_roster_and_saved_level_mapping(GameConfig):
		return
	if not _test_new_car_localized_labels(I18n):
		return
	if not _test_language_resolution(I18n):
		return
	if not _test_dirt_spawn_plan(DirtSpawnPlan, GameConfig):
		return
	if not _test_sap_catalog_and_city_pool(DirtSpawnPlan, GameConfig):
		return
	if not _test_gold_spot_rules(GoldSpot, GameConfig):
		return
	if not _test_license_plate_rules(LicensePlate):
		return
	if not _test_car_paint_catalog(CarPaintCatalog, Economy):
		return

	# --- Scoring: star boundaries (matches smoke_scene 3/2/1-star cases) ---
	var combo_requirements := {0: 4, 1: 4, 3: 4, 4: 5, 6: 5, 7: 6, 19: 10, 40: 10}
	for level in combo_requirements:
		if int(Scoring.star3_combo_requirement(level)) != int(combo_requirements[level]):
			_fail("scaled third-star combo requirement mismatch at level %d" % level)
			return
	if int(GameConfig.STAR3_COMBO_LEVEL_STEP) != 3 or int(GameConfig.STAR3_COMBO_MAX) != 10:
		_fail("third-star combo scaling constants changed unexpectedly")
		return
	if int(Scoring.star3_combo_requirement(1)) != 4:
		_fail("level one must preserve the original third-star combo requirement of four")
		return
	if int(Scoring.star_time_threshold(3, 1)) != 75:
		_fail("3-star threshold at level 1 should be 75s")
		return
	if int(Scoring.star_time_threshold(2, 1)) != 140:
		_fail("2-star threshold at level 1 should be 140s")
		return
	var level5_star3 := float(Scoring.star_time_threshold(3, 5))
	var level10_star3 := float(Scoring.star_time_threshold(3, 10))
	if level5_star3 <= 75.0 * 1.25 or level10_star3 <= level5_star3 * 1.20:
		_fail("star timers must grow meaningfully with later-level wash work")
		return
	var previous_star3_threshold := 0.0
	for level in range(1, 31):
		var threshold := float(Scoring.star_time_threshold(3, level))
		if threshold + 0.001 < previous_star3_threshold:
			_fail("star time thresholds must be monotonic by level")
			return
		if threshold > float(GameConfig.STAR3_TIME) * float(GameConfig.STAR_TIME_SCALE_MAX) + 0.001:
			_fail("star time threshold exceeded its named cap")
			return
		previous_star3_threshold = threshold
	var level10_combo := int(Scoring.star3_combo_requirement(10))
	if int(Scoring.calc_stars(level10_star3, level10_combo, 10)) != 3 \
			or int(Scoring.calc_stars(level10_star3 + 0.01, level10_combo, 10)) != 2:
		_fail("late-level star calculation must switch at the workload-scaled threshold")
		return
	if String(Scoring.grade_slot_state(2, level10_star3, level10_combo, 10, "earned", "target", "locked")) != "earned" \
			or String(Scoring.grade_slot_state(2, level10_star3 + 0.01, level10_combo, 10, "earned", "target", "locked")) != "locked":
		_fail("live grade tracker must share the workload-scaled star threshold")
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
	if int(Scoring.calc_stars(60.0, 4, 4)) != 2 or int(Scoring.calc_stars(60.0, 5, 4)) != 3:
		_fail("level 4 third star must switch exactly at the scaled combo requirement")
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
	if String(Scoring.grade_slot_state(2, 60.0, 4, 4, "earned", "target", "locked")) != "target" \
			or String(Scoring.grade_slot_state(2, 60.0, 5, 4, "earned", "target", "locked")) != "earned":
		_fail("level 4 grade tracker must use the scaled combo requirement")
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
		_fail("1-star clear at combo 10 should pay 44 coins")
		return
	if int(Economy.calc_coin_reward(3, 5)) != 50:
		_fail("3-star clear should pay 50 coins")
		return
	if int(Economy.calc_coin_reward(3, 10)) != 60:
		_fail("3-star clear at combo 10 should pay 60 coins")
		return
	if int(Economy.calc_coin_reward(3, 15)) != 70 or int(Economy.calc_coin_reward(3, 20)) != 70:
		_fail("3-star reward should grow through combo 15 and cap at 70 coins")
		return
	var first_clear_reward: Dictionary = Economy.calc_completion_base_reward(3, 5, 0, false)
	var same_star_rewash: Dictionary = Economy.calc_completion_base_reward(3, 5, 3, true)
	var improved_rewash: Dictionary = Economy.calc_completion_base_reward(3, 5, 1, true)
	if int(first_clear_reward["coins"]) != 50 or bool(first_clear_reward["reduced"]):
		_fail("first clear must keep the full completion base reward")
		return
	if int(same_star_rewash["coins"]) != 25 or not bool(same_star_rewash["reduced"]):
		_fail("same-star rewashing must halve the completion base reward")
		return
	if int(improved_rewash["coins"]) != 33 \
			or int(improved_rewash["star_improvement"]) != 2:
		_fail("rewash star improvement must stay full while the remaining reward is halved")
		return
	if int(GameConfig.COIN_REWARD_BASE) != 16 \
			or int(GameConfig.COIN_REWARD_PER_STAR) != 8 \
			or int(GameConfig.COIN_REWARD_PER_COMBO) != 2 \
			or int(GameConfig.COIN_REWARD_COMBO_CAP) != 15:
		_fail("completion reward tuning must remain centralized in GameConfig")
		return
	if absf(float(GameConfig.PATIENCE_TIP_COINS_PER_FULL_PATIENCE) - 12.0) > 0.001 \
			or int(GameConfig.PATIENCE_TIP_MAX_COINS) != 12:
		_fail("customer tip formula and cap must remain named GameConfig tuning")
		return
	if int(Economy.calc_customer_tip(-0.5)) != 0 \
			or int(Economy.calc_customer_tip(0.0)) != 0 \
			or int(Economy.calc_customer_tip(0.5)) != 6 \
			or int(Economy.calc_customer_tip(0.75)) != 9 \
			or int(Economy.calc_customer_tip(1.0)) != 12 \
			or int(Economy.calc_customer_tip(2.0)) != 12:
		_fail("customer tip must scale linearly from zero and stop at the named cap")
		return
	if int(Economy.calc_customer_tip(1.0, 0.5)) != 6 \
			or int(Economy.calc_customer_tip(1.0, 2.0)) != 12:
		_fail("customer tip must accept a bounded shared rewashing payout ratio after capping")
		return
	if GameConfig.COMBO_BONUS_AMOUNTS != {5: 5, 8: 8, 10: 10, 12: 12, 15: 15, 20: 20}:
		_fail("combo milestone rewards must include the eight and twelve steps")
		return
	if int(Economy.perfect_wash_bonus(0)) != 0 \
			or int(Economy.perfect_wash_bonus(1)) != 10 \
			or int(Economy.perfect_wash_bonus(2)) != 15 \
			or int(Economy.perfect_wash_bonus(3)) != 20 \
			or int(Economy.perfect_wash_bonus(99)) != 20:
		_fail("perfect wash bonus must scale 10/15/20 and cap at three stars")
		return
	if int(GameConfig.BOMB_COST) != 80 \
			or int(GameConfig.WATER_BOOST_COST) != 60 \
			or absf(float(GameConfig.WATER_BOOST_DURATION) - 10.0) > 0.001 \
			or absf(float(GameConfig.WATER_BOOST_RADIUS_MULT) - 1.5) > 0.001 \
			or absf(float(GameConfig.WATER_BOOST_POWER_MULT) - 1.5) > 0.001:
		_fail("booster economy and water tuning must remain centralized in GameConfig")
		return
	if int(Economy.calc_level_milestone_bonus(5)) != 75:
		_fail("level 5 milestone bonus should be 75")
		return
	if int(Economy.calc_level_milestone_bonus(5, true)) != 0 \
			or int(Economy.calc_level_milestone_bonus(10, true)) != 0:
		_fail("claimed level milestones must not pay twice")
		return
	if int(Economy.calc_level_milestone_bonus(3)) != 0:
		_fail("non-milestone level should give no bonus")
		return
	if not _test_tool_specific_upgrade_curves(Economy, GameConfig):
		return
	if not _test_reach_upgrade_curves(Economy, GameConfig):
		return

	# --- Economy: skin purchase intents ---
	var SkinCatalog: GDScript = load("res://core/domain/skin_catalog.gd")
	var catalog: Dictionary = SkinCatalog.catalog()
	if not _test_tool_scoped_skin_purchase_intents(Economy, catalog):
		return
	var migrated_owned: Dictionary = Economy.normalize_skin_ownership(catalog, {
		"classic": true,
		"gold": true,
		"pink": true,
	}, {
		"water": "gold",
		"air": "classic",
		"soap": "pink",
		"sponge": "classic",
	})
	if not bool(migrated_owned.get("water:gold", false)) \
			or bool(migrated_owned.get("air:gold", false)) \
			or bool(migrated_owned.get("sponge:gold", false)) \
			or not bool(migrated_owned.get("soap:pink", false)):
		_fail("legacy shared gold must migrate only to selected tools while unique skins keep their tool")
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
	if not _test_wash_guide_catalog(Coaching, DirtPatch, GameConfig):
		return

	# --- Daily mission: deterministic in the date string ---
	var mission: Dictionary = DailyMission.mission_for("2026-07-06")
	var mission_again: Dictionary = DailyMission.mission_for("2026-07-06")
	if mission != mission_again:
		_fail("daily mission must be deterministic for a fixed date")
		return
	if String(mission["type"]) != "mud" or int(mission["target"]) != 15 or int(mission["requirement"]) != 0 or String(mission["label"]) != "흙탕물 15개 씻기" or int(mission["reward"]) != 60:
		_fail("daily mission for 2026-07-06 changed: " + str(mission))
		return
	var mission_set: Array[Dictionary] = DailyMission.missions_for("2026-07-06", 3, 7)
	if mission_set != DailyMission.missions_for("2026-07-06", 3, 7) or mission_set.size() != 3:
		_fail("same date and streak must return the same three daily missions")
		return
	var mission_types: Dictionary = {}
	for daily_entry in mission_set:
		mission_types[String(daily_entry["type"])] = true
	if mission_types.size() != 3 or String(mission_set[0]["type"]) != "mud":
		_fail("daily mission set must contain three unique types and preserve the legacy first pick")
		return
	if int(mission_set[0]["reward"]) != 85:
		_fail("seven-day streak must add the 25-coin tier bonus")
		return
	if DailyMission.streak_bonus(1) != 0 or DailyMission.streak_bonus(3) != 10 \
			or DailyMission.streak_bonus(7) != 25 or DailyMission.streak_bonus(14) != 50:
		_fail("daily streak reward tiers changed")
		return
	if DailyMission.updated_streak(6, "2026-07-20", "2026-07-20") != 6 \
			or DailyMission.updated_streak(6, "2026-07-20", "2026-07-21") != 7 \
			or DailyMission.updated_streak(6, "2026-07-19", "2026-07-21") != 1 \
			or DailyMission.updated_streak(4, "2026-07-31", "2026-08-01") != 5:
		_fail("daily attendance streak must be idempotent, increment consecutive dates, and reset gaps")
		return
	# claimable predicate — result-screen claim CTA and the engine claim guard share it
	if DailyMission.claimable(15, 15, false) != true \
			or DailyMission.claimable(16, 15, false) != true \
			or DailyMission.claimable(15, 15, true) != false \
			or DailyMission.claimable(14, 15, false) != false \
			or DailyMission.claimable(0, 0, false) != false:
		_fail("daily mission claimable predicate changed")
		return
	# next-day preview — "오늘 스트릭 n → 내일 보상" drives the come-back hooks
	if DailyMission.next_day_streak(6) != 7 or DailyMission.next_day_streak(0) != 1 \
			or DailyMission.next_day_streak(-3) != 1:
		_fail("next_day_streak must advance today's streak by one and floor at one")
		return
	if DailyMission.next_day_streak_bonus(1) != 0 or DailyMission.next_day_streak_bonus(2) != 10 \
			or DailyMission.next_day_streak_bonus(6) != 25 or DailyMission.next_day_streak_bonus(13) != 50:
		_fail("next_day_streak_bonus must preview tomorrow's streak tier")
		return
	if int(DailyMission.next_day_reward_preview("mud", 6)) != 85 \
			or int(DailyMission.next_day_reward_preview("unknown", 2)) != int(GameConfig.DAILY_MISSION_REWARD) + 10:
		_fail("next_day_reward_preview must pay tomorrow's streak-adjusted reward")
		return
	var seen_style_missions: Dictionary = {}
	var style_mission_dates: Dictionary = {}
	for month in range(1, 13):
		for day in range(1, 29):
			var candidate_date := "2026-%02d-%02d" % [month, day]
			var rotated: Dictionary = DailyMission.mission_for(candidate_date)
			if String(rotated["type"]) in ["combo", "fast", "perfect3"]:
				seen_style_missions[String(rotated["type"])] = true
				if not style_mission_dates.has(String(rotated["type"])):
					style_mission_dates[String(rotated["type"])] = candidate_date
	if seen_style_missions.size() != 3:
		_fail("date-hash rotation must include combo, fast, and perfect3 missions")
		return
	# AC-5: each new type must resolve identically when its own date is queried again.
	for mission_type in ["combo", "fast", "perfect3"]:
		var representative_date := String(style_mission_dates[mission_type])
		var first_pick: Dictionary = DailyMission.mission_for(representative_date)
		var repeated_pick: Dictionary = DailyMission.mission_for(representative_date)
		if first_pick != repeated_pick or String(first_pick["type"]) != mission_type:
			_fail("same date must deterministically repeat new mission type %s" % mission_type)
			return
	var expected_style_missions := {
		"combo": {"target": 1, "requirement": 8, "label": "한 판에서 콤보 x8 달성"},
		"fast": {"target": 1, "requirement": 75, "label": "75초 이내 세차 완료"},
		"perfect3": {"target": 2, "requirement": 3, "label": "별 3개 세차 2회"},
	}
	for mission_type in expected_style_missions:
		var style_mission: Dictionary = DailyMission.mission_for_type(mission_type)
		var expected_style: Dictionary = expected_style_missions[mission_type]
		if int(style_mission["target"]) != int(expected_style["target"]) \
				or int(style_mission["requirement"]) != int(expected_style["requirement"]) \
				or String(style_mission["label"]) != String(expected_style["label"]):
			_fail("style daily mission config mismatch for %s: %s" % [mission_type, style_mission])
			return
	var expected_mission_rewards := {
		"leaf": 50,
		"dust": 55,
		"mud": 60,
		"oil": 70,
		"bug": 75,
		"poop": 80,
		"road_grime": 85,
		"combo": 90,
		"fast": 95,
		"perfect3": 100,
	}
	var previous_reward := 0
	var seen_rewards: Array[int] = []
	for mission_type in ["leaf", "dust", "mud", "oil", "bug", "poop", "road_grime", "combo", "fast", "perfect3"]:
		var reward := int(DailyMission.reward_for_type(mission_type))
		if reward != int(expected_mission_rewards[mission_type]):
			_fail("daily mission reward changed for %s: %d" % [mission_type, reward])
			return
		if reward <= previous_reward:
			_fail("harder daily missions must always pay more than easier missions")
			return
		if seen_rewards.has(reward):
			_fail("every daily mission must have a unique reward")
			return
		seen_rewards.append(reward)
		previous_reward = reward
	if int(DailyMission.reward_for_type("unknown")) != int(GameConfig.DAILY_MISSION_REWARD):
		_fail("unknown daily mission should use the legacy reward fallback")
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
	if int(StageSelection.total_best_stars({1: 3, 2: 2, 3: 1})) != 6:
		_fail("total stars must equal the bounded sum of per-level bests")
		return
	var migrated_stars: Dictionary = StageSelection.migrate_best_stars({}, 8, 3)
	if migrated_stars != {1: 3, 2: 3, 3: 2} \
			or int(StageSelection.total_best_stars(migrated_stars)) != 8:
		_fail("legacy total stars must migrate into bounded unlocked-level records")
		return
	if StageSelection.migrate_best_stars({"2": 5, 0: 3}, 99, 2) != {2: 3}:
		_fail("existing best-star records must normalize without legacy inflation")
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
	if not _test_heavy_air_mutation_snapshot(WashRules, DirtPatch):
		return
	if not _test_correct_wash_snapshots(WashRules, DirtPatch):
		return
	if not _test_sap_wash_path(WashRules, Coaching, DirtPatch):
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

	# #245 AC-3: setup() must record a diagnosable status instead of silently
	# no-opping, so the failing precondition is visible (here: headless config absent).
	var probe = FirebaseAdapter.new()
	probe.setup()
	if String(probe.status).is_empty() or String(probe.status) == "uninitialized":
		_fail("adapter setup must record a status for the silent no-op path")
		probe.free()
		return
	probe.free()

	# #245 AC-4: a failed analytics init must NOT discard buffered events (a later
	# retry-success can still flush them) and must record a loud failure status.
	var adapter2 = FirebaseAdapter.new()
	adapter2._firebase_runtime_enabled = true
	adapter2.log_event("pre_init_a", {})
	adapter2.log_event("pre_init_b", {})
	adapter2._on_firebase_analytics_initialized(false)
	if adapter2._pending.size() != 2 or String(adapter2.status) != "analytics_init_failed":
		_fail("failed analytics init must retain buffered events and record a failure status")
		adapter2.free()
		return
	# The retained events flush and clear on a later successful init.
	adapter2._on_firebase_analytics_initialized(true)
	if not adapter2._pending.is_empty() or String(adapter2.status) != "ready":
		_fail("retained events must flush and clear on a later successful init")
		adapter2.free()
		return
	adapter2.free()

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
	var e_bomb_ad: Dictionary = ContentEvents.foam_bomb_use(4, true, GameConfig.BOMB_COST)
	if String(e_bomb_ad["params"]["source"]) != "ad" or String(e_bomb_ad["params"]["cost"]) != "0":
		_fail("ad-sourced foam bomb should report source=ad and cost 0: " + str(e_bomb_ad))
		return
	var e_bomb_coin: Dictionary = ContentEvents.foam_bomb_use(4, false, GameConfig.BOMB_COST)
	if String(e_bomb_coin["params"]["source"]) != "coins" or String(e_bomb_coin["params"]["cost"]) != str(GameConfig.BOMB_COST):
		_fail("coin-sourced foam bomb should report source=coins and its coin cost: " + str(e_bomb_coin))
		return
	var e_mission: Dictionary = ContentEvents.daily_mission_claim("dust", 55, "result")
	if String(e_mission["params"]["mission_type"]) != "dust" or String(e_mission["params"]["reward"]) != "55" \
			or String(e_mission["params"]["placement"]) != "result":
		_fail("daily_mission_claim params changed: " + str(e_mission))
		return
	var e_mission_default: Dictionary = ContentEvents.daily_mission_claim("dust", 55)
	if String(e_mission_default["params"]["placement"]) != "":
		_fail("daily_mission_claim placement must default to empty: " + str(e_mission_default))
		return
	var e_mission_view: Dictionary = ContentEvents.daily_mission_view("main", 2, 6)
	if String(e_mission_view["name"]) != "daily_mission_view" or String(e_mission_view["params"]["placement"]) != "main" \
			or String(e_mission_view["params"]["unclaimed"]) != "2" or String(e_mission_view["params"]["streak"]) != "6":
		_fail("daily_mission_view params changed: " + str(e_mission_view))
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
	for built in [e_start, e_complete, e_bomb_ad, e_mission, e_mission_view, e_upgrade, e_skin, e_double]:
		if not ContentEvents.ALL.has(String(built["name"])):
			_fail("event not registered in ContentEvents.ALL: " + String(built["name"]))
			return

	# #246 AC: numeric params must ship as native int (so GA4 exports int_value, a
	# prerequisite for custom metrics), while enum/id params and the boolean flag
	# stay strings; economy-critical events must carry every required key.
	if typeof(e_start["params"]["level"]) != TYPE_INT:
		_fail("game_start.level must be a native int for GA4 int_value")
		return
	for numeric_key in ["level", "stars", "time_sec", "best_combo", "coins_earned"]:
		if typeof(cp[numeric_key]) != TYPE_INT:
			_fail("level_complete.%s must be a native int: %s" % [numeric_key, str(cp)])
			return
		if not cp.has(numeric_key):
			_fail("level_complete missing required key: " + numeric_key)
			return
	if typeof(cp["new_record"]) != TYPE_STRING or not cp.has("new_record"):
		_fail("level_complete.new_record must stay a string flag")
		return
	if typeof(e_bomb_coin["params"]["cost"]) != TYPE_INT \
			or typeof(e_bomb_coin["params"]["source"]) != TYPE_STRING \
			or not (e_bomb_coin["params"].has("cost") and e_bomb_coin["params"].has("source")):
		_fail("foam_bomb_use must send cost as int and source as string enum: " + str(e_bomb_coin))
		return
	if typeof(e_mission["params"]["reward"]) != TYPE_INT or typeof(e_mission["params"]["mission_type"]) != TYPE_STRING:
		_fail("daily_mission_claim reward must be int and mission_type string")
		return
	if typeof(e_mission_view["params"]["unclaimed"]) != TYPE_INT or typeof(e_mission_view["params"]["streak"]) != TYPE_INT:
		_fail("daily_mission_view unclaimed/streak must be int")
		return
	if typeof(e_upgrade["params"]["cost"]) != TYPE_INT or typeof(e_upgrade["params"]["level"]) != TYPE_INT \
			or typeof(e_skin["params"]["cost"]) != TYPE_INT or typeof(e_double["params"]["bonus"]) != TYPE_INT:
		_fail("upgrade_purchase/skin_purchase/reward_double_coins numeric params must be int")
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
	if e_play != {"name": "play_tap", "params": {"level": 2}}:
		_fail("play_tap event schema changed: " + str(e_play))
		return
	if e_load_start != {"name": "level_load_start", "params": {"level": 2, "reason": "cold_start"}}:
		_fail("level_load_start event schema changed: " + str(e_load_start))
		return
	if e_load_complete != {"name": "level_load_complete", "params": {"level": 2, "car_type": "sports", "reason": "cold_start"}}:
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


func _test_wash_guide_catalog(Coaching: GDScript, DirtPatch: GDScript, GameConfig: GDScript) -> bool:
	var entries: Array = Coaching.wash_guide_entries()
	var guide_kinds: Array = []
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var kind: String = String(entry.get("kind", ""))
		var primary: Array = entry.get("primary", [])
		var follow_up: Array = entry.get("follow_up", [])
		if kind.is_empty() or primary.is_empty() or String(entry.get("description_key", "")).is_empty():
			_fail("every wash guide row must name its dirt, primary tool, and description")
			return false
		guide_kinds.append(kind)
		var dry_patch = DirtPatch.new(kind, Vector2.ZERO, 18.0, 100.0, 0.5)
		if String(Coaching.recommended_tool(dry_patch)) != String(primary[0]):
			_fail("wash guide primary tool must match dry coaching for " + kind)
			return false
		for tool_id in primary:
			if bool(Coaching.tool_misapplied(String(tool_id), dry_patch)):
				_fail("wash guide must not list a misapplied dry tool for " + kind)
				return false
		if kind in ["mud", "road_grime"]:
			dry_patch.wetness = 1.0
		elif not follow_up.is_empty():
			dry_patch.soap = 1.0
		if kind == "poop":
			dry_patch.state = "loosened"
		for tool_id in follow_up:
			if bool(Coaching.tool_misapplied(String(tool_id), dry_patch)):
				_fail("wash guide follow-up must match prepared coaching for " + kind)
				return false
	if guide_kinds != GameConfig.DIRT_TYPES:
		_fail("wash guide must cover every current dirt type in catalog order")
		return false
	return true


func _test_achievement_progress_rule(AchievementProgress: GDScript) -> bool:
	var definitions: Array[Dictionary] = AchievementProgress.definitions()
	if definitions.size() != 5:
		_fail("achievement catalog must expose exactly five launch achievements")
		return false
	var ids := {}
	var counters_seen := {}
	for definition in definitions:
		var achievement_id := String(definition["id"])
		var counter_key := String(definition["counter"])
		if ids.has(achievement_id) or counters_seen.has(counter_key) \
				or int(definition["target"]) <= 0 or int(definition["reward"]) <= 0:
			_fail("achievement definitions need unique ids/counters and positive targets/rewards")
			return false
		ids[achievement_id] = true
		counters_seen[counter_key] = true

	var counters: Dictionary = AchievementProgress.default_counters()
	var claimed := {}
	var dirt_definition: Dictionary = definitions[1]
	var result: Dictionary = AchievementProgress.apply_value(
		counters, claimed, String(dirt_definition["counter"]), int(dirt_definition["target"]) - 1
	)
	if int(result["reward"]) != 0 or not (result["newly_completed"] as Array).is_empty():
		_fail("achievement must stay pending below its local counter threshold")
		return false
	result = AchievementProgress.apply_value(
		result["counters"], result["claimed"],
		String(dirt_definition["counter"]), int(dirt_definition["target"])
	)
	if int(result["reward"]) != int(dirt_definition["reward"]) \
			or not bool((result["claimed"] as Dictionary).get(String(dirt_definition["id"]), false)):
		_fail("reaching an achievement threshold must complete and grant once")
		return false
	var once_reward := int(result["reward"])
	result = AchievementProgress.apply_value(
		result["counters"], result["claimed"],
		String(dirt_definition["counter"]), int(dirt_definition["target"]) + 50
	)
	if int(result["reward"]) != 0 or once_reward <= 0:
		_fail("a completed achievement must never grant its reward twice")
		return false

	var normalized: Dictionary = AchievementProgress.normalize_counters({
		AchievementProgress.COUNTER_WASHES: -4,
		AchievementProgress.COUNTER_COMBO: 12,
		"external_ga4_value": 999,
	})
	if int(normalized[AchievementProgress.COUNTER_WASHES]) != 0 \
			or int(normalized[AchievementProgress.COUNTER_COMBO]) != 12 \
			or normalized.has("external_ga4_value"):
		_fail("saved achievement counters must clamp local values and discard unknown keys")
		return false
	return true


func _test_tool_specific_upgrade_curves(Economy: GDScript, GameConfig: GDScript) -> bool:
	# Every equipped tool owns a distinct three-tier cost curve.
	var expected_upgrade_keys := ["air", "water", "soap", "sponge"]
	var expected_upgrade_costs := [
		[80, 160, 280],
		[110, 230, 380],
		[90, 190, 320],
		[70, 150, 260],
	]
	if GameConfig.UPGRADE_KEYS != expected_upgrade_keys \
			or GameConfig.UPGRADE_COSTS != expected_upgrade_costs:
		_fail("all four power upgrade keys and cost curves must remain named config")
		return false

	# AC-2: every valid tool/level pair is positive, increasing, and reads the
	# expected config value; multipliers stay in the shipped 1x-to-2x range.
	var total_upgrade_sink := 0
	for tool_idx in range(expected_upgrade_costs.size()):
		var previous_cost := 0
		for upgrade_level in range(GameConfig.UPGRADE_MAX_LEVEL):
			var cost := int(Economy.upgrade_cost(tool_idx, upgrade_level))
			if cost != int(expected_upgrade_costs[tool_idx][upgrade_level]):
				_fail("upgrade cost should read the tool-specific config curve")
				return false
			if cost <= previous_cost:
				_fail("upgrade costs must stay positive and increase by level")
				return false
			previous_cost = cost
			total_upgrade_sink += cost
	if total_upgrade_sink != 2320:
		_fail("four differentiated power curves must preserve the 2320-coin total sink")
		return false
	if not bool(Economy.can_buy_upgrade(0, 0, 80)) \
			or bool(Economy.can_buy_upgrade(0, 0, 79)):
		_fail("the first air upgrade must require exactly 80 coins")
		return false
	if not bool(Economy.can_buy_upgrade(1, 0, 110)):
		_fail("110 coins should afford the first water upgrade tier")
		return false
	if bool(Economy.can_buy_upgrade(1, 0, 109)):
		_fail("109 coins should not afford the first water upgrade tier")
		return false
	if bool(Economy.can_buy_upgrade(0, 3, 9999)):
		_fail("a maxed upgrade should never be buyable")
		return false
	for upgrade_level in range(GameConfig.UPGRADE_MAX_LEVEL + 1):
		var multiplier := float(Economy.upgrade_mult(upgrade_level))
		if multiplier < 1.0 or multiplier > 2.0:
			_fail("upgrade multipliers must stay in the supported 1x to 2x range")
			return false
	if absf(float(Economy.upgrade_mult(0)) - 1.0) > 0.0001 \
			or absf(float(Economy.upgrade_mult(3)) - 2.0) > 0.0001:
		_fail("upgrade multipliers should map level to the config table")
		return false

	# AC-3 and AC-4: the existing panel binds its existing buy_rect directly to
	# the data table, so differentiated values need no new UI surface.
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("UPGRADE_COSTS[idx][lvl]") \
			or not main_source.contains("_upgrade_buy_rect(panel, idx)"):
		_fail("upgrade panel must render tool-specific costs in its existing buy rect")
		return false
	return true


func _test_reach_upgrade_curves(Economy: GDScript, GameConfig: GDScript) -> bool:
	var expected_keys := ["air", "water", "soap", "sponge"]
	var expected_costs := [
		[70, 160, 280],
		[80, 180, 300],
		[75, 170, 290],
		[60, 140, 240],
	]
	var expected_mults := [1.0, 1.12, 1.24, 1.36]
	if GameConfig.REACH_UPGRADE_KEYS != expected_keys \
			or int(GameConfig.REACH_UPGRADE_MAX_LEVEL) != 3 \
			or GameConfig.REACH_UPGRADE_COSTS != expected_costs \
			or GameConfig.REACH_UPGRADE_MULTS != expected_mults:
		_fail("reach upgrade keys, costs, multipliers, and max level must remain named config")
		return false
	var total_reach_sink := 0
	for tool_idx in range(expected_keys.size()):
		var previous_cost := 0
		for level in range(GameConfig.REACH_UPGRADE_MAX_LEVEL):
			var cost := int(Economy.reach_upgrade_cost(tool_idx, level))
			if cost != int(expected_costs[tool_idx][level]) or cost <= previous_cost:
				_fail("every reach cost curve must stay positive, increasing, and tool-specific")
				return false
			previous_cost = cost
			total_reach_sink += cost
	if total_reach_sink != 2045:
		_fail("four reach upgrade tracks must preserve the named 2045-coin sink")
		return false
	var previous_mult := 0.0
	for level in range(GameConfig.REACH_UPGRADE_MAX_LEVEL + 1):
		var multiplier := float(Economy.reach_upgrade_mult(level))
		if absf(multiplier - float(expected_mults[level])) > 0.0001 or multiplier <= previous_mult:
			_fail("reach multiplier must increase at every level through the 1.36 cap")
			return false
		previous_mult = multiplier
	if not bool(Economy.can_buy_reach_upgrade(0, 0, 70)) \
			or bool(Economy.can_buy_reach_upgrade(0, 0, 69)) \
			or bool(Economy.can_buy_reach_upgrade(0, 3, 9999)):
		_fail("reach purchase intent must enforce cost and maximum level")
		return false
	return true


func _test_tool_scoped_skin_purchase_intents(Economy: GDScript, catalog: Dictionary) -> bool:
	# AC-2: the same gold id must resolve buy, select, and deny from the exact
	# (tool, skin) ownership tuple rather than from the skin id alone.
	var owned: Dictionary = Economy.default_skin_ownership(catalog)
	owned[Economy.skin_ownership_key("water", "gold")] = true
	var water_select: Dictionary = Economy.resolve_skin_purchase(catalog, "water", 3, owned, 0)
	var air_buy: Dictionary = Economy.resolve_skin_purchase(catalog, "air", 3, owned, 150)
	var air_deny: Dictionary = Economy.resolve_skin_purchase(catalog, "air", 3, owned, 149)
	if water_select != {"action": "select", "cost": 150, "id": "gold"}:
		_fail("owned water gold must resolve to select for water")
		return false
	if air_buy != {"action": "buy", "cost": 150, "id": "gold"}:
		_fail("water gold ownership must still resolve to buy for air")
		return false
	if air_deny != {"action": "deny", "cost": 150, "id": "gold"}:
		_fail("unowned air gold with insufficient coins must resolve to deny")
		return false
	return true


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


func _test_combo_protection_rule(ComboProtection: GDScript, GameConfig: GDScript) -> bool:
	if absf(float(GameConfig.COMBO_GRACE) - 1.0) > 0.001:
		_fail("combo grace should stay at one second")
		return false
	if not bool(ComboProtection.protection_after_removal(0, false)):
		_fail("a newly started combo should charge one protection")
		return false
	if bool(ComboProtection.protection_after_removal(3, false)):
		_fail("an active combo must not recharge spent protection")
		return false
	var first_timeout: Dictionary = ComboProtection.timeout_transition(4, true)
	if int(first_timeout["combo_count"]) != 4 or absf(float(first_timeout["combo_timer"]) - float(GameConfig.COMBO_GRACE)) > 0.001:
		_fail("first timeout should preserve combo and start the named grace window")
		return false
	if bool(first_timeout["protection_available"]) or not bool(first_timeout["grace_active"]) or bool(first_timeout["did_reset"]):
		_fail("first timeout should consume protection without resetting combo")
		return false
	var second_timeout: Dictionary = ComboProtection.timeout_transition(int(first_timeout["combo_count"]), bool(first_timeout["protection_available"]))
	if int(second_timeout["combo_count"]) != 0 or float(second_timeout["combo_timer"]) != 0.0 or not bool(second_timeout["did_reset"]):
		_fail("second timeout should reset combo after protection is spent")
		return false
	return true


func _test_customer_presentation_rule(CustomerPresentation: GDScript, GameConfig: GDScript) -> bool:
	var first_rotation: Array[int] = []
	for level in range(1, 6):
		var car_type := String(GameConfig.car_type_for_level(level))
		var profile_index := int(CustomerPresentation.profile_index(car_type, level))
		if first_rotation.has(profile_index):
			_fail("the first car rotation should expose five distinct customers")
			return false
		first_rotation.append(profile_index)
		var first_profile: Dictionary = CustomerPresentation.profile_for(car_type, level)
		if first_profile != CustomerPresentation.profile_for(car_type, level):
			_fail("customer profile must be deterministic for the same car and level")
			return false
		if not ["cap", "glasses", "headband"].has(String(first_profile["accessory"])):
			_fail("customer profile used an unsupported procedural accessory")
			return false
	if first_rotation.size() < 3:
		_fail("customer rotation must expose at least three profiles")
		return false
	var one_star := float(CustomerPresentation.reaction_strength(1))
	var two_stars := float(CustomerPresentation.reaction_strength(2))
	var three_stars := float(CustomerPresentation.reaction_strength(3))
	if not (one_star < two_stars and two_stars < three_stars):
		_fail("customer completion reaction must grow with earned stars")
		return false
	return true


func _test_customer_patience_rule(CustomerPatience: GDScript, GameConfig: GDScript) -> bool:
	var weight := float(GameConfig.PATIENCE_PROGRESS_WEIGHT)
	if weight <= 0.0 or weight >= 1.0:
		_fail("patience progress weight must expose a bounded gameplay tuning value")
		return false
	for elapsed_seconds in [0.0, 35.0, 70.0, 130.0, 140.0, 210.0]:
		var expected := clampf(1.0 - elapsed_seconds / float(GameConfig.STAR2_TIME), 0.0, 1.0)
		if absf(float(CustomerPatience.value(elapsed_seconds, 0.0)) - expected) > 0.0001:
			_fail("zero-progress patience must preserve the former time-only curve")
			return false
	var dirty_late := float(CustomerPatience.value(130.0, 0.0))
	var halfway_late := float(CustomerPatience.value(130.0, 0.5))
	var nearly_clean_late := float(CustomerPatience.value(130.0, 0.9))
	if not (dirty_late < halfway_late and halfway_late < nearly_clean_late and nearly_clean_late > 0.5):
		_fail("cleaning progress must monotonically relieve patience loss at the same time")
		return false
	if int(CustomerPatience.zone(dirty_late)) != 0 or int(CustomerPatience.zone(nearly_clean_late)) != 2:
		_fail("late dirty and near-clean customers must resolve to different matching mood zones")
		return false
	var previous_zone := 2
	var warning_count := 0
	for current_zone in [2, 1, 1, 2, 2]:
		if bool(CustomerPatience.should_warn(previous_zone, current_zone)):
			warning_count += 1
		previous_zone = current_zone
	if warning_count != 1:
		_fail("patience warning policy must fire once for one downgrade and stay silent otherwise")
		return false
	return true


func _test_dirt_spawn_plan(DirtSpawnPlan: GDScript, GameConfig: GDScript) -> bool:
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
	if absf(float(GameConfig.DIRT_HEALTH_SCALE_PER_LEVEL) - 0.06) > 0.0001 \
			or absf(float(GameConfig.DIRT_HEALTH_SCALE_MAX) - 1.5) > 0.0001:
		_fail("dirt health growth and ceiling must remain named GameConfig tuning")
		return false
	var previous_health_scale := 0.0
	for level in range(1, 10):
		var expected_scale := 1.0 + float(level - 1) * 0.06
		var actual_scale: float = DirtSpawnPlan.health_scale_for_level(level)
		if absf(actual_scale - expected_scale) > 0.0001 or actual_scale <= previous_health_scale:
			_fail("dirt health must preserve the existing +6 percent curve through level 9")
			return false
		previous_health_scale = actual_scale
	for capped_level in [10, 20, 50]:
		if absf(float(DirtSpawnPlan.health_scale_for_level(capped_level)) - 1.5) > 0.0001:
			_fail("dirt health scale must stay at the 1.5 ceiling from level 10 onward")
			return false
	var capped_oil_health: float = DirtSpawnPlan.scaled_health(100.0, "oil", 10)
	if absf(capped_oil_health - 187.5) > 0.0001 \
			or absf(float(DirtSpawnPlan.scaled_health(100.0, "oil", 20)) - capped_oil_health) > 0.0001 \
			or absf(float(DirtSpawnPlan.scaled_health(100.0, "oil", 50)) - capped_oil_health) > 0.0001:
		_fail("same dirt base health must remain identical across capped late levels")
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
	var candidates: Array[Vector2] = DirtSpawnPlan.normalized_candidates(6401)
	if candidates.size() != DirtSpawnPlan.CANDIDATE_COLUMNS * DirtSpawnPlan.CANDIDATE_ROWS or candidates.size() < DirtSpawnPlan.MAX_PATCH_COUNT:
		_fail("normalized spawn candidates must exceed the density cap")
		return false
	if candidates != DirtSpawnPlan.normalized_candidates(6401):
		_fail("spawn candidates must reproduce exactly for the same seed")
		return false
	var alternate_candidates: Array[Vector2] = DirtSpawnPlan.normalized_candidates(6402)
	var moved_candidates := 0
	for index in range(candidates.size()):
		if candidates[index].distance_to(alternate_candidates[index]) > 0.001:
			moved_candidates += 1
	if moved_candidates < candidates.size() * 3 / 4:
		_fail("different spawn seeds must move most procedural candidates")
		return false
	for candidate in candidates:
		if candidate.x <= 0.0 or candidate.x >= 1.0 or candidate.y <= 0.0 or candidate.y >= 1.0:
			_fail("normalized dirt candidate escaped the unit bounds")
			return false
	if DirtSpawnPlan.type_pool_for_level("sports", 2) != ["oil", "dust", "oil", "dust", "leaf", "dust", "mud"]:
		_fail("sports dirt weights or level gate changed")
		return false
	var compact_pool: Array[String] = DirtSpawnPlan.type_pool_for_level("compact", 6)
	var expected_compact_pool: Array[String] = ["dust", "leaf", "poop", "dust", "leaf", "road_grime", "poop", "dust", "leaf", "sap", "mud", "oil", "bug"]
	if compact_pool != expected_compact_pool:
		_fail("compact city dirt profile changed: " + str(compact_pool))
		return false
	var city_bias_count := compact_pool.count("dust") + compact_pool.count("leaf") + compact_pool.count("poop") + compact_pool.count("road_grime") + compact_pool.count("sap")
	var secondary_count := compact_pool.count("mud") + compact_pool.count("oil") + compact_pool.count("bug")
	if city_bias_count <= secondary_count:
		_fail("compact city dirt must favor dust, leaves, droppings, and road residue")
		return false
	for raw_kind in GameConfig.DIRT_TYPES:
		if not compact_pool.has(String(raw_kind)):
			_fail("compact city profile removed dirt kind: " + String(raw_kind))
			return false
	if compact_pool == DirtSpawnPlan.type_pool_for_level("sports", 6) or compact_pool == DirtSpawnPlan.type_pool_for_level("truck", 6):
		_fail("compact city dirt profile must stay distinct from sports and truck")
		return false
	if DirtSpawnPlan.type_pool_for_level("offroad", 4).count("mud") != 3:
		_fail("offroad dirt profile should preserve its mud weight")
		return false
	if DirtSpawnPlan.BASE_PATCH_COUNT <= 0 or DirtSpawnPlan.PATCHES_PER_LEVEL <= 0 or DirtSpawnPlan.MAX_PATCH_COUNT < 38 or DirtSpawnPlan.MIN_CENTER_DISTANCE <= 0.0 or DirtSpawnPlan.DENSE_RADIUS_MIN_SCALE <= 0.0:
		_fail("dirt density tuning constants must remain named and positive")
		return false
	if DirtSpawnPlan.MIN_RADIUS_SUM_SPACING_RATIO < 0.7 or DirtSpawnPlan.MIN_RADIUS_SUM_SPACING_RATIO > 1.0:
		_fail("dirt radius-sum spacing ratio must prevent unreadable clumps")
		return false
	return true


func _test_sap_catalog_and_city_pool(DirtSpawnPlan: GDScript, GameConfig: GDScript) -> bool:
	if not GameConfig.DIRT_TYPES.has("sap"):
		_fail("sap must appear in the complete dirt catalog")
		return false
	var unlocked_city_pool: Array[String] = DirtSpawnPlan.type_pool_for_level("compact", 5)
	if not unlocked_city_pool.has("sap"):
		_fail("sap must appear in the compact city type pool after its level gate")
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

	for kind in ["mud", "oil", "bug", "poop", "road_grime", "sap"]:
		var heavy = DirtPatch.new(kind, Vector2.ZERO, 18.0, 100.0, 0.5)
		WashRules.apply_air(heavy, 1.0, Vector2(0.0, 20.0), 1.0, 20.0)
		if absf(heavy.health - 100.0) > 0.0001:
			_fail("air must keep zero damage on heavy dirt: " + kind)
			return false
	return true


func _test_heavy_air_mutation_snapshot(WashRules: GDScript, DirtPatch: GDScript) -> bool:
	var mud = DirtPatch.new("mud", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_air(mud, 0.5, Vector2(0.0, 20.0), 0.8, 0.0)
	if absf(mud.drift.x) > 0.0001 or absf(mud.drift.y + 2.8) > 0.0001:
		_fail("heavy air drift must accumulate push times delta, proximity, and tuning")
		return false
	if absf(mud.looseness - 0.032) > 0.0001:
		_fail("heavy air looseness must accumulate the mud profile coefficient")
		return false
	if mud.velocity != Vector2.ZERO or String(mud.state) != "stuck" or absf(mud.health - 100.0) > 0.0001:
		_fail("heavy air must ignore lift and preserve velocity, state, and health")
		return false

	WashRules.apply_air(mud, 0.5, Vector2(0.0, 20.0), 0.8, 0.0)
	if absf(mud.drift.length() - 5.5) > 0.0001:
		_fail("heavy air drift must clamp to the configured length limit")
		return false
	if absf(mud.looseness - 0.064) > 0.0001:
		_fail("heavy air looseness must keep accumulating after drift is clamped")
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
	var upgraded_leaf = DirtPatch.new("leaf", Vector2.ZERO, 18.0, 100.0, 0.5)
	WashRules.apply_air(upgraded_leaf, 0.1, Vector2(0.0, 20.0), 1.0, 0.0, 1.3)
	if absf((100.0 - upgraded_leaf.health) / (100.0 - leaf.health) - 1.3) > 0.001:
		_fail("air power multiplier must scale light-dirt damage without changing the base rule")
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


func _test_sap_wash_path(WashRules: GDScript, Coaching: GDScript, DirtPatch: GDScript) -> bool:
	var sap = DirtPatch.new("sap", Vector2.ZERO, 18.0, 100.0, 0.5)
	if String(Coaching.recommended_tool(sap)) != "soap" \
			or not bool(Coaching.tool_misapplied("water", sap)) \
			or not bool(Coaching.tool_misapplied("sponge", sap)):
		_fail("dry sap must reject water and sponge while recommending soap")
		return false
	WashRules.apply_water(sap, 1.0, 1.0, 1.0)
	if absf(sap.health - 100.0) > 0.0001 or sap.soap > 0.0 or sap.looseness > 0.0:
		_fail("water alone must not clean or prepare sap")
		return false
	WashRules.apply_soap(sap, 0.5, 1.0, 1.0)
	if sap.soap <= 0.25 or sap.looseness <= 0.45 or String(sap.state) != "loosened" \
			or absf(sap.health - 100.0) > 0.0001:
		_fail("soap must soften sap without removing it")
		return false
	if String(Coaching.recommended_tool(sap)) != "sponge" \
			or bool(Coaching.tool_misapplied("sponge", sap)):
		_fail("softened sap must switch coaching to sponge")
		return false
	WashRules.apply_sponge(sap, 0.5, Vector2(0.0, 20.0), 1.0, 1.0)
	if sap.health >= 100.0:
		_fail("sponge must remove health from soaped sap")
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
		or absf(float(GameConfig.SOAP_WASH_PROFILES["sap"]["damage"])) > 0.0001 \
		or absf(float(GameConfig.SPONGE_WASH_PROFILES["sap"]["prepared_base"]) - 1.15) > 0.0001 \
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


func _test_car_paint_catalog(CarPaintCatalog: GDScript, Economy: GDScript) -> bool:
	var catalog_source := FileAccess.get_file_as_string("res://core/domain/car_paint_catalog.gd")
	if catalog_source.is_empty():
		_fail("car paint catalog must live in the product-core domain boundary")
		return false
	for forbidden_dependency in ["preload(", "load(", "JavaScriptBridge", "Firebase", "Control", "SceneTree"]:
		if catalog_source.contains(forbidden_dependency):
			_fail("car paint catalog must remain pure and adapter-independent: " + forbidden_dependency)
			return false
	var catalog: Dictionary = CarPaintCatalog.catalog()
	var paints: Array = catalog.get(CarPaintCatalog.TOOL_KEY, [])
	if paints.size() != 4 or String(paints[0]["id"]) != CarPaintCatalog.AUTO_ID:
		_fail("car paint catalog must expose auto plus three fixed presets")
		return false
	var ids := {}
	for paint in paints:
		var paint_data: Dictionary = paint
		var paint_id := String(paint_data.get("id", ""))
		if paint_id.is_empty() or String(paint_data.get("name", "")).is_empty() \
				or not paint_data.has("cost") or not paint_data.has("color") or ids.has(paint_id):
			_fail("car paint presets must have unique ids, names, costs, and colors")
			return false
		ids[paint_id] = true
	if String(CarPaintCatalog.safe_selection("auto")) != "" \
			or String(CarPaintCatalog.safe_selection("unknown")) != "" \
			or String(CarPaintCatalog.safe_selection("paint_mint")) != "paint_mint":
		_fail("car paint selection must preserve only supported fixed presets")
		return false
	var automatic_color := Color("#4f90ff")
	if not (CarPaintCatalog.color_for("", automatic_color) as Color).is_equal_approx(automatic_color):
		_fail("empty car paint selection must retain the automatic level color")
		return false
	if not (CarPaintCatalog.color_for("paint_coral", automatic_color) as Color).is_equal_approx(Color("#ff6f61")):
		_fail("fixed car paint must override the automatic level color")
		return false

	var owned_paints := {CarPaintCatalog.AUTO_ID: true}
	var auto_intent: Dictionary = Economy.resolve_flat_item_purchase(catalog, CarPaintCatalog.TOOL_KEY, 0, owned_paints, 0)
	if String(auto_intent["action"]) != "select":
		_fail("free automatic car paint must reuse the shared owned-item selection path")
		return false
	var buy_intent: Dictionary = Economy.resolve_flat_item_purchase(catalog, CarPaintCatalog.TOOL_KEY, 1, owned_paints, 100)
	if String(buy_intent["action"]) != "buy" or int(buy_intent["cost"]) != 100:
		_fail("fixed car paint purchase must reuse the shared economy judgement")
		return false
	var deny_intent: Dictionary = Economy.resolve_flat_item_purchase(catalog, CarPaintCatalog.TOOL_KEY, 1, owned_paints, 99)
	if String(deny_intent["action"]) != "deny":
		_fail("insufficient coins must deny a car paint purchase")
		return false
	var nozzle_owned_only := {"coral": true, CarPaintCatalog.AUTO_ID: true}
	var isolated_intent: Dictionary = Economy.resolve_flat_item_purchase(catalog, CarPaintCatalog.TOOL_KEY, 1, nozzle_owned_only, 100)
	if String(isolated_intent["action"]) != "buy":
		_fail("nozzle skin ownership must not unlock a car paint")
		return false
	owned_paints["paint_coral"] = true
	var select_intent: Dictionary = Economy.resolve_flat_item_purchase(catalog, CarPaintCatalog.TOOL_KEY, 1, owned_paints, 0)
	if String(select_intent["action"]) != "select":
		_fail("owned car paint must be selectable through the shared economy judgement")
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
