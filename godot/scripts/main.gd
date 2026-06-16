const DESIGN_SIZE := Vector2(390.0, 844.0)
const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const DIRT_TYPES := ["mud", "dust", "leaf", "oil", "bug"]
const CAR_TYPES := ["compact", "sports", "truck"]
const CLEAN_DAMAGE_RATE := 72.0
const AUDIO_MIX_RATE := 22050
const POP_NOTES := [523.25, 659.25, 783.99, 880.0, 1046.5]
const COMBO_WINDOW := 2.5
const STAR3_TIME := 75.0
const STAR3_COMBO := 4
const STAR2_TIME := 140.0
const STAR_WARN_SECONDS := 15.0
const GRADE_SLOT_EARNED := "earned"
const GRADE_SLOT_TARGET := "target"
const GRADE_SLOT_LOCKED := "locked"
const BAR_COL_START := Color(0.286, 0.655, 1.0)   # #49a7ff
const BAR_COL_END   := Color(0.224, 0.851, 0.541)  # #39d98a
const SAVE_PATH := "user://foam_party_save.cfg"
const DAILY_SAVE_PATH := "user://foam_party_daily.cfg"
const BOMB_COST := 40
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
const DAILY_MISSION_POOL := [
	{"type": "leaf", "label": "낙엽 %d개 날리기", "target": 20},
	{"type": "dust", "label": "먼지 %d개 제거하기", "target": 20},
	{"type": "mud", "label": "흙탕물 %d개 씻기", "target": 15},
	{"type": "oil", "label": "오일 %d개 청소하기", "target": 15},
	{"type": "bug", "label": "벌레 자국 %d개 닦기", "target": 12},
]
const DAILY_MISSION_REWARD := 50

class DirtPatch:
	var kind: String
	var position: Vector2
	var radius: float
	var health: float
	var max_health: float
	var soap: float = 0.0
	var wetness: float = 0.0
	var looseness: float = 0.0
	var runoff: float = 0.0
	var seed_offset: float
	var drift: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var state: String = "stuck"
	var resist_time: float = 0.0
	var hint_time: float = 0.0
	var hint_tool: String = ""

	func _init(new_kind: String, new_position: Vector2, new_radius: float, new_health: float, new_seed: float) -> void:
		kind = new_kind
		position = new_position
		radius = new_radius
		health = new_health
		max_health = new_health
		seed_offset = new_seed


class WashParticle:
	var position: Vector2
	var velocity: Vector2
	var ttl: float
	var radius: float
	var color: Color
	var style: String

	func _init(new_position: Vector2, new_velocity: Vector2, new_ttl: float, new_radius: float, new_color: Color, new_style: String) -> void:
		position = new_position
		velocity = new_velocity
		ttl = new_ttl
		radius = new_radius
		color = new_color
		style = new_style


var selected_tool: String = TOOL_WATER
var dirt_patches: Array = []
var particles: Array = []
var rng := RandomNumberGenerator.new()
var sfx_rng := RandomNumberGenerator.new()
var is_washing := false
var pointer_position := Vector2.ZERO
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
const COMBO_BONUS_AMOUNTS := {5: 5, 10: 10, 15: 15, 20: 20}
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
var game_state := STATE_TITLE
var coins := 0
var total_stars := 0
var coin_reward := 0
var _star_reveal_times: Array[float] = [-10.0, -10.0, -10.0]
const STAR_REVEAL_DELAYS: Array[float] = [0.3, 0.75, 1.25]
const STAR_REVEAL_POP_DUR := 0.5
var sound_enabled := true
var tutorial_seen := false
var show_tutorial := false
var persistence_enabled := true
var last_particle_spawn := 0.0
var car_color := Color("#ffcf5a")
var car_type := "compact"
var car_type_labels := {
	"compact": "City",
	"sports": "Sport",
	"truck": "Truck",
}
var canvas_origin := Vector2.ZERO
var canvas_scale := 1.0
var ui_font: Font
var bgm_player: AudioStreamPlayer
var tool_loop_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var completion_sfx_player: AudioStreamPlayer
var active_tool_sound := ""
var audio_playback_enabled := true

var daily_mission_type := ""
var daily_mission_label := ""
var daily_mission_target := 0
var daily_mission_progress := 0
var daily_mission_claimed := false
var daily_mission_date := ""
var _daily_mission_pop_time := -10.0
var _daily_progress_dirty := false
var _main_save_dirty := false
var _daily_save_timer: Timer = null

var tool_ids := [TOOL_AIR, TOOL_WATER, TOOL_SOAP, TOOL_SPONGE]
var tool_labels := {
	TOOL_AIR: "Air",
	TOOL_WATER: "Water",
	TOOL_SOAP: "Soap",
	TOOL_SPONGE: "Sponge",
}
var tool_colors := {
	TOOL_AIR: Color("#b7f0ff"),
	TOOL_WATER: Color("#49a7ff"),
	TOOL_SOAP: Color("#f8f4a6"),
	TOOL_SPONGE: Color("#ff9f5a"),
}
var style_cache: Dictionary = {}
var _hint_pill_box: StyleBoxFlat
var _hint_shadow_box: StyleBoxFlat
var _tool_hint_box: StyleBoxFlat
var _hint_patch: DirtPatch = null
var car_shapes: Dictionary = {}
var tool_audio_streams: Dictionary = {}
var ui_select_stream: AudioStreamWAV
var completion_stream: AudioStreamWAV
var removal_stream: AudioStreamWAV
var removal_sfx_player: AudioStreamPlayer
var combo_break_stream: AudioStreamWAV
var combo_break_player: AudioStreamPlayer
var _hint_stream: AudioStreamWAV = null
var _hint_sfx_player: AudioStreamPlayer = null
var _milestone_stream: AudioStreamWAV = null
var _milestone_sfx_player: AudioStreamPlayer = null
var _record_sfx: AudioStreamPlayer = null
var _combo_milestone_player: AudioStreamPlayer = null
var _star_lost_sfx: AudioStreamPlayer = null
var _prev_star3_time_ok := true
var _prev_star2_time_ok := true
var _star3_gate_sfx: AudioStreamPlayer = null
var _star3_combo_unlocked := false
var _last_milestone_haptic_combo := -1
var _star_warn_sfx: AudioStreamPlayer = null
var _prev_in_warn_zone := false
var _patience_warn_sfx: AudioStreamPlayer = null
var _prev_patience_zone := 3
var _bomb_sfx: AudioStreamPlayer = null
var _bomb_deny_sfx: AudioStreamPlayer = null
var _coin_bonus_sfx: AudioStreamPlayer = null
var _star_earn_sfx: AudioStreamPlayer = null
var _bar_fill_style := StyleBoxFlat.new()


