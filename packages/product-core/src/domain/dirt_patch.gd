extends RefCounted

# A single piece of dirt on the car. Pure data + simulation state; no engine or
# rendering dependency. Ported verbatim from the former inner class in main.gd.

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
var shake_x: float = 0.0

func _init(new_kind: String, new_position: Vector2, new_radius: float, new_health: float, new_seed: float) -> void:
	kind = new_kind
	position = new_position
	radius = new_radius
	health = new_health
	max_health = new_health
	seed_offset = new_seed
