extends RefCounted
# Procedural epic orchestral music (A minor): taiko war drums, swelling strings, choir pad, heroic brass.
# Everything is synthesised - no audio files. Build it in a thread (takes a moment on phones).

const RATE := 12000


static func _f(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


static var _tabs := {}


static func _table(kind: int) -> PackedFloat32Array:
	if _tabs.has(kind):
		return _tabs[kind]
	var hs: Array = [1.0, 0.5, 0.33, 0.25, 0.2, 0.16]
	if kind == 2:
		hs = [1.0, 0.55, 0.12, 0.3]
	elif kind == 3:
		hs = [1.0, 0.4, 0.15]
	var tb := PackedFloat32Array()
	tb.resize(1024)
	for i in 1024:
		var ph := TAU * float(i) / 1024.0
		var v := 0.0
		for h in hs.size():
			v += hs[h] * sin(ph * (h + 1))
		tb[i] = v
	_tabs[kind] = tb
	return tb


static func _note(buf: PackedFloat32Array, t0: float, dur: float, midi: float, amp: float, kind: int) -> void:
	var f0 := _f(midi)
	var i0 := int(t0 * RATE)
	var n := int((dur + 0.8) * RATE)
	var atk := 0.03
	var rel := 0.12
	if kind == 1:
		atk = 0.5; rel = 0.6
	elif kind == 2:
		atk = 0.7; rel = 0.8
	elif kind == 3:
		atk = 0.02; rel = 0.2
	var tb := _table(kind)
	var sz := buf.size()
	var inc := f0 / RATE * 1024.0
	var inc2 := inc * 1.005
	var two := kind == 1
	var ph := 0.0
	var ph2 := 0.0
	var inv := 1.0 / RATE
	for k in n:
		var t := k * inv
		var env := minf(t / atk, 1.0) * minf(maxf(dur + rel - t, 0.0) / rel, 1.0)
		if env <= 0.0:
			break
		var v := tb[int(ph) & 1023]
		if two:
			v = (v + tb[int(ph2) & 1023]) * 0.5
		buf[(i0 + k) % sz] += v * env * amp
		var vib := 1.0
		if kind == 0 and t > 0.25:
			vib = 1.0 + 0.004 * sin(TAU * 5.3 * t)
		ph += inc * vib
		ph2 += inc2


static func _drum(buf: PackedFloat32Array, t0: float, amp: float, low := true) -> void:
	var i0 := int(t0 * RATE)
	var n := int(0.55 * RATE) if low else int(0.18 * RATE)
	for k in n:
		var idx := (i0 + k) % buf.size()
		var t := float(k) / RATE
		var s := 0.0
		if low:
			s = sin(TAU * (42.0 + 70.0 * exp(-t * 28.0)) * t) * exp(-t * 6.0) + 0.35 * (randf() * 2.0 - 1.0) * exp(-t * 55.0)
		else:
			s = (randf() * 2.0 - 1.0) * exp(-t * 28.0) * 0.6 + sin(TAU * 190.0 * t) * exp(-t * 30.0) * 0.5
		buf[idx] += s * amp


# bpm: tempo. power 0..1: how heavy (more drums, louder brass). Returns a seamless 8-bar loop.
static func compose(bpm: float, power: float) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var bars := 8
	var total := beat * 4.0 * bars
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE))
	var roots := [45, 41, 48, 43]
	var chords := [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]
	var mel := [
		[[0.0, 1.5, 76], [1.5, 0.5, 79], [2.0, 2.0, 81], [4.0, 1.0, 79], [5.0, 1.0, 76], [6.0, 2.0, 74]],
		[[0.0, 1.5, 77], [1.5, 0.5, 76], [2.0, 2.0, 77], [4.0, 1.0, 81], [5.0, 1.0, 79], [6.0, 2.0, 77]],
		[[0.0, 1.5, 79], [1.5, 0.5, 84], [2.0, 2.0, 83], [4.0, 1.0, 79], [5.0, 1.0, 76], [6.0, 2.0, 79]],
		[[0.0, 1.5, 74], [1.5, 0.5, 79], [2.0, 2.0, 83], [4.0, 1.0, 81], [5.0, 1.0, 79], [6.0, 2.0, 78]],
	]
	for c in 4:
		var t0: float = c * 8.0 * beat
		for m in chords[c]:
			_note(buf, t0, 8.0 * beat, m, 0.075, 1)
			_note(buf, t0, 8.0 * beat, m + 12, 0.04, 2)
		_note(buf, t0, 4.0 * beat, roots[c], 0.2, 3)
		_note(buf, t0 + 4.0 * beat, 4.0 * beat, roots[c], 0.2, 3)
		for n in mel[c]:
			var s0: float = t0 + n[0] * beat
			_note(buf, s0, n[1] * beat * 0.95, float(n[2]) - 12.0, 0.09 + 0.05 * power, 0)
			_note(buf, s0, n[1] * beat * 0.95, float(n[2]), 0.07 + 0.05 * power, 0)
	# drums
	for b in bars * 4:
		var tb := b * beat
		var strong := b % 4 == 0
		_drum(buf, tb, 0.85 if strong else 0.5)
		if power > 0.4:
			_drum(buf, tb + beat * 0.5, 0.35, false)
		if power > 0.7:
			_drum(buf, tb + beat * 0.75, 0.3)
		if b % 16 >= 14:   # fills before the phrase repeats
			_drum(buf, tb + beat * 0.33, 0.45)
			_drum(buf, tb + beat * 0.66, 0.5)
	# soft normalise
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var k := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(tanh(buf[i] * k * 1.2), -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w