func _ready() -> void:
	rng.seed = 42690
	sfx_rng.seed = 8808
	mouse_filter = Control.MOUSE_FILTER_STOP
	persistence_enabled = DisplayServer.get_name() != "headless" and OS.get_environment("FOAM_DISABLE_SAVE") != "1"
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
	_setup_audio()
	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = BAR_COL_START
	_bar_fill_style.set_corner_radius_all(12)
	_apply_sound_setting()
	reset_game(level_index)


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
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_enabled)


func start_game() -> void:
	game_state = STATE_PLAYING
	if not tutorial_seen:
		show_tutorial = true
	queue_redraw()


func _process(delta: float) -> void:
	if game_state == STATE_PLAYING and not completed and not show_tutorial:
		level_time += delta
		_check_star_time_loss()
		var _warn_time := _grade_time_to_downgrade()
		var _in_warn := _warn_time >= 0.0 and _warn_time <= STAR_WARN_SECONDS
		if _in_warn and not _prev_in_warn_zone:
			if audio_playback_enabled and is_instance_valid(_star_warn_sfx):
				_star_warn_sfx.stop()
				_star_warn_sfx.play()
		_prev_in_warn_zone = _in_warn
		if STAR2_TIME > 0.0:
			var _patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
			var _pzone := 3 if _patience > 0.65 else (2 if _patience > 0.35 else (1 if _patience > 0.1 else 0))
			# Policy: one alert per downgrade event. Patience decreases linearly
			# over 140s so multi-zone skips in one frame are not a realistic
			# concern; a single alert per event is the correct UX choice.
			if _pzone < _prev_patience_zone:
				if audio_playback_enabled and is_instance_valid(_patience_warn_sfx):
					_patience_warn_sfx.stop()
					_patience_warn_sfx.play()
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


func _setup_font() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Apple SD Gothic Neo",
		"AppleGothic",
		"Noto Sans CJK KR",
		"Noto Sans KR",
		"Malgun Gothic",
		"Arial Unicode MS",
	])
	ui_font = system_font


func _font() -> Font:
	if ui_font != null:
		return ui_font
	return get_theme_default_font()


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


