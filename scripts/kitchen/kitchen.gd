extends Node2D
## Phase 2 kitchen: chopping board, pot and plating station for one level's recipe.
## Runs on its own (F6) for testing. Like level_1, it has a `message` signal that
## main.gd can connect to the notifications.

signal message(text: String)
## The chef picked up the plated dish: Phase 2 is over, Phase 3 (deliver) starts.
signal phase_two_complete(recipe: Recipe)

## The dish this kitchen cooks. Swap the .tres per level.
@export var recipe: Recipe = preload("res://resources/recipes/level_1.tres")
## Size of the room in local units (the root is scaled 3x, so 640x360 fills 1920x1080).
@export var room_size := Vector2(640, 360)

@onready var camera: Camera2D = $"Player 1/Camera2D"
@onready var chef: CharacterBody2D = $"Player 1"
@onready var holder: ItemHolder = ItemHolder.get_or_create(chef)
@onready var board: ChoppingBoard = $Stations/ChoppingBoard
@onready var pot: Pot = $Stations/Pot
@onready var plating: PlatingStation = $Stations/PlatingStation


func _ready() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room_size.x * scale.x)
	camera.limit_bottom = int(room_size.y * scale.y)
	chef.footstep_sound = "walk_soft"
	board.recipe = recipe
	pot.recipe = recipe
	plating.recipe = recipe
	for station in $Stations.get_children():
		if station is Station:
			station.message.connect(message.emit)
			# Every station message is a "can't do that" hint.
			station.message.connect(func(_text: String) -> void: Audio.sfx("wrong"))
	plating.dish_picked_up.connect(phase_two_complete.emit)
	# Run on its own (F6) there's no main.gd to show the toasts, so show them here.
	if get_tree().current_scene == self:
		var toasts: Notifications = load("res://scenes/notifications.tscn").instantiate()
		add_sibling.call_deferred(toasts)
		message.connect(toasts.notify)
		# Placeholder hand-off, until main.gd / the Phase 3 scene takes over.
		var popup: ModalPopup = load("res://scenes/modal_popup.tscn").instantiate()
		add_sibling.call_deferred(popup)
		phase_two_complete.connect(func(r: Recipe) -> void:
			popup.open("%s is ready!\nDelivering..." % r.dish_name, [], false, 3.0))


## Debug shortcuts (editor/debug builds only) to try the held-item system before the
## stations can hand items over: 1-3 give each recipe ingredient, 4 the pot, 5 the dish,
## 0 empties the hands.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_0:
			holder.drop()
		KEY_1, KEY_2, KEY_3:
			holder.drop()
			holder.hold_ingredient(recipe.ingredient_at(event.keycode - KEY_1))
		KEY_4:
			holder.drop()
			holder.hold_pot()
		KEY_5:
			holder.drop()
			holder.hold_dish(recipe)
