extends Node

# AdService — engine-side implementation of the AdPort seam.
# Web/AIT uses window.__foamPartyAds. Android/iOS uses the vendored Poing
# Studios AdMob plugin. Desktop/headless builds keep the same safe no-op path.

const NativeAds := preload("res://scripts/services/native_ad_config.gd")

const REWARDED_PLACEMENT_FOAM_BOMB := "foam_bomb_free"
const REWARDED_PLACEMENT_LEVEL_REWARD := "level_reward_2x"
const INTERSTITIAL_PLACEMENT_GAME_OVER := "game_over"
const NATIVE_RELOAD_DELAY_SECONDS := 15.0
const NATIVE_REQUIRED_SINGLETONS := [
	"PoingGodotAdMob",
	"PoingGodotAdMobInterstitialAd",
	"PoingGodotAdMobRewardedAd",
]

var _analytics = null
var _is_web := false
var _ads_js: JavaScriptObject = null
var _reward_js_cb: JavaScriptObject = null
var _pending_reward: Callable = Callable()
var _rewarded_in_flight := false

var _native_supported := false
var _native_init_listener = null
var _interstitial_ad = null
var _showing_interstitial_ad = null
var _interstitial_load_callback = null
var _interstitial_content_callback = null
var _interstitial_loading := false
var _interstitial_in_flight := false
var _interstitial_reload_scheduled := false
var _native_interstitial_placement := ""

var _rewarded_ads: Dictionary = {}
var _rewarded_load_callbacks: Dictionary = {}
var _rewarded_content_callbacks: Dictionary = {}
var _rewarded_loading: Dictionary = {}
var _rewarded_reload_scheduled: Dictionary = {}
var _native_reward_listener = null
var _showing_rewarded_ad = null
var _native_reward_placement := ""
var _native_reward_earned := false


func configure(analytics_port) -> void:
	_analytics = analytics_port


func setup() -> void:
	_is_web = OS.has_feature("web")
	if _is_web:
		_ads_js = JavaScriptBridge.get_interface("__foamPartyAds")
		return
	_setup_native()


## 전면/보상형이 화면을 점유하는 중인지. OS 는 이때도 앱을 pause 시키는데, 그것은
## 사용자가 앱을 떠난 것이 아니라 우리가 띄운 광고다. 이탈 기록과 강제 일시정지를
## 건너뛰는 판단에 쓴다(#269).
func is_fullscreen_ad_showing() -> bool:
	return _interstitial_in_flight or _rewarded_in_flight


func is_rewarded_ready(placement: String) -> bool:
	if _rewarded_in_flight:
		return false
	if _is_web:
		if _ads_js == null:
			return false
		return bool(_ads_js.isRewardedReady(placement))
	if not _native_supported:
		return false
	return _rewarded_ads.get(placement) != null


func show_rewarded(placement: String, on_reward: Callable) -> bool:
	if _rewarded_in_flight:
		return false
	if _is_web:
		if _ads_js == null:
			return false
		_pending_reward = on_reward
		_rewarded_in_flight = true
		_reward_js_cb = JavaScriptBridge.create_callback(_on_web_reward)
		_log_ad_event("ad_rewarded_request", placement, "toss_ads")
		_ads_js.showRewarded(placement, _reward_js_cb)
		return true
	if not _native_supported:
		return false
	var ad = _rewarded_ads.get(placement)
	if ad == null:
		return false
	_rewarded_ads.erase(placement)
	_pending_reward = on_reward
	_rewarded_in_flight = true
	_native_reward_earned = false
	_native_reward_placement = placement
	_showing_rewarded_ad = ad
	_log_ad_event("ad_rewarded_request", placement, "admob")
	ad.show(_native_reward_listener)
	return true


func show_interstitial(placement: String) -> bool:
	if _is_web:
		if _ads_js == null:
			return false
		var shown := bool(_ads_js.showInterstitial(placement))
		if shown:
			_log_ad_event("ad_interstitial_request", placement, "toss_ads")
		return shown
	if not _native_supported or _interstitial_in_flight:
		return false
	if placement != INTERSTITIAL_PLACEMENT_GAME_OVER or _interstitial_ad == null:
		return false
	_showing_interstitial_ad = _interstitial_ad
	_interstitial_ad = null
	_interstitial_in_flight = true
	_native_interstitial_placement = placement
	_log_ad_event("ad_interstitial_request", placement, "admob")
	_showing_interstitial_ad.show()
	return true


