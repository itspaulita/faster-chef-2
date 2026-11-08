class_name SoundToggles
extends CanvasLayer
## Two small buttons in the top-right corner: music on/off and sound effects on/off.
## Add to any screen with:  add_child(SoundToggles.new())
## It's its own layer, so popups (like the level map's) never cover it.

const MUSIC_ICON := preload("res://assets/images/misc/sfx-button.png")   # the note
const SFX_ICON := preload("res://assets/images/misc/sound-icon.png")     # the speaker
const OUTLINE := Color(0.23, 0.12, 0.08)
const ON_COLOR := Color(0.91, 0.6, 0.17)
const OFF_COLOR := Color(0.6, 0.6, 0.62)
const MUTED_SLASH := Color(0.75, 0.1, 0.1)
const BUTTON_SIZE := 72.0
const GAP := 12.0
const MARGIN := 24.0

var _buttons: Array[ToggleButton] = []


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# A full-screen holder that lets clicks through, with the row pinned to its top-right.
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_right = -MARGIN
	row.offset_left = -MARGIN - (BUTTON_SIZE * 2 + GAP)
	row.offset_top = MARGIN
	row.offset_bottom = MARGIN + BUTTON_SIZE
	screen.add_child(row)
	row.add_child(_make_button(Audio.MUSIC_BUS, MUSIC_ICON, "Music"))
	row.add_child(_make_button(Audio.SFX_BUS, SFX_ICON, "Sound effects"))
	Audio.mute_changed.connect(_refresh)
	_refresh()


func _make_button(bus: String, icon: Texture2D, tip: String) -> ToggleButton:
	var button := ToggleButton.new(bus, icon)
	button.tooltip_text = tip
	button.pressed.connect(Audio.toggle_mute.bind(bus))
	_buttons.append(button)
	return button


func _refresh() -> void:
	for button in _buttons:
		button.restyle()


## One square button with a picture: orange when on, grey with a red slash when muted.
class ToggleButton extends Button:
	var bus: String
	var picture: Texture2D

	func _init(bus_name: String, icon_texture: Texture2D) -> void:
		bus = bus_name
		picture = icon_texture
		custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		focus_mode = Control.FOCUS_NONE   # Enter / Space never press it by accident
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels

	func restyle() -> void:
		var color := OFF_COLOR if Audio.is_muted(bus) else ON_COLOR
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = color.lightened(0.15) if state == "hover" else color
			box.set_border_width_all(6)
			box.border_color = OUTLINE
			box.set_corner_radius_all(10)
			add_theme_stylebox_override(state, PixelUI.from_flat(box))
		queue_redraw()

	func _draw() -> void:
		var muted := Audio.is_muted(bus)
		# The 32px picture drawn at 40px (x1.25) in the middle; faded when muted.
		var icon_size := Vector2(40, 40)
		var tint := Color(1, 1, 1, 0.45) if muted else Color.WHITE
		draw_texture_rect(picture, Rect2((size - icon_size) / 2.0, icon_size), false, tint)
		if muted:
			draw_line(size * 0.22, size * 0.78, MUTED_SLASH, 6)
