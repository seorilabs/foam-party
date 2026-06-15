extends Control

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
var best_times: Dictionary = {}
var is_new_record := false
var record_pop_time := -10.0
var _tool_select_time := -10.0
var _bomb_press_time := -10.0
var game_state := STATE_TITLE
var coins := 0
var total_stars := 0
var coin_reward := 0
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
	if config.load(SAVE_PATH) != OK:
		return
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


func _save_progress() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("game", "level", level_index)
	config.set_value("game", "coins", coins)
	config.set_value("game", "total_stars", total_stars)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "tutorial_seen", tutorial_seen)
	config.set_value("game", "best_times", best_times)
	config.save(SAVE_PATH)


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
		_save_progress()


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
	var data := PackedByteArray()
	var freqs := [783.99, 987.77, 1174.66]  # G5, B5, D6 — rising major triad
	for note in 3:
		var phase := 0.0
		for i in range(note_samples):
			var t: float = float(i) / float(AUDIO_MIX_RATE)
			phase += TAU * freqs[note] / float(AUDIO_MIX_RATE)
			var env := exp(-t * 10.0) * clampf(t / 0.004, 0.0, 1.0)
			var tail := clampf(float(note_samples - 1 - i) / float(int(AUDIO_MIX_RATE * 0.010)), 0.0, 1.0)
			_append_i16_sample(data, sin(phase) * 0.36 * env * tail)
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
		_draw_combo_badge()
		_draw_bomb_button()
		_draw_toolbar()
		_draw_completion_panel()
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
	_prev_star3_time_ok = true
	_prev_star2_time_ok = true
	_star3_combo_unlocked = false
	_last_milestone_haptic_combo = -1
	_prev_in_warn_zone = false
	earned_stars = 0
	combo_pop_time = -10.0
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


func _hud_top_y() -> float:
	return maxf(HUD_TOP_Y, _safe_area_design_insets().y + HUD_SAFE_PADDING)


func _top_button_y() -> float:
	if game_state == STATE_PLAYING:
		return _hud_top_y() + 96.0
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
		reset_game(level_index + 1)
		_save_progress()
		_play_ui_select()
	elif keycode == KEY_R and completed:
		reset_game(level_index)
		_play_ui_select()


func _handle_tap(point: Vector2) -> bool:
	if show_tutorial:
		_dismiss_tutorial()
		return true

	if game_state == STATE_TITLE:
		if _get_start_rect().has_point(point):
			start_game()
			_play_ui_select()
		elif _get_sound_rect().has_point(point):
			_toggle_sound()
		elif _get_help_rect().has_point(point):
			show_tutorial = true
			_play_ui_select()
		return true

	if completed and _get_retry_rect().has_point(point):
		reset_game(level_index)
		_play_ui_select()
		return true

	if completed and _get_next_rect().has_point(point):
		reset_game(level_index + 1)
		_save_progress()
		_play_ui_select()
		return true

	if _get_sound_rect().has_point(point):
		_toggle_sound()
		return true

	if _get_help_rect().has_point(point):
		show_tutorial = true
		is_washing = false
		_play_ui_select()
		return true

	if not completed and _get_bomb_rect().has_point(point):
		if coins < BOMB_COST:
			if audio_playback_enabled and is_instance_valid(_bomb_deny_sfx):
				_bomb_deny_sfx.stop()
				_bomb_deny_sfx.play()
		else:
			if apply_foam_bomb():
				_bomb_press_time = float(Time.get_ticks_msec()) / 1000.0
			else:
				if audio_playback_enabled and is_instance_valid(_bomb_deny_sfx):
					_bomb_deny_sfx.stop()
					_bomb_deny_sfx.play()
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
	show_tutorial = false
	_play_ui_select()
	if not tutorial_seen:
		tutorial_seen = true
		_save_progress()


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


func apply_foam_bomb() -> bool:
	if completed or coins < BOMB_COST:
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
		if patch.kind == "oil" or patch.kind == "bug":
			patch.state = STATE_LOOSENED
		elif patch.kind == "mud":
			patch.state = STATE_SOAPED
		var center := _patch_center(patch)
		for bubble_index in range(3):
			var offset := Vector2(rng.randf_range(-patch.radius, patch.radius), rng.randf_range(-patch.radius, patch.radius))
			particles.append(WashParticle.new(center + offset, Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-40.0, -16.0)), rng.randf_range(0.6, 1.1), rng.randf_range(4.0, 9.0), Color.from_hsv(rng.randf(), 0.12, 1.0, 0.85), STYLE_BUBBLE))
	if not applied:
		return false
	coins -= BOMB_COST
	if audio_playback_enabled and is_instance_valid(_bomb_sfx):
		_bomb_sfx.play(0.0)
	_save_progress()
	return true


