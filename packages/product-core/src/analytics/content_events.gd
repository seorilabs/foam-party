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
# Param VALUE TYPES are locked here and must match GA4 export column types.
# Numeric params (level, stars, time_sec, best_combo, coins_earned, cost, reward,
# bonus, unclaimed, streak) are emitted as native int so GA4 exports them under
# int_value/double_value — a prerequisite for registering GA4 custom metrics and
# for aggregating without CAST. Identifier/enum params (mission_type, source,
# car_type, skin_id, tool, placement) and boolean flags stay strings. Sending a
# key as int now, after it was historically logged as string, causes a one-time
# int↔string split in BigQuery for that key; this is accepted on the current small
# sample (see #246) so downstream metrics are correct going forward.

# ── Event names ─────────────────────────────────────────────────────────────
const GAME_START := "game_start"
const LEVEL_START := "level_start"
const LEVEL_COMPLETE := "level_complete"
const LEVEL_ABANDON := "level_abandon"
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
	LEVEL_ABANDON,
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

# level_abandon reason enum — the in-game exit path the player took while a level
# attempt was still incomplete. Locked here so the game and the metrics sink agree
# on the exact string values.
const REASON_PAUSE_HOME := "pause_home"          # pause → 홈(타이틀) 복귀
const REASON_PAUSE_RESTART := "pause_restart"    # pause → 현재 레벨 재시작
const REASON_QUIT_CONFIRM := "quit_confirm"      # 종료 확인 → 앱 종료
const REASON_APP_BACKGROUND := "app_background"  # 앱 백그라운드/종료 요청(시도당 1회)


# ── Builders — each returns {"name": String, "params": Dictionary} ──────────
# The engine layer calls these then forwards the result through the port; it
# never assembles event params inline (that is what let the taxonomy drift).

static func game_start(level: int) -> Dictionary:
	return _event(GAME_START, {"level": level})


static func level_start(level: int, car_type: String) -> Dictionary:
	return _event(LEVEL_START, {"level": level, "car_type": car_type})


static func level_complete(
	level: int, stars: int, time_sec: int, best_combo: int, coins_earned: int, new_record: bool
) -> Dictionary:
	return _event(LEVEL_COMPLETE, {
		"level": level,
		"stars": stars,
		"time_sec": time_sec,
		"best_combo": best_combo,
		"coins_earned": coins_earned,
		"new_record": str(new_record),  # boolean flag stays a string ("true"/"false")
	})


# Fired when the player leaves an in-progress level attempt without completing it.
# `reason` is one of the REASON_* enums; `progress_pct` is the wash completion at
# exit time (0~100 int, from clean_progress) and `elapsed_sec` the level time in
# whole seconds. Numeric params stay native int so GA4 exports int_value.
static func level_abandon(level: int, reason: String, progress_pct: int, elapsed_sec: int) -> Dictionary:
	return _event(LEVEL_ABANDON, {
		"level": level,
		"reason": reason,
		"progress_pct": progress_pct,
		"elapsed_sec": elapsed_sec,
	})


static func foam_bomb_use(level: int, is_ad: bool, coin_cost: int) -> Dictionary:
	# Ad-sourced bombs cost no coins → report cost 0 so the economy sink can sum
	# coin_cost across all foam_bomb_use rows without double counting ad grants.
	return _event(FOAM_BOMB_USE, {
		"level": level,
		"source": SOURCE_AD if is_ad else SOURCE_COINS,
		"cost": 0 if is_ad else coin_cost,
	})


# `placement` marks which surface the claim happened on (main HUD vs level-result
# screen) so the retention analysis can see which exposure drives claims. Empty
# string when the surface is unknown; the key is always present to keep the
# BigQuery column type stable.
static func daily_mission_claim(mission_type: String, reward: int, placement: String = "") -> Dictionary:
	return _event(DAILY_MISSION_CLAIM, {
		"mission_type": mission_type,
		"reward": reward,
		"placement": placement,
	})


# Impression of the daily-mission widget on a given surface (main|result). `unclaimed`
# is how many of today's missions are still unclaimed at view time and `streak` the
# current attendance streak, so exposure can be correlated with later claims.
static func daily_mission_view(placement: String, unclaimed: int, streak: int) -> Dictionary:
	return _event(DAILY_MISSION_VIEW, {
		"placement": placement,
		"unclaimed": unclaimed,
		"streak": streak,
	})


static func upgrade_purchase(tool: String, level: int, cost: int) -> Dictionary:
	return _event(UPGRADE_PURCHASE, {"tool": tool, "level": level, "cost": cost})


static func skin_select(tool: String, skin_id: String) -> Dictionary:
	return _event(SKIN_SELECT, {"tool": tool, "skin_id": skin_id})


static func skin_purchase(tool: String, skin_id: String, cost: int) -> Dictionary:
	return _event(SKIN_PURCHASE, {"tool": tool, "skin_id": skin_id, "cost": cost})


# Level-end rewarded "double coins": the player watched an ad to double the coins
# earned that level. `bonus` is the extra coins granted (equal to the base
# level reward), so the economy sink can sum ad-driven coin issuance separately.
static func reward_double_coins(level: int, bonus: int) -> Dictionary:
	return _event(REWARD_DOUBLE_COINS, {"level": level, "bonus": bonus})


static func _event(name: String, params: Dictionary) -> Dictionary:
	return {"name": name, "params": params}
