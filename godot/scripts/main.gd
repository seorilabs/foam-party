extends Control

const DESIGN_SIZE := Vector2(390.0, 844.0)
const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const DIRT_TYPES := ["mud", "dust", "leaf", "oil", "bug"]
const CLEAN_DAMAGE_RATE := 72.0
const AUDIO_MIX_RATE := 22050
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
var is_washing := false
var pointer_position := Vector2.ZERO
var clean_progress := 0.0
var initial_dirt_total := 1.0
var level_index := 1
var completed := false
var completion_burst_done := false
var last_particle_spawn := 0.0
var car_color := Color("#ffcf5a")
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
var tool_audio_streams: Dictionary = {}
var ui_select_stream: AudioStreamWAV
var completion_stream: AudioStreamWAV


func _ready() -> void:
	rng.seed = 42690
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_font()
	_setup_audio()
	reset_game(1)


func _process(delta: float) -> void:
	if is_washing and not completed:
		_apply_tool_at(pointer_position, delta)

	_update_dirt_motion(delta)
	_update_particles(delta)
	_update_clean_progress()
	_update_audio()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


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
			var compressor_chug: float = 0.72 + 0.28 * sin(TAU * 8.5 * t)
			var valve_burst: float = 0.68 + 0.32 * sin(TAU * 2.1 * t + sin(TAU * 0.7 * t) * 0.9)
			var hose_resonance: float = sin(TAU * 92.0 * t) * 0.14 + sin(TAU * 147.0 * t + low_noise * 1.5) * 0.08
			var compressed_air: float = (mid_noise * 0.35 + high_noise * 0.22) * compressor_chug * valve_burst
			var nozzle_edge: float = sin(TAU * (760.0 + 90.0 * sin(TAU * 2.6 * t)) * t) * 0.035 * valve_burst
			sample = hose_resonance + compressed_air + nozzle_edge
		elif tool_id == TOOL_WATER:
			var pressure_pulse: float = 0.76 + 0.24 * sin(TAU * 21.0 * t)
			var impact_phase: float = fmod(t * 38.0, 1.0)
			var impact_env: float = pow(max(0.0, 1.0 - impact_phase), 6.0)
			var spray_phase: float = fmod(t * 13.0 + 0.23, 1.0)
			var spray_env: float = pow(max(0.0, 1.0 - spray_phase), 3.0)
			var hard_jet: float = high_noise * 0.42 * pressure_pulse
			var water_body: float = mid_noise * 0.22 + sin(TAU * 210.0 * t) * 0.05
			var hitting_metal: float = (noise_rng.randf_range(-1.0, 1.0) * 0.52 + sin(TAU * 980.0 * t) * 0.13) * impact_env
			var splatter: float = noise_rng.randf_range(-1.0, 1.0) * 0.24 * spray_env
			sample = hard_jet + water_body + hitting_metal + splatter
		elif tool_id == TOOL_SOAP:
			var fizz: float = high_noise * 0.075 + mid_noise * 0.035
			var foam_swell: float = 0.55 + 0.45 * max(0.0, sin(TAU * 3.4 * t))
			var pop_phase_a: float = fmod(t * 9.0, 1.0)
			var pop_phase_b: float = fmod(t * 14.0 + 0.31, 1.0)
			var pop_phase_c: float = fmod(t * 22.0 + 0.67, 1.0)
			var pop_a: float = 0.0
			var pop_b: float = 0.0
			var pop_c: float = 0.0
			if pop_phase_a < 0.075:
				pop_a = sin(TAU * 520.0 * t) * pow(1.0 - pop_phase_a / 0.075, 2.8) * 0.20
			if pop_phase_b < 0.052:
				pop_b = sin(TAU * 1040.0 * t) * pow(1.0 - pop_phase_b / 0.052, 3.4) * 0.23
			if pop_phase_c < 0.032:
				pop_c = noise_rng.randf_range(-1.0, 1.0) * pow(1.0 - pop_phase_c / 0.032, 4.0) * 0.17
			var soft_bubble: float = sin(TAU * 260.0 * t + low_noise * 3.0) * 0.045 * foam_swell
			sample = fizz * foam_swell + pop_a + pop_b + pop_c + soft_bubble
		elif tool_id == TOOL_SPONGE:
			var wipe_phase: float = fmod(t * 4.2, 1.0)
			var back_phase: float = fmod(t * 2.1, 1.0)
			var wipe_env: float = pow(sin(PI * wipe_phase), 0.75)
			var pressure_env: float = 0.45 + 0.55 * pow(sin(PI * back_phase), 2.0)
			var cloth_drag: float = (mid_noise * 0.20 + low_noise * 0.12) * wipe_env * pressure_env
			var glass_squeak_env: float = pow(max(0.0, sin(PI * wipe_phase)), 7.0)
			var squeak_freq: float = 1220.0 + 980.0 * wipe_phase + 120.0 * sin(TAU * 9.0 * t)
			var squeak: float = sin(TAU * squeak_freq * t) * glass_squeak_env * 0.34
			var edge_chirp_phase: float = fmod(t * 8.4 + 0.12, 1.0)
			var edge_chirp: float = 0.0
			if edge_chirp_phase < 0.065:
				edge_chirp = sin(TAU * 1880.0 * t) * pow(1.0 - edge_chirp_phase / 0.065, 2.0) * 0.12
			sample = cloth_drag + squeak + edge_chirp

		var fade: float = min(1.0, float(sample_index) / 1600.0, float(total_samples - sample_index) / 1600.0)
		_append_i16_sample(data, sample * fade * 0.92)

	return _make_wav(data)


