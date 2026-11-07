class_name ChefStats
extends RefCounted
## Abilities and weaknesses shown on the chef select screen (text only for now, except
## `speed`, which the player applies). Blank entries show PLACEHOLDER.

const PLACEHOLDER := "TBD"

const DATA := {
	"PrincessDish": {
		"name": "Princess Dish",
		"ability": "15% faster",
		"weakness": "Jumps the lowest",
		"speed": 1.15,
	},
	"LegendOfLasagna": {
		"name": "Legend of Lasagna",
		"ability": "Jumps the highest",
		"weakness": "15% slower",
		"speed": 0.85,
	},
	"Pastatouille": {
		"name": "Pastatouille",
		"ability": "Only 2 chops per ingredient",
		"weakness": "Cat hits cost double points",
	},
	"MavisPapaya": {
		"name": "Mavis Papaya",
		"ability": "Wider ingredient pickup",
		"weakness": "Slippery movement",
	},
}


## Run-speed multiplier for a chef (1.0 = normal). Applied by the player on every map.
static func speed_scale(chef_id: String) -> float:
	return DATA.get(chef_id, {}).get("speed", 1.0)


static func get_stats(chef_id: String) -> Dictionary:
	var stats: Dictionary = DATA.get(chef_id, {"name": chef_id, "ability": "", "weakness": ""}).duplicate()
	for key in ["ability", "weakness"]:
		if stats[key] == "":
			stats[key] = PLACEHOLDER
	return stats
