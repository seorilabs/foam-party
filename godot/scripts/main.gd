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
const STAR3_CASH := 3
const STAR2_TIME := 140.0
const STAR2_CASH := 2
const STAR1_CASH := 1
const STAR3_BONUS_CASH := 5
const STAR2_BONUS_CASH := 3
const STAR1_BONUS_CASH := 1

enum GameState { IDLE, PLAYING, RESULT }
enum StarRating { NONE, ONE, TWO, THREE }

var current_state: GameState = GameState.IDLE
var score: int = 0
var cash: int = 0
var elapsed_time: float = 0.0
var dirt_cells: Dictionary = {}
var total_dirt: int = 0
var cleaned_dirt: int = 0
var active_tool: String = ""
var car_type: String = ""
var rng := RandomNumberGenerator.new()
var combo_count: int = 0
var last_clean_time: float = -999.0
var star_rating: StarRating = StarRating.NONE
var wash_particles: Array = []
var audio_players: Array = []
var foam_particles: Array = []
var current_note_index: int = 0
var pop_phase: float = 0.0
var sponge_scrub_phase: float = 0.0
var water_streams: Array = []
var air_puffs: Array = []
var game_ended: bool = false
var touch_active: bool = false
var touch_position: Vector2 = Vector2.ZERO
var last_touch_position: Vector2 = Vector2.ZERO
var touch_velocity: Vector2 = Vector2.ZERO
var tool_button_rects: Dictionary = {}
var canvas_rect: Rect2 = Rect2.ZERO
var result_display_timer: float = 0.0
var result_display_duration: float = 3.5
var soap_bubbles: Array = []
var car_shine_phase: float = 0.0
var celebration_particles: Array = []
var is_celebrating: bool = false
var celebration_timer: float = 0.0
var star_animation_phase: float = 0.0
var dirt_reveal_progress: float = 0.0
var tool_use_counts: Dictionary = {}
var efficiency_score: float = 0.0
var customer_satisfaction: float = 100.0
var bonus_multiplier: float = 1.0
var car_damage: float = 0.0
var warning_flash_timer: float = 0.0
var game_start_time: float = 0.0
var total_touch_distance: float = 0.0
var bg_gradient_phase: float = 0.0
var sparkle_timer: float = 0.0
var sparkles: Array = []
var button_press_animation: Dictionary = {}
var car_sway_phase: float = 0.0
var time_warning_active: bool = false
var warning_pulse_phase: float = 0.0
var result_star_phases: Array = [0.0, 0.0, 0.0]
var result_cash_display: float = 0.0
var result_anim_phase: float = 0.0
var hud_pulse_phase: float = 0.0
var customer_face_phase: float = 0.0
var customer_face_emoji: String = ""

class WashParticle:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var max_life: float
	var color: Color
	var size: float
	var style: int
	
	func _init(pos: Vector2, vel: Vector2, col: Color, sz: float, st: int = 0) -> void:
		position = pos
		velocity = vel
		life = 1.0
		max_life = 1.0
		color = col
		size = sz
		style = st

class FoamParticle:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var radius: float
	var color: Color
	
	func _init(pos: Vector2, vel: Vector2, rad: float, col: Color) -> void:
		position = pos
		velocity = vel
		life = 1.0
		radius = rad
		color = col

class WaterStream:
	var start: Vector2
	var end: Vector2
	var life: float
	var width: float
	var color: Color
	
	func _init(s: Vector2, e: Vector2, w: float, col: Color) -> void:
		start = s
		end = e
		life = 1.0
		width = w
		color = col

class AirPuff:
	var position: Vector2
	var radius: float
	var life: float
	var color: Color
	
	func _init(pos: Vector2, rad: float, col: Color) -> void:
		position = pos
		radius = rad
		life = 1.0
		color = col

class SoapBubble:
	var position: Vector2
	var velocity: Vector2
	var radius: float
	var life: float
	var color: Color
	var wobble_phase: float
	
	func _init(pos: Vector2, vel: Vector2, rad: float, col: Color) -> void:
		position = pos
		velocity = vel
		radius = rad
		life = 1.0
		color = col
		wobble_phase = randf() * TAU

class Sparkle:
	var position: Vector2
	var life: float
	var size: float
	var color: Color
	var rotation: float
	
	func _init(pos: Vector2, sz: float, col: Color) -> void:
		position = pos
		life = 1.0
		size = sz
		color = col
		rotation = randf() * TAU

const STYLE_CIRCLE := 0
const STYLE_RING := 1
const STYLE_STAR := 2
const STYLE_SPLASH := 3

func _ready() -> void:
	rng.randomize()
	_setup_car()
	_setup_audio()
	queue_redraw()


func _setup_car() -> void:
	car_type = CAR_TYPES[rng.randi() % CAR_TYPES.size()]
	_generate_dirt()


func _generate_dirt() -> void:
	dirt_cells.clear()
	total_dirt = 0
	cleaned_dirt = 0
	
	var car_rect := _get_car_body_rect()
	var cell_size := 20
	var cols := int(car_rect.size.x / cell_size)
	var rows := int(car_rect.size.y / cell_size)
	
	for row in range(rows):
		for col in range(cols):
			if rng.randf() < 0.6:
				var cell_key := Vector2i(col, row)
				var dirt_type := DIRT_TYPES[rng.randi() % DIRT_TYPES.size()]
				dirt_cells[cell_key] = {"type": dirt_type, "amount": 1.0, "cleaned": false}
				total_dirt += 1


func _setup_audio() -> void:
	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)


func _process(delta: float) -> void:
	bg_gradient_phase += delta * 0.3
	car_sway_phase += delta * 0.8
	hud_pulse_phase += delta * 2.0
	
	if current_state == GameState.PLAYING:
		elapsed_time += delta
		pop_phase += delta * 3.0
		sponge_scrub_phase += delta * 8.0
		car_shine_phase += delta * 2.0
		sparkle_timer += delta
		
		_update_customer_face()
		_update_particles(delta)
		_update_foam_particles(delta)
		_update_water_streams(delta)
		_update_air_puffs(delta)
		_update_soap_bubbles(delta)
		_update_sparkles(delta)
		
		if time_warning_active:
			warning_pulse_phase += delta * 4.0
		
		if warning_flash_timer > 0:
			warning_flash_timer -= delta
		
		if sparkle_timer > 0.3:
			sparkle_timer = 0.0
			_spawn_ambient_sparkles()
		
		queue_redraw()
		
	elif current_state == GameState.RESULT:
		result_display_timer += delta
		star_animation_phase += delta * 2.0
		result_anim_phase += delta
		customer_face_phase += delta
		
		if result_cash_display < cash:
			result_cash_display = minf(result_cash_display + delta * 15.0, float(cash))
		
		if is_celebrating:
			celebration_timer += delta
			_update_celebration_particles(delta)
		
		if result_display_timer >= result_display_duration:
			_reset_game()
		
		queue_redraw()


