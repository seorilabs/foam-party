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
const REWARDED_PLACEMENT_LEVEL_REWARD := "level_reward_2x"
const INTERSTITIAL_PLACEMENT_GAME_OVER := "game_over"

var _analytics = null  # AnalyticsPort (log_event); may stay null.
var _is_web := false
var _ads_js: JavaScriptObject = null  # window.__foamPartyAds proxy (web only)
var _reward_js_cb: JavaScriptObject = null  # kept alive while a rewarded ad shows
var _pending_reward: Callable = Callable()
var _rewarded_in_flight := false  # guards against overwriting a live reward flow
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


func show_rewarded(placement: String, on_reward: Callable) -> bool:
	# One rewarded flow at a time — never overwrite a live reward context.
	if _rewarded_in_flight:
		return false
	if _is_web:
		if _ads_js == null:
			return false
		_pending_reward = on_reward
		_rewarded_in_flight = true
		# Keep the JS callback referenced for the duration of the show call.
		_reward_js_cb = JavaScriptBridge.create_callback(_on_web_reward)
		if _analytics != null:
			_analytics.log_event("ad_rewarded_request", {"placement": placement})
		_ads_js.showRewarded(placement, _reward_js_cb)
		return true
	# Native AdMob: Phase 2. on_reward never fires (no reward without an ad).
	return false


func show_interstitial(placement: String) -> bool:
	if _is_web:
		if _ads_js == null:
			return false
		var shown = _ads_js.showInterstitial(placement)
		if _analytics != null:
			_analytics.log_event("ad_interstitial_request", {"placement": placement})
		return bool(shown)
	# Native AdMob: Phase 2.
	return false


# JS → Godot terminal reward callback. args = [placement, earned]. Fires exactly
# once when the rewarded flow ends; grants the reward only when earned, and
# always clears the in-flight state so the next rewarded ad can show.
func _on_web_reward(args: Array) -> void:
	var placement := ""
	var earned := false
	if args.size() > 0 and args[0] != null:
		placement = str(args[0])
	if args.size() > 1 and args[1] != null:
		earned = bool(args[1])
	_rewarded_in_flight = false
	_reward_js_cb = null
	var cb := _pending_reward
	_pending_reward = Callable()
	if earned:
		if _analytics != null:
			_analytics.log_event("ad_rewarded_granted", {"placement": placement})
		if cb.is_valid():
			cb.call()
