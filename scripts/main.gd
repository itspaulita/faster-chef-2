extends Node2D
## Holds the current level and connects it to the HUD, notifications and popup.

const LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	# Add level_2, level_3, level_4 here later.
]
## Which HUD row shows which ingredient. Must match the Hud's Ingredient Frames order.
const INGREDIENT_ROWS := { "salmon": 0, "cream": 1, "potato": 2 }

@onready var hud: Hud = $Hud
@onready var notifications: Notifications = $Notifications
@onready var popup: ModalPopup = $ModalPopup

var level_index := 0
var current_level: Node
var carried_xp := 0   # XP kept when moving from Phase 1 to the Phase 2-3 map
var current_recipe: Recipe

func _ready() -> void:
	load_level(0)


func load_level(index: int) -> void:
	level_index = index
	carried_xp = 0
	_show_scene(LEVELS[index])


func next_level() -> void:
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)


func _show_scene(path: String, phase_three := false) -> void:
	if current_level:
		# Remove the old scene right away so its camera doesn't fight the new one.
		remove_child(current_level)
		current_level.queue_free()
	current_level = load(path).instantiate()
	if phase_three:
		# Set BEFORE add_child: that's when the level's _ready() runs.
		current_level.is_phase_three = true
		current_level.start_xp = carried_xp
		current_level.recipe = current_recipe
	add_child(current_level)
	hud.set_points(carried_xp, false)
	if not phase_three:
		_setup_ingredient_bars()   # Phase 3: keep the bars as they were
	_connect_level_signals()


func _setup_ingredient_bars() -> void:
	if not "total_by_type" in current_level:
		return
	# A full bar = every piece of that ingredient in this level.
	for type in INGREDIENT_ROWS:
		var row: int = INGREDIENT_ROWS[type]
		hud.ingredient_goals[row] = current_level.total_by_type.get(type, 0)
		hud.set_ingredient(row, 0, false)


func _connect_level_signals() -> void:
	if current_level.has_signal("xp_changed"):
		current_level.xp_changed.connect(hud.set_points)
	if current_level.has_signal("ingredient_progress"):
		current_level.ingredient_progress.connect(_on_ingredient_progress)
	if current_level.has_signal("message"):
		current_level.message.connect(notifications.notify)
	if current_level.has_signal("exit_opened"):
		current_level.exit_opened.connect(_on_exit_opened)
	if current_level.has_signal("phase_two_complete"):
		current_level.phase_two_complete.connect(_on_phase_two_complete)
	if current_level.has_signal("phase_one_complete"):
		current_level.phase_one_complete.connect(_on_phase_one_complete)
	if current_level.has_signal("countdown_changed"):
		current_level.countdown_changed.connect(_on_countdown_changed)
	if current_level.has_signal("phase_three_complete"):
		current_level.phase_three_complete.connect(_on_phase_three_complete)
	if current_level.has_signal("phase_three_failed"):
		current_level.phase_three_failed.connect(_on_phase_three_failed)

## The chef left the kitchen with the dish: back to this level's map, in Phase 3 mode.
func _on_phase_two_complete(recipe: Recipe) -> void:
	current_recipe = recipe
	_show_scene.call_deferred(LEVELS[level_index], true)

func _on_ingredient_progress(type: String, have: int, _total: int) -> void:
	if INGREDIENT_ROWS.has(type):
		hud.set_ingredient(INGREDIENT_ROWS[type], have)


func _on_exit_opened() -> void:
	popup.open("The wall is open!\nWalk out to the right for Phase 2,\nor keep collecting for bonus XP.", [], false, 5.0)


func _on_phase_one_complete(final_xp: int) -> void:
	carried_xp = final_xp
	var next: String = current_level.next_phase_scene
	if next != "" and ResourceLoader.exists(next):
		# Deferred: we're inside a collision callback, so swap scenes after it.
		_show_scene.call_deferred(next)
	else:
		# No Phase 2-3 map yet: just show the result for a few seconds.
		popup.open("Phase 1 complete!\nXP: %d\n\nPhase 2 coming soon..." % final_xp, [], false, 5.0)

func _on_countdown_changed(seconds_left: int) -> void:
	if hud.has_method("set_countdown"):
		hud.set_countdown(seconds_left)
	else:
		print("Countdown: ", seconds_left)   # until Paula adds a timer to the HUD


## Placeholder: the monster room hand-off and grading (ticket 2.10) replace this.
func _on_phase_three_complete(time_left: float, final_xp: int) -> void:
	popup.open("Delivered!\nTime left: %d s\nXP: %d" % [ceili(time_left), final_xp], [], false, 5.0)


func _on_phase_three_failed() -> void:
	popup.open("Time's up!\nThe monster is still hungry...", ["Try again"])
	popup.closed.connect(func(_i: int) -> void: load_level(level_index), CONNECT_ONE_SHOT)