func _update_customer_face() -> void:
	if elapsed_time < STAR3_TIME:
		customer_face_emoji = "\U0001F60A"
	elif elapsed_time < STAR2_TIME:
		customer_face_emoji = "\U0001F610"
	else:
		customer_face_emoji = "\U0001F620"


func _update_particles(delta: float) -> void:
	for particle in wash_particles:
		particle.position += particle.velocity * delta
		particle.velocity.y += 200.0 * delta
		particle.velocity *= 0.98
		particle.life -= delta * 2.0
	wash_particles = wash_particles.filter(func(p): return p.life > 0)


func _update_foam_particles(delta: float) -> void:
	for particle in foam_particles:
		particle.position += particle.velocity * delta
		particle.velocity *= 0.95
		particle.life -= delta * 1.5
	foam_particles = foam_particles.filter(func(p): return p.life > 0)


func _update_water_streams(delta: float) -> void:
	for stream in water_streams:
		stream.life -= delta * 3.0
	water_streams = water_streams.filter(func(s): return s.life > 0)


func _update_air_puffs(delta: float) -> void:
	for puff in air_puffs:
		puff.radius += delta * 30.0
		puff.life -= delta * 2.5
	air_puffs = air_puffs.filter(func(p): return p.life > 0)


func _update_soap_bubbles(delta: float) -> void:
	for bubble in soap_bubbles:
		bubble.position += bubble.velocity * delta
		bubble.velocity.y -= 20.0 * delta
		bubble.wobble_phase += delta * 3.0
		bubble.life -= delta * 0.8
	soap_bubbles = soap_bubbles.filter(func(b): return b.life > 0)


func _update_sparkles(delta: float) -> void:
	for sparkle in sparkles:
		sparkle.life -= delta * 1.5
		sparkle.rotation += delta * 3.0
	sparkles = sparkles.filter(func(s): return s.life > 0)


func _update_celebration_particles(delta: float) -> void:
	for particle in celebration_particles:
		particle.position += particle.velocity * delta
		particle.velocity.y += 150.0 * delta
		particle.life -= delta * 0.7
	celebration_particles = celebration_particles.filter(func(p): return p.life > 0)


func _spawn_ambient_sparkles() -> void:
	if cleaned_dirt == 0:
		return
	var car_rect := _get_car_body_rect()
	for i in range(2):
		var pos := Vector2(
			car_rect.position.x + rng.randf() * car_rect.size.x,
			car_rect.position.y + rng.randf() * car_rect.size.y
		)
		sparkles.append(Sparkle.new(pos, rng.randf_range(3.0, 8.0), Color(1.0, 1.0, 0.8, 0.7)))


func _draw() -> void:
	var scale_factor := _get_scale_factor()
	_draw_background(scale_factor)
	_draw_car(scale_factor)
	_draw_dirt(scale_factor)
	_draw_particles(scale_factor)
	_draw_foam(scale_factor)
	_draw_water_streams(scale_factor)
	_draw_air_puffs(scale_factor)
	_draw_soap_bubbles(scale_factor)
	_draw_sparkles(scale_factor)
	_draw_celebration(scale_factor)
	_draw_hud(scale_factor)
	_draw_tool_buttons(scale_factor)
	
	if current_state == GameState.IDLE:
		_draw_start_screen(scale_factor)
	elif current_state == GameState.RESULT:
		_draw_result_screen(scale_factor)
	elif current_state == GameState.PLAYING:
		_draw_customer_face(scale_factor)


func _draw_customer_face(scale_factor: float) -> void:
	if customer_face_emoji == "":
		return
	
	var screen_size := get_viewport_rect().size
	var center_x := screen_size.x / 2.0
	var y_pos := screen_size.y * 0.08
	
	var pulse_scale := 1.0
	if elapsed_time >= STAR2_TIME:
		pulse_scale = 1.0 + sin(elapsed_time * 8.0) * 0.15
	elif elapsed_time >= STAR3_TIME:
		pulse_scale = 1.0 + sin(elapsed_time * 3.0) * 0.05
	
	var font_size := int(40.0 * scale_factor * pulse_scale)
	
	var bg_radius := 28.0 * scale_factor * pulse_scale
	var bg_color := Color(0.0, 0.0, 0.0, 0.35)
	draw_circle(Vector2(center_x, y_pos), bg_radius, bg_color)
	
	var text_pos := Vector2(center_x, y_pos + font_size * 0.35)
	draw_string(
		ThemeDB.fallback_font,
		text_pos,
		customer_face_emoji,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size
	)


func _get_scale_factor() -> float:
	var viewport_size := get_viewport_rect().size
	return minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)


func _draw_background(scale_factor: float) -> void:
	var viewport_size := get_viewport_rect().size
	var t := (sin(bg_gradient_phase) + 1.0) / 2.0
	var top_color := Color(0.15 + t * 0.05, 0.25 + t * 0.05, 0.45 + t * 0.05)
	var bottom_color := Color(0.05 + t * 0.03, 0.12 + t * 0.03, 0.25 + t * 0.03)
	
	for y in range(int(viewport_size.y)):
		var blend := float(y) / viewport_size.y
		var line_color := top_color.lerp(bottom_color, blend)
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), line_color)
	
	var star_positions := [
		Vector2(0.1, 0.05), Vector2(0.3, 0.08), Vector2(0.5, 0.03),
		Vector2(0.7, 0.07), Vector2(0.9, 0.04), Vector2(0.2, 0.12),
		Vector2(0.6, 0.11), Vector2(0.8, 0.09), Vector2(0.4, 0.15),
		Vector2(0.05, 0.18), Vector2(0.95, 0.16)
	]
	
	for star_pos in star_positions:
		var pos := Vector2(star_pos.x * viewport_size.x, star_pos.y * viewport_size.y)
		var brightness := 0.5 + 0.5 * sin(bg_gradient_phase * 2.0 + star_pos.x * 10.0)
		var star_color := Color(brightness, brightness, brightness * 0.8)
		draw_circle(pos, 1.5, star_color)


