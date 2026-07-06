extends RefCounted

# Pure star-rating and live grade-tracker rules. All inputs are injected so the
# results are bit-identical to the former methods on the Main node. Grade slot
# state strings are passed in from the godot layer (its GRADE_SLOT_* consts).

const GameConfig = preload("res://core/domain/game_config.gd")


static func star_time_threshold(tier: int, level_index: int) -> float:
	var base := GameConfig.STAR3_TIME if tier == 3 else GameConfig.STAR2_TIME
	return base * maxf(0.6, 1.0 - float(max(0, level_index - 1)) * 0.015)


static func calc_stars(level_time: float, best_combo: int, level_index: int) -> int:
	if level_time <= star_time_threshold(3, level_index) and best_combo >= GameConfig.STAR3_COMBO:
		return 3
	if level_time <= star_time_threshold(2, level_index):
		return 2
	return 1


# Live state of one star slot in the HUD grade tracker (0 = first star).
static func grade_slot_state(slot_index: int, level_time: float, best_combo: int, level_index: int, earned: String, target: String, locked: String) -> String:
	match slot_index:
		0:
			return earned
		1:
			return earned if level_time <= star_time_threshold(2, level_index) else locked
		2:
			if level_time > star_time_threshold(3, level_index):
				return locked
			return earned if best_combo >= GameConfig.STAR3_COMBO else target
	return locked


# Seconds until the next star is lost, or -1 once only the floor star remains.
static func grade_time_to_downgrade(level_time: float, level_index: int) -> float:
	if level_time <= star_time_threshold(3, level_index):
		return star_time_threshold(3, level_index) - level_time
	if level_time <= star_time_threshold(2, level_index):
		return star_time_threshold(2, level_index) - level_time
	return -1.0


# Star slot (0-based) whose threshold is approaching next, or -1 when none.
static func grade_at_risk_slot(level_time: float, level_index: int) -> int:
	if level_time <= star_time_threshold(3, level_index):
		return 2
	if level_time <= star_time_threshold(2, level_index):
		return 1
	return -1
