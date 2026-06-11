extends SceneTree

## 개발용 스크린샷 캡처 스크립트.
## xvfb-run -a godot --path godot --script res://tests/screenshot_scene.gd --audio-driver Dummy
## 로 실행하면 FOAM_SHOT_DIR(기본 /tmp)에 기본 화면과 도구별 세차 장면, 완료 화면 PNG를 저장합니다.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := OS.get_environment("FOAM_SHOT_DIR")
	if out_dir == "":
		out_dir = "/tmp" if DirAccess.dir_exists_absolute("/tmp") else OS.get_user_data_dir()
	elif out_dir.is_relative_path():
		var cwd := DirAccess.open(".")
		var base_dir := cwd.get_current_dir() if cwd != null else OS.get_user_data_dir()
		out_dir = base_dir.path_join(out_dir)
	if not DirAccess.dir_exists_absolute(out_dir):
		var make_error := DirAccess.make_dir_recursive_absolute(out_dir)
		if make_error != OK:
			push_error("failed to create output dir: " + out_dir)
			quit(1)
			return

	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var node := scene.instantiate()
	get_root().add_child(node)

	get_root().mode = Window.MODE_WINDOWED
	get_root().size = Vector2i(390, 844)

	await _settle(20)
	if not await _capture(out_dir.path_join("shot_default.png")):
		quit(1)
		return

	var wash_points := {
		"water": Vector2(140.0, 510.0),
		"air": Vector2(200.0, 380.0),
		"soap": Vector2(250.0, 590.0),
		"sponge": Vector2(195.0, 520.0),
	}
	for tool_id in ["water", "air", "soap", "sponge"]:
		node.set("selected_tool", tool_id)
		node.set("pointer_position", wash_points[tool_id])
		node.set("is_washing", true)
		await _settle(25)
		var tool_saved: bool = await _capture(out_dir.path_join("shot_%s.png" % tool_id))
		node.set("is_washing", false)
		node.get("particles").clear()
		if not tool_saved:
			quit(1)
			return

	node.set("selected_tool", "water")
	node.set("pointer_position", Vector2(195.0, 520.0))
	for patch in node.get("dirt_patches"):
		if patch.get("position").distance_to(Vector2(195.0, 520.0)) < 120.0:
			patch.set("health", 1.0)
	node.set("is_washing", true)
	await _settle(10)
	var combo_saved: bool = await _capture(out_dir.path_join("shot_combo.png"))
	node.set("is_washing", false)
	node.get("particles").clear()
	if not combo_saved:
		quit(1)
		return

	for patch in node.get("dirt_patches"):
		patch.set("health", 0.0)
	await _settle(12)
	if not await _capture(out_dir.path_join("shot_complete.png")):
		quit(1)
		return

	for level in [2, 3]:
		node.call("reset_game", level)
		await _settle(10)
		var car_name: String = node.call("get_car_type_for_test")
		if not await _capture(out_dir.path_join("shot_car_%s.png" % car_name)):
			quit(1)
			return

	quit(0)


func _settle(frames: int) -> void:
	for index in range(frames):
		await process_frame


func _capture(path: String) -> bool:
	await process_frame
	var texture := get_root().get_texture()
	if texture == null:
		push_error("viewport texture unavailable for " + path)
		return false
	var image := texture.get_image()
	if image == null:
		push_error("viewport image unavailable for " + path)
		return false
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("failed to save " + path)
		return false
	print("saved ", path)
	return true
