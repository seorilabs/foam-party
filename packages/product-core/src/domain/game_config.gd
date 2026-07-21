extends RefCounted

# Pure gameplay tuning constants shared by the product-core rules. These are the
# numbers that define how the game plays (scoring thresholds, economy costs,
# daily mission pool, dirt/car catalogs) and carry no presentation or engine
# dependency. Presentation/layout/audio constants stay in the godot layer.

const STAR3_TIME := 75.0
const STAR3_COMBO := 4
# Third-star combo gate grows by one every three levels and stops at ten.
const STAR3_COMBO_LEVEL_STEP := 3
const STAR3_COMBO_MAX := 10
const STAR2_TIME := 140.0
# Washing progress offsets this fraction of elapsed-time pressure at 100%
# cleanliness. The customer still reaches zero patience after a longer idle.
const PATIENCE_PROGRESS_WEIGHT := 0.65
const STAR_WARN_SECONDS := 15.0
const COMBO_WINDOW := 2.5
const COMBO_GRACE := 1.0
const CLEAN_DAMAGE_RATE := 72.0

# Tool/dirt mutation rates are data, while wash_rules.gd owns state transitions
# and formulas. Keeping every shipped dirt kind explicit makes a balance change a
# config-only edit and prevents a new kind from silently inheriting another rate.
# Wrong-tool DPS stays at 4% of the slowest valid preparation coefficient.
const MISAPPLIED_DAMAGE_COEFFICIENT := 0.002
const RUNOFF_CLEANUP_PROFILES := {
	"mud": {"base": 0.42, "wetness": 0.25},
	"dust": {"base": 0.42, "wetness": 0.25},
	"oil": {"soap": 0.18, "looseness": 0.32},
	"bug": {"soap": 0.18, "looseness": 0.32},
	"poop": {"soap": 0.22, "looseness": 0.28},
	"road_grime": {"soap": 0.10, "looseness": 0.14},
	"sap": {"base": 0.0},
	"leaf": {"base": 0.08},
	"_default": {"base": 0.08},
}
const AIR_WASH_PROFILES := {
	"mud": {"looseness": 0.08},
	"dust": {"looseness": 2.2, "damage": 2.15},
	"leaf": {"looseness": 2.2, "damage": 2.85},
	"oil": {"looseness": 0.08},
	"bug": {"looseness": 0.08},
	"poop": {"looseness": 0.08},
	"road_grime": {"looseness": 0.08},
	"sap": {"looseness": 0.0},
	"_default": {"looseness": 0.08},
}
const AIR_MOTION_PROFILE := {
	"base_speed": 235.0,
	"radius_speed": 3.5,
	"velocity_response": 9.0,
	"heavy_drift": 7.0,
	"heavy_drift_limit": 5.5,
}
const WATER_WETNESS_RATE := 1.85
const WATER_RUNOFF_RATE := 0.8
const WATER_LEAF_PUSH_VELOCITY := Vector2(12.0, 36.0)
const WATER_WASH_PROFILES := {
	"mud": {"runoff_wetness": 0.3, "looseness": 1.1, "damage": 2.25},
	"dust": {"looseness": 1.0, "damage": 1.85},
	"leaf": {"damage": 0.25},
	"oil": {
		"rinse_power_threshold": 0.25, "rinse_base": 0.75, "rinse_looseness": 1.0,
		"prepared_damage": 1.75, "prepared_looseness": 0.55, "prepared_soap_decay": 0.45,
		"dry_damage": 0.08, "dry_soap_decay": 0.12,
	},
	"bug": {
		"rinse_power_threshold": 0.25, "rinse_base": 0.75, "rinse_looseness": 1.0,
		"prepared_damage": 1.75, "prepared_looseness": 0.55, "prepared_soap_decay": 0.45,
		"dry_damage": 0.08, "dry_soap_decay": 0.12,
	},
	"poop": {
		"prepared_soap_threshold": 0.25, "rinse_soap_floor": 0.3,
		"rinse_base": 0.9, "rinse_looseness": 0.5, "prepared_damage": 2.2,
		"prepared_looseness": 0.45, "prepared_soap_decay": 0.55, "dry_damage": 0.04,
	},
	"road_grime": {"looseness": 0.75, "damage": 0.28},
	# Water beads on the resin but cannot soften or remove it.
	"sap": {"damage": 0.0},
	"_default": {"damage": 0.45},
}
const SOAP_WASH_PROFILES := {
	"mud": {"soap_build": 0.85, "looseness": 0.42, "damage": 0.12},
	"dust": {"soap_build": 0.25, "soap_cap": 0.45},
	"leaf": {"soap_build": 0.25, "soap_cap": 0.45},
	"oil": {"loosened_threshold": 0.65, "soap_build": 1.65, "looseness": 0.95, "damage": 0.05},
	"bug": {"loosened_threshold": 0.65, "soap_build": 1.65, "looseness": 0.95, "damage": 0.05},
	"poop": {"loosened_threshold": 0.5, "soap_build": 2.0, "looseness": 1.2, "damage": 0.06},
	"road_grime": {"loosened_threshold": 0.45, "soap_build": 1.25, "looseness": 0.8, "damage": 0.06},
	"sap": {"loosened_threshold": 0.45, "soap_build": 1.5, "looseness": 1.0, "damage": 0.0},
	"_default": {"soap_build": 0.25, "soap_cap": 0.45},
}
const SPONGE_WASH_PROFILES := {
	"mud": {"wetness_threshold": 0.2, "soap_threshold": 0.15, "prepared_damage": 1.15, "dry_damage": 0.35},
	"dust": {"damage": 0.45},
	"leaf": {"damage": 0.2},
	"oil": {
		"soap_threshold": 0.25, "looseness_threshold": 0.35,
		"prepared_looseness": 1.2, "prepared_base": 1.15, "soap_bonus": 1.0,
		"soap_decay": 0.22, "dry_damage": 0.12,
	},
	"bug": {
		"soap_threshold": 0.25, "looseness_threshold": 0.35,
		"prepared_looseness": 1.2, "prepared_base": 1.15, "soap_bonus": 1.0,
		"soap_decay": 0.22, "dry_damage": 0.12,
	},
	"poop": {
		"soap_threshold": 0.25, "looseness_threshold": 0.35,
		"prepared_looseness": 0.8, "prepared_base": 0.8, "soap_bonus": 0.6,
		"soap_decay": 0.18, "dry_damage": 0.08,
	},
	"road_grime": {
		"wetness_threshold": 0.2, "soap_threshold": 0.15, "looseness_threshold": 0.35,
		"prepared_looseness": 1.25, "prepared_base": 1.2,
		"soap_bonus": 0.55, "wetness_bonus": 0.25, "soap_decay": 0.18,
		"dry_damage": 0.12,
	},
	"sap": {
		"soap_threshold": 0.25, "looseness_threshold": 0.45,
		"prepared_looseness": 1.1, "prepared_base": 1.15,
		"soap_bonus": 0.75, "soap_decay": 0.20, "dry_damage": 0.0,
	},
	"_default": {},
}
const SPONGE_MOTION_PROFILE := {
	"drift": 3.0,
	"drift_limit": 7.0,
}
# Completion rewards keep a 24-coin floor for a one-star, no-combo clear while
# extending skill payout through combo 15. A foam bomb costs about 3.3 of those
# baseline clears; stronger combo/perfect play intentionally shortens that path.
const COIN_REWARD_BASE := 16
const COIN_REWARD_PER_STAR := 8
const COIN_REWARD_PER_COMBO := 2
const COIN_REWARD_COMBO_CAP := 15
const BOMB_COST := 80
# Ten seconds is long enough for one focused rinse pass without becoming a
# permanent upgrade. The 1.5x radius and power share one readable tuning ratio,
# while the higher coin price keeps the instant full-board bomb distinct.
const WATER_BOOST_COST := 60
const WATER_BOOST_DURATION := 10.0
const WATER_BOOST_RADIUS_MULT := 1.5
const WATER_BOOST_POWER_MULT := 1.5
# Rewarded ad grants at most this many free foam bombs per level; beyond the cap
# the bomb falls back to the coin price so ad inventory is not farmed endlessly.
const FREE_AD_BOMB_PER_LEVEL := 3
# Rare cleanup target: one deterministic roll per level, one possible target,
# and one small payout keep the discovery moment from inflating the economy.
const GOLD_SPOT_SPAWN_PERCENT := 25
const GOLD_SPOT_BONUS_COINS := 8
const GOLD_SPOT_REWARD_CAP_PER_LEVEL := 1
# Preserve the 1,800-coin full-upgrade sink while pricing each tool by its
# gameplay reach: broad water is premium, setup soap is the baseline, and the
# narrower finishing sponge is the accessible track.
const UPGRADE_COSTS := [
	[110, 230, 380],
	[90, 190, 320],
	[70, 150, 260],
]
const UPGRADE_MULTS := [1.0, 1.3, 1.6, 2.0]
const UPGRADE_KEYS := ["water", "soap", "sponge"]
const UPGRADE_MAX_LEVEL := 3
const UPGRADE_NAMES := ["고압수 강화", "비누 강화", "스펀지 강화"]
const UPGRADE_DESCS := ["흙탕물·먼지 제거 속도 향상", "얼룩 분리 속도 향상", "닦는 속도 향상"]
const DAILY_MISSION_REWARD := 50
const DAILY_MISSION_POOL := [
	{"type": "leaf", "label": "낙엽 %d개 날리기", "target": 20, "reward": 50},
	{"type": "dust", "label": "먼지 %d개 제거하기", "target": 20, "reward": 55},
	{"type": "mud", "label": "흙탕물 %d개 씻기", "target": 15, "reward": 60},
	{"type": "oil", "label": "오일 %d개 청소하기", "target": 15, "reward": 70},
	{"type": "bug", "label": "벌레 자국 %d개 닦기", "target": 12, "reward": 75},
	{"type": "poop", "label": "새똥 %d개 닦기", "target": 10, "reward": 80},
	{"type": "road_grime", "label": "도로 때 %d개 닦기", "target": 8, "reward": 85},
	{"type": "combo", "label": "한 판에서 콤보 x%d 달성", "target": 1, "requirement": 8, "reward": 90},
	{"type": "fast", "label": "%d초 이내 세차 완료", "target": 1, "requirement": 75, "reward": 95},
	{"type": "perfect3", "label": "별 3개 세차 %d회", "target": 2, "requirement": 3, "reward": 100},
]
# Intermediate eight/twelve milestones keep feedback and instant rewards moving
# between the five-point beats; combo 20 remains the final one-shot milestone.
const COMBO_BONUS_AMOUNTS := {5: 5, 8: 8, 10: 10, 12: 12, 15: 15, 20: 20}
const DIRT_TYPES := ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime", "sap"]
# Early levels introduce tool-matching rules gradually. The value is the first
# playable level where each dirt kind may appear; level 5 converges to the full
# catalog used by the existing per-car weighted pools.
const DIRT_UNLOCK_LEVELS := {
	"mud": 1,
	"dust": 1,
	"leaf": 1,
	"oil": 2,
	"bug": 3,
	"poop": 3,
	"road_grime": 4,
	"sap": 5,
}
const CAR_TYPES := ["compact", "sports", "truck", "van", "offroad"]


static func car_type_for_level(level: int) -> String:
	var safe_level := maxi(1, level)
	return CAR_TYPES[(safe_level - 1) % CAR_TYPES.size()]
