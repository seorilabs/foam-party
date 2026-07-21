extends RefCounted

# Pure economy rules: coin rewards, milestone bonuses, upgrade multipliers, and
# purchase judgement. These decide *what should happen*; the godot layer keeps
# the actual coin mutation, save, and rollback.

const GameConfig = preload("res://core/domain/game_config.gd")


static func calc_coin_reward(stars: int, best_combo: int) -> int:
	var rewarded_combo := clampi(best_combo, 0, GameConfig.COIN_REWARD_COMBO_CAP)
	return (
		GameConfig.COIN_REWARD_BASE
		+ stars * GameConfig.COIN_REWARD_PER_STAR
		+ rewarded_combo * GameConfig.COIN_REWARD_PER_COMBO
	)


static func calc_customer_tip(patience: float, payout_ratio: float = 1.0) -> int:
	var bounded_patience := clampf(patience, 0.0, 1.0)
	var full_tip := mini(
		floori(bounded_patience * GameConfig.PATIENCE_TIP_COINS_PER_FULL_PATIENCE),
		GameConfig.PATIENCE_TIP_MAX_COINS
	)
	# Rewash reduction is applied after the full tip is capped. Issue #84 can
	# therefore share its completion payout ratio without duplicating this rule.
	return floori(float(full_tip) * clampf(payout_ratio, 0.0, 1.0))


static func perfect_wash_bonus(stars: int) -> int:
	if stars <= 0:
		return 0
	return 5 + clampi(stars, 1, 3) * 5


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
	return _resolve_catalog_purchase(catalog, tool, skin_idx, owned_skins, coins, true)


static func resolve_flat_item_purchase(catalog: Dictionary, tool: String, item_idx: int, owned_items: Dictionary, coins: int) -> Dictionary:
	return _resolve_catalog_purchase(catalog, tool, item_idx, owned_items, coins, false)


static func skin_ownership_key(tool: String, skin_id: String) -> String:
	return "%s:%s" % [tool, skin_id]


static func is_skin_owned(owned_skins: Dictionary, tool: String, skin_id: String) -> bool:
	return bool(owned_skins.get(skin_ownership_key(tool, skin_id), false))


static func default_skin_ownership(catalog: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tool in catalog:
		for raw_skin in catalog[tool]:
			var skin: Dictionary = raw_skin
			if int(skin.get("cost", 0)) <= 0:
				result[skin_ownership_key(String(tool), String(skin["id"]))] = true
	return result


# New saves use tool:skin keys. Legacy flat ids are migrated without repeating
# shared purchases: unique ids map to their only tool, while a shared paid id
# maps only to tools that had it selected. Free classic remains owned everywhere.
static func normalize_skin_ownership(catalog: Dictionary, raw_owned: Dictionary, selected_by_tool: Dictionary) -> Dictionary:
	var result := default_skin_ownership(catalog)
	for raw_key in raw_owned:
		if not bool(raw_owned[raw_key]):
			continue
		var stored_key := String(raw_key)
		if stored_key.contains(":"):
			var parts := stored_key.split(":", false, 1)
			if parts.size() == 2 and _catalog_has_skin(catalog, String(parts[0]), String(parts[1])):
				result[skin_ownership_key(String(parts[0]), String(parts[1]))] = true
			continue
		var matching_tools: Array[String] = []
		for tool in catalog:
			if _catalog_has_skin(catalog, String(tool), stored_key):
				matching_tools.append(String(tool))
		if matching_tools.size() == 1:
			result[skin_ownership_key(matching_tools[0], stored_key)] = true
		elif matching_tools.size() > 1:
			for tool in matching_tools:
				if String(selected_by_tool.get(tool, "classic")) == stored_key:
					result[skin_ownership_key(tool, stored_key)] = true
	return result


static func _resolve_catalog_purchase(catalog: Dictionary, tool: String, item_idx: int, owned_items: Dictionary, coins: int, scoped_by_tool: bool) -> Dictionary:
	var skins: Array = catalog.get(tool, [])
	if item_idx < 0 or item_idx >= skins.size():
		return {"action": "deny", "cost": 0, "id": ""}
	var skin: Dictionary = skins[item_idx]
	var sid: String = skin["id"]
	var cost: int = skin["cost"]
	var ownership_key := skin_ownership_key(tool, sid) if scoped_by_tool else sid
	if owned_items.get(ownership_key, false):
		return {"action": "select", "cost": cost, "id": sid}
	if coins < cost:
		return {"action": "deny", "cost": cost, "id": sid}
	return {"action": "buy", "cost": cost, "id": sid}


static func _catalog_has_skin(catalog: Dictionary, tool: String, skin_id: String) -> bool:
	for raw_skin in catalog.get(tool, []):
		if String((raw_skin as Dictionary).get("id", "")) == skin_id:
			return true
	return false
