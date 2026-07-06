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


static func runoff_cleanup_rate(patch: DirtPatch) -> float:
	if patch.kind == "mud" or patch.kind == "dust":
		return 0.42 + patch.wetness * 0.25
	if patch.kind == "oil" or patch.kind == "bug":
		return patch.soap * 0.18 + patch.looseness * 0.32
	if patch.kind == "poop":
		return patch.soap * 0.22 + patch.looseness * 0.28
	return 0.08


# `lift_y` is the magnitude of the upward lift impulse for light dirt, drawn by
# the caller (rng.randf_range(10.0, 42.0)) so this stays deterministic/pure.
static func apply_air(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float, lift_y: float) -> void:
	var push := push_direction(patch, source_point)
	if Coaching.is_light_dirt(patch.kind):
		patch.state = STATE_FLYING
		var lift := Vector2(0.0, -lift_y)
		var target_velocity := push * (235.0 + patch.radius * 3.5) + lift
		patch.velocity = patch.velocity.lerp(target_velocity, clamp(delta * 9.0, 0.0, 1.0))
		patch.drift += patch.velocity * delta
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 2.2)
		var rate := 2.85
		if patch.kind == "dust":
			rate = 2.15
		patch.health -= rate * proximity * delta * GameConfig.CLEAN_DAMAGE_RATE
	else:
		patch.drift += push * delta * proximity * 7.0
		patch.drift = patch.drift.limit_length(5.5)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.08)


static func apply_water(patch: DirtPatch, delta: float, proximity: float, mult: float) -> void:
	var wr := GameConfig.CLEAN_DAMAGE_RATE * mult
	patch.wetness = min(1.0, patch.wetness + delta * proximity * 1.85)
	patch.runoff = min(1.0, patch.runoff + delta * proximity * 0.8)

	if patch.kind == "mud":
		patch.state = STATE_RUNOFF if patch.wetness > 0.3 else STATE_WET
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.1)
		patch.health -= 2.25 * proximity * delta * wr
	elif patch.kind == "dust":
		patch.state = STATE_RUNOFF
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.0)
		patch.health -= 1.85 * proximity * delta * wr
	elif patch.kind == "leaf":
		patch.state = STATE_WET
		patch.velocity += Vector2(12.0, 36.0) * delta * proximity
		patch.health -= 0.25 * proximity * delta * wr
	elif patch.kind == "oil" or patch.kind == "bug":
		var rinse_power: float = patch.soap * (0.75 + patch.looseness)
		if rinse_power > 0.25:
			patch.state = STATE_RUNOFF
			patch.health -= rinse_power * 1.75 * proximity * delta * wr
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.55)
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.45)
		else:
			patch.state = STATE_WET
			patch.health -= 0.08 * proximity * delta * wr
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.12)
	elif patch.kind == "poop":
		if patch.soap > 0.25 or patch.state in [STATE_LOOSENED, STATE_RUNOFF]:
			var rinse_power: float = max(patch.soap, 0.3) * (0.9 + patch.looseness * 0.5)
			patch.state = STATE_RUNOFF
			patch.health -= rinse_power * 2.2 * proximity * delta * wr
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.45)
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.55)
		else:
			patch.state = STATE_WET
			patch.health -= 0.04 * proximity * delta * wr
	elif patch.kind == "sticker":
		patch.health -= 0.03 * proximity * delta * wr
	else:
		patch.state = STATE_WET
		patch.health -= 0.45 * proximity * delta * wr


static func apply_soap(patch: DirtPatch, delta: float, proximity: float, mult: float) -> void:
	var sr := GameConfig.CLEAN_DAMAGE_RATE * mult
	if patch.kind == "oil" or patch.kind == "bug":
		patch.soap = min(1.0, patch.soap + delta * proximity * 1.65)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.95)
		patch.state = STATE_LOOSENED if patch.looseness > 0.65 else STATE_SOAPED
		patch.health -= 0.05 * proximity * delta * sr
	elif patch.kind == "mud":
		patch.soap = min(1.0, patch.soap + delta * proximity * 0.85)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.42)
		patch.state = STATE_SOAPED
		patch.health -= 0.12 * proximity * delta * sr
	elif patch.kind == "poop":
		patch.soap = min(1.0, patch.soap + delta * proximity * 2.0)
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.2)
		patch.state = STATE_LOOSENED if patch.looseness > 0.5 else STATE_SOAPED
		patch.health -= 0.06 * proximity * delta * sr
	elif patch.kind == "sticker":
		patch.health -= 0.02 * proximity * delta * sr
	else:
		patch.soap = min(0.45, patch.soap + delta * proximity * 0.25)


static func apply_sponge(patch: DirtPatch, delta: float, source_point: Vector2, proximity: float, mult: float) -> void:
	var spr := GameConfig.CLEAN_DAMAGE_RATE * mult
	var push := push_direction(patch, source_point)
	patch.drift += push * delta * proximity * 3.0
	patch.drift = patch.drift.limit_length(7.0)

	if patch.kind == "oil" or patch.kind == "bug":
		if patch.soap > 0.25 or patch.looseness > 0.35:
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.2)
			patch.health -= (1.15 + patch.soap) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.22)
		else:
			patch.health -= 0.12 * proximity * delta * spr
	elif patch.kind == "mud":
		if patch.wetness > 0.2 or patch.soap > 0.15:
			patch.state = STATE_LOOSENED
			patch.health -= 1.15 * proximity * delta * spr
		else:
			patch.health -= 0.35 * proximity * delta * spr
	elif patch.kind == "dust":
		patch.health -= 0.45 * proximity * delta * spr
	elif patch.kind == "leaf":
		patch.health -= 0.2 * proximity * delta * spr
	elif patch.kind == "sticker":
		patch.state = STATE_LOOSENED
		patch.looseness = min(1.0, patch.looseness + delta * proximity * 1.5)
		patch.health -= 1.35 * proximity * delta * spr
	elif patch.kind == "poop":
		if patch.soap > 0.25 or patch.looseness > 0.35:
			patch.state = STATE_LOOSENED
			patch.looseness = min(1.0, patch.looseness + delta * proximity * 0.8)
			patch.health -= (0.8 + patch.soap * 0.6) * proximity * delta * spr
			patch.soap = max(0.0, patch.soap - delta * proximity * 0.18)
		else:
			patch.health -= 0.08 * proximity * delta * spr
