extends Node
## Procedural ship audio with zero asset dependencies.
##
## The engine hum is a live oscillator pushed into an AudioStreamGenerator,
## tracking throttle every frame. One-shots (laser, explosion, jump sweep,
## dock clunk, purchase blip) are synthesized into AudioStreamWAV buffers at
## startup. All generation is pure math, so it runs headless in tests.

const MIX_RATE := 22050

var _engine: AudioStreamPlayer
var _engine_playback: AudioStreamGeneratorPlayback
var _engine_phase := 0.0
var _throttle := 0.0
var _sfx := {}


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.25
	_engine = AudioStreamPlayer.new()
	_engine.stream = gen
	_engine.volume_db = -18.0
	add_child(_engine)
	_engine.play()
	_engine_playback = _engine.get_stream_playback() as AudioStreamGeneratorPlayback
	_sfx[&"laser"] = _sweep(880.0, 220.0, 0.12, 0.5, true)
	_sfx[&"explosion"] = _noise_burst(0.6, 0.7)
	_sfx[&"jump"] = _sweep(150.0, 900.0, 0.7, 0.4, false)
	_sfx[&"dock"] = _sweep(220.0, 140.0, 0.2, 0.5, false)
	_sfx[&"coin"] = _sweep(660.0, 990.0, 0.09, 0.4, false)


## 0..1 throttle driving engine pitch and grit. Called every physics tick.
func set_throttle(value: float) -> void:
	_throttle = clampf(value, 0.0, 1.0)


func play_sfx(id: StringName) -> void:
	if not _sfx.has(id):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _sfx[id]
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _process(_delta: float) -> void:
	if _engine_playback == null:
		return
	var frequency := 55.0 + _throttle * 75.0
	var available := _engine_playback.get_frames_available()
	var count := mini(available, 512)
	for i in count:
		_engine_phase += TAU * frequency / MIX_RATE
		var tone := sin(_engine_phase) * 0.25
		var grit := (randf() * 2.0 - 1.0) * 0.06 * _throttle
		_engine_playback.push_frame(Vector2(tone + grit, tone + grit))


## Pitched sweep; square=true gives the laser its edge.
func _sweep(freq_from: float, freq_to: float, duration: float, volume: float, square: bool) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / frames
		phase += TAU * lerpf(freq_from, freq_to, t) / MIX_RATE
		var sample := sin(phase)
		if square:
			sample = signf(sample) * 0.7
		sample *= (1.0 - t) * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)


## Decaying noise with a low thump underneath.
func _noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / frames
		phase += TAU * 60.0 / MIX_RATE
		var sample := ((randf() * 2.0 - 1.0) * 0.7 + sin(phase) * 0.5) * exp(-4.0 * t) * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
