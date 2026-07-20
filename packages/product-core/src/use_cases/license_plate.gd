extends RefCounted

# Curated plate text keeps the mobile UI keyboard-free and avoids arbitrary
# user-generated text. Stored values are still validated because save files can
# be edited outside the game.

const DEFAULT_TEXT := "FOAM"
const MAX_LENGTH := 6
const ALLOWED_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const PRESETS: Array[String] = ["FOAM", "BUBBLE", "WASH", "SOAP", "GLOW"]


static func options() -> Array[String]:
	return PRESETS.duplicate()


static func is_safe_text(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_LENGTH:
		return false
	for index in range(value.length()):
		if ALLOWED_CHARACTERS.find(value.substr(index, 1)) < 0:
			return false
	return true


static func safe_selection(raw_value: String) -> String:
	var candidate := raw_value.strip_edges().to_upper()
	if not is_safe_text(candidate) or candidate not in PRESETS:
		return DEFAULT_TEXT
	return candidate
