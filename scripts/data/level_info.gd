class_name LevelInfo
extends Resource
## Everything that changes from level to level: the monster(s) and their order for the
## cutscenes, and which ingredients the HUD shows. Edit the .tres files in resources/levels.

## The Phase 1 map for this level.
@export_file("*.tscn") var level_scene := ""
## One monster, or two (the first one is on the left in the order cutscene).
@export var monsters: Array[Texture2D] = []
## The sentence in the order banner, e.g. "JGPiNE ordered a Hamburger!".
@export var order_text := ""
## The dish picture in the order bubble (60x60).
@export var dish_icon: Texture2D
## The three ingredient pieces of Phase 1, named like their scenes (beef, bun, ...), in the
## order the HUD tiles show them.
@export var ingredient_types := PackedStringArray()
## Their pictures: frames on "ingredients 32x32.png" (6 columns, row-major).
@export var ingredient_frames: Array[int] = []
