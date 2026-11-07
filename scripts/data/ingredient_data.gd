class_name IngredientData
extends Resource
## One ingredient for the chopping minigame: its name and its 3 chop-stage sprites.
## Make one .tres per ingredient in res://resources/ingredients/.

## Matches the ingredient types used in Phase 1 ("salmon", "cream", "potato").
@export var id: StringName = &""
@export var display_name := ""
## The "ingredients sprite sheet 80x80.png" (or any grid sheet).
@export var sheet: Texture2D
@export var cell_size := Vector2i(80, 80)
@export var columns := 6
## Sheet frames (row-major) for: [whole, 2 pieces, 3 pieces].
@export var stage_frames := PackedInt32Array([0, 0, 0])


## Texture for a chop stage: 0 = whole, 1 = 2 pieces, 2 = 3 pieces (clamped).
func stage_texture(stage: int) -> AtlasTexture:
	var frame := stage_frames[clampi(stage, 0, stage_frames.size() - 1)]
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(
		(frame % columns) * cell_size.x,
		(frame / columns) * cell_size.y,
		cell_size.x,
		cell_size.y)
	return atlas


## What the chef carries once the last chop is done.
func chopped_texture() -> AtlasTexture:
	return stage_texture(stage_frames.size() - 1)
