extends RefCounted

# Pure "which tool should I use" coaching rules. Given a dirt patch and a tool
# id, decide whether the tool is misapplied, what tool to recommend next, and
# geometry helpers. No engine or rendering dependency.

const DirtPatch = preload("res://core/domain/dirt_patch.gd")

const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const STATE_LOOSENED := "loosened"
const STATE_RUNOFF := "runoff"


static func tool_misapplied(tool_id: String, patch: DirtPatch) -> bool:
	match patch.kind:
		"mud":
			# Air does nothing; a dry scrub is premature (rinse or soap it first).
			# Water and soap are both valid mud paths, so they are never flagged.
			if tool_id == TOOL_AIR:
				return true
			if tool_id == TOOL_SPONGE:
				return patch.wetness < 0.2 and patch.soap < 0.15
			return false
		"dust":
			return tool_id == TOOL_SOAP
		"leaf":
			return tool_id != TOOL_AIR
		"oil", "bug":
			if tool_id == TOOL_AIR:
				return true
			var soaped: bool = patch.soap > 0.25 or patch.looseness > 0.35
			if not soaped:
				return tool_id == TOOL_WATER or tool_id == TOOL_SPONGE
			return false
		"poop":
			if tool_id == TOOL_AIR:
				return true
			var poop_activated: bool = patch.soap > 0.25 or patch.state in [STATE_LOOSENED, STATE_RUNOFF]
			if not poop_activated:
				return tool_id == TOOL_WATER or tool_id == TOOL_SPONGE
			return false
		"sticker":
			return tool_id != TOOL_SPONGE
	return false


# The tool the player should reach for next on this patch.
static func recommended_tool(patch: DirtPatch) -> String:
	match patch.kind:
		"leaf":
			return TOOL_AIR
		"oil", "bug":
			if patch.soap > 0.25 or patch.looseness > 0.35:
				return TOOL_SPONGE
			return TOOL_SOAP
		"poop":
			if patch.soap > 0.25 or patch.state in [STATE_LOOSENED, STATE_RUNOFF]:
				return TOOL_WATER
			return TOOL_SOAP
		"sticker":
			return TOOL_SPONGE
	return TOOL_WATER


# The tool currently being coached on screen, or "" when no hint is active.
# `patch_active` is supplied by the godot layer (instance validity + not removed).
static func active_hint_tool(patch: DirtPatch, patch_active: bool) -> String:
	if patch != null and patch_active and patch.hint_time > 0.0:
		return patch.hint_tool
	return ""


static func is_light_dirt(kind: String) -> bool:
	return kind == "leaf" or kind == "dust"


static func tool_radius(tool_id: String) -> float:
	if tool_id == TOOL_AIR:
		return 68.0
	if tool_id == TOOL_WATER:
		return 55.0
	if tool_id == TOOL_SOAP:
		return 60.0
	if tool_id == TOOL_SPONGE:
		return 38.0
	return 48.0
