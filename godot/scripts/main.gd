extends Control

# --- product-core (pure gameplay rules), referenced via res://core symlink ---
const GameConfig = preload("res://core/domain/game_config.gd")
const DirtPatch = preload("res://core/domain/dirt_patch.gd")
const WashParticle = preload("res://core/domain/wash_particle.gd")
const SkinCatalog = preload("res://core/domain/skin_catalog.gd")
const CarPaintCatalog = preload("res://core/domain/car_paint_catalog.gd")
const Scoring = preload("res://core/use_cases/scoring.gd")
const Economy = preload("res://core/use_cases/economy.gd")
const Coaching = preload("res://core/use_cases/coaching.gd")
const ComboProtection = preload("res://core/use_cases/combo_protection.gd")
const CustomerPresentation = preload("res://core/use_cases/customer_presentation.gd")
const CustomerPatience = preload("res://core/use_cases/customer_patience.gd")
const StalledDirtHighlight = preload("res://core/use_cases/stalled_dirt_highlight.gd")
const DailyMission = preload("res://core/use_cases/daily_mission.gd")
const AchievementProgress = preload("res://core/use_cases/achievement_progress.gd")
const BestTime = preload("res://core/use_cases/best_time.gd")
const StageSelection = preload("res://core/use_cases/stage_selection.gd")
const DirtSpawnPlan = preload("res://core/use_cases/dirt_spawn_plan.gd")
const GoldSpot = preload("res://core/use_cases/gold_spot.gd")
const WashRules = preload("res://core/use_cases/wash_rules.gd")
const LicensePlate = preload("res://core/use_cases/license_plate.gd")
const AnalyticsPort = preload("res://core/ports/analytics_port.gd")
const ContentEvents = preload("res://core/analytics/content_events.gd")
const FtueEvents = preload("res://core/analytics/ftue_events.gd")
const AdPort = preload("res://core/ports/ad_port.gd")

# --- godot-layer services ---
const AudioService = preload("res://scripts/services/audio_service.gd")
const FirebaseAnalyticsAdapter = preload("res://scripts/services/firebase_analytics_adapter.gd")
const AdService = preload("res://scripts/services/ad_service.gd")
const I18n = preload("res://scripts/services/i18n.gd")

const DESIGN_SIZE := Vector2(390.0, 844.0)
const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const CAR_PAINT_TOOL := CarPaintCatalog.TOOL_KEY
const SKIN_PANEL_TAB_KEYS := [TOOL_WATER, TOOL_AIR, TOOL_SOAP, TOOL_SPONGE, CAR_PAINT_TOOL]
const CAR_TYPES := GameConfig.CAR_TYPES
const CLEAN_DAMAGE_RATE := GameConfig.CLEAN_DAMAGE_RATE
const COMBO_WINDOW := GameConfig.COMBO_WINDOW
const COMBO_GRACE := GameConfig.COMBO_GRACE
const STAR3_TIME := GameConfig.STAR3_TIME
const STAR_WARN_SECONDS := GameConfig.STAR_WARN_SECONDS
const GRADE_SLOT_EARNED := "earned"
const GRADE_SLOT_TARGET := "target"
const GRADE_SLOT_LOCKED := "locked"
const BAR_COL_START := Color(0.286, 0.655, 1.0)   # #49a7ff
const BAR_COL_END   := Color(0.224, 0.851, 0.541)  # #39d98a
const SAVE_PATH := "user://foam_party_save.cfg"
const DAILY_SAVE_PATH := "user://foam_party_daily.cfg"
const BOMB_COST := GameConfig.BOMB_COST
const WATER_BOOST_COST := GameConfig.WATER_BOOST_COST
const WATER_BOOST_DURATION := GameConfig.WATER_BOOST_DURATION
const WATER_BOOST_RADIUS_MULT := GameConfig.WATER_BOOST_RADIUS_MULT
const WATER_BOOST_POWER_MULT := GameConfig.WATER_BOOST_POWER_MULT
const UPGRADE_COSTS := GameConfig.UPGRADE_COSTS
const UPGRADE_MULTS := GameConfig.UPGRADE_MULTS
const UPGRADE_KEYS := GameConfig.UPGRADE_KEYS
const UPGRADE_MAX_LEVEL := GameConfig.UPGRADE_MAX_LEVEL
const REACH_UPGRADE_COSTS := GameConfig.REACH_UPGRADE_COSTS
const REACH_UPGRADE_MULTS := GameConfig.REACH_UPGRADE_MULTS
const REACH_UPGRADE_KEYS := GameConfig.REACH_UPGRADE_KEYS
const REACH_UPGRADE_MAX_LEVEL := GameConfig.REACH_UPGRADE_MAX_LEVEL
const UPGRADE_TAB_POWER := 0
const UPGRADE_TAB_REACH := 1
const TUTORIAL_TAB_TOOLS := 0
const TUTORIAL_TAB_DIRT := 1
const STATE_TITLE := "title"
const STATE_PLAYING := "playing"
const GAMEPLAY_SCALE := 1.16
const GAMEPLAY_PIVOT := Vector2(195.0, 545.0)
const GAMEPLAY_OFFSET := Vector2(0.0, 0.0)
const CAR_TRANSITION_IDLE := "idle"
const CAR_TRANSITION_ENTERING := "entering"
const CAR_TRANSITION_EXITING := "exiting"
const CAR_ENTRY_DURATION := 0.52
const CAR_EXIT_DURATION := 0.48
const CAR_TRANSITION_DISTANCE := 450.0
const HUD_TOP_Y := 12.0
const HUD_SAFE_PADDING := 8.0
const TOP_BUTTON_Y := 104.0
const TOP_BUTTON_SAFE_PADDING := 12.0
const TOOLBAR_Y := 744.0
const TOOL_BUTTON_Y := 764.0
const TOOL_BUTTON_HEIGHT := 72.0
const TOOL_BUTTON_BOTTOM_PADDING := 12.0
const TOOLBAR_TOP_GAP := 20.0
const STALLED_DIRT_PROGRESS_THRESHOLD := StalledDirtHighlight.PROGRESS_THRESHOLD
const STALLED_DIRT_IDLE_SECONDS := StalledDirtHighlight.IDLE_SECONDS_THRESHOLD
# Washing (bram/water/soap/sponge input) only acts within the car + dirt band,
# not the top HUD (card/buttons) or below the toolbar. Matches the dirt bounds
# used by _is_patch_outside_wash_area so a touch can only wash where dirt lives.
const WASH_AREA_TOP := 300.0
const WASH_AREA_BOTTOM := 748.0
const STATE_STUCK := "stuck"
const STATE_WET := "wet"
const STATE_SOAPED := "soaped"
const STATE_LOOSENED := "loosened"
const STATE_RUNOFF := "runoff"
const STATE_FLYING := "flying"
const STATE_REMOVED := "removed"
const STYLE_DROPLET := "droplet"
const STYLE_RING := "ring"
const STYLE_MIST := "mist"
const STYLE_SPRAY_FAN := "spray_fan"
const STYLE_SPLASH := "splash"
const STYLE_STREAK := "streak"
const STYLE_SWIRL := "swirl"
const STYLE_BUBBLE := "bubble"
const STYLE_FOAM := "foam"
const STYLE_SPARKLE := "sparkle"
const STYLE_CONFETTI := "confetti"
const WATER_EFFECT_STYLES := [STYLE_DROPLET, STYLE_MIST, STYLE_SPRAY_FAN, STYLE_SPLASH]
const WATER_EFFECT_PARTICLE_CAP := 72
const FOAM_EFFECT_STYLES := [STYLE_BUBBLE, STYLE_FOAM]
const FOAM_EFFECT_PARTICLE_CAP := 64
const PARTICLE_CAP := 192
const FOAM_BOMB_BURST_PARTICLE_COUNT := 28
const OIL_SHEEN_BAND_COUNT := 5
const OIL_SHEEN_MAX_ALPHA := 0.46
const BODY_FOAM_SOAP_RATE := 0.36
const BODY_FOAM_WATER_RATE := 0.72
const BODY_FOAM_RUNOFF_DECAY := 1.15
# Normalized, deliberately interleaved spots keep partial coverage distributed
# across every silhouette instead of painting one scanline at a time.
const BODY_FOAM_SPOT_UVS := [
	Vector2(0.50, 0.46), Vector2(0.24, 0.62), Vector2(0.76, 0.62), Vector2(0.36, 0.30),
	Vector2(0.64, 0.30), Vector2(0.18, 0.78), Vector2(0.82, 0.78), Vector2(0.50, 0.72),
	Vector2(0.31, 0.49), Vector2(0.69, 0.49), Vector2(0.42, 0.86), Vector2(0.58, 0.86),
	Vector2(0.15, 0.52), Vector2(0.85, 0.52), Vector2(0.50, 0.20), Vector2(0.28, 0.75),
	Vector2(0.72, 0.75), Vector2(0.40, 0.58), Vector2(0.60, 0.58), Vector2(0.22, 0.88),
	Vector2(0.78, 0.88), Vector2(0.34, 0.40), Vector2(0.66, 0.40), Vector2(0.50, 0.92),
	Vector2(0.12, 0.68), Vector2(0.88, 0.68), Vector2(0.43, 0.24), Vector2(0.57, 0.24),
	Vector2(0.26, 0.55), Vector2(0.74, 0.55), Vector2(0.38, 0.69), Vector2(0.62, 0.69),
	Vector2(0.31, 0.84), Vector2(0.69, 0.84), Vector2(0.46, 0.38), Vector2(0.54, 0.78),
]
const DAILY_MISSION_POOL := GameConfig.DAILY_MISSION_POOL
const DAILY_MISSION_REWARD := GameConfig.DAILY_MISSION_REWARD

var selected_tool: String = TOOL_WATER
var dirt_patches: Array = []
var _wheel_dirt_indices: Array[int] = []
var particles: Array = []
var rng := RandomNumberGenerator.new()
var is_washing := false
var pointer_position := Vector2.ZERO
var _primary_touch_index := -1
# Velocity-scaled smear left behind the active tool while scrubbing. Gives the
# core drag gesture a sense of weight: faster sweeps paint a longer, brighter
# tool-tinted streak, so the player feels the effort of "really scrubbing".
var wash_trail: Array = []
var wash_speed := 0.0
var _trail_last_pos := Vector2.ZERO
var _trail_has_last := false
const TRAIL_LIFETIME := 0.4
const TRAIL_MIN_GAP := 7.0
const TRAIL_MAX_POINTS := 16
const COMBO_BONUS_AMOUNTS := GameConfig.COMBO_BONUS_AMOUNTS
var clean_progress := 0.0
var initial_dirt_total := 1.0
# Highest unlocked progression stays stable while active_level_index can revisit
# a deterministic earlier stage from the title sheet.
var level_index := 1
var active_level_index := 1
var completed := false
var completion_burst_done := false
var _car_transition_phase := CAR_TRANSITION_IDLE
var _car_transition_elapsed := 0.0
var _pending_next_level := -1
var _gleam_time := -1.0
const GLEAM_DURATION := 0.72
# Single tuning hook for low-end/reduced-motion policy (#75). The clean-shine
# renderer reads this scale only; gameplay progress and completion stay untouched.
const CLEAN_SHINE_INTENSITY_SCALE := 1.0
var body_foam_coverage := 0.0
var body_foam_runoff := 0.0
var _foam_bomb_burst_count := 0
var _water_boost_remaining := 0.0
var _progress_milestone_hit := 0
var _progress_milestone_time := -1.0
var _progress_milestone_text := ""
var _progress_milestone_color := Color.WHITE
var combo_count := 0
var combo_timer := 0.0
var combo_protection_available := false
var combo_grace_active := false
var _combo_grace_flash_time := -10.0
var _halo_phase := 0.0
var best_combo := 0
var _combo_bonus_time := -10.0
var _combo_bonus_amount := 0
var _gold_spot_rewards_granted := 0
var _gold_spot_pop_time := -10.0
var _gold_spot_pop_position := Vector2.ZERO
var _gold_spot_pop_amount := 0
var level_time := 0.0
var earned_stars := 0
var combo_pop_time := -10.0
var _combo_milestone_flash_time := -10.0
var _combo_milestone_flash_color := Color.WHITE
var _combo_milestone_fanfare := ""
var _combo_milestone_count := 0
var _customer_cheer_text := ""
var _customer_cheer_time := -10.0
var _customer_completion_time := -10.0
var _last_grade_tracker_text := ""
var best_times: Dictionary = {}
var best_stars: Dictionary = {}
var is_new_record := false
var record_pop_time := -10.0
var _tool_select_time := -10.0
var _bomb_press_time := -10.0
var _tool_misapplied_time := -10.0
var _tool_misapplied_tool_id := ""
var game_state := STATE_TITLE
var coins := 0
var total_stars := 0
var coin_reward := 0
var customer_tip_reward := 0
var _level_milestone_bonus := 0
var level_mistakes := 0
var _perfect_wash_bonus := 0
# A: free foam bombs granted via rewarded ad this level (capped by
# GameConfig.FREE_AD_BOMB_PER_LEVEL). B: _double_claimed is set once the level-end
# 2x-coins ad has been watched to completion (one grant per level).
var _free_ad_bombs_used := 0
var _double_claimed := false
# Latched once when the level is completed so the completion panel layout does not
# jitter if ad readiness flips frame-to-frame while the panel is on screen. The
# button's active/tappable state still tracks live ad readiness (see draw/input).
var _double_offer_shown := false
var _star_reveal_times: Array[float] = [-10.0, -10.0, -10.0]
const STAR_REVEAL_DELAYS: Array[float] = [0.3, 0.75, 1.25]
const STAR_REVEAL_POP_DUR := 0.5
var sound_enabled := true
var language_preference := ""
var tutorial_seen := false
var show_tutorial := false
var _tutorial_tab := TUTORIAL_TAB_TOOLS
var _tutorial_returns_to_pause := false
var _tutorial_event_source := ""
var persistence_enabled := true
var last_particle_spawn := 0.0
var car_color := Color("#ffcf5a")
var car_type := "compact"
# Localized at runtime in _rebuild_i18n_labels() (device language -> ko/en).
var car_type_labels: Dictionary = {}
var canvas_origin := Vector2.ZERO
var canvas_scale := 1.0
# window.__foamPartySafeArea proxy (web/AIT only): CSS-px safe-area insets + viewport
# size published by the AIT wrapper (safeAreaRuntime.ts). Cached once available.
var _web_safe_area = null
# AIT back-button / pause navigation. show_pause = in-level pause menu, show_quit_confirm
# = "quit app?" dialog. _web_nav bridges to window.__foamPartyNav (setBackHandler/closeApp).
var show_pause := false
var show_quit_confirm := false
var _web_nav = null
var _back_cb = null
var _back_registered := false
var ui_font: Font
# Procedural audio engine (relocated to AudioService in PR-R3). Instantiated in
# _ready(); main triggers sounds through its public methods.
var audio: AudioService

# Analytics adapter (Firebase). Instantiated in _ready() and always set, so call
# sites can invoke analytics.log_event(...) unguarded. No-ops when the Firebase
# singletons are absent (headless / plugin not bundled). Events go through
# _emit_analytics with a pure-core catalog builder, not scattered dictionaries.
var analytics: Node = null
var _level_started := false
var ads: Node = null
# Show a game-over interstitial only every Nth level transition, so ads never
# interrupt every single completion.
const INTERSTITIAL_EVERY := 3
var _level_transitions := 0

var daily_mission_type := ""
var daily_mission_label := ""
var daily_mission_target := 0
var daily_mission_requirement := 0
var daily_mission_reward := DAILY_MISSION_REWARD
var daily_mission_progress := 0
var daily_mission_claimed := false
var daily_mission_date := ""
var _daily_mission_pop_time := -10.0
var _daily_progress_dirty := false
var upgrade_water := 0
var upgrade_soap := 0
var upgrade_sponge := 0
var reach_upgrade_air := 0
var reach_upgrade_water := 0
var reach_upgrade_soap := 0
var reach_upgrade_sponge := 0
var _upgrade_panel_tab := UPGRADE_TAB_POWER
var show_upgrade_panel := false
var show_skin_panel := false
var show_stage_panel := false
var show_achievement_panel := false
var show_booster_panel := false
var _stage_page := 0
var _skin_panel_tab := 0
var skin_water := "classic"
var skin_air := "classic"
var skin_soap := "classic"
var skin_sponge := "classic"
var selected_car_paint := ""
var license_plate_text := LicensePlate.DEFAULT_TEXT
var owned_skins: Dictionary = Economy.default_skin_ownership(SkinCatalog.catalog())
var owned_car_paints: Dictionary = {CarPaintCatalog.AUTO_ID: true}
var _nozzle_skins: Dictionary = SkinCatalog.catalog()
var _car_paints: Dictionary = CarPaintCatalog.catalog()
var _main_save_dirty := false
var _daily_save_timer: Timer = null
var achievement_counters: Dictionary = AchievementProgress.default_counters()
var achievement_claimed: Dictionary = {}

var tool_ids := [TOOL_AIR, TOOL_WATER, TOOL_SOAP, TOOL_SPONGE]
# Localized at runtime in _rebuild_i18n_labels() (device language -> ko/en).
var tool_labels: Dictionary = {}
var tool_colors := {
	TOOL_AIR: Color("#b7f0ff"),
	TOOL_WATER: Color("#49a7ff"),
	TOOL_SOAP: Color("#f8f4a6"),
	TOOL_SPONGE: Color("#ff9f5a"),
}
var style_cache: Dictionary = {}
# Lazily loaded flat-vector art assets (res://assets/art/*.png). Keyed by base
# name; missing/unimported textures fall back to null so procedural draws still work.
var art_tex: Dictionary = {}
var _hint_pill_box: StyleBoxFlat
var _hint_shadow_box: StyleBoxFlat
var _tool_hint_box: StyleBoxFlat
var _gold_spot_pop_box: StyleBoxFlat
var _hint_patch: DirtPatch = null
var _stalled_dirt_highlight_active := false
var _seconds_without_cleaning := 0.0
var _last_observed_clean_progress := 0.0
var car_shapes: Dictionary = {}
var _body_foam_spot_cache: Dictionary = {}
# Audio-trigger decision state stays here (main decides WHEN to play); the
# players/streams themselves moved to AudioService in PR-R3.
var _prev_star3_time_ok := true
var _prev_star2_time_ok := true
var _star3_combo_unlocked := false
var _last_milestone_haptic_combo := -1
var _prev_in_warn_zone := false
var _prev_patience_zone := 3
var _bar_fill_style := StyleBoxFlat.new()


func _ready() -> void:
	rng.seed = 42690
	mouse_filter = Control.MOUSE_FILTER_STOP
	persistence_enabled = DisplayServer.get_name() != "headless" and OS.get_environment("FOAM_DISABLE_SAVE") != "1"
	I18n.setup()
	_rebuild_i18n_labels()
	_setup_font()
	_build_car_shapes()
	_load_progress()
	if daily_mission_type.is_empty():
		_generate_daily_mission(_today_string())
	if persistence_enabled:
		_daily_save_timer = Timer.new()
		_daily_save_timer.wait_time = 1.0
		_daily_save_timer.timeout.connect(_flush_daily_if_dirty)
		add_child(_daily_save_timer)
		_daily_save_timer.start()
	audio = AudioService.new()
	add_child(audio)
	audio.setup()
	analytics = FirebaseAnalyticsAdapter.new()
	add_child(analytics)
	analytics.setup()
	_emit_analytics(FtueEvents.title_screen_view(FtueEvents.ENTRY_COLD_START))
	ads = AdService.new()
	add_child(ads)
	ads.configure(analytics)
	ads.setup()
	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = BAR_COL_START
	_bar_fill_style.set_corner_radius_all(12)
	_apply_sound_setting()
	reset_game(level_index, "cold_start")


func _load_progress() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	var main_claimed_date := ""
	var main_save_ok := config.load(SAVE_PATH) == OK
	if main_save_ok:
		level_index = max(1, int(config.get_value("game", "level", 1)))
		coins = max(0, int(config.get_value("game", "coins", 0)))
		total_stars = max(0, int(config.get_value("game", "total_stars", 0)))
		sound_enabled = bool(config.get_value("settings", "sound", true))
		_load_language_preference(config)
		tutorial_seen = bool(config.get_value("settings", "tutorial_seen", false))
		_load_upgrade_progress(config)
		_load_nozzle_skin_customization(config)
		_load_car_paint_customization(config)
		license_plate_text = LicensePlate.safe_selection(String(config.get_value("customization", "license_plate", LicensePlate.DEFAULT_TEXT)))
		var stored_best: Variant = config.get_value("game", "best_times", {})
		if stored_best is Dictionary:
			best_times = {}
			for key in (stored_best as Dictionary):
				best_times[int(key)] = float(stored_best[key])
		var stored_best_stars: Variant = config.get_value("game", "best_stars", {})
		if stored_best_stars is Dictionary:
			best_stars = {}
			for key in (stored_best_stars as Dictionary):
				best_stars[int(key)] = clampi(int(stored_best_stars[key]), 0, 3)
		main_claimed_date = String(config.get_value("daily", "claimed_date", ""))
		_load_achievement_progress(config)
	_apply_language_preference()
	var today := _today_string()
	var daily_config := ConfigFile.new()
	if daily_config.load(DAILY_SAVE_PATH) != OK:
		_generate_daily_mission(today)
		if main_claimed_date == today:
			daily_mission_claimed = true
			daily_mission_progress = daily_mission_target
		return
	var saved_date: String = daily_config.get_value("daily", "date", "")
	if saved_date != today:
		_generate_daily_mission(today)
		if main_claimed_date == today:
			daily_mission_claimed = true
			daily_mission_progress = daily_mission_target
			daily_mission_date = today
		return
	var loaded_type: String = daily_config.get_value("daily", "type", "")
	var loaded_label: String = daily_config.get_value("daily", "label", "")
	var loaded_target: int = int(daily_config.get_value("daily", "target", 0))
	var loaded_requirement: int = int(daily_config.get_value("daily", "requirement", 0))
	# Preserve today's progress for installs that generated the retired sticker
	# mission before road grime replaced that dirt type.
	if loaded_type == "sticker":
		loaded_type = "road_grime"
		loaded_label = tr("DM_ROAD_GRIME") % loaded_target
		_daily_progress_dirty = true
	var type_valid := false
	for m in DAILY_MISSION_POOL:
		if m["type"] == loaded_type:
			type_valid = true
			break
	if loaded_target <= 0 or not type_valid or loaded_label.is_empty():
		_generate_daily_mission(today)
		if main_claimed_date == today:
			daily_mission_claimed = true
			daily_mission_progress = daily_mission_target
		return
	daily_mission_type = loaded_type
	daily_mission_label = loaded_label
	daily_mission_target = loaded_target
	daily_mission_requirement = maxi(0, loaded_requirement)
	if daily_mission_requirement == 0:
		daily_mission_requirement = int(DailyMission.mission_for_type(loaded_type).get("requirement", 0))
	daily_mission_reward = DailyMission.reward_for_type(loaded_type)
	daily_mission_progress = clampi(int(daily_config.get_value("daily", "progress", 0)), 0, daily_mission_target)
	daily_mission_claimed = bool(daily_config.get_value("daily", "claimed", false))
	if daily_mission_claimed or daily_mission_progress >= daily_mission_target or main_claimed_date == today:
		daily_mission_claimed = true
		if daily_mission_progress < daily_mission_target:
			daily_mission_progress = daily_mission_target
	daily_mission_date = saved_date
	if main_save_ok and daily_mission_claimed and main_claimed_date != today:
		_grant_daily_mission_coins()
		_main_save_dirty = true


func _load_car_paint_customization(config: ConfigFile) -> void:
	selected_car_paint = CarPaintCatalog.safe_selection(String(config.get_value("customization", "car_paint", "")))
	owned_car_paints = {CarPaintCatalog.AUTO_ID: true}
	var raw_owned: Variant = config.get_value("customization", "owned_car_paints", {})
	if raw_owned is Dictionary:
		for raw_id in (raw_owned as Dictionary):
			var paint_id := String(raw_id)
			if CarPaintCatalog.is_valid_id(paint_id):
				owned_car_paints[paint_id] = true
	if not selected_car_paint.is_empty() and not owned_car_paints.get(selected_car_paint, false):
		selected_car_paint = ""


func _load_nozzle_skin_customization(config: ConfigFile) -> void:
	skin_water = String(config.get_value("skins", "water", "classic"))
	skin_air = String(config.get_value("skins", "air", "classic"))
	skin_soap = String(config.get_value("skins", "soap", "classic"))
	skin_sponge = String(config.get_value("skins", "sponge", "classic"))
	var raw_owned: Variant = config.get_value("skins", "owned", {})
	var owned_dictionary: Dictionary = raw_owned if raw_owned is Dictionary else {}
	owned_skins = Economy.normalize_skin_ownership(_nozzle_skins, owned_dictionary, {
		TOOL_WATER: skin_water,
		TOOL_AIR: skin_air,
		TOOL_SOAP: skin_soap,
		TOOL_SPONGE: skin_sponge,
	})
	if not _is_nozzle_skin_owned(TOOL_WATER, skin_water):
		skin_water = "classic"
	if not _is_nozzle_skin_owned(TOOL_AIR, skin_air):
		skin_air = "classic"
	if not _is_nozzle_skin_owned(TOOL_SOAP, skin_soap):
		skin_soap = "classic"
	if not _is_nozzle_skin_owned(TOOL_SPONGE, skin_sponge):
		skin_sponge = "classic"


func _store_nozzle_skin_customization(config: ConfigFile) -> void:
	config.set_value("skins", "water", skin_water)
	config.set_value("skins", "air", skin_air)
	config.set_value("skins", "soap", skin_soap)
	config.set_value("skins", "sponge", skin_sponge)
	config.set_value("skins", "owned", owned_skins)


func _store_car_paint_customization(config: ConfigFile) -> void:
	config.set_value("customization", "car_paint", selected_car_paint)
	config.set_value("customization", "owned_car_paints", owned_car_paints)


func _load_achievement_progress(config: ConfigFile) -> void:
	achievement_counters = AchievementProgress.normalize_counters(
		config.get_value("achievements", "counters", {})
	)
	achievement_claimed = AchievementProgress.normalize_claimed(
		config.get_value("achievements", "claimed", {})
	)
	# total_stars predates achievements and is an exact local counter, so existing
	# players keep that progress and receive the one-time reward after migration.
	var result := AchievementProgress.apply_value(
		achievement_counters, achievement_claimed,
		AchievementProgress.COUNTER_STARS, total_stars
	)
	achievement_counters = result["counters"]
	achievement_claimed = result["claimed"]
	var migration_reward := int(result["reward"])
	if migration_reward > 0:
		coins += migration_reward
		_main_save_dirty = true


func _store_achievement_progress(config: ConfigFile) -> void:
	config.set_value("achievements", "counters", achievement_counters)
	config.set_value("achievements", "claimed", achievement_claimed)


func _load_upgrade_progress(config: ConfigFile) -> void:
	upgrade_water = clampi(int(config.get_value("upgrades", "water", 0)), 0, UPGRADE_MAX_LEVEL)
	upgrade_soap = clampi(int(config.get_value("upgrades", "soap", 0)), 0, UPGRADE_MAX_LEVEL)
	upgrade_sponge = clampi(int(config.get_value("upgrades", "sponge", 0)), 0, UPGRADE_MAX_LEVEL)
	reach_upgrade_air = clampi(int(config.get_value("upgrades", "reach_air", 0)), 0, REACH_UPGRADE_MAX_LEVEL)
	reach_upgrade_water = clampi(int(config.get_value("upgrades", "reach_water", 0)), 0, REACH_UPGRADE_MAX_LEVEL)
	reach_upgrade_soap = clampi(int(config.get_value("upgrades", "reach_soap", 0)), 0, REACH_UPGRADE_MAX_LEVEL)
	reach_upgrade_sponge = clampi(int(config.get_value("upgrades", "reach_sponge", 0)), 0, REACH_UPGRADE_MAX_LEVEL)


func _store_upgrade_progress(config: ConfigFile) -> void:
	config.set_value("upgrades", "water", upgrade_water)
	config.set_value("upgrades", "soap", upgrade_soap)
	config.set_value("upgrades", "sponge", upgrade_sponge)
	config.set_value("upgrades", "reach_air", reach_upgrade_air)
	config.set_value("upgrades", "reach_water", reach_upgrade_water)
	config.set_value("upgrades", "reach_soap", reach_upgrade_soap)
	config.set_value("upgrades", "reach_sponge", reach_upgrade_sponge)


func _save_progress() -> Error:
	if not persistence_enabled:
		return OK
	var config := ConfigFile.new()
	config.set_value("game", "level", level_index)
	config.set_value("game", "coins", coins)
	config.set_value("game", "total_stars", total_stars)
	config.set_value("settings", "sound", sound_enabled)
	_store_language_preference(config)
	config.set_value("settings", "tutorial_seen", tutorial_seen)
	config.set_value("game", "best_times", best_times)
	config.set_value("game", "best_stars", best_stars)
	config.set_value("daily", "claimed_date", daily_mission_date if daily_mission_claimed else "")
	_store_upgrade_progress(config)
	_store_nozzle_skin_customization(config)
	_store_car_paint_customization(config)
	config.set_value("customization", "license_plate", license_plate_text)
	_store_achievement_progress(config)
	return config.save(SAVE_PATH)


func _record_achievement_value(counter_key: String, value: int) -> int:
	var previous_counters := achievement_counters.duplicate(true)
	var previous_claimed := achievement_claimed.duplicate(true)
	var previous_coins := coins
	var previous_dirty := _main_save_dirty
	var result := AchievementProgress.apply_value(
		achievement_counters, achievement_claimed, counter_key, value
	)
	achievement_counters = result["counters"]
	achievement_claimed = result["claimed"]
	if achievement_counters == previous_counters and achievement_claimed == previous_claimed:
		return 0
	var reward := int(result["reward"])
	coins += reward
	if reward > 0:
		# Completion and its coin grant are one transaction. A failed save restores
		# every achievement mutation so a later retry cannot duplicate the payout.
		if _save_progress() != OK:
			achievement_counters = previous_counters
			achievement_claimed = previous_claimed
			coins = previous_coins
			_main_save_dirty = previous_dirty
			return 0
		_main_save_dirty = false
		if audio != null:
			audio.play_coin_bonus()
	else:
		_main_save_dirty = true
	queue_redraw()
	return reward


func _record_achievement_increment(counter_key: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var current := int(achievement_counters.get(counter_key, 0))
	return _record_achievement_value(counter_key, current + amount)


func _record_achievement_max(counter_key: String, observed_value: int) -> int:
	return _record_achievement_value(counter_key, observed_value)


func _save_daily() -> Error:
	if not persistence_enabled:
		return OK
	var config := ConfigFile.new()
	config.set_value("daily", "type", daily_mission_type)
	config.set_value("daily", "label", daily_mission_label)
	config.set_value("daily", "target", daily_mission_target)
	config.set_value("daily", "requirement", daily_mission_requirement)
	config.set_value("daily", "reward", daily_mission_reward)
	config.set_value("daily", "progress", daily_mission_progress)
	config.set_value("daily", "claimed", daily_mission_claimed)
	config.set_value("daily", "date", daily_mission_date)
	return config.save(DAILY_SAVE_PATH)


func _flush_daily_if_dirty() -> void:
	if _daily_progress_dirty:
		var err := _save_daily()
		if err == OK:
			_daily_progress_dirty = false
	if _main_save_dirty:
		var err := _save_progress()
		if err == OK:
			_main_save_dirty = false


func _apply_sound_setting() -> void:
	audio.apply_sound_setting(sound_enabled)


func _apply_language_preference() -> void:
	I18n.select_locale(language_preference)
	_rebuild_i18n_labels()


func _active_locale() -> String:
	return I18n.normalize_preference(TranslationServer.get_locale())


func _load_language_preference(config: ConfigFile) -> void:
	language_preference = I18n.normalize_preference(String(config.get_value("settings", "language", "")))


func _store_language_preference(config: ConfigFile) -> void:
	if language_preference != "":
		config.set_value("settings", "language", language_preference)


# Forward a catalog-built event through the analytics port. Call sites use the
# pure-core ContentEvents or FtueEvents builders so names and params stay locked.
func _emit_analytics(ev: Dictionary) -> void:
	analytics.log_event(ev["name"], ev["params"])


func start_game(target_level: int = -1, load_reason: String = "title_start") -> void:
	var resolved_level := level_index if target_level < 1 else target_level
	if active_level_index != resolved_level:
		reset_game(resolved_level, load_reason)
	game_state = STATE_PLAYING
	_begin_car_entry()
	_emit_analytics(ContentEvents.game_start(active_level_index))
	_mark_level_started()
	if not tutorial_seen:
		_show_tutorial("first_run")
	queue_redraw()


func _advance_to_next_level(force_transition: bool = false) -> void:
	var next_level := active_level_index + 1
	if _car_transition_phase == CAR_TRANSITION_EXITING:
		return
	if _car_transition_motion_enabled() or force_transition:
		_pending_next_level = next_level
		_car_transition_phase = CAR_TRANSITION_EXITING
		_car_transition_elapsed = 0.0
		is_washing = false
		_stop_tool_loop()
		queue_redraw()
		return
	_commit_next_level(next_level)


func _commit_next_level(next_level: int) -> void:
	level_index = maxi(level_index, next_level)
	reset_game(next_level, "next")
	_save_progress()
	_begin_car_entry()


func _car_transition_motion_enabled() -> bool:
	# Standard headless and screenshot captures must stay deterministic and fully
	# settled. FOAM_REDUCE_MOTION is the forward-compatible hook for #75.
	return DisplayServer.get_name() != "headless" \
		and OS.get_environment("FOAM_DISABLE_SAVE") != "1" \
		and OS.get_environment("FOAM_REDUCE_MOTION") != "1"


func _begin_car_entry(force_transition: bool = false) -> void:
	_pending_next_level = -1
	if not (_car_transition_motion_enabled() or force_transition):
		_car_transition_phase = CAR_TRANSITION_IDLE
		_car_transition_elapsed = 0.0
		return
	_car_transition_phase = CAR_TRANSITION_ENTERING
	_car_transition_elapsed = 0.0
	is_washing = false
	_stop_tool_loop()
	queue_redraw()


func _car_transition_blocks_gameplay() -> bool:
	return _car_transition_phase != CAR_TRANSITION_IDLE


func _car_transition_offset() -> Vector2:
	if _car_transition_phase == CAR_TRANSITION_ENTERING:
		var progress := clampf(_car_transition_elapsed / CAR_ENTRY_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		return Vector2(lerpf(CAR_TRANSITION_DISTANCE, 0.0, eased), 0.0)
	if _car_transition_phase == CAR_TRANSITION_EXITING:
		var progress := clampf(_car_transition_elapsed / CAR_EXIT_DURATION, 0.0, 1.0)
		return Vector2(-CAR_TRANSITION_DISTANCE * pow(progress, 3.0), 0.0)
	return Vector2.ZERO


func _update_car_transition(delta: float) -> void:
	if _car_transition_phase == CAR_TRANSITION_IDLE or show_tutorial or show_pause or show_quit_confirm:
		return
	var duration := CAR_ENTRY_DURATION if _car_transition_phase == CAR_TRANSITION_ENTERING else CAR_EXIT_DURATION
	_car_transition_elapsed = minf(_car_transition_elapsed + maxf(delta, 0.0), duration)
	if _car_transition_elapsed < duration:
		queue_redraw()
		return
	var finished_phase := _car_transition_phase
	_car_transition_phase = CAR_TRANSITION_IDLE
	_car_transition_elapsed = 0.0
	if finished_phase == CAR_TRANSITION_EXITING and _pending_next_level > 0:
		var next_level := _pending_next_level
		_pending_next_level = -1
		_commit_next_level(next_level)
	queue_redraw()


func _mark_level_started() -> void:
	if _level_started:
		return
	_level_started = true
	_emit_analytics(ContentEvents.level_start(active_level_index, car_type))


# Register the Godot back handler with the AIT wrapper once the bridge is present
# (window.__foamPartyNav, installed before Godot boots). Web/AIT only.
func _ensure_back_handler() -> void:
	if _back_registered or not OS.has_feature("web"):
		return
	_web_nav = JavaScriptBridge.get_interface("__foamPartyNav")
	if _web_nav == null:
		return
	_back_cb = JavaScriptBridge.create_callback(_on_back_js)
	_web_nav.setBackHandler(_back_cb)
	_back_registered = true


func _on_back_js(_args: Array) -> void:
	_on_back_pressed()


# Framework back button: dismiss the topmost modal, else pause during a level, else
# ask before quitting on the title. Mirrors the standard Android back stack.
func _on_back_pressed() -> void:
	if show_quit_confirm:
		show_quit_confirm = false
	elif show_booster_panel:
		show_booster_panel = false
	elif show_pause:
		show_pause = false  # back on the pause menu = resume
	elif show_tutorial:
		_dismiss_tutorial()
	elif show_upgrade_panel:
		show_upgrade_panel = false
	elif show_skin_panel:
		show_skin_panel = false
	elif show_stage_panel:
		show_stage_panel = false
	elif show_achievement_panel:
		show_achievement_panel = false
	elif game_state == STATE_PLAYING:
		show_pause = true
		_play_ui_select()
	else:
		show_quit_confirm = true
		_play_ui_select()
	queue_redraw()


func _go_home() -> void:
	show_pause = false
	show_quit_confirm = false
	show_stage_panel = false
	show_achievement_panel = false
	show_booster_panel = false
	is_washing = false
	game_state = STATE_TITLE
	_emit_analytics(FtueEvents.title_screen_view(FtueEvents.ENTRY_PAUSE_HOME))
	_stop_tool_loop()
	_play_ui_select()
	queue_redraw()


func _quit_app() -> void:
	if OS.has_feature("web") and _web_nav != null:
		_web_nav.closeApp()
	else:
		get_tree().quit()


func _process(delta: float) -> void:
	_ensure_back_handler()
	var transition_blocks_gameplay := _car_transition_blocks_gameplay()
	var gameplay_active := game_state == STATE_PLAYING \
		and not completed \
		and not show_tutorial \
		and not show_pause \
		and not show_quit_confirm \
		and not show_booster_panel \
		and not transition_blocks_gameplay
	if gameplay_active:
		level_time += delta
		_update_water_boost(delta)
		_check_star_time_loss()
		var _warn_time := _grade_time_to_downgrade()
		var _in_warn := _warn_time >= 0.0 and _warn_time <= STAR_WARN_SECONDS
		if _in_warn and not _prev_in_warn_zone:
			audio.play_star_warn()
		_prev_in_warn_zone = _in_warn
		var _pzone := CustomerPatience.zone(_current_customer_patience())
		# Policy: one alert per observed downgrade. Cleaning may recover a zone,
		# while equal or upgraded zones stay silent.
		if CustomerPatience.should_warn(_prev_patience_zone, _pzone):
			audio.play_patience_warn()
		_prev_patience_zone = _pzone
		if combo_timer > 0.0:
			combo_timer -= delta
			if combo_timer <= 0.0:
				_resolve_combo_timeout()
			elif combo_count >= _star3_combo_requirement():
				var active_window := COMBO_GRACE if combo_grace_active else COMBO_WINDOW
				var urgency := clampf(1.0 - combo_timer / maxf(active_window, 0.001), 0.0, 1.0)
				_halo_phase = fmod(_halo_phase + delta * (9.0 + urgency * 6.0) * TAU, TAU)
	else:
		var _wt := _grade_time_to_downgrade()
		_prev_in_warn_zone = _wt >= 0.0 and _wt <= STAR_WARN_SECONDS
		_prev_patience_zone = CustomerPatience.zone(_current_customer_patience())

	if is_washing and gameplay_active:
		_apply_tool_at(pointer_position, delta)

	_update_car_transition(delta)
	_update_wash_trail(delta)
	_update_dirt_motion(delta)
	_update_particles(delta)
	body_foam_runoff = maxf(0.0, body_foam_runoff - delta * BODY_FOAM_RUNOFF_DECAY)
	_update_clean_progress()
	_update_stalled_dirt_highlight(delta)
	_update_audio()
	if _gleam_time >= 0.0:
		_gleam_time = minf(_gleam_time + delta / GLEAM_DURATION, 1.0)
		queue_redraw()
		if _gleam_time >= 1.0:
			_gleam_time = -1.0
	# Per-frame redraw drives all animation (dirt, particles, combo/tool pulses,
	# hint fade). The coaching glow pulses via sin(time), so keep redrawing while
	# a hint is active even if the unconditional redraw below is ever made lazy.
	if _active_hint_tool() != "":
		queue_redraw()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		var prog_err := _save_progress()
		var daily_err := _save_daily()
		if prog_err == OK:
			_main_save_dirty = false
		else:
			_main_save_dirty = true
		if daily_err == OK:
			_daily_progress_dirty = false
		else:
			_daily_progress_dirty = true


func _rebuild_i18n_labels() -> void:
	tool_labels = {
		TOOL_AIR: tr("TOOL_AIR"),
		TOOL_WATER: tr("TOOL_WATER"),
		TOOL_SOAP: tr("TOOL_SOAP"),
		TOOL_SPONGE: tr("TOOL_SPONGE"),
	}
	car_type_labels = {
		"compact": tr("CAR_COMPACT"),
		"sports": tr("CAR_SPORTS"),
		"truck": tr("CAR_TRUCK"),
		"van": tr("CAR_VAN"),
		"offroad": tr("CAR_OFFROAD"),
	}


func _setup_font() -> void:
	# Godot Web/AIT canvas cannot rely on SystemFont OS-name fallback for Korean,
	# so bundle Do Hyeon (OFL) as the primary UI font. Keep a SystemFont fallback
	# for the few decorative glyphs Do Hyeon lacks on native platforms.
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Apple SD Gothic Neo",
		"AppleGothic",
		"Noto Sans CJK KR",
		"Noto Sans KR",
		"Malgun Gothic",
		"Arial Unicode MS",
	])
	var bundled: FontFile = load("res://assets/fonts/DoHyeon-Regular.ttf")
	if bundled != null:
		bundled.fallbacks = [system_font]
		ui_font = bundled
	else:
		ui_font = system_font


