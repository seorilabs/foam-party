extends Node2D

# Static wash-bay backdrop: sky/floor bands, ambient circles, structure pillars,
# overhead rail, nozzles, rollers, and the floor drain. Split out of main.gd so
# these ~90 fully static draw commands live on their own cached canvas item and
# only repaint when the layout (viewport fit) changes, instead of every frame of
# the gameplay redraw loop. Drawn behind the parent so ordering matches the old
# "background first" _draw() sequence exactly.

var _canvas_origin := Vector2.ZERO
var _canvas_scale := 1.0
var _design_size := Vector2.ZERO


func _init() -> void:
	show_behind_parent = true


func update_layout(new_origin: Vector2, new_scale: float, new_design_size: Vector2) -> void:
	if new_origin.is_equal_approx(_canvas_origin) \
			and is_equal_approx(new_scale, _canvas_scale) \
			and new_design_size.is_equal_approx(_design_size):
		return
	_canvas_origin = new_origin
	_canvas_scale = new_scale
	_design_size = new_design_size
	queue_redraw()


func bay_geometry() -> Dictionary:
	return {
		"left_pillar": _bay_left_pillar_rect(),
		"right_pillar": _bay_right_pillar_rect(),
		"overhead_rail": _bay_overhead_rail_rect(),
		"left_roller": _bay_left_roller_rect(),
		"right_roller": _bay_right_roller_rect(),
		"floor_drain": _bay_floor_drain_rect(),
	}


func _draw() -> void:
	if _design_size.x <= 0.0 or _design_size.y <= 0.0:
		return
	draw_set_transform(_canvas_origin, 0.0, Vector2(_canvas_scale, _canvas_scale))
	_draw_backdrop()
	_draw_car_wash_bay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_backdrop() -> void:
	var overhang := _canvas_origin / maxf(_canvas_scale, 0.001)
	var bg_left := -overhang.x
	var bg_top := -overhang.y
	var bg_width := _design_size.x + overhang.x * 2.0
	var bg_bottom := _design_size.y + overhang.y
	draw_rect(Rect2(bg_left, bg_top, bg_width, bg_bottom - bg_top), Color("#87e3e9"))
	draw_rect(Rect2(bg_left, bg_top, bg_width, 155.0 - bg_top), Color("#9ff0ef"))
	draw_rect(Rect2(bg_left, 620.0, bg_width, bg_bottom - 620.0), Color("#6dd0d1"))

	var line_slope := 28.0 / _design_size.x
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


func _bay_left_pillar_rect() -> Rect2:
	return Rect2(10.0, 184.0, 36.0, 444.0)


func _bay_right_pillar_rect() -> Rect2:
	return Rect2(344.0, 184.0, 36.0, 444.0)


func _bay_overhead_rail_rect() -> Rect2:
	return Rect2(28.0, 178.0, 334.0, 24.0)


func _bay_left_roller_rect() -> Rect2:
	return Rect2(36.0, 246.0, 30.0, 132.0)


func _bay_right_roller_rect() -> Rect2:
	return Rect2(324.0, 246.0, 30.0, 132.0)


func _bay_floor_drain_rect() -> Rect2:
	return Rect2(120.0, 712.0, 150.0, 12.0)


func _draw_bay_pillar(rect: Rect2, inner_edge_x: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(0.0, 5.0), rect.size), Color(0.03, 0.22, 0.30, 0.24))
	draw_rect(rect, Color("#1c6572"))
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size - Vector2(10.0, 5.0)), Color("#55bcc2"))
	draw_line(Vector2(inner_edge_x, rect.position.y + 5.0), Vector2(inner_edge_x, rect.end.y), Color(0.86, 1.0, 1.0, 0.55), 2.0)
	for index in range(4):
		var bolt_y := rect.position.y + 40.0 + float(index) * 105.0
		draw_circle(Vector2(rect.get_center().x, bolt_y), 3.0, Color("#d8fbf8"))
		draw_circle(Vector2(rect.get_center().x, bolt_y), 3.0, Color("#164b59"), false, 1.0)


