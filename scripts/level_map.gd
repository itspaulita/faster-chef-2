extends Control
## Level map between levels (Candy Crush style): one button per level on a path.
## Opens the popup of the newest level; after a level is won it first plays the unlock
## animation on the next one. Run on its own (F6) to preview.

const ORDER_CUTSCENE := "res://scenes/cutscene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const FONT := preload("res://assets/font/RetroGaming.ttf")
const INK := Color(0.17, 0.09, 0.06)
const OUTLINE := Color(0.23, 0.12, 0.08)
const DONE_COLOR := Color(0.12, 0.45, 0.45)     # finished levels
const OPEN_COLOR := Color(0.91, 0.6, 0.17)      # unlocked, not finished yet
const LOCKED_COLOR := Color(0.6, 0.6, 0.62)
const NODE_SIZE := 150.0
const POPUP_SIZE := 800.0       # the popup is always this square
const MONSTER_FRAMES := [0, 1, 2, 3]   # same idle loop as the order cutscene

## Centre of each level button on the 1920x1080 screen, in level order. Move them here.
@export var node_positions: Array[Vector2] = [Vector2(420, 760), Vector2(960, 470), Vector2(1500, 760)]

var _buttons: Array[Button] = []
var _locks: Array[Control] = []
var _path_fill: Line2D
var _popup: Control
var _busy := false   # true while the unlock animation plays (clicks are ignored)


func _ready() -> void:
	Audio.music("intro")
	var newly := GameState.just_unlocked
	GameState.just_unlocked = -1
	# The path is filled up to the last unlocked level (or one before the one about to unlock).
	_build_path(newly - 1 if newly > 0 else GameState.unlocked_level)
	for i in Levels.count():
		_build_level_node(i, i > GameState.unlocked_level or i == newly)
	if newly > 0:
		await _play_unlock(newly)
	if GameState.game_complete:
		_open_finished_popup()
	else:
		_open_popup(GameState.unlocked_level)
	add_child(SoundToggles.new())


# ---- Map ------------------------------------------------------------------------------

func _build_path(filled_to: int) -> void:
	var base := Line2D.new()
	base.points = PackedVector2Array(node_positions)
	base.width = 28
	base.default_color = Color(0.23, 0.12, 0.08, 0.45)
	add_child(base)
	_path_fill = Line2D.new()
	_path_fill.width = 16
	_path_fill.default_color = OPEN_COLOR
	_path_fill.points = PackedVector2Array(node_positions.slice(0, filled_to + 1))
	add_child(_path_fill)


func _build_level_node(i: int, locked: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size = button.custom_minimum_size
	button.position = node_positions[i] - button.size / 2.0
	button.pivot_offset = button.size / 2.0
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 72)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.pressed.connect(_on_level_pressed.bind(i))
	add_child(button)
	_buttons.append(button)

	var lock := LockIcon.new()
	lock.position = button.size / 2.0 - lock.size / 2.0
	button.add_child(lock)
	_locks.append(lock)

	if GameState.level_results.has(i):
		button.add_child(_stars_row(GameState.level_results[i].stars))
	_style_level(i, locked)


## Colors the button: grey + lock when locked, orange when open, teal when finished.
func _style_level(i: int, locked: bool) -> void:
	var button := _buttons[i]
	var color := LOCKED_COLOR
	if not locked:
		color = DONE_COLOR if GameState.level_results.has(i) else OPEN_COLOR
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.15) if state in ["hover", "focus"] else color
		box.set_border_width_all(8)
		box.border_color = OUTLINE
		box.set_corner_radius_all(20)
		button.add_theme_stylebox_override(state, PixelUI.from_flat(box))
	button.text = "" if locked else str(i + 1)
	_locks[i].visible = locked


## Under a finished level: a star and "7/9".
func _stars_row(stars: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, NODE_SIZE + 6)
	row.size = Vector2(NODE_SIZE, 48)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := StarIcon.new(40)
	star.set_earned(true, false)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(star)
	row.add_child(_label("%d/%d" % [stars, GameState.PHASE_COUNT * GameState.MAX_STARS], 32, INK))
	return row


func _on_level_pressed(i: int) -> void:
	if _busy:
		return
	if i > GameState.unlocked_level:
		# Locked: the lock wiggles "no".
		Audio.sfx("wrong")
		var tween := create_tween()
		for k in 4:
			tween.tween_property(_locks[i], "rotation", 0.3 if k % 2 == 0 else -0.3, 0.05)
		tween.tween_property(_locks[i], "rotation", 0.0, 0.05)
		return
	Audio.sfx("click")
	_open_popup(i)


