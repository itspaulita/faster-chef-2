class_name ChopPanel
extends CanvasLayer
## The popup of the chopping board and the plating station. While chopping it shows the
## ingredient whole, then in 2 and 3 pieces as chops land (open / chopped). Afterwards it
## keeps showing the finished ingredient or dish (show_result) until the chef takes it
## with B; nothing is drawn on the counter. The station closes it (close).

@onready var banner: Control = $Banner
@onready var title_label: Label = %TitleLabel
@onready var item: TextureRect = %Item
@onready var stage_label: Label = %StageLabel
@onready var hint_label: Label = %HintLabel

var _ingredient: IngredientData
var _chops_total := 3


func _ready() -> void:
	# Pivots at the centre so the pop-in and the chop "punch" scale from the middle.
	banner.resized.connect(func(): banner.pivot_offset = banner.size / 2.0)
	item.resized.connect(func(): item.pivot_offset = item.size / 2.0)


func open(ingredient: IngredientData, chops_done: int, chops_total: int) -> void:
	_ingredient = ingredient
	_chops_total = chops_total
	title_label.text = "CHOP %s" % ingredient.display_name.to_upper()
	hint_label.text = "PRESS  C"
	_show_stage(chops_done, false)
	_pop_in()


## Shows a finished thing (a chopped ingredient, the plated dish) that waits for B.
func show_result(title: String, texture: Texture2D, caption: String) -> void:
	_ingredient = null
	title_label.text = title
	item.texture = texture
	stage_label.text = caption
	hint_label.text = "PRESS  B"
	_pop_in()


func _pop_in() -> void:
	visible = true
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.2) \
			.from(Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Call after each chop with the total chops done so far.
func chopped(chops_done: int) -> void:
	if _ingredient == null:
		return   # showing a finished result, not chopping
	_show_stage(chops_done, true)


func close() -> void:
	visible = false


func _show_stage(chops_done: int, animate: bool) -> void:
	if _ingredient == null:
		return
	# 0 chops = whole, 1 = 2 pieces, 2+ = 3 pieces (the last chop has no new sprite).
	item.texture = _ingredient.stage_texture(chops_done)
	stage_label.text = "CHOPS %d/%d" % [chops_done, _chops_total]
	if animate:
		create_tween().tween_property(item, "scale", Vector2.ONE, 0.2) \
				.from(Vector2(1.25, 1.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
