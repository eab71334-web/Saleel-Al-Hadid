extends Control
# Animated menu backdrop: dusk sky, stars, drifting clouds, castle silhouette with flickering torches, rising embers.

var t := 0.0
var embers: Array = []
var stars: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		stars.append(Vector3(rng.randf(), rng.randf() * 0.55, rng.randf()))
	for i in 46:
		embers.append(Vector4(rng.randf(), rng.randf(), 0.03 + rng.randf() * 0.07, rng.randf() * 6.0))


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	# sky gradient
	var bands := 24
	for i in bands:
		var f := float(i) / bands
		var c := Color(0.07, 0.05, 0.16).lerp(Color(0.62, 0.27, 0.2), pow(f, 2.2))
		draw_rect(Rect2(0, h * f, w, h / bands + 2.0), c)
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * (1.0 + s.z * 2.0) + s.x * 40.0)
		draw_circle(Vector2(s.x * w, s.y * h), 1.2 + s.z * 1.4, Color(1, 0.95, 0.8, 0.25 + 0.6 * tw * (1.0 - s.y)))
	# moon
	draw_circle(Vector2(w * 0.8, h * 0.18), h * 0.06, Color(1, 0.93, 0.75, 0.95))
	draw_circle(Vector2(w * 0.8 + h * 0.02, h * 0.17), h * 0.055, Color(0.1, 0.07, 0.2, 0.9))
	# clouds
	for i in 5:
		var cx := fposmod(t * (8.0 + i * 3.0) + i * w * 0.27, w + 400.0) - 200.0
		var cy := h * (0.12 + 0.09 * i)
		for k in 4:
			draw_circle(Vector2(cx + k * 46.0, cy + sin(k * 1.7) * 10.0), 40.0 - k * 4.0, Color(0.9, 0.55, 0.5, 0.10))
	# far hills
	var hills := PackedVector2Array([Vector2(0, h)])
	for i in 41:
		var x := w * i / 40.0
		hills.append(Vector2(x, h * 0.78 - 30.0 * sin(i * 0.55 + 1.0) - 18.0 * sin(i * 1.3)))
	hills.append(Vector2(w, h))
	draw_colored_polygon(hills, Color(0.12, 0.07, 0.14))
	# castle silhouette (centre-right)
	var base := h * 0.82
	var cx0 := w * 0.5
	var u := h * 0.05
	var col := Color(0.05, 0.035, 0.08)
	draw_rect(Rect2(cx0 - u * 7, base - u * 3.2, u * 14, u * 3.4), col)
	for i in 8:
		draw_rect(Rect2(cx0 - u * 7 + i * u * 2.0, base - u * 3.2 - u * 0.5, u * 1.0, u * 0.5), col)
	for side in [-1.0, 1.0]:
		var tx: float = cx0 + side * u * 7.0
		draw_rect(Rect2(tx - u * 1.3, base - u * 6.0, u * 2.6, u * 6.2), col)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - u * 1.7, base - u * 6.0), Vector2(tx, base - u * 8.4), Vector2(tx + u * 1.7, base - u * 6.0)]), col)
	draw_rect(Rect2(cx0 - u * 2.0, base - u * 7.0, u * 4.0, u * 7.2), col)
	draw_colored_polygon(PackedVector2Array([Vector2(cx0 - u * 2.4, base - u * 7.0), Vector2(cx0, base - u * 10.0), Vector2(cx0 + u * 2.4, base - u * 7.0)]), col)
	# glowing windows + flag
	for wp in [Vector2(cx0, base - u * 5.2), Vector2(cx0 - u * 7, base - u * 4.4), Vector2(cx0 + u * 7, base - u * 4.4)]:
		draw_rect(Rect2(wp.x - u * 0.2, wp.y, u * 0.4, u * 0.7), Color(1, 0.75, 0.3, 0.7 + 0.2 * sin(t * 3.0 + wp.x)))
	var fp := Vector2(cx0, base - u * 10.0)
	draw_line(fp, fp + Vector2(0, -u * 1.6), col, 3.0)
	var fl := PackedVector2Array()
	for i in 7:
		fl.append(fp + Vector2(i * u * 0.22, -u * 1.6 + sin(t * 4.0 + i * 0.7) * 5.0))
	for i in range(6, -1, -1):
		fl.append(fp + Vector2(i * u * 0.22, -u * 1.0 + sin(t * 4.0 + i * 0.7) * 5.0))
	draw_colored_polygon(fl, Color(0.8, 0.15, 0.15))
	# torches
	for tx2 in [cx0 - u * 3.0, cx0 + u * 3.0]:
		var fh := 0.7 + 0.3 * sin(t * 11.0 + tx2) * sin(t * 7.3)
		draw_circle(Vector2(tx2, base - u * 2.2), u * 0.9 * fh, Color(1, 0.55, 0.15, 0.18))
		draw_circle(Vector2(tx2, base - u * 2.2), u * 0.35 * fh, Color(1, 0.8, 0.3, 0.9))
	# foreground ground
	draw_rect(Rect2(0, base, w, h - base), Color(0.04, 0.03, 0.06))
	# embers
	for e in embers:
		var ph := fposmod(t * e.z * 3.0 + e.w, 1.0)
		var ex: float = e.x * w + sin(t + e.w * 3.0) * 30.0
		var ey: float = h - ph * h * 0.8
		draw_circle(Vector2(ex, ey), 2.0 + e.z * 14.0, Color(1, 0.6 + ph * 0.3, 0.2, (1.0 - ph) * 0.8))
	# vignette
	draw_rect(Rect2(0, 0, w, h * 0.08), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, h * 0.92, w, h * 0.08), Color(0, 0, 0, 0.45))
