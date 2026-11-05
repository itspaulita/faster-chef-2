extends Node2D
## Moves the AnimatableBody2D back and forth. Each copy is set up in the Inspector.

@export var move_offset := Vector2(0, -100)  # how far it moves from its start. (128, 0) = to the right
@export var meet_at: Node2D                   # optional: go to this node's height instead of move_offset.y
@export var move_time := 2.0                  # seconds for each direction
@export var wait_at_start := 0.4
@export var wait_at_end := 0.7

@onready var body: AnimatableBody2D = $AnimatableBody2D

func _ready() -> void:
	var start := body.position
	var end := start + move_offset
	if meet_at:
		end.y = to_local(meet_at.global_position).y

	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # so the chef rides it smoothly
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_at_start)
	tween.tween_property(body, "position", end, move_time)
	tween.tween_interval(wait_at_end)
	tween.tween_property(body, "position", start, move_time)
