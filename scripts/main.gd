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


func _ready() -> void:
	load_level(0)


func load_level(index: int) -> void:
	level_index = index
	carried_xp = 0
	_show_scene(LEVELS[index])


func next_level() -> void:
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)


func _show_scene(path: String) -> void:
	if current_level:
		# Remove the old scene right away so its camera doesn't fight the new one.
		remove_child(current_level)
		current_level.queue_free()
	current_level = load(path).instantiate()
	add_child(current_level)
	hud.set_points(carried_xp, false)
	_setup_ingredient_bars()
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
	if current_level.has_signal("phase_one_complete"):
		current_level.phase_one_complete.connect(_on_phase_one_complete)


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
