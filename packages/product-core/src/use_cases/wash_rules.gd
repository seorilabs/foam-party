extends RefCounted

# Pure car-washing rules: how each tool mutates a dirt patch, plus the geometry
# and runoff helpers. All engine/random inputs are injected so results are
# bit-identical to the former methods on the Main node:
#   - the air lift (formerly rng.randf_range(10,42)) is passed in as `lift_y`,
#     drawn by the godot layer ONLY for light dirt to preserve the RNG sequence;
#   - the per-tool upgrade multiplier is passed in as `mult`.
# The health clamp, removal side-effects, sfx and bursts stay in the godot layer.

const GameConfig = preload("res://core/domain/game_config.gd")
const Coaching = preload("res://core/use_cases/coaching.gd")
const DirtPatch = preload("res://core/domain/dirt_patch.gd")

const STATE_WET := "wet"
const STATE_SOAPED := "soaped"
const STATE_LOOSENED := "loosened"
const STATE_RUNOFF := "runoff"
const STATE_FLYING := "flying"
const STATE_REMOVED := "removed"

static func patch_center(patch: DirtPatch) -> Vector2:
	return patch.position + patch.drift


static func push_direction(patch: DirtPatch, source_point: Vector2) -> Vector2:
	var direction := (patch_center(patch) - source_point).normalized()
	if direction.length() < 0.1:
		direction = Vector2(1.0, -0.18).normalized()
	return direction


static func is_patch_removed(patch: DirtPatch) -> bool:
	return patch.state == STATE_REMOVED or patch.health <= 0.0


static func _tuning_profile(table: Dictionary, dirt_kind: String) -> Dictionary:
	if table.has(dirt_kind):
		return table[dirt_kind] as Dictionary
	return table.get("_default", {}) as Dictionary


static func runoff_cleanup_rate(patch: DirtPatch) -> float:
	var profile := _tuning_profile(GameConfig.RUNOFF_CLEANUP_PROFILES, patch.kind)
	return float(profile.get("base", 0.0)) \
		+ patch.wetness * float(profile.get("wetness", 0.0)) \
		+ patch.soap * float(profile.get("soap", 0.0)) \
		+ patch.looseness * float(profile.get("looseness", 0.0))