func _draw_car(scale_factor: float) -> void:
	var sway := sin(car_sway_phase) * 1.5 * scale_factor
	
	if car_type == "compact":
		_draw_compact_car(scale_factor, sway)
	elif car_type == "sports":
		_draw_sports_car(scale_factor, sway)
	else:
		_draw_truck(scale_factor, sway)


func _draw_compact_car(scale_factor: float, sway: float) -> void:
	var base_x := 195.0 * scale_factor + sway
	var base_y := 480.0 * scale_factor
	
	var body_rect := Rect2(base_x - 140.0 * scale_factor, base_y - 80.0 * scale_factor,
			280.0 * scale_factor, 110.0 * scale_factor)
	
	var clean_ratio := float(cleaned_dirt) / float(max(total_dirt, 1))
	var body_color := Color(0.2 + clean_ratio * 0.4, 0.4 + clean_ratio * 0.2, 0.8, 1.0)
	var shine_alpha := clean_ratio * 0.3 * (0.7 + 0.3 * sin(car_shine_phase))
	
	draw_rect(body_rect, body_color, true, -1.0)
	
	var cabin_rect := Rect2(base_x - 90.0 * scale_factor, base_y - 150.0 * scale_factor,
			180.0 * scale_factor, 75.0 * scale_factor)
	draw_rect(cabin_rect, body_color.lightened(0.1), true, -1.0)
	
	draw_rect(body_rect, Color(1.0, 1.0, 1.0, shine_alpha), true, -1.0)
	draw_rect(cabin_rect, Color(1.0, 1.0, 1.0, shine_alpha), true, -1.0)
	
	var outline_color := body_color.darkened(0.3)
	draw_rect(body_rect, outline_color, false, 2.0 * scale_factor)
	draw_rect(cabin_rect, outline_color, false, 2.0 * scale_factor)
	
	var window_color := Color(0.5, 0.8, 1.0, 0.6)
	draw_rect(Rect2(base_x - 75.0 * scale_factor, base_y - 145.0 * scale_factor,
			70.0 * scale_factor, 60.0 * scale_factor), window_color, true, -1.0)
	draw_rect(Rect2(base_x + 5.0 * scale_factor, base_y - 145.0 * scale_factor,
			70.0 * scale_factor, 60.0 * scale_factor), window_color, true, -1.0)
	
	_draw_wheels(base_x, base_y, scale_factor, body_color)
	
	_draw_headlights(base_x, base_y, scale_factor)


func _draw_sports_car(scale_factor: float, sway: float) -> void:
	var base_x := 195.0 * scale_factor + sway
	var base_y := 490.0 * scale_factor
	
	var clean_ratio := float(cleaned_dirt) / float(max(total_dirt, 1))
	var body_color := Color(0.8 + clean_ratio * 0.1, 0.15 + clean_ratio * 0.1, 0.15, 1.0)
	var shine_alpha := clean_ratio * 0.35 * (0.7 + 0.3 * sin(car_shine_phase))
	
	var body_points := PackedVector2Array([
		Vector2(base_x - 150.0 * scale_factor, base_y),
		Vector2(base_x - 130.0 * scale_factor, base_y - 50.0 * scale_factor),
		Vector2(base_x - 60.0 * scale_factor, base_y - 90.0 * scale_factor),
		Vector2(base_x + 60.0 * scale_factor, base_y - 90.0 * scale_factor),
		Vector2(base_x + 130.0 * scale_factor, base_y - 50.0 * scale_factor),
		Vector2(base_x + 150.0 * scale_factor, base_y),
	])
	draw_polygon(body_points, PackedColorArray([body_color, body_color, body_color, body_color, body_color, body_color]))
	draw_polygon(body_points, PackedColorArray([
		Color(1.0, 1.0, 1.0, shine_alpha), Color(1.0, 1.0, 1.0, shine_alpha),
		Color(1.0, 1.0, 1.0, shine_alpha), Color(1.0, 1.0, 1.0, shine_alpha),
		Color(1.0, 1.0, 1.0, shine_alpha), Color(1.0, 1.0, 1.0, shine_alpha)
	]))
	draw_polyline(body_points, body_color.darkened(0.3), 2.0 * scale_factor)
	
	var window_points := PackedVector2Array([
		Vector2(base_x - 55.0 * scale_factor, base_y - 55.0 * scale_factor),
		Vector2(base_x - 45.0 * scale_factor, base_y - 85.0 * scale_factor),
		Vector2(base_x + 45.0 * scale_factor, base_y - 85.0 * scale_factor),
		Vector2(base_x + 55.0 * scale_factor, base_y - 55.0 * scale_factor),
	])
	var window_color := Color(0.5, 0.8, 1.0, 0.6)
	draw_polygon(window_points, PackedColorArray([window_color, window_color, window_color, window_color]))
	
	_draw_wheels(base_x, base_y, scale_factor, body_color)
	_draw_headlights(base_x, base_y, scale_factor)


func _draw_truck(scale_factor: float, sway: float) -> void:
	var base_x := 195.0 * scale_factor + sway
	var base_y := 480.0 * scale_factor
	
	var clean_ratio := float(cleaned_dirt) / float(max(total_dirt, 1))
	var body_color := Color(0.2 + clean_ratio * 0.1, 0.55 + clean_ratio * 0.1, 0.2, 1.0)
	var shine_alpha := clean_ratio * 0.3 * (0.7 + 0.3 * sin(car_shine_phase))
	
	var cab_rect := Rect2(base_x - 160.0 * scale_factor, base_y - 120.0 * scale_factor,
			160.0 * scale_factor, 120.0 * scale_factor)
	var bed_rect := Rect2(base_x, base_y - 80.0 * scale_factor,
			160.0 * scale_factor, 80.0 * scale_factor)
	
	draw_rect(cab_rect, body_color, true, -1.0)
	draw_rect(bed_rect, body_color.darkened(0.1), true, -1.0)
	draw_rect(cab_rect, Color(1.0, 1.0, 1.0, shine_alpha), true, -1.0)
	draw_rect(bed_rect, Color(1.0, 1.0, 1.0, shine_alpha * 0.5), true, -1.0)
	
	var outline_color := body_color.darkened(0.3)
	draw_rect(cab_rect, outline_color, false, 2.0 * scale_factor)
	draw_rect(bed_rect, outline_color, false, 2.0 * scale_factor)
	
	var window_rect := Rect2(base_x - 145.0 * scale_factor, base_y - 110.0 * scale_factor,
			130.0 * scale_factor, 60.0 * scale_factor)
	draw_rect(window_rect, Color(0.5, 0.8, 1.0, 0.6), true, -1.0)
	
	_draw_wheels(base_x, base_y, scale_factor, body_color)
	_draw_headlights(base_x, base_y, scale_factor)


