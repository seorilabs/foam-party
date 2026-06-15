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
const SAVE_PATH := "user://foam_party_save.cfg"
const BOMB_COST := 40
const STATE_TITLE := "title"
const STATE_PLAYING := "playing"
const GAMEPLAY_SCALE := 1.16
const GAMEPLAY_PIVOT := Vector2(195.0, 545.0)
const GAMEPLAY_OFFSET := Vector2(0.0, 0.0)
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
var combo_count := 0
var combo_timer := 0.0
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
	"compact": "시티카",
	"sports": "스포츠카",
	"truck": "트럭",
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
	TOOL_AIR: "바람",
	TOOL_WATER: "고압수",
	TOOL_SOAP: "비누",
	TOOL_SPONGE: "스펀지",
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


func _ready() -> void:
	rng.seed = 42690
	sfx_rng.seed = 8808
	mouse_filter = Control.MOUSE_FILTER_STOP
	persistence_enabled = DisplayServer.get_name() != "headless" and OS.get_environment("FOAM_DISABLE_SAVE") != "1"
	_setup_font()
	_build_car_shapes()
	_load_progress()
	_setup_audio()
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
		if combo_timer > 0.0:
			combo_timer -= delta
			if combo_timer <= 0.0:
				combo_timer = 0.0
				combo_count = 0

	if is_washing and not completed and game_state == STATE_PLAYING and not show_tutorial:
		_apply_tool_at(pointer_position, delta)

	_update_wash_trail(delta)
	_update_dirt_motion(delta)
	_update_particles(delta)
	_update_clean_progress()
	_update_audio()
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

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "배경음악"
	bgm_player.stream = _make_bgm_stream()
	bgm_player.volume_db = -23.0
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	if audio_playback_enabled:
		bgm_player.play()

	tool_loop_player = AudioStreamPlayer.new()
	tool_loop_player.name = "청소도구소리"
	tool_loop_player.volume_db = -7.0
	tool_loop_player.finished.connect(_on_tool_loop_finished)
	add_child(tool_loop_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.name = "선택효과음"
	ui_sfx_player.volume_db = -8.0
	add_child(ui_sfx_player)

	completion_sfx_player = AudioStreamPlayer.new()
	completion_sfx_player.name = "완료효과음"
	completion_sfx_player.volume_db = -5.0
	add_child(completion_sfx_player)

	removal_sfx_player = AudioStreamPlayer.new()
	removal_sfx_player.name = "제거효과음"
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