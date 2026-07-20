extends RefCounted

const GameConfig = preload("res://core/domain/game_config.gd")


static func protection_after_removal(previous_combo_count: int, protection_available: bool) -> bool:
	if previous_combo_count <= 0:
		return true
	return protection_available


static func timeout_transition(combo_count: int, protection_available: bool) -> Dictionary:
	if combo_count > 0 and protection_available:
		return {
			"combo_count": combo_count,
			"combo_timer": GameConfig.COMBO_GRACE,
			"protection_available": false,
			"grace_active": true,
			"did_reset": false,
		}
	return {
		"combo_count": 0,
		"combo_timer": 0.0,
		"protection_available": false,
		"grace_active": false,
		"did_reset": combo_count > 0,
	}
