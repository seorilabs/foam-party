extends Node

# Self-contained procedural audio engine for Foam Party.
#
# PR-R3: relocated verbatim from main.gd. Every stream-synthesis and SFX
# playback routine lives here; main.gd only decides WHEN to trigger a sound and
# calls the public methods below. Function bodies are byte-identical to their
# former main.gd counterparts — this is a pure structural move.

const AUDIO_MIX_RATE := 22050
const POP_NOTES := [523.25, 659.25, 783.99, 880.0, 1046.5]
const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"

var bgm_player: AudioStreamPlayer
var tool_loop_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var completion_sfx_player: AudioStreamPlayer
var active_tool_sound := ""
var audio_playback_enabled := true
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
var _star3_gate_sfx: AudioStreamPlayer = null
var _star_warn_sfx: AudioStreamPlayer = null
var _patience_warn_sfx: AudioStreamPlayer = null
var _bomb_sfx: AudioStreamPlayer = null
var _bomb_deny_sfx: AudioStreamPlayer = null
var _coin_bonus_sfx: AudioStreamPlayer = null
var _star_earn_sfx: AudioStreamPlayer = null

# SFX RNG relocated verbatim from main.gd (was `sfx_rng`, seeded 8808 in _ready).
# Only ever advanced by play_removal(), so moving it preserves the exact
# random sequence. Seeded in _init() so setup() stays byte-identical.
var sfx_rng := RandomNumberGenerator.new()

# Gameplay state pushed in by main via update() once per frame. The tool-loop
# `finished` signal handler reads these; previously it read main's live members,
# now it reads the last value update() cached (refreshed every _process frame).
var is_washing := false
var completed := false
var selected_tool := TOOL_WATER


func _init() -> void:
	sfx_rng.seed = 8808


func setup() -> void:
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


# Was _update_audio() in main.gd. The leading three lines cache the gameplay
# state that _on_tool_loop_finished() reads; everything below is the verbatim
# _update_audio body.
func update(p_is_washing: bool, p_selected_tool: String, p_completed: bool) -> void:
	is_washing = p_is_washing
	selected_tool = p_selected_tool
	completed = p_completed
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


func stop_tool_loop() -> void:
	_stop_tool_loop()


func get_stream_count() -> int:
	return tool_audio_streams.size()


func play_ui_select() -> void:
	if ui_sfx_player == null or not audio_playback_enabled:
		return
	ui_sfx_player.stop()
	ui_sfx_player.stream = ui_select_stream
	ui_sfx_player.play()


func play_completion() -> void:
	if completion_sfx_player == null or not audio_playback_enabled:
		return
	completion_sfx_player.stop()
	completion_sfx_player.stream = completion_stream
	completion_sfx_player.play()


func play_removal(combo_count: int) -> void:
	if removal_sfx_player == null or not audio_playback_enabled:
		return
	removal_sfx_player.stop()
	removal_sfx_player.stream = removal_stream
	var combo_pitch: float = 0.92 + 0.05 * float(min(combo_count, 9))
	removal_sfx_player.pitch_scale = combo_pitch + sfx_rng.randf_range(-0.02, 0.02)
	removal_sfx_player.play()


# --- gameplay-triggered one-shots (inline guards relocated verbatim from
# their former main.gd call sites; main now decides WHEN, this decides HOW) ---
func play_star_warn() -> void:
	if audio_playback_enabled and is_instance_valid(_star_warn_sfx):
		_star_warn_sfx.stop()
		_star_warn_sfx.play()


func play_patience_warn() -> void:
	if audio_playback_enabled and is_instance_valid(_patience_warn_sfx):
		_patience_warn_sfx.stop()
		_patience_warn_sfx.play()


func play_star_lost() -> void:
	if audio_playback_enabled and is_instance_valid(_star_lost_sfx):
		_star_lost_sfx.stop()
		_star_lost_sfx.play()


func play_combo_break() -> void:
	if audio_playback_enabled and is_instance_valid(combo_break_player):
		combo_break_player.stop()
		combo_break_player.play()


func play_bomb_deny() -> void:
	if audio_playback_enabled and is_instance_valid(_bomb_deny_sfx):
		_bomb_deny_sfx.stop()
		_bomb_deny_sfx.play()


func play_bomb() -> void:
	if audio_playback_enabled and is_instance_valid(_bomb_sfx):
		_bomb_sfx.play(0.0)


func play_hint() -> void:
	if _hint_sfx_player != null:
		_hint_sfx_player.play()


func play_star3_gate() -> void:
	if audio_playback_enabled and is_instance_valid(_star3_gate_sfx):
		_star3_gate_sfx.stop()
		_star3_gate_sfx.play()


func play_coin_bonus() -> void:
	if audio_playback_enabled and is_instance_valid(_coin_bonus_sfx):
		_coin_bonus_sfx.stop()
		_coin_bonus_sfx.play()


func play_combo_milestone() -> void:
	if audio_playback_enabled and is_instance_valid(_combo_milestone_player):
		_combo_milestone_player.stop()
		_combo_milestone_player.play()


func play_record() -> void:
	if audio_playback_enabled and is_instance_valid(_record_sfx):
		_record_sfx.play()


func play_milestone(stage: int) -> void:
	if _milestone_sfx_player != null:
		_milestone_sfx_player.pitch_scale = 0.85 + float(stage) * 0.18
		_milestone_sfx_player.play()


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


func play_star_earn(stars: int, on_finished: Callable = Callable()) -> void:
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


func apply_sound_setting(sound_enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_enabled)
