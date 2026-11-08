extends Control
## Level map between levels (Candy Crush style): the pictures under Levels, joined by a path.
## Opens the popup of the newest level; after a level is won it first plays the unlock
## animation on the next one. Run on its own (F6) to preview.

const ORDER_CUTSCENE := "res://scenes/cutscene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const FONT := preload("res://assets/font/RetroGaming.ttf")
const INK := Color(0.17, 0.09, 0.06)
const OUTLINE := Color(0.23, 0.12, 0.08)
const DONE_COLOR := Color(0.12, 0.45, 0.45)     # finished levels
const OPEN_COLOR := Color(0.91, 0.6, 0.17)      # unlocked, not finished yet
const POPUP_SIZE := 800.0       # the popup is always this square
const MONSTER_FRAMES := [0, 1, 2, 3]   # same idle loop as the order cutscene
const CHOOSE_CHEF_SCENE := "res://scenes/choose_chef.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const GRAY_SHADER := preload("res://shaders/grayscale.gdshader")
const HOVER_SCALE := 1.08
const NOTIFICATIONS_SCENE := preload("res://scenes/notifications.tscn")

@onready var levels_node: Node2D = $Levels

var _levels: Array[Sprite2D] = []      # the pictures under Levels, in level order
var _base_scales: Array[Vector2] = []  # their scale from the editor (hover/bounce return to it)
var _hovered := -1
var _path_fill: Line2D
var _popup: Control
var _busy := false   # true while the unlock animation plays (clicks are ignored)
var _menu_button: Button
var _menu_panel: PanelContainer
var _music_item: Button
var _sfx_item: Button
var _notifications: Notifications
var _numbers: Array[Label] = []


func _ready() -> void:
	Audio.music("intro")
	_build_menu()
	_notifications = NOTIFICATIONS_SCENE.instantiate()
	add_child(_notifications)
	var newly := GameState.just_unlocked
	GameState.just_unlocked = -1
	_build_levels(newly)
	# The path is filled up to the last unlocked level (or one before the one about to unlock).
	_build_path(newly - 1 if newly > 0 else GameState.unlocked_level)
	if newly > 0:
		await _play_unlock(newly)
	if not GameState.new_chefs.is_empty():
		await _show_new_chefs()
	if GameState.game_complete:
		_open_finished_popup()
	else:
		_open_popup(GameState.unlocked_level)


# ---- Map ------------------------------------------------------------------------------

## Reads the pictures under Levels. Locked ones (and the one about to unlock) are grey.
func _build_levels(newly: int) -> void:
	for child in levels_node.get_children():
		if child is Sprite2D:
			_levels.append(child)
			_base_scales.append(child.scale)
	for i in _levels.size():
		var number := _number_label(i)
		add_child(number)
		_numbers.append(number)
		if i > GameState.unlocked_level or i == newly:
			var gray := ShaderMaterial.new()
			gray.shader = GRAY_SHADER
			gray.set_shader_parameter("amount", 1.0)
			_levels[i].material = gray
			number.modulate = Color(0.6, 0.6, 0.6)   # grey with its level
		if GameState.level_results.has(i):
			add_child(_stars_row(i))

## The big level number in the middle of a picture (drawn above it, ignores the mouse).
func _number_label(i: int) -> Label:
	var label := Label.new()
	label.text = str(i + 1)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 160)
	label.position = _level_pos(i) - label.size / 2.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _level_pos(i: int) -> Vector2:
	return _levels[i].global_position


## A faint line through every level, and a colored one up to `filled_to`. Both sit behind
## the pictures.
func _build_path(filled_to: int) -> void:
	var points := PackedVector2Array()
	for i in _levels.size():
		points.append(_level_pos(i))
	var base := Line2D.new()
	base.points = points
	base.width = 28
	base.default_color = Color(0.23, 0.12, 0.08, 0.45)
	add_child(base)
	move_child(base, levels_node.get_index())
	_path_fill = Line2D.new()
	_path_fill.width = 16
	_path_fill.default_color = OPEN_COLOR
	_path_fill.points = points.slice(0, filled_to + 1)
	add_child(_path_fill)
	move_child(_path_fill, levels_node.get_index())


