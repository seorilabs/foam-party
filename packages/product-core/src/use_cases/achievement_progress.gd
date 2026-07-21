extends RefCounted

# Local-only lifetime achievement rules. The core receives monotonically
# increasing gameplay counters and returns a new immutable-style state plus the
# one-shot reward delta; persistence and presentation stay in the Godot adapter.

const COUNTER_WASHES := "washes_completed"
const COUNTER_DIRT := "dirt_removed"
const COUNTER_LEAF := "leaf_removed"
const COUNTER_STARS := "stars_collected"
const COUNTER_COMBO := "combo_peak"

const COUNTER_KEYS := [
	COUNTER_WASHES,
	COUNTER_DIRT,
	COUNTER_LEAF,
	COUNTER_STARS,
	COUNTER_COMBO,
]

const DEFINITIONS := [
	{"id": "wash_rookie", "counter": COUNTER_WASHES, "target": 10, "reward": 100, "label_key": "ACH_WASHES"},
	{"id": "dirt_hunter", "counter": COUNTER_DIRT, "target": 100, "reward": 80, "label_key": "ACH_DIRT"},
	{"id": "leaf_buster", "counter": COUNTER_LEAF, "target": 50, "reward": 80, "label_key": "ACH_LEAF"},
	{"id": "star_collector", "counter": COUNTER_STARS, "target": 30, "reward": 120, "label_key": "ACH_STARS"},
	{"id": "combo_master", "counter": COUNTER_COMBO, "target": 10, "reward": 100, "label_key": "ACH_COMBO"},
]


static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in DEFINITIONS:
		result.append((definition as Dictionary).duplicate(true))
	return result


static func default_counters() -> Dictionary:
	var counters := {}
	for key in COUNTER_KEYS:
		counters[key] = 0
	return counters


static func normalize_counters(raw: Variant) -> Dictionary:
	var counters := default_counters()
	if raw is Dictionary:
		for key in COUNTER_KEYS:
			counters[key] = maxi(0, int((raw as Dictionary).get(key, 0)))
	return counters


static func normalize_claimed(raw: Variant) -> Dictionary:
	var claimed := {}
	if raw is Dictionary:
		for definition in DEFINITIONS:
			var achievement_id: String = definition["id"]
			if bool((raw as Dictionary).get(achievement_id, false)):
				claimed[achievement_id] = true
	return claimed


static func apply_value(raw_counters: Variant, raw_claimed: Variant, counter_key: String, value: int) -> Dictionary:
	var counters := normalize_counters(raw_counters)
	var claimed := normalize_claimed(raw_claimed)
	if counter_key not in COUNTER_KEYS:
		return {
			"counters": counters,
			"claimed": claimed,
			"reward": 0,
			"newly_completed": [],
		}

	# Lifetime progress never moves backwards. Callers use current+delta for
	# totals and the observed value for peaks, so the same rule covers both.
	counters[counter_key] = maxi(int(counters[counter_key]), maxi(0, value))
	var reward := 0
	var newly_completed: Array[String] = []
	for definition in DEFINITIONS:
		var achievement_id: String = definition["id"]
		var definition_counter: String = definition["counter"]
		if not bool(claimed.get(achievement_id, false)) \
				and int(counters[definition_counter]) >= int(definition["target"]):
			claimed[achievement_id] = true
			reward += int(definition["reward"])
			newly_completed.append(achievement_id)
	return {
		"counters": counters,
		"claimed": claimed,
		"reward": reward,
		"newly_completed": newly_completed,
	}


static func progress_for(definition: Dictionary, counters: Dictionary) -> int:
	return mini(int(definition["target"]), maxi(0, int(counters.get(definition["counter"], 0))))
