class_name DeliveryCutscene
extends CanvasLayer
## Final cutscene: the chef carries the dish in from the right to the monster (the mirror of
## the order cutscene), hands it over, and the monster's reaction bubble pops up (heart,
## smiley or sad face, from the stars earned). Then `finished` fires and the score tally can
## come up. The game is paused while it plays; any key or click skips it.

signal finished

## Bottom row of every chef sheet: arms out, carrying (same as idle_side_grab / running_grab).
const CHEF_WALK := [24, 25]    # running_grab
const CHEF_STAND := [24, 25]   # idle_side_grab
## After handing the dish over: the normal side idle (same frames as idle_side), hands empty.
const CHEF_EMPTY := [8, 9]
const MONSTER_FRAMES := [0, 1, 2, 3]
const EMOTES := preload("res://assets/images/misc/Emotes.png")
const EMOTE_SCALE := 3.0

@export var dish_texture: Texture2D = preload("res://assets/images/food/dish-salmon.png")
## Where the chef stops, left of the monster's hand-over spot.
@export var chef_stop_x := 960.0

var _tween: Tween
var _finished := false
var _was_paused := false

@onready var chef: IdleChef = %Chef
@onready var monster: IdleChef = %Monster
@onready var dish: Sprite2D = %Dish
@onready var reaction: Node2D = %Reaction
@onready var emote: Sprite2D = %Emote
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	# Keep running while the rest of the game is frozen underneath.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true

	if GameState.selected_chef_texture:
		chef.texture = GameState.selected_chef_texture
	#chef.flip_h = true   # walking left
	chef.idle_frames = PackedInt32Array(CHEF_WALK)
	chef.frame_time = 0.15
	monster.idle_frames = PackedInt32Array(MONSTER_FRAMES)
	monster.frame_time = 0.3
	dish.texture = dish_texture

	var atlas := AtlasTexture.new()
	atlas.atlas = EMOTES
	atlas.region = ScoreTally.EMOTE_REGIONS[GameState.mood()]
	emote.texture = atlas
	reaction.scale = Vector2.ZERO

	_tween = create_tween()
	_tween.tween_property(fade, "color:a", 0.0, 0.5)
	_tween.tween_property(chef, "position:x", chef_stop_x, 2.0)
	_tween.tween_callback(_on_arrived)
	_tween.tween_interval(0.3)
	# The dish goes from the chef's hands to the monster.
	_tween.tween_property(dish, "global_position", monster.global_position + Vector2(0, -60), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(dish, "scale", Vector2.ONE * 0.15, 0.5)
	_tween.tween_callback(_on_handed_over)
	_tween.tween_interval(0.2)
	_tween.tween_property(reaction, "scale", Vector2.ONE * EMOTE_SCALE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(1.8)
	_tween.tween_callback(_finish)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_finish()
		get_viewport().set_input_as_handled()


func _on_arrived() -> void:
	chef.idle_frames = PackedInt32Array(CHEF_STAND)
	chef.frame_time = 0.4

## The dish reached the monster: hide it, drop the chef's arms, keep facing left.
func _on_handed_over() -> void:
	dish.hide()
	chef.idle_frames = PackedInt32Array(CHEF_EMPTY)
	# The idle frames (8, 9) are drawn facing left already, unlike the grab frames,
	# so they must NOT be flipped.
	chef.flip_h = false

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_tween.kill()
	var out := create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.25)
	await out.finished
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()
