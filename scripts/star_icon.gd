class_name StarIcon
extends TextureRect
## One star from Star.png (13 frames of 32px: the plain star, then sparkle frames).
## Earned stars are bright, lost ones are dimmed. play_sparkle() runs the sparkle animation.

const SHEET := preload("res://assets/images/misc/Star.png")
const FRAME_SIZE := 32
const FRAME_COUNT := 13
const LOST_COLOR := Color(0.2, 0.2, 0.25, 0.55)

var earned := true

var _atlas := AtlasTexture.new()


func _init(size_px := 48) -> void:
	_atlas.atlas = SHEET
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(size_px, size_px)
	_show_frame(0)
	resized.connect(func() -> void: pivot_offset = size / 2.0)


## Bright when earned, dim when lost. `animate` pops the star as it changes.
func set_earned(value: bool, animate := true) -> void:
	earned = value
	modulate = Color.WHITE if value else LOST_COLOR
	if animate:
		var from := Vector2(1.4, 1.4) if value else Vector2(0.6, 0.6)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3) \
				.from(from).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Plays the sparkle frames once, then rests on the plain star.
func play_sparkle(duration := 0.9) -> Tween:
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void: _show_frame(int(f)), 0.0, float(FRAME_COUNT), duration)
	tween.tween_callback(_show_frame.bind(0))
	return tween


func _show_frame(frame: int) -> void:
	_atlas.region = Rect2(clampi(frame, 0, FRAME_COUNT - 1) * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
