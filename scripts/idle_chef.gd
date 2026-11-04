class_name IdleChef
extends Sprite2D
## Looping frame animation for a sprite sheet, with an optional small bob.
## Defaults to the two-frame front-facing idle (row 0, columns 0-1).

@export var idle_frames: PackedInt32Array = [0, 1]
@export var frame_time := 0.4
@export var bob_height := 0.0
@export var bob_speed := 3.0
## Offsets the loop so a row of chefs doesn't move in sync.
@export var start_delay := 0.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = start_delay


func _process(delta: float) -> void:
	_time += delta
	frame = idle_frames[int(_time / frame_time) % idle_frames.size()]
	position.y = _base_y + sin(_time * bob_speed) * bob_height
