extends Control
# Rotating carousel of big picture cards (Solo Battle / Solo Kingdom). Swipe, tap arrows, or wait - it turns by itself.

signal chosen(id)

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
	# arrows
	var fnt := get_theme_default_font()
	var a := 0.7 + 0.3 * sin(t * 3.0)
	draw_string(fnt, Vector2(14, size.y * 0.5 + 18), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 0.85, 0.4, a))
	draw_string(fnt, Vector2(size.x - 44, size.y * 0.5 + 18), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 0.85, 0.4, a))
	# dots
	for k in n:
		var on := k == cur
		draw_circle(Vector2(size.x * 0.5 + (k - (n - 1) * 0.5) * 26.0, size.y - 8.0), 7.0 if on else 5.0, Color(1, 0.85, 0.4, 1.0 if on else 0.4))


func _card(r: Rect2, c: Dictionary, alpha: float, focus: bool) -> void:
	var fnt := get_theme_default_font()
	# frame
	draw_rect(Rect2(r.position - Vector2(5, 5), r.size + Vector2(10, 10)), Color(0.95, 0.75, 0.3, alpha if focus else alpha * 0.6))
	var art := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.7))
	_art(art, String(c.art), alpha)
	var tx := Rect2(r.position + Vector2(0, art.size.y), Vector2(r.size.x, r.size.y - art.size.y))
	draw_rect(tx, Color(0.09, 0.08, 0.12, alpha))
	var title: String = LocS.t(String(c.title))
	var desc: String = LocS.t(String(c.desc))
	var fs := int(r.size.y * 0.1)
	draw_string(fnt, Vector2(tx.position.x, tx.position.y + fs * 1.15), title, HORIZONTAL_ALIGNMENT_CENTER, tx.size.x, fs, Color(1.0, 0.85, 0.4, alpha))
	draw_string(fnt, Vector2(tx.position.x + 12, tx.position.y + fs * 2.15), desc, HORIZONTAL_ALIGNMENT_CENTER, tx.size.x - 24, int(fs * 0.5), Color(0.85, 0.85, 0.9, alpha))
	if focus:
		draw_string(fnt, Vector2(tx.position.x, tx.end.y - 10), LocS.t("tap to play"), HORIZONTAL_ALIGNMENT_CENTER, tx.size.x, int(fs * 0.5), Color(0.6, 1.0, 0.6, 0.6 + 0.4 * sin(t * 4.0)))


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