func _calc_coin_reward(stars: int) -> int:
	return 20 + stars * 10 + min(best_combo, 10) * 2


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
			type_pool = ["oil", "dust", "oil", "dust", "oil", "leaf", "dust", "bug", "mud"]
			radius_min = 11.0
			radius_max = 20.0
			health_base_min = 80.0
			health_base_max = 135.0
		"truck":
			type_pool = ["mud", "mud", "bug", "leaf", "mud", "bug", "dust", "oil", "leaf"]
			radius_min = 15.0
			radius_max = 28.0
			health_base_min = 85.0
			health_base_max = 145.0
		_:
			type_pool = DIRT_TYPES.duplicate()

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
	match patch.kind:
		"mud":
			# Air does nothing; a dry scrub is premature (rinse or soap it first).
			# Water and soap are both valid mud paths, so they are never flagged.
			if tool_id == TOOL_AIR:
				return true
			if tool_id == TOOL_SPONGE:
				return patch.wetness < 0.2 and patch.soap < 0.15
			return false
		"dust":
			return tool_id == TOOL_SOAP
		"leaf":
			return tool_id != TOOL_AIR
		"oil", "bug":
			if tool_id == TOOL_AIR:
				return true
			var soaped: bool = patch.soap > 0.25 or patch.looseness > 0.35
			if not soaped:
				return tool_id == TOOL_WATER or tool_id == TOOL_SPONGE
			return false
	return false


# The tool currently being coached on screen, or "" when no hint is active.
func _active_hint_tool() -> String:
	if _hint_patch != null and is_instance_valid(_hint_patch) and _hint_patch.hint_time > 0.0 and not _is_patch_removed(_hint_patch):
		return _hint_patch.hint_tool
	return ""


# The tool the player should reach for next on this patch.
func _recommended_tool(patch: DirtPatch) -> String:
	match patch.kind:
		"leaf":
			return TOOL_AIR
		"oil", "bug":
			if patch.soap > 0.25 or patch.looseness > 0.35:
				return TOOL_SPONGE
			return TOOL_SOAP
	return TOOL_WATER


func _update_patch_hint(patch: DirtPatch, delta: float) -> void:
	if _is_patch_removed(patch) or patch.state == STATE_FLYING:
		return
	# Keep coaching even on a stubborn last sliver; only skip the truly-gone.
	if patch.health / max(1.0, patch.max_health) < 0.05:
		return
	if _tool_misapplied(selected_tool, patch):
		# +2*delta here, -delta decay in _update_dirt_motion -> net +delta only
		# while actively rubbing, so brief stray touches never accumulate.
		patch.resist_time += delta * 2.0
		if patch.resist_time >= 0.3:
			# Keep a single active coach so overlapping patches stay readable.
			if _hint_patch != null and _hint_patch != patch:
				_hint_patch.hint_time = 0.0
			_hint_patch = patch
			patch.hint_tool = _recommended_tool(patch)
			var hint_was_inactive := patch.hint_time <= 0.0
			patch.hint_time = max(patch.hint_time, 1.4)
			if hint_was_inactive and _hint_sfx_player != null:
				_hint_sfx_player.play()
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
	var push := _push_direction(patch, source_point)
	if _is_light_dirt(patch.kind):
		patch.state = STATE_FLYING
		var lift := Vector2(0.0, -rng.randf_range(10.0, 42.0))
		var target_velocity := push * (235.0 + patch.radius * 3.5) + lift
		patch.velocity = patch.velocity.lerp(target_velocity, clamp(delta * 9.0, 0.0, 1.0))
		patch.drift += patch.velocity * delta
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 2.2)
		var rate := 2.85
		if patch.kind == "dust":
			rate = 2.15
		patch.health -= rate * proximity * delta * CLEAN_DAMAGE_RATE
	else:
		patch.drift += push * delta * proximity * 7.0
		patch.drift = patch.drift.limit_length(5.5)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.08)


func _apply_water_to_patch(patch: DirtPatch, delta: float, proximity: float) -> void:
	patch.wetness = min(1.0, patch.wetness + delta * proximity * 1.85)
	patch.runoff = min(1.0, patch.runoff + delta * proximity * 0.8)

	if patch.kind == "mud":
		patch.state = STATE_RUNOFF if patch.wetness > 0.3 else STATE_WET
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.1)
		patch.health -= 2.25 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "dust":
		patch.state = STATE_RUNOFF
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.0)
		patch.health -= 1.85 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "leaf":
		patch.state = STATE_WET
		patch.velocity += Vector2(12.0, 36.0) * delta * proximity
		patch.health -= 0.25 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "oil" or patch.kind == "bug":
		var rinse_power: float = patch.soap * (0.75 + patch.looseness)
		if rinse_power > 0.25:
			patch.state = STATE_RUNOFF
			patch.health -= rinse_power * 1.75 * proximity * delta * CLEAN_DAMAGE_RATE
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.55)
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.45)
		else:
			patch.state = STATE_WET
			patch.health -= 0.08 * proximity * delta * CLEAN_DAMAGE_RATE
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.12)
	else:
		patch.state = STATE_WET
		patch.health -= 0.45 * proximity * delta * CLEAN_DAMAGE_RATE


