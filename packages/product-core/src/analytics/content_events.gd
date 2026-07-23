extends RefCounted

# Content analytics catalog — the single source of truth for foam-party's
# content-level event names and their parameter shapes. Pure core seam: no
# engine, no analytics SDK, no platform types.
#
# The engine layer builds an event with these helpers and forwards
# {name, params} through the AnalyticsPort seam
# (res://core/ports/analytics_port.gd). Keeping the taxonomy here means every
# content event has ONE locked schema that the backoffice aggregation depends
# on, and a future self-hosted metrics sink reads the exact same contract.
#
# Param values are stringified at this boundary. Downstream analytics params are
# strings/numbers; keeping them strings gives the daily BigQuery aggregation a
# stable column type per key (int-vs-string drift breaks GROUP BY).

# ── Event names ─────────────────────────────────────────────────────────────
const GAME_START := "game_start"
const LEVEL_START := "level_start"
const LEVEL_COMPLETE := "level_complete"
const FOAM_BOMB_USE := "foam_bomb_use"
const DAILY_MISSION_CLAIM := "daily_mission_claim"
const DAILY_MISSION_VIEW := "daily_mission_view"
const UPGRADE_PURCHASE := "upgrade_purchase"
const SKIN_SELECT := "skin_select"
const SKIN_PURCHASE := "skin_purchase"
const REWARD_DOUBLE_COINS := "reward_double_coins"

# Full catalog — used by tests and as the backoffice contract snapshot.
const ALL := [
	GAME_START,
	LEVEL_START,
	LEVEL_COMPLETE,
	FOAM_BOMB_USE,
	DAILY_MISSION_CLAIM,
	DAILY_MISSION_VIEW,
	UPGRADE_PURCHASE,
	SKIN_SELECT,
	SKIN_PURCHASE,
	REWARD_DOUBLE_COINS,
]

# Foam-bomb coin/ad source labels — shared so the sink and the game agree.
const SOURCE_AD := "ad"
const SOURCE_COINS := "coins"


# ── Builders — each returns {"name": String, "params": Dictionary} ──────────
# The engine layer calls these then forwards the result through the port; it
# never assembles event params inline (that is what let the taxonomy drift).

static func game_start(level: int) -> Dictionary:
	return _event(GAME_START, {"level": str(level)})


static func level_start(level: int, car_type: String) -> Dictionary:
	return _event(LEVEL_START, {"level": str(level), "car_type": car_type})


static func level_complete(
	level: int, stars: int, time_sec: int, best_combo: int, coins_earned: int, new_record: bool
) -> Dictionary:
	return _event(LEVEL_COMPLETE, {
		"level": str(level),
		"stars": str(stars),
		"time_sec": str(time_sec),
		"best_combo": str(best_combo),
		"coins_earned": str(coins_earned),
		"new_record": str(new_record),
	})


static func foam_bomb_use(level: int, is_ad: bool, coin_cost: int) -> Dictionary:
	# Ad-sourced bombs cost no coins → report cost 0 so the economy sink can sum
	# coin_cost across all foam_bomb_use rows without double counting ad grants.
	return _event(FOAM_BOMB_USE, {
		"level": str(level),
		"source": SOURCE_AD if is_ad else SOURCE_COINS,
		"cost": str(0 if is_ad else coin_cost),
	})


# `placement` marks which surface the claim happened on (main HUD vs level-result
# screen) so the retention analysis can see which exposure drives claims. Empty
# string when the surface is unknown; the key is always present to keep the
# BigQuery column type stable.
static func daily_mission_claim(mission_type: String, reward: int, placement: String = "") -> Dictionary:
	return _event(DAILY_MISSION_CLAIM, {
		"mission_type": mission_type,
		"reward": str(reward),
		"placement": placement,
	})


# Impression of the daily-mission widget on a given surface (main|result). `unclaimed`
# is how many of today's missions are still unclaimed at view time and `streak` the
# current attendance streak, so exposure can be correlated with later claims.
static func daily_mission_view(placement: String, unclaimed: int, streak: int) -> Dictionary:
	return _event(DAILY_MISSION_VIEW, {
		"placement": placement,
		"unclaimed": str(unclaimed),
		"streak": str(streak),
	})


static func upgrade_purchase(tool: String, level: int, cost: int) -> Dictionary:
	return _event(UPGRADE_PURCHASE, {"tool": tool, "level": str(level), "cost": str(cost)})


static func skin_select(tool: String, skin_id: String) -> Dictionary:
	return _event(SKIN_SELECT, {"tool": tool, "skin_id": skin_id})


static func skin_purchase(tool: String, skin_id: String, cost: int) -> Dictionary:
	return _event(SKIN_PURCHASE, {"tool": tool, "skin_id": skin_id, "cost": str(cost)})


# Level-end rewarded "double coins": the player watched an ad to double the coins
# earned that level. `bonus` is the extra coins granted (equal to the base
# level reward), so the economy sink can sum ad-driven coin issuance separately.
static func reward_double_coins(level: int, bonus: int) -> Dictionary:
	return _event(REWARD_DOUBLE_COINS, {"level": str(level), "bonus": str(bonus)})


static func _event(name: String, params: Dictionary) -> Dictionary:
	return {"name": name, "params": params}
