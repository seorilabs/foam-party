extends Control

# --- product-core (pure gameplay rules), referenced via res://core symlink ---
const GameConfig = preload("res://core/domain/game_config.gd")
const DirtPatch = preload("res://core/domain/dirt_patch.gd")
const WashParticle = preload("res://core/domain/wash_particle.gd")
const SkinCatalog = preload("res://core/domain/skin_catalog.gd")
const Scoring = preload("res://core/use_cases/scoring.gd")
const Economy = preload("res://core/use_cases/economy.gd")
const Coaching = preload("res://core/use_cases/coaching.gd")
const DailyMission = preload("res://core/use_cases/daily_mission.gd")
const BestTime = preload("res://core/use_cases/best_time.gd")
const WashRules = preload("res://core/use_cases/wash_rules.gd")
const DirtProgression = preload("res://core/use_cases/dirt_progression.gd")
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
const DIRT_TYPES := GameConfig.DIRT_TYPES
const CAR_TYPES := GameConfig.CAR_TYPES
const CLEAN_DAMAGE_RATE := GameConfig.CLEAN_DAMAGE_RATE
const COMBO_WINDOW := GameConfig.COMBO_WINDOW
const STAR3_TIME := GameConfig.STAR3_TIME
const STAR3_COMBO := GameConfig.STAR3_COMBO
const STAR2_TIME := GameConfig.STAR2_TIME
const STAR_WARN_SECONDS := GameConfig.STAR_WARN_SECONDS
const GRADE_SLOT_EARNED := "earned"
const GRADE_SLOT_TARGET := "target"
const GRADE_SLOT_LOCKED := "locked"
const BAR_COL_START := Color(0.286, 0.655, 1.0)   # #49a7ff
const BAR_COL_END   := Color(0.224, 0.851, 0.541)  # #39d98a
const SAVE_PATH := "user://foam_party_save.cfg"
const DAILY_SAVE_PATH := "user://foam_party_daily.cfg"
const BOMB_COST := GameConfig.BOMB_COST
const UPGRADE_COSTS := GameConfig.UPGRADE_COSTS
const UPGRADE_MULTS := GameConfig.UPGRADE_MULTS
const UPGRADE_KEYS := GameConfig.UPGRADE_KEYS
const UPGRADE_MAX_LEVEL := GameConfig.UPGRADE_MAX_LEVEL
const STATE_TITLE := "title"
const STATE_PLAYING := "playing"
const GAMEPLAY_SCALE := 1.16
const GAMEPLAY_PIVOT := Vector2(195.0, 545.0)
const GAMEPLAY_OFFSET := Vector2(0.0, 0.0)
const HUD_TOP_Y := 12.0
const HUD_SAFE_PADDING := 8.0
const TOP_BUTTON_Y := 104.0
const TOP_BUTTON_SAFE_PADDING := 12.0
const TOOLBAR_Y := 744.0
const TOOL_BUTTON_Y := 764.0
const TOOL_BUTTON_HEIGHT := 72.0
const TOOL_BUTTON_BOTTOM_PADDING := 12.0
const TOOLBAR_TOP_GAP := 20.0
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
const STYLE_STREAK := "streak"
const STYLE_SWIRL := "swirl"
const STYLE_BUBBLE := "bubble"
const STYLE_FOAM := "foam"
const STYLE_SPARKLE := "sparkle"
const STYLE_CONFETTI := "confetti"
const DAILY_MISSION_POOL := GameConfig.DAILY_MISSION_POOL
const DAILY_MISSION_REWARD := GameConfig.DAILY_MISSION_REWARD

var selected_tool: String = TOOL_WATER
var dirt_patches: Array = []
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
var level_index := 1
var completed := false
var completion_burst_done := false
var _gleam_time := -1.0
const GLEAM_DURATION := 0.72
var _progress_milestone_hit := 0
var _progress_milestone_time := -1.0
var _progress_milestone_text := ""
var _progress_milestone_color := Color.WHITE
var combo_count := 0
var combo_timer := 0.0
var _halo_phase := 0.0
var best_combo := 0
var _combo_bonus_time := -10.0
var _combo_bonus_amount := 0
var level_time := 0.0
var earned_stars := 0
var combo_pop_time := -10.0
var _combo_milestone_flash_time := -10.0
var _combo_milestone_flash_color := Color.WHITE
var _combo_milestone_fanfare := ""
var _combo_milestone_count := 0
var _customer_cheer_text := ""
var _customer_cheer_time := -10.0
var best_times: Dictionary = {}
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
var _level_milestone_bonus := 0
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
var tutorial_seen := false
var show_tutorial := false
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
var daily_mission_progress := 0
var daily_mission_claimed := false
var daily_mission_date := ""
var _daily_mission_pop_time := -10.0
var _daily_progress_dirty := false
var upgrade_water := 0
var upgrade_soap := 0
var upgrade_sponge := 0
var show_upgrade_panel := false
var show_skin_panel := false
var _skin_panel_tab := 0
var skin_water := "classic"
var skin_air := "classic"
var skin_soap := "classic"
var skin_sponge := "classic"
var owned_skins: Dictionary = {"classic": true}
var _nozzle_skins: Dictionary = SkinCatalog.catalog()
var _main_save_dirty := false
var _daily_save_timer: Timer = null

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
var _hint_patch: DirtPatch = null
var car_shapes: Dictionary = {}
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
		tutorial_seen = bool(config.get_value("settings", "tutorial_seen", false))
		upgrade_water = clampi(int(config.get_value("upgrades", "water", 0)), 0, UPGRADE_MAX_LEVEL)
		upgrade_soap = clampi(int(config.get_value("upgrades", "soap", 0)), 0, UPGRADE_MAX_LEVEL)
		upgrade_sponge = clampi(int(config.get_value("upgrades", "sponge", 0)), 0, UPGRADE_MAX_LEVEL)
		skin_water = String(config.get_value("skins", "water", "classic"))
		skin_air = String(config.get_value("skins", "air", "classic"))
		skin_soap = String(config.get_value("skins", "soap", "classic"))
		skin_sponge = String(config.get_value("skins", "sponge", "classic"))
		var raw_owned: Variant = config.get_value("skins", "owned", {})
		owned_skins = {"classic": true}
		if raw_owned is Dictionary:
			for k in (raw_owned as Dictionary):
				owned_skins[String(k)] = true
		var stored_best: Variant = config.get_value("game", "best_times", {})
		if stored_best is Dictionary:
			best_times = {}
			for key in (stored_best as Dictionary):
				best_times[int(key)] = float(stored_best[key])
		main_claimed_date = String(config.get_value("daily", "claimed_date", ""))
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
	daily_mission_progress = clampi(int(daily_config.get_value("daily", "progress", 0)), 0, daily_mission_target)
	daily_mission_claimed = bool(daily_config.get_value("daily", "claimed", false))
	if daily_mission_claimed or daily_mission_progress >= daily_mission_target or main_claimed_date == today:
		daily_mission_claimed = true
		if daily_mission_progress < daily_mission_target:
			daily_mission_progress = daily_mission_target
	daily_mission_date = saved_date
	if main_save_ok and daily_mission_claimed and main_claimed_date != today:
		coins += DAILY_MISSION_REWARD
		_main_save_dirty = true


