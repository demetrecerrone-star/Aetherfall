extends Node
## Tiny procedural ambient music bed that survives Title -> Loading transitions.
## No copyrighted tracks or external downloads; music fades out on world entry.
const MIX_RATE := 22050.0
const MAX_BLOCK := 2048

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _time := 0.0
var _volume := 0.0
var _target_volume := 0.0

func _ready() -> void:
	var tone := AudioStreamGenerator.new()
	tone.mix_rate = MIX_RATE
	tone.buffer_length = .30
	_player = AudioStreamPlayer.new()
	_player.name = "AetherfallAmbientTheme"
	_player.stream = tone
	_player.volume_db = -13.0
	add_child(_player)
	set_process(false)

func play_menu() -> void:
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		_volume = 0.0
	_target_volume = .36
	set_process(true)

func fade_out() -> void:
	_target_volume = 0.0

func _process(delta: float) -> void:
	_volume = move_toward(_volume, _target_volume, delta * .8)
	if _volume <= .0001 and _target_volume <= .0001:
		_player.stop()
		_playback = null
		set_process(false)
		return
	if _playback == null:
		return
	var count: int = mini(_playback.get_frames_available(), MAX_BLOCK)
	if count <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(count)
	var step := 1.0 / MIX_RATE
	for i in range(count):
		var t := _time + float(i) * step
		# Open fifth + soft minor third; gently varying chord shimmer, no percussion.
		var drone := sin(TAU * 110.0 * t) * .28
		var fifth := sin(TAU * 164.8138 * t) * .20
		var octave := sin(TAU * 220.0 * t) * .13
		var upper := sin(TAU * 261.6256 * t) * .075
		var shimmer := sin(TAU * 329.6276 * t) * .042
		var breath := .72 + .16*sin(TAU*.055*t) + .09*sin(TAU*.083*t)
		var sample := (drone + fifth + octave + upper + shimmer) * breath * _volume
		frames[i] = Vector2(sample * (1.0+.075*sin(TAU*.12*t)),
			sample * (1.0+.075*sin(TAU*.12*t+1.6)))
	_playback.push_buffer(frames)
	_time += float(count) * step
