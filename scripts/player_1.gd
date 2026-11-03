extends CharacterBody2D
@onready var player_1: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 300.0
const JUMP_VELOCITY = -850.0


func _physics_process(delta: float) -> void:
	
	#	add animation
	if velocity.x > 1 or velocity.x < -1:
		player_1.animation = "running"
	else:
		player_1.animation = "idle_side"
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	# switch running direction
	if direction == 1.0:
		player_1.flip_h = false
	elif direction == -1.0:
		player_1.flip_h = true