func _draw_bay_roller(rect: Rect2, arm_start: Vector2) -> void:
	var center_x := rect.get_center().x
	draw_line(arm_start, Vector2(center_x, rect.position.y - 12.0), Color("#174f60"), 7.0)
	draw_line(arm_start, Vector2(center_x, rect.position.y - 12.0), Color("#8fe5df"), 3.0)
	draw_rect(Rect2(center_x - 3.0, rect.position.y, 6.0, rect.size.y), Color("#164b59"))
	for index in range(8):
		var segment_y := rect.position.y + 9.0 + float(index) * 16.0
		var segment_color := Color("#82e6de") if index % 2 == 0 else Color("#70c9e8")
		draw_circle(Vector2(center_x, segment_y), 12.0, Color(segment_color.r, segment_color.g, segment_color.b, 0.58))
		draw_line(Vector2(center_x - 10.0, segment_y), Vector2(center_x + 10.0, segment_y), Color(0.91, 1.0, 1.0, 0.58), 1.5)


func _draw_bay_nozzle(x: float) -> void:
	draw_rect(Rect2(x - 5.0, 199.0, 10.0, 15.0), Color("#225a68"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 8.0, 214.0),
		Vector2(x + 8.0, 214.0),
		Vector2(x + 4.0, 221.0),
		Vector2(x - 4.0, 221.0),
	]), Color("#7bd8dc"))


func _draw_car_wash_bay() -> void:
	var left_pillar := _bay_left_pillar_rect()
	var right_pillar := _bay_right_pillar_rect()
	var overhead_rail := _bay_overhead_rail_rect()
	draw_rect(Rect2(overhead_rail.position + Vector2(0.0, 5.0), overhead_rail.size), Color(0.03, 0.22, 0.30, 0.24))
	draw_rect(overhead_rail, Color("#1c6572"))
	draw_rect(Rect2(overhead_rail.position + Vector2(7.0, 5.0), overhead_rail.size - Vector2(14.0, 10.0)), Color("#61c8cb"))
	draw_line(Vector2(overhead_rail.position.x + 12.0, overhead_rail.position.y + 7.0), Vector2(overhead_rail.end.x - 12.0, overhead_rail.position.y + 7.0), Color(0.88, 1.0, 1.0, 0.62), 2.0)
	_draw_bay_pillar(left_pillar, left_pillar.end.x - 5.0)
	_draw_bay_pillar(right_pillar, right_pillar.position.x + 5.0)
	_draw_bay_nozzle(84.0)
	_draw_bay_nozzle(195.0)
	_draw_bay_nozzle(306.0)
	_draw_bay_roller(_bay_left_roller_rect(), Vector2(left_pillar.end.x, 234.0))
	_draw_bay_roller(_bay_right_roller_rect(), Vector2(right_pillar.position.x, 234.0))

	var drain := _bay_floor_drain_rect()
	draw_rect(Rect2(drain.position + Vector2(0.0, 3.0), drain.size), Color(0.01, 0.18, 0.22, 0.24))
	draw_rect(drain, Color(0.08, 0.34, 0.39, 0.72))
	for index in range(9):
		var groove_x := drain.position.x + 10.0 + float(index) * 16.0
		draw_line(Vector2(groove_x, drain.position.y + 2.0), Vector2(groove_x - 4.0, drain.end.y - 2.0), Color(0.75, 0.96, 0.94, 0.58), 2.0)
	draw_line(Vector2(18.0, 650.0), Vector2(66.0, 738.0), Color(0.92, 1.0, 1.0, 0.26), 3.0)
	draw_line(Vector2(372.0, 650.0), Vector2(324.0, 738.0), Color(0.92, 1.0, 1.0, 0.26), 3.0)
