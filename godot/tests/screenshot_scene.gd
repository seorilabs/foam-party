extends SceneTree

## 개발용 스크린샷 캡처 스크립트.
## xvfb-run godot --path godot --script res://tests/screenshot_scene.gd 로 실행하면
## FOAM_SHOT_DIR(기본 /tmp)에 기본 화면과 도구별 세차 장면, 완료 화면 PNG를 저장합니다.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := OS.get_environment("FOAM_SHOT_DIR")
	if out_dir == "":
		out_dir = "/tmp"

	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var node := scene.instantiate()
	get_root().add_child(node)

	await _settle(20)
	await _capture(out_dir + "/shot_default.png")

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
		await _capture(out_dir + "/shot_%s.png" % tool_id)
		node.set("is_washing", false)

	node.set("completed", true)
	await _settle(10)
	await _capture(out_dir + "/shot_complete.png")

	quit(0)


func _settle(frames: int) -> void:
	for index in range(frames):
		await process_frame


func _capture(path: String) -> void:
	await process_frame
	var image := get_root().get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
