extends RefCounted

# Pure rules for selecting and rewarding the rare cleanup target. Presentation,
# coin mutation, and audio stay in the Godot adapter.

const GameConfig = preload("res://core/domain/game_config.gd")


static func spawn_index(level: int, patch_count: int, seed: int) -> int:
	if patch_count <= 0 or GameConfig.GOLD_SPOT_REWARD_CAP_PER_LEVEL <= 0:
		return -1
	var safe_level := maxi(level, 1)
	var roll := absi(seed * 48271 + safe_level * 69621) % 100
	if roll >= clampi(GameConfig.GOLD_SPOT_SPAWN_PERCENT, 0, 100):
		return -1
	var index_seed := absi(seed * 1103515245 + safe_level * 12345)
	return index_seed % patch_count


static func reward_for_removal(is_gold_spot: bool, rewards_granted: int) -> int:
	if not is_gold_spot or rewards_granted >= GameConfig.GOLD_SPOT_REWARD_CAP_PER_LEVEL:
		return 0
	return maxi(GameConfig.GOLD_SPOT_BONUS_COINS, 0)
