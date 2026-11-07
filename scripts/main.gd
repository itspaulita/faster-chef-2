extends Node2D
## Holds the current level and connects it to the HUD, notifications and popup.

const ORDER_CUTSCENE := "res://scenes/cutscene.tscn"
## Clock and star thresholds per phase (edit the .tres files to tune them).
const PHASE_TIMINGS := {
	1: preload("res://resources/timing/phase_1.tres"),
	2: preload("res://resources/timing/phase_2.tres"),
	3: preload("res://resources/timing/phase_3.tres"),
}
const TITLE_SCENE := "res://scenes/title_screen.tscn"
## Seconds the "too slow" message shows before the level restarts.
const RESTART_DELAY := 2.0

@onready var hud: Hud = $Hud
@onready var notifications: Notifications = $Notifications
@onready var popup: ModalPopup = $ModalPopup

var tally: ScoreTally
var delivery_cutscene: DeliveryCutscene
## Which HUD row shows which ingredient, from the level's LevelInfo: { "beef": 0, ... }.
var ingredient_rows := {}
var level_index := 0
var current_phase := 0   # 1, 2 or 3 while a timed phase is showing, 0 otherwise
var current_level: Node
var carried_xp := 0      # XP kept between phases
var current_recipe: Recipe


func _ready() -> void:
	hud.star_lost.connect(_on_star_lost)
	hud.timed_out.connect(_on_timed_out)
	tally = preload("res://scenes/score_tally.tscn").instantiate()
	# The tally shows over the (paused) delivery cutscene, so it has to keep running.
	tally.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tally)
	tally.continue_pressed.connect(_on_tally_continue)
	load_level(GameState.level_index)


func load_level(index: int) -> void:
	level_index = index
	GameState.level_index = index
	carried_xp = 0
	current_recipe = null
	GameState.reset_run()
	# One music track per level (level-1 ... level-3).
	Audio.music("level-%d" % mini(index + 1, 3))
	var info := Levels.info(index)
	hud.set_ingredient_frames(info.ingredient_frames)
	ingredient_rows = {}
	for row in info.ingredient_types.size():
		ingredient_rows[info.ingredient_types[row]] = row
	_show_scene(info.level_scene)


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
		hud.start_timer(_timing_for(current_phase))
	else:
		hud.hide_timer()


## This level's own clock for a phase if its LevelInfo has one, else the default.
func _timing_for(phase: int) -> PhaseTiming:
	var own := Levels.info(level_index).phase_timings
	if phase - 1 < own.size() and own[phase - 1] != null:
		return own[phase - 1]
	return PHASE_TIMINGS[phase]


func _setup_ingredient_bars() -> void:
	if not "total_by_type" in current_level:
		return
	# A full bar = every piece of that ingredient in this level.
	for type in ingredient_rows:
		var row: int = ingredient_rows[type]
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
	if ingredient_rows.has(type):
		hud.set_ingredient(ingredient_rows[type], have)


func _on_exit_opened() -> void:
	popup.open("The wall is open!\nWalk out to the right for Phase 2,\nor keep collecting for bonus XP.", [], false, 5.0)


func _on_star_lost(stars_left: int) -> void:
	if stars_left > 0:
		notifications.notify("Too slow! You lost a star. %d left." % stars_left)


## A phase ran out of time (0 stars): the whole level starts over.
func _on_timed_out() -> void:
	Audio.sfx("lose")
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
	_show_scene.call_deferred(Levels.info(level_index).level_scene, true)


## A cat hit the chef in Phase 3: take seconds off the HUD clock (stars can drop too).
func _on_time_penalty(seconds: float) -> void:
	hud.phase_timer.advance(seconds)


## The dish was delivered: record Phase 3's stars, play the delivery cutscene
## (monster reaction), then show the tally of all 3 phases on top of it.
func _on_phase_three_complete(final_xp: int) -> void:
	GameState.record_stars(3, hud.stop_timer())
	carried_xp = final_xp
	# The cutscene picks this level's monsters and dish from its LevelInfo by itself.
	delivery_cutscene = preload("res://scenes/delivery_cutscene.tscn").instantiate()
	add_child(delivery_cutscene)
	await delivery_cutscene.finished
	# The cutscene stays up behind the tally as its background.
	Audio.sfx("win")
	tally.show_tally(final_xp)


func _on_tally_continue() -> void:
	if is_instance_valid(delivery_cutscene):
		delivery_cutscene.close()
	if level_index + 1 < Levels.count():
		# Next level: its order cutscene first, then main loads the level.
		GameState.level_index = level_index + 1
		get_tree().change_scene_to_file(ORDER_CUTSCENE)
	elif ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)