func _make_select_stream() -> AudioStreamWAV:
	var duration := 0.11
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var fade: float = 1.0 - float(sample_index) / float(total_samples)
		var sample: float = sin(TAU * (760.0 + 420.0 * t) * t) * 0.28 * fade
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
		var fade: float = 1.0 - clamp((t - 0.72) / 0.2, 0.0, 1.0)
		var sample: float = (sin(TAU * freq * t) * 0.22 + sin(TAU * freq * 2.0 * t) * 0.07) * fade
		_append_i16_sample(data, sample)
	return _make_wav(data)


func _make_bgm_stream() -> AudioStreamWAV:
	var duration := 5.76
	var total_samples: int = int(duration * float(AUDIO_MIX_RATE))
	var data := PackedByteArray()
	var melody := [392.0, 440.0, 493.88, 587.33, 523.25, 493.88, 440.0, 392.0]
	var bass := [130.81, 146.83, 164.81, 196.0]
	for sample_index in range(total_samples):
		var t: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var step: int = int(floor(t / 0.36)) % melody.size()
		var bass_step: int = int(floor(t / 1.44)) % bass.size()
		var beat_phase: float = fmod(t, 0.36) / 0.36
		var pluck: float = pow(1.0 - beat_phase, 1.6)
		var melody_sample: float = sin(TAU * melody[step] * t) * 0.10 * pluck
		var harmony_sample: float = sin(TAU * melody[step] * 1.5 * t) * 0.035 * pluck
		var bass_sample: float = sin(TAU * bass[bass_step] * t) * 0.07
		var shimmer: float = sin(TAU * 880.0 * t) * 0.015 * max(0.0, sin(TAU * 2.0 * t))
		var loop_fade: float = min(1.0, float(sample_index) / 1800.0, float(total_samples - sample_index) / 1800.0)
		_append_i16_sample(data, (melody_sample + harmony_sample + bass_sample + shimmer) * loop_fade)
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
	_draw_status()
	_set_gameplay_draw_transform()
	_draw_car()
	_set_design_draw_transform()
	_draw_dirt()
	_draw_particles()
	_draw_tool_cursor()
	_draw_toolbar()
	_draw_completion_panel()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func reset_game(new_level: int) -> void:
	level_index = new_level
	completed = false
	completion_burst_done = false
	is_washing = false
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


