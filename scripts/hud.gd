class_name Hud
extends CanvasLayer
## HUD: three ingredient progress bars with icons (percentage inside the bar) on the top left,
## and the points counter on the top right.

const ICON_SIZE := 32
## Frames on "ingredients 32x32.png" (6 columns x 2 rows, row-major):
## 0 mushrooms, 1 pumpkin, 2 potato, 3 salmon, 4 pork, 5 shrimp, 6 milk, 7 pepper, 8 eggs, 9 flour.
@export var ingredient_frames: Array[int] = [0, 5, 7]
@export var ingredient_goals: Array[int] = [5, 5, 5]

var _full_style: StyleBoxFlat
var _normal_style: StyleBox

@onready var points_panel: PanelContainer = $PointsPanel
@onready var points_label: Label = $PointsPanel/PointsLabel
@onready var rows: Array[Node] = [
	$Rows/Row1,
	$Rows/Row2,
	$Rows/Row3,
]
@onready var sheet: Texture2D = preload("res://assets/images/food/ingredients 32x32.png")


func _ready() -> void:
	_normal_style = rows[0].get_node("Bar").get_theme_stylebox("fill")
	_full_style = _normal_style.duplicate()
	_full_style.bg_color = Color(0.2, 0.65, 0.3)
	for i in rows.size():
		var icon := AtlasTexture.new()
		icon.atlas = sheet
		var frame := ingredient_frames[i]
		icon.region = Rect2((frame % 6) * ICON_SIZE, (frame / 6) * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		rows[i].get_node("IconTile/Icon").texture = icon
		set_ingredient(i, 0, false)
	set_points(0, false)


## Sets how many of ingredient `index` (0-2) have been collected.
func set_ingredient(index: int, count: int, animate := true) -> void:
	var goal := ingredient_goals[index]
	var bar: ProgressBar = rows[index].get_node("Bar")
	bar.max_value = goal
	if animate:
		create_tween().tween_property(bar, "value", minf(count, goal), 0.2)
	else:
		bar.value = minf(count, goal)
	bar.add_theme_stylebox_override("fill", _full_style if count >= goal else _normal_style)


func set_points(value: int, animate := true) -> void:
	points_label.text = "POINT: %d XP" % value
	if animate:
		await get_tree().process_frame
		points_panel.pivot_offset = points_panel.size / 2.0
		create_tween().tween_property(points_panel, "scale", Vector2.ONE, 0.25) \
				.from(Vector2(1.15, 1.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
