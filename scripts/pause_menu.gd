class_name PauseMenu
extends CanvasLayer
## Pause screen: Resume, Restart level, Back to level map, Back to lobby, Music / SFX on/off, Quit.
## Call open() (the HUD's pause button does). Esc toggles it too.

const LOBBY_SCENE := "res://scenes/choose_chef.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const LEVEL_MAP_SCENE := "res://scenes/level_map.tscn"

signal resumed
## Emitted just before the level is reloaded, in case something outside the scene needs resetting.
signal restart_requested

@onready var banner: Control = $Dim/CenterContainer/Banner
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var map_button: Button = %MapButton
@onready var lobby_button: Button = %LobbyButton
@onready var music_button: Button = %MusicButton
@onready var sfx_button: Button = %SfxButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(_restart_level)
	map_button.pressed.connect(_go_to_level_map)
	lobby_button.pressed.connect(_go_to_lobby)
	music_button.pressed.connect(Audio.toggle_mute.bind(Audio.MUSIC_BUS))
	sfx_button.pressed.connect(Audio.toggle_mute.bind(Audio.SFX_BUS))
	Audio.mute_changed.connect(_refresh_sound_text)
	quit_button.pressed.connect(_quit)
	_refresh_sound_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	Audio.sfx("pause")
	_refresh_sound_text()
	resume_button.grab_focus()
	await get_tree().process_frame
	banner.pivot_offset = banner.size / 2.0
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.2) \
			.from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Audio.sfx("unpause")
	resumed.emit()


## Reloads the current scene, so anything living in the level (HUD, cats, pieces, chef) starts fresh.
func _restart_level() -> void:
	restart_requested.emit()
	get_tree().paused = false
	get_tree().reload_current_scene()

## Leaves the level without finishing it (nothing is saved or unlocked) and goes back to the map.
func _go_to_level_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_MAP_SCENE)

func _go_to_lobby() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _refresh_sound_text() -> void:
	music_button.text = "MUSIC: OFF" if Audio.is_muted(Audio.MUSIC_BUS) else "MUSIC: ON"
	sfx_button.text = "SFX: OFF" if Audio.is_muted(Audio.SFX_BUS) else "SFX: ON"

func _quit() -> void:
	get_tree().paused = false
	# Browsers can't close the tab from the game, so the web build returns to the title screen.
	if OS.has_feature("web"):
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		get_tree().quit()
