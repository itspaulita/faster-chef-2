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

## Which level's order to show (0-based). -1 = the level being played (GameState.level_index);
## set 1 or 2 to preview another level when running this scene on its own.
@export var level_override := -1
@export var chef_stop_x := 960.0

var _tween: Tween
var _finished := false
var _info: LevelInfo
var _monsters: Array[IdleChef] = []
## One order bubble per monster (the scene's own, plus a copy for a second monster).
var _bubbles: Array[Node2D] = []

@onready var chef: IdleChef = $Chef
@onready var monster: IdleChef = $Monster
@onready var bubble: Node2D = $OrderBubble
@onready var dish_icon: Sprite2D = $OrderBubble/DishIcon
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	if GameState.selected_chef_texture:
		chef.texture = GameState.selected_chef_texture
	# Set here, not in the scene, so the editor can't drop these overrides when it re-saves.
	chef.idle_frames = PackedInt32Array(CHEF_WALK_RIGHT)
	chef.frame_time = 0.15
	_info = Levels.info(level_override if level_override >= 0 else GameState.level_index)
	_setup_monsters()
	for b in _bubbles:
		b.get_node("DishIcon").texture = _info.dish_icon
		b.scale = Vector2.ZERO

	_tween = create_tween()
	_tween.tween_property(fade, "color:a", 0.0, 0.5)
	_tween.tween_property(chef, "position:x", chef_stop_x, 2.0)
	_tween.tween_callback(_on_chef_arrived)
	for i in _bubbles.size():
		# The first bubble pops after the chef arrives; the others pop together with it.
		var step := _tween if i == 0 else _tween.parallel()
		step.tween_property(_bubbles[i], "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_show_order_banner)
	_tween.tween_interval(2.6) #Chi
	_tween.tween_callback(_on_chef_leaves) #Chi
	_tween.tween_property(chef, "position:x", CHEF_EXIT_X, 1.0) \
			.set_ease(Tween.EASE_IN) #Chi
	_tween.tween_callback(_finish) #Chi


## One monster stands big on the right; two stand side by side, a bit smaller, each with
## their own order bubble above them.
func _setup_monsters() -> void:
	var textures := _info.monsters
	var pair := textures.size() > 1
	var xs := [1270.0, 1640.0] if pair else [1380.0]
	var scale_k := 3.0 if pair else 4.0
	var y := 728.0 if pair else 656.0   # keeps their feet on the same floor line
	monster.texture = textures[0]
	monster.position = Vector2(xs[0], y)
	monster.scale = Vector2.ONE * scale_k
	_monsters = [monster]
	for i in range(1, mini(textures.size(), xs.size())):
		var extra: IdleChef = monster.duplicate()
		extra.texture = textures[i]
		extra.position = Vector2(xs[i], y)
		add_child(extra)
		move_child(extra, monster.get_index() + 1)   # behind the bubble and the fade
		_monsters.append(extra)
	_bubbles = [bubble]
	if pair:
		# Each bubble sits up-left of its monster, like the single one does.
		for i in _monsters.size():
			var b: Node2D = bubble if i == 0 else bubble.duplicate()
			if i > 0:
				add_child(b)
				move_child(b, bubble.get_index() + 1)
				_bubbles.append(b)
			b.position = Vector2(xs[i] + 150.0, 340.0)
	for m in _monsters:
		m.idle_frames = PackedInt32Array(MONSTER_FRAMES)
		m.frame_time = 0.3


func _show_order_banner() -> void:
	# The popup scene is reused as a notice: no pause, no dimming, closes itself.
	var popup: ModalPopup = load("res://scenes/modal_popup.tscn").instantiate()
	add_child(popup)
	popup.open(_info.order_text, [], false, 2.5)


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
