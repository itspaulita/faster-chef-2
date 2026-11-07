extends Node
## Autoload "Audio": plays every sound effect and the music, by name.
##
##   Audio.sfx("pickup")            # one-shot; names with variants pick one at random
##   Audio.sfx("chop", 2)           # or a specific variant (0-based)
##   Audio.music("level-1")         # starts looping (does nothing if it's already playing)
##   Audio.looping_stream("boiling") # a looping copy of a sound, for a node's own player
##
## It keeps running while the game is paused (menus click, the pause sound plays), and
## every Button in the game gets the click sound automatically.

const SFX_DIR := "res://assets/sfx/FC_sfx_"
const MUSIC_DIR := "res://assets/music/"
const SFX_VOICES := 12
const MUSIC_VOLUME_DB := -8.0
const MUSIC_FADE := 0.6

## name -> the file names (after "FC_sfx_" and before ".wav"). More than one = random variant.
const SOUNDS := {
	"click": ["UI_click"],
	"pause": ["UI_pause"],
	"unpause": ["UI_unpause"],
	"wrong": ["UI_wrong"],
	"countdown": ["UI_countdown_5s"],
	"lose": ["UI_gameover_lose"],
	"win": ["UI_gameover_win"],
	"star": ["UI_scoring_1"],
	"score": ["UI_scoring_2"],
	"meow": ["cat_meow_friendly"],
	"cooked": ["cooking_finished_1"],
	"boiling": ["cooking_inprogress_boiling"],
	"frying": ["cooking_inprogress_frying"],
	"drop": ["ingredient_drop_1", "ingredient_drop_2", "ingredient_drop_3"],
	"drop_plate": ["ingredient_drop_plate_1", "ingredient_drop_plate_2"],
	"pickup": ["ingredient_pickup_1", "ingredient_pickup_2", "ingredient_pickup_3", "ingredient_pickup_4"],
	"minigame_open": ["minigame_open_1"],
	"all_chopped": ["minigame_allchopped_1"],
	"chop": ["player_chopping_1", "player_chopping_2", "player_chopping_3"],
	"plated": ["player_plating_done"],
	"plating": ["player_plating_progress"],
	"walk": ["player_walk_1", "player_walk_2", "player_walk_3"],
	"walk_soft": ["player_walk-2_1", "player_walk-2_2", "player_walk-2_3"],
}
## Some files are recorded very quietly; this brings them up (dB). Missing = 0.
const GAIN_DB := {
	"click": 14.0,
	"walk": 9.0,
	"walk_soft": 14.0,
}

var _voices: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	# Every button, in every scene, clicks.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(sfx.bind("click"))


## Plays a one-shot sound effect. `variant` -1 picks one at random (it avoids repeating the
## last one). Returns false if there is no such sound.
func sfx(sound: String, variant := -1) -> bool:
	if not SOUNDS.has(sound):
		push_warning("Audio: no sound called '%s'" % sound)
		return false
	var files: Array = SOUNDS[sound]
	var index := variant if variant >= 0 else randi() % files.size()
	index = clampi(index, 0, files.size() - 1)
	var voice := _free_voice()
	voice.stream = _load(SFX_DIR + files[index] + ".wav")
	voice.volume_db = GAIN_DB.get(sound, 0.0)
	voice.play()
	return true


## A looping copy of a sound, to put on a node's own AudioStreamPlayer (so the sound
## stops with the node and freezes when the game is paused).
func looping_stream(sound: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = _load(SFX_DIR + SOUNDS[sound][0] + ".wav").duplicate()
	_make_loop(stream)
	return stream


## Starts a music track ("intro", "level-1", ...), fading out whatever played before.
## Asking for the track that is already playing does nothing, so scenes can just ask.
func music(track: String) -> void:
	if track == _music_name and _music_player.playing:
		return
	_music_name = track
	if _music_tween:
		_music_tween.kill()
	if track == "":
		stop_music()
		return
	var stream: AudioStreamWAV = _load(MUSIC_DIR + track + ".wav").duplicate()
	_make_loop(stream)
	_music_tween = create_tween()
	if _music_player.playing:
		_music_tween.tween_property(_music_player, "volume_db", -60.0, MUSIC_FADE)
	_music_tween.tween_callback(func() -> void:
		_music_player.stream = stream
		_music_player.volume_db = MUSIC_VOLUME_DB
		_music_player.play())


func stop_music(fade := MUSIC_FADE) -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -60.0, fade)
	_music_tween.tween_callback(_music_player.stop)


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	return _voices[0]   # all busy: cut the oldest-assigned one


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


func _make_loop(stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
