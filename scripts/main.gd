extends Node2D
## Holds the current level. Loads, restarts and switches levels.
@onready var score_label: Label = $HUD/Score_Placeholder/Score_label ## Placeholder

@onready var message_placeholder: Label = $HUD/Message_Placeholder ## Placeholder
var message_count := 0

const LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	# Add level_2, level_3, level_4 here later.
]

var level_index := 0
var current_level: Node


func _ready() -> void:
	load_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_placeholder"):
		restart_level()


func load_level(index: int) -> void:
	if current_level:
		# Remove the old level right away so its camera doesn't fight the new one.
		remove_child(current_level)
		current_level.queue_free()
	level_index = index
	current_level = load(LEVELS[index]).instantiate()
	add_child(current_level)
	_update_score(0)
	if current_level.has_signal("xp_changed"):
		current_level.xp_changed.connect(_update_score)
	message_placeholder.text = ""     # ← only runs if the level has XP
	if current_level.has_signal("message"):
		current_level.message.connect(_show_message)


func restart_level() -> void:
	load_level(level_index)


func next_level() -> void:
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)

func _update_score(total_xp: int) -> void:
	score_label.text = "XP: %d" % total_xp
	
func _show_message(text: String) -> void:
	message_count += 1
	var my_count := message_count
	message_placeholder.text = text
	await get_tree().create_timer(2.5).timeout
	# Only clear it if no newer message replaced this one.
	if my_count == message_count:
		message_placeholder.text = ""
