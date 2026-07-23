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
var _web_firebase: JavaScriptObject = null  # window.__foamPartyFirebase (web/AIT)
# Diagnosable last state of Firebase setup/init. Firebase failing silently is why
# Android custom events went entirely uncollected (issue #245); this value plus the
# push_warning() calls below turn every silent no-op path into a logged reason
# (visible in logcat) so the failing precondition can be identified on device.
var status := "uninitialized"


func setup() -> void:
	if OS.get_environment("FOAM_FIREBASE_DISABLED") == "1":
		status = "disabled_by_env"
		return
	# Web/AIT export cannot use the native Firebase plugin, so route analytics to
	# the JS Firebase bridge installed by the AIT wrapper (firebaseRuntime.ts).
	if OS.has_feature("web"):
		_web_firebase = JavaScriptBridge.get_interface("__foamPartyFirebase")
		if _web_firebase == null:
			status = "web_bridge_absent"
			push_warning("[Firebase] web bridge __foamPartyFirebase not found; analytics disabled")
		else:
			status = "web_bridge"
		return
	if not _firebase_config_present():
		status = "config_absent"
		push_warning("[Firebase] platform config not present (Android expects %s in the pck); analytics disabled" % FIREBASE_ANDROID_CONFIG_PATH)
		return
	if not Engine.has_singleton("GodotxFirebaseCore"):
		status = "core_singleton_absent"
		push_warning("[Firebase] GodotxFirebaseCore singleton not bundled; analytics disabled")
		return
	_firebase_core = Engine.get_singleton("GodotxFirebaseCore")
	if Engine.has_singleton("GodotxFirebaseAnalytics"):
		_firebase_analytics = Engine.get_singleton("GodotxFirebaseAnalytics")
		_connect_firebase_signal(_firebase_analytics, "analytics_initialized", _on_firebase_analytics_initialized)
	else:
		push_warning("[Firebase] GodotxFirebaseAnalytics singleton absent; custom events cannot be sent")
	_connect_firebase_signal(_firebase_core, "core_initialized", _on_firebase_core_initialized)
	_firebase_runtime_enabled = true
	status = "core_initializing" if _firebase_analytics != null else "analytics_singleton_absent"
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
	if not success:
		status = "core_init_failed"
		push_warning("[Firebase] core initialization failed; analytics unavailable")
		return
	if _firebase_analytics == null:
		status = "analytics_singleton_absent"
		return
	status = "analytics_initializing"
	if _firebase_analytics.has_method("initialize"):
		_firebase_analytics.call("initialize")


func _on_firebase_analytics_initialized(success: bool) -> void:
	_firebase_analytics_initialized = success
	if success:
		status = "ready"
		for e in _pending:
			_emit(e[0], e[1])  # flush buffered events
		_pending.clear()  # flushed — safe to release
		return
	# Init reported failure: keep the buffered events (bounded by the cap in
	# log_event) so a later retry-success can still flush them, and surface the
	# failure loudly instead of silently swallowing it (issue #245).
	status = "analytics_init_failed"
	push_warning("[Firebase] analytics initialization failed; %d buffered event(s) retained, custom events not sent yet" % _pending.size())


func log_event(event_name: String, params: Dictionary = {}) -> void:
	# Web/AIT: forward to the JS Firebase bridge (params as a JSON string).
	if _web_firebase != null:
		_web_firebase.logEvent(event_name, JSON.stringify(params))
		return
	# True no-op when Firebase is not running (headless / plugin not bundled):
	# do not even buffer, so there is zero side-effect in that environment.
	if not _firebase_runtime_enabled:
		return
	if not _firebase_analytics_initialized:
		_pending.append([event_name, params])  # buffer until init (don't lose startup events)
		if _pending.size() > 64:
			_pending.pop_front()
			push_warning("[Firebase] pending analytics buffer exceeded 64 before init; dropping oldest event")
		return
	_emit(event_name, params)


func _emit(event_name: String, params: Dictionary) -> void:
	if _firebase_analytics == null or not _firebase_analytics.has_method("log_event"):
		return
	_firebase_analytics.call("log_event", event_name, params)
