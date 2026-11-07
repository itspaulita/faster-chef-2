extends CharacterBody2D

const SPEED := 450.0
const JUMP_VELOCITY := -1000.0
const COYOTE_TIME := 0.2
const JUMP_BUFFER_TIME := 0.1

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Cat collision: blink effect during immunity cooldown time
const IMMUNE_TIME := 3.0
const BLINK_INTERVAL := 0.4

var is_immune := false
var blink_tween: Tween

# The chosen chef's own run speed (Princess Dish +15%, Legend of Lasagna -15%): see ChefStats.
var chef_speed_scale := 1.0

# Bubblegum (and any future slow zone): 1.0 = normal
var speed_multiplier := 1.0
var jump_multiplier := 1.0
var _gum_count := 0   # how many gum patches the chef is touching right now

func _ready() -> void:
	chef_speed_scale = ChefStats.speed_scale(GameState.selected_chef_name)


func _physics_process(delta: float) -> void:
	# Coyote time: refill while standing, count down while in the air.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	apply_heavy_gravity(delta)

	# Jump buffer: remember the jump press for a short moment.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY * jump_multiplier
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Let go of jump early for a short hop.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var direction := Input.get_axis("left", "right")
	apply_horizontal_movement(delta, direction, SPEED * chef_speed_scale * speed_multiplier)
	if direction:
		sprite.flip_h = direction < 0

	move_and_slide()
	_update_animation()

## Called by a bubblegum path when the chef steps on it.
func enter_gum(speed_mult: float, jump_mult: float) -> void:
	_gum_count += 1
	speed_multiplier = speed_mult
	jump_multiplier = jump_mult
	sprite.speed_scale = speed_mult          # run animation looks sticky/slow too

## Called by a bubblegum path when the chef leaves it.
func exit_gum() -> void:
	_gum_count = maxi(_gum_count - 1, 0)
	if _gum_count == 0:                      # only back to normal when off ALL gum
		speed_multiplier = 1.0
		jump_multiplier = 1.0
		sprite.speed_scale = 1.0

func _update_animation() -> void:
	var carrying := _is_carrying()
	if not is_on_floor():
		# There's no "jumping while holding" animation, so keep the arms out in the air.
		sprite.play("idle_side_grab" if carrying else "jumping")
	elif absf(velocity.x) > 1.0:
		sprite.play("running_grab" if carrying else "running")
	else:
		sprite.play("idle_side_grab" if carrying else "idle_side")


## True while the chef carries the pot or the dish (the kitchen gives her an ItemHolder).
func _is_carrying() -> bool:
	var holder := get_node_or_null("ItemHolder") as ItemHolder
	return holder != null and holder.holds_in_hands()

## Called by a cat when it touches the chef. Returns true if the hit counted.
func hit_by_cat() -> bool:
	if is_immune:
		return false
	is_immune = true
	_start_blink()
	get_tree().create_timer(IMMUNE_TIME).timeout.connect(_end_immunity)
	return true

## Any hazard (cat, fire...) calls this. Returns true if the hit counted (not immune).
func take_hit() -> bool:
	return hit_by_cat()


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
	
	## Gravity that feels heavier on the way down.
## - Rising while holding jump: normal gravity (full, floaty jump)
## - Rising after releasing jump: stronger gravity (short hop ends fast)
## - Falling (past the peak): stronger gravity (fast, heavy drop)
## Works in any CharacterBody2D script. Call it once per frame in _physics_process.
func apply_heavy_gravity(
		delta: float,
		fall_multiplier := 1.8,
		release_multiplier := 2.5,
		max_fall_speed := 1400.0,
		jump_action := "jump") -> void:
	if is_on_floor():
		return
	var gravity := get_gravity()
	if velocity.y > 0.0:
		gravity *= fall_multiplier          # past the peak, falling
	elif not Input.is_action_pressed(jump_action):
		gravity *= release_multiplier       # still rising, but jump was released
	velocity += gravity * delta
	velocity.y = minf(velocity.y, max_fall_speed)  # terminal velocity
	
	## Horizontal movement with a short speed-up and slow-down.
## - accel_time: seconds to go from standing still to full speed
## - decel_time: seconds to go from full speed to a stop after letting go
## - turn_multiplier: how much faster a turnaround is (feels responsive)
## - air_control: 1.0 = same control in the air, lower = more committed jumps
## Works in any CharacterBody2D script. Call it once per frame in _physics_process.
func apply_horizontal_movement(
		delta: float,
		direction: float,
		max_speed := 450.0,
		accel_time := 0.12,
		decel_time := 0.08,
		turn_multiplier := 2.0,
		air_control := 0.8) -> void:
	var target_speed := direction * max_speed
	var rate: float
	if direction == 0.0:
		rate = max_speed / decel_time                     # letting go: slow to a stop
	elif velocity.x != 0.0 and signf(direction) != signf(velocity.x):
		rate = max_speed / accel_time * turn_multiplier   # turning around
	else:
		rate = max_speed / accel_time                     # speeding up
	if not is_on_floor():
		rate *= air_control
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
