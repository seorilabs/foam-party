class_name NativeAdConfig
extends RefCounted

const CONFIG_PATH := "res://config/native_ads.json"

static var _cached_config: Dictionary = {}


static func app_id(platform_override: String = "") -> String:
	var platform := _platform_key(platform_override)
	var platform_config := _platform_config(platform)
	return str(platform_config.get("appId", ""))


static func unit_id(format: String, placement: String, platform_override: String = "") -> String:
	var platform := _platform_key(platform_override)
	var platform_config := _platform_config(platform)
	var units_value: Variant = platform_config.get("units", {})
	if not units_value is Dictionary:
		return ""
	var units: Dictionary = units_value
	var format_value: Variant = units.get(format, {})
	if not format_value is Dictionary:
		return ""
	return str((format_value as Dictionary).get(placement, ""))


static func uses_non_personalized_ads(platform_override: String = "") -> bool:
	var platform := _platform_key(platform_override)
	return bool(_platform_config(platform).get("nonPersonalizedAds", false))


static func mode() -> String:
	return str(_load_config().get("mode", "unknown"))


static func reload_for_test() -> void:
	_cached_config.clear()


static func _platform_key(platform_override: String) -> String:
	if not platform_override.is_empty():
		return platform_override
	return OS.get_name()


static func _platform_config(platform: String) -> Dictionary:
	var platforms_value: Variant = _load_config().get("platforms", {})
	if not platforms_value is Dictionary:
		return {}
	var platform_value: Variant = (platforms_value as Dictionary).get(platform, {})
	if platform_value is Dictionary:
		return platform_value
	return {}


static func _load_config() -> Dictionary:
	if not _cached_config.is_empty():
		return _cached_config
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("Native AdMob config missing: %s" % CONFIG_PATH)
		return {}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Native AdMob config could not be opened: %s" % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Native AdMob config is not a JSON object: %s" % CONFIG_PATH)
		return {}
	_cached_config = parsed
	return _cached_config
