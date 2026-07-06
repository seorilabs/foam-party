extends RefCounted

# Pure daily-mission selection. Deterministic in the date string: no RNG and no
# clock access. The godot layer supplies today's date and stores the result.

const GameConfig = preload("res://core/domain/game_config.gd")


# Returns {type, label, target} for the given YYYY-MM-DD date. The label is
# already formatted with its target count.
static func mission_for(today: String) -> Dictionary:
	var pool: Array = GameConfig.DAILY_MISSION_POOL
	var day_hash := absi(today.hash())
	var pick := day_hash % pool.size()
	var m: Dictionary = pool[pick]
	var target: int = m["target"]
	return {
		"type": m["type"],
		"target": target,
		"label": m["label"] % target,
	}