func _save_progress() -> Error:
	if not persistence_enabled:
		return OK
	var config := ConfigFile.new()
	config.set_value("game", "level", level_index)
	config.set_value("game", "coins", coins)
	config.set_value("game", "total_stars", total_stars)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "tutorial_seen", tutorial_seen)
	config.set_value("game", "best_times", best_times)
	config.set_value("daily", "claimed_date", daily_mission_date if daily_mission_claimed else "")
	config.set_value("upgrades", "water", upgrade_water)
	config.set_value("upgrades", "soap", upgrade_soap)
	config.set_value("upgrades", "sponge", upgrade_sponge)
	config.set_value("skins", "water", skin_water)
	config.set_value("skins", "air", skin_air)
	config.set_value("skins", "soap", skin_soap)
	config.set_value("skins", "sponge", skin_sponge)
	config.set_value("skins", "owned", owned_skins)
	return config.save(SAVE_PATH)


func _save_daily() -> Error:
	if not persistence_enabled:
		return OK
	var config := ConfigFile.new()
	config.set_value("daily", "type", daily_mission_type)
	config.set_value("daily", "label", daily_mission_label)
	config.set_value("daily", "target", daily_mission_target)
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


# Forward a catalog-built event through the analytics port. Call sites use the
# pure-core ContentEvents or FtueEvents builders so names and params stay locked.
func _emit_analytics(ev: Dictionary) -> void:
	analytics.log_event(ev["name"], ev["params"])


func start_game() -> void:
	game_state = STATE_PLAYING
	_emit_analytics(ContentEvents.game_start(level_index))
	_mark_level_started()
	if not tutorial_seen:
		_show_tutorial("first_run")
	queue_redraw()


func _mark_level_started() -> void:
	if _level_started:
		return
	_level_started = true
	_emit_analytics(ContentEvents.level_start(level_index, car_type))


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
	elif show_pause:
		show_pause = false  # back on the pause menu = resume
	elif show_tutorial:
		_dismiss_tutorial()
	elif show_upgrade_panel:
		show_upgrade_panel = false
	elif show_skin_panel:
		show_skin_panel = false
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
	if game_state == STATE_PLAYING and not completed and not show_tutorial and not show_pause and not show_quit_confirm:
		level_time += delta
		_check_star_time_loss()
		var _warn_time := _grade_time_to_downgrade()
		var _in_warn := _warn_time >= 0.0 and _warn_time <= STAR_WARN_SECONDS
		if _in_warn and not _prev_in_warn_zone:
			audio.play_star_warn()
		_prev_in_warn_zone = _in_warn
		if STAR2_TIME > 0.0:
			var _patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
			var _pzone := 3 if _patience > 0.65 else (2 if _patience > 0.35 else (1 if _patience > 0.1 else 0))
			# Policy: one alert per downgrade event. Patience decreases linearly
			# over 140s so multi-zone skips in one frame are not a realistic
			# concern; a single alert per event is the correct UX choice.
			if _pzone < _prev_patience_zone:
				audio.play_patience_warn()
			_prev_patience_zone = _pzone
		if combo_timer > 0.0:
			combo_timer -= delta
			if combo_timer <= 0.0:
				combo_timer = 0.0
				if combo_count >= 2:
					_spawn_combo_break_burst()
				combo_count = 0
				_last_milestone_haptic_combo = -1
			elif combo_count >= STAR3_COMBO:
				var urgency := clampf(1.0 - combo_timer / maxf(COMBO_WINDOW, 0.001), 0.0, 1.0)
				_halo_phase = fmod(_halo_phase + delta * (9.0 + urgency * 6.0) * TAU, TAU)
	else:
		var _wt := _grade_time_to_downgrade()
		_prev_in_warn_zone = _wt >= 0.0 and _wt <= STAR_WARN_SECONDS
		if STAR2_TIME > 0.0:
			var _patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
			_prev_patience_zone = 3 if _patience > 0.65 else (2 if _patience > 0.35 else (1 if _patience > 0.1 else 0))

	if is_washing and not completed and game_state == STATE_PLAYING and not show_tutorial:
		_apply_tool_at(pointer_position, delta)

	_update_wash_trail(delta)
	_update_dirt_motion(delta)
	_update_particles(delta)
	_update_clean_progress()
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
		particles.append(WashParticle.new(
			badge_center + offset,
			Vector2.from_angle(angle) * speed,
			rng.randf_range(0.28, 0.46),
			rng.randf_range(4.0, 7.5),
			fizzle_col,
			STYLE_SPARKLE
		))
	audio.play_combo_break()


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
			if _point_in_wash_area(design_point):
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
			if _point_in_wash_area(touch_point):
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
	_set_gameplay_draw_transform()
	_draw_car()
	_set_design_draw_transform()
	_draw_dirt()
	_draw_particles()
	_draw_gleam()
	if game_state == STATE_TITLE:
		_draw_title_screen()
		if show_upgrade_panel:
			_draw_upgrade_panel()
		if show_skin_panel:
			_draw_skin_panel()
	else:
		_draw_wash_trail()
		_draw_tool_cursor()
		# One compact summary row: stars, customer mood, and daily mission.
		_draw_grade_tracker()
		_draw_customer_patience()
		_draw_daily_mission()
		_draw_tool_hint()
		_draw_combo_badge()
		_draw_bomb_button()
		_draw_toolbar()
		_draw_completion_panel()
		_draw_combo_milestone_flash()
	# Playing HUD exposes one pause/settings entry only. Sound and guide actions
	# live inside that sheet; title-screen shortcuts remain available before play.
	if game_state == STATE_PLAYING and not completed and not show_tutorial and not show_pause and not show_quit_confirm:
		_draw_pause_entry()
	elif game_state == STATE_TITLE and not (show_upgrade_panel or show_skin_panel):
		_draw_top_buttons()
	if show_tutorial:
		_draw_tutorial()
	_draw_pause_menu()
	_draw_quit_confirm()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func reset_game(new_level: int, load_reason: String = "manual") -> void:
	_emit_analytics(FtueEvents.level_load_start(new_level, load_reason))
	level_index = new_level
	_level_started = false
	completed = false
	completion_burst_done = false
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
	best_combo = 0
	level_time = 0.0
	# Sync _prev_patience_zone immediately after level_time reset so there is
	# no gap between the two values that could produce a false downgrade on
	# the first playing frame. With level_time=0 this always evaluates to 3.
	if STAR2_TIME > 0.0:
		var _p0 := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
		_prev_patience_zone = 3 if _p0 > 0.65 else (2 if _p0 > 0.35 else (1 if _p0 > 0.1 else 0))
	else:
		_prev_patience_zone = 3
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
	_customer_cheer_text = ""
	_customer_cheer_time = -10.0
	is_new_record = false
	record_pop_time = -10.0
	_progress_milestone_hit = 0
	_progress_milestone_time = -1.0
	_progress_milestone_text = ""
	_progress_milestone_color = Color.WHITE
	_level_milestone_bonus = 0
	_stop_tool_loop()
	particles.clear()
	_set_car_palette()
	_spawn_dirt()
	_update_clean_progress()
	_emit_analytics(FtueEvents.level_load_complete(level_index, car_type, load_reason))
	if game_state == STATE_PLAYING:
		_mark_level_started()
	queue_redraw()


func get_patch_count_for_test() -> int:
	return dirt_patches.size()


func get_clean_progress_for_test() -> float:
	return clean_progress


func get_selected_tool_label_for_test() -> String:
	return tool_labels[selected_tool]


func get_audio_stream_count_for_test() -> int:
	return audio.get_stream_count()


func get_combo_for_test() -> int:
	return combo_count


func get_best_combo_for_test() -> int:
	return best_combo


func get_level_time_for_test() -> float:
	return level_time


func calc_stars_for_test() -> int:
	return _calc_stars()


