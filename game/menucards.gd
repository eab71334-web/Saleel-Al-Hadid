extends Control
# Rotating carousel of big picture cards (Solo Battle / Solo Kingdom). Swipe, tap arrows, or wait - it turns by itself.

signal chosen(id)
signal focus_changed(i)

var cards: Array = []           # {id, title, desc, art}
var cur := 0
var pos := 0.0                  # animated index (float)
var idle := 0.0
var drag := false
var drag_x := 0.0
var drag_start_pos := 0.0
var t := 0.0
var LocS = preload("res://game/loc.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func go(i: int) -> void:
	cur = posmod(i, cards.size())
	idle = 0.0
	focus_changed.emit(cur)
	var best := float(cur)
	# shortest way around
	var n := cards.size()
	var d := fposmod(best - pos + n * 0.5, float(n)) - n * 0.5
	var tw := create_tween()
	tw.tween_property(self, "pos", pos + d, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(dt: float) -> void:
	t += dt
	idle += dt
	if not drag and idle > 5.5 and cards.size() > 1:
		go(cur + 1)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var cw := size.x * 0.62
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		var pressed: bool = e.pressed
		var px: float = e.position.x
		if pressed:
			drag = true
			drag_x = px
			drag_start_pos = pos
			idle = 0.0
		elif drag:
			drag = false
			var moved := px - drag_x
			if absf(moved) < 14.0:
				# tap: side card -> rotate to it, centre card -> choose it
				if px < size.x * 0.2:
					go(cur - 1)
				elif px > size.x * 0.8:
					go(cur + 1)
				else:
					chosen.emit(cards[cur].id)
			elif moved < -cw * 0.18:
				go(cur + 1)
			elif moved > cw * 0.18:
				go(cur - 1)
			else:
				go(cur)
	elif (e is InputEventMouseMotion or e is InputEventScreenDrag) and drag:
		var dx: float = e.position.x - drag_x
		pos = drag_start_pos - dx / cw
		idle = 0.0


func _draw() -> void:
	var n := cards.size()
	if n == 0:
		return
	var cw := size.x * 0.62
	var ch := size.y * 0.92
	var base_i := int(round(pos))
	var order := [-1, 1, 0]
	for j in order:
		var unwrapped: int = base_i + j
		var k: int = posmod(unwrapped, n)
		var off: float = float(unwrapped) - pos
		if absf(off) > 1.6:
			continue
		var sc := 1.0 - minf(absf(off), 1.0) * 0.2
		var w := cw * sc
		var h := ch * sc
		var cx := size.x * 0.5 + off * cw * 1.05
		var r := Rect2(cx - w * 0.5, size.y * 0.5 - h * 0.5, w, h)
		var alpha := 1.0 - minf(absf(off), 1.0) * 0.6
		_card(r, cards[k], alpha, absf(off) < 0.5)
	# dots
	for k in n:
		var on := k == cur
		draw_circle(Vector2(size.x * 0.5 + (k - (n - 1) * 0.5) * 26.0, size.y - 8.0), 7.0 if on else 5.0, Color(1, 0.85, 0.4, 1.0 if on else 0.4))


func _card(r: Rect2, c: Dictionary, alpha: float, focus: bool) -> void:
	var fnt := get_theme_default_font()
	var glow := 0.5 + 0.5 * sin(t * 2.4)
	if focus:
		for k in 4:
			draw_rect(Rect2(r.position - Vector2(10 + k * 5, 10 + k * 5), r.size + Vector2(20 + k * 10, 20 + k * 10)), Color(1.0, 0.7, 0.2, (0.05 + 0.04 * glow) * (4 - k) * alpha), false, 5.0)
	# gold frame (gradient: bright top, dark bottom)
	var fr := Rect2(r.position - Vector2(6, 6), r.size + Vector2(12, 12))
	var fa := alpha if focus else alpha * 0.7
	var top := Color(1.0, 0.9, 0.5, fa)
	var bot := Color(0.62, 0.42, 0.12, fa)
	draw_polygon(PackedVector2Array([fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]), PackedColorArray([top, top, bot, bot]))
	var art := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.7))
	_art(art, String(c.art), alpha)
	# animated sheen across the art of the focused card
	if focus:
		var sx := art.position.x + fposmod(t * 160.0, art.size.x + 240.0) - 120.0
		var sh := PackedVector2Array([Vector2(sx, art.position.y), Vector2(sx + 50, art.position.y), Vector2(sx + 10, art.end.y), Vector2(sx - 40, art.end.y)])
		var clipped := PackedVector2Array()
		for p in sh:
			clipped.append(Vector2(clampf(p.x, art.position.x, art.end.x), p.y))
		draw_colored_polygon(clipped, Color(1, 1, 1, 0.1 * alpha))
	var tx := Rect2(r.position + Vector2(0, art.size.y), Vector2(r.size.x, r.size.y - art.size.y))
	_grad(tx, Color(0.16, 0.12, 0.1), Color(0.05, 0.04, 0.07), alpha)
	draw_line(tx.position, Vector2(tx.end.x, tx.position.y), Color(1.0, 0.82, 0.4, alpha), 3.0)
	var title: String = LocS.t(String(c.title))
	var desc: String = LocS.t(String(c.desc))
	var fs := int(r.size.y * 0.1)
	draw_string(fnt, Vector2(tx.position.x + 2, tx.position.y + fs * 1.15 + 2), title, HORIZONTAL_ALIGNMENT_CENTER, tx.size.x, fs, Color(0, 0, 0, alpha * 0.8))
	draw_string(fnt, Vector2(tx.position.x, tx.position.y + fs * 1.15), title, HORIZONTAL_ALIGNMENT_CENTER, tx.size.x, fs, Color(1.0, 0.86, 0.42, alpha))
	draw_string(fnt, Vector2(tx.position.x + 12, tx.position.y + fs * 2.15), desc, HORIZONTAL_ALIGNMENT_CENTER, tx.size.x - 24, int(fs * 0.5), Color(0.88, 0.88, 0.95, alpha))
	# corner studs
	for cp in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_circle(cp, 7.0, Color(0.35, 0.22, 0.05, fa))
		draw_circle(cp, 4.5, Color(1.0, 0.9, 0.5, fa))
	if c.get("beta", false):
		var rb := Rect2(r.position.x + r.size.x - 120, r.position.y + 16, 120, 34)
		draw_rect(rb, Color(0.8, 0.15, 0.1, alpha))
		draw_rect(rb, Color(1, 0.85, 0.4, alpha), false, 2.0)
		draw_string(fnt, Vector2(rb.position.x, rb.position.y + 25), "BETA", HORIZONTAL_ALIGNMENT_CENTER, rb.size.x, 22, Color(1, 1, 0.9, alpha))


