extends RefCounted

# A short-lived visual particle (droplet, foam, sparkle, ...). Pure data value;
# the godot layer decides how to draw it. Ported verbatim from main.gd.

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
