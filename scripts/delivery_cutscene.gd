class_name DeliveryCutscene
extends CanvasLayer
## Final cutscene: the chef carries the dish in from the right to the monster(s) (the mirror
## of the order cutscene), hands it over, and the reaction bubble pops up above them (heart,
## smiley or sad face, from the stars earned). Then `finished` fires and the cutscene STAYS
## on screen as the background of the score tally. Call close() to remove it.
## The game is paused while it exists; any key or click skips ahead to the final picture.

signal finished

## Bottom row of every chef sheet: arms out, carrying (same as idle_side_grab / running_grab).
const CHEF_WALK := [24, 25]    # running_grab
const CHEF_STAND := [24, 25]   # idle_side_grab
## After handing the dish over: the normal side idle (same frames as idle_side), hands empty.
const CHEF_EMPTY := [8, 9]
## Chefs whose carrying frames (24, 25) face RIGHT on their sheet.
const CARRY_FACES_RIGHT := ["PrincessDish"]
const MONSTER_FRAMES := [0, 1, 2, 3]
const EMOTES := preload("res://assets/images/misc/Emotes.png")
const EMOTE_SCALE := 3.0

## Which level's monsters and dish to show (0-based). -1 = the level being played.
@export var level_override := -1
## Where the chef stops, left of the monster's hand-over spot.
@export var chef_stop_x := 960.0

var _tween: Tween
var _finished := false
var _was_paused := false
var _info: LevelInfo
var _monsters: Array[IdleChef] = []

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

	_info = Levels.info(level_override if level_override >= 0 else GameState.level_index)
	if GameState.selected_chef_texture:
		chef.texture = GameState.selected_chef_texture
	chef.flip_h = GameState.selected_chef_name in CARRY_FACES_RIGHT
	chef.idle_frames = PackedInt32Array(CHEF_WALK)
	chef.frame_time = 0.15
	_setup_monsters()
	dish.texture = _info.dish_icon

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
	# The dish goes from the chef's hands to the nearest monster.
	_tween.tween_property(dish, "global_position", _monsters[0].global_position + Vector2(0, -50), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(dish, "scale", Vector2.ONE * 0.15, 0.5)
	_tween.tween_callback(_on_handed_over)
	_tween.tween_interval(0.2)
	_tween.tween_property(reaction, "scale", Vector2.ONE * EMOTE_SCALE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(1.8)
	_tween.tween_callback(_finish)


## The order cutscene mirrored: one big monster on the left, or two side by side (the first
## one nearest the chef), with the reaction bubble above them.
func _setup_monsters() -> void:
	var textures := _info.monsters
	var pair := textures.size() > 1
	var xs := [650.0, 280.0] if pair else [540.0]
	var scale_k := 3.0 if pair else 4.0
	var y := 728.0 if pair else 656.0
	monster.texture = textures[0]
	monster.position = Vector2(xs[0], y)
	monster.scale = Vector2.ONE * scale_k
	_monsters = [monster]
	for i in range(1, mini(textures.size(), xs.size())):
		var extra: IdleChef = monster.duplicate()
		extra.texture = textures[i]
		extra.position = Vector2(xs[i], y)
		var parent := monster.get_parent()
		parent.add_child(extra)
		parent.move_child(extra, monster.get_index() + 1)   # behind the chef and the reaction
		_monsters.append(extra)
	reaction.position = Vector2(465.0, 560.0) if pair else Vector2(540.0, 455.0)
	for m in _monsters:
		m.idle_frames = PackedInt32Array(MONSTER_FRAMES)
		m.frame_time = 0.3


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_jump_to_end()
		get_viewport().set_input_as_handled()


func _on_arrived() -> void:
	chef.idle_frames = PackedInt32Array(CHEF_STAND)
	chef.frame_time = 0.4

## The dish reached the monster: hide it, drop the chef's arms, keep facing left.
func _on_handed_over() -> void:
	dish.hide()
	chef.idle_frames = PackedInt32Array(CHEF_EMPTY)
	# The empty-hands frames (8, 9) face RIGHT on every sheet, so flip them to face the monster.
	chef.flip_h = true

## Skips straight to the last picture: chef stopped, dish delivered, reaction showing.
func _jump_to_end() -> void:
	_tween.kill()
	fade.color.a = 0.0
	chef.position.x = chef_stop_x
	_on_handed_over()
	dish.hide()
	reaction.scale = Vector2.ONE * EMOTE_SCALE
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()


## Removes the cutscene and gives the game back its pause state.
func close() -> void:
	get_tree().paused = _was_paused
	queue_free()