## The path fills in, the lock shakes, pops and fades, then the level lights up and bounces.
func _play_unlock(i: int) -> void:
	_busy = true
	var lock := _locks[i]
	var button := _buttons[i]
	var tween := create_tween()
	tween.tween_interval(0.4)
	# 1. The path from the previous level grows to this one.
	_path_fill.add_point(node_positions[i - 1])
	var last := _path_fill.get_point_count() - 1
	tween.tween_method(func(p: Vector2) -> void: _path_fill.set_point_position(last, p),
			node_positions[i - 1], node_positions[i], 0.8)
	# 2. The lock shakes.
	for k in 6:
		tween.tween_property(lock, "rotation", 0.3 if k % 2 == 0 else -0.3, 0.06)
	tween.tween_property(lock, "rotation", 0.0, 0.06)
	# 3. It pops and fades out.
	tween.tween_callback(Audio.sfx.bind("star"))
	tween.tween_property(lock, "scale", Vector2(1.8, 1.8), 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lock, "modulate:a", 0.0, 0.2)
	# 4. The level lights up and bounces.
	tween.tween_callback(_style_level.bind(i, false))
	tween.tween_callback(Audio.sfx.bind("score"))
	tween.tween_property(button, "scale", Vector2(1.3, 1.3), 0.12)
	tween.tween_property(button, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	await tween.finished
	_busy = false


# ---- Popups ---------------------------------------------------------------------------

func _open_popup(i: int) -> void:
	var info := Levels.info(i)
	var box := _new_popup("LEVEL %d" % (i + 1))
	# The monster(s), animated like in the order cutscene. Two monsters are drawn a bit smaller.
	var monsters := HBoxContainer.new()
	monsters.alignment = BoxContainer.ALIGNMENT_CENTER
	monsters.add_theme_constant_override("separation", 20)
	var pair := info.monsters.size() > 1
	for m in info.monsters.size():
		monsters.add_child(_monster_view(info.monsters[m], 220.0 if pair else 280.0, m * 0.15))
	box.add_child(monsters)
	var waiting := _label(_waiting_text(info), 32, INK)
	waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(waiting)
	if GameState.level_results.has(i):
		var best: Dictionary = GameState.level_results[i]
		box.add_child(_label("LAST: %d/9 STARS   %d PTS" % [best.stars, best.score], 28, DONE_COLOR))
	# Ticket 3.2 puts this chef's leaderboard for this level here.
	box.add_child(_label("LEADERBOARD COMING SOON", 24, Color(INK, 0.5)))
	var close := _button("CLOSE")
	close.pressed.connect(_close_popup)
	var start := _button("START")
	start.pressed.connect(_start_level.bind(i))
	box.add_child(_button_row([close, start]))
	start.grab_focus()


## "JGPiNE is waiting to order..." / "Mishapple and Tomate-o are waiting to order..."
func _waiting_text(info: LevelInfo) -> String:
	var names := info.monster_names
	if names.is_empty():
		return "A hungry monster is waiting to order..."
	if names.size() == 1:
		return "%s is waiting to order..." % names[0]
	var first := ", ".join(names.slice(0, names.size() - 1))
	return "%s and %s are waiting to order..." % [first, names[names.size() - 1]]


func _open_finished_popup() -> void:
	var box := _new_popup("ALL LEVELS DONE!")
	box.add_child(_label("TOTAL  %d PTS" % GameState.game_score(), 40, DONE_COLOR))
	var close := _button("CLOSE")
	close.pressed.connect(_close_popup)
	var results := _button("RESULTS")
	results.pressed.connect(func() -> void:
		GameState.game_complete = false
		get_tree().change_scene_to_file(GAME_OVER_SCENE))
	box.add_child(_button_row([close, results]))
	results.grab_focus()


func _start_level(i: int) -> void:
	Audio.sfx("click")
	GameState.level_index = i
	get_tree().change_scene_to_file(ORDER_CUTSCENE)


## Dims the map and shows the square pixel panel, fixed size, in the middle of the screen.
## Returns its content box.
func _new_popup(title: String) -> VBoxContainer:
	_close_popup()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_popup = dim
	# A plain Panel (not a PanelContainer), so the content can never resize or move it.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", PixelUI.panel(Color(1, 0.97, 0.88), OUTLINE, 8, 20, 0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -POPUP_SIZE / 2.0
	panel.offset_top = -POPUP_SIZE / 2.0
	panel.offset_right = POPUP_SIZE / 2.0
	panel.offset_bottom = POPUP_SIZE / 2.0
	panel.pivot_offset = Vector2(POPUP_SIZE, POPUP_SIZE) / 2.0
	dim.add_child(panel)
	# The content fills the panel, minus a margin.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 40
	box.offset_right = -48
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	box.add_child(_label(title, 64, INK))
	# Fade in, with a small pop.
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box


func _close_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


# ---- Small helpers --------------------------------------------------------------------

## An animated monster (the same IdleChef loop as the order cutscene), sized to `size_px`.
## Sprites can't sit in containers, so it's wrapped in a Control of that size.
func _monster_view(texture: Texture2D, size_px: float, delay: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size_px, size_px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := IdleChef.new()
	sprite.texture = texture
	sprite.hframes = 2
	sprite.vframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.idle_frames = PackedInt32Array(MONSTER_FRAMES)
	sprite.frame_time = 0.3
	sprite.start_delay = delay   # two monsters don't move in sync
	sprite.position = Vector2(size_px, size_px) / 2.0
	sprite.scale = Vector2.ONE * (size_px / (texture.get_width() / 2.0))
	holder.add_child(sprite)
	return holder


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Same orange button as the game over screen (PixelSkin gives it the pixel corners).
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 36)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.97, 0.71, 0.28) if state in ["hover", "focus"] else OPEN_COLOR
		box.set_border_width_all(6)
		box.border_color = OUTLINE
		box.set_corner_radius_all(10)
		box.content_margin_left = 40
		box.content_margin_right = 40
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, box)
	return button


func _button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 30)
	for b in buttons:
		row.add_child(b)
	return row


## A padlock drawn with shapes (no image needed).
class LockIcon extends Control:
	func _init() -> void:
		size = Vector2(64, 78)
		pivot_offset = size / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := Color(0.23, 0.12, 0.08)
		draw_arc(Vector2(32, 34), 18, PI, TAU, 16, ink, 8)          # shackle
		draw_line(Vector2(14, 34), Vector2(14, 42), ink, 8)
		draw_line(Vector2(50, 34), Vector2(50, 42), ink, 8)
		draw_rect(Rect2(4, 40, 56, 38), Color(0.98, 0.8, 0.3))      # body
		draw_rect(Rect2(4, 40, 56, 38), ink, false, 6)
		draw_rect(Rect2(28, 50, 8, 16), ink)                         # keyhole
