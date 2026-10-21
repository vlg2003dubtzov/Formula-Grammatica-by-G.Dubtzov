extends Node
## Все звуки синтезируются при запуске — звуковых файлов в игре нет.

const RATE := 22050

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _engine: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_streams["correct"] = _notes([880.0, 1318.5], [0.09, 0.32], 0.45)
	_streams["finish"] = _notes([523.3, 659.3, 784.0, 1046.5], [0.13, 0.13, 0.13, 0.7], 0.4)
	_streams["beep"] = _notes([660.0], [0.25], 0.4)
	_streams["go"] = _notes([1320.0], [0.55], 0.4)
	_streams["click"] = _notes([1500.0], [0.04], 0.2)
	_streams["crash"] = _crash()
	_streams["nitro"] = _whoosh()
	for i in 6:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voices.append(v)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _engine_loop()
	_engine.volume_db = -15.0
	add_child(_engine)


func play(id: String, pitch := 1.0) -> void:
	var s: AudioStream = _streams.get(id)
	if s == null:
		return
	var voice := _voices[0]
	for v in _voices:
		if not v.playing:
			voice = v
			break
	voice.stream = s
	voice.pitch_scale = pitch
	voice.play()


## Гул мотора; rev от 0 (холостой) до 1 (нитро).
func engine(on: bool, rev := 0.0) -> void:
	if on != _engine.playing:
		if on:
			_engine.play()
		else:
			_engine.stop()
	_engine.pitch_scale = 0.55 + clampf(rev, 0.0, 1.0) * 1.1


func _notes(freqs: Array, durs: Array, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n in freqs.size():
		var f := float(freqs[n])
		var d := float(durs[n])
		for i in int(d * RATE):
			var t := float(i) / RATE
			var env := minf(1.0, t * 200.0) * exp(-t * 6.0 / d)
			out.append((sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t)) * env * vol)
	return _wav(out)


func _crash() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var low := 0.0
	for i in int(0.6 * RATE):
		var t := float(i) / RATE
		low += (_rng.randf_range(-1.0, 1.0) - low) * 0.25
		var thump := sin(TAU * 55.0 * t) * exp(-t * 9.0)
		out.append((low * 1.2 * exp(-t * 6.0) + thump * 0.8) * 0.6)
	return _wav(out)


func _whoosh() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var length := 0.9
	var phase := 0.0
	var low := 0.0
	for i in int(length * RATE):
		var t := float(i) / RATE
		var k := t / length
		phase += (180.0 + 700.0 * k * k) / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		low += (_rng.randf_range(-1.0, 1.0) - low) * (0.05 + 0.4 * k)
		var env := minf(1.0, t * 8.0) * (1.0 - k)
		out.append((saw * 0.35 + low * 0.9) * env * 0.5)
	return _wav(out)


## Полсекунды гула: 90 и 30 Гц укладываются в неё целым числом периодов, поэтому
## петля без щелчка.
func _engine_loop() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for i in int(RATE * 0.5):
		var t := float(i) / RATE
		var v := 0.0
		for h in range(1, 7):
			v += sin(TAU * 90.0 * h * t) / h
		v *= 0.8 + 0.2 * sin(TAU * 30.0 * t)
		out.append(v * 0.22)
	return _wav(out, true)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s
