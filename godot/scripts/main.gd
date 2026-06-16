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

class DirtPatch:
	var kind: String
	var position: Vector2
	var radius: float
	var health: float
	var max_health: float
	var soap: float = 0.0
	var wetness: float = 0.0
	var looseness: float = 0.0
	var runoff: float = 0.0
	var seed_offset: float
	var drift: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var state: String = "stuck"
	var resist_time: float = 0.0
	var hint_time: float = 0.0
	var hint_tool: String = ""

	func _init(new_kind: String, new_position: Vector2, new_radius: float, new_health: float, new_seed: float) -> void:
		kind = new_kind
		position = new_position
		radius = new_radius
		health = new_health
		max_health = new_health
		seed_offset = new_seed


class WashParticle:
	var position: Vector2
	var velocity: Vector2
	var ttl: float
	var radius: float
	var color: Color
	var style: String

	func _init(new_position: Vector2, new_velocity: Vector2, new_ttl: float, new_radius: float, new_color: Color, new_style: String) -> void:
		position = new_position
		velocity = new_velocity
		ttl = new_ttl
		radius = new_radius
		color = new_color
		style = new_style


var selected_tool: String = TOOL_WATER
var dirt_patches: Array = []
var particles: Array = []
var rng := RandomNumberGenerator.new()
var sfx_rng := RandomNumberGenerator.new()
var is_washing := false
var pointer_position := Vector2.ZERO
# Velocity-scaled smear left behind the active tool while scrubbing. Gives the
# core drag gesture a sense of weight: faster sweeps paint a longer, brighter
# tool-tinted streak, so the player feels the effort of "really scrubbing".
var wash_trail: Array = []
var wash_speed := 0.0
var _trail_last_pos := Vector2.ZERO
var _trail_has_last := false
const TRAIL_LIFETIME := 0.4
const TRAIL_MIN_GAP := 7.0
const TRAIL_MAX_POINTS := 16
const COMBO_BONUS_AMOUNTS := {5: 5, 10: 10, 15: 15, 20: 20}
var clean_progress := 0.0
var initial_dirt_total := 1.0
var level_index := 1
var completed := false
var completion_burst_done := false
var _gleam_time := -1.0
const GLEAM_DURATION := 0.72
var _progress_milestone_hit := 0
var _progress_milestone_time := -1.0
var _progress_milestone_text := ""
var _progress_milestone_color := Color.WHITE
var combo_count := 0
var combo_timer := 0.0
var _halo_phase := 0.0
var best_combo := 0
var _combo_bonus_time := -10.0
var _combo_bonus_amount := 0
var level_time := 0.0
var earned_stars := 0
var combo_pop_time := -10.0
var _combo_milestone_flash_time := -10.0
var _combo_milestone_flash_color := Color.WHITE
var _combo_milestone_fanfare := ""
var _combo_milestone_count := 0
var _customer_cheer_text := ""
var _customer_cheer_time := -10.0
var best_times: Dictionary = {}
var is_new_record := false
var record_pop_time := -10.0
var _tool_select_time := -10.0
var _bomb_press_time := -10.0
var game_state := STATE_TITLE
var coins := 0
var total_stars := 0
var coin_reward := 0
var _star_reveal_times: Array[float] = [-10.0, -10.0, -10.0]
const STAR_REVEAL_DELAYS: Array[float] = [0.3, 0.75, 1.25]
const STAR_REVEAL_POP_DUR := 0.5
var sound_enabled := true
var tutorial_seen := false
var show_tutorial := false
var persistence_enabled := true
var last_particle_spawn := 0.0
var car_color := Color("#ffcf5a")
var car_type := "compact"
var car_type_labels := {
	"compact": "City",
	"sports": "Sport",
	"truck": "Truck",
}
var canvas_origin := Vector2.ZERO
var canvas_scale := 1.0
var ui_font: Font
var bgm_player: AudioStreamPlayer
var tool_loop_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var completion_sfx_player: AudioStreamPlayer
var active_tool_sound := ""
var audio_playback_enabled := true

var daily_mission_type := ""
var daily_mission_label := ""
var daily_mission_target := 0
var daily_mission_progress := 0
var daily_mission_claimed := false
var daily_mission_date := ""
var _daily_mission_pop_time := -10.0
var _daily_progress_dirty := false
var _main_save_dirty := false
var _daily_save_timer: Timer = null

var tool_ids := [TOOL_AIR, TOOL_WATER, TOOL_SOAP, TOOL_SPONGE]
var tool_labels := {
	TOOL_AIR: "Air",
	TOOL_WATER: "Water",
	TOOL_SOAP: "Soap",
	TOOL_SPONGE: "Sponge",
}
var tool_colors := {
	TOOL_AIR: Color("#b7f0ff"),
	TOOL_WATER: Color("#49a7ff"),
	TOOL_SOAP: Color("#f8f4a6"),
	TOOL_SPONGE: Color("#ff9f5a"),
}
var style_cache: Dictionary = {}
var _hint_pill_box: StyleBoxFlat
var _hint_shadow_box: StyleBoxFlat
var _tool_hint_box: StyleBoxFlat
var _hint_patch: DirtPatch = null
var car_shapes: Dictionary = {}
var tool_audio_streams: Dictionary = {}
var ui_select_stream: AudioStreamWAV
var completion_stream: AudioStreamWAV
var removal_stream: AudioStreamWAV
var removal_sfx_player: AudioStreamPlayer
var combo_break_stream: AudioStreamWAV
var combo_break_player: AudioStreamPlayer
var _hint_stream: AudioStreamWAV = null
var _hint_sfx_player: AudioStreamPlayer = null
var _milestone_stream: AudioStreamWAV = null
var _milestone_sfx_player: AudioStreamPlayer = null
var _record_sfx: AudioStreamPlayer = null
var _combo_milestone_player: AudioStreamPlayer = null
var _star_lost_sfx: AudioStreamPlayer = null
var _prev_star3_time_ok := true
var _prev_star2_time_ok := true
var _star3_gate_sfx: AudioStreamPlayer = null
var _star3_combo_unlocked := false
var _last_milestone_haptic_combo := -1
var _star_warn_sfx: AudioStreamPlayer = null
var _prev_in_warn_zone := false
var _patience_warn_sfx: AudioStreamPlayer = null
var _prev_patience_zone := 3
var _bomb_sfx: AudioStreamPlayer = null
var _bomb_deny_sfx: AudioStreamPlayer = null
var _coin_bonus_sfx: AudioStreamPlayer = null
var _star_earn_sfx: AudioStreamPlayer = null
var _bar_fill_style := StyleBoxFlat.new()
