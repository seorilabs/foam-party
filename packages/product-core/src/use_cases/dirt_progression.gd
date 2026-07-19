extends RefCounted

const GameConfig = preload("res://core/domain/game_config.gd")


static func allowed_types_for_level(level: int) -> Array[String]:
	var allowed: Array[String] = []
	var playable_level := maxi(1, level)
	for raw_kind in GameConfig.DIRT_TYPES:
		var kind := String(raw_kind)
		var unlock_level := int(GameConfig.DIRT_UNLOCK_LEVELS.get(kind, 1))
		if playable_level >= unlock_level:
			allowed.append(kind)
	return allowed


# Preserve the duplicate entries that express each car's dirt bias while
# removing kinds that have not been introduced yet.
static func filter_pool_for_level(source_pool: Array, level: int) -> Array[String]:
	var allowed := allowed_types_for_level(level)
	var filtered: Array[String] = []
	for raw_kind in source_pool:
		var kind := String(raw_kind)
		if kind in allowed:
			filtered.append(kind)
	if filtered.is_empty():
		return allowed
	return filtered