func _font() -> Font:
	if ui_font != null:
		return ui_font
	return get_theme_default_font()


# Lazy texture loader for the flat-vector art assets. Caches the result (including
# a null miss) so a missing/unimported asset never breaks the frame or retries.
func _tex(name: String) -> Texture2D:
	if art_tex.has(name):
		return art_tex[name]
	var tex: Texture2D = load("res://assets/art/%s.png" % name) as Texture2D
	art_tex[name] = tex
	return tex


# Draw an art texture centered at `center`, scaled so its longest edge is `size`.
func _draw_tex_centered(name: String, center: Vector2, size: float, modulate := Color.WHITE) -> bool:
	var tex := _tex(name)
	if tex == null:
		return false
	var src := tex.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return false
	var scale := size / maxf(src.x, src.y)
	var draw_size := src * scale
	draw_texture_rect(tex, Rect2(center - draw_size * 0.5, draw_size), false, modulate)
	return true


func _style(key: String, bg: Color, corner: float, border: Color = Color(0.0, 0.0, 0.0, 0.0), border_width: int = 0) -> StyleBoxFlat:
	if style_cache.has(key):
		return style_cache[key]
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(int(corner))
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	style_cache[key] = style
	return style


# --- thin delegating wrappers to AudioService (preserve existing call sites) ---
func _update_audio() -> void:
	audio.update(is_washing, selected_tool, completed)


func _stop_tool_loop() -> void:
	audio.stop_tool_loop()


func _play_ui_select() -> void:
	audio.play_ui_select()


func _play_completion_sound() -> void:
	audio.play_completion()


func _play_removal_sound() -> void:
	audio.play_removal(combo_count)


func _play_star_earn_sfx(stars: int, on_finished: Callable = Callable()) -> void:
	audio.play_star_earn(stars, on_finished)


func _check_star_time_loss() -> void:
	var star3_time_ok := level_time <= _star_time_threshold(3)
	var star2_time_ok := level_time <= _star_time_threshold(2)
	if (_prev_star3_time_ok and not star3_time_ok) or (_prev_star2_time_ok and not star2_time_ok):
		audio.play_star_lost()
	_prev_star3_time_ok = star3_time_ok
	_prev_star2_time_ok = star2_time_ok


func _spawn_combo_break_burst() -> void:
	var badge_center := Vector2(195.0, _combo_badge_center_y())
	var fizzle_col := Color(0.68, 0.82, 1.0, 0.88)
	var count: int = rng.randi_range(4, 6)
	for _i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(40.0, 85.0)
		var offset := Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-5.0, 5.0))
		_append_particle(WashParticle.new(
			badge_center + offset,
			Vector2.from_angle(angle) * speed,
			rng.randf_range(0.28, 0.46),
			rng.randf_range(4.0, 7.5),
			fizzle_col,
			STYLE_SPARKLE
		))
	audio.play_combo_break()


func _resolve_combo_timeout() -> void:
	var transition: Dictionary = ComboProtection.timeout_transition(combo_count, combo_protection_available)
	var previous_combo := combo_count
	combo_count = int(transition["combo_count"])
	combo_timer = float(transition["combo_timer"])
	combo_protection_available = bool(transition["protection_available"])
	combo_grace_active = bool(transition["grace_active"])
	if combo_grace_active:
		_combo_grace_flash_time = float(Time.get_ticks_msec()) / 1000.0
	elif bool(transition["did_reset"]):
		if previous_combo >= 2:
			_spawn_combo_break_burst()
		_last_milestone_haptic_combo = -1


func _input(event: InputEvent) -> void:
	# The project handles real mouse and real touch events separately. Godot can
	# additionally synthesize the other pointer type with DEVICE_ID_EMULATION;
	# processing both makes one tap toggle sound twice or open and immediately
	# close the help overlay. Ignore only those synthetic duplicates.
	if event.device == InputEvent.DEVICE_ID_EMULATION and (
		event is InputEventMouseButton
		or event is InputEventMouseMotion
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	):
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			_handle_key(key_event.keycode)
		return

	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		var design_point := _to_design(button_event.position)
		if button_event.pressed:
			if _handle_tap(design_point):
				return
			# Only start washing inside the car/dirt band; taps in the top HUD or
			# elsewhere do nothing (and never steal touches from the HUD buttons).
			if _point_in_wash_area(design_point) and not _car_transition_blocks_gameplay():
				pointer_position = design_point
				is_washing = true
		else:
			is_washing = false
		return

	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		pointer_position = _to_design(motion_event.position)
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			# Browser Touch.identifier values are opaque and may be large non-zero
			# integers on iOS WKWebView. Track the first active finger instead of
			# assuming the primary touch always has index 0.
			if _primary_touch_index == -1:
				_primary_touch_index = touch_event.index
			elif touch_event.index != _primary_touch_index:
				return
			var touch_point := _to_design(touch_event.position)
			if _handle_tap(touch_point):
				return
			if _point_in_wash_area(touch_point) and not _car_transition_blocks_gameplay():
				pointer_position = touch_point
				is_washing = true
		else:
			if touch_event.index != _primary_touch_index:
				return
			is_washing = false
			_primary_touch_index = -1
		return

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == _primary_touch_index:
			pointer_position = _to_design(drag_event.position)


func _draw() -> void:
	_update_canvas_transform()
	_set_design_draw_transform()

	_draw_background()
	if game_state == STATE_PLAYING:
		_draw_status()
	if game_state != STATE_TITLE:
		var transition_offset := _car_transition_offset()
		_set_gameplay_draw_transform(transition_offset)
		_draw_car()
		_set_design_draw_transform(transition_offset)
		_draw_dirt()
		_draw_particles()
		_draw_gleam()
		_set_design_draw_transform()
	if game_state == STATE_TITLE:
		_draw_title_screen()
		if show_upgrade_panel:
			_draw_upgrade_panel()
		if show_skin_panel:
			_draw_skin_panel()
		if show_stage_panel:
			_draw_stage_panel()
		if show_achievement_panel:
			_draw_achievement_panel()
	else:
		_draw_wash_trail()
		_draw_tool_cursor()
		# One compact summary row: stars, customer mood, and daily mission.
		_draw_grade_tracker()
		_draw_customer_patience()
		_draw_daily_mission()
		_draw_tool_hint()
		_draw_combo_badge()
		_draw_booster_button()
		_draw_toolbar()
		_draw_completion_panel()
		_draw_combo_milestone_flash()
		_draw_gold_spot_reward_pop()
	# Playing HUD exposes one pause/settings entry only. Sound and guide actions
	# live inside that sheet; title-screen shortcuts remain available before play.
	if game_state == STATE_PLAYING and not completed and not show_tutorial and not show_pause and not show_quit_confirm and not show_booster_panel and not _car_transition_blocks_gameplay():
		_draw_pause_entry()
	elif game_state == STATE_TITLE and not (show_upgrade_panel or show_skin_panel or show_stage_panel or show_achievement_panel):
		_draw_top_buttons()
	if show_tutorial:
		_draw_tutorial()
	if show_booster_panel:
		_draw_booster_panel()
	_draw_pause_menu()
	_draw_quit_confirm()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func reset_game(new_level: int, load_reason: String = "manual") -> void:
	_emit_analytics(FtueEvents.level_load_start(new_level, load_reason))
	active_level_index = maxi(new_level, 1)
	_level_started = false
	completed = false
	completion_burst_done = false
	_car_transition_phase = CAR_TRANSITION_IDLE
	_car_transition_elapsed = 0.0
	_pending_next_level = -1
	body_foam_coverage = 0.0
	body_foam_runoff = 0.0
	_foam_bomb_burst_count = 0
	_water_boost_remaining = 0.0
	show_booster_panel = false
	_free_ad_bombs_used = 0
	_double_claimed = false
	_double_offer_shown = false
	_gleam_time = -1.0
	is_washing = false
	_primary_touch_index = -1
	wash_trail.clear()
	wash_speed = 0.0
	_trail_has_last = false
	combo_count = 0
	combo_timer = 0.0
	combo_protection_available = false
	combo_grace_active = false
	_combo_grace_flash_time = -10.0
	best_combo = 0
	level_time = 0.0
	# Sync immediately after the time reset so the first playing frame cannot
	# emit a false downgrade. At level_time=0 the shared model always returns 1.
	_prev_patience_zone = CustomerPatience.zone(_current_customer_patience())
	_prev_star3_time_ok = true
	_prev_star2_time_ok = true
	_star3_combo_unlocked = false
	_last_milestone_haptic_combo = -1
	_prev_in_warn_zone = false
	earned_stars = 0
	_star_reveal_times = [-10.0, -10.0, -10.0]
	combo_pop_time = -10.0
	_combo_milestone_flash_time = -10.0
	_combo_milestone_flash_color = Color.WHITE
	_combo_milestone_fanfare = ""
	_combo_milestone_count = 0
	_gold_spot_rewards_granted = 0
	_gold_spot_pop_time = -10.0
	_gold_spot_pop_position = Vector2.ZERO
	_gold_spot_pop_amount = 0
	_customer_cheer_text = ""
	_customer_cheer_time = -10.0
	_customer_completion_time = -10.0
	is_new_record = false
	record_pop_time = -10.0
	_progress_milestone_hit = 0
	_progress_milestone_time = -1.0
	_progress_milestone_text = ""
	_progress_milestone_color = Color.WHITE
	_level_milestone_bonus = 0
	customer_tip_reward = 0
	level_mistakes = 0
	_perfect_wash_bonus = 0
	_stop_tool_loop()
	particles.clear()
	_set_car_palette()
	_spawn_dirt()
	_update_clean_progress()
	_reset_stalled_dirt_highlight()
	_emit_analytics(FtueEvents.level_load_complete(active_level_index, car_type, load_reason))
	if game_state == STATE_PLAYING:
		_mark_level_started()
	queue_redraw()


func get_patch_count_for_test() -> int:
	return dirt_patches.size()


func get_patch_centers_for_test() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for raw_patch in dirt_patches:
		centers.append(_patch_center(raw_patch as DirtPatch))
	return centers


func get_wheel_specs_for_test() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wheel in _wheel_specs():
		result.append({
			"center": _gameplay_point(wheel["center"]),
			"radius": _gameplay_length(float(wheel["radius"])),
		})
	return result


func get_wheel_dirt_indices_for_test() -> Array[int]:
	return _wheel_dirt_indices.duplicate()


func get_initial_dirt_total_for_test() -> float:
	return initial_dirt_total


func get_dirt_spawn_pool_size_for_test() -> int:
	return _dirt_spawn_positions().size()


func get_dirt_spawn_min_center_distance_for_test() -> float:
	return _gameplay_length(DirtSpawnPlan.MIN_CENTER_DISTANCE)


func get_dirt_health_scale_for_test(level: int) -> float:
	return DirtSpawnPlan.health_scale_for_level(level)


func get_scaled_dirt_health_for_test(kind: String, base_health: float, level: int) -> float:
	return DirtSpawnPlan.scaled_health(base_health, kind, level)


func get_clean_progress_for_test() -> float:
	return clean_progress


func get_star3_combo_requirement_for_test(level: int) -> int:
	return Scoring.star3_combo_requirement(level)


func is_star3_combo_unlocked_for_test() -> bool:
	return _star3_combo_unlocked


func get_customer_patience_for_test(elapsed_seconds: float, progress: float) -> float:
	return CustomerPatience.value(elapsed_seconds, progress)


func calc_customer_tip_for_test(elapsed_seconds: float, progress: float, payout_ratio: float = 1.0) -> int:
	return Economy.calc_customer_tip(CustomerPatience.value(elapsed_seconds, progress), payout_ratio)


func get_customer_tip_reward_for_test() -> int:
	return customer_tip_reward


func get_customer_patience_zone_for_test(elapsed_seconds: float, progress: float) -> int:
	return CustomerPatience.zone(CustomerPatience.value(elapsed_seconds, progress))


func get_customer_patience_pattern_for_test(patience: float) -> String:
	return _patience_pattern_for_zone(CustomerPatience.zone(patience))


func should_customer_patience_warn_for_test(previous_zone: int, current_zone: int) -> bool:
	return CustomerPatience.should_warn(previous_zone, current_zone)


func get_stalled_dirt_highlight_for_test() -> bool:
	return _stalled_dirt_highlight_active


func get_stalled_dirt_progress_threshold_for_test() -> float:
	return STALLED_DIRT_PROGRESS_THRESHOLD


func get_stalled_dirt_idle_seconds_for_test() -> float:
	return STALLED_DIRT_IDLE_SECONDS


func simulate_stalled_dirt_highlight_for_test(progress: float, idle_seconds: float) -> bool:
	clean_progress = clampf(progress, 0.0, 1.0)
	_last_observed_clean_progress = clean_progress
	_seconds_without_cleaning = 0.0
	_stalled_dirt_highlight_active = false
	_update_stalled_dirt_highlight(maxf(idle_seconds, 0.0))
	return _stalled_dirt_highlight_active


func simulate_cleaning_resumed_for_test(progress_delta: float) -> bool:
	clean_progress = clampf(clean_progress + maxf(progress_delta, 0.0), 0.0, 1.0)
	_update_stalled_dirt_highlight(0.0)
	return _stalled_dirt_highlight_active


func get_clean_shine_alpha_for_test(progress: float) -> float:
	return _clean_shine_alpha(progress)


func get_clean_shine_intensity_scale_for_test() -> float:
	return CLEAN_SHINE_INTENSITY_SCALE


func get_body_foam_coverage_for_test() -> float:
	return body_foam_coverage


func get_body_foam_runoff_for_test() -> float:
	return body_foam_runoff


func get_body_foam_spot_count_for_test() -> int:
	var shapes: Dictionary = car_shapes[car_type]
	var silhouette: PackedVector2Array = shapes["silhouette"]
	return _body_foam_spots(silhouette).size()


func get_foam_bomb_burst_count_for_test() -> int:
	return _foam_bomb_burst_count


func get_water_boost_remaining_for_test() -> float:
	return _water_boost_remaining


func get_water_boost_cost_for_test() -> int:
	return WATER_BOOST_COST


func get_tool_radius_for_test(tool_id: String) -> float:
	return _tool_radius(tool_id)


func get_reach_upgrade_level_for_test(tool_id: String) -> int:
	return _reach_upgrade_level(tool_id)


func set_reach_upgrade_level_for_test(tool_id: String, level: int) -> void:
	_set_reach_upgrade_level(tool_id, level)


func get_tool_power_multiplier_for_test(tool_id: String) -> float:
	return _tool_power_multiplier(tool_id)


func get_foam_effect_particle_count_for_test() -> int:
	return _foam_effect_particle_count()


func get_foam_effect_particle_cap_for_test() -> int:
	return FOAM_EFFECT_PARTICLE_CAP


func get_particle_count_for_test() -> int:
	return particles.size()


func get_particle_cap_for_test() -> int:
	return PARTICLE_CAP


func apply_body_foam_tool_for_test(tool_id: String, delta: float) -> void:
	var previous_tool := selected_tool
	selected_tool = tool_id
	_update_body_foam_from_tool(delta)
	selected_tool = previous_tool


func get_selected_tool_label_for_test() -> String:
	return tool_labels[selected_tool]


func get_audio_stream_count_for_test() -> int:
	return audio.get_stream_count()


func get_combo_for_test() -> int:
	return combo_count


func is_combo_protection_available_for_test() -> bool:
	return combo_protection_available


func is_combo_grace_active_for_test() -> bool:
	return combo_grace_active


func get_best_combo_for_test() -> int:
	return best_combo


func get_level_time_for_test() -> float:
	return level_time


func get_level_mistakes_for_test() -> int:
	return level_mistakes


func get_perfect_wash_bonus_for_test() -> int:
	return _perfect_wash_bonus


func calc_stars_for_test() -> int:
	return _calc_stars()


func get_grade_slot_state_for_test(slot_index: int) -> String:
	return _grade_slot_state(slot_index)


func get_last_grade_tracker_text_for_test() -> String:
	return _last_grade_tracker_text


func get_grade_time_to_downgrade_for_test() -> float:
	return _grade_time_to_downgrade()


func get_car_type_for_test() -> String:
	return car_type


func get_car_color_for_test() -> Color:
	return car_color


func get_selected_car_paint_for_test() -> String:
	return selected_car_paint


func get_car_paint_options_for_test() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for paint in _car_paints.get(CAR_PAINT_TOOL, []):
		result.append((paint as Dictionary).duplicate(true))
	return result


func get_customer_profile_for_test() -> Dictionary:
	return _customer_profile()


func get_customer_reaction_strength_for_test(stars: int) -> float:
	return CustomerPresentation.reaction_strength(stars)


func get_completion_customer_rect_for_test() -> Rect2:
	return _completion_customer_rect(_completion_panel_rect())


func get_car_transition_phase_for_test() -> String:
	return _car_transition_phase


func get_car_transition_offset_for_test() -> Vector2:
	return _car_transition_offset()


func get_license_plate_text_for_test() -> String:
	return license_plate_text


func get_license_plate_options_for_test() -> Array[String]:
	return LicensePlate.options()


func get_active_level_for_test() -> int:
	return active_level_index


func get_unlocked_level_for_test() -> int:
	return level_index


func get_stage_cards_for_test(page: int = 0) -> Array[Dictionary]:
	return StageSelection.cards(level_index, best_times, best_stars, page)


func get_best_stars_for_test(level: int) -> int:
	return int(best_stars.get(level, 0))


func get_coins_for_test() -> int:
	return coins


func get_achievement_definitions_for_test() -> Array[Dictionary]:
	return AchievementProgress.definitions()


func get_achievement_counters_for_test() -> Dictionary:
	return achievement_counters.duplicate(true)


func get_achievement_claimed_for_test() -> Dictionary:
	return achievement_claimed.duplicate(true)


func set_achievement_state_for_test(counters: Dictionary, claimed: Dictionary) -> void:
	achievement_counters = AchievementProgress.normalize_counters(counters)
	achievement_claimed = AchievementProgress.normalize_claimed(claimed)


func record_achievement_progress_for_test(counter_key: String, value: int) -> int:
	return _record_achievement_value(counter_key, value)


func get_daily_mission_reward_for_test() -> int:
	return daily_mission_reward


func prepare_daily_mission_for_test(mission_type: String) -> void:
	configure_daily_mission_for_test(mission_type)
	daily_mission_progress = daily_mission_target
	daily_mission_claimed = false


func configure_daily_mission_for_test(mission_type: String) -> void:
	var mission := DailyMission.mission_for_type(mission_type)
	if mission.is_empty():
		return
	daily_mission_type = String(mission["type"])
	daily_mission_label = String(mission["label"])
	daily_mission_target = int(mission["target"])
	daily_mission_requirement = int(mission["requirement"])
	daily_mission_reward = int(mission["reward"])
	daily_mission_progress = 0
	daily_mission_claimed = false


func claim_daily_mission_for_test() -> bool:
	return _claim_daily_mission_reward()


func grant_daily_mission_retroactive_for_test(mission_type: String) -> int:
	daily_mission_type = mission_type
	daily_mission_reward = DailyMission.reward_for_type(mission_type)
	return _grant_daily_mission_coins()


func get_wash_trail_count_for_test() -> int:
	return wash_trail.size()


func get_water_effect_particle_count_for_test() -> int:
	return _water_effect_particle_count()


func get_water_effect_particle_cap_for_test() -> int:
	return WATER_EFFECT_PARTICLE_CAP


func get_language_preference_for_test() -> String:
	return language_preference


func get_active_locale_for_test() -> String:
	return _active_locale()


func get_oil_sheen_band_count_for_test() -> int:
	return OIL_SHEEN_BAND_COUNT


func get_oil_sheen_alpha_for_test(strength: float) -> float:
	return _oil_sheen_alpha(strength)


func get_oil_sheen_saturation_for_test(strength: float) -> float:
	return _oil_sheen_saturation(strength)


func calc_coin_reward_for_test() -> int:
	return _calc_coin_reward(_calc_stars())


func get_best_time_for_test(level: int) -> float:
	return _best_time_for_level(level)


func register_best_time_for_test() -> void:
	_register_best_time()


func is_new_record_for_test() -> bool:
	return is_new_record


func get_patch_index_by_kind_for_test(kind: String) -> int:
	for index in range(dirt_patches.size()):
		var patch := dirt_patches[index] as DirtPatch
		if patch.kind == kind:
			return index
	return -1


func get_patch_count_by_kind_for_test(kind: String) -> int:
	var count := 0
	for raw_patch in dirt_patches:
		if (raw_patch as DirtPatch).kind == kind:
			count += 1
	return count


func get_spawned_dirt_kinds_for_test() -> Array[String]:
	var kinds: Array[String] = []
	for raw_patch in dirt_patches:
		kinds.append((raw_patch as DirtPatch).kind)
	return kinds


func get_gold_spot_count_for_test() -> int:
	var count := 0
	for raw_patch in dirt_patches:
		if (raw_patch as DirtPatch).is_gold_spot:
			count += 1
	return count


func get_gold_spot_index_for_test() -> int:
	for index in range(dirt_patches.size()):
		if (dirt_patches[index] as DirtPatch).is_gold_spot:
			return index
	return -1


func get_gold_spot_rewards_granted_for_test() -> int:
	return _gold_spot_rewards_granted


func get_gold_spot_pop_amount_for_test() -> int:
	return _gold_spot_pop_amount


func set_patch_gold_spot_for_test(patch_index: int, enabled: bool) -> bool:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return false
	(dirt_patches[patch_index] as DirtPatch).is_gold_spot = enabled
	queue_redraw()
	return true


func spawn_patch_for_test(kind: String) -> int:
	var patch := DirtPatch.new(kind, _gameplay_point(Vector2(195.0, 520.0)), _gameplay_length(18.0), 100.0, 0.5)
	dirt_patches.append(patch)
	initial_dirt_total = max(1.0, initial_dirt_total + patch.max_health)
	return dirt_patches.size() - 1


func get_patch_state_for_test(patch_index: int) -> String:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return ""
	var patch := dirt_patches[patch_index] as DirtPatch
	return patch.state


func get_patch_health_for_test(patch_index: int) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	var patch := dirt_patches[patch_index] as DirtPatch
	return patch.health


func get_patch_drift_length_for_test(patch_index: int) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	var patch := dirt_patches[patch_index] as DirtPatch
	return patch.drift.length()


func get_patch_soap_for_test(patch_index: int) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	var patch := dirt_patches[patch_index] as DirtPatch
	return patch.soap


func apply_tool_to_patch_for_test(tool_id: String, patch_index: int, seconds: float) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	var old_tool := selected_tool
	selected_tool = tool_id
	var patch: DirtPatch = dirt_patches[patch_index]
	var steps: int = max(1, int(ceil(seconds * 30.0)))
	for step_index in range(steps):
		_apply_tool_to_patch(patch, 1.0 / 30.0, patch.position)
		_update_dirt_motion(1.0 / 30.0)
	selected_tool = old_tool
	_update_clean_progress()
	return patch.health


func get_patch_hint_time_for_test(patch_index: int) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	return (dirt_patches[patch_index] as DirtPatch).hint_time


func get_active_hint_tool_for_test() -> String:
	return _active_hint_tool()


func get_recommended_tool_for_test(patch_index: int) -> String:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return ""
	return _recommended_tool(dirt_patches[patch_index] as DirtPatch)


func get_wash_guide_entries_for_test() -> Array:
	return Coaching.wash_guide_entries()


func is_tool_misapplied_for_test(tool_id: String, patch_index: int) -> bool:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return false
	return _tool_misapplied(tool_id, dirt_patches[patch_index] as DirtPatch)


func simulate_patch_hint_for_test(tool_id: String, patch_index: int, seconds: float) -> String:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return ""
	var old_tool := selected_tool
	selected_tool = tool_id
	var patch: DirtPatch = dirt_patches[patch_index]
	var steps: int = max(1, int(ceil(seconds * 30.0)))
	for step_index in range(steps):
		_update_patch_hint(patch, 1.0 / 30.0)
		_update_dirt_motion(1.0 / 30.0)
	selected_tool = old_tool
	return patch.hint_tool if patch.hint_time > 0.0 else ""


# Rub the wrong tool in short bursts with idle gaps; resist should not pile up.
func simulate_choppy_hint_for_test(tool_id: String, patch_index: int, on_seconds: float, off_seconds: float, cycles: int) -> float:
	if patch_index < 0 or patch_index >= dirt_patches.size():
		return -1.0
	var old_tool := selected_tool
	selected_tool = tool_id
	var patch: DirtPatch = dirt_patches[patch_index]
	var on_steps: int = max(1, int(ceil(on_seconds * 30.0)))
	var off_steps: int = max(1, int(ceil(off_seconds * 30.0)))
	for cycle in range(cycles):
		for step_index in range(on_steps):
			_update_patch_hint(patch, 1.0 / 30.0)
			_update_dirt_motion(1.0 / 30.0)
		for step_index in range(off_steps):
			_update_dirt_motion(1.0 / 30.0)
	selected_tool = old_tool
	return patch.hint_time


func _update_canvas_transform() -> void:
	var available_size := size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = DESIGN_SIZE
	canvas_scale = min(available_size.x / DESIGN_SIZE.x, available_size.y / DESIGN_SIZE.y)
	canvas_origin = (available_size - DESIGN_SIZE * canvas_scale) * 0.5


func _safe_area_design_insets() -> Vector4:
	var debug_insets := OS.get_environment("FOAM_SAFE_AREA_DESIGN_INSETS")
	if debug_insets != "":
		var parts := debug_insets.split(",", false)
		if parts.size() == 4:
			return Vector4(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
	# Web/AIT: Godot cannot read the browser safe area, so the AIT wrapper publishes
	# it via window.__foamPartySafeArea (CSS px). Convert to design units here.
	if OS.has_feature("web"):
		return _web_safe_area_design_insets()
	_update_canvas_transform()
	if canvas_scale <= 0.0:
		return Vector4(0.0, 0.0, 0.0, 0.0)
	var window_size := Vector2(DisplayServer.window_get_size())
	var canvas_size := get_viewport_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0 or canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return Vector4(0.0, 0.0, 0.0, 0.0)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4(0.0, 0.0, 0.0, 0.0)
	var scale_x := canvas_size.x / window_size.x
	var scale_y := canvas_size.y / window_size.y
	var safe_canvas := Rect2(
		Vector2(float(safe.position.x) * scale_x, float(safe.position.y) * scale_y),
		Vector2(float(safe.size.x) * scale_x, float(safe.size.y) * scale_y)
	)
	var design_max := canvas_origin + DESIGN_SIZE * canvas_scale
	var inset_left := maxf(0.0, (safe_canvas.position.x - canvas_origin.x) / canvas_scale)
	var inset_top := maxf(0.0, (safe_canvas.position.y - canvas_origin.y) / canvas_scale)
	var inset_right := maxf(0.0, (design_max.x - (safe_canvas.position.x + safe_canvas.size.x)) / canvas_scale)
	var inset_bottom := maxf(0.0, (design_max.y - (safe_canvas.position.y + safe_canvas.size.y)) / canvas_scale)
	return Vector4(inset_left, inset_top, inset_right, inset_bottom)


# Read the AIT-published safe area (CSS px) and map it into design units. The
# wrapper mutates a single stable object, so caching the interface is safe; it is
# re-fetched until present in case Godot boots before the bridge is installed.
func _web_safe_area_design_insets() -> Vector4:
	if _web_safe_area == null:
		_web_safe_area = JavaScriptBridge.get_interface("__foamPartySafeArea")
	if _web_safe_area == null:
		return Vector4.ZERO
	var css_w := float(_web_safe_area.vw)
	var css_h := float(_web_safe_area.vh)
	if css_w <= 0.0 or css_h <= 0.0:
		return Vector4.ZERO
	# Match _update_canvas_transform: DESIGN_SIZE is min-fit and centered in the
	# viewport, so a CSS-px inset maps to design units after removing the letterbox
	# margin and dividing by the fit scale.
	var s := minf(css_w / DESIGN_SIZE.x, css_h / DESIGN_SIZE.y)
	if s <= 0.0:
		return Vector4.ZERO
	var margin_x := (css_w - DESIGN_SIZE.x * s) * 0.5
	var margin_y := (css_h - DESIGN_SIZE.y * s) * 0.5
	var inset_top := maxf(0.0, (float(_web_safe_area.top) - margin_y) / s)
	var inset_bottom := maxf(0.0, (float(_web_safe_area.bottom) - margin_y) / s)
	var inset_left := maxf(0.0, (float(_web_safe_area.left) - margin_x) / s)
	var inset_right := maxf(0.0, (float(_web_safe_area.right) - margin_x) / s)
	return Vector4(inset_left, inset_top, inset_right, inset_bottom)


func _hud_top_y() -> float:
	return maxf(HUD_TOP_Y, _safe_area_design_insets().y + HUD_SAFE_PADDING)


# Combo badge floats below the single compact summary row so it never overlaps
# the top HUD. Shared by the badge draw and its break-burst spawn.
func _combo_badge_center_y() -> float:
	return _hud_top_y() + 172.0


func _title_button_y() -> float:
	return maxf(TOP_BUTTON_Y, _safe_area_design_insets().y + TOP_BUTTON_SAFE_PADDING)


func _tool_button_y() -> float:
	var bottom_inset := _safe_area_design_insets().w
	if bottom_inset <= 0.0:
		return TOOL_BUTTON_Y
	return minf(TOOL_BUTTON_Y, DESIGN_SIZE.y - bottom_inset - TOOL_BUTTON_HEIGHT - TOOL_BUTTON_BOTTOM_PADDING)


func _toolbar_y() -> float:
	return minf(TOOLBAR_Y, _tool_button_y() - TOOLBAR_TOP_GAP)


func _to_design(screen_point: Vector2) -> Vector2:
	_update_canvas_transform()
	if canvas_scale <= 0.0:
		return screen_point
	return (screen_point - canvas_origin) / canvas_scale


func _set_design_draw_transform(offset: Vector2 = Vector2.ZERO) -> void:
	draw_set_transform(canvas_origin + offset * canvas_scale, 0.0, Vector2(canvas_scale, canvas_scale))


func _set_gameplay_draw_transform(offset: Vector2 = Vector2.ZERO) -> void:
	var gameplay_origin := GAMEPLAY_OFFSET + GAMEPLAY_PIVOT * (1.0 - GAMEPLAY_SCALE)
	draw_set_transform(canvas_origin + (gameplay_origin + offset) * canvas_scale, 0.0, Vector2(canvas_scale * GAMEPLAY_SCALE, canvas_scale * GAMEPLAY_SCALE))


func _gameplay_point(point: Vector2) -> Vector2:
	return GAMEPLAY_PIVOT + (point - GAMEPLAY_PIVOT) * GAMEPLAY_SCALE + GAMEPLAY_OFFSET


func _gameplay_length(value: float) -> float:
	return value * GAMEPLAY_SCALE


func _handle_key(keycode: Key) -> void:
	if game_state == STATE_TITLE:
		if keycode == KEY_SPACE or keycode == KEY_ENTER:
			start_game()
		return
	if show_tutorial:
		if keycode == KEY_SPACE or keycode == KEY_ENTER or keycode == KEY_ESCAPE:
			_dismiss_tutorial()
		return
	if _car_transition_blocks_gameplay():
		return
	if keycode == KEY_1:
		if selected_tool != TOOL_AIR:
			selected_tool = TOOL_AIR
			_play_ui_select()
	elif keycode == KEY_2:
		if selected_tool != TOOL_WATER:
			selected_tool = TOOL_WATER
			_play_ui_select()
	elif keycode == KEY_3:
		if selected_tool != TOOL_SOAP:
			selected_tool = TOOL_SOAP
			_play_ui_select()
	elif keycode == KEY_4:
		if selected_tool != TOOL_SPONGE:
			selected_tool = TOOL_SPONGE
			_play_ui_select()
	elif keycode == KEY_SPACE and completed:
		_advance_to_next_level()
		_play_ui_select()
	elif keycode == KEY_R and completed:
		reset_game(active_level_index, "retry")
		_begin_car_entry()
		_play_ui_select()


func _handle_tap(point: Vector2) -> bool:
	# Quit-confirm and pause are modal: they take taps first and swallow anything
	# outside their buttons so the game underneath never reacts.
	if show_quit_confirm:
		if _quit_yes_rect().has_point(point):
			_quit_app()
		elif _quit_no_rect().has_point(point):
			show_quit_confirm = false
			_play_ui_select()
			queue_redraw()
		return true

	if show_booster_panel:
		_handle_booster_panel_tap(point)
		return true

	if show_pause:
		if _pause_button_rect(0).has_point(point):
			show_pause = false
			_play_ui_select()
			queue_redraw()
		elif _pause_button_rect(1).has_point(point):
			show_pause = false
			reset_game(active_level_index, "pause_restart")
			_play_ui_select()
		elif _pause_button_rect(2).has_point(point):
			_toggle_sound()
			queue_redraw()
		elif _pause_language_option_rect("ko").has_point(point):
			_select_language("ko")
		elif _pause_language_option_rect("en").has_point(point):
			_select_language("en")
		elif _pause_button_rect(3).has_point(point):
			show_pause = false
			_tutorial_returns_to_pause = true
			_show_tutorial("pause_guide")
			_play_ui_select()
			queue_redraw()
		elif _pause_button_rect(4).has_point(point):
			_go_home()
		elif _pause_button_rect(5).has_point(point):
			show_pause = false
			show_quit_confirm = true
			_play_ui_select()
			queue_redraw()
		return true

	if show_tutorial:
		_handle_tutorial_tap(point)
		return true

	if game_state == STATE_TITLE:
		if show_upgrade_panel:
			_handle_upgrade_panel_tap(point)
			return true
		if show_skin_panel:
			_handle_skin_panel_tap(point)
			return true
		if show_stage_panel:
			_handle_stage_panel_tap(point)
			return true
		if show_achievement_panel:
			_handle_achievement_panel_tap(point)
			return true
		if _get_start_rect().has_point(point):
			_emit_analytics(FtueEvents.play_tap(level_index))
			start_game()
			_play_ui_select()
		elif _get_upgrade_btn_rect().has_point(point):
			show_upgrade_panel = true
			queue_redraw()
			_play_ui_select()
		elif _get_skin_btn_rect().has_point(point):
			show_skin_panel = true
			queue_redraw()
			_play_ui_select()
		elif _get_stage_btn_rect().has_point(point):
			_stage_page = 0
			show_stage_panel = true
			queue_redraw()
			_play_ui_select()
		elif _get_achievement_btn_rect().has_point(point):
			show_achievement_panel = true
			queue_redraw()
			_play_ui_select()
		elif _get_title_sound_rect().has_point(point):
			_toggle_sound()
		elif _get_title_help_rect().has_point(point):
			_show_tutorial("title_help")
			_play_ui_select()
		return true

	if completed and _car_transition_phase != CAR_TRANSITION_EXITING and _double_offer_shown and not _double_claimed and ads != null and ads.is_rewarded_ready("level_reward_2x") and _get_double_rect().has_point(point):
		_play_ui_select()
		_try_double_coins()
		return true

	if completed and _car_transition_phase != CAR_TRANSITION_EXITING and _get_retry_rect().has_point(point):
		_maybe_show_game_over_interstitial()
		reset_game(active_level_index, "retry")
		_begin_car_entry()
		_play_ui_select()
		return true

	if completed and _car_transition_phase != CAR_TRANSITION_EXITING and _get_next_rect().has_point(point):
		_maybe_show_game_over_interstitial()
		_advance_to_next_level()
		_play_ui_select()
		return true

	if not completed and not _car_transition_blocks_gameplay() and _get_pause_entry_rect().has_point(point):
		show_pause = true
		is_washing = false
		_stop_tool_loop()
		_play_ui_select()
		queue_redraw()
		return true

	if _car_transition_blocks_gameplay():
		return true

	if not completed and _get_booster_rect().has_point(point):
		show_booster_panel = true
		is_washing = false
		_stop_tool_loop()
		_play_ui_select()
		queue_redraw()
		return true

	for index in range(tool_ids.size()):
		if _get_tool_rect(index).has_point(point):
			selected_tool = tool_ids[index]
			_tool_select_time = float(Time.get_ticks_msec()) / 1000.0
			_play_ui_select()
			is_washing = false
			return true

	return false


func _handle_booster_panel_tap(point: Vector2) -> void:
	var panel := _booster_panel_rect()
	if _booster_close_rect(panel).has_point(point):
		show_booster_panel = false
		_play_ui_select()
		queue_redraw()
		return

	if _booster_card_rect(panel, 0).has_point(point):
		if _free_ad_bomb_available():
			show_booster_panel = false
			ads.show_rewarded("foam_bomb_free", _on_foam_bomb_reward)
		elif apply_foam_bomb():
			show_booster_panel = false
			_bomb_press_time = float(Time.get_ticks_msec()) / 1000.0
		else:
			audio.play_bomb_deny()
		queue_redraw()
		return

	if _booster_card_rect(panel, 1).has_point(point):
		if activate_water_boost():
			show_booster_panel = false
			_bomb_press_time = float(Time.get_ticks_msec()) / 1000.0
			_play_ui_select()
		else:
			audio.play_bomb_deny()
		queue_redraw()


func _dismiss_tutorial() -> void:
	if not show_tutorial:
		return
	show_tutorial = false
	_emit_analytics(FtueEvents.tutorial_complete(
		FtueEvents.TUTORIAL_STEP_OVERVIEW,
		_tutorial_event_source if not _tutorial_event_source.is_empty() else "unknown",
	))
	_tutorial_event_source = ""
	if _tutorial_returns_to_pause and game_state == STATE_PLAYING and not completed:
		show_pause = true
	_tutorial_returns_to_pause = false
	_play_ui_select()
	if not tutorial_seen:
		tutorial_seen = true
		_save_progress()


func _handle_tutorial_tap(point: Vector2) -> void:
	if _tutorial_close_rect().has_point(point) or _tutorial_done_rect().has_point(point):
		_dismiss_tutorial()
		return
	for tab in [TUTORIAL_TAB_TOOLS, TUTORIAL_TAB_DIRT]:
		if _tutorial_tab_rect(tab).has_point(point):
			_tutorial_tab = tab
			_play_ui_select()
			queue_redraw()
			return


func _show_tutorial(source: String) -> void:
	show_tutorial = true
	_tutorial_tab = TUTORIAL_TAB_TOOLS
	_tutorial_event_source = source
	_emit_analytics(FtueEvents.tutorial_step_view(FtueEvents.TUTORIAL_STEP_OVERVIEW, source))


func _toggle_sound() -> void:
	# ON→OFF: 뮤트 적용 전에 클릭음을 재생해 소리가 끊기지 않게 한다.
	# OFF→ON: 언뮤트 후 클릭음을 재생한다.
	if sound_enabled:
		_play_ui_select()
	sound_enabled = not sound_enabled
	_apply_sound_setting()
	if sound_enabled:
		_play_ui_select()
	_save_progress()


func _select_language(locale: String) -> void:
	var preference := I18n.normalize_preference(locale)
	if preference == "":
		return
	_play_ui_select()
	language_preference = preference
	_apply_language_preference()
	_save_progress()
	queue_redraw()


func activate_water_boost() -> bool:
	if completed or _water_boost_remaining > 0.0 or coins < WATER_BOOST_COST:
		return false
	coins -= WATER_BOOST_COST
	_water_boost_remaining = WATER_BOOST_DURATION
	selected_tool = TOOL_WATER
	is_washing = false
	_stop_tool_loop()
	_save_progress()
	queue_redraw()
	return true


func _update_water_boost(delta: float) -> void:
	if _water_boost_remaining <= 0.0:
		return
	_water_boost_remaining = maxf(0.0, _water_boost_remaining - maxf(delta, 0.0))


func _water_boost_active() -> bool:
	return _water_boost_remaining > 0.0


func apply_foam_bomb(free := false) -> bool:
	# free=true is granted by a rewarded ad (no coin cost). Otherwise coins pay.
	if completed or (not free and coins < BOMB_COST):
		return false
	var applied := false
	var patch_bubbles: Array[WashParticle] = []
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		if _is_patch_removed(patch) or patch.state == STATE_FLYING:
			continue
		applied = true
		patch.soap = 1.0
		patch.wetness = max(patch.wetness, 0.3)
		patch.looseness = max(patch.looseness, 0.7)
		# D: instant partial clean — knock 25% off each patch's remaining health so
		# the bomb is a real time-saver toward the star-time threshold, not just a
		# soap primer. Clean progress/removal is driven by patch.health.
		patch.health = max(0.0, patch.health * 0.75)
		if patch.kind == "oil" or patch.kind == "bug":
			patch.state = STATE_LOOSENED
		elif patch.kind == "mud":
			patch.state = STATE_SOAPED
		elif patch.kind == "poop":
			patch.state = STATE_LOOSENED
		elif patch.kind == "road_grime":
			patch.state = STATE_LOOSENED
		elif patch.kind == "sap":
			patch.state = STATE_LOOSENED
		var center := _patch_center(patch)
		for bubble_index in range(3):
			var offset := Vector2(rng.randf_range(-patch.radius, patch.radius), rng.randf_range(-patch.radius, patch.radius))
			patch_bubbles.append(WashParticle.new(center + offset, Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-40.0, -16.0)), rng.randf_range(0.6, 1.1), rng.randf_range(4.0, 9.0), Color.from_hsv(rng.randf(), 0.12, 1.0, 0.85), STYLE_BUBBLE))
	if not applied:
		return false
	_append_foam_effect_batch(patch_bubbles)
	body_foam_coverage = 1.0
	body_foam_runoff = 0.0
	_spawn_foam_bomb_burst()
	if not free:
		coins -= BOMB_COST
	audio.play_bomb()
	_emit_analytics(ContentEvents.foam_bomb_use(active_level_index, free, BOMB_COST))
	_save_progress()
	return true


