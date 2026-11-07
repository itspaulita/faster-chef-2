class_name ScoreTally
extends CanvasLayer
## Shown after the dish is delivered: the stars from each phase, the multiplier, the final
## score, and the monster's reaction (heart = happy, smiley = neutral, sad face = poor).

signal continue_pressed

const EMOTES := preload("res://assets/images/misc/Emotes.png")
## Position of each bubble on Emotes.png (80x80 cells, 85px apart).
const EMOTE_REGIONS := {
	GameState.Mood.HAPPY: Rect2(355, 290, 80, 80),    # heart
	GameState.Mood.NEUTRAL: Rect2(15, 290, 80, 80),   # :)
	GameState.Mood.SAD: Rect2(100, 290, 80, 80),      # :(
}
const STAR_STEP := 0.3

## The monster shown with its reaction (first frame of its 2x2 sheet).
@export var monster_texture: Texture2D = preload("res://assets/images/monsters/monster-apple2.png")

@onready var banner: Control = %Banner
@onready var monster: TextureRect = %Monster
@onready var emote: TextureRect = %Emote
@onready var phase_rows: VBoxContainer = %PhaseRows
@onready var total_label: Label = %TotalLabel
@onready var score_label: Label = %ScoreLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue)
	banner.resized.connect(func(): banner.pivot_offset = banner.size / 2.0)
	emote.resized.connect(func(): emote.pivot_offset = emote.size / 2.0)


## Reads the stars from GameState and plays the tally for `xp` base points.
func show_tally(xp: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = monster_texture
	atlas.region = Rect2(Vector2.ZERO, monster_texture.get_size() / 2.0)
	monster.texture = atlas
	var emote_atlas := AtlasTexture.new()
	emote_atlas.atlas = EMOTES
	emote_atlas.region = EMOTE_REGIONS[GameState.mood()]
	emote.texture = emote_atlas

	for child in phase_rows.get_children():
		child.queue_free()
	total_label.modulate.a = 0.0
	score_label.modulate.a = 0.0
	score_label.text = ""
	emote.modulate.a = 0.0
	continue_button.disabled = true

	show()
	banner.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tween := create_tween()
	tween.tween_interval(0.4)
	for phase in GameState.phase_stars.keys():
		var stars: int = GameState.phase_stars[phase]
		var icons := _add_phase_row(phase)
		tween.tween_callback(_reveal_stars.bind(icons, stars))
		tween.tween_interval(maxf(stars, 1) * STAR_STEP + 0.3)

	var multiplier := GameState.multiplier()
	var score := GameState.final_score(xp)
	total_label.text = "%d STARS  =  x%d%s" % [GameState.total_stars(), multiplier,
			"  PERFECT!" if multiplier == GameState.PERFECT_MULTIPLIER else ""]
	tween.tween_callback(func() -> void: total_label.modulate.a = 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void: score_label.modulate.a = 1.0)
	tween.tween_method(func(v: float) -> void:
			score_label.text = "%d XP x %d = %d" % [xp, multiplier, int(round(v))],
			0.0, float(score), 0.8)
	tween.tween_interval(0.3)
	tween.tween_callback(_pop_emote)
	tween.tween_callback(func() -> void:
			continue_button.disabled = false
			continue_button.grab_focus())


func _add_phase_row(phase: int) -> Array[StarIcon]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "PHASE %d" % phase
	label.custom_minimum_size = Vector2(230, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var icons: Array[StarIcon] = []
	for i in GameState.MAX_STARS:
		var star := StarIcon.new(72)
		star.set_earned(false, false)
		row.add_child(star)
		icons.append(star)
	phase_rows.add_child(row)
	return icons


func _reveal_stars(icons: Array[StarIcon], stars: int) -> void:
	for i in stars:
		get_tree().create_timer(i * STAR_STEP).timeout.connect(func() -> void:
			icons[i].set_earned(true)
			icons[i].play_sparkle())


func _pop_emote() -> void:
	emote.modulate.a = 1.0
	create_tween().tween_property(emote, "scale", Vector2.ONE, 0.35) \
			.from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_continue() -> void:
	hide()
	continue_pressed.emit()
