extends RefCounted

const GameConfig = preload("res://core/domain/game_config.gd")

const PROFILES := [
	{"face_hex": "#f6c28b", "hair_hex": "#5a3825", "accent_hex": "#49a7ff", "accessory": "cap"},
	{"face_hex": "#8d5524", "hair_hex": "#20150f", "accent_hex": "#ffce3d", "accessory": "glasses"},
	{"face_hex": "#f1c27d", "hair_hex": "#b85c38", "accent_hex": "#39d98a", "accessory": "headband"},
	{"face_hex": "#c68642", "hair_hex": "#2d1b12", "accent_hex": "#f2857f", "accessory": "cap"},
	{"face_hex": "#ffdbac", "hair_hex": "#d79a44", "accent_hex": "#7fd6e6", "accessory": "glasses"},
]


static func profile_index(car_type: String, level: int) -> int:
	var safe_level := maxi(level, 1)
	var car_index := GameConfig.CAR_TYPES.find(car_type)
	if car_index < 0:
		car_index = 0
	var roster_size := maxi(GameConfig.CAR_TYPES.size(), 1)
	var rotation := int((safe_level - 1) / roster_size)
	return posmod(car_index + rotation, PROFILES.size())


static func profile_for(car_type: String, level: int) -> Dictionary:
	return PROFILES[profile_index(car_type, level)].duplicate(true)


static func reaction_strength(stars: int) -> float:
	return float(clampi(stars, 1, 3)) / 3.0