func _setup_native() -> void:
	if OS.get_name() not in ["Android", "iOS"]:
		return
	for singleton_name in NATIVE_REQUIRED_SINGLETONS:
		if not Engine.has_singleton(singleton_name):
			return
	_native_supported = true
	_native_reward_listener = OnUserEarnedRewardListener.new()
	_native_reward_listener.on_user_earned_reward = _on_native_reward_earned
	_native_init_listener = OnInitializationCompleteListener.new()
	_native_init_listener.on_initialization_complete = _on_native_initialized
	MobileAds.initialize(_native_init_listener)


func _on_native_initialized(_status) -> void:
	_native_init_listener = null
	_load_interstitial()
	_load_rewarded(REWARDED_PLACEMENT_FOAM_BOMB)
	_load_rewarded(REWARDED_PLACEMENT_LEVEL_REWARD)


func _new_native_request() -> AdRequest:
	var request := AdRequest.new()
	request.extras = {}
	if NativeAds.uses_non_personalized_ads():
		request.extras["npa"] = "1"
	return request


func _load_interstitial() -> void:
	if not _native_supported or _interstitial_loading or _interstitial_ad != null or _interstitial_in_flight:
		return
	var unit_id := NativeAds.unit_id("interstitial", INTERSTITIAL_PLACEMENT_GAME_OVER)
	if unit_id.is_empty():
		return
	_interstitial_loading = true
	_interstitial_load_callback = InterstitialAdLoadCallback.new()
	_interstitial_load_callback.on_ad_loaded = _on_interstitial_loaded
	_interstitial_load_callback.on_ad_failed_to_load = _on_interstitial_load_failed
	_interstitial_content_callback = FullScreenContentCallback.new()
	_interstitial_content_callback.on_ad_impression = _on_interstitial_impression
	_interstitial_content_callback.on_ad_dismissed_full_screen_content = _on_interstitial_dismissed
	_interstitial_content_callback.on_ad_failed_to_show_full_screen_content = _on_interstitial_show_failed
	InterstitialAdLoader.new().load(unit_id, _new_native_request(), _interstitial_load_callback)


func _on_interstitial_loaded(ad) -> void:
	_interstitial_loading = false
	ad.full_screen_content_callback = _interstitial_content_callback
	_interstitial_ad = ad
	_log_ad_event("ad_interstitial_loaded", INTERSTITIAL_PLACEMENT_GAME_OVER, "admob")


func _on_interstitial_load_failed(_error) -> void:
	_interstitial_loading = false
	_log_ad_event("ad_interstitial_load_failed", INTERSTITIAL_PLACEMENT_GAME_OVER, "admob")
	_schedule_interstitial_reload()


func _on_interstitial_impression() -> void:
	_log_ad_event("ad_interstitial_impression", _native_interstitial_placement, "admob")


func _on_interstitial_dismissed() -> void:
	_log_ad_event("ad_interstitial_dismissed", _native_interstitial_placement, "admob")
	_finish_native_interstitial()


func _on_interstitial_show_failed(_error) -> void:
	_log_ad_event("ad_interstitial_show_failed", _native_interstitial_placement, "admob")
	_finish_native_interstitial()


func _finish_native_interstitial() -> void:
	if _showing_interstitial_ad != null:
		_showing_interstitial_ad.destroy()
	_showing_interstitial_ad = null
	_interstitial_in_flight = false
	_native_interstitial_placement = ""
	_load_interstitial()


func _schedule_interstitial_reload() -> void:
	if _interstitial_reload_scheduled or not is_inside_tree():
		return
	_interstitial_reload_scheduled = true
	get_tree().create_timer(NATIVE_RELOAD_DELAY_SECONDS).timeout.connect(_retry_interstitial_load, CONNECT_ONE_SHOT)


func _retry_interstitial_load() -> void:
	_interstitial_reload_scheduled = false
	_load_interstitial()


