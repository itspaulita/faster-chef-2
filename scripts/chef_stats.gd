class_name ChefStats
extends RefCounted
## Each chef's look, abilities and weaknesses. The choose-chef screen shows name/ability/weakness;
## the player and the levels read the numbers with ChefStats.mine(key, default).

##   sheet          the chef's sprite sheet (8x4 frames), for pictures outside the choose screen
##   unlock_after   finishing this level (0-based) unlocks the chef; -1 = open from the start

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
		"sheet": "res://assets/images/player/princess dish 2_2.png",
		"unlock_after": -1,
	},
	"LegendOfLasagna": {
		"name": "Legend of Lasagna",
		"ability": "Highest jump",
		"weakness": "15% slower",
		"scene": "res://scenes/player_2.tscn",
		"speed": 0.85,
		"jump": 1.1,
		"sheet": "res://assets/images/player/legend of lasagna.png",
		"unlock_after": 0,
	},
	"Pastatouille": {
		"name": "Pastatouille",
		"ability": "Double jump",
		"weakness": "Cats get excited nearby",
		"scene": "res://scenes/player_3.tscn",
		"air_jumps": 1,
		"cats_hop": true,
		"sheet": "res://assets/images/player/pastatouille.png",
		"unlock_after": 1,
	},
	"MavisPapaya": {
		"name": "Mavis Papaya",
		"ability": "Wider ingredient pickup",
		"weakness": "Slippery movement",
		"scene": "res://scenes/player_4.tscn",
		"pickup_radius": 110.0,
		"slippery": true,
		"sheet": "res://assets/images/player/mavis papaya.png",
		"unlock_after": 2,

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

## The chefs that finishing `level` (0-based) unlocks.
static func unlocked_by(level: int) -> Array[String]:
	var chefs: Array[String] = []
	for id in DATA:
		if DATA[id].get("unlock_after", -1) == level:
			chefs.append(id)
	return chefs


## The level (1-based, as the player sees it) that unlocks this chef, or 0 if it's open from the start.
static func unlock_level(id: String) -> int:
	return stat(id, "unlock_after", -1) + 1
