extends Area2D

signal collected

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var float_player: AnimationPlayer = $AnimatedSprite2D/AnimationPlayer

var is_collected := false


func _on_body_entered(body: Node2D) -> void:
	# Only the chef can collect. The tile map and moving platforms are bodies too.
	if is_collected or not body is CharacterBody2D:
		return
	is_collected = true
	set_deferred("monitoring", false)  # Stop detecting touches.
	collected.emit()

	float_player.stop()                    # Freeze the floating.
	animated_sprite_2d.play("collected")   # Play the sparkle.
	await animated_sprite_2d.animation_finished
	queue_free()                           # Remove the cream.
