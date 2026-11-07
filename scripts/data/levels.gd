class_name Levels
extends RefCounted
## The list of levels, in play order. Add a level by adding its LevelInfo here.

const ALL: Array[LevelInfo] = [
	preload("res://resources/levels/level_1.tres"),
	preload("res://resources/levels/level_2.tres"),
	preload("res://resources/levels/level_3.tres"),
]


static func count() -> int:
	return ALL.size()


## The info for level `index` (0-based), clamped to a valid level.
static func info(index: int) -> LevelInfo:
	return ALL[clampi(index, 0, ALL.size() - 1)]


## The level the player is on (GameState.level_index).
static func current() -> LevelInfo:
	return info(GameState.level_index)
