extends RefCounted

# Pure stage-sheet projection. The Godot layer owns drawing and input; this use
# case decides which levels are visible/unlocked and projects persisted records.

const DEFAULT_PAGE_SIZE := 6


static func page_count(unlocked_level: int, page_size: int = DEFAULT_PAGE_SIZE) -> int:
	var safe_size := maxi(page_size, 1)
	# Always reserve one future preview slot so the next stage reads as locked.
	var total_slots := maxi(safe_size, maxi(unlocked_level, 1) + 1)
	return maxi(1, ceili(float(total_slots) / float(safe_size)))


static func clamp_page(unlocked_level: int, page: int, page_size: int = DEFAULT_PAGE_SIZE) -> int:
	return clampi(page, 0, page_count(unlocked_level, page_size) - 1)


static func cards(
	unlocked_level: int,
	best_times: Dictionary,
	best_stars: Dictionary,
	page: int,
	page_size: int = DEFAULT_PAGE_SIZE
) -> Array[Dictionary]:
	var safe_unlocked := maxi(unlocked_level, 1)
	var safe_size := maxi(page_size, 1)
	var safe_page := clamp_page(safe_unlocked, page, safe_size)
	var total_slots := maxi(safe_size, safe_unlocked + 1)
	var first_level := safe_page * safe_size + 1
	var last_level := mini(total_slots, first_level + safe_size - 1)
	var result: Array[Dictionary] = []
	for level in range(first_level, last_level + 1):
		result.append({
			"level": level,
			"unlocked": level <= safe_unlocked,
			"best_time": maxf(0.0, float(best_times.get(level, 0.0))),
			"best_stars": clampi(int(best_stars.get(level, 0)), 0, 3),
		})
	return result


static func record_best_stars(best_stars: Dictionary, level: int, stars: int) -> Dictionary:
	var safe_level := maxi(level, 1)
	var updated := best_stars.duplicate(true)
	updated[safe_level] = maxi(int(updated.get(safe_level, 0)), clampi(stars, 0, 3))
	return updated


static func total_best_stars(best_stars: Dictionary) -> int:
	var total := 0
	for raw_level in best_stars:
		total += clampi(int(best_stars[raw_level]), 0, 3)
	return total


static func migrate_best_stars(
	raw_best_stars: Dictionary,
	legacy_total_stars: int,
	unlocked_level: int
) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_level in raw_best_stars:
		var level := int(raw_level)
		var stars := clampi(int(raw_best_stars[raw_level]), 0, 3)
		if level > 0 and stars > 0:
			normalized[level] = stars
	if not normalized.is_empty() or legacy_total_stars <= 0:
		return normalized

	# Legacy saves had only an inflation-prone total. Reconstruct bounded records
	# across unlocked stages so the displayed total can immediately become the
	# sum of per-level bests without inventing records for locked future stages.
	var remaining := mini(maxi(legacy_total_stars, 0), maxi(unlocked_level, 1) * 3)
	for level in range(1, maxi(unlocked_level, 1) + 1):
		if remaining <= 0:
			break
		var stars := mini(remaining, 3)
		normalized[level] = stars
		remaining -= stars
	return normalized
