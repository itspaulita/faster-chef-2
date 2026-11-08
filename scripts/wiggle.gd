class_name Wiggle
extends Node2D
## Makes a decoration move on its own. Attach to any Sprite2D / AnimatedSprite2D / Node2D.
##   SWAY   tilts left and right (plants, flags, hanging pans). Rotates around the node's origin,
##          so set the sprite's Offset to put its bottom (or top, if hanging) on the origin.
##   SHAKE  quick small jitter (bubbling pots, a rattling lid)
##   FLOAT  drifts in a small circle (bubbles, steam, flies)
##   BOB    floats up and down

enum Motion { SWAY, SHAKE, FLOAT, BOB }

@export var motion := Motion.SWAY
## Degrees for SWAY, pixels for SHAKE / FLOAT / BOB.
@export var amount := 6.0
## Wiggles per second (roughly).
@export var speed := 1.0
## Random start point, so a row of the same decoration doesn't move in sync.
@export var random_start := true

var _time := 0.0
var _base_position := Vector2.ZERO
var _base_rotation := 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	if random_start:
		_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta * speed * TAU
	match motion:
		Motion.SWAY:
			rotation = _base_rotation + deg_to_rad(amount) * sin(_time)
		Motion.SHAKE:
			# Re-pick a small random spot a few times a second (snaps, like a pixel shake).
			if int(_time * 2.0) != int((_time - delta * speed * TAU) * 2.0):
				position = _base_position + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)).round()
		Motion.FLOAT:
			position = _base_position + Vector2(cos(_time), sin(_time)) * amount
		Motion.BOB:
			position = _base_position + Vector2(0, sin(_time) * amount)