func _update_canvas_transform() -> void:
	var available_size := size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = DESIGN_SIZE
	canvas_scale = min(available_size.x / DESIGN_SIZE.x, available_size.y / DESIGN_SIZE.y)
	canvas_origin = (available_size - DESIGN_SIZE * canvas_scale) * 0.5


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
	if keycode == KEY_1:
		selected_tool = TOOL_AIR
	elif keycode == KEY_2:
		selected_tool = TOOL_WATER
	elif keycode == KEY_3:
		selected_tool = TOOL_SOAP
	elif keycode == KEY_4:
		selected_tool = TOOL_SPONGE
	elif keycode == KEY_SPACE and completed:
		reset_game(level_index + 1)


func _handle_tap(point: Vector2) -> bool:
	if completed and _get_next_rect().has_point(point):
		reset_game(level_index + 1)
		return true

	for index in range(tool_ids.size()):
		if _get_tool_rect(index).has_point(point):
			selected_tool = tool_ids[index]
			_play_ui_select()
			is_washing = false
			return true

	return false


func _set_car_palette() -> void:
	var hue := fmod(0.10 + float(level_index - 1) * 0.18, 1.0)
	car_color = Color.from_hsv(hue, 0.62, 1.0)


func _spawn_dirt() -> void:
	dirt_patches.clear()
	rng.seed = 42690 + int(level_index) * 97

	var positions := [
		Vector2(102.0, 462.0), Vector2(154.0, 439.0), Vector2(218.0, 439.0), Vector2(283.0, 462.0),
		Vector2(89.0, 526.0), Vector2(137.0, 505.0), Vector2(198.0, 498.0), Vector2(256.0, 506.0), Vector2(314.0, 529.0),
		Vector2(80.0, 580.0), Vector2(126.0, 598.0), Vector2(179.0, 584.0), Vector2(226.0, 596.0), Vector2(280.0, 584.0), Vector2(330.0, 596.0),
		Vector2(116.0, 645.0), Vector2(168.0, 662.0), Vector2(221.0, 650.0), Vector2(276.0, 664.0),
		Vector2(138.0, 382.0), Vector2(199.0, 369.0), Vector2(251.0, 385.0),
		Vector2(102.0, 620.0), Vector2(303.0, 620.0)
	]

	for index in range(positions.size()):
		var kind: String = DIRT_TYPES[index % DIRT_TYPES.size()]
		var base_position: Vector2 = _gameplay_point(positions[index])
		var jitter := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0)) * GAMEPLAY_SCALE
		var radius := _gameplay_length(rng.randf_range(13.0, 24.0))
		var health := rng.randf_range(70.0, 120.0)
		if kind == "oil" or kind == "bug":
			health += 25.0
		var patch := DirtPatch.new(kind, base_position + jitter, radius, health, rng.randf_range(0.0, 10.0))
		dirt_patches.append(patch)

	initial_dirt_total = 0.0
	for patch in dirt_patches:
		initial_dirt_total += (patch as DirtPatch).max_health
	initial_dirt_total = max(1.0, initial_dirt_total)


func _apply_tool_at(point: Vector2, delta: float) -> void:
	var tool_radius := _tool_radius(selected_tool)
	var applied := false
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		if _is_patch_removed(patch) or patch.state == STATE_FLYING:
			continue
		var distance := point.distance_to(_patch_center(patch))
		if distance <= tool_radius + patch.radius:
			_apply_tool_to_patch(patch, delta, point)
			applied = true

	if applied:
		_spawn_tool_particles(point, delta)


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
	patch.state = STATE_REMOVED
	patch.health = 0.0
	patch.soap = 0.0
	patch.wetness = 0.0
	patch.looseness = 1.0


