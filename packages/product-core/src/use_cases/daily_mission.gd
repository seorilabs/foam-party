extends RefCounted

# Pure daily-mission selection. Deterministic in the date string: no RNG and no
# clock access. The godot layer supplies today's date and stores the result.

const GameConfig = preload("res://core/domain/game_config.gd")


# Returns {type, label, target, reward} for the given YYYY-MM-DD date. The label
# is already formatted with its target count.
static func mission_for(today: String) -> Dictionary:
	var pool: Array = GameConfig.DAILY_MISSION_POOL
	var day_hash := absi(today.hash())
	var pick := day_hash % pool.size()
	return _mission_result(pool[pick])


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


static func _mission_result(m: Dictionary) -> Dictionary:
	var target: int = m["target"]
	var requirement := maxi(0, int(m.get("requirement", 0)))
	var label_value := display_value(String(m["type"]), target, requirement)
	return {
		"type": m["type"],
		"target": target,
		"requirement": requirement,
		"label": m["label"] % label_value,
		"reward": reward_for_type(String(m["type"])),
	}


static func reward_for_type(mission_type: String) -> int:
	for mission in GameConfig.DAILY_MISSION_POOL:
		if String(mission["type"]) == mission_type:
			return maxi(int(mission.get("reward", GameConfig.DAILY_MISSION_REWARD)), GameConfig.DAILY_MISSION_REWARD)
	return GameConfig.DAILY_MISSION_REWARD