func _spawn_foam_bomb_burst() -> void:
	_foam_bomb_burst_count += 1
	var shapes: Dictionary = car_shapes[car_type]
	var silhouette: PackedVector2Array = shapes["silhouette"]
	var spots: Array = _body_foam_spots(silhouette)
	var burst: Array[WashParticle] = []
	var car_center := _gameplay_point(Vector2(195.0, 520.0))
	for index in range(mini(FOAM_BOMB_BURST_PARTICLE_COUNT, spots.size())):
		var local_center: Vector2 = spots[index]["center"]
		var center := _gameplay_point(local_center)
		var direction := (center - car_center).normalized()
		if direction.length() < 0.1:
			direction = Vector2.UP
		var tint := Color.from_hsv(fmod(float(index) * 0.077, 1.0), 0.10, 1.0, 0.92)
		burst.append(WashParticle.new(
			center,
			direction * rng.randf_range(36.0, 92.0) + Vector2(0.0, rng.randf_range(-54.0, -18.0)),
			rng.randf_range(0.65, 1.05),
			_gameplay_length(float(spots[index]["radius"]) * rng.randf_range(0.62, 1.0)),
			tint,
			STYLE_FOAM if index % 3 != 0 else STYLE_BUBBLE
		))
	_append_foam_effect_batch(burst)
	# Two bounded shock rings make the one-time action read across the whole car;
	# the persistent silhouette layer carries the state after the rings fade.
	_append_particle(WashParticle.new(car_center, Vector2.ZERO, 0.42, _gameplay_length(44.0), Color(0.92, 0.99, 1.0, 0.74), STYLE_RING))
	_append_particle(WashParticle.new(car_center, Vector2.ZERO, 0.58, _gameplay_length(78.0), Color(1.0, 0.93, 0.72, 0.52), STYLE_RING))


# A rewarded free bomb is offered while inventory is ready and the per-level cap
# is not yet reached. Decoupled from the coin balance so the ad actually surfaces.
func _free_ad_bomb_available() -> bool:
	return (
		not completed
		and _free_ad_bombs_used < GameConfig.FREE_AD_BOMB_PER_LEVEL
		and ads != null
		and ads.is_rewarded_ready("foam_bomb_free")
	)


# Rewarded-ad reward callback for the free foam bomb (AdService → here). The
# reward was genuinely earned, so grant the free bomb. If there is nothing left
# to clean (rare), no-op silently — never a rejection sound after a watched ad.
func _on_foam_bomb_reward() -> void:
	# Count the grant against the per-level cap even if the board is already clean,
	# so a watched ad always consumes one slot (no unbounded re-watching).
	_free_ad_bombs_used += 1
	if apply_foam_bomb(true):
		_bomb_press_time = float(Time.get_ticks_msec()) / 1000.0
	queue_redraw()


# B: tapping the completion-panel "double coins" button plays a rewarded ad. Only
# fires when inventory is actually ready (AdService's _rewarded_in_flight guards
# against concurrent shows); a dismissed ad simply leaves the offer re-tappable.
func _try_double_coins() -> void:
	if not completed or _double_claimed or not _double_offer_shown:
		return
	if ads == null or not ads.is_rewarded_ready("level_reward_2x"):
		return
	ads.show_rewarded("level_reward_2x", _on_double_coins_reward)


# Rewarded-ad callback for level-end double coins. Fires only when earned (the ad
# was watched to completion), so grant a bonus equal to the base level reward
# (total = 2x). A dismissed ad never calls this, leaving the offer available.
func _on_double_coins_reward() -> void:
	if _double_claimed:
		return
	_double_claimed = true
	var bonus := coin_reward
	coins += bonus
	_emit_analytics(ContentEvents.reward_double_coins(active_level_index, bonus))
	audio.play_coin_bonus()
	_save_progress()
	queue_redraw()


# Show a game-over interstitial roughly every INTERSTITIAL_EVERY level transitions.
# The counter only advances up to the cap (never overshoots, never goes negative);
# at the cap it attempts a show and resets to 0 only when a show actually started,
# so a not-ready/failed ad simply retries on the next transition.
func _maybe_show_game_over_interstitial() -> void:
	if ads == null:
		return
	if _level_transitions < INTERSTITIAL_EVERY:
		_level_transitions += 1
	if _level_transitions >= INTERSTITIAL_EVERY and ads.show_interstitial("game_over"):
		_level_transitions = 0


func _calc_coin_reward(stars: int) -> int:
	return Economy.calc_coin_reward(stars, best_combo)


func _calc_level_milestone_bonus(level: int) -> int:
	return Economy.calc_level_milestone_bonus(level)


func _set_car_palette() -> void:
	car_type = GameConfig.car_type_for_level(active_level_index)
	var hue := fmod(0.10 + float(active_level_index - 1) * 0.18, 1.0)
	if car_type == "sports":
		car_color = Color.from_hsv(hue, 0.85, 1.0)
	elif car_type == "truck":
		car_color = Color.from_hsv(hue, 0.42, 0.9)
	elif car_type == "van":
		car_color = Color.from_hsv(hue, 0.5, 0.96)
	elif car_type == "offroad":
		car_color = Color.from_hsv(hue, 0.72, 0.84)
	else:
		car_color = Color.from_hsv(hue, 0.62, 1.0)
	car_color = CarPaintCatalog.color_for(selected_car_paint, car_color)


func _spawn_dirt() -> void:
	dirt_patches.clear()
	_wheel_dirt_indices.clear()
	_hint_patch = null
	var spawn_seed := 42690 + int(active_level_index) * 97
	rng.seed = spawn_seed

	var pool: Array[Vector2] = _dirt_spawn_positions()
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap_value: Vector2 = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = swap_value

	# Per-car weighted dirt catalogs and their level gates live in pure core.
	var type_pool: Array[String] = DirtSpawnPlan.type_pool_for_level(car_type, active_level_index)
	var radius_min := 13.0
	var radius_max := 24.0
	var health_base_min := 70.0
	var health_base_max := 120.0
	match car_type:
		"sports":
			radius_min = 11.0
			radius_max = 20.0
			health_base_min = 80.0
			health_base_max = 135.0
		"truck":
			radius_min = 15.0
			radius_max = 28.0
			health_base_min = 85.0
			health_base_max = 145.0
		"van":
			radius_min = 13.0
			radius_max = 24.0
			health_base_min = 78.0
			health_base_max = 130.0
		"offroad":
			radius_min = 16.0
			radius_max = 29.0
			health_base_min = 90.0
			health_base_max = 150.0

	var spawn_count: int = DirtSpawnPlan.spawn_count(active_level_index, pool.size())
	var body_spawn_count := maxi(0, spawn_count - _wheel_specs().size())
	var gold_spot_index := GoldSpot.spawn_index(active_level_index, body_spawn_count, spawn_seed)
	var density_radius_scale: float = DirtSpawnPlan.radius_scale_for_count(spawn_count)
	var health_scale: float = DirtSpawnPlan.health_scale_for_level(active_level_index)
	for index in range(body_spawn_count):
		var kind: String = type_pool[index % type_pool.size()]
		var base_position: Vector2 = _gameplay_point(pool[index])
		var radius := _gameplay_length(rng.randf_range(radius_min, radius_max) * density_radius_scale)
		var health: float = DirtSpawnPlan.scaled_health(
			rng.randf_range(health_base_min, health_base_max),
			kind,
			active_level_index
		)
		var patch := DirtPatch.new(kind, base_position, radius, health, rng.randf_range(0.0, 10.0), index == gold_spot_index)
		dirt_patches.append(patch)
	_spawn_wheel_dirt(health_scale, spawn_seed)

	initial_dirt_total = 0.0
	for patch in dirt_patches:
		initial_dirt_total += (patch as DirtPatch).max_health
	initial_dirt_total = max(1.0, initial_dirt_total)


func _spawn_wheel_dirt(health_scale: float, spawn_seed: int) -> void:
	var wheels := _wheel_specs()
	for wheel_index in range(wheels.size()):
		var wheel: Dictionary = wheels[wheel_index]
		var wheel_radius := float(wheel["radius"])
		var patch := DirtPatch.new(
			"mud",
			_gameplay_point(wheel["center"]),
			_gameplay_length(wheel_radius * 0.58),
			(88.0 + wheel_radius * 0.3) * health_scale,
			float(spawn_seed % 997) * 0.01 + float(wheel_index) * 1.37
		)
		_wheel_dirt_indices.append(dirt_patches.size())
		dirt_patches.append(patch)


func _dirt_spawn_positions() -> Array[Vector2]:
	var shapes: Dictionary = car_shapes[car_type]
	var silhouette: PackedVector2Array = shapes["silhouette"]
	var bounds := _polygon_bounds(silhouette)
	var positions: Array[Vector2] = []
	for uv in DirtSpawnPlan.normalized_candidates():
		var candidate := bounds.position + Vector2(bounds.size.x * uv.x, bounds.size.y * uv.y)
		if not _spawn_candidate_fits_silhouette(candidate, silhouette):
			continue
		var separated := true
		for accepted in positions:
			if candidate.distance_to(accepted) < DirtSpawnPlan.MIN_CENTER_DISTANCE:
				separated = false
				break
		if separated:
			positions.append(candidate)
	return positions


func _spawn_candidate_fits_silhouette(candidate: Vector2, silhouette: PackedVector2Array) -> bool:
	if not Geometry2D.is_point_in_polygon(candidate, silhouette):
		return false
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if not Geometry2D.is_point_in_polygon(candidate + direction * DirtSpawnPlan.SILHOUETTE_EDGE_MARGIN, silhouette):
			return false
	return true


func _apply_tool_at(point: Vector2, delta: float) -> void:
	var tool_radius := _tool_radius(selected_tool)
	var applied := false
	var focus_patch: DirtPatch = null
	var focus_distance := INF
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		if _is_patch_removed(patch) or patch.state == STATE_FLYING:
			continue
		var center_distance := point.distance_to(_patch_center(patch))
		if center_distance <= tool_radius + patch.radius:
			_apply_tool_to_patch(patch, delta, point)
			applied = true
			if center_distance < focus_distance:
				focus_distance = center_distance
				focus_patch = patch

	# Coach only the patch directly under the tool so at most one hint shows.
	if focus_patch != null:
		_update_patch_hint(focus_patch, delta)

	if applied:
		_update_body_foam_from_tool(delta)
		_spawn_tool_particles(point, delta)


func _update_body_foam_from_tool(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if selected_tool == TOOL_SOAP:
		body_foam_coverage = minf(1.0, body_foam_coverage + safe_delta * BODY_FOAM_SOAP_RATE)
	elif selected_tool == TOOL_WATER and body_foam_coverage > 0.0:
		var removed := minf(body_foam_coverage, safe_delta * BODY_FOAM_WATER_RATE)
		body_foam_coverage = maxf(0.0, body_foam_coverage - removed)
		# A rinse creates a short-lived downward read even after the scalar coverage
		# has changed, so water feels like it carries the foam off the body.
		body_foam_runoff = maxf(body_foam_runoff, clampf(0.24 + removed * 2.8, 0.0, 1.0))


# Decides whether the current tool is the wrong choice for this patch right now.
func _tool_misapplied(tool_id: String, patch: DirtPatch) -> bool:
	return Coaching.tool_misapplied(tool_id, patch)


# The tool currently being coached on screen, or "" when no hint is active.
func _active_hint_tool() -> String:
	var patch_active := _hint_patch != null and is_instance_valid(_hint_patch) and not _is_patch_removed(_hint_patch)
	return Coaching.active_hint_tool(_hint_patch, patch_active)


# The tool the player should reach for next on this patch.
func _recommended_tool(patch: DirtPatch) -> String:
	return Coaching.recommended_tool(patch)


func _update_patch_hint(patch: DirtPatch, delta: float) -> void:
	if _is_patch_removed(patch) or patch.state == STATE_FLYING:
		return
	# Keep coaching even on a stubborn last sliver; only skip the truly-gone.
	if patch.health / max(1.0, patch.max_health) < 0.05:
		return
	var wrong_tool := _tool_misapplied(selected_tool, patch)
	if wrong_tool:
		# +2*delta here, -delta decay in _update_dirt_motion -> net +delta only
		# while actively rubbing, so brief stray touches never accumulate.
		patch.resist_time += delta * 2.0
		var time_now := float(Time.get_ticks_msec()) / 1000.0
		if time_now - _tool_misapplied_time > 0.6:
			_tool_misapplied_time = time_now
			_tool_misapplied_tool_id = selected_tool
			patch.shake_x = 6.0
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(30)
		if patch.resist_time >= 0.3:
			# Keep a single active coach so overlapping patches stay readable.
			if _hint_patch != null and _hint_patch != patch:
				_hint_patch.hint_time = 0.0
			_hint_patch = patch
			patch.hint_tool = _recommended_tool(patch)
			var hint_was_inactive := patch.hint_time <= 0.0
			patch.hint_time = max(patch.hint_time, 1.4)
			if hint_was_inactive:
				if not patch.mistake_recorded:
					patch.mistake_recorded = true
					level_mistakes += 1
				audio.play_hint()
	else:
		patch.resist_time = 0.0
		patch.hint_time = 0.0
		if _hint_patch == patch:
			_hint_patch = null


func _apply_tool_to_patch(patch: DirtPatch, delta: float, source_point: Vector2) -> void:
	if _is_patch_removed(patch):
		return

	var distance: float = source_point.distance_to(_patch_center(patch))
	var radius: float = _tool_radius(selected_tool) + patch.radius
	var proximity: float = clamp(1.0 - distance / max(1.0, radius), 0.15, 1.0)

	if selected_tool == TOOL_AIR:
		_apply_air_to_patch(patch, delta, source_point, proximity)
	elif selected_tool == TOOL_WATER:
		_apply_water_to_patch(patch, delta, proximity)
	elif selected_tool == TOOL_SOAP:
		_apply_soap_to_patch(patch, delta, proximity)
	elif selected_tool == TOOL_SPONGE:
		_apply_sponge_to_patch(patch, delta, source_point, proximity)

	patch.health = max(0.0, patch.health)
	if patch.health <= 0.0:
		_mark_patch_removed(patch)


func _apply_air_to_patch(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float) -> void:
	# Draw the lift impulse here (only for light dirt) so the RNG sequence is
	# identical to the pre-refactor inline call; the pure rule consumes the value.
	var lift_y := 0.0
	if _is_light_dirt(patch.kind):
		lift_y = rng.randf_range(10.0, 42.0)
	WashRules.apply_air(patch, delta, source_point, proximity, lift_y)


func _apply_water_to_patch(patch: DirtPatch, delta: float, proximity: float) -> void:
	WashRules.apply_water(patch, delta, proximity, _tool_power_multiplier(TOOL_WATER))


func _apply_soap_to_patch(patch: DirtPatch, delta: float, proximity: float) -> void:
	WashRules.apply_soap(patch, delta, proximity, _upgrade_mult("soap"))


func _apply_sponge_to_patch(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float) -> void:
	WashRules.apply_sponge(patch, delta, source_point, proximity, _upgrade_mult("sponge"))


func _update_dirt_motion(delta: float) -> void:
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		if _is_patch_removed(patch):
			continue

		patch.hint_time = max(0.0, patch.hint_time - delta)
		# Decay resist for every patch; the one under the tool re-adds 2*delta.
		patch.resist_time = max(0.0, patch.resist_time - delta)

		if patch.state == STATE_FLYING:
			patch.drift += patch.velocity * delta
			patch.velocity *= 0.965
			patch.health -= patch.max_health * delta * 0.55
			if _is_patch_outside_wash_area(patch):
				_mark_patch_removed(patch)
		elif patch.state == STATE_RUNOFF:
			patch.runoff = min(1.0, patch.runoff + delta * 0.55)
			patch.drift.y += delta * (24.0 + 52.0 * patch.wetness)
			patch.drift.x += sin(patch.seed_offset + patch.runoff * TAU) * delta * 9.0
			patch.health -= _runoff_cleanup_rate(patch) * delta * CLEAN_DAMAGE_RATE
			patch.soap = max(0.0, patch.soap - delta * 0.3)
			if _patch_center(patch).y > 735.0:
				_mark_patch_removed(patch)
		else:
			patch.drift = patch.drift.move_toward(Vector2.ZERO, delta * 10.0)
			patch.velocity *= 0.9

		if patch.shake_x != 0.0:
			patch.shake_x = -patch.shake_x * exp(-delta * 30.0)
			if absf(patch.shake_x) < 0.2:
				patch.shake_x = 0.0

		patch.wetness = max(0.0, patch.wetness - delta * 0.08)
		if patch.state != STATE_SOAPED and patch.state != STATE_LOOSENED:
			patch.soap = max(0.0, patch.soap - delta * 0.025)

		if patch.health <= 0.0:
			_mark_patch_removed(patch)


func _runoff_cleanup_rate(patch: DirtPatch) -> float:
	return WashRules.runoff_cleanup_rate(patch)


func _patch_center(patch: DirtPatch) -> Vector2:
	return WashRules.patch_center(patch)


func _is_light_dirt(kind: String) -> bool:
	return Coaching.is_light_dirt(kind)


func _push_direction(patch: DirtPatch, source_point: Vector2) -> Vector2:
	return WashRules.push_direction(patch, source_point)


func _is_patch_removed(patch: DirtPatch) -> bool:
	return WashRules.is_patch_removed(patch)


func _mark_patch_removed(patch: DirtPatch) -> void:
	if patch.state == STATE_REMOVED:
		return
	var burst_center := _patch_center(patch)
	var burst_radius := patch.radius
	patch.state = STATE_REMOVED
	patch.health = 0.0
	patch.soap = 0.0
	patch.wetness = 0.0
	patch.looseness = 1.0
	patch.hint_time = 0.0
	patch.resist_time = 0.0
	if _hint_patch == patch:
		_hint_patch = null
	if not completed:
		var gold_reward := GoldSpot.reward_for_removal(patch.is_gold_spot, _gold_spot_rewards_granted)
		if gold_reward > 0:
			coins += gold_reward
			_gold_spot_rewards_granted += 1
			_gold_spot_pop_time = float(Time.get_ticks_msec()) / 1000.0
			_gold_spot_pop_position = burst_center
			_gold_spot_pop_amount = gold_reward
			_spawn_gold_spot_burst(burst_center, burst_radius)
			audio.play_coin_bonus()
		_register_combo_removal()
		if combo_count == _star3_combo_requirement() and not _star3_combo_unlocked:
			_star3_combo_unlocked = true
			audio.play_star3_gate()
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(50)
		if COMBO_BONUS_AMOUNTS.has(combo_count):
			var _bonus: int = COMBO_BONUS_AMOUNTS[combo_count]
			coins += _bonus
			_combo_bonus_amount = _bonus
			_combo_bonus_time = float(Time.get_ticks_msec()) / 1000.0
			audio.play_coin_bonus()
		combo_pop_time = float(Time.get_ticks_msec()) / 1000.0
		_trigger_combo_milestone_flash(combo_count)
		var _cheer := ""
		if combo_count == _star3_combo_requirement():
			_cheer = tr("CHEER_NICE")
		elif combo_count == 6:
			_cheer = tr("CHEER_KEEP")
		elif combo_count == 8:
			_cheer = tr("CHEER_SPOTLESS")
		elif combo_count >= 10 and combo_count % 5 == 0:
			_cheer = tr("CHEER_WOW")
		if _cheer != "":
			_customer_cheer_text = _cheer
			_customer_cheer_time = combo_pop_time
		if combo_count % 5 == 0 and combo_count != _last_milestone_haptic_combo:
			_last_milestone_haptic_combo = combo_count
			audio.play_combo_milestone()
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(38)
		if patch.kind == daily_mission_type:
			_advance_daily_mission()
		_record_achievement_increment(AchievementProgress.COUNTER_DIRT)
		if patch.kind == "leaf":
			_record_achievement_increment(AchievementProgress.COUNTER_LEAF)
	_spawn_removal_burst(burst_center, burst_radius)
	if selected_tool == TOOL_WATER:
		_spawn_water_removal_splash(burst_center, burst_radius)
	if not completed:
		_play_removal_sound()
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(28)


func _register_combo_removal() -> void:
	combo_protection_available = ComboProtection.protection_after_removal(combo_count, combo_protection_available)
	combo_count += 1
	combo_timer = COMBO_WINDOW
	combo_grace_active = false
	best_combo = max(best_combo, combo_count)
	_record_achievement_max(AchievementProgress.COUNTER_COMBO, best_combo)
	if daily_mission_type == "combo" and combo_count == daily_mission_requirement:
		_advance_daily_mission()


func _spawn_removal_burst(center: Vector2, radius: float) -> void:
	# Burst escalates with the active combo so each successive removal feels
	# bigger than the last: more particles, faster spread, and a colour shift
	# from clean white/blue toward a celebratory gold once the combo runs hot.
	var combo: int = max(combo_count, 1)
	var combo_requirement := _star3_combo_requirement()
	var intensity: float = clampf(float(combo - 1) / 8.0, 0.0, 1.0)
	var hot: bool = combo >= combo_requirement
	var cool_tint := Color(1.0, 1.0, 1.0, 0.95)
	var hot_tint := Color(1.0, 0.84, 0.36, 0.98)
	var sparkle_tint := cool_tint.lerp(hot_tint, intensity)

	var sparkle_count: int = 4 + min(combo, 10)
	for index in range(sparkle_count):
		var angle := rng.randf_range(0.0, TAU)
		var offset := Vector2.from_angle(angle) * radius * rng.randf_range(0.2, 0.9)
		var lift := rng.randf_range(-26.0, -8.0) * (1.0 + intensity * 0.6)
		var sparkle := WashParticle.new(center + offset, Vector2(0.0, lift), rng.randf_range(0.4, 0.75) + intensity * 0.2, rng.randf_range(3.5, 6.5) + intensity * 2.0, sparkle_tint, STYLE_SPARKLE)
		_append_particle(sparkle)

	var bubble_count: int = 5 + min(int(round(float(combo) * 0.7)), 8)
	for index in range(bubble_count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(40.0, 120.0) * (1.0 + intensity * 0.5)
		var bubble := WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.3, 0.6), rng.randf_range(2.5, 5.5), Color(0.85, 0.96, 1.0, 0.85), STYLE_BUBBLE)
		_append_particle(bubble)

	# Expanding shockwave ring grows with the combo to punctuate the pop.
	_append_particle(WashParticle.new(center, Vector2.ZERO, 0.3 + intensity * 0.2, 4.0 + radius * (0.5 + intensity * 0.6), sparkle_tint, STYLE_RING))

	# Hot combos throw celebratory gold confetti so a streak reads as a payoff.
	if hot:
		var confetti_count: int = min(combo - combo_requirement + 2, 7)
		for index in range(confetti_count):
			var angle := rng.randf_range(-PI, 0.0)
			var speed := rng.randf_range(120.0, 230.0)
			var color := Color.from_hsv(rng.randf_range(0.09, 0.14), 0.75, 1.0, 0.95)
			_append_particle(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.6, 1.1), rng.randf_range(3.5, 6.5), color, STYLE_CONFETTI))

	# Outward sparkle burst: a small ring of fast sparks gives the scrubbing loop
	# a satisfying "pop" at the exact moment a patch disappears.
	var _tc = tool_colors.get(selected_tool)
	var base_tool_color: Color = _tc if _tc is Color else Color(0.95, 0.95, 1.0, 0.85)
	var pop_color := base_tool_color.lightened(0.3)
	pop_color.a = 0.9
	var pop_count: int = rng.randi_range(6, 8)
	for index in range(pop_count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(60.0, 130.0)
		_append_particle(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.35, 0.55), rng.randf_range(3.5, 6.0), pop_color, STYLE_SPARKLE))


func _spawn_gold_spot_burst(center: Vector2, radius: float) -> void:
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var speed := rng.randf_range(85.0, 155.0)
		_append_particle(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.45, 0.75), rng.randf_range(4.0, 7.0), Color("#ffd84a"), STYLE_SPARKLE))
	_append_particle(WashParticle.new(center, Vector2.ZERO, 0.42, radius + 8.0, Color(1.0, 0.78, 0.12, 0.9), STYLE_RING))


func _spawn_water_removal_splash(center: Vector2, radius: float) -> void:
	# A water-caused removal gets its own impact splash. Particle count and spread
	# scale with the active combo, while the water-only cap prevents accumulation.
	var intensity := clampf(float(max(combo_count, 1) - 1) / 8.0, 0.0, 1.0)
	var splash_count := 5 + int(round(8.0 * intensity))
	var mist_count := 1 + int(round(2.0 * intensity))
	var batch: Array[WashParticle] = []
	var fan_direction := Vector2(-0.18, -1.0).normalized()
	batch.append(WashParticle.new(
		center,
		fan_direction * 18.0,
		0.38 + intensity * 0.14,
		maxf(12.0, radius * (0.72 + intensity * 0.22)),
		Color(0.7, 0.92, 1.0, 0.82),
		STYLE_SPRAY_FAN
	))
	for index in range(splash_count):
		var angle := rng.randf_range(-PI + 0.12, -0.12)
		var speed := rng.randf_range(125.0, 220.0) * (1.0 + intensity * 0.42)
		var tint := Color(0.54, 0.86, 1.0, 0.9).lerp(Color(0.88, 0.97, 1.0, 0.98), intensity)
		batch.append(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.34, 0.62), rng.randf_range(3.0, 5.5) + intensity * 1.5, tint, STYLE_SPLASH))
	for index in range(mist_count):
		var mist_offset := Vector2(rng.randf_range(-radius * 0.8, radius * 0.8), rng.randf_range(-radius * 0.45, 2.0))
		var mist_velocity := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-34.0, -14.0))
		batch.append(WashParticle.new(center + mist_offset, mist_velocity, rng.randf_range(0.48, 0.76) + intensity * 0.12, rng.randf_range(9.0, 15.0) + intensity * 3.0, Color(0.9, 0.98, 1.0, 0.3), STYLE_MIST))
	_append_water_effect_batch(batch)


func _is_patch_outside_wash_area(patch: DirtPatch) -> bool:
	var center := _patch_center(patch)
	return center.x < -48.0 or center.x > DESIGN_SIZE.x + 48.0 or center.y < WASH_AREA_TOP or center.y > WASH_AREA_BOTTOM


# True when a design-space point is inside the washable car/dirt band.
func _point_in_wash_area(p: Vector2) -> bool:
	return p != Vector2.ZERO and p.y >= WASH_AREA_TOP and p.y <= WASH_AREA_BOTTOM


func _update_wash_trail(delta: float) -> void:
	# Age every existing point by the frame delta so the streak fades on a fixed
	# clock, independent of frame rate.
	for index in range(wash_trail.size() - 1, -1, -1):
		var point := wash_trail[index] as Dictionary
		point["age"] = float(point["age"]) + delta
		if float(point["age"]) > TRAIL_LIFETIME:
			wash_trail.remove_at(index)

	var active := is_washing and not completed and game_state == STATE_PLAYING and not show_tutorial and not _car_transition_blocks_gameplay()
	var in_play_area := _point_in_wash_area(pointer_position)
	if active and in_play_area:
		if _trail_has_last:
			var moved := pointer_position.distance_to(_trail_last_pos)
			var inst_speed := moved / maxf(delta, 0.0001)
			wash_speed = lerpf(wash_speed, inst_speed, 0.4)
			if moved >= TRAIL_MIN_GAP:
				wash_trail.append({"pos": pointer_position, "age": 0.0})
				_trail_last_pos = pointer_position
		else:
			_trail_has_last = true
			_trail_last_pos = pointer_position
			wash_trail.append({"pos": pointer_position, "age": 0.0})
	else:
		wash_speed = lerpf(wash_speed, 0.0, 0.25)
		_trail_has_last = false

	while wash_trail.size() > TRAIL_MAX_POINTS:
		wash_trail.remove_at(0)


func _draw_wash_trail() -> void:
	# Hide the streak immediately in non-play moments (completion, tutorial popup)
	# rather than letting it fade behind the overlay.
	if completed or show_tutorial or game_state != STATE_PLAYING or wash_trail.size() < 2:
		return
	var base_color: Color = tool_colors[selected_tool]
	var radius := _tool_radius(selected_tool)
	# Faster sweeps read as more effort: scale the streak's reach and brightness
	# with the smoothed pointer speed.
	var intensity := clampf(wash_speed / 900.0, 0.18, 1.0)
	var count := wash_trail.size()
	var has_prev := false
	var prev_pos := Vector2.ZERO
	for index in range(count):
		var point := wash_trail[index] as Dictionary
		var life := clampf(1.0 - float(point["age"]) / TRAIL_LIFETIME, 0.0, 1.0)
		var seq := float(index + 1) / float(count)
		var pos := point["pos"] as Vector2
		var blob_r := radius * (0.3 + 0.5 * seq) * (0.6 + 0.4 * intensity)
		if has_prev:
			var line_color := base_color
			line_color.a = (0.07 + 0.2 * seq) * life * intensity
			draw_line(prev_pos, pos, line_color, blob_r * 0.9)
		var blob_color := base_color
		blob_color.a = (0.1 + 0.3 * seq) * life * intensity
		draw_circle(pos, blob_r, blob_color)
		prev_pos = pos
		has_prev = true


func _tool_radius(tool_id: String) -> float:
	var radius := Coaching.tool_radius(tool_id) * _reach_upgrade_mult(tool_id)
	if tool_id == TOOL_WATER and _water_boost_active():
		radius *= WATER_BOOST_RADIUS_MULT
	return radius


func _tool_power_multiplier(tool_id: String) -> float:
	var power := 1.0 if tool_id == TOOL_AIR else _upgrade_mult(tool_id)
	if tool_id == TOOL_WATER and _water_boost_active():
		power *= WATER_BOOST_POWER_MULT
	return power


func _spawn_tool_particles(point: Vector2, delta: float) -> void:
	last_particle_spawn += delta
	if last_particle_spawn < 0.025:
		return
	last_particle_spawn = 0.0

	if selected_tool == TOOL_WATER:
		_spawn_water_particles(point)
	elif selected_tool == TOOL_AIR:
		_spawn_air_particles(point)
	elif selected_tool == TOOL_SOAP:
		_spawn_soap_particles(point)
	elif selected_tool == TOOL_SPONGE:
		_spawn_sponge_particles(point)


func _spawn_water_particles(point: Vector2) -> void:
	var batch: Array[WashParticle] = []
	var fan_direction := Vector2(-0.22, -1.0).rotated(rng.randf_range(-0.12, 0.12)).normalized()
	batch.append(WashParticle.new(point, fan_direction * 14.0, 0.34, 10.0, Color(0.68, 0.91, 1.0, 0.76), STYLE_SPRAY_FAN))
	for index in range(3):
		var angle := rng.randf_range(-PI, 0.0)
		var speed := rng.randf_range(60.0, 170.0)
		var velocity := Vector2.from_angle(angle) * speed
		var jitter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0))
		batch.append(WashParticle.new(point + jitter, velocity, rng.randf_range(0.3, 0.6), rng.randf_range(2.0, 4.5), Color("#89d8ff"), STYLE_DROPLET))
	for index in range(2):
		var splash_angle := rng.randf_range(-PI + 0.2, -0.2)
		var splash_speed := rng.randf_range(125.0, 210.0)
		batch.append(WashParticle.new(point, Vector2.from_angle(splash_angle) * splash_speed, rng.randf_range(0.28, 0.48), rng.randf_range(3.0, 5.0), Color(0.72, 0.93, 1.0, 0.9), STYLE_SPLASH))
	batch.append(WashParticle.new(
		point + Vector2(rng.randf_range(-12.0, 12.0), -6.0),
		Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-24.0, -12.0)),
		rng.randf_range(0.48, 0.72),
		rng.randf_range(9.0, 15.0),
		Color(0.92, 0.98, 1.0, 0.28),
		STYLE_MIST
	))
	_append_water_effect_batch(batch)


func _append_particle(particle: WashParticle) -> void:
	while particles.size() >= PARTICLE_CAP:
		particles.remove_at(0)
	particles.append(particle)


