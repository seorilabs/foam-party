extends RefCounted

# Pure customer-patience rule shared by the HUD presentation and warning-zone
# transition logic. Progress slows the time pressure but never stops it, so a
# long-idle customer still eventually reaches zero patience.

const GameConfig = preload("res://core/domain/game_config.gd")


static func value(elapsed_seconds: float, clean_progress: float) -> float:
	if GameConfig.STAR2_TIME <= 0.0:
		return 1.0
	var time_pressure := maxf(elapsed_seconds, 0.0) / GameConfig.STAR2_TIME
	var progress := clampf(clean_progress, 0.0, 1.0)
	var progress_relief := 1.0 - progress * clampf(GameConfig.PATIENCE_PROGRESS_WEIGHT, 0.0, 1.0)
	return clampf(1.0 - time_pressure * progress_relief, 0.0, 1.0)


static func zone(patience: float) -> int:
	var value_now := clampf(patience, 0.0, 1.0)
	if value_now > 0.65:
		return 3
	if value_now > 0.35:
		return 2
	if value_now > 0.1:
		return 1
	return 0


static func should_warn(previous_zone: int, current_zone: int) -> bool:
	return current_zone < previous_zone