func _draw_wheels(base_x: float, base_y: float, scale_factor: float, body_color: Color) -> void:
	var wheel_positions := [
		Vector2(base_x - 95.0 * scale_factor, base_y + 15.0 * scale_factor),
		Vector2(base_x + 95.0 * scale_factor, base_y + 15.0 * scale_factor)
	]
	
	for wheel_pos in wheel_positions:
		draw_circle(wheel_pos, 28.0 * scale_factor, Color(0.15, 0.15, 0.15))
		draw_circle(wheel_pos, 18.0 * scale_factor, Color(0.4, 0.4, 0.4))
		draw_circle(wheel_pos, 10.0 * scale_factor, body_color.lightened(0.2))
		draw_circle(wheel_pos, 28.0 * scale_factor, Color(0.3, 0.3, 0.3), false, 2.0 * scale_factor)


func _draw_headlights(base_x: float, base_y: float, scale_factor: float) -> void:
	var headlight_color := Color(1.0, 1.0, 0.8, 0.9)
	draw_circle(Vector2(base_x - 130.0 * scale_factor, base_y - 20.0 * scale_factor),
			8.0 * scale_factor, headlight_color)
	draw_circle(Vector2(base_x + 130.0 * scale_factor, base_y - 20.0 * scale_factor),
			8.0 * scale_factor, headlight_color)


func _draw_dirt(scale_factor: float) -> void:
	var car_rect := _get_car_body_rect()
	var cell_size := 20
	
	for cell_key in dirt_cells:
		var dirt := dirt_cells[cell_key]
		if dirt["cleaned"]:
			continue
		
		var cell_rect := Rect2(
			car_rect.position.x + cell_key.x * cell_size * scale_factor,
			car_rect.position.y + cell_key.y * cell_size * scale_factor,
			cell_size * scale_factor,
			cell_size * scale_factor
		)
		
		var dirt_color := _get_dirt_color(dirt["type"])
		dirt_color.a = dirt["amount"] * 0.85
		draw_rect(cell_rect, dirt_color, true, -1.0)
		
		if dirt["amount"] > 0.5:
			var texture_color := dirt_color.darkened(0.3)
			texture_color.a *= 0.5
			var cx := cell_rect.position.x + cell_rect.size.x / 2
			var cy := cell_rect.position.y + cell_rect.size.y / 2
			draw_circle(Vector2(cx, cy), 3.0 * scale_factor, texture_color)


func _get_dirt_color(dirt_type: String) -> Color:
	match dirt_type:
		"mud": return Color(0.4, 0.3, 0.2)
		"dust": return Color(0.7, 0.65, 0.55)
		"leaf": return Color(0.3, 0.5, 0.2)
		"oil": return Color(0.1, 0.1, 0.15)
		"bug": return Color(0.5, 0.4, 0.1)
		_: return Color(0.5, 0.5, 0.5)


func _draw_particles(scale_factor: float) -> void:
	for particle in wash_particles:
		var alpha := particle.life * particle.color.a
		var draw_color := Color(particle.color.r, particle.color.g, particle.color.b, alpha)
		var draw_size := particle.size * scale_factor * particle.life
		
		match particle.style:
			STYLE_CIRCLE:
				draw_circle(particle.position, draw_size, draw_color)
			STYLE_RING:
				draw_circle(particle.position, draw_size, draw_color, false, 1.5)
			STYLE_STAR:
				_draw_star_shape(particle.position, draw_size, draw_color)
			STYLE_SPLASH:
				draw_circle(particle.position, draw_size * 1.5, draw_color)
				draw_circle(particle.position, draw_size * 0.8,
						Color(1.0, 1.0, 1.0, alpha * 0.5))


