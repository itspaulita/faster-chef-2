class_name ChefStats
extends RefCounted
## Each chef's look, abilities and weaknesses. The choose-chef screen shows name/ability/weakness;
## the player and the levels read the numbers with ChefStats.mine(key, default).

const PLACEHOLDER := "TBD"

## Keys (all optional, a missing key = normal):
##   scene          the player scene whose animations this chef uses
##   speed          run speed multiplier (1.0 = normal)
##   jump           jump speed multiplier (height grows with the square: 0.9 → ~81%)
##   air_jumps      extra jumps in the air (1 = double jump)
##   cats_hop       cats near this chef stop and hop in place
##   pickup_radius  ingredient pickup circle, in the chef's local units (0 = just the body)
##   slippery       slow to start and stop
const DATA := {
	"PrincessDish": {
		"name": "Princess Dish",
		"ability": "Normal",
		"weakness": "Normal",
		"scene": "res://scenes/player_1.tscn",
		"speed": 1.0,
		"jump": 1.0,
	},
	"LegendOfLasagna": {
		"name": "Legend of Lasagna",
		"ability": "Highest jump",
		"weakness": "15% slower",
		"scene": "res://scenes/player_2.tscn",
		"speed": 0.85,
		"jump": 1.1,
	},
	"Pastatouille": {
		"name": "Pastatouille",
		"ability": "Double jump",
		"weakness": "Cats get excited nearby",
		"scene": "res://scenes/player_3.tscn",
		"air_jumps": 1,
		"cats_hop": true,
	},
	"MavisPapaya": {
		"name": "Mavis Papaya",
		"ability": "Wider ingredient pickup",
		"weakness": "Slippery movement",
		"scene": "res://scenes/player_4.tscn",
		"pickup_radius": 110.0,
		"slippery": true,
	},
}


## One setting of a chef, or `default` if that chef doesn't have it.
static func stat(chef_id: String, key: String, default: Variant) -> Variant:
	return DATA.get(chef_id, {}).get(key, default)


## Same, for the chef picked on the choose-chef screen.
static func mine(key: String, default: Variant) -> Variant:
	return stat(GameState.selected_chef_name, key, default)


## Run-speed multiplier for a chef (1.0 = normal).
static func speed_scale(chef_id: String) -> float:
	return stat(chef_id, "speed", 1.0)


static func get_stats(chef_id: String) -> Dictionary:
	var stats: Dictionary = DATA.get(chef_id, {"name": chef_id, "ability": "", "weakness": ""}).duplicate()
	for key in ["ability", "weakness"]:
		if stats[key] == "":
			stats[key] = PLACEHOLDER
	return stats
