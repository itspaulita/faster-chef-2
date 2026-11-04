extends Node2D

## How many tiles tall the screen shows. Bigger number = zoomed out more.
@export var screen_rows := 18.0
## Fits the player's camera to this level's map.
@onready var terrain: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $"Player 1/Camera2D"


func _ready() -> void:
	var used := terrain.get_used_rect()
	var cell := Vector2(terrain.tile_set.tile_size)

	# Corners of the painted map in world pixels (includes levelRoot's scale).
	var top_left := terrain.to_global(Vector2(used.position) * cell)
	var bottom_right := terrain.to_global(Vector2(used.end) * cell)

	# Zoom so the screen shows `screen_rows` tiles from top to bottom.
	var tile_height := (bottom_right.y - top_left.y) / used.size.y
	var view_height := screen_rows * tile_height
	#var zoom := get_viewport_rect().size.y / view_height
	#camera.zoom = Vector2(zoom, zoom)

	camera.limit_left = int(top_left.x)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
	# Keep the floor on the bottom edge of the screen. If the screen is taller
	# than the map, the extra space goes above it instead of below.
	camera.limit_top = int(minf(top_left.y, bottom_right.y - view_height))
