class_name Pot
extends Station
## Where chopped ingredients go and the dish cooks. Ingredients go in with B, in the recipe's
## order (a repeat or an out-of-order one is refused). When the 3rd goes in the pot cooks
## for the recipe's cook_time with a progress bar, then the chef can pick the whole pot up.

signal ingredient_added(ingredient: IngredientData, count: int)
signal cooking_started
signal cooked
signal pot_taken

enum State { FILLING, COOKING, DONE, TAKEN }

@export var recipe: Recipe:
	set(value):
		recipe = value
		_update_visuals()

var state := State.FILLING
var contents: Array[IngredientData] = []
## Seconds cooked so far. Driven by _process, so pausing the game pauses the pot.
var cook_progress := 0.0

var _boil_sound: AudioStreamPlayer
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _count_label: Label


func _ready() -> void:
	super()
	_build_ui()
	# The pot's own player: it freezes when the game is paused and stops with the pot.
	_boil_sound = AudioStreamPlayer.new()
	_boil_sound.stream = Audio.looping_stream("boiling")
	_boil_sound.volume_db = Audio.gain_db("boiling")
	add_child(_boil_sound)
	_update_visuals()


func _process(delta: float) -> void:
	if state != State.COOKING:
		return
	cook_progress += delta
	_update_visuals()
	if cook_progress >= recipe.cook_time:
		state = State.DONE
		_boil_sound.stop()
		Audio.sfx("cooked")
		_update_visuals()
		refresh_prompt()
		cooked.emit()


func _get_prompt_text() -> String:
	if holder == null:
		return ""
	if state == State.FILLING and holder.holds(ItemHolder.Kind.INGREDIENT):
		return "B  ADD"
	if state == State.DONE and holder.is_empty():
		return "B  TAKE POT"
	return ""


func _on_grab_drop() -> void:
	match state:
		State.FILLING:
			if holder.holds(ItemHolder.Kind.INGREDIENT):
				_try_add(holder.ingredient)
			elif holder.is_empty():
				message.emit("Bring a chopped ingredient to the pot.")
			else:
				message.emit("You can't put %s in the pot." % holder.describe())
		State.COOKING:
			message.emit("Still cooking!")
		State.DONE:
			if holder.hold_pot():
				Audio.sfx("pickup")
				state = State.TAKEN
				_update_visuals()
				pot_taken.emit()
			else:
				message.emit("Your hands are full! You're carrying %s." % holder.describe())
		State.TAKEN:
			message.emit("Nothing to pick up here.")



func _try_add(ingredient: IngredientData) -> void:
	if recipe == null:
		return
	if ingredient in contents:
		message.emit("%s is already in the pot!" % ingredient.display_name)
		return
	var expected := recipe.ingredient_at(contents.size())
	if ingredient != expected:
		message.emit("Not yet! The pot needs %s next." % expected.display_name)
		return
	holder.drop()
	Audio.sfx("drop")
	contents.append(ingredient)
	ingredient_added.emit(ingredient, contents.size())
	if contents.size() >= recipe.ingredient_count():
		state = State.COOKING
		_boil_sound.play()
		cooking_started.emit()
	_update_visuals()
	refresh_prompt()


func _build_ui() -> void:
	_count_label = Label.new()
	_count_label.add_theme_font_override("font", FONT)
	_count_label.add_theme_font_size_override("font_size", 8)
	_count_label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_count_label.add_theme_color_override("font_outline_color", Color(0.23, 0.12, 0.08))
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.position = Vector2(-40, -74)
	_count_label.size = Vector2(80, 10)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.23, 0.12, 0.08)
	_bar_back.position = Vector2(-30, -62)
	_bar_back.size = Vector2(60, 8)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_back)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.95, 0.66, 0.18)
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = Vector2(0, 4)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)


func _update_visuals() -> void:
	if _count_label == null:
		return
	var total := recipe.ingredient_count() if recipe else 3
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual:
		visual.visible = state != State.TAKEN
	_count_label.visible = state != State.TAKEN
	_bar_back.visible = state == State.COOKING
	match state:
		State.FILLING:
			_count_label.text = "%d/%d" % [contents.size(), total]
		State.COOKING:
			_count_label.text = "COOKING"
			var ratio := clampf(cook_progress / recipe.cook_time, 0.0, 1.0)
			_bar_fill.size.x = 56.0 * ratio
		State.DONE:
			_count_label.text = "READY!"