# `lift_y` is the magnitude of the upward lift impulse for light dirt, drawn by
# the caller (rng.randf_range(10.0, 42.0)) so this stays deterministic/pure.
static func apply_air(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float, lift_y: float) -> void:
	var push := push_direction(patch, source_point)
	var profile := _tuning_profile(GameConfig.AIR_WASH_PROFILES, patch.kind)
	if Coaching.is_light_dirt(patch.kind):
		patch.state = STATE_FLYING
		var lift := Vector2(0.0, -lift_y)
		var target_velocity := push * (float(GameConfig.AIR_MOTION_PROFILE["base_speed"]) + patch.radius * float(GameConfig.AIR_MOTION_PROFILE["radius_speed"])) + lift
		patch.velocity = patch.velocity.lerp(target_velocity, clamp(delta * float(GameConfig.AIR_MOTION_PROFILE["velocity_response"]), 0.0, 1.0))
		patch.drift += patch.velocity * delta
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.health -= float(profile["damage"]) * proximity * delta * GameConfig.CLEAN_DAMAGE_RATE
	else:
		patch.drift += push * delta * proximity * float(GameConfig.AIR_MOTION_PROFILE["heavy_drift"])
		patch.drift = patch.drift.limit_length(float(GameConfig.AIR_MOTION_PROFILE["heavy_drift_limit"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))


static func apply_water(patch: DirtPatch, delta: float, proximity: float, mult: float) -> void:
	# Resin repels a water-only wash. Keep every preparation and health field
	# unchanged so the coaching path remains strictly soap then sponge.
	if patch.kind == "sap":
		return
	var was_misapplied := Coaching.tool_misapplied(Coaching.TOOL_WATER, patch)
	var health_before := patch.health
	var wr := GameConfig.CLEAN_DAMAGE_RATE * mult
	var profile := _tuning_profile(GameConfig.WATER_WASH_PROFILES, patch.kind)
	patch.wetness = min(1.0, patch.wetness + delta * proximity * GameConfig.WATER_WETNESS_RATE)
	patch.runoff = min(1.0, patch.runoff + delta * proximity * GameConfig.WATER_RUNOFF_RATE)

	if patch.kind == "mud":
		patch.state = STATE_RUNOFF if patch.wetness > float(profile["runoff_wetness"]) else STATE_WET
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.health -= float(profile["damage"]) * proximity * delta * wr
	elif patch.kind == "dust":
		patch.state = STATE_RUNOFF
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.health -= float(profile["damage"]) * proximity * delta * wr
	elif patch.kind == "leaf":
		patch.state = STATE_WET
		patch.velocity += GameConfig.WATER_LEAF_PUSH_VELOCITY * delta * proximity
		patch.health -= float(profile["damage"]) * proximity * delta * wr
	elif patch.kind == "oil" or patch.kind == "bug":
		var rinse_power: float = patch.soap * (float(profile["rinse_base"]) + patch.looseness * float(profile["rinse_looseness"]))
		if rinse_power > float(profile["rinse_power_threshold"]):
			patch.state = STATE_RUNOFF
			patch.health -= rinse_power * float(profile["prepared_damage"]) * proximity * delta * wr
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["prepared_soap_decay"]))
		else:
			patch.state = STATE_WET
			patch.health -= float(profile["dry_damage"]) * proximity * delta * wr
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["dry_soap_decay"]))
	elif patch.kind == "poop":
		if patch.soap > float(profile["prepared_soap_threshold"]) or patch.state in [STATE_LOOSENED, STATE_RUNOFF]:
			var rinse_power: float = max(patch.soap, float(profile["rinse_soap_floor"])) * (float(profile["rinse_base"]) + patch.looseness * float(profile["rinse_looseness"]))
			patch.state = STATE_RUNOFF
			patch.health -= rinse_power * float(profile["prepared_damage"]) * proximity * delta * wr
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["prepared_soap_decay"]))
		else:
			patch.state = STATE_WET
			patch.health -= float(profile["dry_damage"]) * proximity * delta * wr
	elif patch.kind == "road_grime":
		# A rinse wets and loosens the abrasive surface dust, but the bonded road
		# film still needs a contact wash with the sponge.
		patch.state = STATE_WET
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.health -= float(profile["damage"]) * proximity * delta * wr
	else:
		patch.state = STATE_WET
		patch.health -= float(profile["damage"]) * proximity * delta * wr

	if was_misapplied:
		_apply_misapplied_damage(patch, health_before, delta, proximity, mult)


