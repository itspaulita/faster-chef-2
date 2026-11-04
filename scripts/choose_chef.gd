extends Control

const NEXT_SCENE := "res://scenes/cutscene.tscn"
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const DIMMED := Color(0.6, 0.6, 0.6)
## The stats box sits above the chef, with its bottom edge at this y.
const POPUP_BOTTOM := 690.0

var _selected: Sprite2D

@onready var chefs: Array[Node] = $Chefs.get_children()
@onready var play_button: Button = $PlayButton
@onready var prompt_label: Label = $PromptLabel
@onready var stats_popup: PanelContainer = $StatsPopup
@onready var name_label: Label = $StatsPopup/VBoxContainer/NameLabel
@onready var ability_label: Label = $StatsPopup/VBoxContainer/AbilityLabel
@onready var weakness_label: Label = $StatsPopup/VBoxContainer/WeaknessLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
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
	stats_popup.reset_size()
	await get_tree().process_frame
	if _selected != chef:
		return
	stats_popup.position = Vector2(chef.position.x - stats_popup.size.x / 2.0, POPUP_BOTTOM - stats_popup.size.y)
	stats_popup.modulate.a = 1.0


func _on_play_pressed() -> void:
	if _selected == null:
		prompt_label.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(prompt_label, "modulate", Color.WHITE, 0.4)
		return
	GameState.selected_chef_name = _selected.name
	GameState.selected_chef_texture = _selected.texture
	if ResourceLoader.exists(NEXT_SCENE):
		get_tree().change_scene_to_file(NEXT_SCENE)
	else:
		print("Next scene not made yet: ", NEXT_SCENE)
