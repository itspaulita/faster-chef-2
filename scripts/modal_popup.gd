class_name ModalPopup
extends CanvasLayer
## Reusable modal banner. Dims the screen, blocks input underneath, and (by default)
## pauses the game until a button is pressed.
##
##   popup.open("You have collected enough ingredients!", ["Keep collecting", "Next phase"])
##   var choice: int = await popup.closed   # 0 = first button, -1 = auto-closed

## Emitted when the popup closes. `button_index` is -1 if it auto-closed.
signal closed(button_index: int)

var _open_id := 0
var _paused_by_popup := false

@onready var dim: ColorRect = $Dim
@onready var center: CenterContainer = $Dim/CenterContainer
@onready var banner: PanelContainer = $Dim/CenterContainer/Banner
@onready var message_label: Label = $Dim/CenterContainer/Banner/VBoxContainer/MessageLabel
@onready var button_row: HBoxContainer = $Dim/CenterContainer/Banner/VBoxContainer/ButtonRow


func _ready() -> void:
	hide()


## Shows `text` with one button per entry in `buttons`. With `auto_close` > 0 and no
## buttons, the popup closes itself after that many seconds. `pause_game` freezes the tree
## while it is open.
func open(text: String, buttons: PackedStringArray = ["OK"], pause_game := true, auto_close := 0.0) -> void:
	if visible:
		_close(-1)
	_open_id += 1
	var id := _open_id

	message_label.text = text
	for child in button_row.get_children():
		child.queue_free()
	for i in buttons.size():
		var button := Button.new()
		button.text = buttons[i]
		button.pressed.connect(_close.bind(i))
		button_row.add_child(button)

	_paused_by_popup = pause_game and not get_tree().paused
	if _paused_by_popup:
		get_tree().paused = true
	# Non-pausing popups are just notices: no dimming, and clicks pass through.
	var is_notice := not pause_game and buttons.is_empty()
	dim.color.a = 0.0 if is_notice else 0.5
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_notice else Control.MOUSE_FILTER_STOP
	# Notices sit in the top part of the screen; modal popups stay centered.
	center.anchor_bottom = 0.3 if is_notice else 1.0
	show()
	if button_row.get_child_count() > 0:
		button_row.get_child(0).grab_focus()

	if auto_close > 0.0:
		get_tree().create_timer(auto_close, true).timeout.connect(func() -> void:
			if visible and _open_id == id:
				_close(-1))

	dim.modulate.a = 0.0
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.85, 0.85)
	await get_tree().process_frame
	if _open_id != id:
		return
	banner.pivot_offset = banner.size / 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close(index: int) -> void:
	if not visible:
		return
	hide()
	if _paused_by_popup:
		get_tree().paused = false
		_paused_by_popup = false
	closed.emit(index)