func _append_particle_batch(batch: Array[WashParticle]) -> void:
	var batch_start := maxi(0, batch.size() - PARTICLE_CAP)
	var incoming_count := batch.size() - batch_start
	var overflow := particles.size() + incoming_count - PARTICLE_CAP
	while overflow > 0 and not particles.is_empty():
		particles.remove_at(0)
		overflow -= 1
	for index in range(batch_start, batch.size()):
		particles.append(batch[index])


func _append_water_effect_batch(batch: Array[WashParticle]) -> void:
	# Keep the dedicated water budget first; the shared append helper then applies
	# the total transient budget across every tool and celebration effect.
	var overflow := _water_effect_particle_count() + batch.size() - WATER_EFFECT_PARTICLE_CAP
	while overflow > 0:
		var removed_one := false
		for index in range(particles.size()):
			var candidate := particles[index] as WashParticle
			if candidate.style in WATER_EFFECT_STYLES:
				particles.remove_at(index)
				overflow -= 1
				removed_one = true
				break
		if not removed_one:
			break
	_append_particle_batch(batch)


func _water_effect_particle_count() -> int:
	var count := 0
	for raw_particle in particles:
		if (raw_particle as WashParticle).style in WATER_EFFECT_STYLES:
			count += 1
	return count


func _append_foam_effect_batch(batch: Array[WashParticle]) -> void:
	# Foam is persistent in the silhouette layer, so transient bubbles can safely
	# evict the oldest foam particles without changing gameplay state.
	# A high-level bomb can produce a batch larger than the cap by itself; keep
	# only its newest particles before considering already-active effects.
	var batch_start := maxi(0, batch.size() - FOAM_EFFECT_PARTICLE_CAP)
	var incoming_count := batch.size() - batch_start
	var overflow := _foam_effect_particle_count() + incoming_count - FOAM_EFFECT_PARTICLE_CAP
	while overflow > 0:
		var removed_one := false
		for index in range(particles.size()):
			var candidate := particles[index] as WashParticle
			if candidate.style in FOAM_EFFECT_STYLES:
				particles.remove_at(index)
				overflow -= 1
				removed_one = true
				break
		if not removed_one:
			break
	var retained_batch: Array[WashParticle] = []
	for index in range(batch_start, batch.size()):
		retained_batch.append(batch[index])
	_append_particle_batch(retained_batch)


func _foam_effect_particle_count() -> int:
	var count := 0
	for raw_particle in particles:
		if (raw_particle as WashParticle).style in FOAM_EFFECT_STYLES:
			count += 1
	return count


func _spawn_air_particles(point: Vector2) -> void:
	for index in range(3):
		var angle := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var speed := rng.randf_range(120.0, 230.0)
		var velocity := Vector2.from_angle(angle) * speed + Vector2(0.0, rng.randf_range(-36.0, -8.0))
		var jitter := Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))
		_append_particle(WashParticle.new(point + jitter, velocity, rng.randf_range(0.2, 0.45), rng.randf_range(7.0, 13.0), Color(1.0, 1.0, 1.0, 0.55), STYLE_STREAK))
	if rng.randf() < 0.6:
		_append_particle(WashParticle.new(point + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-16.0, 16.0)), Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-60.0, -20.0)), rng.randf_range(0.35, 0.6), rng.randf_range(6.0, 11.0), Color(1.0, 1.0, 1.0, 0.4), STYLE_SWIRL))


func _spawn_soap_particles(point: Vector2) -> void:
	var batch: Array[WashParticle] = []
	for index in range(5):
		var jitter := Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-14.0, 14.0))
		var velocity := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-46.0, -14.0))
		var tint := Color.from_hsv(rng.randf(), 0.12, 1.0, 0.85)
		batch.append(WashParticle.new(point + jitter, velocity, rng.randf_range(0.5, 1.0), rng.randf_range(3.0, 8.0), tint, STYLE_BUBBLE))
	_append_foam_effect_batch(batch)


func _spawn_sponge_particles(point: Vector2) -> void:
	var batch: Array[WashParticle] = []
	for index in range(3):
		var jitter := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 14.0))
		batch.append(WashParticle.new(point + jitter, Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-8.0, 4.0)), rng.randf_range(0.4, 0.8), rng.randf_range(5.0, 10.0), Color(1.0, 1.0, 1.0, 0.7), STYLE_FOAM))
	if rng.randf() < 0.7:
		batch.append(WashParticle.new(point + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-12.0, 8.0)), Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-36.0, -12.0)), rng.randf_range(0.4, 0.8), rng.randf_range(2.5, 5.0), Color(0.95, 1.0, 1.0, 0.8), STYLE_BUBBLE))
	_append_foam_effect_batch(batch)


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index] as WashParticle
		particle.ttl -= delta
		particle.position += particle.velocity * delta
		if particle.style == STYLE_DROPLET or particle.style == STYLE_SPLASH:
			particle.velocity.y += 320.0 * delta
		elif particle.style == STYLE_RING:
			particle.radius += delta * 60.0
		elif particle.style == STYLE_MIST:
			particle.radius += delta * 30.0
			particle.velocity *= 0.94
		elif particle.style == STYLE_SPRAY_FAN:
			particle.radius += delta * 48.0
			particle.velocity *= 0.86
		elif particle.style == STYLE_BUBBLE:
			particle.velocity *= 0.97
			particle.position.x += sin(particle.ttl * 7.0) * 14.0 * delta
		elif particle.style == STYLE_SWIRL:
			particle.velocity *= 0.94
		elif particle.style == STYLE_SPARKLE:
			particle.velocity *= 0.95
		else:
			particle.velocity *= 0.92
		if particle.ttl <= 0.0:
			particles.remove_at(index)


func _update_clean_progress() -> void:
	var dirt_left := 0.0
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		dirt_left += patch.health
	clean_progress = clamp(1.0 - dirt_left / initial_dirt_total, 0.0, 1.0)
	_check_progress_milestone()

	if clean_progress >= 0.985 and not completed:
		completed = true
		show_booster_panel = false
		body_foam_coverage = 0.0
		body_foam_runoff = 0.0
		_gleam_time = 0.0
		is_washing = false
		earned_stars = _calc_stars()
		_customer_completion_time = float(Time.get_ticks_msec()) / 1000.0
		coin_reward = _calc_coin_reward(earned_stars)
		customer_tip_reward = Economy.calc_customer_tip(_current_customer_patience())
		coin_reward += customer_tip_reward
		_perfect_wash_bonus = Economy.perfect_wash_bonus(earned_stars) if level_mistakes == 0 else 0
		coin_reward += _perfect_wash_bonus
		_level_milestone_bonus = _calc_level_milestone_bonus(active_level_index)
		coin_reward += _level_milestone_bonus
		coins += coin_reward
		total_stars += earned_stars
		# B: latch whether to offer the level-end "double coins" rewarded ad, so the
		# completion panel reserves a stable button row for the life of this screen.
		_double_offer_shown = ads != null and ads.is_rewarded_ready("level_reward_2x")
		_register_best_time()
		_emit_analytics(ContentEvents.level_complete(
			active_level_index, earned_stars, int(level_time), best_combo, coin_reward, is_new_record
		))
		_record_completion_daily_mission()
		_record_achievement_increment(AchievementProgress.COUNTER_WASHES)
		_record_achievement_max(AchievementProgress.COUNTER_STARS, total_stars)
		_save_progress()
		_stop_tool_loop()
		_play_completion_sound()
		_play_star_earn_sfx(earned_stars, func() -> void:
			audio.play_coin_bonus())
		_spawn_completion_burst()
		if _star_reveal_times[0] < 0.0:
			var _t := float(Time.get_ticks_msec()) / 1000.0
			for _si in range(min(earned_stars, STAR_REVEAL_DELAYS.size())):
				_star_reveal_times[_si] = _t + STAR_REVEAL_DELAYS[_si]
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(80)


func _reset_stalled_dirt_highlight() -> void:
	_stalled_dirt_highlight_active = false
	_seconds_without_cleaning = 0.0
	_last_observed_clean_progress = clean_progress


func _update_stalled_dirt_highlight(delta: float) -> void:
	if StalledDirtHighlight.cleaning_resumed(_last_observed_clean_progress, clean_progress):
		_seconds_without_cleaning = 0.0
		_stalled_dirt_highlight_active = false
		_last_observed_clean_progress = clean_progress
	elif clean_progress < _last_observed_clean_progress:
		# Reset/load paths normally call _reset_stalled_dirt_highlight directly;
		# keep this defensive branch for test fixtures and future level flows.
		_last_observed_clean_progress = clean_progress

	var gameplay_active := game_state == STATE_PLAYING \
		and not completed \
		and not show_tutorial \
		and not show_pause \
		and not show_quit_confirm \
		and not show_booster_panel \
		and not _car_transition_blocks_gameplay()
	if not gameplay_active:
		_stalled_dirt_highlight_active = false
		return

	_seconds_without_cleaning += maxf(delta, 0.0)
	_stalled_dirt_highlight_active = StalledDirtHighlight.should_show(
		clean_progress,
		_seconds_without_cleaning
	)


# Star time threshold tightens 1.5% per level after the first (floor at 60% of base).
# This ensures experienced players face a gradually rising skill ceiling.
func _star_time_threshold(tier: int) -> float:
	return Scoring.star_time_threshold(tier, active_level_index)


func _calc_stars() -> int:
	return Scoring.calc_stars(level_time, best_combo, active_level_index)


func _star3_combo_requirement() -> int:
	return Scoring.star3_combo_requirement(active_level_index)


func _grade_combo_prompt() -> String:
	return tr("GRADE_COMBO_FOR3") % _star3_combo_requirement()


# Live state of one star slot in the HUD grade tracker (0 = first star).
# earned: counted in the grade right now. target: still reachable but a
# condition is unmet (3rd star needs the combo gate). locked: no longer reachable.
func _grade_slot_state(slot_index: int) -> String:
	return Scoring.grade_slot_state(slot_index, level_time, best_combo, active_level_index, GRADE_SLOT_EARNED, GRADE_SLOT_TARGET, GRADE_SLOT_LOCKED)


# Seconds until the next star is lost, or -1 once only the floor star remains.
func _grade_time_to_downgrade() -> float:
	return Scoring.grade_time_to_downgrade(level_time, active_level_index)


# Star slot (0-based) whose threshold is approaching next, or -1 when none.
func _grade_at_risk_slot() -> int:
	return Scoring.grade_at_risk_slot(level_time, active_level_index)


func _register_best_time() -> void:
	var previous_best: float = _best_time_for_level(active_level_index)
	is_new_record = BestTime.is_new_record(previous_best, level_time)
	if is_new_record:
		best_times[active_level_index] = level_time
		record_pop_time = float(Time.get_ticks_msec()) / 1000.0
		audio.play_record()
	best_stars = StageSelection.record_best_stars(best_stars, active_level_index, earned_stars)


func _best_time_for_level(level: int) -> float:
	return BestTime.best_time(best_times, level)


func _check_progress_milestone() -> void:
	const THRESHOLDS := [0.25, 0.50, 0.75]
	var MESSAGES := [tr("MILESTONE_25"), tr("MILESTONE_50"), tr("MILESTONE_75")]
	const HUES := [0.55, 0.35, 0.08]
	const TEXT_COLORS := [Color(0.08, 0.72, 0.72), Color(0.14, 0.70, 0.28), Color(0.85, 0.48, 0.08)]
	if _progress_milestone_hit >= THRESHOLDS.size() or completed:
		return
	# Batch-advance through all crossed thresholds in one call so a progress
	# jump (e.g. 20%→60%) shows the highest milestone reached, not a rapid
	# cascade that overwrites before the player can read any of them.
	var new_hit := _progress_milestone_hit
	while new_hit < THRESHOLDS.size() and clean_progress >= THRESHOLDS[new_hit]:
		new_hit += 1
	if new_hit == _progress_milestone_hit:
		return
	var stage := new_hit - 1
	_progress_milestone_hit = new_hit
	_progress_milestone_time = float(Time.get_ticks_msec()) / 1000.0
	_progress_milestone_text = MESSAGES[stage]
	_progress_milestone_color = TEXT_COLORS[stage]
	audio.play_milestone(stage)
	var hue: float = float(HUES[stage])
	for index in range(22):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(50.0, 130.0)
		_append_particle(WashParticle.new(
			Vector2(rng.randf_range(40.0, 280.0), 72.0),
			Vector2.from_angle(angle) * speed + Vector2(0.0, -28.0),
			rng.randf_range(0.55, 1.1),
			rng.randf_range(3.0, 6.5),
			Color.from_hsv(hue + rng.randf_range(-0.06, 0.06), 0.65, 1.0, 0.9),
			STYLE_SPARKLE
		))


func _spawn_completion_burst() -> void:
	if completion_burst_done:
		return
	completion_burst_done = true
	for index in range(90):
		var angle := rng.randf_range(-PI, 0.0)
		var speed := rng.randf_range(70.0, 230.0)
		var color := Color.from_hsv(rng.randf(), 0.55, 1.0, 0.95)
		var particle := WashParticle.new(Vector2(rng.randf_range(70.0, 330.0), rng.randf_range(300.0, 620.0)), Vector2.from_angle(angle) * speed, rng.randf_range(0.7, 1.6), rng.randf_range(3.0, 7.0), color, STYLE_CONFETTI)
		_append_particle(particle)
	if is_new_record:
		_spawn_record_burst()
	if level_time > 0.0 and level_time < 60.0:
		_spawn_speedrun_burst()


func _spawn_speedrun_burst() -> void:
	var center := DESIGN_SIZE * 0.5
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		var speed := rng.randf_range(190.0, 360.0)
		var hue := rng.randf_range(0.10, 0.15)  # gold
		_append_particle(WashParticle.new(
			center,
			Vector2.from_angle(angle) * speed,
			rng.randf_range(0.55, 1.1),
			rng.randf_range(3.5, 6.5),
			Color.from_hsv(hue, 0.88, 1.0, 0.95),
			STYLE_SPARKLE
		))


func _spawn_record_burst() -> void:
	for index in range(26):
		var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
		var speed := rng.randf_range(150.0, 320.0)
		var gold := Color.from_hsv(rng.randf_range(0.1, 0.14), 0.7, 1.0, 0.95)
		_append_particle(WashParticle.new(Vector2(195.0, 300.0), Vector2.from_angle(angle) * speed, rng.randf_range(0.8, 1.5), rng.randf_range(4.0, 8.0), gold, STYLE_CONFETTI))
	for index in range(14):
		var angle := rng.randf_range(0.0, TAU)
		_append_particle(WashParticle.new(Vector2(195.0, 290.0) + Vector2.from_angle(angle) * rng.randf_range(0.0, 60.0), Vector2(0.0, rng.randf_range(-40.0, -12.0)), rng.randf_range(0.5, 1.0), rng.randf_range(4.0, 7.0), Color(1.0, 0.95, 0.65, 0.95), STYLE_SPARKLE))


func _draw_background() -> void:
	var overhang := canvas_origin / maxf(canvas_scale, 0.001)
	var bg_left := -overhang.x
	var bg_top := -overhang.y
	var bg_width := DESIGN_SIZE.x + overhang.x * 2.0
	var bg_bottom := DESIGN_SIZE.y + overhang.y
	draw_rect(Rect2(bg_left, bg_top, bg_width, bg_bottom - bg_top), Color("#87e3e9"))
	draw_rect(Rect2(bg_left, bg_top, bg_width, 155.0 - bg_top), Color("#9ff0ef"))
	draw_rect(Rect2(bg_left, 620.0, bg_width, bg_bottom - 620.0), Color("#6dd0d1"))

	var line_slope := 28.0 / DESIGN_SIZE.x
	for y_index in range(0, 7):
		var y := 638.0 + float(y_index) * 32.0
		draw_line(Vector2(bg_left, y + bg_left * line_slope), Vector2(bg_left + bg_width, y + (bg_left + bg_width) * line_slope), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	var x_start := int(floor((bg_left - 50.0) / 58.0))
	var x_end := int(ceil((bg_left + bg_width + 30.0) / 58.0))
	for x_index in range(x_start, x_end):
		var x := float(x_index) * 58.0 - 30.0
		draw_line(Vector2(x, 620.0), Vector2(x + 80.0, bg_bottom), Color(0.0, 0.0, 0.0, 0.08), 1.0)

	draw_circle(Vector2(68.0, 170.0), 48.0, Color(1.0, 1.0, 1.0, 0.18))
	draw_circle(Vector2(345.0, 197.0), 28.0, Color(1.0, 1.0, 1.0, 0.13))
	draw_circle(Vector2(35.0, 720.0), 20.0, Color(1.0, 1.0, 1.0, 0.16))
	draw_circle(Vector2(356.0, 690.0), 24.0, Color(1.0, 1.0, 1.0, 0.12))


func _draw_status() -> void:
	var font: Font = _font()
	var card := _get_status_rect()
	draw_style_box(_style("hud_shadow", Color(0.05, 0.23, 0.33, 0.25), 20.0), Rect2(card.position + Vector2(0.0, 3.0), card.size))
	draw_style_box(_style("hud_card", Color(0.97, 0.99, 1.0, 0.94), 20.0), card)

	var coin_chip := Rect2(32.0, card.position.y + 10.0, 90.0, 28.0)
	draw_style_box(_style("coin_chip", Color("#fff3cf"), 14.0), coin_chip)
	if not _draw_tex_centered("coin", coin_chip.position + Vector2(16.0, 14.0), 22.0):
		draw_circle(coin_chip.position + Vector2(16.0, 14.0), 8.0, Color("#ffce3d"))
		draw_circle(coin_chip.position + Vector2(16.0, 14.0), 8.0, Color("#9a7400"), false, 1.5)
	var coin_text := "%d" % coins
	var coin_text_width := coin_chip.size.x - 38.0
	var coin_font_size := 14
	while coin_font_size > 10 and font.get_string_size(coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, coin_font_size).x > coin_text_width:
		coin_font_size -= 1
	draw_string(font, Vector2(coin_chip.position.x + 30.0, coin_chip.position.y + 20.0), coin_text, HORIZONTAL_ALIGNMENT_LEFT, coin_text_width, coin_font_size, Color("#6b5200"))
	var badge := Rect2(card.end.x - 120.0, card.position.y + 10.0, 104.0, 28.0)
	draw_style_box(_style("level_badge", Color("#49a7ff"), 14.0), badge)
	draw_string(font, Vector2(badge.position.x, badge.position.y + 20.0), "%s %02d" % [car_type_labels[car_type], active_level_index], HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color.WHITE)

	var bar_rect := Rect2(32.0, card.position.y + 46.0, 196.0, 24.0)
	draw_style_box(_style("bar_bg", Color("#d7e8ef"), 12.0), bar_rect)
	var cp := clampf(clean_progress, 0.0, 1.0)
	var fill_width: float = bar_rect.size.x * cp
	_bar_fill_style.bg_color = BAR_COL_START.lerp(BAR_COL_END, cp)
	if cp > 0.0:
		var draw_w := maxf(fill_width, 2.0)
		_bar_fill_style.set_corner_radius_all(mini(6, int(draw_w * 0.5)))
		draw_style_box(_bar_fill_style, Rect2(bar_rect.position, Vector2(draw_w, bar_rect.size.y)))
	draw_string(font, Vector2(236.0, bar_rect.position.y + 18.0), "%.0f%%" % (cp * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 15, Color("#0d3b55"))

	if _progress_milestone_time >= 0.0:
		var age := float(Time.get_ticks_msec()) / 1000.0 - _progress_milestone_time
		if age < 1.4:
			var alpha := 1.0 - age / 1.4
			var rise := age * 42.0
			var mc := _progress_milestone_color
			draw_string(font, Vector2(32.0, bar_rect.position.y - rise), _progress_milestone_text, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, 17, Color(mc.r, mc.g, mc.b, alpha))


# The selected-tool hint chip. Drawn as its own pass AFTER the car so the car
# never paints over it (it sits low on screen and, with a bottom safe-area
# inset, rises into the car's drawn area).
func _draw_tool_hint() -> void:
	var font: Font = _font()
	# Sit above the toolbar PANEL top (_tool_button_y - TOOLBAR_TOP_GAP), not just the
	# buttons, so a bottom safe-area inset never lets the panel overlap this chip.
	var hint_rect := Rect2(22.0, minf(696.0, _tool_button_y() - 60.0), 244.0, 30.0)
	draw_style_box(_style("hint_bubble", Color(0.03, 0.14, 0.2, 0.78), 15.0), hint_rect)
	draw_string(font, Vector2(hint_rect.position.x, hint_rect.position.y + 21.0), "%s · %s" % [tool_labels[selected_tool], _tool_hint()], HORIZONTAL_ALIGNMENT_CENTER, hint_rect.size.x, 13, Color(0.93, 0.99, 1.0))


func _tool_hint() -> String:
	if selected_tool == TOOL_AIR:
		return tr("HINT_AIR")
	if selected_tool == TOOL_WATER:
		return tr("HINT_WATER")
	if selected_tool == TOOL_SOAP:
		return tr("HINT_SOAP")
	if selected_tool == TOOL_SPONGE:
		return tr("HINT_SPONGE")
	return ""


# Localized daily-mission label rendered from the mission type + target so it
# follows the active locale (the persisted `daily_mission_label` stays for save
# compatibility but does not drive display).
func _daily_mission_display_label() -> String:
	var display_value := DailyMission.display_value(
		daily_mission_type, daily_mission_target, daily_mission_requirement
	)
	return tr("DM_" + daily_mission_type.to_upper()) % display_value


func _build_car_shapes() -> void:
	_body_foam_spot_cache.clear()
	car_shapes["compact"] = {
		"silhouette": _smooth_polygon(PackedVector2Array([
			Vector2(60.0, 650.0), Vector2(50.0, 588.0), Vector2(52.0, 518.0), Vector2(66.0, 478.0),
			Vector2(98.0, 466.0), Vector2(116.0, 458.0), Vector2(124.0, 398.0), Vector2(138.0, 374.0),
			Vector2(172.0, 364.0), Vector2(218.0, 364.0), Vector2(252.0, 374.0), Vector2(266.0, 398.0),
			Vector2(274.0, 458.0), Vector2(292.0, 466.0), Vector2(324.0, 478.0), Vector2(338.0, 518.0),
			Vector2(340.0, 588.0), Vector2(330.0, 650.0), Vector2(298.0, 660.0), Vector2(92.0, 660.0),
		]), 2),
		"bumper": _smooth_polygon(PackedVector2Array([
			Vector2(64.0, 612.0), Vector2(326.0, 612.0), Vector2(330.0, 632.0), Vector2(322.0, 652.0),
			Vector2(296.0, 658.0), Vector2(94.0, 658.0), Vector2(68.0, 652.0), Vector2(60.0, 632.0),
		]), 2),
		"left_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(96.0, 460.0), Vector2(74.0, 452.0), Vector2(64.0, 462.0), Vector2(72.0, 478.0), Vector2(98.0, 478.0),
		]), 2),
		"right_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(294.0, 460.0), Vector2(316.0, 452.0), Vector2(326.0, 462.0), Vector2(318.0, 478.0), Vector2(292.0, 478.0),
		]), 2),
		"windshield": _smooth_polygon(PackedVector2Array([
			Vector2(142.0, 386.0), Vector2(248.0, 386.0), Vector2(262.0, 444.0), Vector2(254.0, 458.0),
			Vector2(136.0, 458.0), Vector2(128.0, 444.0),
		]), 2),
	}
	car_shapes["sports"] = {
		"silhouette": _smooth_polygon(PackedVector2Array([
			Vector2(64.0, 654.0), Vector2(48.0, 600.0), Vector2(50.0, 540.0), Vector2(60.0, 500.0),
			Vector2(86.0, 480.0), Vector2(120.0, 462.0), Vector2(130.0, 404.0), Vector2(146.0, 376.0),
			Vector2(176.0, 366.0), Vector2(214.0, 366.0), Vector2(244.0, 376.0), Vector2(260.0, 404.0),
			Vector2(270.0, 462.0), Vector2(304.0, 480.0), Vector2(330.0, 500.0), Vector2(340.0, 540.0),
			Vector2(342.0, 600.0), Vector2(326.0, 654.0), Vector2(296.0, 662.0), Vector2(94.0, 662.0),
		]), 2),
		"bumper": _smooth_polygon(PackedVector2Array([
			Vector2(62.0, 616.0), Vector2(328.0, 616.0), Vector2(334.0, 634.0), Vector2(326.0, 654.0),
			Vector2(296.0, 662.0), Vector2(94.0, 662.0), Vector2(64.0, 654.0), Vector2(56.0, 634.0),
		]), 2),
		"left_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(112.0, 468.0), Vector2(88.0, 462.0), Vector2(78.0, 472.0), Vector2(88.0, 486.0), Vector2(114.0, 484.0),
		]), 2),
		"right_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(278.0, 468.0), Vector2(302.0, 462.0), Vector2(312.0, 472.0), Vector2(302.0, 486.0), Vector2(276.0, 484.0),
		]), 2),
		"windshield": _smooth_polygon(PackedVector2Array([
			Vector2(150.0, 390.0), Vector2(240.0, 390.0), Vector2(254.0, 444.0), Vector2(246.0, 456.0),
			Vector2(144.0, 456.0), Vector2(136.0, 444.0),
		]), 2),
	}
	car_shapes["truck"] = {
		"silhouette": _smooth_polygon(PackedVector2Array([
			Vector2(58.0, 652.0), Vector2(50.0, 590.0), Vector2(52.0, 506.0), Vector2(60.0, 474.0),
			Vector2(94.0, 464.0), Vector2(114.0, 456.0), Vector2(118.0, 394.0), Vector2(124.0, 370.0),
			Vector2(130.0, 364.0), Vector2(152.0, 360.0), Vector2(238.0, 360.0), Vector2(260.0, 364.0),
			Vector2(266.0, 370.0), Vector2(272.0, 394.0), Vector2(276.0, 456.0), Vector2(296.0, 464.0),
			Vector2(330.0, 474.0), Vector2(338.0, 506.0), Vector2(340.0, 590.0), Vector2(332.0, 652.0),
			Vector2(300.0, 660.0), Vector2(90.0, 660.0),
		]), 2),
		"bumper": _smooth_polygon(PackedVector2Array([
			Vector2(60.0, 600.0), Vector2(330.0, 600.0), Vector2(334.0, 626.0), Vector2(328.0, 654.0),
			Vector2(298.0, 662.0), Vector2(92.0, 662.0), Vector2(62.0, 654.0), Vector2(56.0, 626.0),
		]), 2),
		"left_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(94.0, 448.0), Vector2(68.0, 440.0), Vector2(56.0, 452.0), Vector2(66.0, 472.0), Vector2(96.0, 470.0),
		]), 2),
		"right_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(296.0, 448.0), Vector2(322.0, 440.0), Vector2(334.0, 452.0), Vector2(324.0, 472.0), Vector2(294.0, 470.0),
		]), 2),
		"windshield": _smooth_polygon(PackedVector2Array([
			Vector2(138.0, 378.0), Vector2(252.0, 378.0), Vector2(260.0, 444.0), Vector2(252.0, 456.0),
			Vector2(138.0, 456.0), Vector2(130.0, 444.0),
		]), 2),
	}
	car_shapes["van"] = {
		"silhouette": _smooth_polygon(PackedVector2Array([
			Vector2(58.0, 652.0), Vector2(50.0, 590.0), Vector2(50.0, 492.0), Vector2(58.0, 456.0),
			Vector2(90.0, 448.0), Vector2(110.0, 440.0), Vector2(112.0, 378.0), Vector2(122.0, 348.0),
			Vector2(144.0, 338.0), Vector2(246.0, 338.0), Vector2(268.0, 348.0), Vector2(278.0, 378.0),
			Vector2(280.0, 440.0), Vector2(300.0, 448.0), Vector2(332.0, 456.0), Vector2(340.0, 492.0),
			Vector2(340.0, 590.0), Vector2(332.0, 652.0), Vector2(300.0, 660.0), Vector2(90.0, 660.0),
		]), 2),
		"bumper": _smooth_polygon(PackedVector2Array([
			Vector2(58.0, 606.0), Vector2(332.0, 606.0), Vector2(336.0, 632.0), Vector2(328.0, 654.0),
			Vector2(298.0, 662.0), Vector2(92.0, 662.0), Vector2(62.0, 654.0), Vector2(54.0, 632.0),
		]), 2),
		"left_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(92.0, 438.0), Vector2(64.0, 430.0), Vector2(52.0, 442.0), Vector2(64.0, 462.0), Vector2(94.0, 460.0),
		]), 2),
		"right_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(298.0, 438.0), Vector2(326.0, 430.0), Vector2(338.0, 442.0), Vector2(326.0, 462.0), Vector2(296.0, 460.0),
		]), 2),
		"windshield": _smooth_polygon(PackedVector2Array([
			Vector2(136.0, 354.0), Vector2(254.0, 354.0), Vector2(266.0, 426.0), Vector2(256.0, 442.0),
			Vector2(134.0, 442.0), Vector2(124.0, 426.0),
		]), 2),
	}
	car_shapes["offroad"] = {
		"silhouette": _smooth_polygon(PackedVector2Array([
			Vector2(50.0, 650.0), Vector2(42.0, 602.0), Vector2(48.0, 520.0), Vector2(58.0, 482.0),
			Vector2(92.0, 464.0), Vector2(110.0, 456.0), Vector2(122.0, 408.0), Vector2(140.0, 382.0),
			Vector2(168.0, 370.0), Vector2(222.0, 370.0), Vector2(250.0, 382.0), Vector2(268.0, 408.0),
			Vector2(280.0, 456.0), Vector2(298.0, 464.0), Vector2(332.0, 482.0), Vector2(342.0, 520.0),
			Vector2(348.0, 602.0), Vector2(340.0, 650.0), Vector2(306.0, 662.0), Vector2(84.0, 662.0),
		]), 2),
		"bumper": _smooth_polygon(PackedVector2Array([
			Vector2(50.0, 600.0), Vector2(340.0, 600.0), Vector2(344.0, 628.0), Vector2(334.0, 654.0),
			Vector2(304.0, 664.0), Vector2(86.0, 664.0), Vector2(56.0, 654.0), Vector2(46.0, 628.0),
		]), 2),
		"left_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(106.0, 454.0), Vector2(78.0, 446.0), Vector2(66.0, 458.0), Vector2(78.0, 478.0), Vector2(108.0, 474.0),
		]), 2),
		"right_mirror": _smooth_polygon(PackedVector2Array([
			Vector2(284.0, 454.0), Vector2(312.0, 446.0), Vector2(324.0, 458.0), Vector2(312.0, 478.0), Vector2(282.0, 474.0),
		]), 2),
		"windshield": _smooth_polygon(PackedVector2Array([
			Vector2(146.0, 390.0), Vector2(244.0, 390.0), Vector2(258.0, 444.0), Vector2(248.0, 458.0),
			Vector2(142.0, 458.0), Vector2(132.0, 444.0),
		]), 2),
	}


func _draw_car() -> void:
	var outline := Color("#123246")
	var shapes: Dictionary = car_shapes[car_type]
	_draw_ellipse_shape(Vector2(195.0, 668.0), Vector2(168.0, 20.0), Color(0.0, 0.0, 0.0, 0.16))

	for wheel in _wheel_specs():
		var wheel_center: Vector2 = wheel["center"]
		var wheel_radius := float(wheel["radius"])
		draw_circle(wheel_center, wheel_radius, Color("#1d2b33"))
		draw_circle(wheel_center, wheel_radius * 0.48, Color("#cfd8dc"))

	var silhouette: PackedVector2Array = shapes["silhouette"]
	draw_colored_polygon(silhouette, car_color)
	_draw_clean_shine()
	_draw_closed_outline(silhouette, outline, 5.0)

	var bumper: PackedVector2Array = shapes["bumper"]
	draw_colored_polygon(bumper, Color("#d6dde1") if car_type in ["truck", "offroad"] else Color("#e7eef2"))
	_draw_closed_outline(bumper, outline, 4.0)

	var mirror_color := car_color.darkened(0.12)
	for mirror_key in ["left_mirror", "right_mirror"]:
		var mirror: PackedVector2Array = shapes[mirror_key]
		draw_colored_polygon(mirror, mirror_color)
		_draw_closed_outline(mirror, outline, 3.0)

	var windshield: PackedVector2Array = shapes["windshield"]
	draw_colored_polygon(windshield, Color("#cfeeff"))
	_draw_closed_outline(windshield, outline, 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(158.0, 394.0), Vector2(178.0, 394.0), Vector2(152.0, 450.0), Vector2(140.0, 442.0),
	]), Color(1.0, 1.0, 1.0, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(192.0, 394.0), Vector2(202.0, 394.0), Vector2(174.0, 450.0), Vector2(164.0, 450.0),
	]), Color(1.0, 1.0, 1.0, 0.35))

	if car_type == "compact":
		_draw_compact_details(outline)
	elif car_type == "sports":
		_draw_sports_details(outline)
	elif car_type == "truck":
		_draw_truck_details(outline)
	elif car_type == "van":
		_draw_van_details(outline)
	elif car_type == "offroad":
		_draw_offroad_details(outline)

	var plate := Rect2(159.0, 582.0, 72.0, 22.0)
	draw_rect(plate, Color("#f7fbff"))
	draw_rect(plate, outline, false, 2.5)
	draw_string(_font(), Vector2(plate.position.x, plate.position.y + 16.0), license_plate_text, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 12, outline)
	_draw_body_foam(silhouette)


func _wheel_specs() -> Array[Dictionary]:
	var wheel_y := 642.0
	var wheel_radius := 31.0
	if car_type == "truck":
		wheel_y = 636.0
		wheel_radius = 35.0
	elif car_type == "offroad":
		wheel_y = 632.0
		wheel_radius = 37.0
	elif car_type == "van":
		wheel_y = 640.0
		wheel_radius = 33.0
	elif car_type == "sports":
		wheel_y = 646.0
		wheel_radius = 29.0
	return [
		{"center": Vector2(98.0, wheel_y), "radius": wheel_radius},
		{"center": Vector2(292.0, wheel_y), "radius": wheel_radius},
	]


func _draw_body_foam(silhouette: PackedVector2Array) -> void:
	var coverage := clampf(body_foam_coverage, 0.0, 1.0)
	var runoff := clampf(body_foam_runoff, 0.0, 1.0)
	if coverage <= 0.001 and runoff <= 0.001:
		return

	if coverage > 0.001:
		# The polygon fill is the mask: it can never extend beyond the active car's
		# silhouette, including the taller van and wider off-road body.
		var milk_alpha := 0.045 * coverage + 0.12 * coverage * coverage
		draw_colored_polygon(silhouette, Color(0.92, 0.985, 1.0, milk_alpha))
		var spots := _body_foam_spots(silhouette)
		var visible_float := coverage * float(spots.size())
		var visible_count := mini(spots.size(), ceili(visible_float))
		var time_now := float(Time.get_ticks_msec()) / 1000.0
		for index in range(visible_count):
			var reveal := clampf(visible_float - float(index), 0.0, 1.0)
			var center: Vector2 = spots[index]["center"]
			var radius: float = float(spots[index]["radius"]) * (0.88 + 0.06 * sin(time_now * 2.4 + float(index)))
			var alpha := (0.56 + coverage * 0.28) * reveal
			draw_circle(center, radius, Color(0.92, 0.985, 1.0, alpha))
			draw_circle(center + Vector2(radius * 0.58, radius * 0.12), radius * 0.66, Color(1.0, 1.0, 1.0, alpha * 0.82))
			draw_circle(center + Vector2(-radius * 0.48, radius * 0.24), radius * 0.54, Color(0.82, 0.95, 1.0, alpha * 0.68))
			draw_arc(center + Vector2(-radius * 0.16, -radius * 0.20), radius * 0.54, -2.7, -0.7, 8, Color(1.0, 1.0, 1.0, alpha * 0.86), 1.4)

	if runoff > 0.001:
		_draw_body_foam_runoff(silhouette, runoff)


func _draw_body_foam_runoff(silhouette: PackedVector2Array, amount: float) -> void:
	var bounds := _polygon_bounds(silhouette)
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	for index in range(6):
		var x_ratio := 0.23 + float(index) * 0.108
		var start := bounds.position + Vector2(bounds.size.x * x_ratio, bounds.size.y * (0.43 + 0.025 * float(index % 3)))
		var end := start + Vector2(sin(time_now * 2.2 + float(index)) * 3.5, bounds.size.y * (0.22 + 0.035 * float(index % 2)))
		if not Geometry2D.is_point_in_polygon(start, silhouette) or not Geometry2D.is_point_in_polygon(end, silhouette):
			continue
		var color := Color(0.88, 0.98, 1.0, amount * (0.30 + 0.06 * float(index % 3)))
		draw_line(start, end, color, 2.8 + amount * 2.2)
		draw_circle(end, 2.8 + amount * 2.0, Color(1.0, 1.0, 1.0, color.a * 0.88))


func _body_foam_spots(silhouette: PackedVector2Array) -> Array:
	if _body_foam_spot_cache.has(car_type):
		return _body_foam_spot_cache[car_type]
	var spots: Array = []
	if silhouette.is_empty():
		return spots
	var bounds := _polygon_bounds(silhouette)
	for index in range(BODY_FOAM_SPOT_UVS.size()):
		var uv: Vector2 = BODY_FOAM_SPOT_UVS[index]
		var center := bounds.position + Vector2(bounds.size.x * uv.x, bounds.size.y * uv.y)
		var radius := 8.2 + float((index * 7) % 5) * 1.15
		var margin := radius * 0.78
		var fits := Geometry2D.is_point_in_polygon(center, silhouette)
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			fits = fits and Geometry2D.is_point_in_polygon(center + direction * margin, silhouette)
		if fits:
			spots.append({"center": center, "radius": radius})
	_body_foam_spot_cache[car_type] = spots
	return spots


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _clean_shine_alpha(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	return eased * 0.46 * CLEAN_SHINE_INTENSITY_SCALE


func _draw_clean_shine() -> void:
	# This pass lives inside _draw_car. The later _draw_dirt pass naturally masks
	# shine wherever grime remains, without introducing a separate UI/canvas node.
	var alpha := _clean_shine_alpha(clean_progress)
	if alpha <= 0.001:
		return
	var cool_white := Color(0.9, 0.98, 1.0, alpha)
	var soft_white := Color(1.0, 1.0, 1.0, alpha * 0.34)

	# Two soft reflected-light bands stay inside the common hood footprint shared
	# by compact, sports, truck, van, and offroad silhouettes.
	draw_colored_polygon(PackedVector2Array([
		Vector2(82.0, 510.0),
		Vector2(98.0, 492.0),
		Vector2(154.0, 554.0),
		Vector2(143.0, 569.0),
	]), Color(1.0, 1.0, 1.0, alpha * 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(240.0, 482.0),
		Vector2(252.0, 486.0),
		Vector2(290.0, 531.0),
		Vector2(278.0, 541.0),
	]), Color(0.85, 0.96, 1.0, alpha * 0.13))

	# The curved shoulder reflection becomes the clearest read near completion.
	draw_arc(Vector2(195.0, 535.0), 108.0, PI + 0.55, TAU - 0.55, 24, cool_white, 3.0 + clean_progress * 3.0)
	draw_line(Vector2(100.0, 505.0), Vector2(121.0, 486.0), soft_white, 4.0 + clean_progress * 2.0)
	draw_line(Vector2(269.0, 486.0), Vector2(291.0, 509.0), soft_white, 3.5 + clean_progress * 2.0)


