class_name ChefStats
extends RefCounted
## Placeholder stats shown on the chef select screen. Blank entries show PLACEHOLDER.

const PLACEHOLDER := "TBD"

const DATA := {
	"PrincessDish": {
		"name": "Princess Dish",
		"ability": "Speed 2x",
		"weakness": "",
	},
	"LegendOfLasagna": {
		"name": "Legend of Lasagna",
		"ability": "Can jump high",
		"weakness": "",
	},
	"Pastatouille": {
		"name": "Pastatouille",
		"ability": "",
		"weakness": "Gets 2x minus points when hitting a cat",
	},
	"MavisPapaya": {
		"name": "Mavis Papaya",
		"ability": "",
		"weakness": "",
	},
}


static func get_stats(chef_id: String) -> Dictionary:
	var stats: Dictionary = DATA.get(chef_id, {"name": chef_id, "ability": "", "weakness": ""}).duplicate()
	for key in ["ability", "weakness"]:
		if stats[key] == "":
			stats[key] = PLACEHOLDER
	return stats