## Under a finished level: a star and "7/9".
func _stars_row(i: int) -> HBoxContainer:
	var level := _levels[i]
	var half := level.get_rect().size * level.scale / 2.0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size = Vector2(240, 48)
	row.position = _level_pos(i) + Vector2(-row.size.x / 2.0, half.y + 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := StarIcon.new(40)
	star.set_earned(true, false)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(star)
	var stars: int = GameState.level_results[i].stars
	row.add_child(_label("%d/%d" % [stars, GameState.PHASE_COUNT * GameState.MAX_STARS], 32, INK))
	return row


## Clicks and hovers on the map itself (popups sit on top and catch their own clicks).
func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseMotion:
		_set_hovered(_level_at(event.global_position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _level_at(event.global_position)
		if i >= 0:
			_on_level_pressed(i)


func _level_at(pos: Vector2) -> int:
	for i in _levels.size():
		if _levels[i].get_rect().has_point(_levels[i].to_local(pos)):
			return i
	return -1


## The level under the mouse grows a little, and the cursor becomes a hand.
func _set_hovered(i: int) -> void:
	if i == _hovered:
		return
	if _hovered >= 0:
		create_tween().tween_property(_levels[_hovered], "scale", _base_scales[_hovered], 0.1)
	_hovered = i
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i >= 0 else Control.CURSOR_ARROW
	if i >= 0:
		create_tween().tween_property(_levels[i], "scale", _base_scales[i] * HOVER_SCALE, 0.1)


func _on_level_pressed(i: int) -> void:
	_set_hovered(-1)
	if i > GameState.unlocked_level:
		Audio.sfx("wrong")
		_notifications.notify("Level %d is not unlocked yet! Finish Level %d first." % [i + 1, i])
		return
	Audio.sfx("click")
	_open_popup(i)


func _set_gray(amount: float, i: int) -> void:
	var gray := _levels[i].material as ShaderMaterial
	if gray:
		gray.set_shader_parameter("amount", amount)


## The path grows to the level, it shakes, the color floods back in, then it bounces.
func _play_unlock(i: int) -> void:
	_busy = true
	var level := _levels[i]
	var tween := create_tween()
	tween.tween_interval(0.4)
	# 1. The path from the previous level grows to this one.
	_path_fill.add_point(_level_pos(i - 1))
	var last := _path_fill.get_point_count() - 1
	tween.tween_method(func(p: Vector2) -> void: _path_fill.set_point_position(last, p),
			_level_pos(i - 1), _level_pos(i), 0.8)
	# 2. The grey level shakes.
	for k in 6:
		tween.tween_property(level, "rotation", 0.12 if k % 2 == 0 else -0.12, 0.06)
	tween.tween_property(level, "rotation", 0.0, 0.06)
	# 3. Its color comes back.
	tween.tween_callback(Audio.sfx.bind("star"))
	tween.tween_method(_set_gray.bind(i), 1.0, 0.0, 0.4)
	tween.parallel().tween_property(_numbers[i], "modulate", Color.WHITE, 0.4)
	# 4. It bounces.
	tween.tween_callback(Audio.sfx.bind("score"))
	tween.tween_property(level, "scale", _base_scales[i] * 1.3, 0.12)
	tween.tween_property(level, "scale", _base_scales[i], 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	await tween.finished
	level.material = null
	_busy = false

# ---- Menu (top left) ------------------------------------------------------------------

## MENU button with a dropdown: Back to lobby, Music, SFX, Quit. It's on its own layer,
## so it stays clickable over the level popups.
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40   # above the popups, under the sound buttons (50)
	add_child(layer)

	_menu_button = _button("MENU", 32)
	_menu_button.position = Vector2(24, 24)
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.pressed.connect(_toggle_menu)
	layer.add_child(_menu_button)

	_menu_panel = PanelContainer.new()
	_menu_panel.add_theme_stylebox_override("panel", PixelUI.panel(Color(1, 0.97, 0.88), OUTLINE, 8, 20, 20))
	_menu_panel.position = Vector2(24, 110)
	_menu_panel.visible = false
	layer.add_child(_menu_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(list)
	list.add_child(_menu_item("BACK TO LOBBY", _back_to_lobby))
	_music_item = _menu_item("", Audio.toggle_mute.bind(Audio.MUSIC_BUS))
	list.add_child(_music_item)
	_sfx_item = _menu_item("", Audio.toggle_mute.bind(Audio.SFX_BUS))
	list.add_child(_sfx_item)
	list.add_child(_menu_item("QUIT", _quit))

	Audio.mute_changed.connect(_refresh_menu)
	_refresh_menu()


func _menu_item(text: String, action: Callable) -> Button:
	var item := _button(text, 28)
	item.focus_mode = Control.FOCUS_NONE   # Enter keeps pressing the popup's START
	item.pressed.connect(action)
	return item


func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible


func _refresh_menu() -> void:
	_music_item.text = "MUSIC: OFF" if Audio.is_muted(Audio.MUSIC_BUS) else "MUSIC: ON"
	_sfx_item.text = "SFX: OFF" if Audio.is_muted(Audio.SFX_BUS) else "SFX: ON"


## Clicking anywhere outside the open menu (or Esc) closes it.
func _input(event: InputEvent) -> void:
	if not _menu_panel or not _menu_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_menu_panel.visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if not _menu_panel.get_global_rect().has_point(pos) \
				and not _menu_button.get_global_rect().has_point(pos):
			_menu_panel.visible = false


## Same as the pause menu: browsers can't close the tab, so the web build goes to the title.
func _quit() -> void:
	if OS.has_feature("web"):
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		get_tree().quit()


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
	var close := _button("CLOSE")
	close.pressed.connect(_close_popup)
	var start := _button("START")
	start.pressed.connect(_start_level.bind(i))
	box.add_child(_button_row([close, start]))
	start.grab_focus()


## Choose chef, keeping the level progress (Play there comes back to this map).
func _back_to_lobby() -> void:
	GameState.changing_chef = true
	get_tree().change_scene_to_file(CHOOSE_CHEF_SCENE)


## "NEW CHEF!" with the chef(s) the last level unlocked. Returns when the player presses OK.
func _show_new_chefs() -> void:
	var count := GameState.new_chefs.size()
	var box := _new_popup("NEW CHEF!" if count == 1 else "NEW CHEFS!")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	for id in GameState.new_chefs:
		var column := VBoxContainer.new()
		column.add_child(_chef_view(id, 260.0 if count == 1 else 220.0))
		column.add_child(_label(ChefStats.get_stats(id).name, 28, INK))
		column.add_child(_label(ChefStats.get_stats(id).ability, 22, DONE_COLOR))
		row.add_child(column)
	box.add_child(row)
	var note := _label("Switch chef from MENU > BACK TO LOBBY.", 26, INK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var ok := _button("NICE!")
	box.add_child(_button_row([ok]))
	ok.grab_focus()
	Audio.sfx("win")
	GameState.new_chefs.clear()
	await ok.pressed

## "JGPiNE is waiting to order..." / "Mishapple and Tomate-o are waiting to order..."
func _waiting_text(info: LevelInfo) -> String:
	var names := info.monster_names
	if names.is_empty():
		return "A hungry monster is waiting to order..."
	if names.size() == 1:
		return "%s is waiting to order..." % names[0]
	var first := ", ".join(names.slice(0, names.size() - 1))
	return "%s and %s are waiting to order..." % [first, names[names.size() - 1]]


## After the last level: each level's stars and points, one row at a time, then the total.
func _open_finished_popup() -> void:
	var box := _new_popup("ALL LEVELS DONE!")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	box.add_child(rows)
	var total := _label("TOTAL  %d PTS" % GameState.game_score(), 44, DONE_COLOR)
	total.modulate.a = 0.0
	box.add_child(total)

	var tween := create_tween()
	tween.tween_interval(0.3)
	for level in Levels.count():
		if not GameState.level_results.has(level):
			continue
		var row := _result_row(level, GameState.level_results[level])
		row.modulate.a = 0.0
		rows.add_child(row)
		tween.tween_callback(func() -> void:
			row.modulate.a = 1.0
			Audio.sfx("star"))
		tween.tween_interval(0.45)
	tween.tween_callback(func() -> void:
		total.modulate.a = 1.0
		Audio.sfx("win"))

	var close := _button("CLOSE")
	close.pressed.connect(_close_popup)
	var results := _button("RESULTS")
	results.pressed.connect(func() -> void:
		GameState.game_complete = false
		get_tree().change_scene_to_file(GAME_OVER_SCENE))
	box.add_child(_button_row([close, results]))
	results.grab_focus()


## "LEVEL 1   ★ 7/9   1260 PTS"
func _result_row(level: int, result: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var name_label := _label("LEVEL %d" % (level + 1), 34, INK)
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)
	var star := StarIcon.new(44)
	star.set_earned(true, false)
	row.add_child(star)
	var stars_label := _label("%d/%d" % [result.stars, GameState.PHASE_COUNT * GameState.MAX_STARS], 34, INK)
	stars_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(stars_label)
	var points := _label("%d PTS" % result.score, 34, INK)
	points.custom_minimum_size = Vector2(220, 0)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(points)
	return row


func _start_level(i: int) -> void:
	Audio.sfx("click")
	GameState.level_index = i
	get_tree().change_scene_to_file(ORDER_CUTSCENE)


## Dims the map and shows the square pixel panel, fixed size, in the middle of the screen.
## Returns its content box.
func _new_popup(title: String, popup_size := Vector2(POPUP_SIZE, POPUP_SIZE)) -> VBoxContainer:
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
	panel.offset_left = -popup_size.x / 2.0
	panel.offset_top = -popup_size.y / 2.0
	panel.offset_right = popup_size.x / 2.0
	panel.offset_bottom = popup_size.y / 2.0
	panel.pivot_offset = popup_size / 2.0
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

## A chef idling (front-facing frames of its 8x4 sheet), `size_px` tall, in a Control.
func _chef_view(id: String, size_px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size_px, size_px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet: Texture2D = load(ChefStats.stat(id, "sheet", ""))
	if sheet == null:
		return holder
	var chef := IdleChef.new()
	chef.texture = sheet
	chef.hframes = 8
	chef.vframes = 4
	chef.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chef.position = Vector2(size_px, size_px) / 2.0
	chef.scale = Vector2.ONE * (size_px / (sheet.get_height() / 4.0))
	holder.add_child(chef)
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
func _button(text: String, font_size := 36) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
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