func _draw_star_shape(pos: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := i * TAU / 10.0 - PI / 2.0
		var r := size if i % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
	draw_polygon(points, PackedColorArray([color] * 10))


func _draw_foam(scale_factor: float) -> void:
	for particle in foam_particles:
		var alpha := particle.life * 0.7
		var draw_color := Color(particle.color.r, particle.color.g, particle.color.b, alpha)
		var r := particle.radius * scale_factor * (1.0 + (1.0 - particle.life) * 0.5)
		draw_circle(particle.position, r, draw_color)
		draw_circle(particle.position, r * 0.6, Color(1.0, 1.0, 1.0, alpha * 0.4))


func _draw_water_streams(scale_factor: float) -> void:
	for stream in water_streams:
		var alpha := stream.life * 0.8
		var draw_color := Color(stream.color.r, stream.color.g, stream.color.b, alpha)
		draw_line(stream.start, stream.end, draw_color, stream.width * scale_factor)


func _draw_air_puffs(scale_factor: float) -> void:
	for puff in air_puffs:
		var alpha := puff.life * 0.5
		var draw_color := Color(puff.color.r, puff.color.g, puff.color.b, alpha)
		draw_circle(puff.position, puff.radius, draw_color, false, 2.0)
		draw_circle(puff.position, puff.radius * 0.6, Color(1.0, 1.0, 1.0, alpha * 0.3), false, 1.5)


func _draw_soap_bubbles(scale_factor: float) -> void:
	for bubble in soap_bubbles:
		var alpha := bubble.life * 0.6
		var wobble := sin(bubble.wobble_phase) * 2.0 * scale_factor
		var draw_color := Color(bubble.color.r, bubble.color.g, bubble.color.b, alpha * 0.3)
		var edge_color := Color(1.0, 1.0, 1.0, alpha * 0.8)
		var r := bubble.radius * scale_factor
		draw_circle(bubble.position + Vector2(wobble, 0), r, draw_color)
		draw_circle(bubble.position + Vector2(wobble, 0), r, edge_color, false, 1.5)
		draw_circle(bubble.position + Vector2(wobble - r * 0.3, -r * 0.3),
				r * 0.25, Color(1.0, 1.0, 1.0, alpha * 0.6))


func _draw_sparkles(scale_factor: float) -> void:
	for sparkle in sparkles:
		var alpha := sparkle.life
		var draw_color := Color(sparkle.color.r, sparkle.color.g, sparkle.color.b, alpha)
		var sz := sparkle.size * scale_factor * sparkle.life
		var rot := sparkle.rotation
		for i in range(4):
			var angle := rot + i * TAU / 4.0
			var tip := sparkle.position + Vector2(cos(angle), sin(angle)) * sz
			draw_line(sparkle.position, tip, draw_color, 1.5)


func _draw_celebration(scale_factor: float) -> void:
	if not is_celebrating:
		return
	for particle in celebration_particles:
		var alpha := particle.life
		var draw_color := Color(particle.color.r, particle.color.g, particle.color.b, alpha)
		draw_circle(particle.position, particle.size * scale_factor, draw_color)


func _draw_hud(scale_factor: float) -> void:
	if current_state == GameState.IDLE:
		return
	
	var screen_size := get_viewport_rect().size
	
	var hud_rect := Rect2(10 * scale_factor, 10 * scale_factor,
			screen_size.x - 20 * scale_factor, 85 * scale_factor)
	draw_rect(hud_rect, Color(0.0, 0.0, 0.0, 0.5), true, -1.0)
	draw_rect(hud_rect, Color(1.0, 1.0, 1.0, 0.2), false, 1.5)
	
	var font := ThemeDB.fallback_font
	var font_size := int(16 * scale_factor)
	var small_font_size := int(12 * scale_factor)
	
	var time_color := Color(1.0, 1.0, 1.0)
	if time_warning_active:
		var pulse := (sin(warning_pulse_phase) + 1.0) / 2.0
		time_color = Color(1.0, pulse * 0.5, pulse * 0.2)
	
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var time_str := "%d:%02d" % [minutes, seconds]
	
	draw_string(font, Vector2(20 * scale_factor, 35 * scale_factor),
			"Time: " + time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, time_color)
	
	var clean_pct := int(float(cleaned_dirt) / float(max(total_dirt, 1)) * 100)
	draw_string(font, Vector2(20 * scale_factor, 55 * scale_factor),
			"Clean: " + str(clean_pct) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size,
			Color(0.7, 1.0, 0.7))
	
	var progress_bar_rect := Rect2(20 * scale_factor, 65 * scale_factor,
			(screen_size.x - 40 * scale_factor) * 0.4, 10 * scale_factor)
	draw_rect(progress_bar_rect, Color(0.3, 0.3, 0.3), true, -1.0)
	var fill_width := progress_bar_rect.size.x * float(cleaned_dirt) / float(max(total_dirt, 1))
	draw_rect(Rect2(progress_bar_rect.position, Vector2(fill_width, progress_bar_rect.size.y)),
			Color(0.3, 0.9, 0.3), true, -1.0)
	
	draw_string(font, Vector2(screen_size.x - 120 * scale_factor, 35 * scale_factor),
			"$" + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.9, 0.3))
	
	if combo_count > 1:
		var combo_alpha := minf(1.0, (elapsed_time - last_clean_time + COMBO_WINDOW) / COMBO_WINDOW)
		var pulse := (sin(hud_pulse_phase * 2.0) + 1.0) / 2.0
		var combo_color := Color(1.0, 0.8 - pulse * 0.3, 0.2, combo_alpha)
		draw_string(font, Vector2(screen_size.x - 120 * scale_factor, 55 * scale_factor),
				"x" + str(combo_count) + " Combo!", HORIZONTAL_ALIGNMENT_LEFT, -1,
				small_font_size, combo_color)
	
	if warning_flash_timer > 0:
		var flash_alpha := warning_flash_timer / 0.5
		draw_rect(Rect2(Vector2.ZERO, screen_size), Color(1.0, 0.0, 0.0, flash_alpha * 0.15), true, -1.0)


func _draw_tool_buttons(scale_factor: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	var tools := [TOOL_WATER, TOOL_SOAP, TOOL_SPONGE, TOOL_AIR]
	var tool_icons := {TOOL_WATER: "\U0001F4A7", TOOL_SOAP: "\U0001F9FC", TOOL_SPONGE: "\U0001F9F4", TOOL_AIR: "\U0001F4A8"}
	var tool_colors := {
		TOOL_WATER: Color(0.3, 0.6, 1.0),
		TOOL_SOAP: Color(0.8, 0.5, 1.0),
		TOOL_SPONGE: Color(1.0, 0.8, 0.3),
		TOOL_AIR: Color(0.7, 0.9, 1.0)
	}
	
	var button_size := 70.0 * scale_factor
	var button_spacing := 10.0 * scale_factor
	var screen_size := get_viewport_rect().size
	var total_width := tools.size() * button_size + (tools.size() - 1) * button_spacing
	var start_x := (screen_size.x - total_width) / 2.0
	var button_y := screen_size.y - button_size - 20.0 * scale_factor
	
	tool_button_rects.clear()
	
	for i in range(tools.size()):
		var tool := tools[i]
		var btn_x := start_x + i * (button_size + button_spacing)
		var btn_rect := Rect2(btn_x, button_y, button_size, button_size)
		tool_button_rects[tool] = btn_rect
		
		var is_active := active_tool == tool
		var press_anim := button_press_animation.get(tool, 0.0)
		var btn_scale := 1.0 + press_anim * 0.1
		var scaled_rect := btn_rect.grow(press_anim * 3.0 * scale_factor)
		
		var btn_color := tool_colors[tool]
		if is_active:
			btn_color = btn_color.lightened(0.3)
		
		draw_rect(scaled_rect, Color(btn_color.r, btn_color.g, btn_color.b, 0.85), true, -1.0)
		
		if is_active:
			draw_rect(scaled_rect, Color(1.0, 1.0, 1.0, 0.8), false, 3.0 * scale_factor)
		else:
			draw_rect(scaled_rect, Color(1.0, 1.0, 1.0, 0.3), false, 1.5 * scale_factor)
		
		var icon_font_size := int(30 * scale_factor)
		var icon_pos := Vector2(btn_rect.get_center().x, btn_rect.get_center().y + icon_font_size * 0.35)
		draw_string(ThemeDB.fallback_font, icon_pos, tool_icons[tool],
				HORIZONTAL_ALIGNMENT_CENTER, -1, icon_font_size)
		
		if press_anim > 0:
			button_press_animation[tool] = maxf(0.0, press_anim - 0.1)


func _draw_start_screen(scale_factor: float) -> void:
	var screen_size := get_viewport_rect().size
	var center := screen_size / 2.0
	
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.0, 0.0, 0.6), true, -1.0)
	
	var font := ThemeDB.fallback_font
	var title_size := int(38 * scale_factor)
	var sub_size := int(18 * scale_factor)
	var hint_size := int(14 * scale_factor)
	
	var pulse := (sin(bg_gradient_phase * 2.0) + 1.0) / 2.0
	var title_color := Color(0.3 + pulse * 0.4, 0.8, 1.0)
	
	draw_string(font, Vector2(center.x, center.y - 80 * scale_factor),
			"\U0001F697 Car Wash!", HORIZONTAL_ALIGNMENT_CENTER, -1, title_size, title_color)
	
	draw_string(font, Vector2(center.x, center.y - 30 * scale_factor),
			"Tap to start washing", HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size, Color(1.0, 1.0, 1.0, 0.9))
	
	draw_string(font, Vector2(center.x, center.y + 10 * scale_factor),
			"Use Water, Soap, Sponge & Air", HORIZONTAL_ALIGNMENT_CENTER, -1, hint_size, Color(0.8, 0.9, 1.0, 0.8))
	
	draw_string(font, Vector2(center.x, center.y + 35 * scale_factor),
			"to clean the car!", HORIZONTAL_ALIGNMENT_CENTER, -1, hint_size, Color(0.8, 0.9, 1.0, 0.8))
	
	var btn_rect := Rect2(center.x - 80 * scale_factor, center.y + 70 * scale_factor,
			160 * scale_factor, 50 * scale_factor)
	var btn_pulse := (sin(bg_gradient_phase * 3.0) + 1.0) / 2.0
	draw_rect(btn_rect, Color(0.2 + btn_pulse * 0.2, 0.7, 0.3), true, -1.0)
	draw_rect(btn_rect, Color(1.0, 1.0, 1.0, 0.5), false, 2.0)
	draw_string(font, Vector2(center.x, center.y + 103 * scale_factor),
			"START", HORIZONTAL_ALIGNMENT_CENTER, -1, int(20 * scale_factor), Color(1.0, 1.0, 1.0))


