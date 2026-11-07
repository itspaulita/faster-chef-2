class_name Station
extends Area2D
## Base for the kitchen's interaction zones (chopping board, pot, plating station).
## Tracks the chef standing in the zone, shows a key prompt above the station, and routes
## E (chop) and Q (grab/drop) to the station the chef is standing at. Away from every
## station, nothing listens, so the keys do nothing.

signal chef_entered(chef: Node2D)
signal chef_exited(chef: Node2D)
## Short feedback text, e.g. for the toast notifications.
signal message(text: String)

const FONT := preload("res://assets/font/RetroGaming.ttf")

@export var station_name := "Station"
## Where the prompt floats, relative to the station. High enough to clear the held item.
@export var prompt_offset := Vector2(0, -108)

var chef: Node2D
var holder: ItemHolder
var _blink: Tween

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const BLINK_TIME := 0.45

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_prompt()
	refresh_prompt()


## Blinks a yellow outline around the station's picture to show it is the next thing to do.
func set_highlight(on: bool) -> void:
	if on == (_blink != null):
		return
	# The station's picture is the AnimatedSprite2D inside its art scene (chopping_spot, ...).
	var sprites := find_children("*", "AnimatedSprite2D", true, false)
	if sprites.is_empty():
		return
	var art := sprites[0] as CanvasItem
	if _blink:
		_blink.kill()
		_blink = null
	if not on:
		art.material = null
		return
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("width", 3.0)
	art.material = material
	_blink = create_tween().set_loops()
	_blink.tween_method(func(a: float) -> void:
		material.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.2, a)), 1.0, 0.1, BLINK_TIME)
	_blink.tween_method(func(a: float) -> void:
		material.set_shader_parameter("outline_color", Color(1.0, 0.85, 0.2, a)), 0.1, 1.0, BLINK_TIME)


func is_chef_near() -> bool:
	return chef != null


## Subclasses return the prompt, e.g. "E  CHOP". An empty string hides it.
func _get_prompt_text() -> String:
	return ""


## Subclasses react to the keys here. Only called while the chef is in the zone.
## By default a station isn't for chopping; the chopping board overrides this.
func _on_chop() -> void:
	message.emit("Chopping happens at the chopping board!")


## By default there's nothing to do here.
func _on_grab_drop() -> void:
	message.emit("Nothing to pick up here.")


## Call whenever something that changes the prompt text changes.
func refresh_prompt() -> void:
	if _prompt == null:
		return
	var text := _get_prompt_text() if is_chef_near() else ""
	_prompt.visible = text != ""
	_prompt_label.text = text
	_prompt.reset_size()
	_prompt.position = prompt_offset - _prompt.size / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if chef == null:
		return
	# `false` ignores key repeat, so holding a key can't fire it over and over.
	if event.is_action_pressed("chop", false):
		_on_chop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("grab_drop", false):
		_on_grab_drop()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if chef != null or not body is CharacterBody2D:
		return
	chef = body
	holder = ItemHolder.get_or_create(body)
	holder.changed.connect(refresh_prompt)
	chef_entered.emit(body)
	refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body != chef:
		return
	if holder:
		holder.changed.disconnect(refresh_prompt)
	var left := chef
	chef = null
	holder = null
	refresh_prompt()
	chef_exited.emit(left)


func _build_prompt() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.88)
	style.border_color = Color(0.23, 0.12, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3

	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", style)
	_prompt.z_index = 10
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_override("font", FONT)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(0.17, 0.09, 0.06))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_prompt_label)
	add_child(_prompt)
