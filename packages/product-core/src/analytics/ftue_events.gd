extends RefCounted

# First-time user experience analytics catalog. These builders stay in the
# engine-independent core so native Android and iOS share one event contract.

const TITLE_SCREEN_VIEW := "title_screen_view"
const PLAY_TAP := "play_tap"
const LEVEL_LOAD_START := "level_load_start"
const LEVEL_LOAD_COMPLETE := "level_load_complete"
const TUTORIAL_STEP_VIEW := "tutorial_step_view"
const TUTORIAL_COMPLETE := "tutorial_complete"

const ALL := [
	TITLE_SCREEN_VIEW,
	PLAY_TAP,
	LEVEL_LOAD_START,
	LEVEL_LOAD_COMPLETE,
	TUTORIAL_STEP_VIEW,
	TUTORIAL_COMPLETE,
]

const ENTRY_COLD_START := "cold_start"
const ENTRY_PAUSE_HOME := "pause_home"
const TUTORIAL_STEP_OVERVIEW := "overview"


static func title_screen_view(entry: String) -> Dictionary:
	return _event(TITLE_SCREEN_VIEW, {"entry": entry})


static func play_tap(level: int) -> Dictionary:
	return _event(PLAY_TAP, {"level": str(level)})


static func level_load_start(level: int, reason: String) -> Dictionary:
	return _event(LEVEL_LOAD_START, {"level": str(level), "reason": reason})


static func level_load_complete(level: int, car_type: String, reason: String) -> Dictionary:
	return _event(LEVEL_LOAD_COMPLETE, {
		"level": str(level),
		"car_type": car_type,
		"reason": reason,
	})


static func tutorial_step_view(step: String, source: String) -> Dictionary:
	return _event(TUTORIAL_STEP_VIEW, {"step": step, "source": source})


static func tutorial_complete(step: String, source: String) -> Dictionary:
	return _event(TUTORIAL_COMPLETE, {"step": step, "source": source})


static func _event(name: String, params: Dictionary) -> Dictionary:
	return {"name": name, "params": params}