func _draw_compact_details(outline: Color) -> void:
	draw_arc(Vector2(195.0, 600.0), 128.0, PI + 0.42, TAU - 0.42, 26, outline.lerp(car_color, 0.55), 3.0)
	draw_line(Vector2(186.0, 364.0), Vector2(182.0, 342.0), outline, 3.0)
	draw_circle(Vector2(181.0, 338.0), 5.0, Color("#ff6b6b"))
	_draw_round_headlight(Vector2(118.0, 545.0), outline)
	_draw_round_headlight(Vector2(272.0, 545.0), outline)
	draw_arc(Vector2(195.0, 538.0), 34.0, PI * 0.22, PI * 0.78, 18, outline, 4.0)
	for fog_x in [86.0, 304.0]:
		draw_circle(Vector2(fog_x, 626.0), 8.0, Color("#ffe7a7"))
		draw_circle(Vector2(fog_x, 626.0), 8.0, outline, false, 2.0)
	draw_arc(Vector2(195.0, 560.0), 118.0, PI + 0.55, PI + 1.0, 12, Color(1.0, 1.0, 1.0, 0.3), 7.0)


func _draw_sports_details(outline: Color) -> void:
	var scoop := Rect2(173.0, 472.0, 44.0, 16.0)
	draw_rect(scoop, outline)
	draw_rect(Rect2(scoop.position + Vector2(4.0, 4.0), scoop.size - Vector2(8.0, 8.0)), Color("#22343d"))
	_draw_sleek_headlight(Vector2(116.0, 540.0), outline, false)
	_draw_sleek_headlight(Vector2(274.0, 540.0), outline, true)
	draw_arc(Vector2(195.0, 536.0), 30.0, PI * 0.3, PI * 0.66, 14, outline, 4.0)
	for slat_index in range(3):
		var slat_y := 556.0 + float(slat_index) * 11.0
		draw_line(Vector2(74.0, slat_y), Vector2(96.0, slat_y + 4.0), outline, 3.0)
		draw_line(Vector2(316.0, slat_y), Vector2(294.0, slat_y + 4.0), outline, 3.0)
	for led_x in [78.0, 290.0]:
		draw_rect(Rect2(led_x, 624.0, 22.0, 5.0), Color("#dff4ff"))
		draw_rect(Rect2(led_x, 624.0, 22.0, 5.0), outline, false, 1.5)
	draw_line(Vector2(96.0, 656.0), Vector2(294.0, 656.0), Color("#22343d"), 6.0)
	draw_arc(Vector2(195.0, 640.0), 150.0, PI + 0.5, PI + 0.9, 10, Color(1.0, 1.0, 1.0, 0.3), 7.0)


func _draw_truck_details(outline: Color) -> void:
	draw_line(Vector2(150.0, 354.0), Vector2(240.0, 354.0), outline, 4.0)
	draw_line(Vector2(158.0, 354.0), Vector2(158.0, 362.0), outline, 3.0)
	draw_line(Vector2(232.0, 354.0), Vector2(232.0, 362.0), outline, 3.0)
	_draw_square_headlight(Rect2(94.0, 528.0, 46.0, 32.0), outline)
	_draw_square_headlight(Rect2(250.0, 528.0, 46.0, 32.0), outline)
	for bar_index in range(3):
		var bar_y := 530.0 + float(bar_index) * 11.0
		draw_rect(Rect2(152.0, bar_y, 86.0, 5.0), outline.lerp(car_color, 0.35))
	draw_arc(Vector2(195.0, 568.0), 24.0, PI * 0.25, PI * 0.75, 12, outline, 4.0)
	for fog_x in [80.0, 296.0]:
		draw_rect(Rect2(fog_x, 620.0, 15.0, 11.0), Color("#ffe7a7"))
		draw_rect(Rect2(fog_x, 620.0, 15.0, 11.0), outline, false, 2.0)
	draw_rect(Rect2(168.0, 636.0, 54.0, 12.0), Color("#9aa7ad"))
	draw_rect(Rect2(168.0, 636.0, 54.0, 12.0), outline, false, 2.0)
	draw_arc(Vector2(195.0, 620.0), 140.0, PI + 0.5, PI + 0.85, 10, Color(1.0, 1.0, 1.0, 0.26), 7.0)


func _draw_van_details(outline: Color) -> void:
	# Split windshield and roof markers give the tall cab a delivery-van read.
	draw_line(Vector2(195.0, 350.0), Vector2(195.0, 442.0), outline, 3.0)
	for marker_x in [162.0, 195.0, 228.0]:
		draw_circle(Vector2(marker_x, 346.0), 5.0, Color("#ffb84d"))
		draw_circle(Vector2(marker_x, 346.0), 5.0, outline, false, 1.5)
	_draw_square_headlight(Rect2(88.0, 518.0, 42.0, 35.0), outline)
	_draw_square_headlight(Rect2(260.0, 518.0, 42.0, 35.0), outline)
	for slat_index in range(4):
		var slat_y := 520.0 + float(slat_index) * 12.0
		draw_line(Vector2(152.0, slat_y), Vector2(238.0, slat_y), outline.lerp(car_color, 0.3), 4.0)
	draw_arc(Vector2(195.0, 568.0), 27.0, PI * 0.24, PI * 0.76, 14, outline, 4.0)
	draw_rect(Rect2(144.0, 626.0, 102.0, 14.0), Color("#aab7bd"))
	draw_rect(Rect2(144.0, 626.0, 102.0, 14.0), outline, false, 2.0)


func _draw_offroad_details(outline: Color) -> void:
	# Roof rack, round lamps and a skid plate distinguish the lifted off-roader.
	draw_line(Vector2(142.0, 368.0), Vector2(248.0, 368.0), outline, 5.0)
	for rack_x in [152.0, 238.0]:
		draw_line(Vector2(rack_x, 368.0), Vector2(rack_x, 378.0), outline, 4.0)
	for lamp_x in [170.0, 220.0]:
		draw_circle(Vector2(lamp_x, 375.0), 9.0, outline)
		draw_circle(Vector2(lamp_x, 375.0), 6.0, Color("#fff2a8"))
	_draw_round_headlight(Vector2(112.0, 536.0), outline)
	_draw_round_headlight(Vector2(278.0, 536.0), outline)
	for slot_index in range(5):
		var slot_x := 157.0 + float(slot_index) * 18.0
		draw_rect(Rect2(slot_x, 510.0, 9.0, 48.0), outline.lerp(car_color, 0.28))
	draw_arc(Vector2(195.0, 566.0), 28.0, PI * 0.22, PI * 0.78, 14, outline, 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(146.0, 620.0), Vector2(244.0, 620.0), Vector2(230.0, 648.0), Vector2(160.0, 648.0),
	]), Color("#8f9da3"))
	draw_polyline(PackedVector2Array([
		Vector2(146.0, 620.0), Vector2(244.0, 620.0), Vector2(230.0, 648.0), Vector2(160.0, 648.0), Vector2(146.0, 620.0),
	]), outline, 2.5)
	for hook_x in [128.0, 252.0]:
		draw_arc(Vector2(hook_x, 630.0), 9.0, 0.0, PI, 12, Color("#ff7a59"), 4.0)


func _draw_round_headlight(center: Vector2, outline: Color) -> void:
	draw_circle(center, 23.0, outline)
	draw_circle(center, 19.0, Color("#fff7dd"))
	draw_circle(center, 11.0, Color("#ffe289"))
	draw_circle(center + Vector2(-5.0, -5.0), 4.5, Color(1.0, 1.0, 1.0, 0.9))


func _draw_sleek_headlight(center: Vector2, outline: Color, flip: bool) -> void:
	draw_circle(center, 21.0, outline)
	draw_circle(center, 17.0, Color("#fff7dd"))
	draw_circle(center, 9.0, Color("#ffd24d"))
	var lid_left_y := -14.0 if flip else -6.0
	var lid_right_y := -6.0 if flip else -14.0
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-22.0, lid_left_y),
		center + Vector2(22.0, lid_right_y),
		center + Vector2(22.0, -24.0),
		center + Vector2(-22.0, -24.0),
	]), car_color)
	draw_line(center + Vector2(-21.0, lid_left_y), center + Vector2(21.0, lid_right_y), outline, 4.0)
	draw_circle(center + Vector2(-4.0, 2.0), 3.5, Color(1.0, 1.0, 1.0, 0.9))


func _draw_square_headlight(rect: Rect2, outline: Color) -> void:
	draw_style_box(_style("truck_light_border", outline, 9.0), rect.grow(3.0))
	draw_style_box(_style("truck_light", Color("#fff7dd"), 7.0), rect)
	var center := rect.get_center()
	draw_circle(center, 8.0, Color("#ffe289"))
	draw_circle(center + Vector2(-4.0, -4.0), 3.0, Color(1.0, 1.0, 1.0, 0.9))


func _smooth_polygon(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current := points
	for iteration in range(iterations):
		var smoothed := PackedVector2Array()
		for index in range(current.size()):
			var point_a := current[index]
			var point_b := current[(index + 1) % current.size()]
			smoothed.append(point_a.lerp(point_b, 0.25))
			smoothed.append(point_a.lerp(point_b, 0.75))
		current = smoothed
	return current


func _draw_closed_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	if closed.size() > 0:
		closed.append(closed[0])
	draw_polyline(closed, color, width)


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _draw_dirt() -> void:
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		if _is_patch_removed(patch):
			continue
		var strength: float = clamp(patch.health / patch.max_health, 0.0, 1.0)
		var center: Vector2 = _patch_center(patch) + Vector2(patch.shake_x, 0.0)
		if patch.state == STATE_FLYING:
			_draw_flying_trail(patch, center, strength)
		if patch.wetness > 0.08 or patch.state == STATE_RUNOFF:
			_draw_runoff_streaks(center, patch.radius, patch.wetness, patch.runoff)

		if patch.kind == "mud":
			_draw_mud_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "dust":
			_draw_dust_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "leaf":
			_draw_leaf_patch(center, patch.radius, strength)
		elif patch.kind == "oil":
			_draw_oil_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "bug":
			_draw_bug_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "poop":
			_draw_poop_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "road_grime":
			_draw_road_grime_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "sap":
			_draw_sap_patch(center, patch.radius, strength, patch.seed_offset)

		if patch.wetness > 0.18:
			_draw_wet_gloss(center, patch.radius, patch.wetness)
		if patch.soap > 0.05:
			_draw_soap_foam(center, patch.radius, patch.soap)
		if patch.is_gold_spot:
			_draw_gold_spot_marker(patch, center, strength)

	# Late-cleaning guidance is a car-surface overlay only. Draw it after dirt so
	# even very faint remaining patches stay discoverable without adding HUD UI.
	if _stalled_dirt_highlight_active:
		for raw_patch in dirt_patches:
			var remaining_patch := raw_patch as DirtPatch
			if _is_patch_removed(remaining_patch):
				continue
			_draw_stalled_dirt_highlight(
				remaining_patch,
				_patch_center(remaining_patch) + Vector2(remaining_patch.shake_x, 0.0)
			)

	# Coaching hints are drawn last so they stay above any overlapping dirt.
	for raw_patch in dirt_patches:
		var hint_patch := raw_patch as DirtPatch
		if _is_patch_removed(hint_patch):
			continue
		if hint_patch.hint_time > 0.0 and hint_patch.hint_tool != "":
			_draw_patch_hint(hint_patch, _patch_center(hint_patch) + Vector2(hint_patch.shake_x, 0.0))


func _draw_stalled_dirt_highlight(patch: DirtPatch, center: Vector2) -> void:
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var pulse := 0.5 + sin(time_now * 3.8 + patch.seed_offset) * 0.5
	var radius := patch.radius + 8.0 + pulse * 3.0
	var alpha := 0.46 + pulse * 0.22
	var shadow := Color(0.03, 0.16, 0.28, alpha * 0.76)
	var highlight := Color(0.64, 0.94, 1.0, alpha)
	draw_arc(center, radius, 0.0, TAU, 30, shadow, 5.0)
	draw_arc(center, radius, 0.0, TAU, 30, highlight, 2.4)
	# Four short brackets keep the cue readable as a location marker even when
	# its cyan hue has low contrast against the current vehicle color.
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		draw_arc(center, radius + 3.5, angle - 0.22, angle + 0.22, 5, Color(1.0, 1.0, 1.0, alpha), 2.8)


func _draw_gold_spot_marker(patch: DirtPatch, center: Vector2, strength: float) -> void:
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var pulse := 1.0 + sin(time_now * 5.0 + patch.seed_offset) * 0.08
	var radius := (patch.radius + 5.0) * pulse
	var alpha := lerpf(0.72, 1.0, clampf(strength, 0.0, 1.0))
	var outline := Color(0.35, 0.22, 0.02, 0.92 * alpha)
	var gold := Color(1.0, 0.82, 0.18, alpha)
	draw_arc(center, radius, 0.0, TAU, 28, outline, 5.0)
	draw_arc(center, radius, 0.0, TAU, 28, gold, 2.5)
	# Four diamond sparkles make the target readable without relying on hue.
	for index in range(4):
		var direction := Vector2.from_angle(TAU * float(index) / 4.0 + PI * 0.25)
		var sparkle_center := center + direction * radius
		var tangent := Vector2(-direction.y, direction.x)
		var sparkle := PackedVector2Array([
			sparkle_center + direction * 6.0,
			sparkle_center + tangent * 3.0,
			sparkle_center - direction * 6.0,
			sparkle_center - tangent * 3.0,
		])
		draw_colored_polygon(sparkle, Color(1.0, 0.96, 0.58, alpha))
		var closed_sparkle := sparkle.duplicate()
		closed_sparkle.append(sparkle[0])
		draw_polyline(closed_sparkle, outline, 1.5)


func _draw_patch_hint(patch: DirtPatch, center: Vector2) -> void:
	var font: Font = _font()
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var alpha: float = clamp(patch.hint_time / 0.45, 0.0, 1.0)
	var tool_color: Color = tool_colors[patch.hint_tool]
	# Gentle ring around the patch to draw the eye to where to act.
	draw_arc(center, patch.radius + 5.0, 0.0, TAU, 22, Color(tool_color.r, tool_color.g, tool_color.b, 0.5 * alpha), 2.5)

	var bob := sin(time_now * 5.0 + patch.seed_offset) * 2.0
	var label := "%s!" % tool_labels[patch.hint_tool]
	var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	var pill_size := Vector2(text_width + 40.0, 26.0)
	var pill_center := center + Vector2(0.0, -patch.radius - 24.0 + bob)
	var pill := Rect2(pill_center - pill_size * 0.5, pill_size)

	# Arrow pointing down to the patch.
	var arrow := PackedVector2Array([
		pill_center + Vector2(-6.0, pill_size.y * 0.5 - 1.0),
		pill_center + Vector2(6.0, pill_size.y * 0.5 - 1.0),
		pill_center + Vector2(0.0, pill_size.y * 0.5 + 8.0),
	])
	var border_color := Color(tool_color.r, tool_color.g, tool_color.b, 0.95 * alpha)
	draw_colored_polygon(arrow, border_color)

	# Reused rounded boxes (no per-frame allocation, no overlapping primitives).
	if _hint_pill_box == null:
		_hint_pill_box = StyleBoxFlat.new()
		_hint_pill_box.set_corner_radius_all(int(pill_size.y * 0.5))
		_hint_pill_box.set_border_width_all(2)
		_hint_shadow_box = StyleBoxFlat.new()
		_hint_shadow_box.set_corner_radius_all(int(pill_size.y * 0.5))
	_hint_shadow_box.bg_color = Color(0.04, 0.16, 0.22, 0.26 * alpha)
	_hint_pill_box.bg_color = Color(1.0, 1.0, 1.0, 0.98 * alpha)
	_hint_pill_box.border_color = border_color
	draw_style_box(_hint_shadow_box, Rect2(pill.position + Vector2(0.0, 2.0), pill.size))
	draw_style_box(_hint_pill_box, pill)
	var dot_center := Vector2(pill.position.x + 16.0, pill_center.y)
	draw_circle(dot_center, 7.0, Color(tool_color.r, tool_color.g, tool_color.b, alpha))
	draw_string(font, Vector2(pill.position.x + 28.0, pill_center.y + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, pill_size.x - 32.0, 13, Color(0.07, 0.2, 0.29, alpha))


func _draw_mud_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var base_color := Color(
		lerp(0.72, 0.36, s),
		lerp(0.58, 0.19, s),
		lerp(0.44, 0.08, s),
		0.82 * s
	)
	draw_circle(center, radius * (0.8 + s * 0.25), base_color)
	for index in range(5):
		var angle := seed_value + float(index) * 1.35
		var offset := Vector2(cos(angle), sin(angle)) * radius * 0.45
		draw_circle(center + offset, radius * 0.38, base_color.darkened(0.1))


func _draw_dust_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var color := Color(0.86, 0.75, 0.52, 0.52 * strength)
	draw_circle(center, radius * 1.05, color)
	for index in range(7):
		var angle := seed_value + float(index) * 0.9
		var offset := Vector2(cos(angle), sin(angle)) * radius * rng.randf_range(0.2, 0.75)
		draw_circle(center + offset, max(1.5, radius * 0.12), Color(0.55, 0.43, 0.28, 0.45 * strength))


func _draw_leaf_patch(center: Vector2, radius: float, strength: float) -> void:
	var color := Color(0.2, 0.58, 0.24, 0.92 * strength)
	var vein := Color(0.1, 0.36, 0.13, 0.85 * strength)
	var tilt := 0.5
	var points := PackedVector2Array()
	for index in range(14):
		var progress := float(index) / 13.0
		var along := -radius + progress * radius * 2.0
		var width := sin(PI * progress) * radius * 0.55
		points.append(center + Vector2(along, -width).rotated(tilt))
	for index in range(14):
		var progress := 1.0 - float(index) / 13.0
		var along := -radius + progress * radius * 2.0
		var width := sin(PI * progress) * radius * 0.55
		points.append(center + Vector2(along, width).rotated(tilt))
	draw_colored_polygon(points, color)
	draw_line(center + Vector2(-radius * 0.85, 0.0).rotated(tilt), center + Vector2(radius * 0.85, 0.0).rotated(tilt), vein, 2.0)
	for index in range(3):
		var along := -radius * 0.45 + float(index) * radius * 0.4
		draw_line(center + Vector2(along, 0.0).rotated(tilt), center + Vector2(along + radius * 0.28, -radius * 0.3).rotated(tilt), vein, 1.5)
	draw_line(center + Vector2(-radius, 0.0).rotated(tilt), center + Vector2(-radius * 1.35, 0.18 * radius).rotated(tilt), vein, 2.5)


func _draw_oil_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	draw_circle(center, radius * 1.1, Color(0.03, 0.05, 0.08, 0.82 * s))
	draw_circle(center + Vector2(radius * 0.25, -radius * 0.28), radius * 0.28, Color(0.2, 0.35, 0.5, 0.5 * s))
	draw_circle(center + Vector2(-radius * 0.18, radius * 0.12), radius * 0.42, Color(0.06, 0.12, 0.16, 0.55 * s))
	_draw_oil_sheen(center, radius, s, seed_value)


func _draw_oil_sheen(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var sheen_alpha := _oil_sheen_alpha(strength)
	if sheen_alpha <= 0.0:
		return
	var saturation := _oil_sheen_saturation(strength)
	var hue_phase := fposmod(seed_value * 0.137, 1.0)
	for index in range(OIL_SHEEN_BAND_COUNT):
		var progress := float(index) / float(OIL_SHEEN_BAND_COUNT - 1)
		var hue := fposmod(hue_phase + progress * 0.82, 1.0)
		var arc_radius := radius * (0.42 + progress * 0.45)
		var start_angle := -2.95 + float(index) * 0.20 + sin(seed_value + float(index)) * 0.08
		var band_offset := Vector2.from_angle(seed_value + float(index) * 1.7) * radius * 0.045
		var band_color := Color.from_hsv(hue, saturation, 1.0, sheen_alpha * (0.76 + progress * 0.18))
		draw_arc(center + band_offset, arc_radius, start_angle, start_angle + 2.25, 14, band_color, maxf(1.5, radius * 0.105))

	# A pale, continuous crescent keeps the oily film readable without relying
	# on hue alone. It is one fixed draw call alongside the five HSV bands.
	var gloss_color := Color(0.92, 0.98, 1.0, 0.38 * strength)
	draw_arc(center + Vector2(-radius * 0.06, -radius * 0.08), radius * 0.88, -2.85, -0.48, 18, gloss_color, maxf(1.5, radius * 0.085))


func _oil_sheen_alpha(strength: float) -> float:
	return clampf(strength, 0.0, 1.0) * OIL_SHEEN_MAX_ALPHA


func _oil_sheen_saturation(strength: float) -> float:
	return clampf(strength, 0.0, 1.0) * 0.90


func _draw_bug_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var color := Color(0.28, 0.13, 0.06, 0.84 * strength)
	draw_circle(center, radius * 0.65, color)
	for index in range(8):
		var angle := seed_value + float(index) * TAU / 8.0
		draw_line(center, center + Vector2.from_angle(angle) * radius, color, 4.0 * strength)
	draw_circle(center + Vector2(-radius * 0.15, -radius * 0.1), radius * 0.18, Color(0.1, 0.05, 0.03, 0.8 * strength))


func _draw_poop_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var blob_color := Color(0.95, 0.93, 0.88, 0.90 * s)
	draw_circle(center, radius * (0.75 + s * 0.28), blob_color)
	draw_circle(center + Vector2(radius * 0.08, -radius * 0.06), radius * 0.35, Color(0.78, 0.82, 0.22, 0.68 * s))
	var drop_color := Color(0.92, 0.90, 0.84, 0.78 * s)
	for index in range(6):
		var angle := seed_value + float(index) * TAU / 6.0
		var dist: float = 0.55 + 0.28 * abs(sin(seed_value + float(index) * 0.71))
		var drop_r: float = radius * (0.12 + 0.14 * abs(cos(seed_value + float(index) * 1.13)))
		draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * dist, max(2.0, drop_r), drop_color)


func _draw_road_grime_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var rotation: float = fmod(seed_value * 0.73, TAU)
	var radius_x: float = radius * (1.22 + 0.10 * sin(seed_value * 1.7))
	var radius_y: float = radius * (0.72 + 0.08 * cos(seed_value * 1.3))
	var body_points := PackedVector2Array()
	var outer_points := PackedVector2Array()
	for index in range(14):
		var angle: float = TAU * float(index) / 14.0
		var wobble: float = 1.0 \
			+ 0.13 * sin(seed_value * 2.1 + float(index) * 1.91) \
			+ 0.08 * cos(seed_value * 1.3 + float(index) * 2.67)
		var local_point: Vector2 = Vector2(cos(angle) * radius_x, sin(angle) * radius_y) * wobble
		body_points.append(center + local_point.rotated(rotation))
		outer_points.append(center + (local_point * 1.14).rotated(rotation))
	body_points = _smooth_polygon(body_points, 1)
	outer_points = _smooth_polygon(outer_points, 1)

	# Two translucent silhouettes create a feathered, paint-hugging road-film edge
	# instead of the old sticker's hard rectangular border.
	draw_colored_polygon(outer_points, Color(0.30, 0.29, 0.26, 0.14 * s))
	draw_colored_polygon(body_points, Color(0.31, 0.28, 0.22, 0.48 * s))

	var inner_points := PackedVector2Array()
	var highlight_offset: Vector2 = Vector2(-radius * 0.10, -radius * 0.08).rotated(rotation)
	for point in body_points:
		inner_points.append(center + (point - center) * 0.68 + highlight_offset)
	draw_colored_polygon(inner_points, Color(0.48, 0.44, 0.34, 0.17 * s))

	# Deterministic grit flecks break up the silhouette without repeating a woven
	# or striped texture. They fade with the same health-driven opacity.
	for index in range(6):
		var fleck_angle: float = seed_value * 1.9 + float(index) * 1.73
		var fleck_distance: float = radius * (0.62 + 0.38 * absf(sin(seed_value + float(index) * 0.83)))
		var fleck_local: Vector2 = Vector2(
			cos(fleck_angle) * fleck_distance * 1.15,
			sin(fleck_angle) * fleck_distance * 0.70
		).rotated(rotation)
		var fleck_radius: float = maxf(1.3, radius * (0.055 + 0.045 * absf(cos(seed_value * 1.4 + float(index)))))
		draw_circle(center + fleck_local, fleck_radius, Color(0.20, 0.18, 0.14, 0.36 * s))


func _draw_sap_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	var rotation := fposmod(seed_value * 0.71, TAU)
	var amber_edge := Color(0.42, 0.20, 0.03, 0.82 * s)
	var amber_body := Color(0.94, 0.52, 0.08, 0.72 * s)
	var amber_glow := Color(1.0, 0.75, 0.20, 0.48 * s)
	var lobe_centers := PackedVector2Array()
	for index in range(3):
		var angle := rotation + float(index) * TAU / 3.0
		var lobe_center := center + Vector2.from_angle(angle) * radius * (0.26 + float(index) * 0.04)
		var lobe_radius := radius * (0.46 - float(index) * 0.055)
		lobe_centers.append(lobe_center)
		draw_circle(lobe_center, lobe_radius + 2.0, amber_edge)
		draw_circle(lobe_center, lobe_radius, amber_body)
		draw_circle(lobe_center + Vector2(-lobe_radius * 0.24, -lobe_radius * 0.28),
			lobe_radius * 0.24, amber_glow)
	# Thin resin strings make the patch readable as sticky sap rather than oil.
	for index in range(lobe_centers.size()):
		var next_index := (index + 1) % lobe_centers.size()
		draw_line(lobe_centers[index], lobe_centers[next_index], amber_edge, maxf(1.5, radius * 0.10))
	draw_arc(center, radius * 0.78, rotation - 2.45, rotation - 0.78, 12,
		Color(1.0, 0.91, 0.56, 0.76 * s), maxf(1.5, radius * 0.09))


func _draw_flying_trail(patch: DirtPatch, center: Vector2, strength: float) -> void:
	var direction := patch.velocity.normalized()
	if direction.length() < 0.1:
		direction = Vector2(-1.0, 0.12).normalized()
	for index in range(3):
		var offset := direction * -patch.radius * (0.75 + float(index) * 0.55)
		var alpha := 0.22 * strength * (1.0 - float(index) * 0.22)
		draw_line(center + offset, center + offset - direction * patch.radius * 0.8, Color(1.0, 1.0, 1.0, alpha), 2.0)


func _draw_runoff_streaks(center: Vector2, radius: float, wetness: float, runoff: float) -> void:
	var amount: float = clamp(max(wetness, runoff), 0.0, 1.0)
	if amount <= 0.0:
		return
	for index in range(4):
		var spread := -radius * 0.55 + radius * 1.1 * float(index) / 3.0
		var start := center + Vector2(spread, radius * 0.2)
		var end := start + Vector2(sin(float(index) * 1.7 + runoff * 3.0) * 7.0, radius * (1.0 + runoff * 2.2))
		draw_line(start, end, Color(0.45, 0.82, 1.0, 0.26 * amount), 3.0)
		draw_circle(end, max(2.0, radius * 0.11), Color(0.8, 0.95, 1.0, 0.22 * amount))


func _draw_wet_gloss(center: Vector2, radius: float, wetness: float) -> void:
	var alpha: float = clamp(wetness, 0.0, 1.0) * 0.26
	draw_arc(center + Vector2(-radius * 0.18, -radius * 0.16), radius * 0.7, -2.4, -0.45, 18, Color(1.0, 1.0, 1.0, alpha), 3.0)


func _draw_soap_foam(center: Vector2, radius: float, amount: float) -> void:
	var bubble_count := 5 + int(amount * 8.0)
	for index in range(bubble_count):
		var angle := float(index) * TAU / float(bubble_count)
		var offset := Vector2(cos(angle), sin(angle)) * radius * (0.3 + 0.45 * sin(float(index)))
		var bubble_radius := radius * (0.16 + 0.1 * cos(float(index) * 1.7))
		draw_circle(center + offset, max(2.0, bubble_radius), Color(1.0, 1.0, 1.0, 0.64 * amount))


func _draw_particles() -> void:
	for raw_particle in particles:
		var particle := raw_particle as WashParticle
		var alpha: float = clamp(particle.ttl * 1.7, 0.0, 1.0)
		var color: Color = particle.color
		color.a *= alpha
		if particle.style == STYLE_DROPLET:
			var direction := particle.velocity.normalized()
			draw_line(particle.position, particle.position - direction * particle.radius * 3.0, color, max(2.0, particle.radius * 0.8))
			draw_circle(particle.position, particle.radius * 0.6, color)
		elif particle.style == STYLE_SPLASH:
			var direction := particle.velocity.normalized()
			if direction.length() < 0.1:
				direction = Vector2.UP
			var bright := color.lightened(0.22)
			bright.a = color.a
			draw_line(particle.position, particle.position - direction * particle.radius * 4.2, color, max(2.2, particle.radius * 1.05))
			draw_circle(particle.position, particle.radius * 0.8, bright)
		elif particle.style == STYLE_RING:
			draw_arc(particle.position, particle.radius, 0.0, TAU, 22, color, 2.5)
		elif particle.style == STYLE_MIST:
			draw_circle(particle.position, particle.radius, Color(color.r, color.g, color.b, color.a * 0.55))
			draw_circle(particle.position + Vector2(-particle.radius * 0.55, particle.radius * 0.12), particle.radius * 0.7, Color(color.r, color.g, color.b, color.a * 0.42))
			draw_circle(particle.position + Vector2(particle.radius * 0.5, -particle.radius * 0.08), particle.radius * 0.62, Color(color.r, color.g, color.b, color.a * 0.36))
		elif particle.style == STYLE_SPRAY_FAN:
			var direction := particle.velocity.normalized()
			if direction.length() < 0.1:
				direction = Vector2.UP
			var tangent := Vector2(-direction.y, direction.x)
			var reach := particle.radius * 2.35
			var half_width := particle.radius * 1.05
			var fan_fill := Color(color.r, color.g, color.b, color.a * 0.24)
			var fan_points := PackedVector2Array([
				particle.position,
				particle.position + direction * reach + tangent * half_width,
				particle.position + direction * reach - tangent * half_width,
			])
			draw_colored_polygon(fan_points, fan_fill)
			draw_arc(particle.position, reach, direction.angle() - 0.42, direction.angle() + 0.42, 12, color, 2.4)
			for ray_offset in [-0.3, 0.0, 0.3]:
				var ray_direction := direction.rotated(ray_offset)
				draw_line(particle.position, particle.position + ray_direction * reach, Color(color.r, color.g, color.b, color.a * 0.72), 1.8)
		elif particle.style == STYLE_STREAK:
			var direction := particle.velocity.normalized()
			if direction.length() < 0.1:
				direction = Vector2.RIGHT
			draw_line(particle.position, particle.position - direction * particle.radius * 2.4, color, 2.5)
		elif particle.style == STYLE_SWIRL:
			draw_arc(particle.position, particle.radius, particle.ttl * 5.0, particle.ttl * 5.0 + 3.6, 14, color, 2.0)
		elif particle.style == STYLE_BUBBLE:
			draw_circle(particle.position, particle.radius, Color(color.r, color.g, color.b, color.a * 0.45))
			draw_arc(particle.position, particle.radius, 0.0, TAU, 16, color, 1.5)
			draw_circle(particle.position + Vector2(-particle.radius * 0.3, -particle.radius * 0.3), particle.radius * 0.25, Color(1.0, 1.0, 1.0, color.a))
		elif particle.style == STYLE_FOAM:
			draw_circle(particle.position, particle.radius, color)
			draw_circle(particle.position + Vector2(particle.radius * 0.6, particle.radius * 0.2), particle.radius * 0.7, Color(color.r, color.g, color.b, color.a * 0.8))
			draw_circle(particle.position + Vector2(-particle.radius * 0.55, particle.radius * 0.25), particle.radius * 0.6, Color(color.r, color.g, color.b, color.a * 0.8))
		elif particle.style == STYLE_SPARKLE:
			_draw_sparkle(particle.position, particle.radius, color)
		elif particle.style == STYLE_CONFETTI:
			draw_rect(Rect2(particle.position, Vector2(particle.radius * 1.5, particle.radius)), color)
		else:
			draw_circle(particle.position, particle.radius, color)


func _draw_sparkle(center: Vector2, radius: float, color: Color) -> void:
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), color, 2.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), color, 2.0)
	var diagonal := radius * 0.45
	draw_line(center + Vector2(-diagonal, -diagonal), center + Vector2(diagonal, diagonal), color, 1.5)
	draw_line(center + Vector2(-diagonal, diagonal), center + Vector2(diagonal, -diagonal), color, 1.5)
	draw_circle(center, radius * 0.22, color)


func _draw_gleam() -> void:
	if _gleam_time < 0.0 or game_state != STATE_PLAYING or not completed:
		return
	var sweep_x: float = lerp(-80.0, float(DESIGN_SIZE.x) + 80.0, _gleam_time)
	var alpha: float = sin(PI * _gleam_time) * 0.55
	var h: float = DESIGN_SIZE.y
	# Wide soft outer band (parallelogram leaning top-left to bottom-right)
	var outer_points := PackedVector2Array([
		Vector2(sweep_x - 48.0, 0.0),
		Vector2(sweep_x + 28.0, 0.0),
		Vector2(sweep_x + 52.0, h),
		Vector2(sweep_x - 24.0, h),
	])
	draw_colored_polygon(outer_points, Color(1.0, 1.0, 1.0, alpha * 0.45))
	# Narrower brighter core
	var core_points := PackedVector2Array([
		Vector2(sweep_x - 10.0, 0.0),
		Vector2(sweep_x + 14.0, 0.0),
		Vector2(sweep_x + 24.0, h),
		Vector2(sweep_x, h),
	])
	draw_colored_polygon(core_points, Color(1.0, 1.0, 1.0, alpha * 0.75))


func _draw_tool_cursor() -> void:
	if completed:
		return
	var in_play_area := _point_in_wash_area(pointer_position)
	if not is_washing and not in_play_area:
		return
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var alpha_scale := 1.0 if is_washing else 0.45
	var radius := _tool_radius(selected_tool)
	var ring_color: Color = tool_colors[selected_tool]
	ring_color.a = 0.55 * alpha_scale
	_draw_dashed_ring(pointer_position, radius, ring_color, time_now)

	if selected_tool == TOOL_WATER:
		_draw_water_gun(pointer_position, time_now, alpha_scale)
	elif selected_tool == TOOL_AIR:
		_draw_air_blower(pointer_position, time_now, alpha_scale)
	elif selected_tool == TOOL_SOAP:
		_draw_foam_bottle(pointer_position, time_now, alpha_scale)
	elif selected_tool == TOOL_SPONGE:
		_draw_sponge_tool(pointer_position, time_now, alpha_scale)


func _draw_dashed_ring(center: Vector2, radius: float, color: Color, time_now: float) -> void:
	var spin := time_now * 0.9
	for index in range(10):
		var start_angle := TAU * float(index) / 10.0 + spin
		draw_arc(center, radius, start_angle, start_angle + TAU / 22.0, 5, color, 2.0)


func _draw_water_gun(point: Vector2, time_now: float, alpha_scale: float) -> void:
	var nozzle := point + Vector2(34.0, 44.0)
	var grip := point + Vector2(64.0, 84.0)
	if is_washing:
		var wiggle := sin(time_now * 26.0) * 3.0
		draw_line(nozzle, point + Vector2(wiggle, 0.0), Color(0.85, 0.96, 1.0, 0.95), 7.0)
		draw_line(nozzle, point + Vector2(-9.0 + wiggle, 5.0), Color(0.54, 0.85, 1.0, 0.7), 4.0)
		draw_line(nozzle, point + Vector2(9.0 + wiggle, 6.0), Color(0.54, 0.85, 1.0, 0.7), 4.0)
		draw_line(nozzle, point + Vector2(wiggle * 0.5, 1.0), Color(1.0, 1.0, 1.0, 0.9), 2.5)
	draw_line(grip, nozzle, Color(0.22, 0.28, 0.31, alpha_scale), 9.0)
	draw_line(grip, grip + Vector2(4.0, 20.0), Color(0.22, 0.28, 0.31, alpha_scale), 9.0)
	draw_circle(grip + Vector2(-2.0, -4.0), 10.0, Color(1.0, 0.83, 0.29, alpha_scale))
	draw_circle(grip + Vector2(-2.0, -4.0), 10.0, Color(0.07, 0.2, 0.27, alpha_scale), false, 2.5)
	draw_circle(nozzle, 5.5, _active_skin_color(TOOL_WATER, alpha_scale))


func _draw_air_blower(point: Vector2, time_now: float, alpha_scale: float) -> void:
	var nozzle := point + Vector2(40.0, 36.0)
	var body := point + Vector2(72.0, 64.0)
	if is_washing:
		for index in range(3):
			var sway := sin(time_now * 9.0 + float(index) * 2.1) * 6.0
			var gust_center := point + Vector2(-10.0 - float(index) * 16.0, sway)
			draw_arc(gust_center, 16.0 + float(index) * 7.0, -0.9, 0.9, 12, Color(1.0, 1.0, 1.0, 0.6 - float(index) * 0.15), 3.0)
		draw_line(nozzle, point, Color(1.0, 1.0, 1.0, 0.35), 10.0)
	draw_line(body, nozzle, Color(0.38, 0.49, 0.55, alpha_scale), 13.0)
	draw_circle(body, 17.0, Color(1.0, 0.62, 0.35, alpha_scale))
	draw_circle(body, 17.0, Color(0.07, 0.2, 0.27, alpha_scale), false, 3.0)
	draw_arc(body, 10.0, 0.0, TAU, 14, Color(0.07, 0.2, 0.27, alpha_scale * 0.6), 2.0)
	draw_circle(nozzle, 6.5, _active_skin_color(TOOL_AIR, alpha_scale))


