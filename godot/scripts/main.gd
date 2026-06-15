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
const SAVE_PATH := "user://foam_party_save.cfg"
const BOMB_COST := 40
const STATE_TITLE := "title"
const STATE_PLAYING := "playing"
const GAMEPLAY_SCALE := 1.16
const GAMEPLAY_PIVOT := Vector2(195.0, 545.0)
const GAMEPLAY_OFFSET := Vector2(0.0, 0.0)
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
