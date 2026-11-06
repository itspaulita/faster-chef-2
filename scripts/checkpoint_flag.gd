extends Area2D
## Touching this flag makes it the chef's respawn point. Works only once.

signal reached(spawn_position: Vector2)

## Where the chef reappears, relative to the flag. Negative y = above it.
@export var spawn_offset := Vector2(0, -10)

var is_active := false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("checkpoint")        # the level finds every flag through this group
	sprite.stop()
	sprite.frame = 0                  # frozen on the first frame until the chef passes

func _on_body_entered(body: Node2D) -> void:
	if is_active or not body is CharacterBody2D:
		return
	is_active = true
	sprite.play("checkpoint")            # the arrow starts moving = checkpoint is active
	reached.emit(to_global(spawn_offset))