func _setup_audio() -> void:
	audio_playback_enabled = DisplayServer.get_name() != "headless"
	tool_audio_streams = {
		TOOL_AIR: _make_tool_loop_stream(TOOL_AIR),
		TOOL_WATER: _make_tool_loop_stream(TOOL_WATER),
		TOOL_SOAP: _make_tool_loop_stream(TOOL_SOAP),
		TOOL_SPONGE: _make_tool_loop_stream(TOOL_SPONGE),
	}
	ui_select_stream = _make_select_stream()
	completion_stream = _make_completion_stream()
	removal_stream = _make_removal_stream()
	if audio_playback_enabled:
		combo_break_stream = _make_combo_break_stream()
		combo_break_player = AudioStreamPlayer.new()
		combo_break_player.stream = combo_break_stream
		combo_break_player.volume_db = -7.0
		add_child(combo_break_player)
		_hint_stream = _make_hint_stream()
		_hint_sfx_player = AudioStreamPlayer.new()
		_hint_sfx_player.stream = _hint_stream
		_hint_sfx_player.volume_db = -11.0
		add_child(_hint_sfx_player)
		_milestone_stream = _make_milestone_stream()
		_milestone_sfx_player = AudioStreamPlayer.new()
		_milestone_sfx_player.stream = _milestone_stream
		_milestone_sfx_player.volume_db = -8.0
		add_child(_milestone_sfx_player)
		_record_sfx = AudioStreamPlayer.new()
		_record_sfx.stream = _make_record_stream()
		_record_sfx.volume_db = -6.0
		add_child(_record_sfx)
		_combo_milestone_player = AudioStreamPlayer.new()
		_combo_milestone_player.stream = _make_combo_milestone_stream()
		_combo_milestone_player.volume_db = -5.0
		add_child(_combo_milestone_player)
		_star_lost_sfx = AudioStreamPlayer.new()
		_star_lost_sfx.stream = _make_star_lost_stream()
		_star_lost_sfx.volume_db = -5.0
		add_child(_star_lost_sfx)
		_star3_gate_sfx = AudioStreamPlayer.new()
		_star3_gate_sfx.stream = _make_star3_gate_stream()
		_star3_gate_sfx.volume_db = -4.0
		add_child(_star3_gate_sfx)
		_star_warn_sfx = AudioStreamPlayer.new()
		_star_warn_sfx.stream = _make_star_warn_stream()
		_star_warn_sfx.volume_db = -6.0
		add_child(_star_warn_sfx)
		_patience_warn_sfx = AudioStreamPlayer.new()
		_patience_warn_sfx.stream = _make_patience_warn_stream()
		_patience_warn_sfx.volume_db = -9.0
		add_child(_patience_warn_sfx)
		_bomb_sfx = AudioStreamPlayer.new()
		_bomb_sfx.stream = _make_bomb_stream()
		_bomb_sfx.volume_db = -3.0
		add_child(_bomb_sfx)
		_bomb_deny_sfx = AudioStreamPlayer.new()
		_bomb_deny_sfx.stream = _make_bomb_deny_stream()
		_bomb_deny_sfx.volume_db = -9.0
		add_child(_bomb_deny_sfx)
		_coin_bonus_sfx = AudioStreamPlayer.new()
		_coin_bonus_sfx.stream = _make_coin_bonus_stream()
		_coin_bonus_sfx.volume_db = -6.0
		add_child(_coin_bonus_sfx)
		_star_earn_sfx = AudioStreamPlayer.new()
		_star_earn_sfx.volume_db = -6.0
		add_child(_star_earn_sfx)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BackgroundMusic"
	bgm_player.stream = _make_bgm_stream()
	bgm_player.volume_db = -23.0
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	if audio_playback_enabled:
		bgm_player.play()

	tool_loop_player = AudioStreamPlayer.new()
	tool_loop_player.name = "ToolLoopSound"
	tool_loop_player.volume_db = -7.0
	tool_loop_player.finished.connect(_on_tool_loop_finished)
	add_child(tool_loop_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.name = "SelectSfx"
	ui_sfx_player.volume_db = -8.0
	add_child(ui_sfx_player)

	completion_sfx_player = AudioStreamPlayer.new()
	completion_sfx_player.name = "CompletionSfx"
	completion_sfx_player.volume_db = -5.0
	add_child(completion_sfx_player)

	removal_sfx_player = AudioStreamPlayer.new()
	removal_sfx_player.name = "RemovalSfx"
	removal_sfx_player.volume_db = -9.0
	add_child(removal_sfx_player)


func _update_audio() -> void:
	if not audio_playback_enabled:
		return
	if completed or not is_washing:
		_stop_tool_loop()
		return
	_play_tool_loop(selected_tool)


func _play_tool_loop(tool_id: String) -> void:
	if tool_loop_player == null:
		return
	var stream: AudioStream = tool_audio_streams.get(tool_id) as AudioStream
	if stream == null:
		return
	if active_tool_sound != tool_id:
		active_tool_sound = tool_id
		tool_loop_player.stop()
		tool_loop_player.stream = stream
	if not tool_loop_player.playing:
		tool_loop_player.play()


func _stop_tool_loop() -> void:
	active_tool_sound = ""
	if tool_loop_player != null and tool_loop_player.playing:
		tool_loop_player.stop()


func _play_ui_select() -> void:
	if ui_sfx_player == null or not audio_playback_enabled:
		return
	ui_sfx_player.stop()
	ui_sfx_player.stream = ui_select_stream
	ui_sfx_player.play()


func _play_completion_sound() -> void:
	if completion_sfx_player == null or not audio_playback_enabled:
		return
	completion_sfx_player.stop()
	completion_sfx_player.stream = completion_stream
	completion_sfx_player.play()


func _play_removal_sound() -> void:
	if removal_sfx_player == null or not audio_playback_enabled:
		return
	removal_sfx_player.stop()
	removal_sfx_player.stream = removal_stream
	var combo_pitch: float = 0.92 + 0.05 * float(min(combo_count, 9))
	removal_sfx_player.pitch_scale = combo_pitch + sfx_rng.randf_range(-0.02, 0.02)
	removal_sfx_player.play()


func _scale_pop(t: float, rate: float, width: float, note_shift: int, amp: float) -> float:
	var phase: float = fmod(t * rate, 1.0)
	if phase >= width:
		return 0.0
	var note_index: int = (int(floor(t * rate)) + note_shift) % POP_NOTES.size()
	var envelope: float = sin(PI * phase / width)
	return sin(TAU * POP_NOTES[note_index] * t) * envelope * amp


func _on_bgm_finished() -> void:
	if bgm_player != null and audio_playback_enabled:
		bgm_player.play()


func _on_tool_loop_finished() -> void:
	if is_washing and not completed and active_tool_sound != "":
		_play_tool_loop(active_tool_sound)


func _make_tool_loop_stream(tool_id: String) -> AudioStreamWAV:
	var duration := 0.92
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = _tool_audio_seed(tool_id)
	var low_noise := 0.0
	var mid_noise := 0.0
	var high_filter := 0.0
	var high_noise := 0.0

	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var noise: float = noise_rng.randf_range(-1.0, 1.0)
		low_noise = lerp(low_noise, noise, 0.018)
		mid_noise = lerp(mid_noise, noise, 0.12)
		high_filter = lerp(high_filter, noise, 0.045)
		high_noise = noise - high_filter
		var sample: float = 0.0
		if tool_id == TOOL_AIR:
			var swell: float = 0.62 + 0.38 * sin(TAU * 1.087 * t - PI * 0.5)
			var breeze: float = (low_noise * 0.34 + mid_noise * 0.16) * swell
			var whistle_freq: float = 520.0 + 170.0 * sin(TAU * 1.087 * t) + 40.0 * sin(TAU * 3.26 * t)
			var whistle: float = sin(TAU * whistle_freq * t) * 0.085 * swell
			var flutter: float = high_noise * 0.05 * (0.5 + 0.5 * sin(TAU * 5.43 * t))
			sample = breeze + whistle + flutter
		elif tool_id == TOOL_WATER:
			var flow: float = (low_noise * 0.24 + mid_noise * 0.20) * (0.82 + 0.18 * sin(TAU * 2.17 * t))
			var burble_a: float = sin(TAU * (170.0 + 42.0 * sin(TAU * 1.087 * t)) * t) * 0.075
			var burble_b: float = sin(TAU * (233.0 + 58.0 * sin(TAU * 2.174 * t + 1.7)) * t) * 0.055
			var plink_rate := 6.52
			var plink_phase: float = fmod(t * plink_rate, 1.0)
			var plink_index: int = int(floor(t * plink_rate)) % POP_NOTES.size()
			var plink: float = 0.0
			if plink_phase < 0.16:
				var plink_env: float = sin(PI * plink_phase / 0.16)
				plink = sin(TAU * POP_NOTES[plink_index] * 0.5 * t) * plink_env * 0.11
			sample = flow + burble_a + burble_b + plink
		elif tool_id == TOOL_SOAP:
			var foam_swell: float = 0.6 + 0.4 * max(0.0, sin(TAU * 2.174 * t))
			var fizz: float = (high_noise * 0.055 + mid_noise * 0.03) * foam_swell
			var pop_a := _scale_pop(t, 7.6, 0.10, 0, 0.16)
			var pop_b := _scale_pop(t, 11.96, 0.07, 2, 0.13)
			var pop_c := _scale_pop(t, 17.39, 0.05, 4, 0.10)
			var wobble: float = sin(TAU * 330.0 * t + sin(TAU * 4.35 * t) * 2.2) * 0.04 * foam_swell
			sample = fizz + pop_a + pop_b + pop_c + wobble
		elif tool_id == TOOL_SPONGE:
			var wipe_phase: float = fmod(t * 3.26, 1.0)
			var wipe_env: float = pow(sin(PI * wipe_phase), 1.4)
			var squish: float = (low_noise * 0.30 + mid_noise * 0.13) * wipe_env
			var rub_freq: float = 360.0 + 150.0 * wipe_phase
			var rub: float = sin(TAU * rub_freq * t) * pow(wipe_env, 3.0) * 0.10
			var boing_phase: float = fmod(t * 2.174, 1.0)
			var boing: float = 0.0
			if boing_phase < 0.12:
				var boing_env: float = sin(PI * boing_phase / 0.12)
				boing = sin(TAU * (190.0 - 70.0 * boing_phase / 0.12) * t) * boing_env * 0.09
			sample = squish + rub + boing

		var fade: float = min(1.0, float(sample_index) / 1600.0, float(total_samples - sample_index) / 1600.0)
		_append_i16_sample(data, sample * fade * 0.92)

	return _make_wav(data)


func _make_select_stream() -> AudioStreamWAV:
	var duration := 0.16
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var first_env: float = exp(-t * 30.0)
		var sample: float = (sin(TAU * 659.25 * t) * 0.26 + sin(TAU * 1318.5 * t) * 0.05) * first_env
		if t >= 0.07:
			var second_t := t - 0.07
			var attack: float = clamp(second_t / 0.008, 0.0, 1.0)
			var second_env: float = exp(-second_t * 26.0) * attack
			sample += (sin(TAU * 987.77 * second_t) * 0.26 + sin(TAU * 1975.53 * second_t) * 0.05) * second_env
		_append_i16_sample(data, sample)
	return _make_wav(data)


func _make_removal_stream() -> AudioStreamWAV:
	var duration := 0.24
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var pop_rng := RandomNumberGenerator.new()
	pop_rng.seed = 6606
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var pop_env: float = exp(-t * 42.0)
		var pop: float = sin(TAU * (820.0 - 360.0 * min(1.0, t * 9.0)) * t) * pop_env * 0.30
		var fizz: float = pop_rng.randf_range(-1.0, 1.0) * exp(-t * 30.0) * 0.07
		var chime_env: float = exp(-max(0.0, t - 0.05) * 16.0) * clamp((t - 0.05) / 0.02, 0.0, 1.0)
		var chime: float = sin(TAU * 1318.5 * t) * chime_env * 0.10
		_append_i16_sample(data, pop + fizz + chime)
	return _make_wav(data)


func _make_milestone_stream() -> AudioStreamWAV:
	var total_samples: int = int(0.10 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var phase := 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(AUDIO_MIX_RATE)
		phase += TAU * 659.0 / float(AUDIO_MIX_RATE)
		var env := exp(-t * 16.0) * clampf(t / 0.004, 0.0, 1.0)
		_append_i16_sample(data, sin(phase) * 0.30 * env)
	return _make_wav(data)


func _make_record_stream() -> AudioStreamWAV:
	const NOTE_SAMPLES: int = int(0.06 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [880.0, 1047.0]
	for note in 2:
		var phase := 0.0
		for i in range(NOTE_SAMPLES):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 14.0) * clampf(t / 0.003, 0.0, 1.0)
			var tail := clampf(float(NOTE_SAMPLES - 1 - i) / float(int(AUDIO_MIX_RATE * 0.010)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.36 * env * tail)
	return _make_wav(data)


func _make_combo_milestone_stream() -> AudioStreamWAV:
	const NOTE_SAMPLES: int = int(0.08 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [659.25, 783.99, 987.77]  # E5, G5, B5 ascending arpeggio
	for note in 3:
		var phase := 0.0
		for i in range(NOTE_SAMPLES):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 12.0) * clampf(t / 0.003, 0.0, 1.0)
			var tail := clampf(float(NOTE_SAMPLES - 1 - i) / float(int(AUDIO_MIX_RATE * 0.012)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.38 * env * tail)
	return _make_wav(data)


func _make_star_lost_stream() -> AudioStreamWAV:
	var total_samples: int = int(0.12 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var phase := 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(AUDIO_MIX_RATE)
		var freq := 440.0 * pow(0.5, t * 3.0)
		phase += TAU * freq / float(AUDIO_MIX_RATE)
		var env := exp(-t * 5.5) * clampf(t / 0.010, 0.0, 1.0)
		var tail := clampf(float(total_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.020)), 0.0, 1.0)
		_append_i16_sample(data, sin(phase) * 0.35 * env * tail)
	return _make_wav(data)


func _make_star_warn_stream() -> AudioStreamWAV:
	var note_samples: int = int(0.050 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [587.33, 440.0]  # D5, A4 — 하행 완전4도 경보
	for note in 2:
		var phase := 0.0
		for i in range(note_samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 8.0) * clampf(t / 0.003, 0.0, 1.0)
			var tail := clampf(float(note_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.010)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.38 * env * tail)
	return _make_wav(data)


func _make_patience_warn_stream() -> AudioStreamWAV:
	var note_samples: int = int(0.055 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [392.0, 293.66]  # G4→D4 하행 완전5도 — 부드러운 경고
	for note in 2:
		var freq: float = freqs[note]
		var phase := 0.0
		for i in range(note_samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freq / float(AUDIO_MIX_RATE)
			var env := exp(-t * 10.0) * clampf(t / 0.004, 0.0, 1.0)
			var tail := clampf(float(note_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.012)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.32 * env * tail)
	return _make_wav(data)


func _make_bomb_stream() -> AudioStreamWAV:
	var duration := 0.38
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var bomb_rng := RandomNumberGenerator.new()
	bomb_rng.seed = 5577
	var phase := 0.0
	var fade_len: int = maxi(1, int(AUDIO_MIX_RATE * 0.05))
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var thump_freq := 195.0 * exp(-t * 9.0) + 70.0
		phase += TAU * thump_freq / float(AUDIO_MIX_RATE)
		var thump_env := exp(-t * 11.0) * clampf(t / 0.004, 0.0, 1.0)
		var thump := sin(phase) * 0.38 * thump_env
		var noise := bomb_rng.randf_range(-1.0, 1.0)
		var fizz_env := t * exp(-t * 8.0) * 3.2
		var fizz := noise * fizz_env * 0.13
		var fade := clampf(float(total_samples - 1 - sample_index) / float(fade_len), 0.0, 1.0)
		_append_i16_sample(data, clampf((thump + fizz) * fade, -1.0, 1.0))
	return _make_wav(data)


func _make_bomb_deny_stream() -> AudioStreamWAV:
	var total_samples: int = int(0.055 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var phase := 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(AUDIO_MIX_RATE)
		var freq := 48.0 * exp(-t * 12.0) + 72.0
		phase += TAU * freq / float(AUDIO_MIX_RATE)
		var env := exp(-t * 35.0) * clampf(t / 0.002, 0.0, 1.0)
		_append_i16_sample(data, clampf(sin(phase) * 0.28 * env, -1.0, 1.0))
	return _make_wav(data)


func _make_coin_bonus_stream() -> AudioStreamWAV:
	var note_samples: int = int(0.055 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [1046.50, 1318.51]  # C6, E6 — 밝은 두 음 상행
	for note in 2:
		var phase := 0.0
		for i in range(note_samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 18.0) * clampf(t / 0.002, 0.0, 1.0)
			var tail := clampf(float(note_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.008)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.32 * env * tail)
	return _make_wav(data)


func _make_star3_gate_stream() -> AudioStreamWAV:
	var note_samples: int = int(0.055 * float(AUDIO_MIX_RATE))
	var final_samples: int = int(0.075 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var freqs := [783.99, 987.77, 1174.66, 1567.98]  # G5, B5, D6, G6
	for note in freqs.size():
		var samples := final_samples if note == freqs.size() - 1 else note_samples
		var phase := 0.0
		for i in range(samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 10.0) * clampf(t / 0.004, 0.0, 1.0)
			var tail := clampf(float(samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.010)), 0.0, 1.0)
			var amp := 0.40 if note == freqs.size() - 1 else 0.36
			_append_i16_sample(data, sin(phase) * amp * env * tail)
	return _make_wav(data)


func _play_star_earn_sfx(stars: int, on_finished: Callable = Callable()) -> void:
	if not audio_playback_enabled or not is_instance_valid(_star_earn_sfx):
		if on_finished.is_valid():
			on_finished.call()
		return
	var stream := _make_star_earn_stream(stars)
	if stream == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	_star_earn_sfx.stop()
	if on_finished.is_valid():
		_star_earn_sfx.finished.connect(on_finished, CONNECT_ONE_SHOT)
	_star_earn_sfx.stream = stream
	_star_earn_sfx.play()


func _make_star_earn_stream(stars: int) -> AudioStreamWAV:
	var freqs := [523.25, 659.26, 783.99]  # C5 E5 G5
	var count := clampi(stars, 0, freqs.size())
	if count <= 0:
		return null
	var note_samples := int(0.09 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	for n in range(count):
		var freq: float = freqs[n]
		var phase := 0.0
		for i in range(note_samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freq / float(AUDIO_MIX_RATE)
			var env := exp(-t * 12.0) * clampf(t / 0.004, 0.0, 1.0)
			var tail := clampf(float(note_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.010)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.38 * env * tail)
	return _make_wav(data)


func _check_star_time_loss() -> void:
	var star3_time_ok := level_time <= _star_time_threshold(3)
	var star2_time_ok := level_time <= _star_time_threshold(2)
	if (_prev_star3_time_ok and not star3_time_ok) or (_prev_star2_time_ok and not star2_time_ok):
		if audio_playback_enabled and is_instance_valid(_star_lost_sfx):
			_star_lost_sfx.stop()
			_star_lost_sfx.play()
	_prev_star3_time_ok = star3_time_ok
	_prev_star2_time_ok = star2_time_ok


func _make_hint_stream() -> AudioStreamWAV:
	var total_samples: int = int(0.09 * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var phase := 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(AUDIO_MIX_RATE)
		phase += TAU * 440.0 / float(AUDIO_MIX_RATE)
		var env := exp(-t * 24.0) * clampf(t / 0.003, 0.0, 1.0)
		_append_i16_sample(data, sin(phase) * 0.32 * env)
	return _make_wav(data)


func _make_combo_break_stream() -> AudioStreamWAV:
	var duration := 0.20
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var break_rng := RandomNumberGenerator.new()
	break_rng.seed = 7713
	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(AUDIO_MIX_RATE)
		var f1 := 740.0 * pow(0.35, t * 3.2)
		var f2 := 555.0 * pow(0.35, t * 2.8)
		var env: float = exp(-t * 18.0) * clampf(t / 0.008, 0.0, 1.0)
		phase1 += TAU * f1 / float(AUDIO_MIX_RATE)
		phase2 += TAU * f2 / float(AUDIO_MIX_RATE)
		var noise: float = break_rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.06
		var sample: float = (sin(phase1) * 0.30 + sin(phase2) * 0.22 + noise) * env
		_append_i16_sample(data, sample)
	return _make_wav(data)


func _spawn_combo_break_burst() -> void:
	var badge_center := Vector2(195.0, maxf(134.0, _hud_top_y() + 112.0))
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
	if audio_playback_enabled and is_instance_valid(combo_break_player):
		combo_break_player.stop()
		combo_break_player.play()


func _make_completion_stream() -> AudioStreamWAV:
	var duration := 0.92
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var note_index: int = clamp(int(floor(t / 0.18)), 0, notes.size() - 1)
		var freq: float = notes[note_index]
		var note_t: float = fmod(t, 0.18)
		var pluck: float = exp(-note_t * 7.0)
		var fade: float = 1.0 - clamp((t - 0.72) / 0.2, 0.0, 1.0)
		var shimmer: float = sin(TAU * freq * 4.0 * t) * 0.04 * pluck
		var sample: float = (sin(TAU * freq * t) * 0.24 + sin(TAU * freq * 2.0 * t) * 0.08 + shimmer) * pluck * fade
		_append_i16_sample(data, sample)
	return _make_wav(data)


func _make_bgm_stream() -> AudioStreamWAV:
	var duration := 5.76
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var melody := [392.0, 440.0, 493.88, 587.33, 523.25, 493.88, 440.0, 392.0]
	var bass := [130.81, 146.83, 164.81, 196.0]
	var hat_rng := RandomNumberGenerator.new()
	hat_rng.seed = 7707
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var step: int = int(floor(t / 0.36)) % melody.size()
		var bass_step: int = int(floor(t / 1.44)) % bass.size()
		var beat_phase: float = fmod(t, 0.36) / 0.36
		var pluck: float = pow(1.0 - beat_phase, 1.8)
		var melody_sample: float = (sin(TAU * melody[step] * t) * 0.10 + sin(TAU * melody[step] * 2.0 * t) * 0.025) * pluck
		var harmony_sample: float = sin(TAU * melody[step] * 1.5 * t) * 0.03 * pluck
		var bass_phase: float = fmod(t, 0.72) / 0.72
		var bass_sample: float = sin(TAU * bass[bass_step] * t) * 0.075 * (0.6 + 0.4 * pow(1.0 - bass_phase, 1.2))
		var hat_phase: float = fmod(t + 0.18, 0.36) / 0.36
		var hat: float = hat_rng.randf_range(-1.0, 1.0) * 0.02 * pow(max(0.0, 1.0 - hat_phase * 5.0), 2.0)
		var shimmer: float = sin(TAU * 880.0 * t) * 0.012 * max(0.0, sin(TAU * 2.0 * t))
		var loop_fade: float = min(1.0, float(sample_index) / 1800.0, float(total_samples - sample_index) / 1800.0)
		_append_i16_sample(data, (melody_sample + harmony_sample + bass_sample + hat + shimmer) * loop_fade)
	return _make_wav(data)


func _tool_audio_seed(tool_id: String) -> int:
	if tool_id == TOOL_AIR:
		return 1101
	if tool_id == TOOL_WATER:
		return 2202
	if tool_id == TOOL_SOAP:
		return 3303
	if tool_id == TOOL_SPONGE:
		return 4404
	return 5505


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _append_i16_sample(data: PackedByteArray, value: float) -> void:
	var sample: int = int(clamp(value, -1.0, 1.0) * 32767.0)
	if sample < 0:
		sample += 65536
	data.append(sample & 0xff)
	data.append((sample >> 8) & 0xff)


func _input(event: InputEvent) -> void:
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
		if touch_event.index != 0:
			return
		var touch_point := _to_design(touch_event.position)
		if touch_event.pressed:
			if _handle_tap(touch_point):
				return
			pointer_position = touch_point
			is_washing = true
		else:
			is_washing = false
		return

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == 0:
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
	else:
		_draw_wash_trail()
		_draw_tool_cursor()
		_draw_grade_tracker()
		_draw_customer_patience()
		_draw_daily_mission()
		_draw_combo_badge()
		_draw_bomb_button()
		_draw_toolbar()
		_draw_completion_panel()
		_draw_combo_milestone_flash()
	_draw_top_buttons()
	if show_tutorial:
		_draw_tutorial()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func reset_game(new_level: int) -> void:
	level_index = new_level
	completed = false
	completion_burst_done = false
	_gleam_time = -1.0
	is_washing = false
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
	_stop_tool_loop()
	particles.clear()
	_set_car_palette()
	_spawn_dirt()
	_update_clean_progress()
	queue_redraw()


func get_patch_count_for_test() -> int:
	return dirt_patches.size()


func get_clean_progress_for_test() -> float:
	return clean_progress


func get_selected_tool_label_for_test() -> String:
	return tool_labels[selected_tool]


func get_audio_stream_count_for_test() -> int:
	return tool_audio_streams.size()


func get_combo_for_test() -> int:
	return combo_count


func get_best_combo_for_test() -> int:
	return best_combo


func get_level_for_test() -> int:
	return level_index


func _today_string() -> String:
	var now := Time.get_ticks_msec()
	var unix_time := now / 1000
	var dict := Time.get_time_dict_from_system()
	return "%04d-%02d-%02d" % [dict.year, dict.month, dict.day]


func _generate_daily_mission(today: String) -> void:
	daily_mission_type = ""
	daily_mission_label = ""
	daily_mission_target = 0
	daily_mission_progress = 0
	daily_mission_claimed = false
	daily_mission_date = today
	if DAILY_MISSION_POOL.is_empty():
		return
	var index := rng.randi() % DAILY_MISSION_POOL.size()
	var mission := DAILY_MISSION_POOL[index]
	daily_mission_type = mission["type"]
	daily_mission_target = mission["target"]
	daily_mission_label = mission["label"]
	_daily_progress_dirty = true


func _draw_combo_milestone_flash() -> void:
	if _combo_milestone_flash_time < 0.0:
		return
	var age := Time.get_ticks_msec() / 1000.0 - _combo_milestone_flash_time
	var duration := 0.4
	if age >= duration:
		_combo_milestone_flash_time = -1.0
		return
	var alpha := 1.0 - age / duration
	var size := 44.0 + age * 120.0
	var pos := Vector2(195.0, _hud_top_y() + 60.0)
	draw_circle(pos, size / 2.0, _combo_milestone_flash_color * Color(1.0, 1.0, 1.0, alpha * 0.6))
	queue_redraw()


func _trigger_combo_milestone(combo: int) -> void:
	_combo_milestone_flash_time = Time.get_ticks_msec() / 1000.0
	var tint := tool_colors.get(selected_tool, Color.WHITE)
	_combo_milestone_flash_color = tint
	var fanfare_label: String = ""
	var fanfare_sound: String = ""
	if combo == 4:
		fanfare_label = "COMBO!"
		fanfare_sound = "combo"
	elif combo == 10:
		fanfare_label = "HOT STREAK!"
		fanfare_sound = "streak"
	elif combo >= 20:
		fanfare_label = "MASSIVE!"
		fanfare_sound = "massive"
	_combo_milestone_fanfare = fanfare_label
	_combo_milestone_count = combo
	if fanfare_sound != "" and audio_playback_enabled and is_instance_valid(_combo_milestone_player):
		_combo_milestone_player.stop()
		_combo_milestone_player.play()


func _hud_top_y() -> float:
	var safe_pad := 0.0
	if get_viewport() != null and get_viewport().get_visible_rect().size.y > 480.0:
		safe_pad = HUD_SAFE_PADDING * (get_viewport().get_visible_rect().size.y - 480.0) / 100.0
	return HUD_TOP_Y + safe_pad


func _draw_combo_badge() -> void:
	if combo_count == 0:
		return
	var badge_y := _hud_top_y() + 60.0
	var badge_rect := Rect2(145.0, badge_y - 16.0, 100.0, 32.0)
	var bg_color := Color(0.1, 0.1, 0.1, 0.7)
	draw_rect(badge_rect, bg_color)
	draw_rect(badge_rect, Color(0.2, 0.2, 0.2), false)
	var combo_text: String = "x%d" % combo_count
	draw_string(_font(), Vector2(badge_rect.position.x + 6.0, badge_rect.position.y + 10.0), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _draw_customer_patience() -> void:
	if STAR2_TIME <= 0.0 or game_state != STATE_PLAYING or completed:
		return
	var patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
	var bar_width := 180.0
	var bar_height := 4.0
	var bar_x := (DESIGN_SIZE.x - bar_width) * 0.5
	var bar_y := _hud_top_y() + 30.0
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.3, 0.3, 0.3))
	var filled_width := bar_width * patience
	var bar_color := Color.WHITE.lerp(Color.RED, 1.0 - patience)
	draw_rect(Rect2(bar_x, bar_y, filled_width, bar_height), bar_color)


func _draw_combo_milestone_flash() -> void:
	if _combo_milestone_flash_time < 0.0:
		return
	var age := Time.get_ticks_msec() / 1000.0 - _combo_milestone_flash_time
	var duration := 0.4
	if age >= duration:
		_combo_milestone_flash_time = -1.0
		return
	var alpha := 1.0 - age / duration
	var size := 44.0 + age * 120.0
	var pos := Vector2(195.0, _hud_top_y() + 60.0)
	draw_circle(pos, size / 2.0, _combo_milestone_flash_color * Color(1.0, 1.0, 1.0, alpha * 0.6))
	queue_redraw()


func _apply_tool_at(pos: Vector2, delta: float) -> void:
	var found_dirty := false
	var combo_before := combo_count
	for patch in dirt_patches:
		var dist := pos.distance_to(patch.position)
		if dist <= patch.radius + 12.0:
			if _apply_tool_to_patch(patch, selected_tool, delta):
				found_dirty = true
				if combo_count > combo_before:
					_last_milestone_haptic_combo = combo_before
					if combo_count == 4 or combo_count == 10 or combo_count == 20:
						_trigger_combo_milestone(combo_count)
	if found_dirty:
		_play_removal_sound()


func _apply_tool_to_patch(patch: DirtPatch, tool: String, delta: float) -> bool:
	if patch.health <= 0:
		return false
	var damage := 0.0
	var soap_req := 0.0
	if tool == TOOL_WATER:
		soap_req = 0.3
		damage = CLEAN_DAMAGE_RATE * delta
		if patch.soap < soap_req:
			damage *= 0.1
	elif tool == TOOL_SOAP:
		damage = CLEAN_DAMAGE_RATE * delta * 0.3
		patch.soap = minf(patch.soap + delta * 0.8, 1.0)
	elif tool == TOOL_SPONGE:
		soap_req = 0.5
		damage = CLEAN_DAMAGE_RATE * delta * 1.8
		if patch.soap < soap_req:
			damage *= 0.2
	elif tool == TOOL_AIR:
		if patch.state == STATE_RUNOFF:
			damage = CLEAN_DAMAGE_RATE * delta * 3.0
		else:
			damage = 0.0
	var dirty_before := patch.health > 0.0
	patch.health -= damage
	var dirty_after := patch.health > 0.0
	if dirty_before and not dirty_after:
		combo_timer = COMBO_WINDOW
		combo_count += 1
		if combo_count > best_combo:
			best_combo = combo_count
		return true
	return false


func _update_clean_progress() -> void:
	var total_health := 0.0
	for patch in dirt_patches:
		total_health += patch.health
	clean_progress = 1.0 - (total_health / maxf(initial_dirt_total, 0.001))
	if clean_progress >= 1.0:
		if not completed:
			completed = true
			_save_progress()


func _spawn_dirt() -> void:
	dirt_patches.clear()
	initial_dirt_total = 0.0
	var car_size := 80.0
	var spawn_regions := [
		Rect2(90.0, 300.0, 210.0, 150.0),
		Rect2(120.0, 480.0, 150.0, 140.0),
		Rect2(100.0, 650.0, 190.0, 120.0),
	]
	var region_idx := 0
	for i in range(1, 5):
		var region := spawn_regions[region_idx % spawn_regions.size()]
		region_idx += 1
		var patch_count := rng.randi_range(1, 3)
		for _j in range(patch_count):
			var x := rng.randf_range(region.position.x, region.position.x + region.size.x)
			var y := rng.randf_range(region.position.y, region.position.y + region.size.y)
			var dirt_type := DIRT_TYPES[rng.randi() % DIRT_TYPES.size()]
			var radius := rng.randf_range(12.0, 28.0)
			var health := radius * rng.randf_range(4.0, 8.0)
			var seed_val := rng.randf_range(0.0, 1.0)
			dirt_patches.append(DirtPatch.new(dirt_type, Vector2(x, y), radius, health, seed_val))
			initial_dirt_total += health


func _update_dirt_motion(delta: float) -> void:
	for patch in dirt_patches:
		if patch.health <= 0:
			if patch.state != STATE_REMOVED:
				patch.state = STATE_REMOVED
				patch.velocity = Vector2.ZERO
				patch.drift = Vector2.ZERO
			continue
		if patch.health <= 0:
			continue
		var state_before := patch.state
		if patch.soap >= 0.5:
			patch.state = STATE_SOAPED
		elif patch.soap >= 0.3:
			patch.state = STATE_WET
		elif patch.state == STATE_REMOVED:
			patch.state = STATE_STUCK
		if patch.state == STATE_SOAPED:
			patch.soap = maxf(patch.soap - delta * 0.15, 0.0)
		if patch.health <= 20.0 and patch.soap >= 0.4:
			patch.state = STATE_RUNOFF
		if patch.state == STATE_RUNOFF:
			if patch.velocity.length() < 40.0:
				patch.velocity += Vector2.from_angle(randf() * TAU) * rng.randf_range(20.0, 40.0)
			patch.velocity *= exp(-delta * 1.2)
			patch.position += patch.velocity * delta
		if state_before != patch.state and patch.state == STATE_RUNOFF:
			_spawn_runoff_particles(patch.position, patch.radius)


func _spawn_runoff_particles(pos: Vector2, radius: float) -> void:
	for _i in range(rng.randi_range(3, 6)):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(60.0, 120.0)
		var vel := Vector2.from_angle(angle) * speed
		var lifetime := rng.randf_range(0.4, 0.7)
		var part_radius := rng.randf_range(2.0, 4.0)
		var color := Color(0.6, 0.7, 0.8, 0.9)
		particles.append(WashParticle.new(pos, vel, lifetime, part_radius, color, STYLE_DROPLET))


func _update_wash_trail(delta: float) -> void:
	if is_washing and wash_trail.size() < TRAIL_MAX_POINTS:
		var dist_to_last := pointer_position.distance_to(_trail_last_pos)
		if not _trail_has_last or dist_to_last >= TRAIL_MIN_GAP:
			wash_trail.append({"pos": pointer_position, "ttl": TRAIL_LIFETIME})
			_trail_last_pos = pointer_position
			_trail_has_last = true
	wash_speed = pointer_position.distance_to(_trail_last_pos) / maxf(delta, 0.001) if _trail_has_last else 0.0
	var i := 0
	while i < wash_trail.size():
		wash_trail[i]["ttl"] -= delta
		if wash_trail[i]["ttl"] <= 0:
			wash_trail.remove_at(i)
		else:
			i += 1


func _update_particles(delta: float) -> void:
	var i := 0
	while i < particles.size():
		var p := particles[i]
		p.ttl -= delta
		if p.ttl <= 0:
			particles.remove_at(i)
		else:
			p.position += p.velocity * delta
			p.velocity *= exp(-delta * 0.8)
			i += 1


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.95, 0.96, 0.98))


func _draw_status() -> void:
	var status_text: String = "Level %d | Time: %.1fs" % [level_index, level_time]
	draw_string(_font(), Vector2(DESIGN_SIZE.x * 0.5 - 40.0, _hud_top_y() + 10.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)


func _draw_car() -> void:
	var car_shape := car_shapes.get(car_type) as PackedVector2Array
	if car_shape == null or car_shape.size() < 3:
		return
	draw_colored_polygon(car_shape, car_color)


func _draw_dirt() -> void:
	for patch in dirt_patches:
		if patch.health <= 0:
			continue
		var alpha := clampf(patch.health / patch.max_health, 0.2, 1.0)
		var color := Color(0.4, 0.3, 0.2, alpha)
		draw_circle(patch.position + patch.drift, patch.radius, color)


func _draw_particles() -> void:
	for p in particles:
		draw_circle(p.position, p.radius, p.color * Color(1.0, 1.0, 1.0, clampf(p.ttl / 0.5, 0.0, 1.0)))


func _draw_gleam() -> void:
	if _gleam_time < 0.0:
		return
	var progress := _gleam_time
	var width := 80.0
	var height := 200.0
	var x := -width + progress * (DESIGN_SIZE.x + width * 2.0) - width
	var gleam_color := Color(1.0, 1.0, 1.0, 0.3 * (1.0 - progress))
	draw_rect(Rect2(x, 200.0, width, height), gleam_color)


func _draw_wash_trail() -> void:
	for i in range(wash_trail.size()):
		var t := wash_trail[i]
		var progress := 1.0 - t["ttl"] / TRAIL_LIFETIME
		var alpha := (1.0 - progress) * 0.4
		var tool_col := tool_colors.get(selected_tool, Color.WHITE)
		draw_circle(t["pos"], 3.0 + progress * 2.0, tool_col * Color(1.0, 1.0, 1.0, alpha))


func _draw_tool_cursor() -> void:
	var cursor_col := tool_colors.get(selected_tool, Color.WHITE)
	draw_circle(pointer_position, 8.0, cursor_col * Color(1.0, 1.0, 1.0, 0.6))


func _draw_grade_tracker() -> void:
	var progress := clean_progress
	var bar_width := 160.0
	var bar_height := 8.0
	var bar_x := (DESIGN_SIZE.x - bar_width) * 0.5
	var bar_y := DESIGN_SIZE.y - 60.0
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(bar_x, bar_y, bar_width * progress, bar_height), Color(0.2, 0.8, 0.4))


func _draw_bomb_button() -> void:
	if coins < BOMB_COST:
		return
	var btn_size := 36.0
	var btn_x := DESIGN_SIZE.x - 30.0 - btn_size
	var btn_y := TOOLBAR_Y - btn_size - 20.0
	var btn_rect := Rect2(btn_x, btn_y, btn_size, btn_size)
	draw_rect(btn_rect, Color(1.0, 0.3, 0.3))
	draw_string(_font(), Vector2(btn_x + 8.0, btn_y + 12.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_toolbar() -> void:
	draw_rect(Rect2(0.0, TOOLBAR_Y, DESIGN_SIZE.x, DESIGN_SIZE.y - TOOLBAR_Y), Color(0.9, 0.9, 0.9))
	for i in range(tool_ids.size()):
		var tool_id := tool_ids[i]
		var btn_x := 16.0 + i * 90.0
		var btn_y := TOOL_BUTTON_Y
		var btn_rect := Rect2(btn_x, btn_y, 72.0, 72.0)
		var is_selected := selected_tool == tool_id
		draw_rect(btn_rect, Color(0.2, 0.2, 0.2) if is_selected else Color(0.7, 0.7, 0.7))
		draw_string(_font(), Vector2(btn_x + 12.0, btn_y + 32.0), tool_labels[tool_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if is_selected else Color.BLACK)


func _draw_completion_panel() -> void:
	if not completed:
		return
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.0, 0.0, 0.0, 0.5))
	var panel_height := 200.0
	var panel_y := (DESIGN_SIZE.y - panel_height) * 0.5
	draw_rect(Rect2(20.0, panel_y, DESIGN_SIZE.x - 40.0, panel_height), Color(0.2, 0.2, 0.2))
	draw_string(_font(), Vector2(50.0, panel_y + 40.0), "Level Complete!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(_font(), Vector2(50.0, panel_y + 80.0), "Time: %.1fs" % level_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(_font(), Vector2(50.0, panel_y + 110.0), "Best Combo: %d" % best_combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_daily_mission() -> void:
	if daily_mission_type.is_empty():
		return
	var mission_text: String = daily_mission_label % daily_mission_target
	draw_string(_font(), Vector2(20.0, DESIGN_SIZE.y - 30.0), mission_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	var progress_text: String = "Progress: %d/%d" % [daily_mission_progress, daily_mission_target]
	draw_string(_font(), Vector2(20.0, DESIGN_SIZE.y - 12.0), progress_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.DARK_GRAY)


func _draw_top_buttons() -> void:
	var btn_size := 32.0
	var btn_spacing := 10.0
	var start_x := DESIGN_SIZE.x - btn_size - 12.0
	draw_rect(Rect2(start_x, TOP_BUTTON_Y, btn_size, btn_size), Color(0.1, 0.1, 0.1))
	draw_string(_font(), Vector2(start_x + 8.0, TOP_BUTTON_Y + 8.0), "=", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_title_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.9, 0.95, 1.0))
	draw_string(_font(), Vector2(DESIGN_SIZE.x * 0.5 - 60.0, 100.0), "Foam Party", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.BLACK)
	draw_string(_font(), Vector2(DESIGN_SIZE.x * 0.5 - 80.0, 200.0), "Tap to Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.BLACK)


func _draw_tutorial() -> void:
	if not show_tutorial:
		return
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(30.0, 150.0, DESIGN_SIZE.x - 60.0, 400.0), Color(0.2, 0.2, 0.2))
	draw_string(_font(), Vector2(50.0, 180.0), "How to Play", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(_font(), Vector2(50.0, 220.0), "Drag to wash the car", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(_font(), Vector2(50.0, 250.0), "Switch tools at the bottom", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(_font(), Vector2(50.0, 280.0), "Complete the level before time runs out", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(_font(), Vector2(50.0, 520.0), "Tap anywhere to dismiss", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GRAY)


func _to_design(screen_point: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale := viewport_size.y / DESIGN_SIZE.y
	var offset_x := (viewport_size.x - DESIGN_SIZE.x * scale) * 0.5
	return (screen_point - Vector2(offset_x, 0.0)) / scale


func _handle_key(keycode: Key) -> void:
	if keycode == KEY_1:
		selected_tool = TOOL_WATER
		_play_ui_select()
	elif keycode == KEY_2:
		selected_tool = TOOL_SOAP
		_play_ui_select()
	elif keycode == KEY_3:
		selected_tool = TOOL_SPONGE
		_play_ui_select()
	elif keycode == KEY_4:
		selected_tool = TOOL_AIR
		_play_ui_select()
	elif keycode == KEY_R:
		reset_game(level_index)

elif keycode == KEY_N:
		reset_game(level_index + 1)
	elif keycode == KEY_ESCAPE:
		get_tree().quit()


func _handle_tap(design_point: Vector2) -> bool:
	if show_tutorial:
		show_tutorial = false
		return true
	if game_state == STATE_TITLE:
		start_game()
		return true
	var toolbar_rect := Rect2(0.0, TOOL_BUTTON_Y, DESIGN_SIZE.x, TOOL_BUTTON_HEIGHT)
	if toolbar_rect.has_point(design_point):
		var tool_index := int((design_point.x - 16.0) / 90.0)
		if tool_index >= 0 and tool_index < tool_ids.size():
			selected_tool = tool_ids[tool_index]
			_play_ui_select()
		return true
	return false


func _active_hint_tool() -> String:
	return ""


func _star_time_threshold(stars: int) -> float:
	if stars == 3:
		return STAR3_TIME
	if stars == 2:
		return STAR2_TIME
	return 999999.0


func _grade_time_to_downgrade() -> float:
	var time_remaining_3star := _star_time_threshold(3) - level_time
	var time_remaining_2star := _star_time_threshold(2) - level_time
	if time_remaining_3star > 0.0:
		return time_remaining_3star
	elif time_remaining_2star > 0.0:
		return time_remaining_2star
	else:
		return -1.0


func _build_car_shapes() -> void:
	var compact_shape := PackedVector2Array([
		Vector2(100.0, 400.0), Vector2(290.0, 400.0),
		Vector2(300.0, 500.0), Vector2(90.0, 500.0)
	])
	var sports_shape := PackedVector2Array([
		Vector2(120.0, 420.0), Vector2(270.0, 420.0),
		Vector2(290.0, 480.0), Vector2(100.0, 480.0)
	])
	var truck_shape := PackedVector2Array([
		Vector2(80.0, 420.0), Vector2(310.0, 420.0),
		Vector2(320.0, 520.0), Vector2(70.0, 520.0)
	])
	car_shapes = {
		"compact": compact_shape,
		"sports": sports_shape,
		"truck": truck_shape,
	}


func _set_car_palette() -> void:
	car_color = Color("#ffcf5a")


func _set_design_draw_transform() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale := viewport_size.y / DESIGN_SIZE.y
	var offset_x := (viewport_size.x - DESIGN_SIZE.x * scale) * 0.5
	draw_set_transform(Vector2(offset_x, 0.0), 0.0, Vector2(scale, scale))


func _set_gameplay_draw_transform() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale := viewport_size.y / DESIGN_SIZE.y
	var offset_x := (viewport_size.x - DESIGN_SIZE.x * scale) * 0.5
	draw_set_transform(Vector2(offset_x, 0.0), 0.0, Vector2(scale * GAMEPLAY_SCALE, scale * GAMEPLAY_SCALE))


func _update_canvas_transform() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale := viewport_size.y / DESIGN_SIZE.y
	var offset_x := (viewport_size.x - DESIGN_SIZE.x * scale) * 0.5
	canvas_origin = Vector2(offset_x, 0.0)
	canvas_scale = scale