func _draw_result_screen(scale_factor: float) -> void:
	var screen_size := get_viewport_rect().size
	var center := screen_size / 2.0
	
	var overlay_alpha := minf(0.85, result_display_timer * 2.0)
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.0, 0.0, overlay_alpha), true, -1.0)
	
	var font := ThemeDB.fallback_font
	
	var result_y := center.y - 180 * scale_factor
	var slide_in := minf(1.0, result_anim_phase * 2.0)
	result_y += (1.0 - slide_in) * 50 * scale_factor
	
	var face_emoji := customer_face_emoji
	if game_ended:
		face_emoji = "\U0001F604"
	
	if face_emoji != "":
		var face_size := int(52 * scale_factor)
		var face_pulse := (sin(customer_face_phase * 2.0) + 1.0) / 2.0
		var face_scale := 1.0 + face_pulse * 0.08
		var actual_face_size := int(float(face_size) * face_scale)
		var face_bg_radius := 36.0 * scale_factor * face_scale
		draw_circle(Vector2(center.x, result_y - 10 * scale_factor), face_bg_radius, Color(0.0, 0.0, 0.0, 0.4))
		draw_string(font,
			Vector2(center.x, result_y + actual_face_size * 0.35),
			face_emoji,
			HORIZONTAL_ALIGNMENT_CENTER, -1, actual_face_size)
		result_y += 70 * scale_factor
	
	var title_text := "Well Done!" if star_rating.value >= StarRating.TWO else "Job Done!"
	if star_rating == StarRating.THREE:
		title_text = "Perfect!"
	
	var title_pulse := (sin(star_animation_phase) + 1.0) / 2.0
	var title_color := Color(1.0, 0.9 + title_pulse * 0.1, 0.3 + title_pulse * 0.3)
	draw_string(font, Vector2(center.x, result_y + 35 * scale_factor),
			title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(32 * scale_factor), title_color)
	
	result_y += 60 * scale_factor
	
	var stars_to_show := star_rating
	var star_spacing := 50.0 * scale_factor
	var star_start_x := center.x - (stars_to_show - 1) * star_spacing / 2.0
	
	for i in range(int(stars_to_show)):
		var star_phase := result_anim_phase * 3.0 - i * 0.3
		var star_scale := minf(1.0, star_phase)
		if star_scale <= 0:
			continue
		var star_pos := Vector2(star_start_x + i * star_spacing, result_y)
		var star_pulse2 := sin(star_animation_phase + i * 0.5) * 0.1
		_draw_star_shape(star_pos, (18.0 + star_pulse2 * 18.0) * scale_factor * star_scale,
				Color(1.0, 0.85, 0.2, star_scale))
	
	result_y += 55 * scale_factor
	
	var time_str := "%d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60]
	draw_string(font, Vector2(center.x, result_y),
			"Time: " + time_str, HORIZONTAL_ALIGNMENT_CENTER, -1, int(16 * scale_factor),
			Color(0.8, 0.9, 1.0))
	
	result_y += 28 * scale_factor
	
	var clean_pct := int(float(cleaned_dirt) / float(max(total_dirt, 1)) * 100)
	draw_string(font, Vector2(center.x, result_y),
			"Cleaned: " + str(clean_pct) + "%", HORIZONTAL_ALIGNMENT_CENTER, -1,
			int(16 * scale_factor), Color(0.7, 1.0, 0.7))
	
	result_y += 35 * scale_factor
	
	var cash_display_int := int(result_cash_display)
	var cash_color := Color(1.0, 0.9, 0.2)
	if cash > 5:
		cash_color = Color(1.0, 0.7, 0.0)
	draw_string(font, Vector2(center.x, result_y),
			"Earned: $" + str(cash_display_int), HORIZONTAL_ALIGNMENT_CENTER, -1,
			int(22 * scale_factor), cash_color)
	
	var progress_alpha := minf(1.0, result_display_timer * 1.5 - 1.0)
	if progress_alpha > 0:
		var progress_text := "Next customer in..."
		var time_left := result_display_duration - result_display_timer
		draw_string(font, Vector2(center.x, center.y + 170 * scale_factor),
				progress_text, HORIZONTAL_ALIGNMENT_CENTER, -1,
				int(13 * scale_factor), Color(0.7, 0.7, 0.7, progress_alpha))
		draw_string(font, Vector2(center.x, center.y + 190 * scale_factor),
				"%.1f" % maxf(0.0, time_left), HORIZONTAL_ALIGNMENT_CENTER, -1,
				int(18 * scale_factor), Color(1.0, 1.0, 1.0, progress_alpha))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_active = true
		touch_position = event.position
		last_touch_position = event.position
		_handle_tap(event.position)
	else:
		touch_active = false
		touch_velocity = Vector2.ZERO


