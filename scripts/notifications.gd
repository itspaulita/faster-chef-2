class_name Notifications
extends CanvasLayer
## Short toast banners stacked at the top center of the screen.
##
##   notifications.notify("Teleport unlocked")
##   notifications.notify("A cat stole a potato!", 3.0)
##
## Toasts keep animating while the game is paused. Repeating a message that is already
## showing restarts its timer instead of stacking a duplicate.

const MAX_TOASTS := 4
const MAX_TEXT_WIDTH := 900.0
const FADE_OUT := 0.3

@onready var stack: VBoxContainer = $Stack


func notify(text: String, duration := 2.5) -> void:
	var existing := _find(text)
	if existing:
		existing.modulate.a = 1.0
		_hold_then_fade(existing, duration)
		return

	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast.modulate.a = 0.0
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(label)
	stack.add_child(toast)
	if label.get_minimum_size().x > MAX_TEXT_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = MAX_TEXT_WIDTH

	while stack.get_child_count() > MAX_TOASTS:
		_remove_now(stack.get_child(0))

	_hold_then_fade(toast, duration)
	toast.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	if not is_instance_valid(toast):
		return
	toast.pivot_offset = toast.size / 2.0
	var pop := toast.create_tween().set_parallel()
	pop.tween_property(toast, "modulate:a", 1.0, 0.2)
	pop.tween_property(toast, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _find(text: String) -> PanelContainer:
	for toast: PanelContainer in stack.get_children():
		if not toast.is_queued_for_deletion() and (toast.get_child(0) as Label).text == text:
			return toast
	return null


func _hold_then_fade(toast: PanelContainer, duration: float) -> void:
	if toast.has_meta("hold"):
		(toast.get_meta("hold") as Tween).kill()
	var tween := toast.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(toast.queue_free)
	toast.set_meta("hold", tween)


func _remove_now(toast: Node) -> void:
	stack.remove_child(toast)
	toast.queue_free()
