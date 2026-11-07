extends Node2D
## Fits the player's camera to this level's map.

## How many tiles tall the screen shows. Used to keep the floor on the bottom edge.
@export var screen_rows := 18.0
## The Phase 2-3 map this level leads to. Leave empty until it exists.
@export_file("*.tscn") var next_phase_scene := ""
## How many pieces of EACH ingredient open the exit wall (and show the Phase 2 popup).
@export var min_pieces_per_ingredient := 2

@onready var terrain: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $"Player 1/Camera2D"
@onready var exit_wall: TileMapLayer = $ExitWall
@onready var exit_zone: Area2D = $ExitZone

var exit_open := false # if player doesnt collect enough ingredient, exit is blocked

signal exit_opened
signal phase_one_complete(final_xp: int)
signal xp_changed(total_xp: int)
signal ingredient_progress(type: String, have: int, total: int)

const BASE_XP := 1
const BONUS_XP := 3
const FALL_PENALTY_XP := 1
const FIRE_PENALTY_XP := 1
const CAT_TIME_PENALTY := 3   # seconds a cat costs in Phase 3
## After this percent of the level's pieces are collected, each extra piece gives BONUS_XP.
const BONUS_PERCENT := 80

@onready var ingredients: Node2D = $ingredients

# Cat noti
signal message(text: String)

@onready var cats: Node2D = $cats

var scene_by_type := {}       # "salmon": the salmon scene, used to respawn
var collected_pieces := {}    # "salmon": [ { "position": ..., "xp": 1 }, ... ]

var total_by_type := {}       # e.g. { "salmon": 3, "cream": 3, "potato": 3 }
var collected_by_type := {}   # e.g. { "salmon": 1, "cream": 0, "potato": 2 }
var xp := 0

# respawn character
@onready var player: CharacterBody2D = $"Player 1"

# ---- Phase 3: run back to the start with the dish ----
## A cat hit the chef in Phase 3: main.gd takes these seconds off the HUD clock.
signal time_penalty(seconds: float)
signal phase_three_complete(final_xp: int)

# main.gd sets these BEFORE the level is added, so _ready() knows which phase it is.
var is_phase_three := false
var start_xp := 0
## The dish this level cooks in the shared kitchen (and carries back in Phase 3).
@export var recipe: Recipe
var delivered := false

@onready var phase3_start: Marker2D = get_node_or_null("Phase3Start")
@onready var delivery_zone: Area2D = get_node_or_null("DeliveryZone")

## How far below the bottom of the map the chef falls before respawning.
const FALL_MARGIN := 200.0
var respawn_point := Vector2.ZERO


func _ready() -> void:
	_fit_camera_to_map()
	_setup_cats()
	_setup_fire_pits()
	if is_phase_three:
		_start_phase_three()
	else:
		_setup_ingredients()
		exit_zone.body_entered.connect(_on_exit_zone_entered)
	_setup_checkpoints()

func _fit_camera_to_map() -> void:
	var used := terrain.get_used_rect()
	var cell := Vector2(terrain.tile_set.tile_size)

	# Corners of the painted map in world pixels (includes levelRoot's scale).
	var top_left := terrain.to_global(Vector2(used.position) * cell)
	var bottom_right := terrain.to_global(Vector2(used.end) * cell)

	var tile_height := (bottom_right.y - top_left.y) / used.size.y
	var view_height := screen_rows * tile_height

	camera.limit_left = int(top_left.x)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
	# If the screen is taller than the map, the extra space goes above it.
	camera.limit_top = int(minf(top_left.y, bottom_right.y - view_height))

func _setup_ingredients() -> void:
	for piece in ingredients.get_children():
		if not piece.has_signal("collected"):
			continue
		var type: String = piece.scene_file_path.get_file().get_basename()
		total_by_type[type] = total_by_type.get(type, 0) + 1
		collected_by_type[type] = 0
		collected_pieces[type] = []
		scene_by_type[type] = load(piece.scene_file_path)
		_connect_piece(piece, type)


func _connect_piece(piece: Node2D, type: String) -> void:
	# Remember the type and where this piece lives, so it can respawn there.
	piece.collected.connect(_on_ingredient_collected.bind(type, piece.position))


func _on_ingredient_collected(type: String, spawn_position: Vector2) -> void:
	Audio.sfx("pickup")
	collected_by_type[type] += 1
	var have: int = collected_by_type[type]
	var total: int = total_by_type[type]
	var gained := BONUS_XP if have * 100 >= total * BONUS_PERCENT else BASE_XP
	collected_pieces[type].append({ "position": spawn_position, "xp": gained })
	_add_xp(gained)
	ingredient_progress.emit(type, have, total)
	print("%s %d/%d  +%d XP  (total %d XP)" % [type, have, total, gained, xp])
	_update_exit()

func _add_xp(amount: int) -> void:
	xp = maxi(xp + amount, 0)   # XP never goes below 0
	xp_changed.emit(xp)
	
