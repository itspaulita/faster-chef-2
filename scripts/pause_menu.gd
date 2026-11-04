class_name PauseMenu
extends CanvasLayer
## Pause screen: Resume, Back to lobby, Sound on/off, Quit.
## Call open() (the HUD's pause button does). Esc toggles it too.

const LOBBY_SCENE := "res://scenes/choose_chef.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"

signal resumed

@onready var banner: Control = $Dim/CenterContainer/Banner
@onready var resume_button: Button = %ResumeButton
@onready var lobby_button: Button = %LobbyButton
@onready var sound_button: Button = %SoundButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	lobby_button.pressed.connect(_go_to_lobby)
	sound_button.pressed.connect(_toggle_sound)
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
	resumed.emit()


func _go_to_lobby() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _toggle_sound() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	sound_button.text = "SOUND: OFF" if AudioServer.is_bus_mute(0) else "SOUND: ON"


func _quit() -> void:
	get_tree().paused = false
	# Browsers can't close the tab from the game, so the web build returns to the title screen.
	if OS.has_feature("web"):
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		get_tree().quit()