func get_grade_slot_state_for_test(slot_index: int) -> String:
	return _grade_slot_state(slot_index)


func get_grade_time_to_downgrade_for_test() -> float:
	return _grade_time_to_downgrade()


func get_car_type_for_test() -> String:
	return car_type


func get_coins_for_test() -> int:
	return coins


func get_wash_trail_count_for_test() -> int:
	return wash_trail.size()


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


func _set_design_draw_transform() -> void:
	draw_set_transform(canvas_origin, 0.0, Vector2(canvas_scale, canvas_scale))


func _set_gameplay_draw_transform() -> void:
	var gameplay_origin := GAMEPLAY_OFFSET + GAMEPLAY_PIVOT * (1.0 - GAMEPLAY_SCALE)
	draw_set_transform(canvas_origin + gameplay_origin * canvas_scale, 0.0, Vector2(canvas_scale * GAMEPLAY_SCALE, canvas_scale * GAMEPLAY_SCALE))


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
		reset_game(level_index + 1, "next")
		_save_progress()
		_play_ui_select()
	elif keycode == KEY_R and completed:
		reset_game(level_index, "retry")
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

	if show_pause:
		if _pause_button_rect(0).has_point(point):
			show_pause = false
			_play_ui_select()
			queue_redraw()
		elif _pause_button_rect(1).has_point(point):
			_toggle_sound()
			queue_redraw()
		elif _pause_button_rect(2).has_point(point):
			show_pause = false
			_tutorial_returns_to_pause = true
			_show_tutorial("pause_guide")
			_play_ui_select()
			queue_redraw()
		elif _pause_button_rect(3).has_point(point):
			_go_home()
		elif _pause_button_rect(4).has_point(point):
			show_pause = false
			show_quit_confirm = true
			_play_ui_select()
			queue_redraw()
		return true

	if show_tutorial:
		_dismiss_tutorial()
		return true

	if game_state == STATE_TITLE:
		if show_upgrade_panel:
			_handle_upgrade_panel_tap(point)
			return true
		if show_skin_panel:
			_handle_skin_panel_tap(point)
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
		elif _get_title_sound_rect().has_point(point):
			_toggle_sound()
		elif _get_title_help_rect().has_point(point):
			_show_tutorial("title_help")
			_play_ui_select()
		return true

	if completed and _double_offer_shown and not _double_claimed and ads != null and ads.is_rewarded_ready("level_reward_2x") and _get_double_rect().has_point(point):
		_play_ui_select()
		_try_double_coins()
		return true

	if completed and _get_retry_rect().has_point(point):
		_maybe_show_game_over_interstitial()
		reset_game(level_index, "retry")
		_play_ui_select()
		return true

	if completed and _get_next_rect().has_point(point):
		_maybe_show_game_over_interstitial()
		reset_game(level_index + 1, "next")
		_save_progress()
		_play_ui_select()
		return true

	if not completed and _get_pause_entry_rect().has_point(point):
		show_pause = true
		is_washing = false
		_stop_tool_loop()
		_play_ui_select()
		queue_redraw()
		return true

	if not completed and _get_bomb_rect().has_point(point):
		# A: the free-via-ad bomb is offered whenever rewarded inventory is ready and
		# the per-level cap is not hit — no longer gated on being out of coins. This
		# is what actually surfaces the rewarded ad, since a cleared level usually
		# leaves the player able to afford the coin price.
		if _free_ad_bomb_available():
			ads.show_rewarded("foam_bomb_free", _on_foam_bomb_reward)
		elif coins >= BOMB_COST:
			if apply_foam_bomb():
				_bomb_press_time = float(Time.get_ticks_msec()) / 1000.0
			else:
				audio.play_bomb_deny()
		else:
			# No ad ready (or cap reached) and can't afford: deny.
			audio.play_bomb_deny()
		return true

	for index in range(tool_ids.size()):
		if _get_tool_rect(index).has_point(point):
			selected_tool = tool_ids[index]
			_tool_select_time = float(Time.get_ticks_msec()) / 1000.0
			_play_ui_select()
			is_washing = false
			return true

	return false


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


func _show_tutorial(source: String) -> void:
	show_tutorial = true
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


func apply_foam_bomb(free := false) -> bool:
	# free=true is granted by a rewarded ad (no coin cost). Otherwise coins pay.
	if completed or (not free and coins < BOMB_COST):
		return false
	var applied := false
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
		var center := _patch_center(patch)
		for bubble_index in range(3):
			var offset := Vector2(rng.randf_range(-patch.radius, patch.radius), rng.randf_range(-patch.radius, patch.radius))
			particles.append(WashParticle.new(center + offset, Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-40.0, -16.0)), rng.randf_range(0.6, 1.1), rng.randf_range(4.0, 9.0), Color.from_hsv(rng.randf(), 0.12, 1.0, 0.85), STYLE_BUBBLE))
	if not applied:
		return false
	if not free:
		coins -= BOMB_COST
	audio.play_bomb()
	_emit_analytics(ContentEvents.foam_bomb_use(level_index, free, BOMB_COST))
	_save_progress()
	return true


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
	_emit_analytics(ContentEvents.reward_double_coins(level_index, bonus))
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
	car_type = CAR_TYPES[(level_index - 1) % CAR_TYPES.size()]
	var hue := fmod(0.10 + float(level_index - 1) * 0.18, 1.0)
	if car_type == "sports":
		car_color = Color.from_hsv(hue, 0.85, 1.0)
	elif car_type == "truck":
		car_color = Color.from_hsv(hue, 0.42, 0.9)
	else:
		car_color = Color.from_hsv(hue, 0.62, 1.0)