func _is_patch_outside_wash_area(patch: DirtPatch) -> bool:
	var center := _patch_center(patch)
	return center.x < -48.0 or center.x > DESIGN_SIZE.x + 48.0 or center.y < 300.0 or center.y > 748.0


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

	var count := 4
	if selected_tool == TOOL_SOAP:
		count = 7
	elif selected_tool == TOOL_AIR:
		count = 3
	elif selected_tool == TOOL_SPONGE:
		count = 5

	for particle_index in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(35.0, 130.0)
		var velocity := Vector2.from_angle(angle) * speed
		var color: Color = tool_colors[selected_tool]
		var radius := rng.randf_range(2.0, 6.0)
		var style := selected_tool
		if selected_tool == TOOL_WATER:
			velocity.y += rng.randf_range(40.0, 110.0)
			color = Color("#89d8ff")
		elif selected_tool == TOOL_SOAP:
			color = Color(1.0, 1.0, 1.0, 0.8)
		elif selected_tool == TOOL_AIR:
			color = Color(1.0, 1.0, 1.0, 0.55)
			radius = rng.randf_range(6.0, 12.0)
		elif selected_tool == TOOL_SPONGE:
			velocity = Vector2(rng.randf_range(-115.0, 115.0), rng.randf_range(-32.0, 32.0))
			color = Color("#ffd0a6")
			radius = rng.randf_range(5.0, 10.0)
		var particle := WashParticle.new(point + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0)), velocity, rng.randf_range(0.25, 0.7), radius, color, style)
		particles.append(particle)


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index] as WashParticle
		particle.ttl -= delta
		particle.position += particle.velocity * delta
		particle.velocity *= 0.92
		if particle.style == TOOL_WATER:
			particle.velocity.y += 180.0 * delta
		if particle.ttl <= 0.0:
			particles.remove_at(index)


func _update_clean_progress() -> void:
	var dirt_left := 0.0
	for raw_patch in dirt_patches:
		var patch := raw_patch as DirtPatch
		dirt_left += patch.health
	clean_progress = clamp(1.0 - dirt_left / initial_dirt_total, 0.0, 1.0)

	if clean_progress >= 0.985 and not completed:
		completed = true
		is_washing = false
		_stop_tool_loop()
		_play_completion_sound()
		_spawn_completion_burst()


