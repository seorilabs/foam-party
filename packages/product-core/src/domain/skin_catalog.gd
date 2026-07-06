extends RefCounted

# Nozzle skin catalog: for each tool, the ordered list of purchasable skins with
# id, display name, coin cost and tint color. Pure data. The godot layer sources
# its runtime `_nozzle_skins` dictionary from `catalog()`.

const _CATALOG := {
	"water": [
		{"id": "classic",  "name": "Classic",  "cost": 0,   "color": Color(0.29, 0.65, 1.0)},
		{"id": "coral",    "name": "Coral",    "cost": 80,  "color": Color(1.0, 0.42, 0.32)},
		{"id": "mint",     "name": "Mint",     "cost": 80,  "color": Color(0.22, 0.88, 0.68)},
		{"id": "gold",     "name": "Gold",     "cost": 150, "color": Color(1.0, 0.82, 0.20)},
	],
	"air": [
		{"id": "classic",  "name": "Classic",  "cost": 0,   "color": Color(0.27, 0.38, 0.43)},
		{"id": "cobalt",   "name": "Cobalt",   "cost": 80,  "color": Color(0.18, 0.38, 0.92)},
		{"id": "violet",   "name": "Violet",   "cost": 80,  "color": Color(0.62, 0.22, 0.90)},
		{"id": "gold",     "name": "Gold",     "cost": 150, "color": Color(1.0, 0.72, 0.15)},
	],
	"soap": [
		{"id": "classic",  "name": "Classic",  "cost": 0,   "color": Color(1.0, 1.0, 1.0)},
		{"id": "pink",     "name": "Pink",     "cost": 80,  "color": Color(1.0, 0.58, 0.78)},
		{"id": "lavender", "name": "Lavender", "cost": 80,  "color": Color(0.74, 0.52, 1.0)},
		{"id": "gold",     "name": "Gold",     "cost": 150, "color": Color(1.0, 0.82, 0.20)},
	],
	"sponge": [
		{"id": "classic",  "name": "Classic",  "cost": 0,   "color": Color(1.0, 0.62, 0.35)},
		{"id": "lime",     "name": "Lime",     "cost": 80,  "color": Color(0.42, 0.90, 0.28)},
		{"id": "purple",   "name": "Purple",   "cost": 80,  "color": Color(0.62, 0.28, 0.92)},
		{"id": "gold",     "name": "Gold",     "cost": 150, "color": Color(1.0, 0.82, 0.20)},
	],
}


static func catalog() -> Dictionary:
	return _CATALOG.duplicate(true)