func _spawn_dirt() -> void:
	dirt_patches.clear()
	_hint_patch = null
	rng.seed = 42690 + int(level_index) * 97

	var positions := [
		Vector2(102.0, 462.0), Vector2(154.0, 439.0), Vector2(218.0, 439.0), Vector2(283.0, 462.0),
		Vector2(89.0, 526.0), Vector2(137.0, 505.0), Vector2(198.0, 498.0), Vector2(256.0, 506.0), Vector2(314.0, 529.0),
		Vector2(80.0, 580.0), Vector2(126.0, 598.0), Vector2(179.0, 584.0), Vector2(226.0, 596.0), Vector2(280.0, 584.0), Vector2(330.0, 596.0),
		Vector2(116.0, 645.0), Vector2(168.0, 662.0), Vector2(221.0, 650.0), Vector2(276.0, 664.0),
		Vector2(138.0, 382.0), Vector2(199.0, 369.0), Vector2(251.0, 385.0),
		Vector2(102.0, 620.0), Vector2(303.0, 620.0)
	]

	var pool: Array = positions.duplicate()
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap_value: Vector2 = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = swap_value

	# Per-car dirt patterns: sports cars skew toward oil and dust,
	# trucks skew toward mud and bugs, and city cars stay balanced.
	var type_pool: Array
	var radius_min := 13.0
	var radius_max := 24.0
	var health_base_min := 70.0
	var health_base_max := 120.0
	match car_type:
		"sports":
			type_pool = ["oil", "dust", "oil", "dust", "road_grime", "leaf", "dust", "bug", "mud"]
			radius_min = 11.0
			radius_max = 20.0
			health_base_min = 80.0
			health_base_max = 135.0
		"truck":
			type_pool = ["mud", "mud", "bug", "leaf", "mud", "poop", "dust", "road_grime", "leaf"]
			radius_min = 15.0
			radius_max = 28.0
			health_base_min = 85.0
			health_base_max = 145.0
		_:
			type_pool = DIRT_TYPES.duplicate()
	type_pool = DirtProgression.filter_pool_for_level(type_pool, level_index)

	var spawn_count: int = min(pool.size(), 18 + level_index * 2)
	var health_scale := 1.0 + float(level_index - 1) * 0.06
	for index in range(spawn_count):
		var kind: String = type_pool[index % type_pool.size()]
		var base_position: Vector2 = _gameplay_point(pool[index])
		var jitter := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0)) * GAMEPLAY_SCALE
		var radius := _gameplay_length(rng.randf_range(radius_min, radius_max))
		var health := rng.randf_range(health_base_min, health_base_max) * health_scale
		if kind == "oil" or kind == "bug":
			health += 25.0 * health_scale
		elif kind == "poop":
			health += 15.0 * health_scale
		elif kind == "road_grime":
			health += 20.0 * health_scale
		var patch := DirtPatch.new(kind, base_position + jitter, radius, health, rng.randf_range(0.0, 10.0))
		dirt_patches.append(patch)

	initial_dirt_total = 0.0
	for patch in dirt_patches:
		initial_dirt_total += (patch as DirtPatch).max_health
	initial_dirt_total = max(1.0, initial_dirt_total)


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
		_spawn_tool_particles(point, delta)


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
	WashRules.apply_water(patch, delta, proximity, _upgrade_mult("water"))


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
		combo_count += 1
		combo_timer = COMBO_WINDOW
		best_combo = max(best_combo, combo_count)
		if combo_count == STAR3_COMBO and not _star3_combo_unlocked:
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
		if combo_count == STAR3_COMBO:
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
		if not daily_mission_claimed and patch.kind == daily_mission_type:
			daily_mission_progress += 1
			if daily_mission_progress >= daily_mission_target:
				daily_mission_progress = daily_mission_target
				daily_mission_claimed = true
				coins += DAILY_MISSION_REWARD
				_emit_analytics(ContentEvents.daily_mission_claim(daily_mission_type, DAILY_MISSION_REWARD))
				_daily_mission_pop_time = float(Time.get_ticks_msec()) / 1000.0
				var daily_err := _save_daily()
				if daily_err != OK:
					_daily_progress_dirty = true
				var prog_err := _save_progress()
				if prog_err != OK:
					_main_save_dirty = true
				if OS.has_feature("mobile"):
					Input.vibrate_handheld(60)
			else:
				_daily_progress_dirty = true
	_spawn_removal_burst(burst_center, burst_radius)
	if not completed:
		_play_removal_sound()
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(28)


func _spawn_removal_burst(center: Vector2, radius: float) -> void:
	# Burst escalates with the active combo so each successive removal feels
	# bigger than the last: more particles, faster spread, and a colour shift
	# from clean white/blue toward a celebratory gold once the combo runs hot.
	var combo: int = max(combo_count, 1)
	var intensity: float = clampf(float(combo - 1) / 8.0, 0.0, 1.0)
	var hot: bool = combo >= STAR3_COMBO
	var cool_tint := Color(1.0, 1.0, 1.0, 0.95)
	var hot_tint := Color(1.0, 0.84, 0.36, 0.98)
	var sparkle_tint := cool_tint.lerp(hot_tint, intensity)

	var sparkle_count: int = 4 + min(combo, 10)
	for index in range(sparkle_count):
		var angle := rng.randf_range(0.0, TAU)
		var offset := Vector2.from_angle(angle) * radius * rng.randf_range(0.2, 0.9)
		var lift := rng.randf_range(-26.0, -8.0) * (1.0 + intensity * 0.6)
		var sparkle := WashParticle.new(center + offset, Vector2(0.0, lift), rng.randf_range(0.4, 0.75) + intensity * 0.2, rng.randf_range(3.5, 6.5) + intensity * 2.0, sparkle_tint, STYLE_SPARKLE)
		particles.append(sparkle)

	var bubble_count: int = 5 + min(int(round(float(combo) * 0.7)), 8)
	for index in range(bubble_count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(40.0, 120.0) * (1.0 + intensity * 0.5)
		var bubble := WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.3, 0.6), rng.randf_range(2.5, 5.5), Color(0.85, 0.96, 1.0, 0.85), STYLE_BUBBLE)
		particles.append(bubble)

	# Expanding shockwave ring grows with the combo to punctuate the pop.
	particles.append(WashParticle.new(center, Vector2.ZERO, 0.3 + intensity * 0.2, 4.0 + radius * (0.5 + intensity * 0.6), sparkle_tint, STYLE_RING))

	# Hot combos throw celebratory gold confetti so a streak reads as a payoff.
	if hot:
		var confetti_count: int = min(combo - STAR3_COMBO + 2, 7)
		for index in range(confetti_count):
			var angle := rng.randf_range(-PI, 0.0)
			var speed := rng.randf_range(120.0, 230.0)
			var color := Color.from_hsv(rng.randf_range(0.09, 0.14), 0.75, 1.0, 0.95)
			particles.append(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.6, 1.1), rng.randf_range(3.5, 6.5), color, STYLE_CONFETTI))

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
		particles.append(WashParticle.new(center, Vector2.from_angle(angle) * speed, rng.randf_range(0.35, 0.55), rng.randf_range(3.5, 6.0), pop_color, STYLE_SPARKLE))


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

	var active := is_washing and not completed and game_state == STATE_PLAYING and not show_tutorial
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
	return Coaching.tool_radius(tool_id)


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
	for index in range(5):
		var angle := rng.randf_range(-PI, 0.0)
		var speed := rng.randf_range(60.0, 170.0)
		var velocity := Vector2.from_angle(angle) * speed
		var jitter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0))
		particles.append(WashParticle.new(point + jitter, velocity, rng.randf_range(0.3, 0.6), rng.randf_range(2.0, 4.5), Color("#89d8ff"), STYLE_DROPLET))
	particles.append(WashParticle.new(point, Vector2.ZERO, 0.28, 6.0, Color(1.0, 1.0, 1.0, 0.5), STYLE_RING))
	if rng.randf() < 0.5:
		particles.append(WashParticle.new(point + Vector2(rng.randf_range(-12.0, 12.0), -6.0), Vector2(0.0, -16.0), rng.randf_range(0.4, 0.7), rng.randf_range(8.0, 14.0), Color(1.0, 1.0, 1.0, 0.22), STYLE_MIST))


func _spawn_air_particles(point: Vector2) -> void:
	for index in range(3):
		var angle := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var speed := rng.randf_range(120.0, 230.0)
		var velocity := Vector2.from_angle(angle) * speed + Vector2(0.0, rng.randf_range(-36.0, -8.0))
		var jitter := Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))
		particles.append(WashParticle.new(point + jitter, velocity, rng.randf_range(0.2, 0.45), rng.randf_range(7.0, 13.0), Color(1.0, 1.0, 1.0, 0.55), STYLE_STREAK))
	if rng.randf() < 0.6:
		particles.append(WashParticle.new(point + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-16.0, 16.0)), Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-60.0, -20.0)), rng.randf_range(0.35, 0.6), rng.randf_range(6.0, 11.0), Color(1.0, 1.0, 1.0, 0.4), STYLE_SWIRL))


func _spawn_soap_particles(point: Vector2) -> void:
	for index in range(5):
		var jitter := Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-14.0, 14.0))
		var velocity := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-46.0, -14.0))
		var tint := Color.from_hsv(rng.randf(), 0.12, 1.0, 0.85)
		particles.append(WashParticle.new(point + jitter, velocity, rng.randf_range(0.5, 1.0), rng.randf_range(3.0, 8.0), tint, STYLE_BUBBLE))


