class_name Recipe
extends Resource
## A level's dish: the ingredients in the order they must be chopped and cooked.
## The kitchen reads everything from here, so nothing about a dish is hard-coded.

@export var dish_name := ""
## In recipe order. Chopping and the pot both follow this order.
@export var ingredients: Array[IngredientData] = []
@export var chops_per_ingredient := 3
## Seconds the pot cooks once every ingredient is in.
@export var cook_time := 3.0
## "5 dishes 60x60.png" and the frame of this dish on it.
@export var dish_sheet: Texture2D
@export var dish_cell_size := Vector2i(60, 60)
@export var dish_columns := 5
@export var dish_frame := 0


func ingredient_count() -> int:
	return ingredients.size()


func ingredient_at(index: int) -> IngredientData:
	return ingredients[index] if index >= 0 and index < ingredients.size() else null


func dish_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = dish_sheet
	atlas.region = Rect2(
		(dish_frame % dish_columns) * dish_cell_size.x,
		(dish_frame / dish_columns) * dish_cell_size.y,
		dish_cell_size.x,
		dish_cell_size.y)
	return atlas
