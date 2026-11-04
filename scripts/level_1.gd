extends Node2D
## Fits the player's camera to this level's map.

## How many tiles tall the screen shows. Used to keep the floor on the bottom edge.
@export var screen_rows := 18.0

@onready var terrain: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $"Player 1/Camera2D"


signal xp_changed(total_xp: int)
signal ingredient_progress(type: String, have: int, total: int)

const BASE_XP := 1
const BONUS_XP := 3
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

func _ready() -> void:
	_fit_camera_to_map()
	_setup_ingredients()
	_setup_cats()

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
	collected_by_type[type] += 1
	var have: int = collected_by_type[type]
	var total: int = total_by_type[type]
	var gained := BONUS_XP if have * 100 >= total * BONUS_PERCENT else BASE_XP
	collected_pieces[type].append({ "position": spawn_position, "xp": gained })
	xp += gained
	xp_changed.emit(xp)
	ingredient_progress.emit(type, have, total)
	print("%s %d/%d  +%d XP  (total %d XP)" % [type, have, total, gained, xp])


func _setup_cats() -> void:
	for cat in cats.get_children():
		if cat.has_signal("hit_chef"):
			cat.hit_chef.connect(_on_cat_hit_chef)


func _on_cat_hit_chef(cat_name: String) -> void:
	var type := _most_collected_type()
	if type == "":
		return  # Nothing collected yet, nothing to steal.
	var stolen: Dictionary = collected_pieces[type].pop_back()
	collected_by_type[type] -= 1
	xp -= stolen.xp
	xp_changed.emit(xp)
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
	