func _load_rewarded(placement: String) -> void:
	if not _native_supported or bool(_rewarded_loading.get(placement, false)):
		return
	if _rewarded_ads.get(placement) != null:
		return
	var unit_id := NativeAds.unit_id("rewarded", placement)
	if unit_id.is_empty():
		return
	_rewarded_loading[placement] = true
	var load_callback := RewardedAdLoadCallback.new()
	load_callback.on_ad_loaded = func(ad) -> void: _on_rewarded_loaded(placement, ad)
	load_callback.on_ad_failed_to_load = func(error) -> void: _on_rewarded_load_failed(placement, error)
	_rewarded_load_callbacks[placement] = load_callback
	RewardedAdLoader.new().load(unit_id, _new_native_request(), load_callback)


func _on_rewarded_loaded(placement: String, ad) -> void:
	_rewarded_loading[placement] = false
	var content_callback := FullScreenContentCallback.new()
	content_callback.on_ad_impression = func() -> void: _on_rewarded_impression(placement)
	content_callback.on_ad_dismissed_full_screen_content = func() -> void: _on_rewarded_dismissed(placement)
	content_callback.on_ad_failed_to_show_full_screen_content = func(error) -> void: _on_rewarded_show_failed(placement, error)
	_rewarded_content_callbacks[placement] = content_callback
	ad.full_screen_content_callback = content_callback
	_rewarded_ads[placement] = ad
	_log_ad_event("ad_rewarded_loaded", placement, "admob")


func _on_rewarded_load_failed(placement: String, _error) -> void:
	_rewarded_loading[placement] = false
	_rewarded_load_callbacks.erase(placement)
	_log_ad_event("ad_rewarded_load_failed", placement, "admob")
	_schedule_rewarded_reload(placement)


func _on_rewarded_impression(placement: String) -> void:
	if placement == _native_reward_placement:
		_log_ad_event("ad_rewarded_impression", placement, "admob")


func _on_rewarded_dismissed(placement: String) -> void:
	if placement != _native_reward_placement:
		return
	_log_ad_event("ad_rewarded_dismissed", placement, "admob")
	_finish_native_rewarded(placement)


func _on_rewarded_show_failed(placement: String, _error) -> void:
	if placement != _native_reward_placement:
		return
	_log_ad_event("ad_rewarded_show_failed", placement, "admob")
	_finish_native_rewarded(placement)


func _on_native_reward_earned(_rewarded_item) -> void:
	if not _rewarded_in_flight or _native_reward_earned:
		return
	_native_reward_earned = true
	var callback := _pending_reward
	_pending_reward = Callable()
	_log_ad_event("ad_rewarded_granted", _native_reward_placement, "admob")
	if callback.is_valid():
		callback.call()


func _finish_native_rewarded(placement: String) -> void:
	if _showing_rewarded_ad != null:
		_showing_rewarded_ad.destroy()
	_showing_rewarded_ad = null
	_pending_reward = Callable()
	_rewarded_in_flight = false
	_native_reward_earned = false
	_native_reward_placement = ""
	_rewarded_load_callbacks.erase(placement)
	_rewarded_content_callbacks.erase(placement)
	_load_rewarded(placement)


func _schedule_rewarded_reload(placement: String) -> void:
	if bool(_rewarded_reload_scheduled.get(placement, false)) or not is_inside_tree():
		return
	_rewarded_reload_scheduled[placement] = true
	var retry := func() -> void: _retry_rewarded_load(placement)
	get_tree().create_timer(NATIVE_RELOAD_DELAY_SECONDS).timeout.connect(retry, CONNECT_ONE_SHOT)


func _retry_rewarded_load(placement: String) -> void:
	_rewarded_reload_scheduled[placement] = false
	_load_rewarded(placement)


func _on_web_reward(args: Array) -> void:
	var placement := ""
	var earned := false
	if args.size() > 0 and args[0] != null:
		placement = str(args[0])
	if args.size() > 1 and args[1] != null:
		earned = bool(args[1])
	_rewarded_in_flight = false
	_reward_js_cb = null
	var callback := _pending_reward
	_pending_reward = Callable()
	if earned:
		_log_ad_event("ad_rewarded_granted", placement, "toss_ads")
		if callback.is_valid():
			callback.call()


func _log_ad_event(event_name: String, placement: String, provider: String) -> void:
	if _analytics != null:
		_analytics.log_event(event_name, {"placement": placement, "provider": provider})
