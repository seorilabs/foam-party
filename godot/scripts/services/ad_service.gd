extends Node

# AdService — engine-side implementation of the AdPort seam
# (res://core/ports/ad_port.gd).
#
# Routes by platform, always safe to call:
#   - Web / AppsInToss: bridges to window.__foamPartyAds (Toss Ads integrated
#     ad via @apps-in-toss/web-framework loadFullScreenAd/showFullScreenAd).
#   - Native (Android/iOS): Google AdMob via a Godot plugin singleton. The
#     singleton is ABSENT until the AdMob plugin is bundled (Phase 2), so every
#     method safely no-ops until then — matching the FirebaseAnalyticsAdapter
#     "no-op when the platform capability is missing" contract.
#
# Gameplay-level ad events are logged through the injected AnalyticsPort so they
# land in the same Firebase stream as the rest of the game. SDK-level lifecycle
# events (load/impression/dismiss) are logged by the web runtime itself
# (tossFullScreenAdRuntime.ts via window.__foamPartyFirebase) to avoid double
# counting.

const REWARDED_PLACEMENT_FOAM_BOMB := "foam_bomb_free"
const INTERSTITIAL_PLACEMENT_GAME_OVER := "game_over"

var _analytics = null  # AnalyticsPort (log_event); may stay null.
var _is_web := false
var _ads_js: JavaScriptObject = null  # window.__foamPartyAds proxy (web only)
var _reward_js_cb: JavaScriptObject = null  # kept alive while a rewarded ad shows
var _pending_reward: Callable = Callable()
var _admob: Object = null  # native AdMob plugin singleton (Phase 2)


func configure(analytics_port) -> void:
	_analytics = analytics_port


func setup() -> void:
	_is_web = OS.has_feature("web")
	if _is_web:
		# window.__foamPartyAds is installed by the AIT web wrapper before Godot
		# boots (ait/apps-in-toss-web/src/main.tsx). null if the bridge is absent.
		_ads_js = JavaScriptBridge.get_interface("__foamPartyAds")
		return
	# Native AdMob singleton (Phase 2). Absent for now → everything no-ops.
	for singleton_name in ["GodotAdMob", "AdMob", "PoingGodotAdMob"]:
		if Engine.has_singleton(singleton_name):
			_admob = Engine.get_singleton(singleton_name)
			break


func is_rewarded_ready(placement: String) -> bool:
	if _is_web:
		if _ads_js == null:
			return false
		var ready = _ads_js.isRewardedReady(placement)
		return bool(ready)
	# Native AdMob: Phase 2. No-op until the plugin lands.
	return false


func show_rewarded(placement: String, on_reward: Callable) -> void:
	if _analytics != null:
		_analytics.log_event("ad_rewarded_request", {"placement": placement})
	if _is_web:
		if _ads_js == null:
			return
		_pending_reward = on_reward
		# Keep the JS callback referenced for the duration of the show call.
		_reward_js_cb = JavaScriptBridge.create_callback(_on_web_reward)
		_ads_js.showRewarded(placement, _reward_js_cb)
		return
	# Native AdMob: Phase 2. on_reward never fires (no reward without an ad).


func show_interstitial(placement: String) -> void:
	if _is_web:
		if _ads_js == null:
			return
		_ads_js.showInterstitial(placement)
		if _analytics != null:
			_analytics.log_event("ad_interstitial_request", {"placement": placement})
		return
	# Native AdMob: Phase 2.


# JS → Godot reward callback. Args come from the JS runtime as a JS array; the
# first element is the placement (for logging). Grants the reward exactly once.
func _on_web_reward(args: Array) -> void:
	var placement := ""
	if args.size() > 0 and args[0] != null:
		placement = str(args[0])
	if _analytics != null:
		_analytics.log_event("ad_rewarded_granted", {"placement": placement})
	var cb := _pending_reward
	_pending_reward = Callable()
	if cb.is_valid():
		cb.call()