func _handle_drag(event: InputEventScreenDrag) -> void:
	if touch_active:
		last_touch_position = touch_position
		touch_position = event.position
		touch_velocity = event.velocity
		if current_state == GameState.PLAYING:
			_apply_tool_at(event.position)
			total_touch_distance += event.position.distance_to(last_touch_position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_active = true
			touch_position = event.position
			last_touch_position = event.position
			_handle_tap(event.position)
		else:
			touch_active = false
			touch_velocity = Vector2.ZERO


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if touch_active:
		last_touch_position = touch_position
		touch_position = event.position
		if current_state == GameState.PLAYING:
			_apply_tool_at(event.position)
			total_touch_distance += event.position.distance_to(last_touch_position)


func _handle_tap(pos: Vector2) -> void:
	if current_state == GameState.IDLE:
		_start_game()
		return
	
	if current_state == GameState.RESULT:
		return
	
	for tool in tool_button_rects:
		if tool_button_rects[tool].has_point(pos):
			_select_tool(tool)
			return
	
	if active_tool != "":
		_apply_tool_at(pos)


func _select_tool(tool: String) -> void:
	active_tool = tool
	button_press_animation[tool] = 1.0
	_play_select_sound()


func _start_game() -> void:
	current_state = GameState.PLAYING
	elapsed_time = 0.0
	score = 0
	cash = 0
	combo_count = 0
	last_clean_time = -999.0
	star_rating = StarRating.NONE
	game_ended = false
	time_warning_active = false
	total_touch_distance = 0.0
	efficiency_score = 0.0
	customer_satisfaction = 100.0
	car_damage = 0.0
	game_start_time = Time.get_ticks_msec() / 1000.0
	wash_particles.clear()
	foam_particles.clear()
	soap_bubbles.clear()
	sparkles.clear()
	is_celebrating = false
	celebration_timer = 0.0
	celebration_particles.clear()
	result_display_timer = 0.0
	result_cash_display = 0.0
	result_anim_phase = 0.0
	customer_face_phase = 0.0
	customer_face_emoji = ""
	_setup_car()
	active_tool = TOOL_WATER


func _apply_tool_at(pos: Vector2) -> void:
	if current_state != GameState.PLAYING:
		return
	
	for tool in tool_button_rects:
		if tool_button_rects[tool].has_point(pos):
			return
	
	var car_rect := _get_car_body_rect()
	
	match active_tool:
		TOOL_WATER:
			_apply_water(pos, car_rect)
		TOOL_SOAP:
			_apply_soap(pos, car_rect)
		TOOL_SPONGE:
			_apply_sponge(pos, car_rect)
		TOOL_AIR:
			_apply_air(pos, car_rect)


func _apply_water(pos: Vector2, car_rect: Rect2) -> void:
	var cleaned := _clean_dirt_at(pos, car_rect, 18.0, 0.15)
	
	for i in range(5):
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(80.0, 200.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color := Color(0.5 + rng.randf() * 0.3, 0.8 + rng.randf() * 0.2,
				1.0, 0.8 + rng.randf() * 0.2)
		var style := STYLE_CIRCLE if rng.randf() < 0.6 else STYLE_SPLASH
		wash_particles.append(WashParticle.new(pos, vel, color,
				rng.randf_range(3.0, 8.0), style))
	
	var stream_end := pos + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(20.0, 60.0))
	water_streams.append(WaterStream.new(pos, stream_end, rng.randf_range(2.0, 5.0),
			Color(0.6, 0.85, 1.0, 0.8)))
	
	if rng.randf() < 0.5:
		particles.append(WashParticle.new(pos + Vector2(rng.randf_range(-10.0, 10.0), 0),
				Vector2(0, rng.randf_range(-50.0, -150.0)),
				Color(1.0, 1.0, 1.0, 0.5), STYLE_RING))
	
	if cleaned > 0:
		_register_clean(cleaned)
		if not time_warning_active and elapsed_time > STAR3_TIME:
			time_warning_active = true


func _apply_soap(pos: Vector2, car_rect: Rect2) -> void:
	var cleaned := _clean_dirt_at(pos, car_rect, 22.0, 0.08)
	
	for i in range(6):
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(20.0, 80.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var hue := rng.randf_range(0.6, 0.9)
		var color := Color.from_hsv(hue, 0.3, 1.0, 0.7)
		soap_bubbles.append(SoapBubble.new(pos + Vector2(rng.randf_range(-15.0, 15.0),
				rng.randf_range(-15.0, 15.0)), vel, rng.randf_range(5.0, 18.0), color))
	
	for i in range(3):
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(40.0, 120.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		foam_particles.append(FoamParticle.new(pos, vel, rng.randf_range(4.0, 12.0),
				Color(0.9, 0.9, 1.0, 0.8)))
	
	_play_soap_sound()
	
	if cleaned > 0:
		_register_clean(cleaned)


func _apply_sponge(pos: Vector2, car_rect: Rect2) -> void:
	var cleaned := _clean_dirt_at(pos, car_rect, 25.0, 0.25)
	
	for i in range(8):
		var offset := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		var vel := offset.normalized() * rng.randf_range(30.0, 90.0)
		var color := Color(0.95, 0.9, 0.5, 0.7 + rng.randf() * 0.3)
		wash_particles.append(WashParticle.new(pos + offset * 0.5, vel, color,
				rng.randf_range(4.0, 10.0), STYLE_CIRCLE))
	
	for i in range(4):
		var angle := sponge_scrub_phase + i * TAU / 4.0
		var orbit_pos := pos + Vector2(cos(angle), sin(angle)) * 15.0
		foam_particles.append(FoamParticle.new(orbit_pos,
				Vector2(cos(angle + PI/2), sin(angle + PI/2)) * 40.0,
				rng.randf_range(3.0, 8.0), Color(1.0, 1.0, 1.0, 0.6)))
	
	if cleaned > 0:
		_register_clean(cleaned)


func _apply_air(pos: Vector2, car_rect: Rect2) -> void:
	var cleaned := _clean_dirt_at(pos, car_rect, 20.0, 0.3)
	
	for i in range(4):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(10.0, 40.0)
		air_puffs.append(AirPuff.new(pos + Vector2(cos(angle), sin(angle)) * radius * 0.5,
				radius, Color(0.85, 0.95, 1.0, 0.5)))
	
	for i in range(6):
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(100.0, 300.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		wash_particles.append(WashParticle.new(pos, vel,
				Color(0.9, 0.95, 1.0, 0.5), rng.randf_range(2.0, 6.0), STYLE_RING))
	
	if cleaned > 0:
		_register_clean(cleaned)


func _clean_dirt_at(pos: Vector2, car_rect: Rect2, radius: float, clean_rate: float) -> int:
	var cell_size := 20
	var cleaned_count := 0
	
	for cell_key in dirt_cells:
		var dirt := dirt_cells[cell_key]
		if dirt["cleaned"]:
			continue
		
		var cell_world_pos := Vector2(
			car_rect.position.x + (cell_key.x + 0.5) * cell_size * _get_scale_factor(),
			car_rect.position.y + (cell_key.y + 0.5) * cell_size * _get_scale_factor()
		)
		
		if pos.distance_to(cell_world_pos) <= radius * _get_scale_factor():
			dirt["amount"] = maxf(0.0, dirt["amount"] - clean_rate)
			if dirt["amount"] <= 0.0:
				dirt["cleaned"] = true
				cleaned_count += 1
				cleaned_dirt += 1
	
	return cleaned_count


func _register_clean(count: int) -> void:
	var now := elapsed_time
	if now - last_clean_time <= COMBO_WINDOW:
		combo_count += count
	else:
		combo_count = count
	last_clean_time = now
	
	var base_points := count * 10
	var combo_bonus := 1 + (combo_count / 10)
	score += base_points * combo_bonus
	
	_play_clean_sound()
	
	if cleaned_dirt >= total_dirt:
		_complete_wash()


func _complete_wash() -> void:
	if game_ended:
		return
	game_ended = true
	
	customer_face_emoji = "\U0001F604"
	
	if elapsed_time <= STAR3_TIME:
		star_rating = StarRating.THREE
		cash = STAR3_CASH + STAR3_BONUS_CASH
	elif elapsed_time <= STAR2_TIME:
		star_rating = StarRating.TWO
		cash = STAR2_CASH + STAR2_BONUS_CASH
	else:
		star_rating = StarRating.ONE
		cash = STAR1_CASH + STAR1_BONUS_CASH
	
	_start_celebration()
	current_state = GameState.RESULT
	result_display_timer = 0.0
	result_cash_display = 0.0
	result_anim_phase = 0.0
	customer_face_phase = 0.0


func _start_celebration() -> void:
	is_celebrating = true
	celebration_timer = 0.0
	
	var screen_size := get_viewport_rect().size
	for i in range(60):
		var pos := Vector2(rng.randf() * screen_size.x, rng.randf() * screen_size.y * 0.6)
		var vel := Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-200.0, -50.0))
		var color := Color.from_hsv(rng.randf(), 0.8, 1.0)
		celebration_particles.append(WashParticle.new(pos, vel, color,
				rng.randf_range(4.0, 12.0), STYLE_CIRCLE))


func _reset_game() -> void:
	current_state = GameState.IDLE
	star_rating = StarRating.NONE
	is_celebrating = false
	celebration_particles.clear()
	wash_particles.clear()
	foam_particles.clear()
	soap_bubbles.clear()
	sparkles.clear()
	air_puffs.clear()
	water_streams.clear()
	customer_face_emoji = ""
	_setup_car()


func _play_clean_sound() -> void:
	var note := POP_NOTES[current_note_index % POP_NOTES.size()]
	current_note_index += 1
	_generate_tone(note, 0.08, 0.3)


func _play_soap_sound() -> void:
	_generate_tone(440.0, 0.05, 0.15)


func _play_select_sound() -> void:
	_generate_tone(880.0, 0.03, 0.1)


func _generate_tone(frequency: float, duration: float, volume: float) -> void:
	var player := _get_free_audio_player()
	if not player:
		return
	
	var sample_count := int(AUDIO_MIX_RATE * duration)
	var audio_stream := AudioStreamWAV.new()
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = AUDIO_MIX_RATE
	audio_stream.stereo = false
	
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	
	for i in range(sample_count):
		var t := float(i) / float(AUDIO_MIX_RATE)
		var envelope := 1.0
		if t < 0.01:
			envelope = t / 0.01
		elif t > duration - 0.02:
			envelope = (duration - t) / 0.02
		
		var sample := sin(TAU * frequency * t) * envelope * volume
		sample += sin(TAU * frequency * 2.0 * t) * envelope * volume * 0.3
		sample += sin(TAU * frequency * 3.0 * t) * envelope * volume * 0.1
		
		var int_sample := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	
	audio_stream.data = data
	player.stream = audio_stream
	player.play()


func _get_free_audio_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player
	return null


func _get_car_body_rect() -> Rect2:
	var scale_factor := _get_scale_factor()
	var viewport_size := get_viewport_rect().size
	
	match car_type:
		"compact":
			return Rect2(
				195.0 * scale_factor - 140.0 * scale_factor,
				480.0 * scale_factor - 150.0 * scale_factor,
				280.0 * scale_factor,
				165.0 * scale_factor
			)
		"sports":
			return Rect2(
				195.0 * scale_factor - 150.0 * scale_factor,
				490.0 * scale_factor - 90.0 * scale_factor,
				300.0 * scale_factor,
				90.0 * scale_factor
			)
		"truck":
			return Rect2(
				195.0 * scale_factor - 160.0 * scale_factor,
				480.0 * scale_factor - 120.0 * scale_factor,
				320.0 * scale_factor,
				120.0 * scale_factor
			)
		_:
			return Rect2(50.0 * scale_factor, 300.0 * scale_factor,
					290.0 * scale_factor, 180.0 * scale_factor)


func _get_settings_rect() -> Rect2:
	return Rect2(306.0, 104.0, 36.0, 36.0)


func _get_help_rect() -> Rect2:
	return Rect2(344.0, 104.0, 36.0, 36.0)


func _get_bomb_rect() -> Rect2:
	return Rect2(276.0, 688.0, 92.0, 46.0)

