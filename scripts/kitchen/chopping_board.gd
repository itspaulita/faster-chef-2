class_name ChoppingBoard
extends Station
## Where the chef chops. Standing still at the board turns the chef to the wall and opens
## the chop panel. Each E is one chop (whole -> 2 pieces -> 3 pieces -> done). When the
## 3rd chop lands the panel keeps showing the chopped ingredient (nothing is drawn on the
## counter) until the chef picks it up with Q, which puts it in their hands. Ingredients are chopped in the recipe's order.

signal chopped(ingredient: IngredientData)
signal ingredient_taken(ingredient: IngredientData)

const PANEL_SCENE := preload("res://scenes/chop_panel.tscn")
## Seconds a chop takes. Presses during it are ignored, so mashing E can't skip stages.
const CHOP_TIME := 0.25
### Seconds the chef must stand still in the zone before the panel opens by itself.
#const STAND_TIME := 0.15

@export var recipe: Recipe

## Index of the recipe ingredient being chopped next.
var next_index := 0
var chops := 0
var is_chopping := false
## The chopped ingredient waiting on the board to be picked up.
var ready_item: IngredientData

var _busy := false
## Bumped whenever chopping starts over, so a chop timer from before can't act on the new one.
var _session := 0
#var _still_time := 0.0
var _panel: ChopPanel


func _ready() -> void:
	super()
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	chef_entered.connect(_on_chef_arrived)   # walk in  → panel opens
	chef_exited.connect(_on_chef_left)       # walk out → panel closes, chopping resets

#func _physics_process(delta: float) -> void:
	#if chef == null or is_chopping or not _can_start_chopping():
		#_still_time = 0.0
		#return
	#if _is_standing():
		#_still_time += delta
		#if _still_time >= STAND_TIME:
			#_start_chopping()
	#else:
		#_still_time = 0.0  # Just running past the board: don't grab the chef.


func _get_prompt_text() -> String:
	if holder == null or is_chopping:
		return ""
	if ready_item != null:
		return "Q  PICK UP" if holder.is_empty() else ""
	return "E  CHOP" if _can_start_chopping() else ""


func _on_chop() -> void:
	if not is_chopping:
		if not _can_start_chopping():
			if not holder.is_empty():
				message.emit("Your hands are full! You're carrying %s." % holder.describe())
			elif ready_item != null:
				message.emit("Pick up the chopped %s first (Q)." % ready_item.display_name)
			else:
				message.emit("Everything is already chopped!")
			return
		_start_chopping()
	if _busy:
		return
	_chop()

func _on_grab_drop() -> void:
	if is_chopping:
		message.emit("Finish chopping first!")
		return
	if ready_item == null:
		if holder.is_empty():
			message.emit("Nothing to pick up here.")
		else:
			message.emit("You can't put %s on the chopping board." % holder.describe())
		return
	var taken := ready_item
	if holder.hold_ingredient(taken):
		Audio.sfx("pickup")
		ready_item = null
		_panel.close()
		ingredient_taken.emit(taken)
		refresh_prompt()
	else:
		message.emit("Your hands are full!")


func _can_start_chopping() -> bool:
	return recipe != null \
			and holder != null and holder.is_empty() \
			and ready_item == null \
			and next_index < recipe.ingredient_count()

#
#func _is_grounded() -> bool:
	#return (chef as CharacterBody2D).is_on_floor()


#func _is_standing() -> bool:
	#return _is_grounded() and absf((chef as CharacterBody2D).velocity.x) < 5.0


func _start_chopping() -> void:
	_session += 1
	is_chopping = true
	#_still_time = 0.0
	Audio.sfx("minigame_open")
	#_lock_chef()
	_panel.open(recipe.ingredient_at(next_index), chops, recipe.chops_per_ingredient)
	refresh_prompt()


func _chop() -> void:
	chops += 1
	_busy = true
	Audio.sfx("chop", chops - 1)   # chop 1, 2, 3 each have their own sound
	_panel.chopped(chops)
	# Ignore E until the chop animation is over; the last chop then closes the panel.
	var session := _session
	create_tween().tween_interval(CHOP_TIME).finished.connect(func() -> void:
		if session == _session:
			_after_chop())


func _after_chop() -> void:
	if chops >= recipe.chops_per_ingredient:
		_finish_chopping()
	else:
		_busy = false


func _finish_chopping() -> void:
	Audio.sfx("all_chopped")
	ready_item = recipe.ingredient_at(next_index)
	next_index += 1
	chops = 0
	is_chopping = false
	_busy = false
	#_unlock_chef()
	_show_ready_item()
	chopped.emit(ready_item)
	refresh_prompt()

func _show_ready_item() -> void:
	_panel.show_result("%s CHOPPED!" % ready_item.display_name.to_upper(), ready_item.chopped_texture(), "TAKE IT!")


## The chef walked out of the zone: the popup closes. Mid-chop, this ingredient starts over.
func _on_chef_left(_body: Node2D) -> void:
	_panel.close()
	if not is_chopping:
		return
	_session += 1
	chops = 0
	is_chopping = false
	_busy = false
	#message.emit("You walked away, chopping reset!")
	refresh_prompt()

func _on_chef_arrived(_body: Node2D) -> void:
	if ready_item != null:
		_show_ready_item()   # still waiting to be picked up
	elif _can_start_chopping():
		_start_chopping()
# The chef can't move while chopping, and turns to face the wall (the front-facing idle).
#func _lock_chef() -> void:
	#chef.set_physics_process(false)
	#(chef as CharacterBody2D).velocity = Vector2.ZERO
	#var sprite := chef.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	#if sprite and sprite.sprite_frames.has_animation("idle"):
		#sprite.play("idle")
#
#
#func _unlock_chef() -> void:
	#chef.set_physics_process(true)
