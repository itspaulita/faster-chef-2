extends Control

const NEXT_SCENE := "res://scenes/choose_chef.tscn"

@onready var start_button: Button = $StartButton
@onready var how_to_play_button: Button = $HowToPlayButton
@onready var how_to_play: HowToPlay = $HowToPlay


func _ready() -> void:
	Audio.music("intro")
	start_button.pressed.connect(_on_start_pressed)
	how_to_play_button.pressed.connect(how_to_play.open)
	add_child(SoundToggles.new())


func _on_start_pressed() -> void:
	if ResourceLoader.exists(NEXT_SCENE):
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		print("Next scene not made yet: ", NEXT_SCENE)