func _apply_soap_to_patch(patch: DirtPatch, delta: float, proximity: float) -> void:
	if patch.kind == "oil" or patch.kind == "bug":
		patch.soap = min(1.0, patch.soap + delta * proximity * 1.65)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.95)
		patch.state = STATE_LOOSENED if patch.looseness > 0.65 else STATE_SOAPED
		patch.health -= 0.05 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "mud":
		patch.soap = min(1.0, patch.soap + delta * proximity * 0.85)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.42)
		patch.state = STATE_SOAPED
		patch.health -= 0.12 * proximity * delta * CLEAN_DAMAGE_RATE
	else:
		patch.soap = min(0.45, patch.soap + delta * proximity * 0.25)


func _apply_sponge_to_patch(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float) -> void:
	var push := _push_direction(patch, source_point)
	patch.drift += push * delta * proximity * 3.0
	patch.drift = patch.drift.limit_length(7.0)

	if patch.kind == "oil" or patch.kind == "bug":
		if patch.soap > 0.25 or patch.looseness > 0.35:
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.2)
			patch.health -= (1.15 + patch.soap) * proximity * delta * CLEAN_DAMAGE_RATE
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.22)
		else:
			patch.health -= 0.12 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "mud":
		if patch.wetness > 0.2 or patch.soap > 0.15:
			patch.state = STATE_LOOSENED
			patch.health -= 1.15 * proximity * delta * CLEAN_DAMAGE_RATE
		else:
			patch.health -= 0.35 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "dust":
		patch.health -= 0.45 * proximity * delta * CLEAN_DAMAGE_RATE
	elif patch.kind == "leaf":
		patch.health -= 0.2 * proximity * delta * CLEAN_DAMAGE_RATE


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

		patch.wetness = max(0.0, patch.wetness - delta * 0.08)
		if patch.state != STATE_SOAPED and patch.state != STATE_LOOSENED:
			patch.soap = max(0.0, patch.soap - delta * 0.025)

		if patch.health <= 0.0:
			_mark_patch_removed(patch)


func _runoff_cleanup_rate(patch: DirtPatch) -> float:
	if patch.kind == "mud" or patch.kind == "dust":
		return 0.42 + patch.wetness * 0.25
	if patch.kind == "oil" or patch.kind == "bug":
		return patch.soap * 0.18 + patch.looseness * 0.32
	return 0.08


func _patch_center(patch: DirtPatch) -> Vector2:
	return patch.position + patch.drift


func _is_light_dirt(kind: String) -> bool:
	return kind == "leaf" or kind == "dust"


func _push_direction(patch: DirtPatch, source_point: Vector2) -> Vector2:
	var direction := (_patch_center(patch) - source_point).normalized()
	if direction.length() < 0.1:
		direction = Vector2(1.0, -0.18).normalized()
	return direction


func _is_patch_removed(patch: DirtPatch) -> bool:
	return patch.state == STATE_REMOVED or patch.health <= 0.0


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
			if audio_playback_enabled and is_instance_valid(_star3_gate_sfx):
				_star3_gate_sfx.stop()
				_star3_gate_sfx.play()
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(50)
		if COMBO_BONUS_AMOUNTS.has(combo_count):
			var _bonus: int = COMBO_BONUS_AMOUNTS[combo_count]
			coins += _bonus
			_combo_bonus_amount = _bonus
			_combo_bonus_time = float(Time.get_ticks_msec()) / 1000.0
			if audio_playback_enabled and is_instance_valid(_coin_bonus_sfx):
				_coin_bonus_sfx.stop()
				_coin_bonus_sfx.play()
		combo_pop_time = float(Time.get_ticks_msec()) / 1000.0
		if combo_count % 5 == 0 and combo_count != _last_milestone_haptic_combo:
			_last_milestone_haptic_combo = combo_count
			if audio_playback_enabled and is_instance_valid(_combo_milestone_player):
				_combo_milestone_player.stop()
				_combo_milestone_player.play()
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(38)
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
	return center.x < -48.0 or center.x > DESIGN_SIZE.x + 48.0 or center.y < 300.0 or center.y > 748.0


func _update_wash_trail(delta: float) -> void:
	# Age every existing point by the frame delta so the streak fades on a fixed
	# clock, independent of frame rate.
	for index in range(wash_trail.size() - 1, -1, -1):
		var point := wash_trail[index] as Dictionary
		point["age"] = float(point["age"]) + delta
		if float(point["age"]) > TRAIL_LIFETIME:
			wash_trail.remove_at(index)

	var active := is_washing and not completed and game_state == STATE_PLAYING and not show_tutorial
	var in_play_area := pointer_position.y > 120.0 and pointer_position.y < 744.0 and pointer_position != Vector2.ZERO
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
	if tool_id == TOOL_AIR:
		return 68.0
	if tool_id == TOOL_WATER:
		return 55.0
	if tool_id == TOOL_SOAP:
		return 60.0
	if tool_id == TOOL_SPONGE:
		return 38.0
	return 48.0


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
		coins += coin_reward
		total_stars += earned_stars
		_register_best_time()
		_save_progress()
		_stop_tool_loop()
		_play_completion_sound()
		_play_star_earn_sfx(earned_stars, func() -> void:
			if audio_playback_enabled and is_instance_valid(_coin_bonus_sfx):
				_coin_bonus_sfx.stop()
				_coin_bonus_sfx.play())
		_spawn_completion_burst()
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(80)