func _draw_foam_bottle(point: Vector2, time_now: float, alpha_scale: float) -> void:
	var nozzle := point + Vector2(30.0, 40.0)
	var bottle_top := point + Vector2(48.0, 56.0)
	var bottle_bottom := point + Vector2(64.0, 88.0)
	if is_washing:
		for index in range(4):
			var travel := fmod(time_now * 2.2 + float(index) * 0.25, 1.0)
			var bubble_pos := nozzle.lerp(point, travel) + Vector2(sin(travel * 9.0) * 5.0, 0.0)
			draw_circle(bubble_pos, 4.0 + travel * 4.0, Color(1.0, 1.0, 1.0, 0.8 - travel * 0.4))
	var axis := (bottle_top - bottle_bottom).normalized()
	var side := axis.orthogonal() * 10.0
	var body := PackedVector2Array([
		bottle_bottom - side + axis * -6.0, bottle_bottom + side + axis * -6.0,
		bottle_top + side, bottle_top - side,
	])
	draw_colored_polygon(body, Color(0.93, 0.91, 0.65, alpha_scale))
	_draw_closed_outline(body, Color(0.07, 0.2, 0.27, alpha_scale), 2.5)
	draw_line(bottle_top, nozzle, Color(0.55, 0.62, 0.66, alpha_scale), 7.0)
	draw_circle(nozzle, 6.0, _active_skin_color(TOOL_SOAP, alpha_scale))
	draw_circle(nozzle, 6.0, Color(0.07, 0.2, 0.27, alpha_scale), false, 2.0)


func _draw_sponge_tool(point: Vector2, time_now: float, alpha_scale: float) -> void:
	var angle := 0.0
	if is_washing:
		angle = sin(time_now * 11.0) * 0.16
		point += Vector2(sin(time_now * 11.0) * 5.0, 0.0)
	var half := Vector2(26.0, 18.0)
	var top_half := Vector2(26.0, 8.0)
	var body := _rotated_rect_points(point, half, angle)
	var cap := _rotated_rect_points(point + Vector2(0.0, -10.0).rotated(angle), top_half, angle)
	draw_colored_polygon(body, _active_skin_color(TOOL_SPONGE, alpha_scale))
	draw_colored_polygon(cap, Color(1.0, 0.84, 0.31, alpha_scale))
	_draw_closed_outline(body, Color(0.07, 0.2, 0.27, alpha_scale), 3.0)
	if is_washing:
		for index in range(4):
			var foam_offset := Vector2(-21.0 + float(index) * 14.0, 17.0).rotated(angle)
			draw_circle(point + foam_offset, 6.0 + sin(time_now * 8.0 + float(index)) * 1.5, Color(1.0, 1.0, 1.0, 0.85))


func _rotated_rect_points(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y).rotated(angle),
		center + Vector2(half.x, -half.y).rotated(angle),
		center + Vector2(half.x, half.y).rotated(angle),
		center + Vector2(-half.x, half.y).rotated(angle),
	])


func get_title_skin_swatch_colors_for_test() -> Array[Color]:
	return [
		_active_skin_color(TOOL_WATER),
		_active_skin_color(TOOL_AIR),
		_active_skin_color(TOOL_SOAP),
		_active_skin_color(TOOL_SPONGE),
	]


func get_title_hero_rect_for_test() -> Rect2:
	return Rect2(34.0, 138.0, 322.0, 234.0)


func _draw_title_hero_car() -> void:
	var hero_rect := get_title_hero_rect_for_test()
	draw_style_box(_style("title_hero_shadow", Color(0.02, 0.18, 0.27, 0.24), 26.0),
		Rect2(hero_rect.position + Vector2(0.0, 5.0), hero_rect.size))
	draw_style_box(_style("title_hero_bay", Color(0.86, 0.98, 1.0, 0.36), 26.0,
		Color(1.0, 1.0, 1.0, 0.42), 2), hero_rect)
	# Soft wash-bay light bars echo the glossy reference without importing an
	# external image and remain behind the shared procedural car path.
	for light_index in range(4):
		var light_x := hero_rect.position.x + 44.0 + float(light_index) * 78.0
		draw_line(Vector2(light_x, hero_rect.position.y + 16.0),
			Vector2(light_x - 28.0, hero_rect.end.y - 40.0), Color(1.0, 1.0, 1.0, 0.13), 18.0)
	var hero_scale := 0.48
	var hero_origin := Vector2(195.0 - 195.0 * hero_scale, -6.0)
	draw_set_transform(canvas_origin + hero_origin * canvas_scale, 0.0,
		Vector2(canvas_scale * hero_scale, canvas_scale * hero_scale))
	_draw_car()
	_set_design_draw_transform()


func _draw_title_skin_swatches() -> void:
	var swatch_rect := Rect2(97.0, 330.0, 196.0, 38.0)
	draw_style_box(_style("title_skin_swatches", Color(0.03, 0.16, 0.24, 0.78), 19.0,
		Color(1.0, 1.0, 1.0, 0.28), 1), swatch_rect)
	var tool_keys := [TOOL_WATER, TOOL_AIR, TOOL_SOAP, TOOL_SPONGE]
	var icon_names := ["tool_water", "tool_air", "tool_soap", "tool_sponge"]
	for tool_index in range(tool_keys.size()):
		var center := Vector2(swatch_rect.position.x + 28.0 + float(tool_index) * 47.0,
			swatch_rect.get_center().y)
		var skin_color := _active_skin_color(tool_keys[tool_index])
		draw_circle(center, 13.0, Color(1.0, 1.0, 1.0, 0.92))
		draw_circle(center, 10.5, skin_color)
		draw_circle(center, 10.5, Color("#123246"), false, 1.5)
		_draw_tex_centered(icon_names[tool_index], center, 14.0, Color(1.0, 1.0, 1.0, 0.88))


func _draw_title_screen() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.21, 0.69, 0.74, 1.0))
	for bubble_index in range(8):
		var bubble_x := 40.0 + float(bubble_index) * 45.0
		var bubble_y := 84.0 + sin(float(bubble_index) * 1.9) * 32.0
		draw_circle(Vector2(bubble_x, bubble_y), 14.0 + float(bubble_index % 3) * 8.0, Color(1.0, 1.0, 1.0, 0.18))

	draw_string(font, Vector2(2.0, 98.0), "Foam Party", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 44, Color("#0d3b55"))
	draw_string(font, Vector2(0.0, 94.0), "Foam Party", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 44, Color.WHITE)
	draw_string(font, Vector2(0.0, 128.0), tr("TITLE_SUBTITLE"), HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 16, Color("#0d3b55"))
	_draw_title_hero_car()
	_draw_title_skin_swatches()

	# 타이틀 데일리 미션 카드 — 시작 전에 오늘 할 일을 보여준다
	if not daily_mission_type.is_empty():
		var dm_rect := Rect2(18.0, 382.0, 354.0, 82.0)
		var dm_claimed := daily_mission_claimed
		var dm_prog := mini(daily_mission_progress, daily_mission_target)
		draw_style_box(_style("title_dm_shadow", Color(0.03, 0.12, 0.22, 0.22), 14.0),
			Rect2(dm_rect.position + Vector2(0.0, 3.0), dm_rect.size))
		var dm_bg_key := "title_dm_bg_done" if dm_claimed else "title_dm_bg_todo"
		var dm_bg_col := Color(0.05, 0.26, 0.18, 0.72) if dm_claimed else Color(0.05, 0.20, 0.32, 0.72)
		draw_style_box(_style(dm_bg_key, dm_bg_col, 14.0), dm_rect)
		draw_string(font, Vector2(dm_rect.position.x + 12.0, dm_rect.position.y + 18.0),
			tr("DM_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.85, 1.0, 0.8))
		draw_string(font, Vector2(dm_rect.position.x, dm_rect.position.y + 18.0),
			tr("DM_REWARD") % daily_mission_reward, HORIZONTAL_ALIGNMENT_RIGHT, dm_rect.size.x - 10.0, 11,
			Color(1.0, 0.85, 0.25, 0.9))
		var mission_col := Color(0.72, 1.0, 0.78) if dm_claimed else Color(0.90, 0.96, 1.0)
		draw_string(font, Vector2(dm_rect.position.x + 12.0, dm_rect.position.y + 40.0),
			_daily_mission_display_label(), HORIZONTAL_ALIGNMENT_LEFT, dm_rect.size.x - 24.0, 14, mission_col)
		var dm_bar_margin := 12.0
		var dm_bar_rect := Rect2(dm_rect.position.x + dm_bar_margin, dm_rect.position.y + 52.0,
			dm_rect.size.x - dm_bar_margin * 2.0, 6.0)
		draw_style_box(_style("title_dm_bar_bg", Color(0.0, 0.0, 0.0, 0.35), 3.0), dm_bar_rect)
		var dm_fill := 1.0 if dm_claimed else float(dm_prog) / float(max(daily_mission_target, 1))
		if dm_fill > 0.0:
			var bar_fill_key := "title_dm_bar_fill_done" if dm_claimed else "title_dm_bar_fill_todo"
			var bar_fill_col := Color("#39d98a") if dm_claimed else Color("#49a7ff")
			var fill_w := maxf(8.0, dm_bar_rect.size.x * dm_fill)
			draw_style_box(_style(bar_fill_key, bar_fill_col, 3.0),
				Rect2(dm_bar_rect.position, Vector2(fill_w, dm_bar_rect.size.y)))
		var count_text := tr("DM_DONE") if dm_claimed else "%d / %d" % [dm_prog, daily_mission_target]
		var count_col := Color("#39d98a") if dm_claimed else Color(0.7, 0.9, 1.0)
		draw_string(font, Vector2(dm_rect.position.x, dm_rect.position.y + 74.0),
			count_text, HORIZONTAL_ALIGNMENT_RIGHT, dm_rect.size.x - 12.0, 12, count_col)

	var start_rect := _get_start_rect()
	draw_style_box(_style("start_shadow", Color("#1f8a55"), 16.0), Rect2(start_rect.position + Vector2(0.0, 5.0), start_rect.size))
	draw_style_box(_style("start_button", Color("#39d98a"), 16.0), start_rect)
	var start_label := tr("START")
	if level_index > 1:
		var progress_car_type: String = GameConfig.car_type_for_level(level_index)
		start_label = tr("CONTINUE") % [car_type_labels[progress_car_type], level_index]
	draw_string(font, Vector2(start_rect.position.x, start_rect.position.y + 38.0), start_label, HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, 19, Color("#0d3b2a"))

	draw_string(font, Vector2(0.0, 578.0), tr("COIN_STAR") % [coins, total_stars], HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 15, Color(1.0, 1.0, 1.0, 0.9))
	var upg_rect := _get_upgrade_btn_rect()
	draw_style_box(_style("upg_shadow", Color(0.18, 0.25, 0.55, 0.9), 12.0), Rect2(upg_rect.position + Vector2(0.0, 4.0), upg_rect.size))
	draw_style_box(_style("upg_btn", Color(0.33, 0.53, 0.95, 1.0), 12.0), upg_rect)
	draw_string(font, Vector2(upg_rect.position.x, upg_rect.position.y + 28.0), tr("BTN_UPGRADE"), HORIZONTAL_ALIGNMENT_CENTER, upg_rect.size.x, 16, Color(1.0, 1.0, 1.0, 0.96))
	var skin_rect := _get_skin_btn_rect()
	draw_style_box(_style("skin_shadow", Color(0.28, 0.12, 0.48, 0.9), 12.0), Rect2(skin_rect.position + Vector2(0.0, 4.0), skin_rect.size))
	draw_style_box(_style("skin_btn", Color(0.58, 0.28, 0.88, 1.0), 12.0), skin_rect)
	draw_string(font, Vector2(skin_rect.position.x, skin_rect.position.y + 28.0), tr("BTN_SKIN"), HORIZONTAL_ALIGNMENT_CENTER, skin_rect.size.x, 16, Color(1.0, 1.0, 1.0, 0.96))
	var stage_rect := _get_stage_btn_rect()
	draw_style_box(_style("stage_shadow", Color(0.09, 0.34, 0.43, 0.9), 12.0), Rect2(stage_rect.position + Vector2(0.0, 4.0), stage_rect.size))
	draw_style_box(_style("stage_btn", Color(0.18, 0.67, 0.74, 1.0), 12.0), stage_rect)
	draw_string(font, Vector2(stage_rect.position.x, stage_rect.position.y + 28.0), tr("BTN_STAGE"), HORIZONTAL_ALIGNMENT_CENTER, stage_rect.size.x, 16, Color(1.0, 1.0, 1.0, 0.96))
	var achievement_rect := _get_achievement_btn_rect()
	draw_style_box(_style("achievement_shadow", Color(0.48, 0.25, 0.02, 0.9), 12.0), Rect2(achievement_rect.position + Vector2(0.0, 4.0), achievement_rect.size))
	draw_style_box(_style("achievement_btn", Color(0.95, 0.58, 0.16, 1.0), 12.0), achievement_rect)
	var achievement_total := AchievementProgress.DEFINITIONS.size()
	var achievement_label := tr("BTN_ACHIEVEMENT") % [_achievement_completed_count(), achievement_total]
	draw_string(font, Vector2(achievement_rect.position.x, achievement_rect.position.y + 28.0), achievement_label, HORIZONTAL_ALIGNMENT_CENTER, achievement_rect.size.x, 15, Color(0.24, 0.12, 0.01, 0.96))
	var version_y := minf(826.0, DESIGN_SIZE.y - _safe_area_design_insets().w - 12.0)
	draw_string(font, Vector2(0.0, version_y), "v0.1", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 12, Color(1.0, 1.0, 1.0, 0.5))


func _today_string() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _generate_daily_mission(today: String) -> void:
	daily_mission_date = today
	var m := DailyMission.mission_for(today)
	daily_mission_type = m["type"]
	daily_mission_target = m["target"]
	daily_mission_requirement = m["requirement"]
	daily_mission_label = m["label"]
	daily_mission_reward = m["reward"]
	daily_mission_progress = 0
	daily_mission_claimed = false


func _claim_daily_mission_reward() -> bool:
	if daily_mission_claimed or daily_mission_target <= 0 or daily_mission_progress < daily_mission_target:
		return false
	daily_mission_claimed = true
	var granted_reward := _grant_daily_mission_coins()
	_emit_analytics(ContentEvents.daily_mission_claim(daily_mission_type, granted_reward))
	_daily_mission_pop_time = float(Time.get_ticks_msec()) / 1000.0
	var daily_err := _save_daily()
	_daily_progress_dirty = daily_err != OK
	var prog_err := _save_progress()
	if prog_err != OK:
		_main_save_dirty = true
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(60)
	return true


func _advance_daily_mission(amount: int = 1) -> bool:
	if daily_mission_claimed or daily_mission_target <= 0 or amount <= 0:
		return false
	var previous_progress := daily_mission_progress
	daily_mission_progress = mini(daily_mission_target, daily_mission_progress + amount)
	if daily_mission_progress == previous_progress:
		return false
	if daily_mission_progress >= daily_mission_target:
		return _claim_daily_mission_reward()
	_daily_progress_dirty = true
	return true


func _record_completion_daily_mission() -> void:
	if daily_mission_claimed:
		return
	if daily_mission_type == "fast" and level_time <= float(daily_mission_requirement):
		_advance_daily_mission()
	elif daily_mission_type == "perfect3" and earned_stars == daily_mission_requirement:
		_advance_daily_mission()


func _grant_daily_mission_coins() -> int:
	coins += daily_mission_reward
	return daily_mission_reward


func _draw_daily_mission() -> void:
	if game_state != STATE_PLAYING or daily_mission_type.is_empty():
		return
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var rect := _get_daily_mission_rect()

	draw_style_box(_style("dm_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0),
		Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("dm_bg", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	var font := _font()
	var claimed := daily_mission_claimed
	var progress := mini(daily_mission_progress, daily_mission_target)

	var bar_rect := _get_daily_mission_bar_rect()
	draw_style_box(_style("dm_bar_bg", Color(0.0, 0.0, 0.0, 0.35), 2.0), bar_rect)
	var fill := 1.0 if claimed else float(progress) / float(max(daily_mission_target, 1))
	if fill > 0.0:
		var fill_col := Color("#39d98a") if claimed else Color("#49a7ff")
		var fill_w := maxf(6.0, bar_rect.size.x * fill)
		draw_style_box(_style("dm_bar_fill", fill_col, 2.0),
			Rect2(bar_rect.position, Vector2(fill_w, bar_rect.size.y)))

	var label_text := _daily_mission_display_label()
	var count_text := tr("DM_DONE") if claimed else "%d/%d" % [progress, daily_mission_target]
	var label_col := Color(0.7, 1.0, 0.75) if claimed else Color(0.85, 0.95, 1.0)
	var count_col := Color("#39d98a") if claimed else Color(0.7, 0.9, 1.0)
	var label_width := rect.size.x - 16.0
	var label_font_size := 11
	while label_font_size > 8 and font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size).x > label_width:
		label_font_size -= 1
	draw_string(font, Vector2(rect.position.x + 8.0, rect.position.y + 18.0),
		label_text, HORIZONTAL_ALIGNMENT_CENTER, label_width, label_font_size, label_col)
	draw_string(font, Vector2(rect.position.x + 8.0, rect.position.y + 40.0),
		count_text, HORIZONTAL_ALIGNMENT_CENTER, label_width, 11, count_col)

	if _daily_mission_pop_time >= 0.0:
		var age := time_now - _daily_mission_pop_time
		if age < 2.8:
			var alpha := clampf(1.0 - (age - 1.6) / 1.2, 0.0, 1.0)
			var rise := age * 26.0
			var pop_text := tr("DM_CLEAR_POP") % daily_mission_reward
			draw_string(font, Vector2(rect.position.x - 30.0, rect.end.y + 18.0 - rise),
				pop_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 30.0, 11, Color(1.0, 0.9, 0.3, alpha))
		else:
			_daily_mission_pop_time = -10.0


func _draw_top_buttons() -> void:
	var font: Font = _font()
	var sound_rect := _get_title_sound_rect()
	var help_rect := _get_title_help_rect()
	for rect in [sound_rect, help_rect]:
		draw_style_box(_style("round_button", Color(0.03, 0.14, 0.2, 0.68), rect.size.x * 0.5), rect)
	var icon_color := Color(0.93, 0.99, 1.0)
	var speaker_center := sound_rect.get_center()
	var icon_scale := sound_rect.size.x / 30.0
	draw_colored_polygon(PackedVector2Array([
		speaker_center + Vector2(-9.0, -3.0) * icon_scale, speaker_center + Vector2(-3.0, -3.0) * icon_scale, speaker_center + Vector2(3.0, -9.0) * icon_scale,
		speaker_center + Vector2(3.0, 9.0) * icon_scale, speaker_center + Vector2(-3.0, 3.0) * icon_scale, speaker_center + Vector2(-9.0, 3.0) * icon_scale,
	]), icon_color)
	if sound_enabled:
		draw_arc(speaker_center + Vector2(4.0, 0.0) * icon_scale, 7.0 * icon_scale, -1.0, 1.0, 8, icon_color, maxf(1.5, 2.0 * icon_scale))
	else:
		draw_line(speaker_center + Vector2(-11.0, -11.0) * icon_scale, speaker_center + Vector2(11.0, 11.0) * icon_scale, Color("#ff6b6b"), maxf(2.0, 3.0 * icon_scale))
	var help_font_size := maxi(15, roundi(20.0 * help_rect.size.x / 30.0))
	# draw_string() receives a baseline, not a glyph center. Derive it from the
	# font metrics so the question mark shares the speaker icon's visual center.
	var help_baseline_y := help_rect.get_center().y + (
		font.get_ascent(help_font_size) - font.get_descent(help_font_size)
	) * 0.5
	draw_string(font, Vector2(help_rect.position.x, help_baseline_y), "?", HORIZONTAL_ALIGNMENT_CENTER, help_rect.size.x, help_font_size, icon_color)


func _draw_pause_entry() -> void:
	var rect := _get_pause_entry_rect()
	draw_style_box(_style("pause_entry_shadow", Color(0.03, 0.14, 0.2, 0.24), 22.0), Rect2(rect.position + Vector2(0.0, 3.0), rect.size))
	draw_style_box(_style("pause_entry", Color(0.03, 0.14, 0.2, 0.76), 22.0), rect)
	var center := rect.get_center()
	var bar_size := Vector2(4.5, 16.0)
	for offset_x in [-5.0, 5.0]:
		draw_rect(Rect2(center + Vector2(offset_x, 0.0) - bar_size * 0.5, bar_size), Color(0.93, 0.99, 1.0))


func _draw_tutorial() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.55))
	var panel: Rect2 = _tutorial_panel_rect()
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 40.0), tr("TUT_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#123246"))
	var close_rect: Rect2 = _tutorial_close_rect()
	draw_style_box(_style("tutorial_close", Color("#e0e9f5"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 25.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 17, Color("#123246"))

	for tab in [TUTORIAL_TAB_TOOLS, TUTORIAL_TAB_DIRT]:
		var tab_rect: Rect2 = _tutorial_tab_rect(tab)
		var selected: bool = tab == _tutorial_tab
		var tab_style_key: String = "tutorial_tab_%d_%s" % [tab, "selected" if selected else "idle"]
		draw_style_box(_style(tab_style_key, Color("#3a9ef0") if selected else Color("#d5e3f1"), 10.0), tab_rect)
		draw_string(font, Vector2(tab_rect.position.x, tab_rect.position.y + 23.0), tr("TUT_TAB_TOOLS") if tab == TUTORIAL_TAB_TOOLS else tr("TUT_TAB_DIRT"), HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x, 14, Color.WHITE if selected else Color("#49677c"))

	if _tutorial_tab == TUTORIAL_TAB_DIRT:
		_draw_wash_guide_rows(panel, font)
	else:
		_draw_tool_guide_rows(panel, font)

	var done_rect: Rect2 = _tutorial_done_rect()
	draw_style_box(_style("tutorial_done", Color("#39d98a"), 12.0), done_rect)
	draw_string(font, Vector2(done_rect.position.x, done_rect.position.y + 27.0), tr("TUT_START"), HORIZONTAL_ALIGNMENT_CENTER, done_rect.size.x, 15, Color("#123246"))


func _draw_tool_guide_rows(panel: Rect2, font: Font) -> void:

	var rows := [
		[TOOL_AIR, tr("TOOL_AIR"), tr("TUT_AIR")],
		[TOOL_WATER, tr("TOOL_WATER"), tr("TUT_WATER")],
		[TOOL_SOAP, tr("TOOL_SOAP"), tr("TUT_SOAP")],
		[TOOL_SPONGE, tr("TOOL_SPONGE"), tr("TUT_SPONGE")],
	]
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var row_y: float = panel.position.y + 154.0 + float(row_index) * 94.0
		draw_style_box(_style("tutorial_tool_row_%d" % row_index, Color("#e8f3f8"), 14.0), Rect2(panel.position.x + 18.0, row_y - 30.0, panel.size.x - 36.0, 72.0))
		_draw_tool_icon(row[0], Vector2(panel.position.x + 55.0, row_y + 5.0))
		draw_string(font, Vector2(panel.position.x + 96.0, row_y - 3.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, 200.0, 17, Color("#123246"))
		draw_string(font, Vector2(panel.position.x + 96.0, row_y + 21.0), row[2], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 120.0, 12, Color("#2c6b78"))

	draw_string(font, Vector2(panel.position.x, panel.position.y + 548.0), tr("TUT_TIP") % [BOMB_COST, WATER_BOOST_COST], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, Color("#2c6b78"))


func _draw_wash_guide_rows(panel: Rect2, font: Font) -> void:
	draw_string(font, Vector2(panel.position.x + 56.0, panel.position.y + 122.0), tr("GUIDE_HEADER_DIRT"), HORIZONTAL_ALIGNMENT_LEFT, 82.0, 11, Color("#6a8294"))
	draw_string(font, Vector2(panel.position.x + 144.0, panel.position.y + 122.0), tr("GUIDE_HEADER_PATH"), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 11, Color("#6a8294"))
	var entries: Array = Coaching.wash_guide_entries()
	for row_index in range(entries.size()):
		var entry: Dictionary = entries[row_index]
		var kind: String = String(entry["kind"])
		var row_rect: Rect2 = _tutorial_dirt_row_rect(row_index)
		draw_style_box(_style("tutorial_dirt_row_%d" % row_index, Color("#e8f3f8") if row_index % 2 == 0 else Color("#edf6fa"), 12.0), row_rect)
		_draw_wash_guide_dirt_icon(kind, Vector2(row_rect.position.x + 24.0, row_rect.position.y + 26.0))
		draw_string(font, Vector2(row_rect.position.x + 45.0, row_rect.position.y + 23.0), tr("GUIDE_DIRT_" + kind.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, 82.0, 12, Color("#123246"))
		var primary_text: String = _localized_tool_list(entry["primary"] as Array)
		var follow_up_text: String = _localized_tool_list(entry["follow_up"] as Array)
		if follow_up_text.is_empty():
			follow_up_text = tr("GUIDE_NONE")
		var path_text: String = "%s  →  %s" % [primary_text, follow_up_text]
		draw_string(font, Vector2(row_rect.position.x + 132.0, row_rect.position.y + 23.0), path_text, HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 142.0, 11, Color("#155879"))
		draw_string(font, Vector2(row_rect.position.x + 45.0, row_rect.position.y + 45.0), tr(String(entry["description_key"])), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 55.0, 10, Color("#49677c"))


func _localized_tool_list(tool_ids_to_join: Array) -> String:
	var labels: PackedStringArray = []
	for tool_id in tool_ids_to_join:
		labels.append(tr("TOOL_" + String(tool_id).to_upper()))
	return "·".join(labels)


func _draw_wash_guide_dirt_icon(kind: String, center: Vector2) -> void:
	draw_circle(center, 17.0, Color("#f8fbfd"))
	match kind:
		"mud":
			_draw_mud_patch(center, 10.0, 1.0, 0.8)
		"dust":
			draw_circle(center, 10.5, Color(0.86, 0.75, 0.52, 0.64))
			for index in range(6):
				var angle: float = float(index) * TAU / 6.0
				draw_circle(center + Vector2.from_angle(angle) * 7.0, 1.8, Color(0.55, 0.43, 0.28, 0.72))
		"leaf":
			_draw_leaf_patch(center, 10.0, 1.0)
		"oil":
			_draw_oil_patch(center, 10.0, 1.0, 0.8)
		"bug":
			_draw_bug_patch(center, 10.0, 1.0, 0.8)
		"poop":
			_draw_poop_patch(center, 10.0, 1.0, 0.8)
		"road_grime":
			_draw_road_grime_patch(center, 10.0, 1.0, 0.8)
		"sap":
			_draw_sap_patch(center, 10.0, 1.0, 0.8)


func _draw_booster_button() -> void:
	if completed:
		return
	var font: Font = _font()
	var rect := _get_booster_rect()
	var t := float(Time.get_ticks_msec()) / 1000.0
	var pop := 1.0 + 0.14 * exp(-(t - _bomb_press_time) * 9.0)
	if pop > 1.001:
		var c := rect.get_center()
		draw_set_transform(c * (1.0 - pop), 0.0, Vector2(pop, pop))
	var active := _water_boost_active()
	var bg := Color("#8fdcff") if active else Color("#f8f4a6")
	draw_style_box(_style("booster_active" if active else "booster_entry", bg, 14.0), rect)
	if active:
		draw_circle(rect.position + Vector2(22.0, 20.0), 10.0, Color("#49a7ff"))
		draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(22.0, 5.0),
			rect.position + Vector2(32.0, 20.0),
			rect.position + Vector2(12.0, 20.0),
		]), Color("#49a7ff"))
	else:
		draw_circle(rect.position + Vector2(20.0, 17.0), 9.0, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(rect.position + Vector2(30.0, 12.0), 6.0, Color(1.0, 1.0, 1.0, 0.8))
		draw_circle(rect.position + Vector2(28.0, 23.0), 5.0, Color("#72c7ff"))
	draw_string(font, Vector2(rect.position.x + 40.0, rect.position.y + 20.0), tr("WATER_BOOST_SHORT") if active else tr("BOOSTER_LABEL"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 42.0, 11, Color("#123246"))
	var sub_text := tr("BOOSTER_ACTIVE") % int(ceil(_water_boost_remaining)) if active else tr("BOOSTER_SELECT")
	draw_string(font, Vector2(rect.position.x + 40.0, rect.position.y + 38.0), sub_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 42.0, 12, Color("#0d516d") if active else Color("#6b5200"))
	if pop > 1.001:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_booster_panel() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.08, 0.14, 0.68))
	var panel := _booster_panel_rect()
	draw_style_box(_style("booster_panel_shadow", Color(0.03, 0.13, 0.19, 0.45), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("booster_panel", Color("#f7fbff"), 22.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 42.0), tr("BOOSTER_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#123246"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 66.0), tr("COINS_LABEL") % coins, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#3a7fc1"))
	var close_rect := _booster_close_rect(panel)
	draw_style_box(_style("booster_close", Color("#e0e9f5"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#123246"))

	var foam_card := _booster_card_rect(panel, 0)
	var foam_ad_ready := _free_ad_bomb_available()
	var foam_available := foam_ad_ready or coins >= BOMB_COST
	draw_style_box(_style("booster_foam_on" if foam_available else "booster_foam_off", Color("#e9fbf2") if foam_available else Color("#e4e8eb"), 15.0), foam_card)
	draw_circle(foam_card.position + Vector2(34.0, 42.0), 16.0, Color(1.0, 1.0, 1.0, 0.96))
	draw_circle(foam_card.position + Vector2(48.0, 31.0), 10.0, Color(1.0, 0.96, 0.76, 0.9))
	draw_circle(foam_card.position + Vector2(49.0, 50.0), 8.0, Color("#b7f0ff"))
	draw_string(font, Vector2(foam_card.position.x + 70.0, foam_card.position.y + 29.0), tr("BOOSTER_FOAM"), HORIZONTAL_ALIGNMENT_LEFT, 136.0, 17, Color("#123246"))
	draw_string(font, Vector2(foam_card.position.x + 70.0, foam_card.position.y + 51.0), tr("BOOSTER_FOAM_DESC"), HORIZONTAL_ALIGNMENT_LEFT, 140.0, 11, Color("#2c6b78"))
	var foam_action := Rect2(foam_card.end.x - 78.0, foam_card.position.y + 24.0, 66.0, 40.0)
	draw_style_box(_style("booster_foam_action_on" if foam_available else "booster_foam_action_off", Color("#39d98a") if foam_available else Color("#aeb9bf"), 11.0), foam_action)
	draw_string(font, Vector2(foam_action.position.x, foam_action.position.y + 26.0), tr("BOMB_FREE") if foam_ad_ready else tr("COST_COIN") % BOMB_COST, HORIZONTAL_ALIGNMENT_CENTER, foam_action.size.x, 12, Color("#123246"))
	_draw_unaffordable_lock(foam_card, foam_available, Color("#40515a"))

	var water_card := _booster_card_rect(panel, 1)
	var water_active := _water_boost_active()
	var water_available := water_active or coins >= WATER_BOOST_COST
	draw_style_box(_style("booster_water_active" if water_active else ("booster_water_on" if water_available else "booster_water_off"), Color("#d9f3ff") if water_available else Color("#e4e8eb"), 15.0), water_card)
	_draw_tool_icon(TOOL_WATER, water_card.position + Vector2(40.0, 42.0))
	draw_string(font, Vector2(water_card.position.x + 70.0, water_card.position.y + 29.0), tr("BOOSTER_WATER"), HORIZONTAL_ALIGNMENT_LEFT, 136.0, 17, Color("#123246"))
	draw_string(font, Vector2(water_card.position.x + 70.0, water_card.position.y + 51.0), tr("BOOSTER_WATER_DESC") % int(WATER_BOOST_DURATION), HORIZONTAL_ALIGNMENT_LEFT, 140.0, 11, Color("#2c6b78"))
	var water_action := Rect2(water_card.end.x - 78.0, water_card.position.y + 24.0, 66.0, 40.0)
	draw_style_box(_style("booster_water_action_active" if water_active else ("booster_water_action_on" if water_available else "booster_water_action_off"), Color("#49a7ff") if water_available else Color("#aeb9bf"), 11.0), water_action)
	var water_action_text := tr("BOOSTER_ACTIVE") % int(ceil(_water_boost_remaining)) if water_active else tr("COST_COIN") % WATER_BOOST_COST
	draw_string(font, Vector2(water_action.position.x, water_action.position.y + 26.0), water_action_text, HORIZONTAL_ALIGNMENT_CENTER, water_action.size.x, 12, Color("#123246"))
	_draw_unaffordable_lock(water_card, water_available, Color("#40515a"))


func _draw_unaffordable_lock(rect: Rect2, available: bool, color: Color) -> void:
	if available:
		return
	var center := Vector2(rect.end.x - 10.0, rect.get_center().y + 4.0)
	draw_arc(center + Vector2(0.0, -5.0), 4.0, PI, TAU, 12, color, 1.8)
	draw_rect(Rect2(center + Vector2(-5.0, -3.0), Vector2(10.0, 9.0)), color)
	draw_circle(center + Vector2(0.0, 1.0), 1.2, Color(1.0, 1.0, 1.0, 0.75))


# Live "what grade am I earning right now" tracker. Surfaces the otherwise
# invisible star criteria (clear speed + the combo gate) so the player has a
# clear in-the-moment goal and feels the pressure to keep their stars.
func _draw_grade_tracker() -> void:
	if completed:
		return
	var font: Font = _font()
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var rect := _get_grade_rect()
	draw_style_box(_style("grade_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0), Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("grade_chip", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	var time_left := _grade_time_to_downgrade()
	var at_risk := _grade_at_risk_slot()
	var combo_requirement := _star3_combo_requirement()
	var warning: bool = time_left >= 0.0 and time_left <= STAR_WARN_SECONDS

	var star_y := rect.position.y + 20.0
	var risk_beat: float = 0.5 + 0.5 * sin(time_now * 12.0)
	for slot in range(3):
		var center := Vector2(rect.position.x + 20.0 + float(slot) * 32.0, star_y)
		var state := _grade_slot_state(slot)
		# A star about to be lost pulses a red ring whether it is already earned
		# or still a reachable target, so the urgency reads the same either way.
		var at_risk_here: bool = warning and slot == at_risk
		if at_risk_here:
			draw_arc(center, 11.0, 0.0, TAU, 20, Color(1.0, 0.42, 0.36, 0.35 + 0.45 * risk_beat), 2.5)
		if state == GRADE_SLOT_EARNED:
			var scale: float = 1.0 + (0.16 * risk_beat if at_risk_here else 0.0)
			_draw_star(center, 8.5 * scale, Color("#ffce3d"), Color("#e0a818"))
		elif state == GRADE_SLOT_TARGET:
			var tp: float = 0.5 + 0.5 * sin(time_now * 5.0)
			var ts: float = 1.0 + (0.12 * risk_beat if at_risk_here else 0.0)
			_draw_star(center, 8.5 * ts, Color(1.0, 0.81, 0.24, 0.14 + 0.12 * tp), Color(1.0, 0.81, 0.24, 0.5 + 0.4 * tp))
		else:
			_draw_star(center, 8.0, Color(0.42, 0.5, 0.55, 0.85), Color(0.3, 0.37, 0.42, 0.9))

	var line_y := rect.position.y + rect.size.y - 9.0
	var text := ""
	var col := Color(0.86, 0.93, 0.97)
	if warning:
		var blink: float = 0.55 + 0.45 * sin(time_now * 10.0)
		var secs := int(ceil(time_left))
		if _grade_slot_state(at_risk) == GRADE_SLOT_TARGET:
			# Star is reachable but not yet earned: keep nudging the combo gate
			# so the player races the clock and the combo.
			text = tr("GRADE_COMBO_URGENT") % [combo_requirement, secs]
		else:
			text = tr("GRADE_KEEP_STAR") % [at_risk + 1, secs]
		col = Color(1.0, 0.74, 0.36)
		col.a = blink
	elif _grade_slot_state(2) == GRADE_SLOT_TARGET:
		text = _grade_combo_prompt()
		col = Color(1.0, 0.88, 0.55)
	else:
		text = tr("GRADE_TIME") % _format_time(level_time)
	_last_grade_tracker_text = text
	var text_font_size := 11
	while text_font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_font_size).x > rect.size.x - 8.0:
		text_font_size -= 1
	draw_string(font, Vector2(rect.position.x + 4.0, line_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, text_font_size, col)


func _current_customer_patience() -> float:
	return CustomerPatience.value(level_time, clean_progress)


func _draw_customer_patience() -> void:
	if completed:
		return
	# 손님 인내 게이지: 경과 시간 압력을 세차 진행도가 일부 완화한다.
	# 별점과 일일 미션 사이의 같은 높이 요약 카드에 배치한다.
	var patience := _current_customer_patience()
	var patience_zone := CustomerPatience.zone(patience)
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var rect := _get_customer_rect()

	draw_style_box(_style("cust_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0),
		Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("cust_chip", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	# 손님 얼굴 (카드 왼쪽)
	var face := Vector2(rect.position.x + 21.0, rect.position.y + 23.0)
	var fr := 14.0
	var customer_profile := _customer_profile()
	var face_col := Color(String(customer_profile["face_hex"])).lerp(Color("#f2857f"), (1.0 - patience) * 0.42)
	draw_circle(face, fr, face_col)
	draw_arc(face, fr, 0.0, TAU, 28, Color(0.0, 0.0, 0.0, 0.18), 1.5)
	_draw_customer_accessory(face, fr, customer_profile)

	# 눈
	draw_circle(Vector2(face.x - 5.0, face.y - 4.5), 2.0, Color(0.08, 0.06, 0.04))
	draw_circle(Vector2(face.x + 5.0, face.y - 4.5), 2.0, Color(0.08, 0.06, 0.04))

	# 눈썹 (찡그림 구간인 patience <= 0.2에서만 인상을 찌푸림)
	# anger: 0.2에서 0으로 시작해 0에서 1로 증가 → 경계에서 불연속 없음
	if patience <= 0.2:
		var anger := clampf((0.2 - patience) / 0.2, 0.0, 1.0)
		var tilt := anger * 2.8
		draw_line(Vector2(face.x - 9.0, face.y - 10.0 - tilt), Vector2(face.x - 3.0, face.y - 9.5 + tilt),
			Color(0.08, 0.06, 0.04, 0.9), 1.5)
		draw_line(Vector2(face.x + 3.0, face.y - 9.5 + tilt), Vector2(face.x + 9.0, face.y - 10.0 - tilt),
			Color(0.08, 0.06, 0.04, 0.9), 1.5)

	# 입 (미소 / 무표정 / 찡그림)
	if patience > 0.5:
		# 미소: 아래로 볼록한 호 (Godot Y-down: 0.4→PI-0.4 clockwise = 아래를 지나는 호)
		draw_arc(Vector2(face.x, face.y + 3.0), 6.0, 0.4, PI - 0.4, 12, Color(0.08, 0.06, 0.04), 2.0)
	elif patience > 0.2:
		# 무표정: 수평선
		draw_line(Vector2(face.x - 5.5, face.y + 7.0), Vector2(face.x + 5.5, face.y + 7.0),
			Color(0.08, 0.06, 0.04), 2.0)
	else:
		# 찡그림: 위로 볼록한 호 (PI+0.4→TAU-0.4 clockwise = 위를 지나는 호)
		draw_arc(Vector2(face.x, face.y + 9.5), 6.0, PI + 0.4, TAU - 0.4, 12, Color(0.08, 0.06, 0.04), 2.0)

	# 인내 게이지 바 (카드 오른쪽)
	var bar := Rect2(rect.position.x + 43.0, rect.position.y + 14.0, 53.0, 10.0)
	draw_style_box(_style("cust_bar_bg", Color(0.15, 0.28, 0.38, 0.55), 5.0), bar)
	if patience > 0.0:
		var bar_key: String
		var bar_col: Color
		if patience_zone == 3:
			bar_key = "cust_bar_g"
			bar_col = Color(0.22, 0.87, 0.55)
		elif patience_zone == 2:
			bar_key = "cust_bar_y"
			bar_col = Color(0.97, 0.82, 0.22)
		else:
			bar_key = "cust_bar_r"
			bar_col = Color(1.0, 0.40, 0.28)
		var fill_rect := Rect2(bar.position, Vector2(bar.size.x * patience, bar.size.y))
		draw_style_box(_style(bar_key, bar_col, 5.0), fill_rect)
		_draw_patience_tier_pattern(bar, fill_rect, patience_zone)
	else:
		_draw_patience_tier_pattern(bar, Rect2(bar.position, Vector2.ZERO), patience_zone)

	# 기분 레이블
	var font: Font = _font()
	var mood_label: String
	var mood_col := Color(0.86, 0.93, 0.97)
	if patience_zone == 3:
		mood_label = tr("MOOD_HAPPY")
	elif patience_zone == 2:
		mood_label = tr("MOOD_OK")
	elif patience_zone == 1:
		mood_label = tr("MOOD_HURRY")
	else:
		var blink := 0.55 + 0.45 * sin(time_now * 8.0)
		mood_label = tr("MOOD_ANGRY")
		mood_col = Color(1.0, 0.62, 0.40, blink)
	draw_string(font, Vector2(rect.position.x + 40.0, rect.position.y + rect.size.y - 8.0),
		mood_label, HORIZONTAL_ALIGNMENT_CENTER, 61.0, 11, mood_col)

	# 콤보 리액션 말풍선: 콤보 마일스톤 달성 직후 2.2초간 표시 후 페이드.
	var cheer_age := time_now - _customer_cheer_time
	if cheer_age < 2.2 and _customer_cheer_text != "":
		var cheer_alpha := clampf(1.0 - (cheer_age - 1.4) / 0.8, 0.0, 1.0)
		var bubble := Rect2(rect.position.x, rect.position.y - 38.0, rect.size.x, 28.0)
		draw_style_box(_style("cheer_bubble", Color(1.0, 0.97, 0.82, 0.92 * cheer_alpha), 10.0), bubble)
		# 말풍선 꼬리: 손님 얼굴 중심 방향을 가리키는 삼각형
		var face_x := face.x
		var tail_y := bubble.position.y + bubble.size.y
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(face_x - 6.0, tail_y),
				Vector2(face_x + 6.0, tail_y),
				Vector2(face_x, tail_y + 8.0),
			]),
			Color(1.0, 0.97, 0.82, 0.92 * cheer_alpha))
		draw_string(font, Vector2(bubble.position.x, bubble.position.y + 20.0),
			_customer_cheer_text, HORIZONTAL_ALIGNMENT_CENTER, bubble.size.x, 14,
			Color(0.35, 0.18, 0.02, cheer_alpha))


func _patience_pattern_for_zone(patience_zone: int) -> String:
	if patience_zone == 3:
		return "dots"
	if patience_zone == 2:
		return "ticks"
	if patience_zone == 1:
		return "crosses"
	return "alert"


func _draw_patience_tier_pattern(bar: Rect2, fill_rect: Rect2, patience_zone: int) -> void:
	var pattern := _patience_pattern_for_zone(patience_zone)
	var ink := Color(0.04, 0.12, 0.16, 0.58)
	if pattern == "alert":
		var alert_center := bar.get_center()
		draw_line(alert_center + Vector2(0.0, -3.0), alert_center + Vector2(0.0, 1.0), ink, 2.0)
		draw_circle(alert_center + Vector2(0.0, 3.5), 1.2, ink)
		return
	if fill_rect.size.x < 4.0:
		return
	if pattern == "dots":
		var dot_x := fill_rect.position.x + 5.0
		while dot_x < fill_rect.end.x - 2.0:
			draw_circle(Vector2(dot_x, fill_rect.get_center().y), 1.3, ink)
			dot_x += 9.0
	elif pattern == "ticks":
		var tick_x := fill_rect.position.x + 4.0
		while tick_x < fill_rect.end.x - 1.0:
			draw_line(Vector2(tick_x, fill_rect.position.y + 2.0), Vector2(tick_x, fill_rect.end.y - 2.0), ink, 1.2)
			tick_x += 6.0
	else:
		var cross_x := fill_rect.position.x + 4.0
		while cross_x < fill_rect.end.x:
			draw_line(Vector2(cross_x - 2.0, fill_rect.position.y + 2.0), Vector2(cross_x + 2.0, fill_rect.end.y - 2.0), ink, 1.2)
			draw_line(Vector2(cross_x + 2.0, fill_rect.position.y + 2.0), Vector2(cross_x - 2.0, fill_rect.end.y - 2.0), ink, 1.2)
			cross_x += 7.0


func _customer_profile() -> Dictionary:
	return CustomerPresentation.profile_for(car_type, active_level_index)


func _draw_customer_accessory(center: Vector2, radius: float, profile: Dictionary) -> void:
	var hair := Color(String(profile["hair_hex"]))
	var accent := Color(String(profile["accent_hex"]))
	var scale := radius / 14.0
	draw_arc(center, radius - 1.0 * scale, PI + 0.12, TAU - 0.12, 18, hair, 3.0 * scale, true)
	match String(profile["accessory"]):
		"cap":
			var crown := PackedVector2Array([
				center + Vector2(-9.0, -11.5) * scale,
				center + Vector2(-5.0, -17.0) * scale,
				center + Vector2(7.0, -16.0) * scale,
				center + Vector2(10.0, -10.0) * scale,
			])
			draw_colored_polygon(crown, accent)
			draw_line(center + Vector2(-10.0, -10.0) * scale, center + Vector2(13.0, -8.5) * scale, accent.darkened(0.18), 2.5 * scale, true)
		"glasses":
			for side in [-1.0, 1.0]:
				draw_arc(center + Vector2(side * 5.0, -4.5) * scale, 4.1 * scale, 0.0, TAU, 16, accent.darkened(0.25), 1.4 * scale, true)
			draw_line(center + Vector2(-1.0, -4.5) * scale, center + Vector2(1.0, -4.5) * scale, accent.darkened(0.25), 1.4 * scale, true)
		"headband":
			draw_arc(center, radius - 2.0 * scale, PI + 0.15, TAU - 0.15, 18, accent, 3.2 * scale, true)


func _draw_combo_badge() -> void:
	if completed or combo_count < 2:
		return
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	# Pop amplitude grows with the combo so a longer streak punches harder.
	var pop_amp: float = 0.35 + 0.05 * float(min(combo_count - 2, 8))
	var pop: float = 1.0 + pop_amp * exp(-(time_now - combo_pop_time) * 6.0)
	var badge_size := Vector2(118.0, 36.0) * pop
	var badge_center_y := _combo_badge_center_y()
	var badge := Rect2(Vector2(195.0, badge_center_y) - badge_size * 0.5, badge_size)
	var is_hot := combo_count >= _star3_combo_requirement()
	var style_key := "combo_hot" if is_hot else "combo_cool"
	var bg := Color("#ffce3d") if is_hot else Color(0.97, 0.99, 1.0, 0.95)
	# Hot streaks gain a soft pulsing halo so momentum is unmistakable.
	if is_hot:
		var halo: float = 0.18 + 0.12 * sin(_halo_phase)
		var halo_size := badge_size + Vector2(18.0, 18.0)
		var halo_rect := Rect2(Vector2(195.0, badge_center_y) - halo_size * 0.5, halo_size)
		draw_style_box(_style("combo_halo", Color(1.0, 0.78, 0.22, halo), 24.0), halo_rect)
	draw_style_box(_style(style_key, bg, 18.0), badge)
	draw_string(_font(), Vector2(badge.position.x, badge.position.y + badge_size.y * 0.5 + 6.0), tr("COMBO_BADGE") % combo_count, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, int(16.0 * pop), Color("#7a5500") if is_hot else Color("#123246"))
	_draw_combo_protection_marker(badge, pop, time_now)
	if _combo_bonus_time >= 0.0:
		var _age := float(Time.get_ticks_msec()) / 1000.0 - _combo_bonus_time
		if _age < 1.2:
			var _alpha := 1.0 - _age / 1.2
			var _rise := _age * 38.0
			draw_string(_font(), Vector2(badge.position.x + 4.0, badge.position.y - _rise - 14.0),
				tr("COIN_GAIN") % _combo_bonus_amount, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 16, Color(1.0, 0.85, 0.2, _alpha))
	# Circular timer ring — sweeps clockwise from top as the combo window drains.
	var active_window := COMBO_GRACE if combo_grace_active else COMBO_WINDOW
	var fill_frac := clampf(combo_timer / maxf(active_window, 0.001), 0.0, 1.0)
	var is_urgent := fill_frac > 0.0 and fill_frac <= 0.35
	var ring_alpha := clampf(fill_frac / 0.3, 0.65 if is_urgent else 0.0, 1.0)
	var ring_r := maxf(badge_size.x, badge_size.y) * 0.5 + 8.0
	var ring_center := Vector2(badge.position.x + badge_size.x * 0.5, badge.position.y + badge_size.y * 0.5)
	var ring_col: Color
	if is_urgent:
		ring_col = Color(1.0, 0.35, 0.2, ring_alpha)
	elif is_hot:
		ring_col = Color(1.0, 0.87, 0.25, ring_alpha)
	else:
		ring_col = Color(0.49, 0.89, 0.82, ring_alpha)
	if fill_frac > 0.0:
		var ring_points := clampi(int(ring_r * TAU), 32, 128)
		draw_arc(ring_center, ring_r, -PI * 0.5, -PI * 0.5 + TAU, ring_points, Color(0.0, 0.0, 0.0, 0.22 * ring_alpha), 5.0, true)
		draw_arc(ring_center, ring_r, -PI * 0.5, -PI * 0.5 + TAU * fill_frac, ring_points, ring_col, 3.5, true)


func _draw_combo_protection_marker(badge: Rect2, pop: float, time_now: float) -> void:
	var center := Vector2(badge.end.x - 14.0 * pop, badge.get_center().y)
	var radius := 5.0 * pop
	if combo_protection_available:
		draw_circle(center, radius + 2.0 * pop, Color(0.08, 0.24, 0.32, 0.32))
		draw_circle(center, radius, Color("#65e6d1"))
		draw_circle(center - Vector2(1.4, 1.4) * pop, 1.6 * pop, Color(1.0, 1.0, 1.0, 0.9))
		return
	var flash_age := time_now - _combo_grace_flash_time
	if combo_grace_active or (flash_age >= 0.0 and flash_age < 0.55):
		var pulse := 1.0 + 0.22 * sin(time_now * 18.0)
		var alpha := 1.0 if combo_grace_active else clampf(1.0 - flash_age / 0.55, 0.0, 1.0)
		draw_arc(center, (radius + 2.0 * pop) * pulse, 0.0, TAU, 24, Color(0.4, 0.93, 1.0, alpha), 2.2 * pop, true)


func _draw_gold_spot_reward_pop() -> void:
	if _gold_spot_pop_time < 0.0 or _gold_spot_pop_amount <= 0:
		return
	var age := float(Time.get_ticks_msec()) / 1000.0 - _gold_spot_pop_time
	if age >= 1.5:
		_gold_spot_pop_time = -10.0
		return
	var alpha := clampf(1.0 - maxf(age - 0.8, 0.0) / 0.7, 0.0, 1.0)
	var pop_scale := 1.0 + exp(-age * 8.0) * 0.32
	var center := _gold_spot_pop_position + Vector2(0.0, -34.0 - age * 34.0)
	var chip := Rect2(center - Vector2(35.0, 15.0) * pop_scale, Vector2(70.0, 30.0) * pop_scale)
	if _gold_spot_pop_box == null:
		_gold_spot_pop_box = StyleBoxFlat.new()
		_gold_spot_pop_box.set_corner_radius_all(15)
	_gold_spot_pop_box.bg_color = Color(0.13, 0.09, 0.02, 0.86 * alpha)
	draw_style_box(_gold_spot_pop_box, chip)
	var coin_center := Vector2(chip.position.x + 16.0 * pop_scale, chip.get_center().y)
	draw_circle(coin_center, 8.5 * pop_scale, Color(1.0, 0.82, 0.18, alpha))
	draw_arc(coin_center, 8.5 * pop_scale, 0.0, TAU, 20, Color(0.45, 0.29, 0.02, alpha), 1.5)
	draw_string(_font(), Vector2(chip.position.x + 28.0 * pop_scale, chip.get_center().y + 6.0 * pop_scale), "+%d" % _gold_spot_pop_amount, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 30.0 * pop_scale, int(16.0 * pop_scale), Color(1.0, 0.94, 0.55, alpha))


func _trigger_combo_milestone_flash(count: int) -> void:
	# ×4 콤보: 노란색 플래시 / ×6: 주황색 / ×8: 빨간색 / ×10+: 레인보우(보라)
	if count == 4:
		_combo_milestone_flash_color = Color(1.0, 0.92, 0.22, 0.0)
		_combo_milestone_fanfare = tr("COMBO_FAN_4")
	elif count == 6:
		_combo_milestone_flash_color = Color(1.0, 0.58, 0.12, 0.0)
		_combo_milestone_fanfare = tr("COMBO_FAN_6")
	elif count == 8:
		_combo_milestone_flash_color = Color(1.0, 0.22, 0.22, 0.0)
		_combo_milestone_fanfare = tr("COMBO_FAN_8")
	elif count >= 10 and count % 5 == 0:
		_combo_milestone_flash_color = Color(0.72, 0.22, 1.0, 0.0)
		_combo_milestone_fanfare = tr("COMBO_FAN_MAX") % count
	else:
		return
	_combo_milestone_count = count
	_combo_milestone_flash_time = float(Time.get_ticks_msec()) / 1000.0


func _draw_combo_milestone_flash() -> void:
	if _combo_milestone_flash_time < 0.0:
		return
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var age := time_now - _combo_milestone_flash_time
	const FLASH_DUR := 0.55
	const TEXT_DUR := 1.1
	if age > TEXT_DUR:
		_combo_milestone_flash_time = -10.0
		return

	# 화면 플래시 오버레이: 빠르게 점등 후 서서히 소멸
	if age < FLASH_DUR:
		var flash_alpha: float
		if age < 0.06:
			flash_alpha = age / 0.06
		else:
			flash_alpha = 1.0 - (age - 0.06) / (FLASH_DUR - 0.06)
		flash_alpha *= 0.38
		var fc := Color(_combo_milestone_flash_color.r, _combo_milestone_flash_color.g, _combo_milestone_flash_color.b, flash_alpha)
		draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), fc)

	# ×8 이상: 화면 가장자리 glow 테두리
	var _milestone_count := _combo_milestone_count
	if _milestone_count >= 8:
		var edge_alpha := maxf(0.0, 1.0 - age / TEXT_DUR)
		edge_alpha *= 0.55
		var ec := Color(_combo_milestone_flash_color.r, _combo_milestone_flash_color.g, _combo_milestone_flash_color.b, edge_alpha)
		const EDGE := 22.0
		draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE.x, EDGE), ec)
		draw_rect(Rect2(0.0, DESIGN_SIZE.y - EDGE, DESIGN_SIZE.x, EDGE), ec)
		draw_rect(Rect2(0.0, 0.0, EDGE, DESIGN_SIZE.y), ec)
		draw_rect(Rect2(DESIGN_SIZE.x - EDGE, 0.0, EDGE, DESIGN_SIZE.y), ec)

	# 팡파르 텍스트: 중앙에 크게 등장 후 위로 부드럽게 퇴장
	if age < TEXT_DUR:
		var t_alpha := 1.0 - (age / TEXT_DUR)
		t_alpha = t_alpha * t_alpha
		var rise := age * 52.0
		# 콤보 수에 따라 글자 크기 단계적 증가
		var font_size: int
		if _combo_milestone_count >= 10:
			font_size = 34
		elif _combo_milestone_count >= 8:
			font_size = 30
		elif _combo_milestone_count >= 6:
			font_size = 26
		else:
			font_size = 22
		# 팡파르 텍스트 팝: 0→peak scale(0.12s) 후 정착
		var pop_scale: float
		if age < 0.12:
			pop_scale = 1.0 + 0.4 * (1.0 - age / 0.12) * (1.0 - age / 0.12)
		else:
			pop_scale = 1.0
		var draw_size := int(float(font_size) * pop_scale)
		var tc := Color(_combo_milestone_flash_color.r, _combo_milestone_flash_color.g, _combo_milestone_flash_color.b, t_alpha)
		var center_y := DESIGN_SIZE.y * 0.42 - rise
		# 그림자 (카툰 윤곽선 느낌)
		var shadow_col := Color(0.0, 0.0, 0.0, t_alpha * 0.55)
		draw_string(_font(), Vector2(4.0, center_y + float(draw_size) * 0.5 + 2.0), _combo_milestone_fanfare, HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x + 8.0, draw_size, shadow_col)
		draw_string(_font(), Vector2(0.0, center_y + float(draw_size) * 0.5), _combo_milestone_fanfare, HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, draw_size, tc)


func _draw_toolbar() -> void:
	var font: Font = _font()
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var hint_tool := _active_hint_tool()
	var toolbar_y := _toolbar_y()
	draw_style_box(_style("toolbar", Color(0.04, 0.16, 0.22, 0.96), 24.0), Rect2(-24.0, toolbar_y, DESIGN_SIZE.x + 48.0, DESIGN_SIZE.y - toolbar_y + 24.0))
	for index in range(tool_ids.size()):
		var tool_id: String = tool_ids[index]
		var rect := _get_tool_rect(index)
		var color: Color = tool_colors[tool_id]
		var is_selected := selected_tool == tool_id
		if _tool_misapplied_time > 0.0 and tool_id == _tool_misapplied_tool_id:
			var age := time_now - _tool_misapplied_time
			if age < 0.5:
				rect.position.x += sin(age * 55.0) * 5.0 * (1.0 - age / 0.5)
		var visual_rect := rect
		if is_selected:
			visual_rect = Rect2(rect.position - Vector2(0.0, 8.0), rect.size + Vector2(0.0, 8.0))
			var pop: float = 1.0 + 0.15 * exp(-(time_now - _tool_select_time) * 9.0)
			if pop > 1.001:
				var center := visual_rect.get_center()
				visual_rect = Rect2(center - visual_rect.size * pop * 0.5, visual_rect.size * pop)
			draw_style_box(_style("tool_glow_" + tool_id, Color(color.r, color.g, color.b, 0.35), 18.0), visual_rect.grow(4.0))
			draw_style_box(_style("tool_selected", Color("#f7fbff"), 16.0), visual_rect)
			draw_style_box(_style("tool_selected_border_" + tool_id, Color(0.0, 0.0, 0.0, 0.0), 16.0, color, 3), visual_rect)
		else:
			# Pulse the coached tool's button so "use this!" leads straight here.
			if tool_id == hint_tool:
				if _tool_hint_box == null:
					_tool_hint_box = StyleBoxFlat.new()
					_tool_hint_box.set_corner_radius_all(16)
					_tool_hint_box.set_border_width_all(3)
				var pulse: float = 0.5 + 0.5 * sin(time_now * 6.0)
				_tool_hint_box.bg_color = Color(color.r, color.g, color.b, 0.16 + 0.14 * pulse)
				_tool_hint_box.border_color = Color(color.r, color.g, color.b, 0.55 + 0.45 * pulse)
				draw_style_box(_tool_hint_box, visual_rect.grow(4.0))
			draw_style_box(_style("tool_idle", Color("#16384a"), 16.0), visual_rect)
		_draw_tool_icon(tool_id, visual_rect.position + Vector2(visual_rect.size.x * 0.5, 30.0))
		draw_string(font, visual_rect.position + Vector2(0.0, visual_rect.size.y - 9.0), tool_labels[tool_id], HORIZONTAL_ALIGNMENT_CENTER, visual_rect.size.x, 14, Color("#123246") if is_selected else Color(0.85, 0.93, 0.97))


const _TOOL_ICON_TEX := {
	TOOL_AIR: "tool_air",
	TOOL_WATER: "tool_water",
	TOOL_SOAP: "tool_soap",
	TOOL_SPONGE: "tool_sponge",
}


func _draw_tool_icon(tool_id: String, center: Vector2) -> void:
	# Prefer the flat-vector art asset; fall back to the procedural glyph if the
	# texture is missing (e.g. not yet imported on a headless build).
	var tex_name: String = _TOOL_ICON_TEX.get(tool_id, "")
	if tex_name != "" and _draw_tex_centered(tex_name, center + Vector2(0.0, 2.0), 46.0):
		return
	if tool_id == TOOL_AIR:
		for index in range(3):
			var y := -10.0 + float(index) * 10.0
			var sweep := 22.0 - absf(float(index) - 1.0) * 5.0
			draw_line(center + Vector2(-sweep, y), center + Vector2(sweep, y), Color("#b7f0ff"), 3.5)
			draw_circle(center + Vector2(sweep, y), 2.4, Color("#d9f8ff"))
		draw_arc(center + Vector2(-14.0, 0.0), 10.0, PI * 0.5, PI * 1.5, 12, Color("#d9f8ff"), 3.0)
	elif tool_id == TOOL_WATER:
		draw_circle(center + Vector2(0.0, 6.0), 12.0, Color("#49a7ff"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -17.0), center + Vector2(12.0, 5.0), center + Vector2(-12.0, 5.0)]), Color("#49a7ff"))
		draw_circle(center + Vector2(-4.0, 4.0), 3.5, Color(1.0, 1.0, 1.0, 0.7))
	elif tool_id == TOOL_SOAP:
		draw_circle(center + Vector2(-8.0, 4.0), 10.0, Color(1.0, 1.0, 1.0, 0.5))
		draw_arc(center + Vector2(-8.0, 4.0), 10.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.9), 1.8)
		draw_circle(center + Vector2(8.0, -5.0), 12.0, Color(0.97, 0.95, 0.75, 0.5))
		draw_arc(center + Vector2(8.0, -5.0), 12.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.9), 1.8)
		draw_circle(center + Vector2(4.0, -9.0), 3.0, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(center + Vector2(-11.0, 0.0), 2.4, Color(1.0, 1.0, 1.0, 0.95))
	elif tool_id == TOOL_SPONGE:
		draw_style_box(_style("icon_sponge_base", Color("#ff9f5a"), 6.0), Rect2(center - Vector2(18.0, 6.0), Vector2(36.0, 18.0)))
		draw_style_box(_style("icon_sponge_cap", Color("#ffd54f"), 6.0), Rect2(center - Vector2(18.0, 14.0), Vector2(36.0, 10.0)))
		draw_circle(center + Vector2(-12.0, 13.0), 4.0, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(center + Vector2(0.0, 15.0), 5.0, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(center + Vector2(12.0, 13.0), 4.0, Color(1.0, 1.0, 1.0, 0.9))


func _pause_title_text() -> String:
	return tr("PAUSE_TITLE")


func _pause_action_labels() -> Array[String]:
	return [tr("RESUME"), tr("PAUSE_RESTART"), tr("SOUND_ON") if sound_enabled else tr("SOUND_OFF"), tr("GUIDE"), tr("HOME"), tr("QUIT")]


func _pause_language_labels() -> Array[String]:
	return [tr("LANGUAGE_KO"), tr("LANGUAGE_EN")]


func _draw_pause_menu() -> void:
	if not show_pause:
		return
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.5))
	var panel := _pause_panel()
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 46.0), _pause_title_text(), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#123246"))
	var labels := _pause_action_labels()
	var fills := [Color("#39d98a"), Color("#7fd6e6"), Color("#a9d7ff"), Color("#a9d7ff"), Color("#f8d97a"), Color("#f2a0a0")]
	var text_cols := [Color("#0d3b2a"), Color("#0d3b55"), Color("#123246"), Color("#123246"), Color("#5b4a10"), Color("#5a1616")]
	for i in range(labels.size()):
		var r := _pause_button_rect(i)
		draw_style_box(_style("pause_sh_%d" % i, Color(0.0, 0.0, 0.0, 0.18), 14.0), Rect2(r.position + Vector2(0.0, 4.0), r.size))
		draw_style_box(_style("pause_btn_%d" % i, fills[i], 14.0), r)
		draw_string(font, Vector2(r.position.x, r.position.y + 33.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, text_cols[i])

	var language_labels := _pause_language_labels()
	var active_locale := _active_locale()
	for index in range(2):
		var locale := "ko" if index == 0 else "en"
		var option_rect := _pause_language_option_rect(locale)
		var selected := locale == active_locale
		var fill := Color("#d7f8e5") if selected else Color("#e5eef5")
		var visual_state := "selected" if selected else "idle"
		draw_style_box(_style("pause_language_%s_%s" % [locale, visual_state], fill, 14.0), option_rect)
		draw_string(font, Vector2(option_rect.position.x, option_rect.position.y + 31.0), language_labels[index], HORIZONTAL_ALIGNMENT_CENTER, option_rect.size.x, 16, Color("#123246"))
		if selected:
			draw_style_box(_style("pause_language_mark_%s" % locale, Color("#159f6d"), 2.0), Rect2(option_rect.position + Vector2(14.0, option_rect.size.y - 7.0), Vector2(option_rect.size.x - 28.0, 3.0)))


func _draw_quit_confirm() -> void:
	if not show_quit_confirm:
		return
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.55))
	var panel := _quit_panel()
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 22.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 22.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 62.0), tr("QUIT_CONFIRM"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Color("#123246"))
	var yes := _quit_yes_rect()
	draw_style_box(_style("quit_yes_sh", Color("#8a2a2a"), 14.0), Rect2(yes.position + Vector2(0.0, 4.0), yes.size))
	draw_style_box(_style("quit_yes", Color("#f2857f"), 14.0), yes)
	draw_string(font, Vector2(yes.position.x, yes.position.y + 30.0), tr("QUIT_YES"), HORIZONTAL_ALIGNMENT_CENTER, yes.size.x, 16, Color("#4a1010"))
	var no := _quit_no_rect()
	draw_style_box(_style("quit_no_sh", Color("#246076"), 14.0), Rect2(no.position + Vector2(0.0, 4.0), no.size))
	draw_style_box(_style("quit_no", Color("#7fd6e6"), 14.0), no)
	draw_string(font, Vector2(no.position.x, no.position.y + 30.0), tr("QUIT_NO"), HORIZONTAL_ALIGNMENT_CENTER, no.size.x, 16, Color("#0d3b55"))


