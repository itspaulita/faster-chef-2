class_name HowToPlay
extends CanvasLayer
## "How to play" panel: the three phases and the controls. Opened from the title screen.
## Closes with the button, Esc, or a click outside the panel.

@onready var close_button: Button = %CloseButton
@onready var banner: Control = %Banner


func _ready() -> void:
	hide()
	close_button.pressed.connect(close)
	banner.resized.connect(func(): banner.pivot_offset = banner.size / 2.0)


func open() -> void:
	show()
	close_button.grab_focus()
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.2) \
			.from(Vector2(0.9, 0.9)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
