extends SceneTree

## Development screenshot capture script.
## xvfb-run -a godot --path godot --script res://tests/screenshot_scene.gd --audio-driver Dummy
## Saves title, tool-specific wash scenes, and completion PNGs to FOAM_SHOT_DIR (default /tmp).

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

	OS.set_environment("FOAM_DISABLE_SAVE", "1")
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
	if not await _capture(out_dir.path_join("shot_title.png")):
		quit(1)
		return

	node.call("start_game")
	await _settle(5)
	if not await _capture(out_dir.path_join("shot_tutorial.png")):
		quit(1)
		return
	node.call("_dismiss_tutorial")
	node.set("coins", 120)

	await _settle(10)
	if not await _capture(out_dir.path_join("shot_default.png")):
		quit(1)
		return
	_set_clean_progress(node, 0.0)
	if not await _capture(out_dir.path_join("shot_clean_shine_0.png")):
		quit(1)
		return
	_set_clean_progress(node, 0.5)
	if not await _capture(out_dir.path_join("shot_clean_shine_50.png")):
		quit(1)
		return
	_set_clean_progress(node, 0.98)
	if not await _capture(out_dir.path_join("shot_clean_shine_98.png")):
		quit(1)
		return
	node.call("reset_game", 1, "clean_shine_screenshot_cleanup")
	node.call("_on_back_pressed")
	await _settle(5)
	if not await _capture(out_dir.path_join("shot_pause.png")):
		quit(1)
		return
	node.call("_on_back_pressed")

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
	node.get("particles").clear()
	node.set("is_washing", true)
	await _settle(4)
	if not await _capture(out_dir.path_join("shot_water_impact.png")):
		quit(1)
		return
	node.set("is_washing", false)
	node.get("particles").clear()
	node.set("combo_count", 1)
	node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	if not await _capture(out_dir.path_join("shot_water_combo_low.png")):
		quit(1)
		return
	node.get("particles").clear()
	node.set("combo_count", 9)
	node.call("_spawn_water_removal_splash", Vector2(195.0, 520.0), 18.0)
	if not await _capture(out_dir.path_join("shot_water_combo_hot.png")):
		quit(1)
		return
	node.set("combo_count", 0)
	node.get("particles").clear()

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

	node.call("reset_game", node.get("level_index"))
	node.get("best_times")[int(node.get("level_index"))] = 30.0
	node.set("level_time", 95.0)
	for patch in node.get("dirt_patches"):
		patch.set("health", 0.0)
	await _settle(12)
	if not await _capture(out_dir.path_join("shot_complete_record.png")):
		quit(1)
		return

	for level in [2, 3, 4, 5]:
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


func _set_clean_progress(node: Node, progress: float) -> void:
	var remaining := 1.0 - clampf(progress, 0.0, 1.0)
	for raw_patch in node.get("dirt_patches"):
		raw_patch.set("health", float(raw_patch.get("max_health")) * remaining)
	node.call("_update_clean_progress")
	node.set("_progress_milestone_hit", 3)
	node.set("_progress_milestone_time", -1.0)


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
