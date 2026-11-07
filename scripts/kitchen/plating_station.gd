class_name PlatingStation
extends Station
## Where the cooked pot is set down (Q) and turned into the plated dish. Picking the dish up
## with Q hands it to the chef, which is what starts Phase 3.

signal dish_plated
signal dish_picked_up(recipe: Recipe)

@export var recipe: Recipe

var has_dish := false

var _dish_sprite: Sprite2D


func _ready() -> void:
	super()
	_dish_sprite = Sprite2D.new()
	_dish_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dish_sprite.position = Vector2(0, -42)
	_dish_sprite.scale = Vector2.ONE * 0.6
	_dish_sprite.visible = false
	add_child(_dish_sprite)


func _get_prompt_text() -> String:
	if holder == null:
		return ""
	if has_dish:
		return "Q  PICK UP DISH" if holder.is_empty() else ""
	return "Q  PLATE" if holder.holds(ItemHolder.Kind.POT) else ""


func _on_grab_drop() -> void:
	if has_dish:
		if holder.hold_dish(recipe):
			Audio.sfx("pickup")
			has_dish = false
			_dish_sprite.visible = false
			dish_picked_up.emit(recipe)
			refresh_prompt()
		else:
			message.emit("Your hands are full! You're carrying %s." % holder.describe())
	elif holder.holds(ItemHolder.Kind.POT):
		holder.drop()
		Audio.sfx("drop_plate")
		Audio.sfx("plated")
		has_dish = true
		_dish_sprite.texture = recipe.dish_texture()
		_dish_sprite.visible = true
		dish_plated.emit()
		refresh_prompt()
	elif holder.is_empty():
		message.emit("Bring the cooked pot here to plate it.")
	else:
		message.emit("Only the cooked pot goes here, not %s." % holder.describe())
