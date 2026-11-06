extends Area2D
## Sticky floor: slows the chef down and makes jumps shorter while standing on it.

@export var speed_multiplier := 0.6   # 40% slower
@export var jump_multiplier := 0.8    # jump power, see note below

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_gum"):
		body.enter_gum(speed_multiplier, jump_multiplier)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_gum"):
		body.exit_gum()
