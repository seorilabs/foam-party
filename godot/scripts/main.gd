extends Control

const DESIGN_SIZE := Vector2(390.0, 844.0)
const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const DIRT_TYPES := ["mud", "dust", "leaf", "oil", "bug"]
const CAR_TYPES := ["compact", "sports", "truck"]
const CLEAN_DAMAGE_RATE := 72.0
const AUDIO_MIX_RATE := 22050
const POP_NOTES := [523.25, 659.25, 783.99, 880.0, 1046.5]
const COMBO_WINDOW := 2.5
const STAR3_TIME := 75.0
const STAR3_COMBO := 4
const STAR2_TIME := 140.0
const STAR_WARN_SECONDS := 15.0
const GRADE_SLOT_EARNED := "earned"
const GRADE_SLOT_TARGET := "target"
const GRADE_SLOT_LOCKED := "locked"
const BAR_COL_START := Color(0.286, 0.655, 1.0)   # #49a7ff
const BAR_COL_END   := Color(0.224, 0.851, 0.541)  # #39d98a
const SAVE_PATH := "user://foam_party_save.cfg"
const DAILY_SAVE_PATH := "user://foam_party_daily.cfg"
const BOMB_COST := 40
const UPGRADE_COSTS := [[80, 160, 280], [80, 160, 280], [80, 160, 280]]
const UPGRADE_MULTS := [1.0, 1.3, 1.6, 2.0]
const UPGRADE_KEYS := ["water", "soap", "sponge"]
const UPGRADE_NAMES := ["Water Power", "Soap Power", "Sponge Power"]
const UPGRADE_DESCS := ["Scrubs mud & dust faster", "Loosens stains faster", "Wipes faster"]
const UPGRADE_MAX_LEVEL := 3
const STATE_TITLE := "title"
const STATE_PLAYING := "playing"
const GAMEPLAY_SCALE := 1.16
const GAMEPLAY_PIVOT := Vector2(195.0, 545.0)
const GAMEPLAY_OFFSET := Vector2(0.0, 0.0)
const HUD_TOP_Y := 12.0
const HUD_SAFE_PADDING := 8.0
const TOP_BUTTON_Y := 104.0
const TOP_BUTTON_SAFE_PADDING := 12.0
const TOOLBAR_Y := 744.0
const TOOL_BUTTON_Y := 764.0
const TOOL_BUTTON_HEIGHT := 72.0
const TOOL_BUTTON_BOTTOM_PADDING := 12.0
const TOOLBAR_TOP_GAP := 20.0
const STATE_STUCK := "stuck"
const STATE_WET := "wet"
const STATE_SOAPED := "soaped"
const STATE_LOOSENED := "loosened"
const STATE_RUNOFF := "runoff"
const STATE_FLYING := "flying"
const STATE_REMOVED := "removed"
const STYLE_DROPLET := "droplet"
const STYLE_RING := "ring"
const STYLE_MIST := "mist"
const STYLE_STREAK := "streak"
const STYLE_SWIRL := "swirl"
const STYLE_BUBBLE := "bubble"
const STYLE_FOAM := "foam"
const STYLE_SPARKLE := "sparkle"
const STYLE_CONFETTI := "confetti"
const DAILY_MISSION_POOL := [
	{"type": "leaf", "label": "낙엽 %d개 날리기", "target": 20},
	{"type": "dust", "label": "먼지 %d개 제거하기", "target": 20},
	{"type": "mud", "label": "흙탕물 %d개 씻기", "target": 15},
	{"type": "oil", "label": "오일 %d개 청소하기", "target": 15},
	{"type": "bug", "label": "벌레 자국 %d개 닦기", "target": 12},
]
const DAILY_MISSION_REWARD := 50
