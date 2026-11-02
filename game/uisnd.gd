extends RefCounted
# Tiny procedural UI / ambience sounds (no audio files). Streams are built once and cached.

const RATE := 22050
static var _cache := {}
static var _player: AudioStreamPlayer = null
static var muted := false


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func get_stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	match name:
		"click":
			var n := int(RATE * 0.11)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				var f := 780.0 + 900.0 * minf(t / 0.03, 1.0)
				s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.01 * t) * 0.2 + (rng.randf() - 0.5) * 0.25 * exp(-t * 120.0)) * exp(-t * 34.0)
		"hover":
			var n := int(RATE * 0.06)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				s[i] = sin(TAU * 1500.0 * t) * 0.25 * exp(-t * 60.0)
		"back":
			var n := int(RATE * 0.14)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				s[i] = (sin(TAU * (900.0 - 500.0 * t / 0.14) * t) * 0.5) * exp(-t * 26.0)
		"whoosh":
			var n := int(RATE * 0.55)
			s.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / n
				lp = lp * (0.55 + 0.4 * t) + (rng.randf() - 0.5) * (0.45 - 0.4 * t)
				s[i] = lp * sin(PI * t) * 1.6
		"confirm":
			var n := int(RATE * 1.1)
			s.resize(n)
			for i in n:
				var t := float(i) / RATE
				var v := 0.0
				var notes := [392.0, 493.9, 587.3, 784.0]
				for k in notes.size():
					var st: float = k * 0.07
					if t > st:
						var tt: float = t - st
						v += (sin(TAU * notes[k] * tt) + 0.4 * sin(TAU * notes[k] * 2.0 * tt) + 0.2 * sin(TAU * notes[k] * 3.01 * tt)) * exp(-tt * 3.2) * 0.22
				s[i] = v
		"bell":
			var n := int(RATE * 5.0)
			s.resize(n)
			var parts := [[1.0, 1.0, 0.9], [2.0, 0.6, 1.4], [2.76, 0.5, 1.8], [5.4, 0.3, 2.6], [8.93, 0.15, 3.5]]
			for i in n:
				var t := float(i) / RATE
				var v := 0.0
				for p in parts:
					v += sin(TAU * 196.0 * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
				s[i] = v * 0.35 * minf(t / 0.004, 1.0)
		"wind":
			var n := RATE * 6
			s.resize(n)
			var lp := 0.0
			var lp2 := 0.0
			for i in n:
				var t := float(i) / RATE
				lp += ((rng.randf() - 0.5) - lp) * 0.035
				lp2 += (lp - lp2) * 0.08
				s[i] = lp2 * (2.2 + 1.2 * sin(TAU * t / 6.0 * 2.0) + 0.6 * sin(TAU * t / 6.0 * 3.0))
			var xf := int(RATE * 0.4)
			for i in xf:
				var a := float(i) / xf
				s[i] = s[i] * a + s[n - xf + i] * (1.0 - a)
			s.resize(n - xf)
			return _store(name, _wav(s, true))
		"crackle":
			var n := RATE * 4
			s.resize(n)
			var env := 0.0
			for i in n:
				if rng.randf() < 0.0009:
					env = rng.randf_range(0.3, 1.0)
				env *= 0.9
				s[i] = (rng.randf() - 0.5) * env * 0.9 + (rng.randf() - 0.5) * 0.02
			return _store(name, _wav(s, true))
		_:
			s.resize(10)
	return _store(name, _wav(s))


static func _store(name: String, w: AudioStreamWAV) -> AudioStreamWAV:
	_cache[name] = w
	return w


static func play(owner: Node, name: String, vol := -8.0, pitch := 1.0) -> void:
	if muted or owner == null or not owner.is_inside_tree():
		return
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		owner.get_tree().root.add_child(_player)
	# one-shot players so sounds can overlap
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(name)
	p.volume_db = vol
	p.pitch_scale = pitch
	owner.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
