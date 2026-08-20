class_name FoamPartyPlatformAuthService
extends Node
## Platform 표준 Firebase identity adapter와 Platform 세션을 게임 시작과 분리해 조립한다.

signal finished(success: bool, firebase_uid: String)

const PlatformClientScript := preload("res://addons/seorilabs_platform/platform_client.gd")
const FirebaseIdentityAdapterScript := preload(
	"res://addons/seorilabs_platform/adapters/firebase_identity_adapter.gd"
)
const PLATFORM_API_BASE_URL := "https://platform-api-306278488979.asia-northeast3.run.app"
const PLATFORM_APP_ID := "foam-party"
const ANDROID_FIREBASE_CONFIG_PATH := "res://google-services.json"
const IOS_FIREBASE_CONFIG_PATH := "res://GoogleService-Info.plist"

var status := "unconfigured"
var _platform_client: Node
var _identity_adapter: Node
var _firebase_uid := ""
var _configured := false
var _started := false
var _completed := false


## Tests may inject both collaborators before start(). Production creates the vendored SDK types.
func configure(options: Dictionary = {}) -> void:
	if _configured:
		return
	_configured = true

	var client_value: Variant = options.get("platform_client")
	var identity_value: Variant = options.get("identity_adapter")
	if (client_value == null) != (identity_value == null):
		_fail("platform_auth_injection_incomplete")
		return

	if client_value is Node and identity_value is Node:
		_platform_client = client_value as Node
		_identity_adapter = identity_value as Node
		_adopt_child(_platform_client)
		_adopt_child(_identity_adapter)
	else:
		var firebase_api_key := firebase_api_key_for_current_platform()
		if firebase_api_key.is_empty():
			_fail("firebase_api_key_missing")
			return

		_platform_client = PlatformClientScript.new()
		_platform_client.call("configure", {
			"base_url": PLATFORM_API_BASE_URL,
			"app_id": PLATFORM_APP_ID,
		})
		add_child(_platform_client)

		_identity_adapter = FirebaseIdentityAdapterScript.new()
		_identity_adapter.call("configure", {
			"firebase_api_key": firebase_api_key,
			"platform_client": _platform_client,
		})
		add_child(_identity_adapter)

	if not _identity_adapter.has_method("ensure_identity") \
			or not _platform_client.has_method("sign_in"):
		_fail("platform_auth_sdk_unavailable")
		return
	status = "ready"


func start() -> void:
	if _started:
		return
	_started = true
	if status != "ready":
		if not _completed:
			_fail("platform_auth_not_ready")
		return
	status = "firebase_identity"
	_authenticate.call_deferred()


func current_uid() -> String:
	return _firebase_uid


func _authenticate() -> void:
	var identity_value: Variant = await _identity_adapter.call("ensure_identity")
	if not identity_value is Dictionary:
		_fail("firebase_identity_invalid_response")
		return
	var identity: Dictionary = identity_value
	if not bool(identity.get("success", false)):
		_fail("firebase_identity_%s" % String(identity.get("reason", "unknown")))
		return

	_firebase_uid = String(identity.get("uid", ""))
	var id_token := String(identity.get("id_token", ""))
	if _firebase_uid.is_empty() or id_token.is_empty():
		_fail("firebase_identity_fields_missing")
		return

	status = "platform_session"
	_platform_client.call(
		"sign_in",
		{"kind": "firebase-id-token", "value": id_token},
		Callable(self, "_on_platform_session"),
	)


func _on_platform_session(response: Dictionary) -> void:
	if not bool(response.get("ok", false)):
		_fail("platform_session_%s" % String(response.get("code", "unknown")))
		return
	status = "signed_in"
	_completed = true
	finished.emit(true, _firebase_uid)


func _fail(reason: String) -> void:
	if _completed:
		return
	status = "failed"
	_completed = true
	var safe_reason := reason.strip_edges()
	if safe_reason.is_empty():
		safe_reason = "unknown"
	push_warning("Platform 인증 실패 - 게임은 로컬 모드로 계속됩니다: %s" % safe_reason)
	finished.emit(false, _firebase_uid)


func _adopt_child(child: Node) -> void:
	if child.get_parent() == null:
		add_child(child)


static func firebase_api_key_for_current_platform() -> String:
	if OS.has_feature("ios"):
		return firebase_api_key_from_ios_plist(IOS_FIREBASE_CONFIG_PATH)
	if OS.has_feature("android"):
		return firebase_api_key_from_android_json(ANDROID_FIREBASE_CONFIG_PATH)
	return ""


static func firebase_api_key_from_android_json(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ""
	var clients: Variant = (parsed as Dictionary).get("client", [])
	if not clients is Array or (clients as Array).is_empty():
		return ""
	var first_client: Variant = (clients as Array)[0]
	if not first_client is Dictionary:
		return ""
	var api_keys: Variant = (first_client as Dictionary).get("api_key", [])
	if not api_keys is Array or (api_keys as Array).is_empty():
		return ""
	var first_key: Variant = (api_keys as Array)[0]
	if not first_key is Dictionary:
		return ""
	return String((first_key as Dictionary).get("current_key", "")).strip_edges()


static func firebase_api_key_from_ios_plist(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var matcher := RegEx.new()
	if matcher.compile("<key>API_KEY</key>\\s*<string>([^<]+)</string>") != OK:
		return ""
	var matched := matcher.search(FileAccess.get_file_as_string(path))
	if matched == null:
		return ""
	return matched.get_string(1).strip_edges()
