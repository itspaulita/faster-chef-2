extends Control
## Chef runs in, stops by the monster, and the monster's order pops up.

const NEXT_SCENE := "res://scenes/main.tscn" # Chi - change scene to main after cutscene
const FALLBACK_SCENE := "res://scenes/title_screen.tscn"
## Sheet row 1 (side view): columns 6-7 walk right, columns 2-3 stand facing right.
const CHEF_WALK_RIGHT := [14, 15]
const CHEF_STAND_RIGHT := [10, 11]
const MONSTER_FRAMES := [0, 1, 2, 3]
## Chi - Where the chef runs to before the level starts (off the right edge of 1920).
const CHEF_EXIT_X := 2100.0

@export var dish_name := "Tom yum"
## Index into the 5-dish sheet.
@export var dish_frame := 0
@export var chef_stop_x := 960.0

var _tween: Tween
var _finished := false

@onready var chef: IdleChef = $Chef
@onready var monster: IdleChef = $Monster
@onready var bubble: Node2D = $OrderBubble
@onready var dish_icon: Sprite2D = $OrderBubble/DishIcon
@onready var dish_label: Label = $OrderBubble/DishLabel
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	if GameState.selected_chef_texture:
		chef.texture = GameState.selected_chef_texture
	# Set here, not in the scene, so the editor can't drop these overrides when it re-saves.
	chef.idle_frames = PackedInt32Array(CHEF_WALK_RIGHT)
	chef.frame_time = 0.15
	monster.idle_frames = PackedInt32Array(MONSTER_FRAMES)
	monster.frame_time = 0.3
	dish_icon.frame = dish_frame
	dish_label.text = dish_name
	dish_label.visible_ratio = 0.0
	bubble.scale = Vector2.ZERO

	_tween = create_tween()
	_tween.tween_property(fade, "color:a", 0.0, 0.5)
	_tween.tween_property(chef, "position:x", chef_stop_x, 2.0)
	_tween.tween_callback(_on_chef_arrived)
	_tween.tween_property(bubble, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(dish_label, "visible_ratio", 1.0, 0.6)
	_tween.tween_interval(2.0) #Chi
	_tween.tween_callback(_on_chef_leaves) #Chi
	_tween.tween_property(chef, "position:x", CHEF_EXIT_X, 1.0) \
			.set_ease(Tween.EASE_IN) #Chi
	_tween.tween_callback(_finish) #Chi


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_finish()


func _on_chef_arrived() -> void:
	chef.idle_frames = PackedInt32Array(CHEF_STAND_RIGHT)
	chef.frame_time = 0.4

# Chi - when chef leave the cut scene, walk all the way to the right
func _on_chef_leaves() -> void:
	chef.idle_frames = PackedInt32Array(CHEF_WALK_RIGHT)
	chef.frame_time = 0.1   # faster steps = running

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_tween.kill()
	var out := create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.25)
	await out.finished
	if ResourceLoader.exists(NEXT_SCENE):
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		print("Next scene not made yet: ", NEXT_SCENE)
		get_tree().change_scene_to_file(FALLBACK_SCENE)