func _setup_cats() -> void:
	for cat in cats.get_children():
		if cat.has_signal("hit_chef"):
			cat.hit_chef.connect(_on_cat_hit_chef)

func _setup_fire_pits() -> void:
	for pit in get_tree().get_nodes_in_group("fire_pit"):
		pit.burned.connect(_on_fire_burned)

func _on_fire_burned() -> void:
	_add_xp(-FIRE_PENALTY_XP)
	message.emit("Ouch, hot! -%d XP" % FIRE_PENALTY_XP)
	
func _on_cat_hit_chef(cat_name: String) -> void:
	if is_phase_three:
		# Phase 3: nothing to steal, so the cat costs time on the HUD clock instead.
		time_penalty.emit(CAT_TIME_PENALTY)
		message.emit("%s slowed you down! -%d s" % [cat_name, CAT_TIME_PENALTY])
		return
	var type := _most_collected_type()
	if type == "":
		return  # Nothing collected yet, nothing to steal.
	var stolen: Dictionary = collected_pieces[type].pop_back()
	collected_by_type[type] -= 1
	_add_xp(-stolen.xp)
	ingredient_progress.emit(type, collected_by_type[type], total_by_type[type])
	message.emit("Oh No %s steals %s!" % [cat_name, type.capitalize()])
	_respawn_piece(type, stolen.position)


func _most_collected_type() -> String:
	var best := ""
	var best_count := 0
	for type in collected_by_type:
		if collected_by_type[type] > best_count:
			best = type
			best_count = collected_by_type[type]
	return best


func _respawn_piece(type: String, spawn_position: Vector2) -> void:
	var piece: Node2D = scene_by_type[type].instantiate()
	piece.position = spawn_position
	_connect_piece(piece, type)
	# Deferred: we're inside a collision callback, where Godot won't let us add Areas.
	ingredients.add_child.call_deferred(piece)
	
func _update_exit() -> void:
	if exit_open or not _all_ingredients_at_minimum():
		return
	exit_open = true
	_open_exit_wall()
	exit_opened.emit()


func _open_exit_wall() -> void:
	# Fade the wall out, then turn it off (no drawing, no collision).
	var tween := create_tween()
	tween.tween_property(exit_wall, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): exit_wall.enabled = false)


func _all_ingredients_at_minimum() -> bool:
	for type in total_by_type:
		# mini(): a level with fewer pieces than the minimum still needs all of them, not more
		if collected_by_type[type] < mini(min_pieces_per_ingredient, total_by_type[type]):
			return false
	return true


func _on_exit_zone_entered(body: Node2D) -> void:
	if not exit_open or not body is CharacterBody2D:
		return
	# A cat may have stolen us back below the minimum after the wall opened.
	if not _all_ingredients_at_minimum():
		message.emit("You're missing ingredients! Go get them back first.")
		return
	phase_one_complete.emit(xp)
	
func _setup_checkpoints() -> void:
	respawn_point = player.global_position     # Phase 1: the start. Phase 3: Phase3Start.
	var used := "CheckpointsPhase3" if is_phase_three else "Checkpoints"
	var unused := "Checkpoints" if is_phase_three else "CheckpointsPhase3"

	var unused_flags := get_node_or_null(unused)
	if unused_flags:
		unused_flags.queue_free()               # the other phase's flags disappear

	var used_flags := get_node_or_null(used)
	if used_flags:
		for flag in used_flags.get_children():
			if flag.has_signal("reached"):
				flag.reached.connect(_on_checkpoint_reached)

func _on_checkpoint_reached(spawn_position: Vector2) -> void:
	# Only move forward: right in Phase 1, left in Phase 3.
	var is_forward := spawn_position.x < respawn_point.x if is_phase_three \
			else spawn_position.x > respawn_point.x
	if not is_forward:
		return
	respawn_point = spawn_position
	message.emit("Checkpoint!")

func _physics_process(_delta: float) -> void:
	if player.global_position.y > camera.limit_bottom + FALL_MARGIN:
		_respawn_player()


func _respawn_player() -> void:
	player.global_position = respawn_point
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()                        # jump the camera there, don't glide
	_add_xp(-FALL_PENALTY_XP)
	message.emit("Oops! -%d XP" % FALL_PENALTY_XP)
	
func _start_phase_three() -> void:
	ingredients.queue_free()                     # nothing to collect on the way back
	exit_wall.enabled = false                    # the wall stays open
	player.global_position = phase3_start.global_position
	player.sprite.flip_h = true                  # face left
	camera.reset_smoothing()
	if recipe:
		ItemHolder.get_or_create(player).hold_dish(recipe)   # dish floats above the chef
	xp = start_xp                                # continue from the Phase 1 XP
	xp_changed.emit(xp)
	delivery_zone.body_entered.connect(_on_delivery_zone_entered)


func _on_delivery_zone_entered(body: Node2D) -> void:
	if delivered or body != player:
		return
	delivered = true
	phase_three_complete.emit(xp)
