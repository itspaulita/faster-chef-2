class_name Hud
extends CanvasLayer
## HUD, top left: the phase timer (a draining bar with the 3 stars on it, and the clock under it),
## and under it one tile per ingredient with the "have/goal" count under it. Top right: the points counter and the pause button.

## A star was lost to the clock; `stars_left` is what remains.
signal star_lost(stars_left: int)
## The clock hit 0:00 (0 stars).
signal timed_out

const TIMER_NORMAL := Color(0.17, 0.09, 0.06, 1)
const TIMER_WARNING := Color(0.6, 0.04, 0.04, 1)
const BAR_COLOR := Color(0.2, 0.65, 0.3, 1)
const BAR_WARNING_COLOR := Color(0.85, 0.2, 0.15, 1)
const BAR_WIDTH := 420.0
const STAR_SIZE := 48

const ICON_SIZE := 32
## Frames on "ingredients 32x32.png" (6 columns x 2 rows, row-major):
## 0 mushrooms, 1 pumpkin, 2 potato, 3 salmon, 4 pork, 5 shrimp, 6 milk, 7 pepper, 8 eggs, 9 flour.
@export var ingredient_frames: Array[int] = [0, 5, 7]
@export var ingredient_goals: Array[int] = [5, 5, 5]

## The phase countdown. It's a node, so pausing the game freezes it.
var phase_timer := PhaseTimer.new()
var star_icons: Array[StarIcon] = []

var _bar_fill: StyleBoxFlat

# Ingredient tile looks: grey at 0 collected, blue while collecting, yellow once complete.
var _empty_tile_style: StyleBoxFlat
var _done_tile_style: StyleBoxFlat
var _normal_tile_style: StyleBox

@onready var points_panel: PanelContainer = $PointsPanel
@onready var points_label: Label = $PointsPanel/PointsLabel
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var timer_panel: Control = $TopLeft/TimerBox
@onready var timer_label: Label = $TopLeft/TimerBox/Box/TimerLabel
@onready var bar_area: Control = $TopLeft/TimerBox/Box/BarArea
@onready var bar: ProgressBar = $TopLeft/TimerBox/Box/BarArea/Bar
@onready var rows: Array[Node] = [
	$TopLeft/Ingredients/Slot1,
	$TopLeft/Ingredients/Slot2,
	$TopLeft/Ingredients/Slot3,
]
@onready var sheet: Texture2D = preload("res://assets/images/food/ingredients 32x32.png")


func _ready() -> void:
	_normal_tile_style = rows[0].get_node("IconTile").get_theme_stylebox("panel")
	_empty_tile_style = _normal_tile_style.duplicate()
	_empty_tile_style.bg_color = Color(0.72, 0.74, 0.78)
	_done_tile_style = _normal_tile_style.duplicate()
	_done_tile_style.bg_color = Color(1.0, 0.86, 0.3)
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
	_setup_bar()


## Sets how many of ingredient `index` (0-2) have been collected.
func set_ingredient(index: int, count: int, animate := true) -> void:
	var goal := ingredient_goals[index]
	var slot := rows[index]
	var label: Label = slot.get_node("CountLabel")
	var tile: PanelContainer = slot.get_node("IconTile")
	label.text = "%d/%d" % [count, goal]
	var style := _normal_tile_style
	if count <= 0:
		style = _empty_tile_style
	elif count >= goal:
		style = _done_tile_style
	tile.add_theme_stylebox_override("panel", style)
	# The picture is dimmed to grey too while nothing has been collected.
	slot.get_node("IconTile/Icon").modulate = Color(0.45, 0.45, 0.5, 0.8) if count <= 0 else Color.WHITE
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
## The bar has a fill style we can recolor, and the 3 stars sit on it, one per third.
func _setup_bar() -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 0.97, 0.88)
	back.set_border_width_all(4)
	back.border_color = Color(0.23, 0.12, 0.08)
	back.set_corner_radius_all(14)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = BAR_COLOR
	_bar_fill.set_corner_radius_all(14)
	_bar_fill.set_border_width_all(4)
	_bar_fill.border_color = Color(0.23, 0.12, 0.08)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", _bar_fill)
	for i in 3:
		var star := StarIcon.new(STAR_SIZE)
		star.size = Vector2(STAR_SIZE, STAR_SIZE)
		bar_area.add_child(star)
		star_icons.append(star)


## Puts each star where it is lost on the bar (see PhaseTiming.star_fraction), so the bar
## drains past a star just as it dims. Star 1 (leftmost) is lost last, star 3 first.
func _place_stars(timing: PhaseTiming) -> void:
	for i in star_icons.size():
		var center_x := clampf(BAR_WIDTH * timing.star_fraction(i + 1), STAR_SIZE / 2.0, BAR_WIDTH - STAR_SIZE / 2.0)
		star_icons[i].position = Vector2(center_x - STAR_SIZE / 2.0, 6)


func start_timer(timing: PhaseTiming) -> void:
	timer_panel.visible = true
	_place_stars(timing)
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
	var warning := phase_timer.stars <= 1
	timer_label.add_theme_color_override("font_color", TIMER_WARNING if warning else TIMER_NORMAL)
	_bar_fill.bg_color = BAR_WARNING_COLOR if warning else BAR_COLOR
	if phase_timer.timing:
		bar.value = phase_timer.timing.bar_fraction(time_left)


func _on_star_lost(stars_left: int) -> void:
	_update_stars(true)
	star_lost.emit(stars_left)


func _update_stars(animate: bool) -> void:
	for i in star_icons.size():
		var earned := i < phase_timer.stars
		if star_icons[i].earned != earned or not animate:
			star_icons[i].set_earned(earned, animate and star_icons[i].earned != earned)
