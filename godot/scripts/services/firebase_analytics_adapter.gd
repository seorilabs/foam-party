extends Node

# Firebase Analytics adapter — engine-side implementation of the AnalyticsPort
# seam (res://core/ports/analytics_port.gd).
#
# When the Firebase plugin singletons are ABSENT (headless / plugin not yet
# bundled), every method safely no-ops. Events fired before Analytics finishes
# initializing are buffered and flushed on ready, so startup events
# (game_start / level_start) are not lost. Events are fire-and-forget: no
# method here alters gameplay state or return values.

const FIREBASE_ANDROID_CONFIG_PATH := "res://google-services.json"

var _firebase_core: Object = null
var _firebase_analytics: Object = null
var _firebase_runtime_enabled := false
var _firebase_core_initialized := false
var _firebase_analytics_initialized := false
var _pending: Array = []  # buffer events fired before init, flush on ready


func setup() -> void:
	if OS.get_environment("FOAM_FIREBASE_DISABLED") == "1":
		return
	if not _firebase_config_present():
		return
	if not Engine.has_singleton("GodotxFirebaseCore"):
		return
	_firebase_core = Engine.get_singleton("GodotxFirebaseCore")
	if Engine.has_singleton("GodotxFirebaseAnalytics"):
		_firebase_analytics = Engine.get_singleton("GodotxFirebaseAnalytics")
		_connect_firebase_signal(_firebase_analytics, "analytics_initialized", _on_firebase_analytics_initialized)
	_connect_firebase_signal(_firebase_core, "core_initialized", _on_firebase_core_initialized)
	_firebase_runtime_enabled = true
	if _firebase_core.has_method("initialize"):
		_firebase_core.call("initialize")


func _firebase_config_present() -> bool:
	if OS.has_feature("ios"):
		return true
	if OS.has_feature("android"):
		return FileAccess.file_exists(FIREBASE_ANDROID_CONFIG_PATH)
	return false


func _connect_firebase_signal(obj, sig, target) -> void:
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, target):
		obj.connect(sig, target)


func _on_firebase_core_initialized(success: bool) -> void:
	_firebase_core_initialized = success
	if not success or _firebase_analytics == null:
		return
	if _firebase_analytics.has_method("initialize"):
		_firebase_analytics.call("initialize")


func _on_firebase_analytics_initialized(success: bool) -> void:
	_firebase_analytics_initialized = success
	if success:
		for e in _pending:
			_emit(e[0], e[1])  # flush buffered events
	# Drop the buffer either way: on success it has been flushed; on failure the
	# events can never be delivered, so retaining them would leak indefinitely.
	_pending.clear()


func log_event(event_name: String, params: Dictionary = {}) -> void:
	# True no-op when Firebase is not running (headless / plugin not bundled):
	# do not even buffer, so there is zero side-effect in that environment.
	if not _firebase_runtime_enabled:
		return
	if not _firebase_analytics_initialized:
		_pending.append([event_name, params])  # buffer until init (don't lose startup events)
		if _pending.size() > 64:
			_pending.pop_front()
		return
	_emit(event_name, params)


func _emit(event_name: String, params: Dictionary) -> void:
	if _firebase_analytics == null or not _firebase_analytics.has_method("log_event"):
		return
	_firebase_analytics.call("log_event", event_name, params)
