extends RefCounted

# Pure "which tool should I use" coaching rules. Given a dirt patch and a tool
# id, decide whether the tool is misapplied, what tool to recommend next, and
# geometry helpers. No engine or rendering dependency.

const DirtPatch = preload("res://core/domain/dirt_patch.gd")
const GameConfig = preload("res://core/domain/game_config.gd")

const TOOL_AIR := "air"
const TOOL_WATER := "water"
const TOOL_SOAP := "soap"
const TOOL_SPONGE := "sponge"
const STATE_LOOSENED := "loosened"
const STATE_RUNOFF := "runoff"

# One catalog shared by the persistent wash guide and rule tests. Primary tools
# are valid on a dry patch; follow-up tools are valid after the first step has
# prepared it. The first primary tool is the one returned by recommended_tool.
const WASH_GUIDE_ENTRIES := [
	{"kind": "mud", "primary": [TOOL_WATER, TOOL_SOAP], "follow_up": [TOOL_SPONGE], "description_key": "GUIDE_DESC_MUD"},
	{"kind": "dust", "primary": [TOOL_WATER, TOOL_AIR], "follow_up": [], "description_key": "GUIDE_DESC_DUST"},
	{"kind": "leaf", "primary": [TOOL_AIR], "follow_up": [], "description_key": "GUIDE_DESC_LEAF"},
	{"kind": "oil", "primary": [TOOL_SOAP], "follow_up": [TOOL_SPONGE, TOOL_WATER], "description_key": "GUIDE_DESC_OIL"},
	{"kind": "bug", "primary": [TOOL_SOAP], "follow_up": [TOOL_SPONGE, TOOL_WATER], "description_key": "GUIDE_DESC_BUG"},
	{"kind": "poop", "primary": [TOOL_SOAP], "follow_up": [TOOL_WATER, TOOL_SPONGE], "description_key": "GUIDE_DESC_POOP"},
	{"kind": "road_grime", "primary": [TOOL_WATER, TOOL_SOAP], "follow_up": [TOOL_SPONGE], "description_key": "GUIDE_DESC_ROAD_GRIME"},
	{"kind": "sap", "primary": [TOOL_SOAP], "follow_up": [TOOL_SPONGE], "description_key": "GUIDE_DESC_SAP"},
]


static func wash_guide_entries() -> Array:
	return WASH_GUIDE_ENTRIES.duplicate(true)


static func tool_misapplied(tool_id: String, patch: DirtPatch) -> bool:
	match patch.kind:
		"mud":
			# Air does nothing; a dry scrub is premature (rinse or soap it first).
			# Water and soap are both valid mud paths, so they are never flagged.
			if tool_id == TOOL_AIR:
				return true
			if tool_id == TOOL_SPONGE:
				var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
				return patch.wetness < float(sponge_profile["wetness_threshold"]) and patch.soap < float(sponge_profile["soap_threshold"])
			return false
		"dust":
			return tool_id == TOOL_SOAP
		"leaf":
			return tool_id != TOOL_AIR
		"oil", "bug":
			if tool_id == TOOL_AIR:
				return true
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			var soaped: bool = patch.soap > float(sponge_profile["soap_threshold"]) or patch.looseness > float(sponge_profile["looseness_threshold"])
			if not soaped:
				return tool_id == TOOL_WATER or tool_id == TOOL_SPONGE
			return false
		"poop":
			if tool_id == TOOL_AIR:
				return true
			var water_profile: Dictionary = GameConfig.WATER_WASH_PROFILES[patch.kind]
			var poop_activated: bool = patch.soap > float(water_profile["prepared_soap_threshold"]) or patch.state in [STATE_LOOSENED, STATE_RUNOFF]
			if not poop_activated:
				return tool_id == TOOL_WATER or tool_id == TOOL_SPONGE
			return false
		"road_grime":
			if tool_id == TOOL_AIR:
				return true
			# Contact washing starts only after the road film has been rinsed or
			# soaped; dry scrubbing would drag grit across the paint.
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			var road_grime_softened: bool = patch.wetness > float(sponge_profile["wetness_threshold"]) or patch.soap > float(sponge_profile["soap_threshold"]) or patch.looseness > float(sponge_profile["looseness_threshold"])
			if not road_grime_softened:
				return tool_id == TOOL_SPONGE
			return false
		"sap":
			if tool_id == TOOL_AIR or tool_id == TOOL_WATER:
				return true
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			var sap_softened: bool = patch.soap > float(sponge_profile["soap_threshold"]) \
				or patch.looseness > float(sponge_profile["looseness_threshold"])
			return tool_id == TOOL_SPONGE and not sap_softened
	return false


# The tool the player should reach for next on this patch.
static func recommended_tool(patch: DirtPatch) -> String:
	match patch.kind:
		"leaf":
			return TOOL_AIR
		"oil", "bug":
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			if patch.soap > float(sponge_profile["soap_threshold"]) or patch.looseness > float(sponge_profile["looseness_threshold"]):
				return TOOL_SPONGE
			return TOOL_SOAP
		"poop":
			var water_profile: Dictionary = GameConfig.WATER_WASH_PROFILES[patch.kind]
			if patch.soap > float(water_profile["prepared_soap_threshold"]) or patch.state in [STATE_LOOSENED, STATE_RUNOFF]:
				return TOOL_WATER
			return TOOL_SOAP
		"road_grime":
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			if patch.wetness > float(sponge_profile["wetness_threshold"]) or patch.soap > float(sponge_profile["soap_threshold"]) or patch.looseness > float(sponge_profile["looseness_threshold"]):
				return TOOL_SPONGE
			return TOOL_WATER
		"sap":
			var sponge_profile: Dictionary = GameConfig.SPONGE_WASH_PROFILES[patch.kind]
			if patch.soap > float(sponge_profile["soap_threshold"]) \
					or patch.looseness > float(sponge_profile["looseness_threshold"]):
				return TOOL_SPONGE
			return TOOL_SOAP
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