func _spawn_completion_burst() -> void:
	if completion_burst_done:
		return
	completion_burst_done = true
	for index in range(90):
		var angle := rng.randf_range(-PI, 0.0)
		var speed := rng.randf_range(70.0, 230.0)
		var color := Color.from_hsv(rng.randf(), 0.55, 1.0, 0.95)
		var particle := WashParticle.new(Vector2(rng.randf_range(70.0, 330.0), rng.randf_range(300.0, 620.0)), Vector2.from_angle(angle) * speed, rng.randf_range(0.7, 1.6), rng.randf_range(3.0, 7.0), color, "confetti")
		particles.append(particle)


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
	draw_string(font, Vector2(24.0, 37.0), "폼 파티", HORIZONTAL_ALIGNMENT_LEFT, 220.0, 27, Color("#0d3b55"))
	draw_string(font, Vector2(246.0, 33.0), "차량 %02d" % level_index, HORIZONTAL_ALIGNMENT_CENTER, 74.0, 15, Color("#0d3b55"))

	var bar_rect := Rect2(24.0, 58.0, 342.0, 19.0)
	draw_rect(bar_rect.grow(3.0), Color("#0d3b55"))
	draw_rect(bar_rect, Color("#dff9ff"))
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clean_progress, bar_rect.size.y)), Color("#39d98a"))
	draw_string(font, Vector2(24.0, 99.0), "청결도 %.0f%%" % (clean_progress * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 170.0, 16, Color("#0d3b55"))
	draw_string(font, Vector2(208.0, 99.0), _tool_hint(), HORIZONTAL_ALIGNMENT_RIGHT, 154.0, 16, Color("#0d3b55"))


func _tool_hint() -> String:
	if selected_tool == TOOL_AIR:
		return "낙엽·먼지 날림"
	if selected_tool == TOOL_WATER:
		return "흘려보내기·헹굼"
	if selected_tool == TOOL_SOAP:
		return "기름·벌레 불림"
	if selected_tool == TOOL_SPONGE:
		return "불린 자국 닦기"
	return ""


func _draw_car() -> void:
	var outline := Color("#123246")
	var shadow := Color(0.0, 0.0, 0.0, 0.16)
	_draw_ellipse_shape(Vector2(195.0, 666.0), Vector2(164.0, 22.0), shadow)
	draw_rect(Rect2(67.0, 654.0, 86.0, 10.0), Color(0.0, 0.0, 0.0, 0.12))
	draw_rect(Rect2(247.0, 654.0, 86.0, 10.0), Color(0.0, 0.0, 0.0, 0.12))

	_draw_capsule(Rect2(47.0, 470.0, 296.0, 142.0), 46.0, outline)
	_draw_capsule(Rect2(55.0, 478.0, 280.0, 126.0), 40.0, car_color)

	var roof_outline := PackedVector2Array([Vector2(112.0, 484.0), Vector2(143.0, 371.0), Vector2(253.0, 371.0), Vector2(291.0, 484.0)])
	var roof_fill := PackedVector2Array([Vector2(121.0, 479.0), Vector2(149.0, 383.0), Vector2(247.0, 383.0), Vector2(279.0, 479.0)])
	draw_colored_polygon(roof_outline, outline)
	draw_colored_polygon(roof_fill, car_color.lightened(0.08))

	var window_color := Color("#dff9ff")
	draw_colored_polygon(PackedVector2Array([Vector2(150.0, 392.0), Vector2(190.0, 392.0), Vector2(188.0, 465.0), Vector2(130.0, 465.0)]), window_color)
	draw_colored_polygon(PackedVector2Array([Vector2(202.0, 392.0), Vector2(242.0, 392.0), Vector2(268.0, 465.0), Vector2(205.0, 465.0)]), window_color)
	draw_line(Vector2(196.0, 390.0), Vector2(197.0, 466.0), outline, 5.0)
	draw_line(Vector2(132.0, 465.0), Vector2(268.0, 465.0), outline, 4.0)

	draw_circle(Vector2(110.0, 617.0), 42.0, outline)
	draw_circle(Vector2(110.0, 617.0), 25.0, Color("#e8f2f5"))
	draw_circle(Vector2(110.0, 617.0), 12.0, Color("#79a1b1"))
	draw_circle(Vector2(291.0, 617.0), 42.0, outline)
	draw_circle(Vector2(291.0, 617.0), 25.0, Color("#e8f2f5"))
	draw_circle(Vector2(291.0, 617.0), 12.0, Color("#79a1b1"))

	draw_rect(Rect2(71.0, 532.0, 48.0, 16.0), Color("#ffe7a7"))
	draw_rect(Rect2(284.0, 532.0, 40.0, 16.0), Color("#ff6b6b"))
	draw_rect(Rect2(154.0, 550.0, 72.0, 17.0), Color("#f7fbff"))
	draw_string(_font(), Vector2(154.0, 564.0), "세차", HORIZONTAL_ALIGNMENT_CENTER, 72.0, 12, Color("#123246"))

	draw_arc(Vector2(187.0, 518.0), 23.0, PI * 0.1, PI * 0.9, 18, Color("#123246"), 3.0)
	draw_arc(Vector2(224.0, 518.0), 23.0, PI * 0.1, PI * 0.9, 18, Color("#123246"), 3.0)
	draw_line(Vector2(187.0, 541.0), Vector2(223.0, 541.0), Color("#123246"), 3.0)


func _draw_capsule(rect: Rect2, radius: float, color: Color) -> void:
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2.0), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, color)


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


