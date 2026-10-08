extends Node
# Procedural sound effects + music (no audio files needed)

const RATE := 22050
var lib := {}
var pool: Array = []
var ui: AudioStreamPlayer
var music: AudioStreamPlayer


func _ready() -> void:
	_build_lib()
	for i in 20:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 140.0
		add_child(p)
		pool.append(p)
	ui = AudioStreamPlayer.new()
	add_child(ui)
	music = AudioStreamPlayer.new()
	music.stream = lib["music"]
	music.volume_db = -11.0
	add_child(music)
	music.play()


func play(sound: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	if not lib.has(sound):
		return
	for p in pool:
		if not p.playing:
			p.stream = lib[sound]
			p.global_position = pos
			p.volume_db = vol
			p.pitch_scale = pitch * randf_range(0.92, 1.08)
			p.play()
			return


func play_ui(sound: String, vol := 0.0) -> void:
	if lib.has(sound):
		ui.stream = lib[sound]
		ui.volume_db = vol
		ui.play()


func _wav(d: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(d.size() * 2)
	for i in d.size():
		b.encode_s16(i * 2, int(clampf(d[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = d.size()
	return w


func _gen(len_s: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(len_s * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		d[i] = fn.call(float(i) / RATE)
	return _wav(d, loop)


func _nz() -> float:
	return randf() * 2.0 - 1.0


func _build_lib() -> void:
	var tau := TAU
	# sword clang
	lib["clang"] = _gen(0.5, func(t):
		var e := exp(-t * 13.0)
		return 0.55 * (e * (0.4 * sin(tau * 1900.0 * t) + 0.3 * sin(tau * 2870.0 * t) + 0.2 * sin(tau * 4100.0 * t)) + 0.5 * _nz() * exp(-t * 70.0)))
	# body thud
	lib["thud"] = _gen(0.35, func(t):
		return 0.8 * (sin(tau * 70.0 * t) * exp(-t * 11.0) + 0.4 * _nz() * exp(-t * 45.0)))
	# death
	lib["death"] = _gen(0.6, func(t):
		return 0.7 * (sin(tau * 90.0 * t * exp(-t * 2.0)) * exp(-t * 5.0) + 0.3 * _nz() * exp(-t * 20.0)))
	# bow twang
	lib["twang"] = _gen(0.6, func(t):
		return 0.5 * (sin(tau * 196.0 * t + 2.0 * sin(tau * 7.0 * t)) * exp(-t * 9.0) + 0.5 * sin(tau * 392.0 * t) * exp(-t * 14.0)))
	# war horn
	lib["horn"] = _gen(2.2, func(t):
		var f := 116.0 * (1.0 + 0.004 * sin(tau * 5.0 * t))
		var s := 0.0
		for k in range(1, 7):
			s += sin(tau * f * k * t) / k
		var env: float = minf(t / 0.25, 1.0) * clampf((2.2 - t) / 0.7, 0.0, 1.0)
		return 0.5 * s * env * 0.6)
	# ambient war music: 8s seamless loop (drone + choir pad + drums)
	lib["music"] = _gen(8.0, func(t):
		var drone := 0.22 * sin(tau * 55.0 * t) + 0.14 * sin(tau * 82.5 * t) + (0.1 + 0.05 * sin(tau * 0.25 * t)) * sin(tau * 110.0 * t)
		var pad := 0.05 * sin(tau * 220.0 * t) * (0.5 + 0.5 * sin(tau * 0.125 * t)) + 0.03 * sin(tau * 330.0 * t)
		var tt := fmod(t, 0.5)
		var amp := 0.75 if fmod(t, 1.0) < 0.5 else 0.4
		var drum := amp * sin(tau * 52.0 * tt) * exp(-tt * 9.0)
		return clampf(drone + pad + drum, -1.0, 1.0)
	, true)
