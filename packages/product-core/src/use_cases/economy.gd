extends RefCounted

# Pure economy rules: coin rewards, milestone bonuses, upgrade multipliers, and
# purchase judgement. These decide *what should happen*; the godot layer keeps
# the actual coin mutation, save, and rollback.

const GameConfig = preload("res://core/domain/game_config.gd")


static func calc_coin_reward(stars: int, best_combo: int) -> int:
	# Medium economy tightening (~15% lower base income): scarcity comes from the
	# upgrade/skin sinks, and ad-watchers can recover the gap via the level-end
	# double-coins rewarded ad. Ad-free foam bombs (rewarded) keep the bomb cheap.
	return 16 + stars * 8 + min(best_combo, 10) * 2


static func calc_level_milestone_bonus(level: int) -> int:
	if level <= 0 or level % 5 != 0:
		return 0
	var step := int(level / 5)
	return 50 + step * 25


static func upgrade_mult(level: int) -> float:
	return GameConfig.UPGRADE_MULTS[clampi(level, 0, GameConfig.UPGRADE_MAX_LEVEL)]


static func upgrade_cost(idx: int, level: int) -> int:
	return GameConfig.UPGRADE_COSTS[idx][level]


static func can_buy_upgrade(idx: int, level: int, coins: int) -> bool:
	return level < GameConfig.UPGRADE_MAX_LEVEL and coins >= GameConfig.UPGRADE_COSTS[idx][level]


# Decide what a tap on a skin card should do without touching any state.
# Returns an intent dict {action: "buy"|"select"|"deny", cost: int, id: String}.
static func resolve_skin_purchase(catalog: Dictionary, tool: String, skin_idx: int, owned_skins: Dictionary, coins: int) -> Dictionary:
	var skins: Array = catalog.get(tool, [])
	if skin_idx < 0 or skin_idx >= skins.size():
		return {"action": "deny", "cost": 0, "id": ""}
	var skin: Dictionary = skins[skin_idx]
	var sid: String = skin["id"]
	var cost: int = skin["cost"]
	if owned_skins.get(sid, false):
		return {"action": "select", "cost": cost, "id": sid}
	if coins < cost:
		return {"action": "deny", "cost": cost, "id": sid}
	return {"action": "buy", "cost": cost, "id": sid}