func _draw_mud_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var color := Color(0.36, 0.19, 0.08, 0.82 * strength)
	draw_circle(center, radius * (0.8 + strength * 0.25), color)
	for index in range(5):
		var angle := seed_value + float(index) * 1.35
		var offset := Vector2(cos(angle), sin(angle)) * radius * 0.45
		draw_circle(center + offset, radius * 0.38, color.darkened(0.1))


func _draw_dust_patch(center: Vector2, radius: float, strength: float, seed_value: float) -> void:
	var color := Color(0.86, 0.75, 0.52, 0.52 * strength)
	draw_circle(center, radius * 1.05, color)
	for index in range(7):
		var angle := seed_value + float(index) * 0.9
		var offset := Vector2(cos(angle), sin(angle)) * radius * rng.randf_range(0.2, 0.75)
		draw_circle(center + offset, max(1.5, radius * 0.12), Color(0.55, 0.43, 0.28, 0.45 * strength))


func _draw_leaf_patch(center: Vector2, radius: float, strength: float) -> void:
	var color := Color(0.17, 0.56, 0.22, 0.9 * strength)
	var leaf := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius * 0.75, -radius * 0.12),
		center + Vector2(0.0, radius),
		center + Vector2(-radius * 0.75, -radius * 0.12),
	])
	draw_colored_polygon(leaf, color)
	draw_line(center + Vector2(0.0, -radius * 0.7), center + Vector2(0.0, radius * 0.7), Color(0.08, 0.33, 0.1, 0.8 * strength), 2.0)


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
		if particle.style == TOOL_AIR:
			draw_arc(particle.position, particle.radius, -0.3, 0.9, 12, color, 2.0)
		elif particle.style == TOOL_WATER:
			var direction := particle.velocity.normalized()
			draw_line(particle.position, particle.position - direction * particle.radius * 4.0, color, max(2.0, particle.radius * 0.75))
		elif particle.style == TOOL_SPONGE:
			draw_line(particle.position + Vector2(-particle.radius, 0.0), particle.position + Vector2(particle.radius, 0.0), color, 2.0)
		elif particle.style == "confetti":
			draw_rect(Rect2(particle.position, Vector2(particle.radius * 1.5, particle.radius)), color)
		else:
			draw_circle(particle.position, particle.radius, color)


func _draw_tool_cursor() -> void:
	if not is_washing or completed:
		return
	var radius := _tool_radius(selected_tool)
	var color: Color = tool_colors[selected_tool]
	color.a = 0.32
	draw_circle(pointer_position, radius, color)
	color.a = 0.9
	draw_arc(pointer_position, radius, 0.0, TAU, 48, color, 3.0)

	if selected_tool == TOOL_WATER:
		draw_line(pointer_position + Vector2(-18.0, -40.0), pointer_position + Vector2(5.0, 18.0), Color("#d8f6ff"), 5.0)
		draw_line(pointer_position + Vector2(2.0, -42.0), pointer_position + Vector2(22.0, 15.0), Color("#89d8ff"), 5.0)
	elif selected_tool == TOOL_AIR:
		for index in range(3):
			draw_arc(pointer_position + Vector2(-18.0, -10.0 + float(index) * 16.0), 26.0 + float(index) * 4.0, -0.5, 0.45, 18, Color(1.0, 1.0, 1.0, 0.7), 3.0)
	elif selected_tool == TOOL_SOAP:
		for index in range(5):
			draw_circle(pointer_position + Vector2.from_angle(float(index) * 1.2) * 18.0, 8.0, Color(1.0, 1.0, 1.0, 0.8))
	elif selected_tool == TOOL_SPONGE:
		draw_rect(Rect2(pointer_position - Vector2(17.0, 12.0), Vector2(34.0, 24.0)), Color("#ff9f5a"))
		draw_rect(Rect2(pointer_position - Vector2(17.0, 12.0), Vector2(34.0, 24.0)), Color("#9c4e1c"), false, 2.0)


