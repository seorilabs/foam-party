extends RefCounted

const GameConfig = preload("res://core/domain/game_config.gd")
const DirtProgression = preload("res://core/use_cases/dirt_progression.gd")

# Count growth stays readable through level 10, then reaches a mobile-safe hard
# cap instead of turning every later level into more overlapping touch targets.
const BASE_PATCH_COUNT := 18
const PATCHES_PER_LEVEL := 2
const MAX_PATCH_COUNT := 40
const DENSE_RADIUS_START_COUNT := 24
const DENSE_RADIUS_MIN_SCALE := 0.72

# A jittered normalized grid supplies more candidates than the density cap. The
# Godot adapter filters these points through the active car silhouette and the
# named center-distance/edge guards below.
const CANDIDATE_COLUMNS := 9
const CANDIDATE_ROWS := 9
const CANDIDATE_JITTER := 0.10
const MIN_CENTER_DISTANCE := 25.0
const SILHOUETTE_EDGE_MARGIN := 8.0

const HEALTH_BONUS_BY_KIND := {
	"oil": 25.0,
	"bug": 25.0,
	"poop": 15.0,
	"road_grime": 20.0,
	"sap": 20.0,
}

# Duplicate entries are intentional weights. Keeping the catalog in core makes
# both the level gate and each car's dirt bias independently testable.
const CAR_TYPE_POOLS := {
	# Parked city cars collect airborne dust, leaves, bird droppings, road residue,
	# and tree sap. Mud, oil, and bugs stay as low-frequency accents.
	"compact": ["dust", "leaf", "poop", "dust", "leaf", "road_grime", "poop", "dust", "leaf", "sap", "mud", "oil", "bug"],
	"sports": ["oil", "dust", "oil", "dust", "road_grime", "leaf", "dust", "bug", "mud"],
	"truck": ["mud", "mud", "bug", "leaf", "mud", "poop", "dust", "road_grime", "leaf"],
	"van": ["dust", "road_grime", "leaf", "dust", "mud", "road_grime", "oil", "leaf", "bug"],
	"offroad": ["mud", "road_grime", "mud", "bug", "leaf", "road_grime", "poop", "mud", "dust"],
}


static func spawn_count(level: int, available_slots: int = MAX_PATCH_COUNT) -> int:
	var safe_level := maxi(level, 1)
	var desired := BASE_PATCH_COUNT + safe_level * PATCHES_PER_LEVEL
	return mini(maxi(available_slots, 0), mini(desired, MAX_PATCH_COUNT))


static func radius_scale_for_count(patch_count: int) -> float:
	var dense_span := maxi(MAX_PATCH_COUNT - DENSE_RADIUS_START_COUNT, 1)
	var density := clampf(float(patch_count - DENSE_RADIUS_START_COUNT) / float(dense_span), 0.0, 1.0)
	return lerpf(1.0, DENSE_RADIUS_MIN_SCALE, density)


static func health_scale_for_level(level: int) -> float:
	var safe_level := maxi(level, 1)
	return minf(
		1.0 + float(safe_level - 1) * GameConfig.DIRT_HEALTH_SCALE_PER_LEVEL,
		GameConfig.DIRT_HEALTH_SCALE_MAX
	)


static func scaled_health(base_health: float, kind: String, level: int) -> float:
	var bonus: float = float(HEALTH_BONUS_BY_KIND.get(kind, 0.0))
	return (maxf(base_health, 0.0) + bonus) * health_scale_for_level(level)


static func normalized_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	for row in range(CANDIDATE_ROWS):
		for column in range(CANDIDATE_COLUMNS):
			# Fixed trig jitter breaks the visible grid while remaining deterministic.
			var phase := float(row * CANDIDATE_COLUMNS + column)
			var jitter_x := sin(phase * 2.17 + float(row) * 0.41) * CANDIDATE_JITTER
			var jitter_y := cos(phase * 1.73 + float(column) * 0.37) * CANDIDATE_JITTER
			candidates.append(Vector2(
				(float(column) + 0.5 + jitter_x) / float(CANDIDATE_COLUMNS),
				(float(row) + 0.5 + jitter_y) / float(CANDIDATE_ROWS)
			))
	return candidates


static func type_pool_for_level(car_type: String, level: int) -> Array[String]:
	var source: Array = CAR_TYPE_POOLS.get(car_type, GameConfig.DIRT_TYPES)
	return DirtProgression.filter_pool_for_level(source, level)
