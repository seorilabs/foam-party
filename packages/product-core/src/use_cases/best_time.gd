extends RefCounted

# Pure best-time (per level) rules. The godot layer owns the map write, the sfx,
# and the record-pop animation timestamp.

static func is_new_record(prev: float, t: float) -> bool:
	return prev <= 0.0 or t < prev


static func best_time(map: Dictionary, level: int) -> float:
	return float(map.get(level, 0.0))
