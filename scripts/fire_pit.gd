extends Area2D
## Burns the chef while they stand in it. The chef's 3 s immunity spaces out the hits.

signal burned

func _ready() -> void:
	add_to_group("fire_pit")   # the level finds every fire pit through this group
	
func _physics_process(_delta: float) -> void:
	# Checked every frame, not only on enter, so standing still in the fire keeps hurting.
	for body in get_overlapping_bodies():
		if body.has_method("take_hit") and body.take_hit():
			burned.emit()