func _grad(r: Rect2, top: Color, bot: Color, alpha: float) -> void:
	var t1 := Color(top.r, top.g, top.b, alpha)
	var b1 := Color(bot.r, bot.g, bot.b, alpha)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([t1, t1, b1, b1]))


func _art(r: Rect2, kind: String, alpha: float) -> void:
	if kind == "battle":
		_grad(r, Color(0.16, 0.12, 0.3), Color(0.95, 0.5, 0.25), alpha)
		draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.62), r.size.y * 0.2, Color(1.0, 0.85, 0.5, alpha))
		# hills
		var hp := PackedVector2Array([r.position + Vector2(0, r.size.y), r.position + Vector2(0, r.size.y * 0.72), r.position + Vector2(r.size.x * 0.3, r.size.y * 0.66), r.position + Vector2(r.size.x * 0.6, r.size.y * 0.74), r.position + Vector2(r.size.x, r.size.y * 0.68), r.position + Vector2(r.size.x, r.size.y)])
		draw_colored_polygon(hp, Color(0.12, 0.1, 0.14, alpha))
		# two armies
		for side in 2:
			var col := Color(0.25, 0.45, 1.0, alpha) if side == 0 else Color(1.0, 0.3, 0.25, alpha)
			for i in 14:
				var row := i % 2
				var x := r.position.x + r.size.x * (0.08 + 0.26 * float(i) / 14.0 + (0.0 if side == 0 else 0.58))
				var y := r.position.y + r.size.y * (0.78 + 0.08 * row)
				draw_rect(Rect2(x, y - 14, 7, 16), col)
				draw_line(Vector2(x + 3, y - 14), Vector2(x + 3 + (8 if side == 0 else -8), y - 36), Color(0.85, 0.85, 0.9, alpha), 2.0)
		# crossed swords
		var c := r.position + r.size * Vector2(0.5, 0.36)
		var s := r.size.y * 0.28
		draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(0.9, 0.92, 1.0, alpha), 7.0)
		draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Color(0.9, 0.92, 1.0, alpha), 7.0)
		draw_line(c + Vector2(-s * 0.5, s * 0.25), c + Vector2(-s * 0.2, s * 0.55), Color(0.8, 0.6, 0.2, alpha), 9.0)
		draw_line(c + Vector2(s * 0.5, s * 0.25), c + Vector2(s * 0.2, s * 0.55), Color(0.8, 0.6, 0.2, alpha), 9.0)
	elif kind == "world":
		_grad(r, Color(0.12, 0.3, 0.5), Color(0.2, 0.45, 0.65), alpha)
		var land := PackedVector2Array()
		for i in 21:
			var a := float(i) / 20.0 * TAU
			var rr := 0.36 + 0.07 * sin(a * 3.0 + 1.0) + 0.04 * sin(a * 7.0)
			land.append(r.position + r.size * Vector2(0.5 + cos(a) * rr * 1.2, 0.5 + sin(a) * rr * 0.95))
		draw_colored_polygon(land, Color(0.3, 0.5, 0.2, alpha))
		var land2 := PackedVector2Array()
		for p in land:
			land2.append(r.position + r.size * 0.5 + (p - r.position - r.size * 0.5) * 0.78)
		draw_colored_polygon(land2, Color(0.24, 0.42, 0.16, alpha))
		for i in 5:
			var mp := r.position + r.size * Vector2(0.38 + i * 0.07, 0.36 + (i % 2) * 0.05)
			draw_colored_polygon(PackedVector2Array([mp + Vector2(-22, 24), mp + Vector2(22, 24), mp + Vector2(0, -26)]), Color(0.42, 0.4, 0.45, alpha))
			draw_colored_polygon(PackedVector2Array([mp + Vector2(-7, -12), mp + Vector2(7, -12), mp + Vector2(0, -26)]), Color(0.95, 0.95, 1.0, alpha))
		draw_circle(r.position + r.size * Vector2(0.62, 0.62), r.size.y * 0.06, Color(0.14, 0.34, 0.55, alpha))
		var spots := [Vector2(0.3, 0.55), Vector2(0.5, 0.7), Vector2(0.7, 0.42), Vector2(0.42, 0.28), Vector2(0.66, 0.3)]
		for i in spots.size():
			var sp: Vector2 = r.position + r.size * spots[i]
			var col := Color(1.0, 0.85, 0.3, alpha) if i == 0 else Color(1, 1, 1, alpha)
			draw_rect(Rect2(sp - Vector2(7, 7), Vector2(14, 14)), Color(0, 0, 0, alpha))
			draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), col)
		var pc := r.position + r.size * Vector2(0.5, 0.5)
		draw_arc(pc, 12.0 + 4.0 * sin(t * 3.0), 0, TAU, 24, Color(1, 0.4, 0.3, alpha), 3.0)
		# compass
		var cc := r.position + r.size * Vector2(0.86, 0.2)
		draw_arc(cc, 26.0, 0, TAU, 28, Color(1, 0.85, 0.4, alpha), 3.0)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -26), cc + Vector2(7, 0), cc + Vector2(-7, 0)]), Color(0.9, 0.2, 0.2, alpha))
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, 26), cc + Vector2(7, 0), cc + Vector2(-7, 0)]), Color(0.9, 0.9, 0.9, alpha))
	else:
		_grad(r, Color(0.28, 0.5, 0.85), Color(0.98, 0.82, 0.55), alpha)
		draw_circle(r.position + Vector2(r.size.x * 0.82, r.size.y * 0.25), r.size.y * 0.12, Color(1.0, 0.95, 0.7, alpha))
		var g := PackedVector2Array([r.position + Vector2(0, r.size.y), r.position + Vector2(0, r.size.y * 0.8), r.position + Vector2(r.size.x, r.size.y * 0.76), r.position + Vector2(r.size.x, r.size.y)])
		draw_colored_polygon(g, Color(0.25, 0.5, 0.2, alpha))
		# castle
		var base := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.82)
		var stone := Color(0.72, 0.68, 0.62, alpha)
		var dark := Color(0.5, 0.47, 0.43, alpha)
		var w := r.size.x * 0.46
		draw_rect(Rect2(base.x - w * 0.5, base.y - r.size.y * 0.3, w, r.size.y * 0.3), stone)
		for i in 7:
			draw_rect(Rect2(base.x - w * 0.5 + i * w / 7.0, base.y - r.size.y * 0.34, w / 14.0, r.size.y * 0.05), stone)
		for sx in [-1.0, 1.0]:
			var tx: float = base.x + sx * w * 0.5
			draw_rect(Rect2(tx - r.size.x * 0.045, base.y - r.size.y * 0.5, r.size.x * 0.09, r.size.y * 0.5), dark)
			var tri := PackedVector2Array([Vector2(tx - r.size.x * 0.06, base.y - r.size.y * 0.5), Vector2(tx + r.size.x * 0.06, base.y - r.size.y * 0.5), Vector2(tx, base.y - r.size.y * 0.66)])
			draw_colored_polygon(tri, Color(0.25, 0.4, 0.95, alpha))
		draw_rect(Rect2(base.x - r.size.x * 0.05, base.y - r.size.y * 0.55, r.size.x * 0.1, r.size.y * 0.55), stone)
		var kt := PackedVector2Array([Vector2(base.x - r.size.x * 0.065, base.y - r.size.y * 0.55), Vector2(base.x + r.size.x * 0.065, base.y - r.size.y * 0.55), Vector2(base.x, base.y - r.size.y * 0.74)])
		draw_colored_polygon(kt, Color(0.25, 0.4, 0.95, alpha))
		draw_line(Vector2(base.x, base.y - r.size.y * 0.74), Vector2(base.x, base.y - r.size.y * 0.84), Color(0.3, 0.2, 0.1, alpha), 3.0)
		draw_rect(Rect2(base.x, base.y - r.size.y * 0.84, 22, 12), Color(1.0, 0.8, 0.2, alpha))
		draw_rect(Rect2(base.x - r.size.x * 0.035, base.y - r.size.y * 0.14, r.size.x * 0.07, r.size.y * 0.14), Color(0.25, 0.15, 0.08, alpha))
		for i in 4:
			draw_circle(r.position + Vector2(r.size.x * (0.1 + 0.07 * i), r.size.y * 0.9), 5.0, Color(0.9, 0.7, 0.3, alpha))
