extends Control

const NEXT_SCENE := "res://scenes/level_map.tscn"
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const DIMMED := Color(0.6, 0.6, 0.6)
## The stats box sits above the chef, with its bottom edge at this y.
const POPUP_BOTTOM := 690.0

const DEFAULT_PROMPT := "Select a chef and press play"
const NICKNAME_PROMPT := "Type a nickname first!"

var _selected: Sprite2D

@onready var chefs: Array[Node] = $Chefs.get_children()
@onready var play_button: Button = $PlayButton
@onready var prompt_label: Label = $PromptLabel
@onready var nickname_edit: LineEdit = $NicknameRow/NicknameEdit
@onready var stats_popup: PanelContainer = $StatsPopup
@onready var name_label: Label = $StatsPopup/VBoxContainer/NameLabel
@onready var ability_label: Label = $StatsPopup/VBoxContainer/AbilityLabel
@onready var weakness_label: Label = $StatsPopup/VBoxContainer/WeaknessLabel


func _ready() -> void:
	Audio.music("intro")
	play_button.pressed.connect(_on_play_pressed)
	nickname_edit.text = GameState.nickname
	# Enter confirms the name, so the keyboard goes back to the screen.
	nickname_edit.text_changed.connect(func(_text: String) -> void: prompt_label.text = DEFAULT_PROMPT)
	nickname_edit.text_submitted.connect(_on_nickname_submitted)


## Enter confirms the name and picks the first chef (if none is picked yet), so the rest can be
## done with the keyboard: Left / Right (or A / D) switch chef, Enter starts.
func _on_nickname_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		Audio.sfx("wrong")
		prompt_label.text = NICKNAME_PROMPT
		_flash(prompt_label)
		_flash(nickname_edit)
		return
	nickname_edit.release_focus()
	if _selected == null:
		_select(chefs[0])


func _move_selection(step: int) -> void:
	var index := chefs.find(_selected)
	if index < 0:
		index = 0 if step > 0 else chefs.size() - 1
	else:
		index = wrapi(index + step, 0, chefs.size())
	_select(chefs[index])


## Returns true if the key was used.
func _handle_key(event: InputEventKey) -> bool:
	if nickname_edit.has_focus():
		return false   # typing; Enter is handled by the name field itself
	if event.is_action_pressed("ui_accept", false, true):
		_on_play_pressed()
		return true
	if event.is_action_pressed("ui_left", false, true) or event.is_action_pressed("left", false, true):
		_move_selection(-1)
		return true
	if event.is_action_pressed("ui_right", false, true) or event.is_action_pressed("right", false, true):
		_move_selection(1)
		return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Grab the viewport first: starting the game changes the scene, which removes this node.
		var viewport := get_viewport()
		if _handle_key(event):
			viewport.set_input_as_handled()
			return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Clicking anywhere but the name field leaves it.
	if not nickname_edit.get_global_rect().has_point(event.position):
		nickname_edit.release_focus()
	for chef: Sprite2D in chefs:
		if chef.get_rect().has_point(chef.to_local(event.position)):
			_select(chef)
			return


func _select(chef: Sprite2D) -> void:
	_selected = chef
	for other: Sprite2D in chefs:
		other.material = null
		other.modulate = DIMMED
	chef.modulate = Color.WHITE
	chef.material = ShaderMaterial.new()
	chef.material.shader = OUTLINE_SHADER
	_show_stats(chef)


func _show_stats(chef: Sprite2D) -> void:
	var stats := ChefStats.get_stats(chef.name)
	name_label.text = stats.name
	ability_label.text = "Ability: %s" % stats.ability
	weakness_label.text = "Weakness: %s" % stats.weakness
	# Wrapped labels only report their final height once laid out at the final width,
	# so lay the box out invisibly first, then place it.
	stats_popup.modulate.a = 0.0
	stats_popup.visible = true
	stats_popup.size = Vector2(stats_popup.custom_minimum_size.x, 0.0)
	await get_tree().process_frame
	if not is_inside_tree():
		return   # the game already started
	stats_popup.reset_size()
	await get_tree().process_frame
	if not is_inside_tree() or _selected != chef:
		return
	stats_popup.position = Vector2(chef.position.x - stats_popup.size.x / 2.0, POPUP_BOTTOM - stats_popup.size.y)
	stats_popup.modulate.a = 1.0


func _on_play_pressed() -> void:
	# The nickname is required (it will be the name on the scoreboard).
	if nickname_edit.text.strip_edges().is_empty():
		Audio.sfx("wrong")
		prompt_label.text = NICKNAME_PROMPT
		_flash(prompt_label)
		_flash(nickname_edit)
		nickname_edit.grab_focus()
		return
	if _selected == null:
		Audio.sfx("wrong")
		prompt_label.text = DEFAULT_PROMPT
		_flash(prompt_label)
		return
	GameState.nickname = nickname_edit.text.strip_edges()
	GameState.level_index = 0   # a new game starts at level 1
	GameState.reset_game()
	GameState.selected_chef_name = _selected.name
	GameState.selected_chef_texture = _selected.texture
	if ResourceLoader.exists(NEXT_SCENE):
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		print("Next scene not made yet: ", NEXT_SCENE)


## Turns a control red and fades it back, to show what's missing.
func _flash(control: Control) -> void:
	control.modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(control, "modulate", Color.WHITE, 0.4)
