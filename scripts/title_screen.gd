extends Control

const NEXT_SCENE := "res://scenes/cutscene.tscn"
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const DIMMED := Color(0.6, 0.6, 0.6)

var _selected: Sprite2D

@onready var chefs: Array[Node] = $Chefs.get_children()
@onready var start_button: Button = $StartButton
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)


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


func _on_start_pressed() -> void:
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
