extends Control
## The end of the game: every level's stars and score added up, then back to the title.
## The scores come from GameState.level_results (filled in as each level's tally shows).
## Run this scene on its own (F6) to preview it with sample scores.

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const FONT := preload("res://assets/font/RetroGaming.ttf")
const WALL := preload("res://assets/images/bg/blue wall.png")
const FLOOR := preload("res://assets/images/bg/floor.png")
const IDLE_SCRIPT := preload("res://scripts/idle_chef.gd")
const INK := Color(0.17, 0.09, 0.06)
const OUTLINE := Color(0.23, 0.12, 0.08)
const ROW_STEP := 0.55

var _continue_button: Button
var _total_label: Label


func _ready() -> void:
	Audio.music("intro")
	if GameState.level_results.is_empty() and get_tree().current_scene == self:
		_fill_sample_results()   # running this scene on its own
	_build_background()
	_build_panel()


func _build_background() -> void:
	var wall := Sprite2D.new()
	wall.texture = WALL
	wall.centered = false
	add_child(wall)
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = FLOOR
	floor_sprite.centered = false
	floor_sprite.position = Vector2(0, 720)
	floor_sprite.scale = Vector2.ONE * 1.344
	add_child(floor_sprite)
	if GameState.selected_chef_texture:
		# The chosen chef, happy at the end, standing on the floor.
		var chef: Sprite2D = Sprite2D.new()
		chef.set_script(IDLE_SCRIPT)
		chef.texture = GameState.selected_chef_texture
		chef.hframes = 8
		chef.vframes = 4
		chef.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chef.scale = Vector2.ONE * 3.0
		chef.position = Vector2(300, 830)
		add_child(chef)


func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 520.0   # leaves the left side for the chef
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.88)
	style.set_border_width_all(8)
	style.border_color = OUTLINE
	style.set_corner_radius_all(14)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 32
	style.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(_label("GAME OVER", 80, Color(0.91, 0.5, 0.1), true))
	var who := GameState.nickname if GameState.nickname != "" else "Chef"
	box.add_child(_label("Every order delivered, %s!" % who, 34, INK))

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	box.add_child(rows)

	var tween := create_tween()
	tween.tween_interval(0.5)
	var levels := GameState.level_results.keys()
	levels.sort()
	for level in levels:
		var row := _result_row(level, GameState.level_results[level])
		row.modulate.a = 0.0
		rows.add_child(row)
		tween.tween_callback(func() -> void:
			row.modulate.a = 1.0
			Audio.sfx("star"))
		tween.tween_interval(ROW_STEP)

	var line := ColorRect.new()
	line.color = OUTLINE
	line.custom_minimum_size = Vector2(0, 6)
	box.add_child(line)

	_total_label = _label("TOTAL  0 PTS", 56, Color(0.12, 0.45, 0.45))
	_total_label.modulate.a = 0.0
	box.add_child(_total_label)

	_continue_button = Button.new()
	_continue_button.text = "BACK TO TITLE"
	_continue_button.disabled = true
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_continue_button)
	_continue_button.pressed.connect(_back_to_title)
	box.add_child(_continue_button)

	var total := GameState.game_score()
	tween.tween_callback(func() -> void:
		_total_label.modulate.a = 1.0
		Audio.sfx("win"))
	tween.tween_method(func(v: float) -> void:
		_total_label.text = "TOTAL  %s PTS" % _format(int(round(v))), 0.0, float(total), 1.0)
	tween.tween_callback(func() -> void:
		Audio.sfx("score")
		_continue_button.disabled = false
		_continue_button.grab_focus())


## One level: its name, the stars it earned, and its score.
func _result_row(level: int, result: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var name_label := _label("LEVEL %d" % (level + 1), 36, INK)
	name_label.custom_minimum_size = Vector2(230, 0)
	row.add_child(name_label)
	var star := StarIcon.new(48)
	row.add_child(star)
	var stars_label := _label("%d" % result.stars, 36, INK)
	stars_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(stars_label)
	var score_label := _label("%s PTS" % _format(result.score), 36, INK)
	score_label.custom_minimum_size = Vector2(300, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_label)
	return row


func _label(text: String, size: int, color: Color, outlined := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", OUTLINE)
		label.add_theme_constant_override("outline_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 36)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.97, 0.71, 0.28) if state in ["hover", "focus"] else Color(0.91, 0.6, 0.17)
		if state == "disabled":
			box.bg_color = Color(0.75, 0.7, 0.62)
		box.set_border_width_all(6)
		box.border_color = OUTLINE
		box.set_corner_radius_all(10)
		box.content_margin_left = 40
		box.content_margin_right = 40
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, box)


## 1234567 -> "1,234,567"
func _format(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


func _back_to_title() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _fill_sample_results() -> void:
	GameState.nickname = "Paula"
	GameState.level_results = {
		0: {"stars": 9, "points": 140, "score": 1260},
		1: {"stars": 7, "points": 180, "score": 1260},
		2: {"stars": 9, "points": 220, "score": 1980},
	}