# Star time threshold tightens 1.5% per level after the first (floor at 60% of base).
# This ensures experienced players face a gradually rising skill ceiling.
func _star_time_threshold(tier: int) -> float:
	var base := STAR3_TIME if tier == 3 else STAR2_TIME
	return base * maxf(0.6, 1.0 - float(max(0, level_index - 1)) * 0.015)


func _calc_stars() -> int:
	if level_time <= _star_time_threshold(3) and best_combo >= STAR3_COMBO:
		return 3
	if level_time <= _star_time_threshold(2):
		return 2
	return 1


# Live state of one star slot in the HUD grade tracker (0 = first star).
# earned: counted in the grade right now. target: still reachable but a
# condition is unmet (3rd star needs the combo gate). locked: no longer reachable.
func _grade_slot_state(slot_index: int) -> String:
	match slot_index:
		0:
			return GRADE_SLOT_EARNED
		1:
			return GRADE_SLOT_EARNED if level_time <= _star_time_threshold(2) else GRADE_SLOT_LOCKED
		2:
			if level_time > _star_time_threshold(3):
				return GRADE_SLOT_LOCKED
			return GRADE_SLOT_EARNED if best_combo >= STAR3_COMBO else GRADE_SLOT_TARGET
	return GRADE_SLOT_LOCKED


# Seconds until the next star is lost, or -1 once only the floor star remains.
func _grade_time_to_downgrade() -> float:
	if level_time <= _star_time_threshold(3):
		return _star_time_threshold(3) - level_time
	if level_time <= _star_time_threshold(2):
		return _star_time_threshold(2) - level_time
	return -1.0


# Star slot (0-based) whose threshold is approaching next, or -1 when none.
func _grade_at_risk_slot() -> int:
	if level_time <= _star_time_threshold(3):
		return 2
	if level_time <= _star_time_threshold(2):
		return 1
	return -1


func _register_best_time() -> void:
	var previous_best: float = _best_time_for_level(level_index)
	is_new_record = previous_best <= 0.0 or level_time < previous_best
	if is_new_record:
		best_times[level_index] = level_time
		record_pop_time = float(Time.get_ticks_msec()) / 1000.0
		if audio_playback_enabled and is_instance_valid(_record_sfx):
			_record_sfx.play()


func _best_time_for_level(level: int) -> float:
	return float(best_times.get(level, 0.0))