func _draw_completion_panel() -> void:
	if not completed or _car_transition_phase == CAR_TRANSITION_EXITING:
		return
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.35))
	var panel := _completion_panel_rect()
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)

	var time_now := float(Time.get_ticks_msec()) / 1000.0
	_draw_completion_customer_reaction(panel, time_now)
	for index in range(3):
		var star_center := Vector2(145.0 + float(index) * 50.0, panel.position.y + 42.0)
		var reveal_age: float = time_now - _star_reveal_times[index]
		if index < earned_stars and reveal_age >= 0.0:
			var pop_scale := 1.0
			if reveal_age < STAR_REVEAL_POP_DUR:
				pop_scale = 1.0 + 0.6 * (1.0 - reveal_age / STAR_REVEAL_POP_DUR)
			else:
				pop_scale = 1.0 + sin(time_now * 4.0 + float(index) * 0.9) * 0.08
			if not _draw_tex_centered("star", star_center, 42.0 * pop_scale):
				_draw_star(star_center, 17.0 * pop_scale, Color("#ffce3d"), Color("#e0a818"))
		elif index >= earned_stars or reveal_age < 0.0:
			_draw_star(star_center, 15.0, Color("#dde4e8"), Color("#b4c0c7"))

	draw_string(font, Vector2(panel.position.x, panel.position.y + 84.0), tr("COMPLETE_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color("#123246"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 108.0), tr("COMPLETE_SUB") % [car_type_labels[car_type], active_level_index, _format_time(level_time), best_combo], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#2c6b78"))

	var record_seconds: float = _best_time_for_level(active_level_index)
	if is_new_record:
		var record_pulse := 1.0 + 0.25 * exp(-(time_now - record_pop_time) * 5.0)
		var record_color := Color("#e0a818").lerp(Color("#fff3cf"), 0.5 + 0.5 * sin(time_now * 6.0))
		_draw_star(Vector2(panel.position.x + 96.0, panel.position.y + 132.0), 7.0 * record_pulse, record_color, Color("#9a7400"))
		_draw_star(Vector2(panel.position.x + panel.size.x - 96.0, panel.position.y + 132.0), 7.0 * record_pulse, record_color, Color("#9a7400"))
		draw_string(font, Vector2(panel.position.x, panel.position.y + 138.0), tr("NEW_RECORD") % _format_time(record_seconds), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, int(17.0 * record_pulse), Color("#d98a00"))
	elif record_seconds > 0.0:
		draw_string(font, Vector2(panel.position.x, panel.position.y + 136.0), tr("BEST_RECORD") % _format_time(record_seconds), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#6b7d86"))

	var reward_chip := Rect2(panel.position.x + panel.size.x - 106.0, panel.position.y - 14.0, 96.0, 30.0)
	draw_style_box(_style("reward_chip", Color("#ffce3d"), 15.0), reward_chip)
	if not _draw_tex_centered("coin", reward_chip.position + Vector2(16.0, 15.0), 24.0):
		draw_circle(reward_chip.position + Vector2(16.0, 15.0), 8.0, Color("#fff3cf"))
		draw_circle(reward_chip.position + Vector2(16.0, 15.0), 8.0, Color("#9a7400"), false, 1.5)
	draw_string(font, Vector2(reward_chip.position.x + 28.0, reward_chip.position.y + 21.0), "+%d" % coin_reward, HORIZONTAL_ALIGNMENT_LEFT, 64.0, 15, Color("#6b5200"))  # numeric only, locale-neutral

	var tip_chip := _customer_tip_chip_rect(panel)
	draw_style_box(_style("tip_chip", Color("#f7d8ff"), 14.0), tip_chip)
	draw_string(font, Vector2(tip_chip.position.x, tip_chip.position.y + 20.0), tr("PATIENCE_TIP_CHIP") % customer_tip_reward, HORIZONTAL_ALIGNMENT_CENTER, tip_chip.size.x, 13, Color("#70407d"))

	if _level_milestone_bonus > 0:
		var time_now2 := float(Time.get_ticks_msec()) / 1000.0
		var milestone_chip := Rect2(panel.position.x + 10.0, panel.position.y - 14.0, 106.0, 30.0)
		var chip_color := Color("#a855f7").lerp(Color("#ec4899"), 0.5 + 0.5 * sin(time_now2 * 3.0))
		draw_style_box(_style("milestone_chip", chip_color, 15.0), milestone_chip)
		draw_string(font, Vector2(milestone_chip.position.x, milestone_chip.position.y + 21.0), tr("MILESTONE_CHIP") % [active_level_index, _level_milestone_bonus], HORIZONTAL_ALIGNMENT_CENTER, milestone_chip.size.x, 13, Color("#fff0ff"))

	if level_mistakes == 0 and _perfect_wash_bonus > 0:
		var perfect_chip := _perfect_chip_rect(panel)
		var perfect_color := Color("#1fba82").lerp(Color("#f0b92f"), 0.42 + 0.18 * sin(time_now * 3.4))
		draw_style_box(_style("milestone_chip", perfect_color, 15.0), perfect_chip)
		var perfect_font_size := 11 if _level_milestone_bonus > 0 else 13
		draw_string(font, Vector2(perfect_chip.position.x, perfect_chip.position.y + 21.0), tr("PERFECT_CHIP") % _perfect_wash_bonus, HORIZONTAL_ALIGNMENT_CENTER, perfect_chip.size.x, perfect_font_size, Color("#fffdf2"))

	# B: level-end "watch ad → double coins" CTA. Active (green + play triangle)
	# until claimed; after a watched ad it flips to a claimed/disabled state so the
	# row stays put and can't be tapped twice.
	if _double_offer_shown:
		var dbl := _get_double_rect()
		var claimed := _double_claimed
		# Active (tappable) only while inventory is ready; between a dismissed show
		# and its reload the chip dims but keeps its reserved row.
		var active: bool = not claimed and ads != null and ads.is_rewarded_ready("level_reward_2x")
		var dbl_bg: Color
		var dbl_shadow: Color
		if active:
			dbl_bg = Color("#39d98a")
			dbl_shadow = Color("#1f8a55")
		else:
			dbl_bg = Color("#c9d3d9")
			dbl_shadow = Color("#9aa8b0")
		draw_style_box(_style("double_shadow", dbl_shadow, 14.0), Rect2(dbl.position + Vector2(0.0, 4.0), dbl.size))
		draw_style_box(_style("double_button", dbl_bg, 14.0), dbl)
		if active:
			var dtx := dbl.position.x + 26.0
			var dty := dbl.position.y + dbl.size.y * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(dtx, dty - 7.0), Vector2(dtx, dty + 7.0), Vector2(dtx + 11.0, dty)]), Color("#0d3b2a"))
		draw_string(font, Vector2(dbl.position.x, dbl.position.y + 27.0), tr("DOUBLE_DONE") if claimed else tr("DOUBLE_COINS"), HORIZONTAL_ALIGNMENT_CENTER, dbl.size.x, 16, Color("#4a565c") if not active else Color("#0d3b2a"))

	var retry_rect := _get_retry_rect()
	draw_style_box(_style("retry_shadow", Color("#246076"), 14.0), Rect2(retry_rect.position + Vector2(0.0, 4.0), retry_rect.size))
	draw_style_box(_style("retry_button", Color("#7fd6e6"), 14.0), retry_rect)
	draw_string(font, Vector2(retry_rect.position.x, retry_rect.position.y + 30.0), tr("RETRY"), HORIZONTAL_ALIGNMENT_CENTER, retry_rect.size.x, 16, Color("#0d3b55"))

	var next_rect := _get_next_rect()
	draw_style_box(_style("next_shadow", Color("#1f8a55"), 14.0), Rect2(next_rect.position + Vector2(0.0, 4.0), next_rect.size))
	draw_style_box(_style("next_button", Color("#39d98a"), 14.0), next_rect)
	draw_string(font, Vector2(next_rect.position.x, next_rect.position.y + 30.0), tr("NEXT"), HORIZONTAL_ALIGNMENT_CENTER, next_rect.size.x, 16, Color("#0d3b2a"))


func _completion_panel_rect() -> Rect2:
	return Rect2(38.0, 198.0, 314.0, 272.0 + _completion_extra())


func _customer_tip_chip_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position.x + 76.0, panel.position.y + 148.0, 162.0, 28.0)


func _perfect_chip_rect(panel: Rect2) -> Rect2:
	if _level_milestone_bonus > 0:
		return Rect2(panel.position.x + 122.0, panel.position.y - 14.0, 80.0, 30.0)
	return Rect2(panel.position.x + 10.0, panel.position.y - 14.0, 106.0, 30.0)


func _completion_customer_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(15.0, 13.0), Vector2(58.0, 58.0))


func _draw_completion_customer_reaction(panel: Rect2, time_now: float) -> void:
	var profile := _customer_profile()
	var reaction_rect := _completion_customer_rect(panel)
	var strength := CustomerPresentation.reaction_strength(earned_stars)
	var age := maxf(time_now - _customer_completion_time, 0.0)
	var bounce := absf(sin(age * (7.0 + strength * 3.0))) * exp(-age * 1.6) * (2.0 + strength * 4.0)
	var pop := 1.0 + exp(-age * 5.0) * strength * 0.18
	var center := reaction_rect.get_center() + Vector2(0.0, -bounce)
	var radius := 20.0 * pop

	draw_circle(center + Vector2(0.0, 2.0), radius + 3.0, Color(0.08, 0.2, 0.28, 0.14))
	draw_circle(center, radius, Color(String(profile["face_hex"])))
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.2), 1.8, true)
	_draw_customer_accessory(center, radius, profile)

	var feature_scale := radius / 20.0
	var ink := Color(0.12, 0.07, 0.04)
	if earned_stars >= 3:
		for side in [-1.0, 1.0]:
			var eye := center + Vector2(side * 7.0, -4.5) * feature_scale
			draw_arc(eye, 3.5 * feature_scale, 0.15, PI - 0.15, 10, ink, 2.0 * feature_scale, true)
	else:
		draw_circle(center + Vector2(-7.0, -4.5) * feature_scale, 2.2 * feature_scale, ink)
		draw_circle(center + Vector2(7.0, -4.5) * feature_scale, 2.2 * feature_scale, ink)
	if earned_stars <= 1:
		draw_arc(center + Vector2(0.0, 3.0) * feature_scale, 7.0 * feature_scale, 0.35, PI - 0.35, 14, ink, 2.2 * feature_scale, true)
	else:
		draw_circle(center + Vector2(0.0, 7.0) * feature_scale, (4.0 + strength * 3.0) * feature_scale, ink)
		draw_arc(center + Vector2(0.0, 6.0) * feature_scale, 3.5 * feature_scale, 0.2, PI - 0.2, 10, Color("#f2857f"), 1.8 * feature_scale, true)
		draw_circle(center + Vector2(-13.0, 4.0) * feature_scale, 2.3 * feature_scale, Color(1.0, 0.38, 0.42, 0.34))
		draw_circle(center + Vector2(13.0, 4.0) * feature_scale, 2.3 * feature_scale, Color(1.0, 0.38, 0.42, 0.34))

	for index in range(clampi(earned_stars, 1, 3)):
		var angle := -PI * 0.85 + float(index) * PI * 0.85
		var sparkle_center := center + Vector2.from_angle(angle) * (radius + 9.0 + sin(time_now * 5.0 + float(index)) * 2.0)
		_draw_star(sparkle_center, (3.5 + strength * 2.0), Color("#ffce3d"), Color("#e0a818"))


