class_name ItemHolder
extends Node2D
## The chef's hands: holds ONE item at a time (a chopped ingredient, the pot, or the dish)
## and draws it above the chef's head. Stations never change the item directly; they ask
## this node, and it says no if the hands are already full.

signal changed

enum Kind { NONE, INGREDIENT, POT, DISH }

const NODE_NAME := "ItemHolder"
const CHEF_GROUP := &"chef"
## Where the item floats, in the chef's local space.
const HEAD_OFFSET := Vector2(0, -78)
const ITEM_SCALE := 0.6

var kind := Kind.NONE
## Set while holding an ingredient.
var ingredient: IngredientData
## Set while holding the dish.
var recipe: Recipe

var _sprite: Sprite2D


## Finds the chef's ItemHolder, or adds one. Works on any CharacterBody2D, so a map doesn't
## have to set anything up.
static func get_or_create(chef: Node) -> ItemHolder:
	var existing := chef.get_node_or_null(NODE_NAME) as ItemHolder
	if existing:
		return existing
	var holder := ItemHolder.new()
	holder.name = NODE_NAME
	chef.add_child(holder)
	chef.add_to_group(CHEF_GROUP)
	return holder


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = HEAD_OFFSET
	_sprite.scale = Vector2.ONE * ITEM_SCALE
	_sprite.visible = false
	add_child(_sprite)


func is_empty() -> bool:
	return kind == Kind.NONE


func holds(what: Kind) -> bool:
	return kind == what


## Each hold_* returns false (and changes nothing) when the hands are full.
func hold_ingredient(data: IngredientData) -> bool:
	if not is_empty() or data == null:
		return false
	ingredient = data
	_set_item(Kind.INGREDIENT, data.chopped_texture())
	return true


func hold_pot() -> bool:
	if not is_empty():
		return false
	_set_item(Kind.POT, null)
	return true


func hold_dish(dish_recipe: Recipe) -> bool:
	if not is_empty() or dish_recipe == null:
		return false
	recipe = dish_recipe
	_set_item(Kind.DISH, dish_recipe.dish_texture())
	return true


## Empties the hands and returns what was held.
func drop() -> Kind:
	var was := kind
	if was != Kind.NONE:
		ingredient = null
		recipe = null
		_set_item(Kind.NONE, null)
	return was


## Short phrase for messages, e.g. "a chopped Potato" or "the pot".
func describe() -> String:
	match kind:
		Kind.INGREDIENT:
			return "a chopped %s" % ingredient.display_name
		Kind.POT:
			return "the pot"
		Kind.DISH:
			return "the dish"
	return "nothing"


func _set_item(new_kind: Kind, texture: Texture2D) -> void:
	kind = new_kind
	_sprite.texture = texture
	_sprite.visible = texture != null
	queue_redraw()
	changed.emit()


# The pot has no art yet, so it's a simple placeholder drawing.
func _draw() -> void:
	if kind != Kind.POT:
		return
	var c := HEAD_OFFSET
	var dark := Color(0.23, 0.12, 0.08)
	draw_rect(Rect2(c + Vector2(-26, -4), Vector2(8, 5)), dark)   # left handle
	draw_rect(Rect2(c + Vector2(18, -4), Vector2(8, 5)), dark)    # right handle
	draw_rect(Rect2(c + Vector2(-20, -10), Vector2(40, 22)), dark)
	draw_rect(Rect2(c + Vector2(-17, -7), Vector2(34, 16)), Color(0.55, 0.57, 0.6))
	draw_rect(Rect2(c + Vector2(-17, -7), Vector2(34, 4)), Color(0.75, 0.77, 0.8))