func _spawn_sponge_particles(point: Vector2) -> void:
	for index in range(3):
		var jitter := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 14.0))
		particles.append(WashParticle.new(point + jitter, Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-8.0, 4.0)), rng.randf_range(0.4, 0.8), rng.randf_range(5.0, 10.0), Color(1.0, 1.0, 1.0, 0.7), STYLE_FOAM))
	if rng.randf() < 0.7:
		particles.append(WashParticle.new(point + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-12.0, 8.0)), Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-36.0, -12.0)), rng.randf_range(0.4, 0.8), rng.randf_range(2.5, 5.0), Color(0.95, 1.0, 1.0, 0.8), STYLE_BUBBLE))


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index] as WashParticle
		particle.ttl -= delta
		particle.position += particle.velocity * delta
		if particle.style == STYLE_DROPLET:
			particle.velocity.y += 320.0 * delta
		elif particle.style == STYLE_RING or particle.style == STYLE_MIST:
			particle.radius += delta * (60.0 if particle.style == STYLE_RING else 24.0)
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
		_gleam_time = 0.0
		is_washing = false
		earned_stars = _calc_stars()
		coin_reward = _calc_coin_reward(earned_stars)
		_level_milestone_bonus = _calc_level_milestone_bonus(level_index)
		coin_reward += _level_milestone_bonus
		coins += coin_reward
		total_stars += earned_stars
		# B: latch whether to offer the level-end "double coins" rewarded ad, so the
		# completion panel reserves a stable button row for the life of this screen.
		_double_offer_shown = ads != null and ads.is_rewarded_ready("level_reward_2x")
		_register_best_time()
		_emit_analytics(ContentEvents.level_complete(
			level_index, earned_stars, int(level_time), best_combo, coin_reward, is_new_record
		))
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


# Star time threshold tightens 1.5% per level after the first (floor at 60% of base).
# This ensures experienced players face a gradually rising skill ceiling.
func _star_time_threshold(tier: int) -> float:
	return Scoring.star_time_threshold(tier, level_index)


func _calc_stars() -> int:
	return Scoring.calc_stars(level_time, best_combo, level_index)


# Live state of one star slot in the HUD grade tracker (0 = first star).
# earned: counted in the grade right now. target: still reachable but a
# condition is unmet (3rd star needs the combo gate). locked: no longer reachable.
func _grade_slot_state(slot_index: int) -> String:
	return Scoring.grade_slot_state(slot_index, level_time, best_combo, level_index, GRADE_SLOT_EARNED, GRADE_SLOT_TARGET, GRADE_SLOT_LOCKED)


# Seconds until the next star is lost, or -1 once only the floor star remains.
func _grade_time_to_downgrade() -> float:
	return Scoring.grade_time_to_downgrade(level_time, level_index)


# Star slot (0-based) whose threshold is approaching next, or -1 when none.
func _grade_at_risk_slot() -> int:
	return Scoring.grade_at_risk_slot(level_time, level_index)