func _format_time(seconds_value: float) -> String:
	var clamped: float = max(0.0, seconds_value)
	var minutes := int(clamped / 60.0)
	var seconds := int(clamped) % 60
	return "%02d:%02d" % [minutes, seconds]


func _draw_star(center: Vector2, radius: float, fill: Color, rim: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		var angle := -PI * 0.5 + TAU * float(index) / 10.0
		var reach := radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2.from_angle(angle) * reach)
	draw_colored_polygon(points, fill)
	_draw_closed_outline(points, rim, 2.0)


func _get_tool_rect(index: int) -> Rect2:
	var gap := 8.0
	var margin := 18.0
	var width := (DESIGN_SIZE.x - margin * 2.0 - gap * 3.0) / 4.0
	return Rect2(margin + float(index) * (width + gap), _tool_button_y(), width, TOOL_BUTTON_HEIGHT)


# B: when the level-end double-coins offer is shown, the completion panel grows by
# this much and the retry/next row slides down to make room for the 2x button.
const COMPLETION_DOUBLE_EXTRA := 56.0


func _completion_extra() -> float:
	return COMPLETION_DOUBLE_EXTRA if _double_offer_shown else 0.0


func _get_double_rect() -> Rect2:
	return Rect2(58.0, 392.0, 274.0, 42.0)


# Pause/settings sheet: resume / restart / sound / language / guide / home / quit.
func _pause_panel() -> Rect2:
	var panel_height := 500.0
	var insets := _safe_area_design_insets()
	var min_y := insets.y + 16.0
	var max_y := DESIGN_SIZE.y - insets.w - 16.0 - panel_height
	var centered_y := (DESIGN_SIZE.y - panel_height) * 0.5
	return Rect2(55.0, clampf(centered_y, min_y, maxf(min_y, max_y)), 280.0, panel_height)


func _pause_button_rect(index: int) -> Rect2:
	var row := index if index < 3 else index + 1
	return _pause_row_rect(row)


func _pause_language_rect() -> Rect2:
	return _pause_row_rect(3)


func _pause_language_option_rect(locale: String) -> Rect2:
	var row := _pause_language_rect()
	var gap := 8.0
	var option_width := (row.size.x - gap) * 0.5
	if locale == "ko":
		return Rect2(row.position, Vector2(option_width, row.size.y))
	return Rect2(row.position + Vector2(option_width + gap, 0.0), Vector2(option_width, row.size.y))


func _pause_row_rect(row_index: int) -> Rect2:
	var panel := _pause_panel()
	var button_h := 46.0
	var gap := 8.0
	var y0 := panel.position.y + 72.0
	return Rect2(panel.position.x + 24.0, y0 + float(row_index) * (button_h + gap), panel.size.x - 48.0, button_h)


func _tutorial_panel_rect() -> Rect2:
	return Rect2(20.0, 78.0, 350.0, 688.0)


func _tutorial_close_rect() -> Rect2:
	var panel: Rect2 = _tutorial_panel_rect()
	return Rect2(panel.end.x - 46.0, panel.position.y + 8.0, 36.0, 36.0)


func _tutorial_tab_rect(tab: int) -> Rect2:
	var panel: Rect2 = _tutorial_panel_rect()
	var gap: float = 8.0
	var width: float = (panel.size.x - 40.0 - gap) * 0.5
	return Rect2(panel.position.x + 20.0 + float(tab) * (width + gap), panel.position.y + 58.0, width, 34.0)


func _tutorial_dirt_row_rect(index: int) -> Rect2:
	var panel: Rect2 = _tutorial_panel_rect()
	return Rect2(panel.position.x + 16.0, panel.position.y + 132.0 + float(index) * 60.0, panel.size.x - 32.0, 54.0)


func _tutorial_done_rect() -> Rect2:
	var panel: Rect2 = _tutorial_panel_rect()
	return Rect2(panel.position.x + 72.0, panel.end.y - 54.0, panel.size.x - 144.0, 40.0)


func _quit_panel() -> Rect2:
	return Rect2(65.0, 348.0, 260.0, 170.0)


func _quit_yes_rect() -> Rect2:
	var panel := _quit_panel()
	var button_w := (panel.size.x - 52.0) / 2.0
	return Rect2(panel.position.x + 20.0, panel.position.y + panel.size.y - 62.0, button_w, 46.0)


func _quit_no_rect() -> Rect2:
	var panel := _quit_panel()
	var button_w := (panel.size.x - 52.0) / 2.0
	return Rect2(panel.position.x + panel.size.x - 20.0 - button_w, panel.position.y + panel.size.y - 62.0, button_w, 46.0)


func _get_retry_rect() -> Rect2:
	return Rect2(58.0, 400.0 + _completion_extra(), 131.0, 46.0)


func _get_next_rect() -> Rect2:
	return Rect2(201.0, 400.0 + _completion_extra(), 131.0, 46.0)


func _get_start_rect() -> Rect2:
	return Rect2(95.0, 488.0, 200.0, 58.0)


func _get_status_rect() -> Rect2:
	return Rect2(14.0, _hud_top_y(), 310.0, 84.0)


func _get_grade_rect() -> Rect2:
	return Rect2(14.0, _hud_top_y() + 90.0, 104.0, 56.0)


func _get_customer_rect() -> Rect2:
	return Rect2(124.0, _hud_top_y() + 90.0, 104.0, 56.0)


func _get_daily_mission_rect() -> Rect2:
	return Rect2(234.0, _hud_top_y() + 90.0, 142.0, 56.0)


func _get_daily_mission_bar_rect() -> Rect2:
	var rect := _get_daily_mission_rect()
	var margin_x := 10.0
	var height := 4.0
	var bottom_padding := 7.0
	return Rect2(
		rect.position.x + margin_x,
		rect.end.y - bottom_padding - height,
		rect.size.x - margin_x * 2.0,
		height
	)


func _get_pause_entry_rect() -> Rect2:
	return Rect2(332.0, _hud_top_y() + 20.0, 44.0, 44.0)


func _get_title_sound_rect() -> Rect2:
	return Rect2(14.0, _title_button_y(), 30.0, 30.0)


func _get_title_help_rect() -> Rect2:
	return Rect2(50.0, _title_button_y(), 30.0, 30.0)


func _get_booster_rect() -> Rect2:
	# Bottom aligned with the hint chip, above the toolbar PANEL top so a bottom
	# safe-area inset never lets the panel overlap this chip.
	return Rect2(276.0, minf(688.0, _tool_button_y() - 76.0), 92.0, 46.0)


func _booster_panel_rect() -> Rect2:
	return Rect2(34.0, 302.0, 322.0, 286.0)


func _booster_close_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.end.x - 46.0, panel.position.y + 8.0, 36.0, 36.0)


func _booster_card_rect(panel: Rect2, index: int) -> Rect2:
	return Rect2(panel.position.x + 14.0, panel.position.y + 78.0 + float(index) * 98.0, panel.size.x - 28.0, 88.0)


func _get_upgrade_btn_rect() -> Rect2:
	return Rect2(95.0, 600.0, 200.0, 44.0)


func _upgrade_mult(key: String) -> float:
	return Economy.upgrade_mult(_power_upgrade_level(key))


func _power_upgrade_level(key: String) -> int:
	if key == TOOL_WATER:
		return upgrade_water
	if key == TOOL_SOAP:
		return upgrade_soap
	if key == TOOL_SPONGE:
		return upgrade_sponge
	return 0


func _set_power_upgrade_level(key: String, level: int) -> void:
	var safe_level: int = clampi(level, 0, UPGRADE_MAX_LEVEL)
	if key == TOOL_WATER:
		upgrade_water = safe_level
	elif key == TOOL_SOAP:
		upgrade_soap = safe_level
	elif key == TOOL_SPONGE:
		upgrade_sponge = safe_level


func _reach_upgrade_level(key: String) -> int:
	if key == TOOL_AIR:
		return reach_upgrade_air
	if key == TOOL_WATER:
		return reach_upgrade_water
	if key == TOOL_SOAP:
		return reach_upgrade_soap
	if key == TOOL_SPONGE:
		return reach_upgrade_sponge
	return 0


func _set_reach_upgrade_level(key: String, level: int) -> void:
	var safe_level: int = clampi(level, 0, REACH_UPGRADE_MAX_LEVEL)
	if key == TOOL_AIR:
		reach_upgrade_air = safe_level
	elif key == TOOL_WATER:
		reach_upgrade_water = safe_level
	elif key == TOOL_SOAP:
		reach_upgrade_soap = safe_level
	elif key == TOOL_SPONGE:
		reach_upgrade_sponge = safe_level


func _reach_upgrade_mult(key: String) -> float:
	return Economy.reach_upgrade_mult(_reach_upgrade_level(key))


func _upgrade_panel_rect() -> Rect2:
	return Rect2(20.0, 100.0, 350.0, 520.0)


func _upgrade_tab_rect(tab: int) -> Rect2:
	var panel: Rect2 = _upgrade_panel_rect()
	var gap: float = 8.0
	var width: float = (panel.size.x - 40.0 - gap) * 0.5
	return Rect2(panel.position.x + 20.0 + float(tab) * (width + gap), panel.position.y + 82.0, width, 34.0)


func _upgrade_row_y(panel: Rect2, idx: int) -> float:
	return panel.position.y + 128.0 + float(idx) * 86.0


func _upgrade_buy_rect(panel: Rect2, idx: int) -> Rect2:
	return Rect2(panel.position.x + panel.size.x - 114.0, _upgrade_row_y(panel, idx) + 20.0, 90.0, 38.0)


func _handle_upgrade_panel_tap(point: Vector2) -> void:
	var panel: Rect2 = _upgrade_panel_rect()
	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	if close_rect.has_point(point):
		show_upgrade_panel = false
		queue_redraw()
		_play_ui_select()
		return
	for tab in [UPGRADE_TAB_POWER, UPGRADE_TAB_REACH]:
		if _upgrade_tab_rect(tab).has_point(point):
			_upgrade_panel_tab = tab
			queue_redraw()
			_play_ui_select()
			return
	var keys: Array = UPGRADE_KEYS if _upgrade_panel_tab == UPGRADE_TAB_POWER else REACH_UPGRADE_KEYS
	for idx in range(keys.size()):
		if _upgrade_buy_rect(panel, idx).has_point(point):
			_try_buy_upgrade(idx)
			return


func _try_buy_upgrade(idx: int) -> void:
	var is_reach: bool = _upgrade_panel_tab == UPGRADE_TAB_REACH
	var keys: Array = REACH_UPGRADE_KEYS if is_reach else UPGRADE_KEYS
	if idx < 0 or idx >= keys.size():
		return
	var key: String = String(keys[idx])
	var lvl: int = _reach_upgrade_level(key) if is_reach else _power_upgrade_level(key)
	var can_buy: bool = Economy.can_buy_reach_upgrade(idx, lvl, coins) if is_reach else Economy.can_buy_upgrade(idx, lvl, coins)
	if not can_buy:
		return
	var cost: int = Economy.reach_upgrade_cost(idx, lvl) if is_reach else Economy.upgrade_cost(idx, lvl)
	coins -= cost
	if is_reach:
		_set_reach_upgrade_level(key, lvl + 1)
	else:
		_set_power_upgrade_level(key, lvl + 1)
	if _save_progress() != OK:
		coins += cost
		if is_reach:
			_set_reach_upgrade_level(key, lvl)
		else:
			_set_power_upgrade_level(key, lvl)
		return
	var analytics_key: String = "reach_" + key if is_reach else key
	_emit_analytics(ContentEvents.upgrade_purchase(analytics_key, lvl + 1, cost))
	_play_ui_select()
	queue_redraw()


func _draw_upgrade_panel() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.05, 0.18, 0.72))
	var panel: Rect2 = _upgrade_panel_rect()
	draw_style_box(_style("upg_panel_shadow", Color(0.02, 0.06, 0.22, 0.5), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("upg_panel", Color("#f0f6ff"), 22.0), panel)

	draw_string(font, Vector2(panel.position.x, panel.position.y + 50.0), tr("UPG_SHOP_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#0d2a50"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 74.0), tr("COINS_LABEL") % coins, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#3a7fc1"))

	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	draw_style_box(_style("upg_close_bg", Color("#e0e9f5"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#0d2a50"))

	for tab in [UPGRADE_TAB_POWER, UPGRADE_TAB_REACH]:
		var tab_rect: Rect2 = _upgrade_tab_rect(tab)
		var selected: bool = tab == _upgrade_panel_tab
		draw_style_box(_style("upg_tab_%d" % tab, Color("#3a9ef0") if selected else Color("#d5e3f1"), 10.0), tab_rect)
		draw_string(font, Vector2(tab_rect.position.x, tab_rect.position.y + 23.0), tr("UPG_TAB_POWER") if tab == UPGRADE_TAB_POWER else tr("UPG_TAB_REACH"), HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x, 14, Color.WHITE if selected else Color("#49677c"))

	var is_reach: bool = _upgrade_panel_tab == UPGRADE_TAB_REACH
	var keys: Array = REACH_UPGRADE_KEYS if is_reach else UPGRADE_KEYS
	var max_level: int = REACH_UPGRADE_MAX_LEVEL if is_reach else UPGRADE_MAX_LEVEL
	for idx in range(keys.size()):
		var key: String = String(keys[idx])
		var lvl: int = _reach_upgrade_level(key) if is_reach else _power_upgrade_level(key)
		var row_y: float = _upgrade_row_y(panel, idx)
		var row_rect := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 78.0)
		draw_style_box(_style("upg_row_%d" % idx, Color("#ddeaf8"), 14.0), row_rect)

		draw_circle(Vector2(panel.position.x + 43.0, row_y + 39.0), 17.0, _upgrade_tool_color(key))
		var upg_key: String = key.to_upper()
		var name_key: String = "UPG_REACH_NAME_" + upg_key if is_reach else "UPG_NAME_" + upg_key
		draw_string(font, Vector2(panel.position.x + 70.0, row_y + 23.0), tr(name_key), HORIZONTAL_ALIGNMENT_LEFT, 156.0, 14, Color("#0d2a50"))
		var description: String = tr("UPG_DESC_" + upg_key)
		if is_reach:
			var preview_level: int = mini(lvl + 1, REACH_UPGRADE_MAX_LEVEL)
			var increase_percent: int = roundi((Economy.reach_upgrade_mult(preview_level) - 1.0) * 100.0)
			description = tr("UPG_REACH_DESC") % increase_percent
		draw_string(font, Vector2(panel.position.x + 70.0, row_y + 43.0), description, HORIZONTAL_ALIGNMENT_LEFT, 156.0, 10, Color("#2c6b78"))

		for dot_idx in range(max_level):
			var dot_x: float = panel.position.x + 76.0 + float(dot_idx) * 18.0
			var dot_y: float = row_y + 62.0
			if dot_idx < lvl:
				draw_circle(Vector2(dot_x, dot_y), 5.0, Color("#3a9ef0"))
			else:
				draw_circle(Vector2(dot_x, dot_y), 5.0, Color("#b8cfe0"))

		var buy_rect: Rect2 = _upgrade_buy_rect(panel, idx)
		if lvl >= max_level:
			draw_style_box(_style("upg_max_bg", Color("#b8cfe0"), 10.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 26.0), tr("MAX"), HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 15, Color("#6a8aaa"))
		else:
			var cost: int = REACH_UPGRADE_COSTS[idx][lvl] if is_reach else UPGRADE_COSTS[idx][lvl]
			var affordable: bool = coins >= cost
			var btn_col: Color = Color("#39d98a") if affordable else Color("#8fc4b4")
			draw_style_box(_style("upg_buy_%d" % idx, btn_col, 10.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 26.0), tr("COST_COIN") % cost, HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 14, Color("#0d2a3b") if affordable else Color("#4a7a6a"))
			_draw_unaffordable_lock(buy_rect, affordable, Color("#264d45"))


func _upgrade_tool_color(key: String) -> Color:
	if key == TOOL_AIR:
		return Color("#d8eef5")
	if key == TOOL_WATER:
		return Color("#49a7ff")
	if key == TOOL_SOAP:
		return Color("#f8f4a6")
	return Color("#ff9f5a")


func _get_skin_btn_rect() -> Rect2:
	return Rect2(95.0, 652.0, 200.0, 44.0)


func _get_stage_btn_rect() -> Rect2:
	return Rect2(95.0, 704.0, 200.0, 44.0)


func _get_achievement_btn_rect() -> Rect2:
	return Rect2(95.0, 756.0, 200.0, 44.0)


func _achievement_completed_count() -> int:
	var count := 0
	for definition in AchievementProgress.DEFINITIONS:
		if bool(achievement_claimed.get(String(definition["id"]), false)):
			count += 1
	return count


func _achievement_panel_rect() -> Rect2:
	return Rect2(15.0, 62.0, 360.0, 650.0)


func _achievement_close_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.end.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)


func _achievement_row_rect(panel: Rect2, row_index: int) -> Rect2:
	return Rect2(panel.position.x + 14.0, panel.position.y + 102.0 + float(row_index) * 100.0, panel.size.x - 28.0, 88.0)


func _handle_achievement_panel_tap(point: Vector2) -> void:
	var panel := _achievement_panel_rect()
	if _achievement_close_rect(panel).has_point(point):
		show_achievement_panel = false
		queue_redraw()
		_play_ui_select()


func _draw_achievement_panel() -> void:
	var font := _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.03, 0.06, 0.14, 0.76))
	var panel := _achievement_panel_rect()
	draw_style_box(_style("achievement_panel_shadow", Color(0.19, 0.10, 0.02, 0.48), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("achievement_panel", Color("#fff8e8"), 22.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 46.0), tr("ACH_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 23, Color("#4d2c08"))
	var definitions := AchievementProgress.definitions()
	draw_string(font, Vector2(panel.position.x, panel.position.y + 72.0), tr("ACH_SUMMARY") % [_achievement_completed_count(), definitions.size()], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#8a5b20"))
	var close_rect := _achievement_close_rect(panel)
	draw_style_box(_style("achievement_close", Color("#f2dfb8"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#4d2c08"))

	for achievement_index in range(definitions.size()):
		var definition: Dictionary = definitions[achievement_index]
		var achievement_id: String = definition["id"]
		var complete := bool(achievement_claimed.get(achievement_id, false))
		var row := _achievement_row_rect(panel, achievement_index)
		var row_bg := Color("#e6f7e9") if complete else Color("#fff1d2")
		var row_border := Color("#35a966") if complete else Color("#e5aa45")
		draw_style_box(_style("achievement_row_%s_%s" % [achievement_id, str(complete)], row_bg, 13.0, row_border, 2), row)
		var title := tr(String(definition["label_key"])) % int(definition["target"])
		draw_string(font, Vector2(row.position.x + 12.0, row.position.y + 25.0), title, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 112.0, 15, Color("#3f2c13"))
		draw_string(font, Vector2(row.position.x, row.position.y + 25.0), tr("ACH_REWARD") % int(definition["reward"]), HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 12.0, 12, Color("#9b650d"))
		var progress := AchievementProgress.progress_for(definition, achievement_counters)
		var target := int(definition["target"])
		var bar := Rect2(row.position.x + 12.0, row.position.y + 43.0, row.size.x - 24.0, 9.0)
		draw_style_box(_style("achievement_bar_bg", Color(0.22, 0.16, 0.08, 0.18), 4.0), bar)
		var ratio := float(progress) / float(maxi(target, 1))
		if ratio > 0.0:
			var fill := Rect2(bar.position, Vector2(maxf(7.0, bar.size.x * ratio), bar.size.y))
			draw_style_box(_style("achievement_bar_done" if complete else "achievement_bar_active", Color("#35a966") if complete else Color("#f0a52b"), 4.0), fill)
		var progress_label := tr("ACH_DONE") if complete else "%d / %d" % [progress, target]
		draw_string(font, Vector2(row.position.x + 12.0, row.position.y + 74.0), progress_label, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 24.0, 13, Color("#25834d") if complete else Color("#76511c"))


func _stage_panel_rect() -> Rect2:
	return Rect2(15.0, 78.0, 360.0, 624.0)


func _stage_close_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)


func _stage_card_rect(panel: Rect2, card_index: int) -> Rect2:
	var col := card_index % 2
	var row := int(card_index / 2)
	var card_width := (panel.size.x - 36.0) / 2.0
	return Rect2(
		panel.position.x + 14.0 + float(col) * (card_width + 8.0),
		panel.position.y + 82.0 + float(row) * 136.0,
		card_width,
		126.0
	)


func _stage_prev_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position.x + 22.0, panel.end.y - 54.0, 86.0, 38.0)


func _stage_next_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.end.x - 108.0, panel.end.y - 54.0, 86.0, 38.0)


func _handle_stage_panel_tap(point: Vector2) -> void:
	var panel := _stage_panel_rect()
	if _stage_close_rect(panel).has_point(point):
		show_stage_panel = false
		queue_redraw()
		_play_ui_select()
		return
	var page_count: int = StageSelection.page_count(level_index)
	if _stage_prev_rect(panel).has_point(point) and _stage_page > 0:
		_stage_page -= 1
		queue_redraw()
		_play_ui_select()
		return
	if _stage_next_rect(panel).has_point(point) and _stage_page + 1 < page_count:
		_stage_page += 1
		queue_redraw()
		_play_ui_select()
		return
	var cards: Array[Dictionary] = StageSelection.cards(level_index, best_times, best_stars, _stage_page)
	for card_index in range(cards.size()):
		var card: Dictionary = cards[card_index]
		if bool(card["unlocked"]) and _stage_card_rect(panel, card_index).has_point(point):
			var target_level := int(card["level"])
			show_stage_panel = false
			reset_game(target_level, "stage_retry")
			start_game(target_level, "stage_retry")
			_play_ui_select()
			return


func _draw_stage_panel() -> void:
	var font := _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.01, 0.06, 0.12, 0.76))
	var panel := _stage_panel_rect()
	draw_style_box(_style("stage_panel_shadow", Color(0.02, 0.12, 0.18, 0.55), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("stage_panel_bg", Color("#eefbff"), 22.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), tr("STAGE_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 23, Color("#0d3b55"))
	var close_rect := _stage_close_rect(panel)
	draw_style_box(_style("stage_close_bg", Color("#d9eef4"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#0d3b55"))

	var cards: Array[Dictionary] = StageSelection.cards(level_index, best_times, best_stars, _stage_page)
	for card_index in range(cards.size()):
		var card: Dictionary = cards[card_index]
		var card_rect := _stage_card_rect(panel, card_index)
		var unlocked := bool(card["unlocked"])
		var card_bg := Color("#ffffff") if unlocked else Color("#dbe5e9")
		var border := Color("#49a7ff") if unlocked else Color("#a9b7bd")
		draw_style_box(_style("stage_card_%d_%s" % [int(card["level"]), str(unlocked)], card_bg, 14.0, border, 2), card_rect)
		var stage_level := int(card["level"])
		draw_string(font, Vector2(card_rect.position.x, card_rect.position.y + 28.0), tr("STAGE_LEVEL") % stage_level, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 16, Color("#0d3b55") if unlocked else Color("#718087"))
		if not unlocked:
			draw_string(font, Vector2(card_rect.position.x, card_rect.position.y + 76.0), tr("STAGE_LOCKED"), HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 18, Color("#718087"))
			continue
		var stage_car := GameConfig.car_type_for_level(stage_level)
		draw_string(font, Vector2(card_rect.position.x, card_rect.position.y + 49.0), car_type_labels[stage_car], HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 12, Color("#3f7184"))
		var record := float(card["best_time"])
		var record_label := _format_time(record) if record > 0.0 else "-"
		draw_string(font, Vector2(card_rect.position.x, card_rect.position.y + 72.0), tr("STAGE_BEST") % record_label, HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, 13, Color("#2c6b78"))
		var stars := int(card["best_stars"])
		for star_index in range(3):
			var star_center := Vector2(card_rect.position.x + card_rect.size.x * 0.5 + float(star_index - 1) * 25.0, card_rect.position.y + 99.0)
			if star_index < stars:
				_draw_star(star_center, 7.5, Color("#ffce3d"), Color("#d69e00"))
			else:
				_draw_star(star_center, 7.0, Color("#d7e1e5"), Color("#a9b7bd"))

	var page_count: int = StageSelection.page_count(level_index)
	var prev_rect := _stage_prev_rect(panel)
	var next_rect := _stage_next_rect(panel)
	draw_style_box(_style("stage_prev_%d" % _stage_page, Color("#7fd6e6") if _stage_page > 0 else Color("#c8d8dd"), 10.0), prev_rect)
	draw_style_box(_style("stage_next_%d_%d" % [_stage_page, page_count], Color("#7fd6e6") if _stage_page + 1 < page_count else Color("#c8d8dd"), 10.0), next_rect)
	draw_string(font, Vector2(prev_rect.position.x, prev_rect.position.y + 25.0), tr("STAGE_PREV"), HORIZONTAL_ALIGNMENT_CENTER, prev_rect.size.x, 14, Color("#0d3b55"))
	draw_string(font, Vector2(next_rect.position.x, next_rect.position.y + 25.0), tr("STAGE_NEXT"), HORIZONTAL_ALIGNMENT_CENTER, next_rect.size.x, 14, Color("#0d3b55"))
	draw_string(font, Vector2(panel.position.x, panel.end.y - 28.0), tr("STAGE_PAGE") % [_stage_page + 1, page_count], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#3f7184"))


func _active_skin_color(tool_key: String, alpha: float = 1.0) -> Color:
	var sid: String
	if tool_key == TOOL_WATER:
		sid = skin_water
	elif tool_key == TOOL_AIR:
		sid = skin_air
	elif tool_key == TOOL_SOAP:
		sid = skin_soap
	else:
		sid = skin_sponge
	var skins: Array = _nozzle_skins.get(tool_key, [])
	for s in skins:
		if s["id"] == sid:
			var c: Color = s["color"]
			c.a = alpha
			return c
	if not skins.is_empty():
		var c: Color = skins[0]["color"]
		c.a = alpha
		return c
	return Color(0.5, 0.5, 0.5, alpha)


func _is_nozzle_skin_owned(tool_key: String, skin_id: String) -> bool:
	return Economy.is_skin_owned(owned_skins, tool_key, skin_id)


func _skin_tab_rect(panel: Rect2, tab_idx: int) -> Rect2:
	var tab_w: float = (panel.size.x - 20.0) / float(SKIN_PANEL_TAB_KEYS.size())
	return Rect2(panel.position.x + 10.0 + tab_idx * tab_w, panel.position.y + 74.0, tab_w, 34.0)


func _skin_panel_rect() -> Rect2:
	return Rect2(15.0, 88.0, 360.0, 480.0)


func _skin_card_rect(panel: Rect2, card_idx: int) -> Rect2:
	var col: int = card_idx % 2
	var row: int = int(card_idx / 2)
	var card_w: float = (panel.size.x - 28.0 - 8.0) / 2.0
	var card_h := 118.0
	var x: float = panel.position.x + 14.0 + float(col) * (card_w + 8.0)
	var y: float = panel.position.y + 116.0 + float(row) * (card_h + 8.0)
	return Rect2(x, y, card_w, card_h)


func _skin_buy_rect(card: Rect2) -> Rect2:
	return Rect2(card.position.x + 8.0, card.position.y + card.size.y - 38.0, card.size.x - 16.0, 30.0)


func _license_plate_choice_rect(panel: Rect2, choice_index: int) -> Rect2:
	var options := LicensePlate.options()
	var gap := 6.0
	var width := (panel.size.x - 28.0 - gap * float(options.size() - 1)) / float(options.size())
	return Rect2(panel.position.x + 14.0 + float(choice_index) * (width + gap), panel.position.y + 400.0, width, 42.0)


func _handle_skin_panel_tap(point: Vector2) -> void:
	var panel := _skin_panel_rect()
	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	if close_rect.has_point(point):
		show_skin_panel = false
		queue_redraw()
		_play_ui_select()
		return
	for t in range(SKIN_PANEL_TAB_KEYS.size()):
		if _skin_tab_rect(panel, t).has_point(point):
			_skin_panel_tab = t
			queue_redraw()
			_play_ui_select()
			return
	var tool_key: String = SKIN_PANEL_TAB_KEYS[_skin_panel_tab]
	var skins: Array = _car_paints.get(tool_key, []) if tool_key == CAR_PAINT_TOOL else _nozzle_skins.get(tool_key, [])
	for ci in range(skins.size()):
		if _skin_buy_rect(_skin_card_rect(panel, ci)).has_point(point):
			if tool_key == CAR_PAINT_TOOL:
				_try_buy_or_select_car_paint(ci)
			else:
				_try_buy_or_select_skin(tool_key, ci)
			return
	var plate_options := LicensePlate.options()
	for choice_index in range(plate_options.size()):
		if _license_plate_choice_rect(panel, choice_index).has_point(point):
			_select_license_plate(String(plate_options[choice_index]))
			return


func _select_license_plate(raw_value: String) -> void:
	var next_value := LicensePlate.safe_selection(raw_value)
	if next_value == license_plate_text:
		return
	var previous_value := license_plate_text
	license_plate_text = next_value
	if _save_progress() != OK:
		license_plate_text = previous_value
		queue_redraw()
		return
	_play_ui_select()
	queue_redraw()


func _try_buy_or_select_skin(tool_key: String, skin_idx: int) -> void:
	var intent := Economy.resolve_skin_purchase(_nozzle_skins, tool_key, skin_idx, owned_skins, coins)
	var action: String = intent["action"]
	if action == "deny":
		return
	var sid: String = intent["id"]
	var cost: int = intent["cost"]

	var prev_sid: String
	if tool_key == TOOL_WATER:
		prev_sid = skin_water
	elif tool_key == TOOL_AIR:
		prev_sid = skin_air
	elif tool_key == TOOL_SOAP:
		prev_sid = skin_soap
	else:
		prev_sid = skin_sponge

	if action == "select":
		if tool_key == TOOL_WATER:
			skin_water = sid
		elif tool_key == TOOL_AIR:
			skin_air = sid
		elif tool_key == TOOL_SOAP:
			skin_soap = sid
		else:
			skin_sponge = sid
		if _save_progress() != OK:
			if tool_key == TOOL_WATER:
				skin_water = prev_sid
			elif tool_key == TOOL_AIR:
				skin_air = prev_sid
			elif tool_key == TOOL_SOAP:
				skin_soap = prev_sid
			else:
				skin_sponge = prev_sid
			queue_redraw()
			return
		queue_redraw()
		_emit_analytics(ContentEvents.skin_select(tool_key, sid))
		_play_ui_select()
		return

	# Economy intent already validates ownership and affordability. Only its
	# explicit buy result may enter the coin/ownership mutation below.
	if action != "buy":
		return
	coins -= cost
	var ownership_key := Economy.skin_ownership_key(tool_key, sid)
	owned_skins[ownership_key] = true
	if tool_key == TOOL_WATER:
		skin_water = sid
	elif tool_key == TOOL_AIR:
		skin_air = sid
	elif tool_key == TOOL_SOAP:
		skin_soap = sid
	else:
		skin_sponge = sid
	if _save_progress() != OK:
		coins += cost
		owned_skins.erase(ownership_key)
		if tool_key == TOOL_WATER:
			skin_water = prev_sid
		elif tool_key == TOOL_AIR:
			skin_air = prev_sid
		elif tool_key == TOOL_SOAP:
			skin_soap = prev_sid
		else:
			skin_sponge = prev_sid
		queue_redraw()
		return
	_emit_analytics(ContentEvents.skin_purchase(tool_key, sid, cost))
	_play_ui_select()
	queue_redraw()


func _try_buy_or_select_car_paint(paint_idx: int) -> void:
	var intent := Economy.resolve_flat_item_purchase(_car_paints, CAR_PAINT_TOOL, paint_idx, owned_car_paints, coins)
	var action: String = intent["action"]
	if action == "deny":
		return
	var paint_id: String = intent["id"]
	var cost: int = intent["cost"]
	var previous_selection := selected_car_paint
	var next_selection := CarPaintCatalog.safe_selection(paint_id)

	if action == "select":
		selected_car_paint = next_selection
		_set_car_palette()
		if _save_progress() != OK:
			selected_car_paint = previous_selection
			_set_car_palette()
			queue_redraw()
			return
		_emit_analytics(ContentEvents.skin_select(CAR_PAINT_TOOL, paint_id))
		_play_ui_select()
		queue_redraw()
		return

	# action == "buy"
	coins -= cost
	owned_car_paints[paint_id] = true
	selected_car_paint = next_selection
	_set_car_palette()
	if _save_progress() != OK:
		coins += cost
		owned_car_paints.erase(paint_id)
		selected_car_paint = previous_selection
		_set_car_palette()
		queue_redraw()
		return
	_emit_analytics(ContentEvents.skin_purchase(CAR_PAINT_TOOL, paint_id, cost))
	_play_ui_select()
	queue_redraw()


func _draw_skin_panel() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.05, 0.18, 0.72))
	var panel := _skin_panel_rect()
	draw_style_box(_style("skin_panel_shadow", Color(0.08, 0.02, 0.22, 0.5), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("skin_panel_bg", Color("#f5f0ff"), 22.0), panel)

	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), tr("SKIN_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#2a0d50"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 70.0), tr("COINS_LABEL") % coins, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#7a3ac1"))

	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	draw_style_box(_style("skin_close_bg", Color("#e8d8f8"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#2a0d50"))

	var tab_labels := [tr("TOOL_WATER"), tr("TOOL_AIR"), tr("TOOL_SOAP"), tr("TOOL_SPONGE"), tr("CAR_PAINT_TAB")]
	for t in range(SKIN_PANEL_TAB_KEYS.size()):
		var tr: Rect2 = _skin_tab_rect(panel, t)
		var is_active: bool = _skin_panel_tab == t
		var tab_col := Color("#7a35c8") if is_active else Color("#d0b8f0")
		draw_style_box(_style("skin_tab_%d_%s" % [t, str(is_active)], tab_col, 8.0), tr)
		var lbl_col := Color(1.0, 1.0, 1.0) if is_active else Color("#4a2a7a")
		draw_string(font, Vector2(tr.position.x, tr.position.y + 22.0), tab_labels[t], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 12, lbl_col)

	var tool_key: String = SKIN_PANEL_TAB_KEYS[_skin_panel_tab]
	var active_sid: String
	var skins: Array
	var owned_items: Dictionary
	if tool_key == CAR_PAINT_TOOL:
		active_sid = CarPaintCatalog.selected_catalog_id(selected_car_paint)
		skins = _car_paints.get(tool_key, [])
		owned_items = owned_car_paints
	elif tool_key == TOOL_WATER:
		active_sid = skin_water
		skins = _nozzle_skins.get(tool_key, [])
		owned_items = owned_skins
	elif tool_key == TOOL_AIR:
		active_sid = skin_air
		skins = _nozzle_skins.get(tool_key, [])
		owned_items = owned_skins
	elif tool_key == TOOL_SOAP:
		active_sid = skin_soap
		skins = _nozzle_skins.get(tool_key, [])
		owned_items = owned_skins
	else:
		active_sid = skin_sponge
		skins = _nozzle_skins.get(tool_key, [])
		owned_items = owned_skins

	for ci in range(skins.size()):
		var skin: Dictionary = skins[ci]
		var sid: String = skin["id"]
		var cost: int = skin["cost"]
		var col: Color = skin["color"]
		var is_owned: bool = owned_items.get(sid, false) if tool_key == CAR_PAINT_TOOL else _is_nozzle_skin_owned(tool_key, sid)
		var is_selected: bool = sid == active_sid
		var card: Rect2 = _skin_card_rect(panel, ci)

		var card_bg := Color("#e8d8f8") if is_selected else Color("#f0e8ff")
		var border_col := Color("#7a35c8") if is_selected else Color("#c8a8f0")
		draw_style_box(_style("skin_card_%d_%d_%s" % [ci, int(is_selected), sid], card_bg, 12.0, border_col, 2), card)

		var circle_center := Vector2(card.position.x + card.size.x * 0.5, card.position.y + 38.0)
		if sid == CarPaintCatalog.AUTO_ID:
			draw_circle(circle_center + Vector2(-9.0, 3.0), 15.0, Color("#ff6f61"))
			draw_circle(circle_center + Vector2(9.0, 3.0), 15.0, Color("#39d9a0"))
			draw_circle(circle_center + Vector2(0.0, -8.0), 15.0, Color("#9b6dff"))
		else:
			draw_circle(circle_center, 24.0, col)
		draw_arc(circle_center, 24.0, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.18), 2.0)

		var name_col := Color("#2a0d50") if is_owned else Color("#5a4a7a")
		draw_string(font, Vector2(card.position.x, card.position.y + 74.0), tr("SKIN_" + sid.to_upper()), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 12, name_col)

		var buy_rect: Rect2 = _skin_buy_rect(card)
		if is_selected:
			draw_style_box(_style("skin_sel_bg", Color("#7a35c8"), 8.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 20.0), tr("SKIN_SELECTED"), HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 12, Color(1.0, 1.0, 1.0))
		elif is_owned:
			draw_style_box(_style("skin_own_bg", Color("#39d98a"), 8.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 20.0), tr("SKIN_SELECT"), HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 12, Color("#0d2a1a"))
		else:
			var affordable: bool = coins >= cost
			var btn_c := Color("#a855f7") if affordable else Color("#c8a8f0")
			draw_style_box(_style("skin_buy_%d_%d_%s" % [ci, int(affordable), sid], btn_c, 8.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 20.0), tr("COST_COIN") % cost, HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 11, Color(1.0, 1.0, 1.0) if affordable else Color("#6a4a8a"))
			_draw_unaffordable_lock(buy_rect, affordable, Color("#4a2a6a"))

	draw_string(font, Vector2(panel.position.x + 14.0, panel.position.y + 386.0), tr("PLATE_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 28.0, 15, Color("#2a0d50"))
	var plate_options := LicensePlate.options()
	for choice_index in range(plate_options.size()):
		var option := String(plate_options[choice_index])
		var choice_rect := _license_plate_choice_rect(panel, choice_index)
		var selected := option == license_plate_text
		var fill := Color("#39d98a") if selected else Color("#e8d8f8")
		var border := Color("#16875a") if selected else Color("#c8a8f0")
		draw_style_box(_style("plate_choice_%s_%s" % [option, str(selected)], fill, 9.0, border, 2), choice_rect)
		draw_string(font, Vector2(choice_rect.position.x, choice_rect.position.y + 27.0), option, HORIZONTAL_ALIGNMENT_CENTER, choice_rect.size.x, 12, Color("#0d3b2a") if selected else Color("#4a2a7a"))