func _draw_toolbar() -> void:
	var font: Font = _font()
	draw_rect(Rect2(0.0, 744.0, DESIGN_SIZE.x, 100.0), Color(0.05, 0.18, 0.24, 0.9))
	for index in range(tool_ids.size()):
		var tool_id: String = tool_ids[index]
		var rect := _get_tool_rect(index)
		var color: Color = tool_colors[tool_id]
		var is_selected := selected_tool == tool_id
		draw_rect(rect, Color("#f7fbff") if is_selected else Color("#163847"))
		draw_rect(rect, color, false, 3.0 if is_selected else 1.5)
		_draw_tool_icon(tool_id, rect.position + Vector2(rect.size.x * 0.5, 31.0))
		draw_string(font, rect.position + Vector2(0.0, 66.0), tool_labels[tool_id], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color("#123246") if is_selected else Color("#f7fbff"))


func _draw_tool_icon(tool_id: String, center: Vector2) -> void:
	if tool_id == TOOL_AIR:
		for index in range(3):
			var y := -17.0 + float(index) * 14.0
			draw_arc(center + Vector2(-9.0, y), 29.0 - float(index) * 2.0, -0.15, 0.72, 22, Color("#b7f0ff"), 4.2)
			draw_line(center + Vector2(-30.0, y + 5.0), center + Vector2(24.0, y + 1.0), Color("#d9f8ff"), 3.2)
		draw_arc(center + Vector2(17.0, 1.0), 14.0, -1.1, 1.15, 18, Color("#b7f0ff"), 3.6)
	elif tool_id == TOOL_WATER:
		draw_circle(center + Vector2(0.0, 4.0), 13.0, Color("#49a7ff"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -19.0), center + Vector2(13.0, 3.0), center + Vector2(-13.0, 3.0)]), Color("#49a7ff"))
		draw_circle(center + Vector2(5.0, 2.0), 4.0, Color(1.0, 1.0, 1.0, 0.55))
	elif tool_id == TOOL_SOAP:
		draw_circle(center + Vector2(-8.0, 3.0), 11.0, Color(1.0, 1.0, 1.0, 0.85))
		draw_circle(center + Vector2(8.0, -4.0), 13.0, Color(1.0, 1.0, 1.0, 0.75))
		draw_circle(center + Vector2(9.0, 11.0), 7.0, Color("#f8f4a6"))
	elif tool_id == TOOL_SPONGE:
		draw_rect(Rect2(center - Vector2(19.0, 13.0), Vector2(38.0, 26.0)), Color("#ff9f5a"))
		for index in range(3):
			draw_line(center + Vector2(-15.0, -6.0 + float(index) * 8.0), center + Vector2(15.0, -6.0 + float(index) * 8.0), Color("#cf6c2a"), 2.0)


func _draw_completion_panel() -> void:
	if not completed:
		return
	var font: Font = _font()
	var panel := Rect2(38.0, 225.0, 314.0, 164.0)
	draw_rect(panel.grow(5.0), Color("#123246"))
	draw_rect(panel, Color("#f7fbff"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 47.0), "반짝반짝 완료", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, Color("#123246"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 78.0), "차량 %02d 세차 완료" % level_index, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 16, Color("#2c6b78"))
	var next_rect := _get_next_rect()
	draw_rect(next_rect, Color("#39d98a"))
	draw_rect(next_rect, Color("#123246"), false, 3.0)
	draw_string(font, Vector2(next_rect.position.x, next_rect.position.y + 31.0), "다음 차", HORIZONTAL_ALIGNMENT_CENTER, next_rect.size.x, 16, Color("#123246"))


func _get_tool_rect(index: int) -> Rect2:
	var gap := 8.0
	var margin := 18.0
	var width := (DESIGN_SIZE.x - margin * 2.0 - gap * 3.0) / 4.0
	return Rect2(margin + float(index) * (width + gap), 764.0, width, 72.0)


func _get_next_rect() -> Rect2:
	return Rect2(103.0, 327.0, 184.0, 48.0)