static func apply_soap(patch: DirtPatch, delta: float, proximity: float, mult: float) -> void:
	var was_misapplied := Coaching.tool_misapplied(Coaching.TOOL_SOAP, patch)
	var health_before := patch.health
	var sr := GameConfig.CLEAN_DAMAGE_RATE * mult
	var profile := _tuning_profile(GameConfig.SOAP_WASH_PROFILES, patch.kind)
	if patch.kind == "oil" or patch.kind == "bug":
		patch.soap = min(1.0, patch.soap + delta * proximity * float(profile["soap_build"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.state = STATE_LOOSENED if patch.looseness > float(profile["loosened_threshold"]) else STATE_SOAPED
		patch.health -= float(profile["damage"]) * proximity * delta * sr
	elif patch.kind == "sap":
		patch.soap = min(1.0, patch.soap + delta * proximity * float(profile["soap_build"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.state = STATE_LOOSENED if patch.looseness > float(profile["loosened_threshold"]) else STATE_SOAPED
		patch.health -= float(profile["damage"]) * proximity * delta * sr
	elif patch.kind == "mud":
		patch.soap = min(1.0, patch.soap + delta * proximity * float(profile["soap_build"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.state = STATE_SOAPED
		patch.health -= float(profile["damage"]) * proximity * delta * sr
	elif patch.kind == "poop":
		patch.soap = min(1.0, patch.soap + delta * proximity * float(profile["soap_build"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.state = STATE_LOOSENED if patch.looseness > float(profile["loosened_threshold"]) else STATE_SOAPED
		patch.health -= float(profile["damage"]) * proximity * delta * sr
	elif patch.kind == "road_grime":
		patch.soap = min(1.0, patch.soap + delta * proximity * float(profile["soap_build"]))
		patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["looseness"]))
		patch.state = STATE_LOOSENED if patch.looseness > float(profile["loosened_threshold"]) else STATE_SOAPED
		patch.health -= float(profile["damage"]) * proximity * delta * sr
	else:
		patch.soap = min(float(profile["soap_cap"]), patch.soap + delta * proximity * float(profile["soap_build"]))

	if was_misapplied:
		_apply_misapplied_damage(patch, health_before, delta, proximity, mult)


static func apply_sponge(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float, mult: float) -> void:
	var was_misapplied := Coaching.tool_misapplied(Coaching.TOOL_SPONGE, patch)
	var health_before := patch.health
	var spr := GameConfig.CLEAN_DAMAGE_RATE * mult
	var push := push_direction(patch, source_point)
	var profile := _tuning_profile(GameConfig.SPONGE_WASH_PROFILES, patch.kind)
	patch.drift += push * delta * proximity * float(GameConfig.SPONGE_MOTION_PROFILE["drift"])
	patch.drift = patch.drift.limit_length(float(GameConfig.SPONGE_MOTION_PROFILE["drift_limit"]))

	if patch.kind == "oil" or patch.kind == "bug":
		if patch.soap > float(profile["soap_threshold"]) or patch.looseness > float(profile["looseness_threshold"]):
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.health -= (float(profile["prepared_base"]) + patch.soap * float(profile["soap_bonus"])) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["soap_decay"]))
		else:
			patch.health -= float(profile["dry_damage"]) * proximity * delta * spr
	elif patch.kind == "sap":
		if patch.soap > float(profile["soap_threshold"]) or patch.looseness > float(profile["looseness_threshold"]):
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.health -= (float(profile["prepared_base"]) + patch.soap * float(profile["soap_bonus"])) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["soap_decay"]))
		else:
			patch.health -= float(profile["dry_damage"]) * proximity * delta * spr
	elif patch.kind == "mud":
		if patch.wetness > float(profile["wetness_threshold"]) or patch.soap > float(profile["soap_threshold"]):
			patch.state = STATE_LOOSENED
			patch.health -= float(profile["prepared_damage"]) * proximity * delta * spr
		else:
			patch.health -= float(profile["dry_damage"]) * proximity * delta * spr
	elif patch.kind == "dust":
		patch.health -= float(profile["damage"]) * proximity * delta * spr
	elif patch.kind == "leaf":
		patch.health -= float(profile["damage"]) * proximity * delta * spr
	elif patch.kind == "road_grime":
		if patch.wetness > float(profile["wetness_threshold"]) or patch.soap > float(profile["soap_threshold"]) or patch.looseness > float(profile["looseness_threshold"]):
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.health -= (float(profile["prepared_base"]) + patch.soap * float(profile["soap_bonus"]) + patch.wetness * float(profile["wetness_bonus"])) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["soap_decay"]))
		else:
			patch.health -= float(profile["dry_damage"]) * proximity * delta * spr
	elif patch.kind == "poop":
		if patch.soap > float(profile["soap_threshold"]) or patch.looseness > float(profile["looseness_threshold"]):
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * float(profile["prepared_looseness"]))
			patch.health -= (float(profile["prepared_base"]) + patch.soap * float(profile["soap_bonus"])) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * float(profile["soap_decay"]))
		else:
			patch.health -= float(profile["dry_damage"]) * proximity * delta * spr

	if was_misapplied:
		_apply_misapplied_damage(patch, health_before, delta, proximity, mult)


static func _apply_misapplied_damage(patch: DirtPatch, health_before: float, delta: float, proximity: float, mult: float) -> void:
	patch.health = health_before - GameConfig.MISAPPLIED_DAMAGE_COEFFICIENT * proximity * delta * GameConfig.CLEAN_DAMAGE_RATE * mult
