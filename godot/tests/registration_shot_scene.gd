extends SceneTree

## AppsInToss registration screenshot capture script.
## godot --path godot --script res://tests/registration_shot_scene.gd --audio-driver Dummy
## Saves start/main/result PNGs to FOAM_SHOT_DIR (default /tmp).
## FOAM_SHOT_SIZE (e.g. "636x1048") overrides the capture viewport size.

var _viewport: SubViewport


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

	var shot_size := Vector2i(636, 1048)
	var size_text := OS.get_environment("FOAM_SHOT_SIZE")
	if size_text != "":
		var parts := size_text.split("x")
		if parts.size() == 2:
			shot_size = Vector2i(int(parts[0]), int(parts[1]))

	OS.set_environment("FOAM_DISABLE_SAVE", "1")
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var node := scene.instantiate()
	_viewport = SubViewport.new()
	_viewport.size = shot_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_viewport.add_child(node)
	if node is Control:
		(node as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(node as Control).size = Vector2(shot_size)

	await _settle(20)
	if not await _capture(out_dir.path_join("reg_start.png")):
		quit(1)
		return

	node.call("start_game")
	await _settle(5)
	node.call("_dismiss_tutorial")
	node.set("coins", 120)
	await _settle(10)

	node.set("selected_tool", "water")
	node.set("pointer_position", Vector2(195.0, 520.0))
	for patch in node.get("dirt_patches"):
		if patch.get("position").distance_to(Vector2(195.0, 520.0)) < 120.0:
			patch.set("health", 1.0)
	node.set("is_washing", true)
	await _settle(12)
	node.set("is_washing", false)
	await _settle(240)
	node.set("is_washing", true)
	await _settle(8)
	var main_saved: bool = await _capture(out_dir.path_join("reg_main.png"))
	node.set("is_washing", false)
	node.get("particles").clear()
	if not main_saved:
		quit(1)
		return

	node.set("level_time", 24.6)
	node.set("best_combo", 5)
	for patch in node.get("dirt_patches"):
		patch.set("health", 0.0)
	await _settle(300)
	if not await _capture(out_dir.path_join("reg_result.png")):
		quit(1)
		return

	quit(0)


func _settle(frames: int) -> void:
	for index in range(frames):
		await process_frame


func _capture(path: String) -> bool:
	await process_frame
	var texture := _viewport.get_texture()
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