func _check_progress_milestone() -> void:
	const THRESHOLDS := [0.25, 0.50, 0.75]
	const MESSAGES := ["25%! Great start!", "Halfway clean!", "Almost done!"]
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
	if _milestone_sfx_player != null:
		_milestone_sfx_player.pitch_scale = 0.85 + float(stage) * 0.18
		_milestone_sfx_player.play()
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
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("#87e3e9"))
	draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE.x, 155.0), Color("#9ff0ef"))
	draw_rect(Rect2(0.0, 620.0, DESIGN_SIZE.x, 224.0), Color("#6dd0d1"))

	for y_index in range(0, 7):
		var y := 638.0 + float(y_index) * 32.0
		draw_line(Vector2(0.0, y), Vector2(DESIGN_SIZE.x, y + 28.0), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	for x_index in range(0, 8):
		var x := float(x_index) * 58.0 - 30.0
		draw_line(Vector2(x, 620.0), Vector2(x + 80.0, DESIGN_SIZE.y), Color(0.0, 0.0, 0.0, 0.08), 1.0)

	draw_circle(Vector2(68.0, 170.0), 48.0, Color(1.0, 1.0, 1.0, 0.18))
	draw_circle(Vector2(345.0, 197.0), 28.0, Color(1.0, 1.0, 1.0, 0.13))
	draw_circle(Vector2(35.0, 720.0), 20.0, Color(1.0, 1.0, 1.0, 0.16))
	draw_circle(Vector2(356.0, 690.0), 24.0, Color(1.0, 1.0, 1.0, 0.12))


func _draw_status() -> void:
	var font: Font = _font()
	var card := Rect2(14.0, _hud_top_y(), 362.0, 84.0)
	draw_style_box(_style("hud_shadow", Color(0.05, 0.23, 0.33, 0.25), 20.0), Rect2(card.position + Vector2(0.0, 3.0), card.size))
	draw_style_box(_style("hud_card", Color(0.97, 0.99, 1.0, 0.94), 20.0), card)

	var coin_chip := Rect2(150.0, card.position.y + 10.0, 90.0, 28.0)
	var title_width := coin_chip.position.x - 32.0 - 8.0
	var title_size := 19
	while title_size > 15 and font.get_string_size("Foam Party", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x > title_width:
		title_size -= 1
	draw_string(font, Vector2(32.0, card.position.y + 32.0), "Foam Party", HORIZONTAL_ALIGNMENT_LEFT, title_width, title_size, Color("#0d3b55"))
	draw_style_box(_style("coin_chip", Color("#fff3cf"), 14.0), coin_chip)
	draw_circle(coin_chip.position + Vector2(16.0, 14.0), 8.0, Color("#ffce3d"))
	draw_circle(coin_chip.position + Vector2(16.0, 14.0), 8.0, Color("#9a7400"), false, 1.5)
	var coin_text := "%d" % coins
	var coin_text_width := coin_chip.size.x - 38.0
	var coin_font_size := 14
	while coin_font_size > 10 and font.get_string_size(coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, coin_font_size).x > coin_text_width:
		coin_font_size -= 1
	draw_string(font, Vector2(coin_chip.position.x + 30.0, coin_chip.position.y + 20.0), coin_text, HORIZONTAL_ALIGNMENT_LEFT, coin_text_width, coin_font_size, Color("#6b5200"))
	var badge := Rect2(248.0, card.position.y + 10.0, 112.0, 28.0)
	draw_style_box(_style("level_badge", Color("#49a7ff"), 14.0), badge)
	draw_string(font, Vector2(badge.position.x, badge.position.y + 20.0), "%s %02d" % [car_type_labels[car_type], level_index], HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color.WHITE)

	var bar_rect := Rect2(32.0, card.position.y + 46.0, 254.0, 24.0)
	draw_style_box(_style("bar_bg", Color("#d7e8ef"), 12.0), bar_rect)
	var cp := clampf(clean_progress, 0.0, 1.0)
	var fill_width: float = bar_rect.size.x * cp
	_bar_fill_style.bg_color = BAR_COL_START.lerp(BAR_COL_END, cp)
	if cp > 0.0:
		var draw_w := maxf(fill_width, 2.0)
		_bar_fill_style.set_corner_radius_all(mini(6, int(draw_w * 0.5)))
		draw_style_box(_bar_fill_style, Rect2(bar_rect.position, Vector2(draw_w, bar_rect.size.y)))
	draw_string(font, Vector2(294.0, bar_rect.position.y + 18.0), "%.0f%%" % (cp * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 66.0, 15, Color("#0d3b55"))

	if _progress_milestone_time >= 0.0:
		var age := float(Time.get_ticks_msec()) / 1000.0 - _progress_milestone_time
		if age < 1.4:
			var alpha := 1.0 - age / 1.4
			var rise := age * 42.0
			var mc := _progress_milestone_color
			draw_string(font, Vector2(32.0, bar_rect.position.y - rise), _progress_milestone_text, HORIZONTAL_ALIGNMENT_CENTER, 254.0, 17, Color(mc.r, mc.g, mc.b, alpha))

	var hint_rect := Rect2(22.0, minf(696.0, _tool_button_y() - 46.0), 244.0, 30.0)
	draw_style_box(_style("hint_bubble", Color(0.03, 0.14, 0.2, 0.78), 15.0), hint_rect)
	draw_string(font, Vector2(hint_rect.position.x, hint_rect.position.y + 21.0), "%s · %s" % [tool_labels[selected_tool], _tool_hint()], HORIZONTAL_ALIGNMENT_CENTER, hint_rect.size.x, 13, Color(0.93, 0.99, 1.0))


func _tool_hint() -> String:
	if selected_tool == TOOL_AIR:
		return "blow leaves"
	if selected_tool == TOOL_WATER:
		return "rinse dirt"
	if selected_tool == TOOL_SOAP:
		return "loosen stains"
	if selected_tool == TOOL_SPONGE:
		return "wipe clean"
	return ""


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
		var center: Vector2 = _patch_center(patch)
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
			_draw_patch_hint(hint_patch, _patch_center(hint_patch))


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
	var in_play_area := pointer_position.y > 120.0 and pointer_position.y < 744.0 and pointer_position != Vector2.ZERO
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
	draw_circle(nozzle, 5.5, Color(0.29, 0.65, 1.0, alpha_scale))


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
	draw_circle(nozzle, 6.5, Color(0.27, 0.38, 0.43, alpha_scale))


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
	draw_circle(nozzle, 6.0, Color(1.0, 1.0, 1.0, alpha_scale))
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
	draw_colored_polygon(body, Color(1.0, 0.62, 0.35, alpha_scale))
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
	draw_string(font, Vector2(0.0, 368.0), "A bubbly car wash game", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 18, Color("#0d3b55"))

	var start_rect := _get_start_rect()
	draw_style_box(_style("start_shadow", Color("#1f8a55"), 16.0), Rect2(start_rect.position + Vector2(0.0, 5.0), start_rect.size))
	draw_style_box(_style("start_button", Color("#39d98a"), 16.0), start_rect)
	var start_label := "Start Wash"
	if level_index > 1:
		start_label = "Continue · %s %02d" % [car_type_labels[car_type], level_index]
	draw_string(font, Vector2(start_rect.position.x, start_rect.position.y + 38.0), start_label, HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, 19, Color("#0d3b2a"))

	draw_string(font, Vector2(0.0, 588.0), "Coins %d · Stars %d" % [coins, total_stars], HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 15, Color(1.0, 1.0, 1.0, 0.9))
	var version_y := minf(826.0, DESIGN_SIZE.y - _safe_area_design_insets().w - 12.0)
	draw_string(font, Vector2(0.0, version_y), "v0.1", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 12, Color(1.0, 1.0, 1.0, 0.5))


func _draw_top_buttons() -> void:
	var font: Font = _font()
	var sound_rect := _get_sound_rect()
	var help_rect := _get_help_rect()
	for rect in [sound_rect, help_rect]:
		draw_style_box(_style("round_button", Color(0.03, 0.14, 0.2, 0.62), 18.0), rect)
	var icon_color := Color(0.93, 0.99, 1.0)
	var speaker_center := sound_rect.get_center()
	draw_colored_polygon(PackedVector2Array([
		speaker_center + Vector2(-9.0, -3.0), speaker_center + Vector2(-3.0, -3.0), speaker_center + Vector2(3.0, -9.0),
		speaker_center + Vector2(3.0, 9.0), speaker_center + Vector2(-3.0, 3.0), speaker_center + Vector2(-9.0, 3.0),
	]), icon_color)
	if sound_enabled:
		draw_arc(speaker_center + Vector2(4.0, 0.0), 7.0, -1.0, 1.0, 8, icon_color, 2.0)
	else:
		draw_line(speaker_center + Vector2(-11.0, -11.0), speaker_center + Vector2(11.0, 11.0), Color("#ff6b6b"), 3.0)
	draw_string(font, Vector2(help_rect.position.x, help_rect.position.y + 26.0), "?", HORIZONTAL_ALIGNMENT_CENTER, help_rect.size.x, 20, icon_color)


func _draw_tutorial() -> void:
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.55))
	var panel := Rect2(30.0, 176.0, 330.0, 452.0)
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 44.0), "Wash Guide", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color("#123246"))

	var rows := [
		[TOOL_AIR, "Air", "Blow off leaves and dust"],
		[TOOL_WATER, "Water", "Rinse mud and soap away"],
		[TOOL_SOAP, "Soap", "Soften oil and bug marks"],
		[TOOL_SPONGE, "Sponge", "Wipe loosened stains"],
	]
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var row_y := panel.position.y + 92.0 + float(row_index) * 72.0
		draw_style_box(_style("tutorial_row", Color("#e8f3f8"), 14.0), Rect2(panel.position.x + 18.0, row_y - 26.0, panel.size.x - 36.0, 58.0))
		_draw_tool_icon(row[0], Vector2(panel.position.x + 52.0, row_y + 2.0))
		draw_string(font, Vector2(panel.position.x + 92.0, row_y - 2.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, 200.0, 17, Color("#123246"))
		draw_string(font, Vector2(panel.position.x + 92.0, row_y + 20.0), row[2], HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 116.0, 13, Color("#2c6b78"))

	draw_string(font, Vector2(panel.position.x, panel.position.y + 410.0), "Chain combos for 3 stars. Foam Bomb: %d coins" % BOMB_COST, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color("#2c6b78"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 436.0), "Tap to start!", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 16, Color("#1f8a55"))


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
	var bg := Color("#f8f4a6") if can_afford else Color(0.55, 0.6, 0.63, 0.85)
	draw_style_box(_style("bomb_on" if can_afford else "bomb_off", bg, 14.0), rect)
	draw_circle(rect.position + Vector2(22.0, 17.0), 9.0, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(rect.position + Vector2(32.0, 12.0), 6.0, Color(1.0, 1.0, 1.0, 0.8))
	draw_circle(rect.position + Vector2(30.0, 22.0), 4.5, Color(1.0, 1.0, 1.0, 0.8))
	draw_string(font, Vector2(rect.position.x + 42.0, rect.position.y + 20.0), "Foam", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 42.0, 11, Color("#123246"))
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
	var rect := Rect2(14.0, 100.0, 120.0, 56.0)
	draw_style_box(_style("grade_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0), Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("grade_chip", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	var time_left := _grade_time_to_downgrade()
	var at_risk := _grade_at_risk_slot()
	var warning: bool = time_left >= 0.0 and time_left <= STAR_WARN_SECONDS

	var star_y := rect.position.y + 22.0
	var risk_beat: float = 0.5 + 0.5 * sin(time_now * 12.0)
	for slot in range(3):
		var center := Vector2(rect.position.x + 30.0 + float(slot) * 30.0, star_y)
		var state := _grade_slot_state(slot)
		# A star about to be lost pulses a red ring whether it is already earned
		# or still a reachable target, so the urgency reads the same either way.
		var at_risk_here: bool = warning and slot == at_risk
		if at_risk_here:
			draw_arc(center, 13.0, 0.0, TAU, 20, Color(1.0, 0.42, 0.36, 0.35 + 0.45 * risk_beat), 2.5)
		if state == GRADE_SLOT_EARNED:
			var scale: float = 1.0 + (0.16 * risk_beat if at_risk_here else 0.0)
			_draw_star(center, 10.0 * scale, Color("#ffce3d"), Color("#e0a818"))
		elif state == GRADE_SLOT_TARGET:
			var tp: float = 0.5 + 0.5 * sin(time_now * 5.0)
			var ts: float = 1.0 + (0.12 * risk_beat if at_risk_here else 0.0)
			_draw_star(center, 10.0 * ts, Color(1.0, 0.81, 0.24, 0.14 + 0.12 * tp), Color(1.0, 0.81, 0.24, 0.5 + 0.4 * tp))
		else:
			_draw_star(center, 9.0, Color(0.42, 0.5, 0.55, 0.85), Color(0.3, 0.37, 0.42, 0.9))

	var line_y := rect.position.y + rect.size.y - 9.0
	var text := ""
	var col := Color(0.86, 0.93, 0.97)
	if warning:
		var blink: float = 0.55 + 0.45 * sin(time_now * 10.0)
		var secs := int(ceil(time_left))
		if _grade_slot_state(at_risk) == GRADE_SLOT_TARGET:
			# Star is reachable but not yet earned: keep nudging the combo gate
			# so the player races the clock and the combo.
			text = "Combo x%d! %ds" % [STAR3_COMBO, secs]
		else:
			text = "Keep star %d: %ds" % [at_risk + 1, secs]
		col = Color(1.0, 0.74, 0.36)
		col.a = blink
	elif _grade_slot_state(2) == GRADE_SLOT_TARGET:
		text = "Combo x%d for 3 stars" % STAR3_COMBO
		col = Color(1.0, 0.88, 0.55)
	else:
		text = "Time %s" % _format_time(level_time)
	draw_string(font, Vector2(rect.position.x, line_y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, col)


func _draw_customer_patience() -> void:
	if completed:
		return
	# 손님 인내 게이지: STAR2_TIME(140s)을 기준으로 1.0 → 0.0으로 감소.
	# 등급 트래커(x=14, w=120) 오른쪽, 사운드 버튼(x=306) 왼쪽 사이에 배치.
	if STAR2_TIME <= 0.0:
		return
	var patience := clampf(1.0 - level_time / STAR2_TIME, 0.0, 1.0)
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	var rect := Rect2(144.0, 100.0, 110.0, 56.0)

	draw_style_box(_style("cust_shadow", Color(0.03, 0.14, 0.2, 0.22), 16.0),
		Rect2(rect.position + Vector2(0.0, 2.0), rect.size))
	draw_style_box(_style("cust_chip", Color(0.03, 0.14, 0.2, 0.66), 16.0), rect)

	# 손님 얼굴 (카드 왼쪽)
	var face := Vector2(rect.position.x + 26.0, rect.position.y + 24.0)
	var fr := 15.0
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
	var bar := Rect2(rect.position.x + 53.0, rect.position.y + 14.0, 48.0, 11.0)
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
		mood_label = "Happy!"
	elif patience > 0.35:
		mood_label = "OK..."
	elif patience > 0.1:
		mood_label = "Hurry!"
	else:
		var blink := 0.55 + 0.45 * sin(time_now * 8.0)
		mood_label = "ANGRY!"
		mood_col = Color(1.0, 0.62, 0.40, blink)
	draw_string(font, Vector2(rect.position.x + 48.0, rect.position.y + rect.size.y - 8.0),
		mood_label, HORIZONTAL_ALIGNMENT_CENTER, 62.0, 12, mood_col)


func _draw_combo_badge() -> void:
	if completed or combo_count < 2:
		return
	var time_now := float(Time.get_ticks_msec()) / 1000.0
	# Pop amplitude grows with the combo so a longer streak punches harder.
	var pop_amp: float = 0.35 + 0.05 * float(min(combo_count - 2, 8))
	var pop: float = 1.0 + pop_amp * exp(-(time_now - combo_pop_time) * 6.0)
	var badge_size := Vector2(118.0, 36.0) * pop
	var badge_center_y := maxf(134.0, _hud_top_y() + 112.0)
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
	draw_string(_font(), Vector2(badge.position.x, badge.position.y + badge_size.y * 0.5 + 6.0), "Combo x%d" % combo_count, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, int(16.0 * pop), Color("#7a5500") if is_hot else Color("#123246"))
	if _combo_bonus_time >= 0.0:
		var _age := float(Time.get_ticks_msec()) / 1000.0 - _combo_bonus_time
		if _age < 1.2:
			var _alpha := 1.0 - _age / 1.2
			var _rise := _age * 38.0
			draw_string(_font(), Vector2(badge.position.x + 4.0, badge.position.y - _rise - 14.0),
				"+%d coins!" % _combo_bonus_amount, HORIZONTAL_ALIGNMENT_LEFT,
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


func _draw_tool_icon(tool_id: String, center: Vector2) -> void:
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


func _draw_completion_panel() -> void:
	if not completed:
		return
	var font: Font = _font()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.02, 0.1, 0.15, 0.35))
	var panel := Rect2(38.0, 198.0, 314.0, 232.0)
	draw_style_box(_style("panel_shadow", Color(0.03, 0.13, 0.19, 0.4), 24.0), Rect2(panel.position + Vector2(0.0, 5.0), panel.size))
	draw_style_box(_style("panel", Color("#f7fbff"), 24.0), panel)

	var time_now := float(Time.get_ticks_msec()) / 1000.0
	for index in range(3):
		var star_center := Vector2(145.0 + float(index) * 50.0, panel.position.y + 42.0)
		if index < earned_stars:
			var pulse := 1.0 + sin(time_now * 4.0 + float(index) * 0.9) * 0.08
			_draw_star(star_center, 17.0 * pulse, Color("#ffce3d"), Color("#e0a818"))
		else:
			_draw_star(star_center, 15.0, Color("#dde4e8"), Color("#b4c0c7"))

	draw_string(font, Vector2(panel.position.x, panel.position.y + 84.0), "All Clean!", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color("#123246"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 108.0), "%s %02d · %s · Best x%d" % [car_type_labels[car_type], level_index, _format_time(level_time), best_combo], HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#2c6b78"))

	var record_seconds: float = _best_time_for_level(level_index)
	if is_new_record:
		var record_pulse := 1.0 + 0.25 * exp(-(time_now - record_pop_time) * 5.0)
		var record_color := Color("#e0a818").lerp(Color("#fff3cf"), 0.5 + 0.5 * sin(time_now * 6.0))
		_draw_star(Vector2(panel.position.x + 96.0, panel.position.y + 132.0), 7.0 * record_pulse, record_color, Color("#9a7400"))
		_draw_star(Vector2(panel.position.x + panel.size.x - 96.0, panel.position.y + 132.0), 7.0 * record_pulse, record_color, Color("#9a7400"))
		draw_string(font, Vector2(panel.position.x, panel.position.y + 138.0), "New record! %s" % _format_time(record_seconds), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, int(17.0 * record_pulse), Color("#d98a00"))
	elif record_seconds > 0.0:
		draw_string(font, Vector2(panel.position.x, panel.position.y + 136.0), "Best time %s" % _format_time(record_seconds), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, Color("#6b7d86"))

	var reward_chip := Rect2(panel.position.x + panel.size.x - 106.0, panel.position.y - 14.0, 96.0, 30.0)
	draw_style_box(_style("reward_chip", Color("#ffce3d"), 15.0), reward_chip)
	draw_circle(reward_chip.position + Vector2(16.0, 15.0), 8.0, Color("#fff3cf"))
	draw_circle(reward_chip.position + Vector2(16.0, 15.0), 8.0, Color("#9a7400"), false, 1.5)
	draw_string(font, Vector2(reward_chip.position.x + 28.0, reward_chip.position.y + 21.0), "+%d" % coin_reward, HORIZONTAL_ALIGNMENT_LEFT, 64.0, 15, Color("#6b5200"))

	var retry_rect := _get_retry_rect()
	draw_style_box(_style("retry_shadow", Color("#246076"), 14.0), Rect2(retry_rect.position + Vector2(0.0, 4.0), retry_rect.size))
	draw_style_box(_style("retry_button", Color("#7fd6e6"), 14.0), retry_rect)
	draw_string(font, Vector2(retry_rect.position.x, retry_rect.position.y + 30.0), "↺ Wash Again", HORIZONTAL_ALIGNMENT_CENTER, retry_rect.size.x, 16, Color("#0d3b55"))

	var next_rect := _get_next_rect()
	draw_style_box(_style("next_shadow", Color("#1f8a55"), 14.0), Rect2(next_rect.position + Vector2(0.0, 4.0), next_rect.size))
	draw_style_box(_style("next_button", Color("#39d98a"), 14.0), next_rect)
	draw_string(font, Vector2(next_rect.position.x, next_rect.position.y + 30.0), "Next Car ▶", HORIZONTAL_ALIGNMENT_CENTER, next_rect.size.x, 16, Color("#0d3b2a"))


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


func _get_retry_rect() -> Rect2:
	return Rect2(58.0, 360.0, 131.0, 46.0)


func _get_next_rect() -> Rect2:
	return Rect2(201.0, 360.0, 131.0, 46.0)


func _get_start_rect() -> Rect2:
	return Rect2(95.0, 488.0, 200.0, 58.0)


func _get_sound_rect() -> Rect2:
	return Rect2(306.0, _top_button_y(), 36.0, 36.0)


func _get_help_rect() -> Rect2:
	return Rect2(344.0, _top_button_y(), 36.0, 36.0)


func _get_bomb_rect() -> Rect2:
	return Rect2(276.0, minf(688.0, _tool_button_y() - 58.0), 92.0, 46.0)
