extends RefCounted

# Pure daily-mission selection. Deterministic in the date string: no RNG and no
# clock access. The godot layer supplies today's date and stores the result.

const GameConfig = preload("res://core/domain/game_config.gd")


# Returns {type, label, target, reward} for the given YYYY-MM-DD date. The label
# is already formatted with its target count.
static func mission_for(today: String) -> Dictionary:
	var missions := missions_for(today, 1)
	return missions[0] if not missions.is_empty() else {}


# Picks unique mission types for one day. A stride of three walks the ten-item
# pool without repetition and keeps the legacy first pick unchanged.
static func missions_for(
	today: String,
	count: int = GameConfig.DAILY_MISSION_COUNT,
	streak: int = 1
) -> Array[Dictionary]:
	var pool: Array = GameConfig.DAILY_MISSION_POOL
	var results: Array[Dictionary] = []
	if pool.is_empty() or count <= 0:
		return results
	var day_hash := absi(today.hash())
	var first_pick := day_hash % pool.size()
	for offset in range(mini(count, pool.size())):
		var pick := (first_pick + offset * 3) % pool.size()
		results.append(_mission_result(pool[pick], streak))
	return results


static func mission_for_type(mission_type: String) -> Dictionary:
	for raw_mission in GameConfig.DAILY_MISSION_POOL:
		var mission: Dictionary = raw_mission
		if String(mission["type"]) == mission_type:
			return _mission_result(mission)
	return {}


static func display_value(mission_type: String, target: int, requirement: int) -> int:
	if mission_type == "combo" or mission_type == "fast":
		return requirement
	return target


static func _mission_result(m: Dictionary, streak: int = 1) -> Dictionary:
	var target: int = m["target"]
	var requirement := maxi(0, int(m.get("requirement", 0)))
	var label_value := display_value(String(m["type"]), target, requirement)
	return {
		"type": m["type"],
		"target": target,
		"requirement": requirement,
		"label": m["label"] % label_value,
		"reward": reward_for_type(String(m["type"]), streak),
	}


static func reward_for_type(mission_type: String, streak: int = 1) -> int:
	for mission in GameConfig.DAILY_MISSION_POOL:
		if String(mission["type"]) == mission_type:
			var base := maxi(int(mission.get("reward", GameConfig.DAILY_MISSION_REWARD)), GameConfig.DAILY_MISSION_REWARD)
			return base + streak_bonus(streak)
	return GameConfig.DAILY_MISSION_REWARD + streak_bonus(streak)


static func streak_bonus(streak: int) -> int:
	var bonus := 0
	var milestones: Array = GameConfig.DAILY_STREAK_REWARD_BONUSES.keys()
	milestones.sort()
	for raw_milestone in milestones:
		var milestone := int(raw_milestone)
		if streak >= milestone:
			bonus = int(GameConfig.DAILY_STREAK_REWARD_BONUSES[milestone])
	return bonus


# Attendance advances once per calendar date. Reopening on the same date is
# idempotent; skipping any date or supplying malformed dates starts at day one.
static func updated_streak(previous_streak: int, last_active_date: String, today: String) -> int:
	if today.is_empty():
		return 1
	if last_active_date == today:
		return maxi(previous_streak, 1)
	var last_day := _day_number(last_active_date)
	var current_day := _day_number(today)
	if last_day >= 0 and current_day - last_day == 1:
		return maxi(previous_streak, 0) + 1
	return 1


static func _day_number(date_string: String) -> int:
	if date_string.length() != 10:
		return -1
	var parts := date_string.split("-")
	if parts.size() != 3:
		return -1
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31:
		return -1
	return int(Time.get_unix_time_from_datetime_string(date_string + "T00:00:00") / 86400.0)
