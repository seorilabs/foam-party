extends RefCounted

# Pure car-paint catalog. The empty persisted selection means automatic
# level-based color rotation; the UI exposes that state through the `auto` card.

const TOOL_KEY := "car"
const AUTO_ID := "auto"

const _CATALOG := {
	TOOL_KEY: [
		{"id": AUTO_ID, "name": "Auto", "cost": 0, "color": Color(0.0, 0.0, 0.0, 0.0)},
		{"id": "paint_coral", "name": "Coral", "cost": 100, "color": Color("#ff6f61")},
		{"id": "paint_mint", "name": "Mint", "cost": 100, "color": Color("#39d9a0")},
		{"id": "paint_violet", "name": "Violet", "cost": 150, "color": Color("#9b6dff")},
	],
}


static func catalog() -> Dictionary:
	return _CATALOG.duplicate(true)


static func is_valid_id(paint_id: String) -> bool:
	for paint in _CATALOG[TOOL_KEY]:
		if String(paint["id"]) == paint_id:
			return true
	return false


static func safe_selection(raw_value: String) -> String:
	if raw_value.is_empty() or raw_value == AUTO_ID:
		return ""
	return raw_value if is_valid_id(raw_value) else ""


static func selected_catalog_id(selection: String) -> String:
	var safe := safe_selection(selection)
	return AUTO_ID if safe.is_empty() else safe


static func color_for(selection: String, automatic_color: Color) -> Color:
	var safe := safe_selection(selection)
	if safe.is_empty():
		return automatic_color
	for paint in _CATALOG[TOOL_KEY]:
		if String(paint["id"]) == safe:
			return paint["color"]
	return automatic_color
