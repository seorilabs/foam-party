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
## 핸드셰이크 감시 시간. 네이티브 초기화는 보통 1초 안에 끝난다.
const HANDSHAKE_WATCH_SECONDS := 8.0

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
		if not _connect_firebase_signal(
			_firebase_analytics, "analytics_initialized", _on_firebase_analytics_initialized
		):
			push_warning("[Firebase] analytics_initialized signal unavailable; events would stay buffered")
	else:
		push_warning("[Firebase] GodotxFirebaseAnalytics singleton absent; custom events cannot be sent")
	var core_signal_ok := _connect_firebase_signal(
		_firebase_core, "core_initialized", _on_firebase_core_initialized
	)
	_firebase_runtime_enabled = true
	status = "core_initializing" if _firebase_analytics != null else "analytics_singleton_absent"
	_log_state("setup core_signal=%s analytics_singleton=%s" % [
		core_signal_ok, _firebase_analytics != null,
	])
	# has_method() 로 가드하지 않는다. Android 플러그인 싱글턴의 @UsedByGodot 메서드는
	# 런타임 디스패치라 GDScript 의 has_method() 가 false 를 돌려준다. 실기기 로그로
	# 확인했다(#245). 싱글턴 존재는 위에서 Engine.has_singleton() 으로 이미 확인했다.
	_firebase_core.call("initialize")
	_watch_handshake()


## 핸드셰이크가 끝나지 않으면 이벤트가 영원히 버퍼에만 쌓인다. 실패 신호가 오지
## 않는 경우는 push_warning 경로에 걸리지 않으므로 시간으로 잡는다.
func _watch_handshake() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(HANDSHAKE_WATCH_SECONDS).timeout
	if _firebase_analytics_initialized:
		return
	push_warning(
		"[Firebase] analytics not ready %.0fs after setup (status=%s, core_initialized=%s); %d event(s) still buffered"
		% [HANDSHAKE_WATCH_SECONDS, status, _firebase_core_initialized, _pending.size()]
	)


func _firebase_config_present() -> bool:
	if OS.has_feature("ios"):
		return true
	if OS.has_feature("android"):
		return FileAccess.file_exists(FIREBASE_ANDROID_CONFIG_PATH)
	return false


## 상태 전이를 한 줄로 남긴다. 실패에만 경고를 내면 "신호 대기 중"과 "정상"이
## 로그에서 구분되지 않아 어디서 멈췄는지 알 수 없다(#245 AC-3). 전이 시점에만
## 찍으므로 이벤트마다 시끄러워지지 않는다.
func _log_state(reason: String) -> void:
	print("[Firebase] status=%s reason=%s pending=%d" % [status, reason, _pending.size()])


## 신호 연결 성공 여부를 돌려준다. 플러그인이 신호를 노출하지 않으면 연결이 조용히
## 실패하고 초기화 핸드셰이크가 영원히 끝나지 않는다. 그 경우를 로그로 드러낸다.
func _connect_firebase_signal(obj, sig, target) -> bool:
	if obj == null:
		return false
	if not obj.has_signal(sig):
		push_warning("[Firebase] plugin does not expose signal '%s'; handshake cannot complete" % sig)
		return false
	if obj.is_connected(sig, target):
		return true
	return obj.connect(sig, target) == OK


func _on_firebase_core_initialized(success: bool) -> void:
	_firebase_core_initialized = success
	_log_state("core_initialized=%s" % success)
	if not success:
		status = "core_init_failed"
		push_warning("[Firebase] core initialization failed; analytics unavailable")
		return
	if _firebase_analytics == null:
		status = "analytics_singleton_absent"
		return
	status = "analytics_initializing"
	_firebase_analytics.call("initialize")


func _on_firebase_analytics_initialized(success: bool) -> void:
	_firebase_analytics_initialized = success
	_log_state("analytics_initialized=%s" % success)
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
	# 여기서도 has_method() 가드를 쓰지 않는다. 쓰면 네이티브 경로에서 모든 이벤트가
	# 조용히 버려진다. 호출 가능 여부는 setup() 의 싱글턴 확인이 책임진다.
	if _firebase_analytics == null:
		return
	_firebase_analytics.call("log_event", event_name, params)
