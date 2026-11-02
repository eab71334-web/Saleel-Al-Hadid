extends Control
# Animated menu backdrop: dusk sky, moon, parallax mountains, a lit castle with waving banners,
# a marching army on the ridge, fog, torches and rising embers.

var t := 0.0
var embers: Array = []
var stars: Array = []
var pines: Array = []
var shoot := Vector3(-1, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		stars.append(Vector3(rng.randf(), rng.randf() * 0.6, rng.randf()))
	for i in 60:
		embers.append(Vector4(rng.randf(), rng.randf(), 0.03 + rng.randf() * 0.07, rng.randf() * 6.0))
	for i in 38:
		pines.append(Vector3(rng.randf(), 0.7 + rng.randf() * 0.6, rng.randf()))


func _process(dt: float) -> void:
	t += dt
	if shoot.x < 0.0 and fmod(t, 11.0) < dt:
		shoot = Vector3(0.1 + randf() * 0.5, 0.05 + randf() * 0.2, 0.0)
	if shoot.x >= 0.0:
		shoot.z += dt
		if shoot.z > 0.9:
			shoot = Vector3(-1, 0, 0)
	queue_redraw()


func _ridge(w: float, h: float, base: float, amp: float, seed_: float, col: Color, snow := false) -> void:
	var pts := PackedVector2Array([Vector2(0, h)])
	var n := 60
	for i in n + 1:
		var x := w * i / float(n)
		var y := base - amp * (0.55 * sin(i * 0.23 + seed_) + 0.3 * sin(i * 0.61 + seed_ * 2.3) + 0.15 * sin(i * 1.7 + seed_ * 5.1))
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, col)
	if snow:
		for i in range(1, n):
			var p: Vector2 = pts[i + 1]
			if p.y < base - amp * 0.55:
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(-w * 0.012, amp * 0.22), p + Vector2(w * 0.012, amp * 0.22)]), Color(0.85, 0.8, 0.9, 0.22))


func _tower(cx: float, base: float, tw: float, th: float, roof: float, col: Color, lit: Color, seed_: float) -> void:
	draw_rect(Rect2(cx - tw * 0.5, base - th, tw, th), col)
	# battlement ring
	var cw := tw / 5.0
	for i in 3:
		draw_rect(Rect2(cx - tw * 0.6 + i * tw * 0.6, base - th - cw * 0.9, cw * 1.2, cw * 0.9), col)
	draw_rect(Rect2(cx - tw * 0.6, base - th - cw * 0.1, tw * 1.2, cw * 0.35), col)
	# conical roof
	draw_colored_polygon(PackedVector2Array([Vector2(cx - tw * 0.62, base - th - cw * 0.9), Vector2(cx, base - th - roof), Vector2(cx + tw * 0.62, base - th - cw * 0.9)]), col.lightened(0.04))
	# windows
	var wy := base - th * 0.7
	for k in 3:
		var fl := 0.65 + 0.35 * sin(t * (2.0 + k) + seed_ + k * 2.0)
		var wr := Rect2(cx - cw * 0.35, wy + k * th * 0.2, cw * 0.7, cw * 1.2)
		draw_rect(Rect2(wr.position - Vector2(cw * 0.6, cw * 0.6), wr.size + Vector2(cw * 1.2, cw * 1.2)), Color(lit.r, lit.g, lit.b, 0.07 * fl))
		draw_rect(wr, Color(lit.r, lit.g, lit.b, 0.9 * fl))
	# banner
	var fp := Vector2(cx, base - th - roof)
	draw_line(fp, fp + Vector2(0, -roof * 0.55), Color(0.2, 0.15, 0.1), 2.0)
	var fl2 := PackedVector2Array()
	for i in 8:
		fl2.append(fp + Vector2(2 + i * tw * 0.07, -roof * 0.55 + sin(t * 4.5 + i * 0.7 + seed_) * 3.5 * (i / 7.0)))
	for i in range(7, -1, -1):
		fl2.append(fp + Vector2(2 + i * tw * 0.07, -roof * 0.28 + sin(t * 4.5 + i * 0.7 + seed_) * 3.5 * (i / 7.0)))
	draw_colored_polygon(fl2, Color(0.78, 0.12, 0.12))


