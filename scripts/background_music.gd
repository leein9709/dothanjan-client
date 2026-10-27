extends Node

const TRACK_BYTES: String = "res://assets/audio/dothanjan-bgm.mp3.bytes"
const REPEAT_GAP_SECONDS: float = 2.0
const VOLUME_DB: float = -10.0

var player: AudioStreamPlayer
var repeat_timer: Timer

func _ready() -> void:
	# One persistent player for login, setup, transitions, cafe and logout.
	# Scene changes must not restart either the song or its two-second rest.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(TRACK_BYTES)
	if bytes.is_empty():
		push_error("Background music asset could not be read")
		return
	var track := AudioStreamMP3.new()
	track.data = bytes
	track.loop = false
	if track.get_length() <= 0.0:
		push_error("Background music asset is not a valid MP3 stream")
		return
	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.stream = track
	player.volume_db = VOLUME_DB
	player.max_polyphony = 1
	add_child(player)
	repeat_timer = Timer.new()
	repeat_timer.name = "RepeatGap"
	repeat_timer.wait_time = REPEAT_GAP_SECONDS
	repeat_timer.one_shot = true
	repeat_timer.ignore_time_scale = true
	add_child(repeat_timer)
	player.finished.connect(_on_track_finished)
	repeat_timer.timeout.connect(_play_from_start)
	_play_from_start()

func _on_track_finished() -> void:
	# Native looping is disabled so silence lasts two seconds after the real end.
	repeat_timer.start()

func _play_from_start() -> void:
	if not player.playing:
		player.play(0.0)