func _register_best_time() -> void:
	var previous_best: float = _best_time_for_level(level_index)
	is_new_record = BestTime.is_new_record(previous_best, level_time)
	if is_new_record:
		best_times[level_index] = level_time
		record_pop_time = float(Time.get_ticks_msec()) / 1000.0
		audio.play_record()


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
		particles.append(WashParticle.new(
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
		particles.append(particle)
	if is_new_record:
		_spawn_record_burst()
	if level_time > 0.0 and level_time < 60.0:
		_spawn_speedrun_burst(particles)


func _spawn_speedrun_burst(p: Array) -> void:
	var center := DESIGN_SIZE * 0.5
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		var speed := rng.randf_range(190.0, 360.0)
		var hue := rng.randf_range(0.10, 0.15)  # gold
		p.append(WashParticle.new(
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
		particles.append(WashParticle.new(Vector2(195.0, 300.0), Vector2.from_angle(angle) * speed, rng.randf_range(0.8, 1.5), rng.randf_range(4.0, 8.0), gold, STYLE_CONFETTI))
	for index in range(14):
		var angle := rng.randf_range(0.0, TAU)
		particles.append(WashParticle.new(Vector2(195.0, 290.0) + Vector2.from_angle(angle) * rng.randf_range(0.0, 60.0), Vector2(0.0, rng.randf_range(-40.0, -12.0)), rng.randf_range(0.5, 1.0), rng.randf_range(4.0, 7.0), Color(1.0, 0.95, 0.65, 0.95), STYLE_SPARKLE))


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
	draw_string(font, Vector2(badge.position.x, badge.position.y + 20.0), "%s %02d" % [car_type_labels[car_type], level_index], HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color.WHITE)

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
	return tr("DM_" + daily_mission_type.to_upper()) % daily_mission_target


func _build_car_shapes() -> void:
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


func _draw_car() -> void:
	var outline := Color("#123246")
	var shapes: Dictionary = car_shapes[car_type]
	_draw_ellipse_shape(Vector2(195.0, 668.0), Vector2(168.0, 20.0), Color(0.0, 0.0, 0.0, 0.16))

	var wheel_y := 642.0
	var wheel_radius := 31.0
	if car_type == "truck":
		wheel_y = 636.0
		wheel_radius = 35.0
	elif car_type == "sports":
		wheel_y = 646.0
		wheel_radius = 29.0
	for wheel_x in [98.0, 292.0]:
		draw_circle(Vector2(wheel_x, wheel_y), wheel_radius, Color("#1d2b33"))
		draw_circle(Vector2(wheel_x, wheel_y), wheel_radius * 0.48, Color("#cfd8dc"))

	var silhouette: PackedVector2Array = shapes["silhouette"]
	draw_colored_polygon(silhouette, car_color)
	_draw_closed_outline(silhouette, outline, 5.0)

	var bumper: PackedVector2Array = shapes["bumper"]
	draw_colored_polygon(bumper, Color("#d6dde1") if car_type == "truck" else Color("#e7eef2"))
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

	var plate := Rect2(159.0, 582.0, 72.0, 22.0)
	draw_rect(plate, Color("#f7fbff"))
	draw_rect(plate, outline, false, 2.5)
	draw_string(_font(), Vector2(plate.position.x, plate.position.y + 16.0), "FOAM", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 12, outline)


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
			_draw_oil_patch(center, patch.radius, strength)
		elif patch.kind == "bug":
			_draw_bug_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "poop":
			_draw_poop_patch(center, patch.radius, strength, patch.seed_offset)
		elif patch.kind == "road_grime":
			_draw_road_grime_patch(center, patch.radius, strength, patch.seed_offset)

		if patch.wetness > 0.18:
			_draw_wet_gloss(center, patch.radius, patch.wetness)
		if patch.soap > 0.05:
			_draw_soap_foam(center, patch.radius, patch.soap)

	# Coaching hints are drawn last so they stay above any overlapping dirt.
	for raw_patch in dirt_patches:
		var hint_patch := raw_patch as DirtPatch
		if _is_patch_removed(hint_patch):
			continue
		if hint_patch.hint_time > 0.0 and hint_patch.hint_tool != "":
			_draw_patch_hint(hint_patch, _patch_center(hint_patch) + Vector2(hint_patch.shake_x, 0.0))


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


func _draw_oil_patch(center: Vector2, radius: float, strength: float) -> void:
	draw_circle(center, radius * 1.1, Color(0.03, 0.05, 0.08, 0.82 * strength))
	draw_circle(center + Vector2(radius * 0.25, -radius * 0.28), radius * 0.28, Color(0.2, 0.35, 0.5, 0.5 * strength))
	draw_circle(center + Vector2(-radius * 0.18, radius * 0.12), radius * 0.42, Color(0.06, 0.12, 0.16, 0.55 * strength))


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
		elif particle.style == STYLE_RING:
			draw_arc(particle.position, particle.radius, 0.0, TAU, 22, color, 2.5)
		elif particle.style == STYLE_MIST:
			draw_circle(particle.position, particle.radius, color)
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


func _draw_title_screen() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.21, 0.69, 0.74, 0.82))
	for bubble_index in range(8):
		var bubble_x := 40.0 + float(bubble_index) * 45.0
		var bubble_y := 120.0 + sin(float(bubble_index) * 1.9) * 50.0
		draw_circle(Vector2(bubble_x, bubble_y), 14.0 + float(bubble_index % 3) * 8.0, Color(1.0, 1.0, 1.0, 0.18))

	draw_circle(Vector2(130.0, 268.0), 44.0, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(Vector2(258.0, 252.0), 30.0, Color(1.0, 1.0, 1.0, 0.3))
	draw_circle(Vector2(220.0, 296.0), 20.0, Color(1.0, 1.0, 1.0, 0.28))
	draw_string(font, Vector2(2.0, 332.0), "Foam Party", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 52, Color("#0d3b55"))
	draw_string(font, Vector2(0.0, 328.0), "Foam Party", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 52, Color.WHITE)
	draw_string(font, Vector2(0.0, 368.0), tr("TITLE_SUBTITLE"), HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 18, Color("#0d3b55"))

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
			tr("DM_REWARD") % DAILY_MISSION_REWARD, HORIZONTAL_ALIGNMENT_RIGHT, dm_rect.size.x - 10.0, 11,
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
		start_label = tr("CONTINUE") % [car_type_labels[car_type], level_index]
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
	daily_mission_label = m["label"]
	daily_mission_progress = 0
	daily_mission_claimed = false


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
			var pop_text := tr("DM_CLEAR_POP") % DAILY_MISSION_REWARD
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
	var panel := Rect2(30.0, 176.0, 330.0, 452.0)
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 44.0), tr("TUT_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color("#123246"))

	var rows := [
		[TOOL_AIR, tr("TOOL_AIR"), tr("TUT_AIR")],
		[TOOL_WATER, tr("TOOL_WATER"), tr("TUT_WATER")],
		[TOOL_SOAP, tr("TOOL_SOAP"), tr("TUT_SOAP")],
		[TOOL_SPONGE, tr("TOOL_SPONGE"), tr("TUT_SPONGE")],
	]
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var row_y := panel.position.y + 92.0 + float(row_index) * 72.0
		draw_style_box(_style("tutorial_row", Color("#e8f3f8"), 14.0), Rect2(panel.position.x + 18.0, row_y - 26.0, panel.size.x - 36.0, 58.0))
		_draw_tool_icon(row[0], Vector2(panel.position.x + 52.0, row_y + 2.0))
		draw_string(font, Vector2(panel.position.x + 92.0, row_y - 2.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, 200.0, 17, Color("#123246"))
		draw_string(font, Vector2(panel.position.x + 92.0, row_y + 20.0), row[2], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 116.0, 13, Color("#2c6b78"))

	draw_string(font, Vector2(panel.position.x, panel.position.y + 410.0), tr("TUT_TIP") % BOMB_COST, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#2c6b78"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 436.0), tr("TUT_START"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 16, Color("#1f8a55"))


func _draw_bomb_button() -> void:
	if completed:
		return
	var font: Font = _font()
	var rect := _get_bomb_rect()
	var t := float(Time.get_ticks_msec()) / 1000.0
	var pop := 1.0 + 0.14 * exp(-(t - _bomb_press_time) * 9.0)
	if pop > 1.001:
		var c := rect.get_center()
		draw_set_transform(c * (1.0 - pop), 0.0, Vector2(pop, pop))
	var can_afford := coins >= BOMB_COST
	# A: whenever a rewarded free bomb is available (inventory ready + under the
	# per-level cap), the chip is the green "watch ad for a free bomb" affordance —
	# regardless of coin balance, so the ad actually gets shown. Falls back to the
	# coin price only when no free ad is available.
	var ad_ready := _free_ad_bomb_available()
	var bg: Color
	var style_key: String
	if ad_ready:
		bg = Color("#a8e6c0")
		style_key = "bomb_ad"
	elif can_afford:
		bg = Color("#f8f4a6")
		style_key = "bomb_on"
	else:
		bg = Color(0.55, 0.6, 0.63, 0.85)
		style_key = "bomb_off"
	draw_style_box(_style(style_key, bg, 14.0), rect)
	draw_circle(rect.position + Vector2(22.0, 17.0), 9.0, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(rect.position + Vector2(32.0, 12.0), 6.0, Color(1.0, 1.0, 1.0, 0.8))
	draw_circle(rect.position + Vector2(30.0, 22.0), 4.5, Color(1.0, 1.0, 1.0, 0.8))
	draw_string(font, Vector2(rect.position.x + 42.0, rect.position.y + 20.0), tr("BOMB_LABEL"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 42.0, 11, Color("#123246"))
	if ad_ready:
		# Play triangle + "free": tap plays a rewarded ad for a free foam bomb.
		var tx := rect.position.x + 48.0
		var ty := rect.position.y + 33.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx, ty - 6.0), Vector2(tx, ty + 6.0), Vector2(tx + 9.0, ty)]), Color("#123246"))
		draw_string(font, Vector2(rect.position.x + 60.0, rect.position.y + 38.0), tr("BOMB_FREE"), HORIZONTAL_ALIGNMENT_LEFT, 34.0, 12, Color("#0d3b2a"))
	else:
		draw_circle(rect.position + Vector2(52.0, 33.0), 6.0, Color("#ffce3d"))
		draw_circle(rect.position + Vector2(52.0, 33.0), 6.0, Color("#9a7400"), false, 1.5)
		draw_string(font, Vector2(rect.position.x + 62.0, rect.position.y + 38.0), "%d" % BOMB_COST, HORIZONTAL_ALIGNMENT_LEFT, 30.0, 13, Color("#123246"))
	if pop > 1.001:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
			text = tr("GRADE_COMBO_URGENT") % [STAR3_COMBO, secs]
		else:
			text = tr("GRADE_KEEP_STAR") % [at_risk + 1, secs]
		col = Color(1.0, 0.74, 0.36)
		col.a = blink
	elif _grade_slot_state(2) == GRADE_SLOT_TARGET:
		text = tr("GRADE_COMBO_FOR3") % STAR3_COMBO
		col = Color(1.0, 0.88, 0.55)
	else:
		text = tr("GRADE_TIME") % _format_time(level_time)
	var text_font_size := 11
	while text_font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_font_size).x > rect.size.x - 8.0:
		text_font_size -= 1
	draw_string(font, Vector2(rect.position.x + 4.0, line_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, text_font_size, col)


func _draw_customer_patience() -> void:
	if completed:
		return
	# 손님 인내 게이지: STAR2_TIME(140s)을 기준으로 1.0 → 0.0으로 감소.
	# 별점과 일일 미션 사이의 같은 높이 요약 카드에 배치한다.
	if STAR2_TIME <= 0.0:
		return
	var patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var rect := _get_customer_rect()

	draw_style_box(_style("cust_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0),
		Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("cust_chip", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	# 손님 얼굴 (카드 왼쪽)
	var face := Vector2(rect.position.x + 21.0, rect.position.y + 23.0)
	var fr := 14.0
	var face_col := Color(1.0, 0.85, 0.22).lerp(Color(1.0, 0.35, 0.22), 1.0 - patience)
	draw_circle(face, fr, face_col)
	draw_arc(face, fr, 0.0, TAU, 28, Color(0.0, 0.0, 0.0, 0.18), 1.5)

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
		if patience > 0.65:
			bar_key = "cust_bar_g"
			bar_col = Color(0.22, 0.87, 0.55)
		elif patience > 0.35:
			bar_key = "cust_bar_y"
			bar_col = Color(0.97, 0.82, 0.22)
		else:
			bar_key = "cust_bar_r"
			bar_col = Color(1.0, 0.40, 0.28)
		draw_style_box(_style(bar_key, bar_col, 5.0),
			Rect2(bar.position, Vector2(bar.size.x * patience, bar.size.y)))

	# 기분 레이블
	var font: Font = _font()
	var mood_label: String
	var mood_col := Color(0.86, 0.93, 0.97)
	if patience > 0.65:
		mood_label = tr("MOOD_HAPPY")
	elif patience > 0.35:
		mood_label = tr("MOOD_OK")
	elif patience > 0.1:
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
	var is_hot := combo_count >= STAR3_COMBO
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
	if _combo_bonus_time >= 0.0:
		var _age := float(Time.get_ticks_msec()) / 1000.0 - _combo_bonus_time
		if _age < 1.2:
			var _alpha := 1.0 - _age / 1.2
			var _rise := _age * 38.0
			draw_string(_font(), Vector2(badge.position.x + 4.0, badge.position.y - _rise - 14.0),
				tr("COIN_GAIN") % _combo_bonus_amount, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 16, Color(1.0, 0.85, 0.2, _alpha))
	# Circular timer ring — sweeps clockwise from top as the combo window drains.
	var fill_frac := clampf(combo_timer / COMBO_WINDOW, 0.0, 1.0)
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
	return [tr("RESUME"), tr("SOUND_ON") if sound_enabled else tr("SOUND_OFF"), tr("GUIDE"), tr("HOME"), tr("QUIT")]


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
	var fills := [Color("#39d98a"), Color("#7fd6e6"), Color("#a9d7ff"), Color("#f8d97a"), Color("#f2a0a0")]
	var text_cols := [Color("#0d3b2a"), Color("#0d3b55"), Color("#123246"), Color("#5b4a10"), Color("#5a1616")]
	for i in range(5):
		var r := _pause_button_rect(i)
		draw_style_box(_style("pause_sh_%d" % i, Color(0.0, 0.0, 0.0, 0.18), 14.0), Rect2(r.position + Vector2(0.0, 4.0), r.size))
		draw_style_box(_style("pause_btn_%d" % i, fills[i], 14.0), r)
		draw_string(font, Vector2(r.position.x, r.position.y + 33.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, text_cols[i])


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
	if not completed:
		return
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.35))
	var panel := Rect2(38.0, 198.0, 314.0, 232.0 + _completion_extra())
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)

	var time_now := float(Time.get_ticks_msec()) / 1000.0
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
	draw_string(font, Vector2(panel.position.x, panel.position.y + 108.0), tr("COMPLETE_SUB") % [car_type_labels[car_type], level_index, _format_time(level_time), best_combo], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#2c6b78"))

	var record_seconds: float = _best_time_for_level(level_index)
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

	if _level_milestone_bonus > 0:
		var time_now2 := float(Time.get_ticks_msec()) / 1000.0
		var milestone_chip := Rect2(panel.position.x + 10.0, panel.position.y - 14.0, 106.0, 30.0)
		var chip_color := Color("#a855f7").lerp(Color("#ec4899"), 0.5 + 0.5 * sin(time_now2 * 3.0))
		draw_style_box(_style("milestone_chip", chip_color, 15.0), milestone_chip)
		draw_string(font, Vector2(milestone_chip.position.x, milestone_chip.position.y + 21.0), tr("MILESTONE_CHIP") % [level_index, _level_milestone_bonus], HORIZONTAL_ALIGNMENT_CENTER, milestone_chip.size.x, 13, Color("#fff0ff"))

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
	return Rect2(58.0, 352.0, 274.0, 42.0)


# Pause/settings sheet: resume / sound / guide / home / quit.
func _pause_panel() -> Rect2:
	var panel_height := 416.0
	var insets := _safe_area_design_insets()
	var min_y := insets.y + 16.0
	var max_y := DESIGN_SIZE.y - insets.w - 16.0 - panel_height
	var centered_y := (DESIGN_SIZE.y - panel_height) * 0.5
	return Rect2(55.0, clampf(centered_y, min_y, maxf(min_y, max_y)), 280.0, panel_height)


func _pause_button_rect(index: int) -> Rect2:
	var panel := _pause_panel()
	var button_h := 50.0
	var gap := 10.0
	var y0 := panel.position.y + 72.0
	return Rect2(panel.position.x + 24.0, y0 + float(index) * (button_h + gap), panel.size.x - 48.0, button_h)


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
	return Rect2(58.0, 360.0 + _completion_extra(), 131.0, 46.0)


func _get_next_rect() -> Rect2:
	return Rect2(201.0, 360.0 + _completion_extra(), 131.0, 46.0)


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


func _get_bomb_rect() -> Rect2:
	# Bottom aligned with the hint chip, above the toolbar PANEL top so a bottom
	# safe-area inset never lets the panel overlap this chip.
	return Rect2(276.0, minf(688.0, _tool_button_y() - 76.0), 92.0, 46.0)


func _get_upgrade_btn_rect() -> Rect2:
	return Rect2(95.0, 600.0, 200.0, 44.0)


func _upgrade_mult(key: String) -> float:
	var lvl := 0
	if key == "water":
		lvl = upgrade_water
	elif key == "soap":
		lvl = upgrade_soap
	else:
		lvl = upgrade_sponge
	return Economy.upgrade_mult(lvl)


func _upgrade_row_y(panel: Rect2, idx: int) -> float:
	return panel.position.y + 110.0 + float(idx) * 118.0


func _upgrade_buy_rect(panel: Rect2, idx: int) -> Rect2:
	return Rect2(panel.position.x + panel.size.x - 124.0, _upgrade_row_y(panel, idx) + 32.0, 100.0, 38.0)


func _handle_upgrade_panel_tap(point: Vector2) -> void:
	var panel := Rect2(20.0, 100.0, 350.0, 520.0)
	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	if close_rect.has_point(point):
		show_upgrade_panel = false
		queue_redraw()
		_play_ui_select()
		return
	for idx in range(UPGRADE_KEYS.size()):
		if _upgrade_buy_rect(panel, idx).has_point(point):
			_try_buy_upgrade(idx)
			return


func _try_buy_upgrade(idx: int) -> void:
	var lvl := upgrade_water if idx == 0 else (upgrade_soap if idx == 1 else upgrade_sponge)
	if not Economy.can_buy_upgrade(idx, lvl, coins):
		return
	var cost: int = Economy.upgrade_cost(idx, lvl)
	coins -= cost
	if idx == 0:
		upgrade_water += 1
	elif idx == 1:
		upgrade_soap += 1
	else:
		upgrade_sponge += 1
	if _save_progress() != OK:
		coins += cost
		if idx == 0:
			upgrade_water -= 1
		elif idx == 1:
			upgrade_soap -= 1
		else:
			upgrade_sponge -= 1
		return
	_emit_analytics(ContentEvents.upgrade_purchase(UPGRADE_KEYS[idx], lvl + 1, cost))
	_play_ui_select()
	queue_redraw()


func _draw_upgrade_panel() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.05, 0.18, 0.72))
	var panel := Rect2(20.0, 100.0, 350.0, 520.0)
	draw_style_box(_style("upg_panel_shadow", Color(0.02, 0.06, 0.22, 0.5), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("upg_panel", Color("#f0f6ff"), 22.0), panel)

	draw_string(font, Vector2(panel.position.x, panel.position.y + 50.0), tr("UPG_SHOP_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#0d2a50"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 74.0), tr("COINS_LABEL") % coins, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#3a7fc1"))

	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	draw_style_box(_style("upg_close_bg", Color("#e0e9f5"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#0d2a50"))

	var tool_col := [Color("#49a7ff"), Color("#f8f4a6"), Color("#ff9f5a")]
	var upgrade_lvls := [upgrade_water, upgrade_soap, upgrade_sponge]

	for idx in range(UPGRADE_KEYS.size()):
		var lvl: int = upgrade_lvls[idx]
		var row_y := _upgrade_row_y(panel, idx)
		var row_rect := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 106.0)
		draw_style_box(_style("upg_row_%d" % idx, Color("#ddeaf8"), 14.0), row_rect)

		draw_circle(Vector2(panel.position.x + 48.0, row_y + 53.0), 22.0, tool_col[idx])
		var upg_key: String = String(UPGRADE_KEYS[idx]).to_upper()
		draw_string(font, Vector2(panel.position.x + 80.0, row_y + 28.0), tr("UPG_NAME_" + upg_key), HORIZONTAL_ALIGNMENT_LEFT, 200.0, 16, Color("#0d2a50"))
		draw_string(font, Vector2(panel.position.x + 80.0, row_y + 50.0), tr("UPG_DESC_" + upg_key), HORIZONTAL_ALIGNMENT_LEFT, 190.0, 12, Color("#2c6b78"))

		for dot_idx in range(UPGRADE_MAX_LEVEL):
			var dot_x := panel.position.x + 80.0 + float(dot_idx) * 22.0
			var dot_y := row_y + 72.0
			if dot_idx < lvl:
				draw_circle(Vector2(dot_x, dot_y), 7.0, Color("#3a9ef0"))
			else:
				draw_circle(Vector2(dot_x, dot_y), 7.0, Color("#b8cfe0"))

		var buy_rect := _upgrade_buy_rect(panel, idx)
		if lvl >= UPGRADE_MAX_LEVEL:
			draw_style_box(_style("upg_max_bg", Color("#b8cfe0"), 10.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 26.0), tr("MAX"), HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 15, Color("#6a8aaa"))
		else:
			var cost: int = UPGRADE_COSTS[idx][lvl]
			var affordable: bool = coins >= cost
			var btn_col := Color("#39d98a") if affordable else Color("#8fc4b4")
			draw_style_box(_style("upg_buy_%d" % idx, btn_col, 10.0), buy_rect)
			draw_string(font, Vector2(buy_rect.position.x, buy_rect.position.y + 26.0), tr("COST_COIN") % cost, HORIZONTAL_ALIGNMENT_CENTER, buy_rect.size.x, 14, Color("#0d2a3b") if affordable else Color("#4a7a6a"))


func _get_skin_btn_rect() -> Rect2:
	return Rect2(95.0, 652.0, 200.0, 44.0)


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


func _skin_tab_rect(panel: Rect2, tab_idx: int) -> Rect2:
	var tab_w: float = (panel.size.x - 20.0) / 4.0
	return Rect2(panel.position.x + 10.0 + tab_idx * tab_w, panel.position.y + 74.0, tab_w, 34.0)


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


func _handle_skin_panel_tap(point: Vector2) -> void:
	var panel := Rect2(15.0, 88.0, 360.0, 362.0)
	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	if close_rect.has_point(point):
		show_skin_panel = false
		queue_redraw()
		_play_ui_select()
		return
	var tab_keys: Array = [TOOL_WATER, TOOL_AIR, TOOL_SOAP, TOOL_SPONGE]
	for t in range(4):
		if _skin_tab_rect(panel, t).has_point(point):
			_skin_panel_tab = t
			queue_redraw()
			_play_ui_select()
			return
	var tool_key: String = tab_keys[_skin_panel_tab]
	var skins: Array = _nozzle_skins.get(tool_key, [])
	for ci in range(skins.size()):
		if _skin_buy_rect(_skin_card_rect(panel, ci)).has_point(point):
			_try_buy_or_select_skin(tool_key, ci)
			return


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

	# action == "buy"
	coins -= cost
	owned_skins[sid] = true
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
		owned_skins.erase(sid)
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


func _draw_skin_panel() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.05, 0.18, 0.72))
	var panel := Rect2(15.0, 88.0, 360.0, 362.0)
	draw_style_box(_style("skin_panel_shadow", Color(0.08, 0.02, 0.22, 0.5), 22.0), Rect2(panel.position + Vector2(0.0, 6.0), panel.size))
	draw_style_box(_style("skin_panel_bg", Color("#f5f0ff"), 22.0), panel)

	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), tr("SKIN_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, Color("#2a0d50"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 70.0), tr("COINS_LABEL") % coins, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#7a3ac1"))

	var close_rect := Rect2(panel.position.x + panel.size.x - 48.0, panel.position.y + 10.0, 38.0, 38.0)
	draw_style_box(_style("skin_close_bg", Color("#e8d8f8"), 10.0), close_rect)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 26.0), "X", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 18, Color("#2a0d50"))

	var tab_keys: Array = [TOOL_WATER, TOOL_AIR, TOOL_SOAP, TOOL_SPONGE]
	var tab_labels := [tr("TOOL_WATER"), tr("TOOL_AIR"), tr("TOOL_SOAP"), tr("TOOL_SPONGE")]
	for t in range(4):
		var tr: Rect2 = _skin_tab_rect(panel, t)
		var is_active: bool = _skin_panel_tab == t
		var tab_col := Color("#7a35c8") if is_active else Color("#d0b8f0")
		draw_style_box(_style("skin_tab_%d_%s" % [t, str(is_active)], tab_col, 8.0), tr)
		var lbl_col := Color(1.0, 1.0, 1.0) if is_active else Color("#4a2a7a")
		draw_string(font, Vector2(tr.position.x, tr.position.y + 22.0), tab_labels[t], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 12, lbl_col)

	var tool_key: String = tab_keys[_skin_panel_tab]
	var active_sid: String
	if tool_key == TOOL_WATER:
		active_sid = skin_water
	elif tool_key == TOOL_AIR:
		active_sid = skin_air
	elif tool_key == TOOL_SOAP:
		active_sid = skin_soap
	else:
		active_sid = skin_sponge

	var skins: Array = _nozzle_skins.get(tool_key, [])
	for ci in range(skins.size()):
		var skin: Dictionary = skins[ci]
		var sid: String = skin["id"]
		var cost: int = skin["cost"]
		var col: Color = skin["color"]
		var is_owned: bool = owned_skins.get(sid, false)
		var is_selected: bool = sid == active_sid
		var card: Rect2 = _skin_card_rect(panel, ci)

		var card_bg := Color("#e8d8f8") if is_selected else Color("#f0e8ff")
		var border_col := Color("#7a35c8") if is_selected else Color("#c8a8f0")
		draw_style_box(_style("skin_card_%d_%d_%s" % [ci, int(is_selected), sid], card_bg, 12.0, border_col, 2), card)

		var circle_center := Vector2(card.position.x + card.size.x * 0.5, card.position.y + 38.0)
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
