extends CharacterBody2D

const SPEED := 450.0
const JUMP_VELOCITY := -850.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Cat collision: blink effect during immunity cooldown time
const IMMUNE_TIME := 3.0
const BLINK_INTERVAL := 0.4

var is_immune := false
var blink_tween: Tween

func _physics_process(delta: float) -> void:
	# Coyote time: refill while standing, count down while in the air.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
		velocity += get_gravity() * delta

	# Jump buffer: remember the jump press for a short moment.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Let go of jump early for a short hop.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if not is_on_floor():
		sprite.play("jumping")
	elif absf(velocity.x) > 1.0:
		sprite.play("running")
	else:
		sprite.play("idle_side")

## Called by a cat when it touches the chef. Returns true if the hit counted.
func hit_by_cat() -> bool:
	if is_immune:
		return false
	is_immune = true
	_start_blink()
	get_tree().create_timer(IMMUNE_TIME).timeout.connect(_end_immunity)
	return true


func _start_blink() -> void:
	if blink_tween:
		blink_tween.kill()
	# One loop = fade out + fade in, so 3 s / 0.2 s = 15 blinks.
	blink_tween = create_tween().set_loops(int(IMMUNE_TIME / (BLINK_INTERVAL * 2)))
	blink_tween.tween_property(sprite, "modulate:a", 0.2, BLINK_INTERVAL)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, BLINK_INTERVAL)


func _end_immunity() -> void:
	is_immune = false
	if blink_tween:
		blink_tween.kill()
	sprite.modulate.a = 1.0
