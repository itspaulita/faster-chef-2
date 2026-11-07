extends Node2D
## Holds the current level and connects it to the HUD, notifications and popup.

const LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]
## Clock and star thresholds per phase (edit the .tres files to tune them).
const PHASE_TIMINGS := {
	1: preload("res://resources/timing/phase_1.tres"),
	2: preload("res://resources/timing/phase_2.tres"),
	3: preload("res://resources/timing/phase_3.tres"),
}
const TITLE_SCENE := "res://scenes/title_screen.tscn"
## Seconds the "too slow" message shows before the level restarts.
const RESTART_DELAY := 2.0
## Which HUD row shows which ingredient. Must match the Hud's Ingredient Frames order.
const INGREDIENT_ROWS := { "salmon": 0, "cream": 1, "potato": 2 }

@onready var hud: Hud = $Hud
@onready var notifications: Notifications = $Notifications
@onready var popup: ModalPopup = $ModalPopup

var tally: ScoreTally
var level_index := 0
var current_phase := 0   # 1, 2 or 3 while a timed phase is showing, 0 otherwise
var current_level: Node
var carried_xp := 0      # XP kept between phases
var current_recipe: Recipe


func _ready() -> void:
	hud.star_lost.connect(_on_star_lost)
	hud.timed_out.connect(_on_timed_out)
	tally = preload("res://scenes/score_tally.tscn").instantiate()
	add_child(tally)
	tally.continue_pressed.connect(_on_tally_continue)
	load_level(0)


func load_level(index: int) -> void:
	level_index = index
	carried_xp = 0
	current_recipe = null
	GameState.reset_run()
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
	# Set BEFORE add_child: that's when the scene's _ready() runs.
	if current_recipe and "recipe" in current_level:
		current_level.recipe = current_recipe   # the kitchen cooks this level's dish
	if phase_three:
		current_level.is_phase_three = true
		current_level.start_xp = carried_xp
	add_child(current_level)
	hud.set_points(carried_xp, false)
	if not phase_three:
		_setup_ingredient_bars()   # Phase 3: keep the bars as they were
	_connect_level_signals()
	# Each timed phase has its own clock. Phase 3 reuses the Phase 1 map, so check it first.
	current_phase = 0
	if phase_three:
		current_phase = 3
	elif current_level.has_signal("phase_one_complete"):
		current_phase = 1
	elif current_level.has_signal("phase_two_complete"):
		current_phase = 2
	if current_phase > 0:
		hud.start_timer(PHASE_TIMINGS[current_phase])
	else:
		hud.hide_timer()


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
	if current_level.has_signal("time_penalty"):
		current_level.time_penalty.connect(_on_time_penalty)
	if current_level.has_signal("phase_three_complete"):
		current_level.phase_three_complete.connect(_on_phase_three_complete)


func _on_ingredient_progress(type: String, have: int, _total: int) -> void:
	if INGREDIENT_ROWS.has(type):
		hud.set_ingredient(INGREDIENT_ROWS[type], have)


func _on_exit_opened() -> void:
	popup.open("The wall is open!\nWalk out to the right for Phase 2,\nor keep collecting for bonus XP.", [], false, 5.0)


func _on_star_lost(stars_left: int) -> void:
	if stars_left > 0:
		notifications.notify("Too slow! You lost a star. %d left." % stars_left)


## A phase ran out of time (0 stars): the whole level starts over.
func _on_timed_out() -> void:
	notifications.notify("Out of time! Restarting the level...", RESTART_DELAY)
	var index := level_index
	await get_tree().create_timer(RESTART_DELAY).timeout
	if index == level_index:
		load_level(level_index)


func _on_phase_one_complete(final_xp: int) -> void:
	GameState.record_stars(1, hud.stop_timer())
	carried_xp = final_xp
	current_recipe = current_level.recipe
	var next: String = current_level.next_phase_scene
	if next != "" and ResourceLoader.exists(next):
		# Deferred: we're inside a collision callback, so swap scenes after it.
		_show_scene.call_deferred(next)
	else:
		# No Phase 2-3 map yet: just show the result for a few seconds.
		popup.open("Phase 1 complete!\nXP: %d   Stars: %d\n\nPhase 2 coming soon..." % [final_xp, GameState.phase_stars[1]], [], false, 5.0)


## The chef left the kitchen with the dish: back to this level's map, in Phase 3 mode.
func _on_phase_two_complete(recipe: Recipe) -> void:
	GameState.record_stars(2, hud.stop_timer())
	current_recipe = recipe
	_show_scene.call_deferred(LEVELS[level_index], true)


## A cat hit the chef in Phase 3: take seconds off the HUD clock (stars can drop too).
func _on_time_penalty(seconds: float) -> void:
	hud.phase_timer.advance(seconds)


## The dish was delivered: record Phase 3's stars and show the tally of all 3 phases.
func _on_phase_three_complete(final_xp: int) -> void:
	GameState.record_stars(3, hud.stop_timer())
	carried_xp = final_xp
	tally.show_tally(final_xp)


func _on_tally_continue() -> void:
	if level_index + 1 < LEVELS.size():
		next_level()
	elif ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)
