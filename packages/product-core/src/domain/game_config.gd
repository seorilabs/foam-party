extends RefCounted

# Pure gameplay tuning constants shared by the product-core rules. These are the
# numbers that define how the game plays (scoring thresholds, economy costs,
# daily mission pool, dirt/car catalogs) and carry no presentation or engine
# dependency. Presentation/layout/audio constants stay in the godot layer.

const STAR3_TIME := 75.0
const STAR3_COMBO := 4
const STAR2_TIME := 140.0
const STAR_WARN_SECONDS := 15.0
const COMBO_WINDOW := 2.5
const CLEAN_DAMAGE_RATE := 72.0
const BOMB_COST := 40
# Rewarded ad grants at most this many free foam bombs per level; beyond the cap
# the bomb falls back to the coin price so ad inventory is not farmed endlessly.
const FREE_AD_BOMB_PER_LEVEL := 3
const UPGRADE_COSTS := [[90, 190, 320], [90, 190, 320], [90, 190, 320]]
const UPGRADE_MULTS := [1.0, 1.3, 1.6, 2.0]
const UPGRADE_KEYS := ["water", "soap", "sponge"]
const UPGRADE_MAX_LEVEL := 3
const UPGRADE_NAMES := ["고압수 강화", "비누 강화", "스펀지 강화"]
const UPGRADE_DESCS := ["흙탕물·먼지 제거 속도 향상", "얼룩 분리 속도 향상", "닦는 속도 향상"]
const DAILY_MISSION_POOL := [
	{"type": "leaf", "label": "낙엽 %d개 날리기", "target": 20},
	{"type": "dust", "label": "먼지 %d개 제거하기", "target": 20},
	{"type": "mud", "label": "흙탕물 %d개 씻기", "target": 15},
	{"type": "oil", "label": "오일 %d개 청소하기", "target": 15},
	{"type": "bug", "label": "벌레 자국 %d개 닦기", "target": 12},
	{"type": "poop", "label": "새똥 %d개 닦기", "target": 10},
	{"type": "road_grime", "label": "도로 때 %d개 닦기", "target": 8},
]
const DAILY_MISSION_REWARD := 50
const COMBO_BONUS_AMOUNTS := {5: 5, 10: 10, 15: 15, 20: 20}
const DIRT_TYPES := ["mud", "dust", "leaf", "oil", "bug", "poop", "road_grime"]
# Early levels introduce tool-matching rules gradually. The value is the first
# playable level where each dirt kind may appear; level 4 converges to the full
# catalog used by the existing per-car weighted pools.
const DIRT_UNLOCK_LEVELS := {
	"mud": 1,
	"dust": 1,
	"leaf": 1,
	"oil": 2,
	"bug": 3,
	"poop": 3,
	"road_grime": 4,
}
const CAR_TYPES := ["compact", "sports", "truck"]
