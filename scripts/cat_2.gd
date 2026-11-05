extends Area2D

# cat hit logic
signal hit_chef(cat_name: String)

@export var cat_name := "Lem"
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var speed := 70.0          # use 70.0 in cat_2.gd
@export var patrol_to: Node2D      # the other cat. Leave empty to keep the old timer behaviour (level 1)

var direction := -1.0
var min_x := 0.0
var max_x := 0.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if patrol_to:
		var other_x: float = get_parent().to_local(patrol_to.global_position).x
		min_x = min(position.x, other_x)
		max_x = max(position.x, other_x)
		direction = 1.0 if other_x > position.x else -1.0  # left cat walks right first
		animated_sprite_2d.flip_h = direction > 0
	else:
		$Timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x += direction * speed * delta
	if patrol_to:
		if (direction > 0 and position.x >= max_x) or (direction < 0 and position.x <= min_x):
			_turn()

func _on_timer_timeout() -> void:
	_turn()

func _turn() -> void:
	direction *= -1
	animated_sprite_2d.flip_h = direction > 0

func _on_body_entered(body: Node2D) -> void:
	# hit_by_cat() returns false while the chef is immune, so no steal then.
	if body.has_method("hit_by_cat") and body.hit_by_cat():
		hit_chef.emit(cat_name)
