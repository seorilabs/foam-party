extends RefCounted

# Pure late-cleaning guidance rule. The Godot layer owns elapsed-time tracking
# and rendering; this use case only decides whether the overlay should be shown.

const PROGRESS_THRESHOLD := 0.90
const IDLE_SECONDS_THRESHOLD := 3.0
const PROGRESS_EPSILON := 0.00001


static func should_show(clean_progress: float, seconds_without_cleaning: float) -> bool:
	return clean_progress >= PROGRESS_THRESHOLD \
		and seconds_without_cleaning >= IDLE_SECONDS_THRESHOLD


static func cleaning_resumed(previous_progress: float, current_progress: float) -> bool:
	return current_progress > previous_progress + PROGRESS_EPSILON
