class_name PlatingStation
extends Station
## Where the cooked pot is set down (Q) and turned into the plated dish. The dish shows in a
## popup (nothing on the counter) until the chef picks it up with Q, which puts it in their
## hands and is what starts Phase 3.

signal dish_plated
signal dish_picked_up(recipe: Recipe)

@export var recipe: Recipe

var has_dish := false

var _panel: ChopPanel


func _ready() -> void:
	super()
	_panel = preload("res://scenes/chop_panel.tscn").instantiate()
	add_child(_panel)
	chef_entered.connect(func(_body: Node2D) -> void:
		if has_dish:
			_show_dish())
	chef_exited.connect(func(_body: Node2D) -> void: _panel.close())


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
			_panel.close()
			dish_picked_up.emit(recipe)
			refresh_prompt()
		else:
			message.emit("Your hands are full! You're carrying %s." % holder.describe())
	elif holder.holds(ItemHolder.Kind.POT):
		holder.drop()
		Audio.sfx("drop_plate")
		Audio.sfx("plated")
		has_dish = true
		_show_dish()
		dish_plated.emit()
		refresh_prompt()
	elif holder.is_empty():
		message.emit("Bring the cooked pot here to plate it.")
	else:
		message.emit("Only the cooked pot goes here, not %s." % holder.describe())


func _show_dish() -> void:
	_panel.show_result("%s READY!" % recipe.dish_name.to_upper(), recipe.dish_texture(), "TAKE IT!")