func _knight(x: float, y: float, s: float, col: Color, step: float, banner := false) -> void:
	var bob := absf(sin(step)) * s * 0.18
	y -= bob
	draw_rect(Rect2(x - s * 0.22, y - s * 1.0, s * 0.44, s * 0.8), col)                 # body
	draw_circle(Vector2(x, y - s * 1.18), s * 0.2, col)                                   # head
	draw_rect(Rect2(x - s * 0.2, y - s * 0.22, s * 0.16, s * 0.24 + bob), col)           # legs
	draw_rect(Rect2(x + s * 0.04, y - s * 0.22, s * 0.16, s * 0.24 - bob * 0.2), col)
	draw_line(Vector2(x + s * 0.3, y - s * 0.2), Vector2(x + s * 0.34, y - s * 2.1), col, maxf(1.5, s * 0.07))  # spear
	draw_colored_polygon(PackedVector2Array([Vector2(x + s * 0.34, y - s * 2.1), Vector2(x + s * 0.28, y - s * 1.9), Vector2(x + s * 0.4, y - s * 1.9)]), col)
	draw_circle(Vector2(x - s * 0.3, y - s * 0.7), s * 0.26, col.lightened(0.05))        # shield
	if banner:
		var bp := Vector2(x + s * 0.34, y - s * 2.0)
		var pts := PackedVector2Array([bp, bp + Vector2(s * 0.9, sin(t * 5.0) * 3.0), bp + Vector2(s * 0.9, s * 0.6 + sin(t * 5.0 + 1.0) * 3.0), bp + Vector2(0, s * 0.7)])
		draw_colored_polygon(pts, Color(0.7, 0.1, 0.1))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	# sky
	var bands := 48
	for i in bands:
		var f := float(i) / bands
		var c := Color(0.04, 0.03, 0.12).lerp(Color(0.28, 0.12, 0.3), smoothstep(0.0, 0.55, f)).lerp(Color(0.95, 0.5, 0.25), pow(maxf(f - 0.55, 0.0) / 0.45, 1.6))
		draw_rect(Rect2(0, h * f, w, h / bands + 2.0), c)
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * (1.0 + s.z * 2.0) + s.x * 40.0)
		draw_circle(Vector2(s.x * w, s.y * h), 0.9 + s.z * 1.5, Color(1, 0.95, 0.85, (0.2 + 0.7 * tw) * (1.0 - s.y * 1.3)))
	if shoot.x >= 0.0:
		var sp := Vector2(shoot.x * w, shoot.y * h) + Vector2(1, 0.45) * shoot.z * w * 0.4
		draw_line(sp, sp - Vector2(1, 0.45) * 70.0, Color(1, 0.95, 0.8, 1.0 - shoot.z), 2.5)
	# moon with halo
	var mp := Vector2(w * 0.82, h * 0.17)
	for k in 6:
		draw_circle(mp, h * (0.06 + k * 0.035), Color(1, 0.9, 0.7, 0.05 - k * 0.007))
	draw_circle(mp, h * 0.06, Color(1, 0.94, 0.78))
	draw_circle(mp + Vector2(-h * 0.018, h * 0.008), h * 0.012, Color(0.9, 0.82, 0.65))
	draw_circle(mp + Vector2(h * 0.015, -h * 0.014), h * 0.008, Color(0.9, 0.82, 0.65))
	# clouds
	for i in 6:
		var cx := fposmod(t * (7.0 + i * 3.0) + i * w * 0.24, w + 500.0) - 250.0
		var cy := h * (0.1 + 0.075 * i)
		for k in 6:
			draw_circle(Vector2(cx + k * 44.0, cy + sin(k * 1.7 + i) * 9.0), 42.0 - k * 3.5, Color(0.8, 0.45, 0.5, 0.08))
	# mountains (parallax)
	_ridge(w, h, h * 0.66, h * 0.20, 1.0 + t * 0.0, Color(0.16, 0.1, 0.24), true)
	_ridge(w, h, h * 0.72, h * 0.14, 3.7, Color(0.12, 0.07, 0.17))
	# distant fog
	for i in 6:
		draw_rect(Rect2(0, h * 0.62 + i * h * 0.02, w, h * 0.03), Color(0.85, 0.5, 0.45, 0.025))
	# castle complex
	var base := h * 0.84
	var u := h * 0.05
	var cx0 := w * 0.5
	var stone := Color(0.07, 0.05, 0.1)
	var lit := Color(1.0, 0.72, 0.28)
	# rock outcrop under castle
	draw_colored_polygon(PackedVector2Array([Vector2(cx0 - u * 11, h), Vector2(cx0 - u * 9, base - u * 0.2), Vector2(cx0 - u * 5, base - u * 1.2), Vector2(cx0 + u * 5, base - u * 1.2), Vector2(cx0 + u * 9, base - u * 0.2), Vector2(cx0 + u * 11, h)]), Color(0.06, 0.045, 0.08))
	# curtain wall with merlons
	draw_rect(Rect2(cx0 - u * 8.5, base - u * 3.6, u * 17.0, u * 3.5), stone)
	for i in 22:
		draw_rect(Rect2(cx0 - u * 8.5 + i * u * 0.8, base - u * 3.6 - u * 0.5, u * 0.45, u * 0.5), stone)
	# gate arch with glow
	var gx := cx0
	draw_rect(Rect2(gx - u * 0.9, base - u * 2.2, u * 1.8, u * 2.15), Color(1.0, 0.6, 0.2, 0.55 + 0.1 * sin(t * 6.0)))
	draw_circle(Vector2(gx, base - u * 2.2), u * 0.9, Color(1.0, 0.6, 0.2, 0.55 + 0.1 * sin(t * 6.0)))
	for k in 5:
		draw_line(Vector2(gx - u * 0.9 + k * u * 0.45, base - u * 2.9), Vector2(gx - u * 0.9 + k * u * 0.45, base - u * 0.1), stone, 2.0)
	# towers
	_tower(cx0 - u * 8.6, base, u * 2.6, u * 6.2, u * 2.6, stone, lit, 1.0)
	_tower(cx0 + u * 8.6, base, u * 2.6, u * 6.2, u * 2.6, stone, lit, 2.0)
	_tower(cx0 - u * 4.2, base, u * 1.9, u * 5.0, u * 2.0, stone, lit, 3.0)
	_tower(cx0 + u * 4.2, base, u * 1.9, u * 5.0, u * 2.0, stone, lit, 4.0)
	# great keep
	_tower(cx0, base - u * 3.2, u * 4.2, u * 5.2, u * 4.2, stone, lit, 5.0)
	# torches on the wall
	for tx in [cx0 - u * 2.0, cx0 + u * 2.0, cx0 - u * 6.2, cx0 + u * 6.2]:
		var fh := 0.7 + 0.3 * sin(t * 11.0 + tx) * sin(t * 7.3 + tx * 0.1)
		for k in 4:
			draw_circle(Vector2(tx, base - u * 2.6), u * (1.6 - k * 0.35) * fh, Color(1, 0.55, 0.15, 0.05 + k * 0.025))
		draw_circle(Vector2(tx, base - u * 2.6), u * 0.22 * fh, Color(1, 0.85, 0.4, 0.95))
	# foreground hills + pines
	_ridge(w, h, h * 0.9, h * 0.07, 9.1, Color(0.035, 0.025, 0.05))
	for p in pines:
		var px: float = p.x * w
		var ph: float = h * 0.07 * p.y
		var py: float = h * 0.93 - sin(p.x * 14.0) * h * 0.02
		if absf(px - cx0) < u * 9.5:
			continue
		for k in 3:
			var ky: float = py - ph * (0.35 * k)
			var kw: float = ph * (0.42 - k * 0.1)
			draw_colored_polygon(PackedVector2Array([Vector2(px - kw, ky), Vector2(px, ky - ph * 0.55), Vector2(px + kw, ky)]), Color(0.025, 0.02, 0.04))
	# marching army on the ridge
	var ridge_y := h * 0.935
	var sc := h * 0.032
	for i in 14:
		var ax: float = fposmod(t * 22.0 + i * sc * 1.25, w + sc * 4.0) - sc * 2.0
		var ay: float = ridge_y + (i % 3) * sc * 0.18
		_knight(ax, ay, sc * (0.92 + (i % 3) * 0.08), Color(0.02, 0.015, 0.03), t * 6.0 + i * 1.3, i % 5 == 0)
	# rolling fog
	for i in 5:
		var fx := fposmod(t * (6.0 + i * 2.0) + i * w * 0.3, w + 700.0) - 350.0
		for k in 7:
			draw_circle(Vector2(fx + k * 90.0, h * (0.88 + 0.025 * i) + sin(t * 0.4 + k + i) * 6.0), 90.0 + k * 6.0, Color(0.75, 0.55, 0.6, 0.035))
	# embers
	for e in embers:
		var ph2 := fposmod(t * e.z * 3.0 + e.w, 1.0)
		var ex: float = e.x * w + sin(t + e.w * 3.0) * 30.0
		var ey: float = h - ph2 * h * 0.85
		draw_circle(Vector2(ex, ey), 1.5 + e.z * 14.0, Color(1, 0.6 + ph2 * 0.3, 0.2, (1.0 - ph2) * 0.8))
	# vignette
	for i in 10:
		var a := 0.07 * (1.0 - i / 10.0)
		draw_rect(Rect2(0, i * h * 0.012, w, h * 0.012), Color(0, 0, 0, a * 3.0))
		draw_rect(Rect2(0, h - (i + 1) * h * 0.012, w, h * 0.012), Color(0, 0, 0, a * 4.0))
		draw_rect(Rect2(i * w * 0.01, 0, w * 0.01, h), Color(0, 0, 0, a * 2.0))
		draw_rect(Rect2(w - (i + 1) * w * 0.01, 0, w * 0.01, h), Color(0, 0, 0, a * 2.0))
