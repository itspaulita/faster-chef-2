class_name Hud
extends CanvasLayer
## HUD, top left: the phase timer with its stars above it, and under it one tile per ingredient with
## the "have/goal" count under it. Top right: the points counter and the pause button.

## A star was lost to the clock; `stars_left` is what remains.
signal star_lost(stars_left: int)
## The clock hit 0:00 (0 stars).
signal timed_out

const TIMER_NORMAL := Color(0.17, 0.09, 0.06, 1)
const TIMER_WARNING := Color(0.6, 0.04, 0.04, 1)

const ICON_SIZE := 32
## Frames on "ingredients 32x32.png" (6 columns x 2 rows, row-major):
## 0 mushrooms, 1 pumpkin, 2 potato, 3 salmon, 4 pork, 5 shrimp, 6 milk, 7 pepper, 8 eggs, 9 flour.
@export var ingredient_frames: Array[int] = [0, 5, 7]
@export var ingredient_goals: Array[int] = [5, 5, 5]

## The phase countdown. It's a node, so pausing the game freezes it.
var phase_timer := PhaseTimer.new()
var star_icons: Array[StarIcon] = []

var _full_tile_style: StyleBoxFlat
var _normal_tile_style: StyleBox

@onready var points_panel: PanelContainer = $PointsPanel
@onready var points_label: Label = $PointsPanel/PointsLabel
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var timer_panel: Control = $TopLeft/TimerBox
@onready var timer_label: Label = $TopLeft/TimerBox/TimerPanel/TimerLabel
@onready var stars_row: HBoxContainer = $TopLeft/TimerBox/StarsRow
@onready var rows: Array[Node] = [
	$TopLeft/Ingredients/Slot1,
	$TopLeft/Ingredients/Slot2,
	$TopLeft/Ingredients/Slot3,
]
@onready var sheet: Texture2D = preload("res://assets/images/food/ingredients 32x32.png")


func _ready() -> void:
	_normal_tile_style = rows[0].get_node("IconTile").get_theme_stylebox("panel")
	_full_tile_style = _normal_tile_style.duplicate()
	_full_tile_style.bg_color = Color(0.7, 0.92, 0.7)
	for i in rows.size():
		var icon := AtlasTexture.new()
		icon.atlas = sheet
		var frame := ingredient_frames[i]
		icon.region = Rect2((frame % 6) * ICON_SIZE, (frame / 6) * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		rows[i].get_node("IconTile/Icon").texture = icon
		set_ingredient(i, 0, false)
	set_points(0, false)
	$PauseButton.pressed.connect(pause_menu.open)
	add_child(phase_timer)
	phase_timer.tick.connect(_on_tick)
	phase_timer.star_lost.connect(_on_star_lost)
	phase_timer.timed_out.connect(timed_out.emit)
	for i in 3:
		var star := StarIcon.new(52)
		stars_row.add_child(star)
		star_icons.append(star)


## Sets how many of ingredient `index` (0-2) have been collected.
func set_ingredient(index: int, count: int, animate := true) -> void:
	var goal := ingredient_goals[index]
	var slot := rows[index]
	var label: Label = slot.get_node("CountLabel")
	var tile: PanelContainer = slot.get_node("IconTile")
	label.text = "%d/%d" % [count, goal]
	var full := count >= goal
	tile.add_theme_stylebox_override("panel", _full_tile_style if full else _normal_tile_style)
	if animate:
		tile.pivot_offset = tile.size / 2.0
		create_tween().tween_property(tile, "scale", Vector2.ONE, 0.2) \
				.from(Vector2(1.15, 1.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_points(value: int, animate := true) -> void:
	points_label.text = "POINT: %d XP" % value
	if animate:
		await get_tree().process_frame
		points_panel.pivot_offset = points_panel.size / 2.0
		create_tween().tween_property(points_panel, "scale", Vector2.ONE, 0.25) \
				.from(Vector2(1.15, 1.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows the countdown and starts it. Everyone starts with 3 stars; the HUD dims one each
## time the clock says it's lost.
func start_timer(timing: PhaseTiming) -> void:
	timer_panel.visible = true
	phase_timer.start(timing)
	_update_stars(false)


## Freezes the countdown where it is (it stays on screen). Returns the stars earned.
func stop_timer() -> int:
	return phase_timer.stop()


func hide_timer() -> void:
	phase_timer.stop()
	timer_panel.visible = false


func _on_tick(time_left: float) -> void:
	var whole := ceili(time_left)
	timer_label.text = "%d:%02d" % [whole / 60, whole % 60]
	timer_label.add_theme_color_override("font_color", \
			TIMER_WARNING if phase_timer.stars <= 1 else TIMER_NORMAL)


func _on_star_lost(stars_left: int) -> void:
	_update_stars(true)
	star_lost.emit(stars_left)


func _update_stars(animate: bool) -> void:
	for i in star_icons.size():
		var earned := i < phase_timer.stars
		if star_icons[i].earned != earned or not animate:
			star_icons[i].set_earned(earned, animate and star_icons[i].earned != earned)
