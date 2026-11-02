extends Control
# Studio logo intro + copyright notice. Everything is drawn in code (two rings, spaced lettering),
# so it stays sharp on every screen. Tap to skip after a moment.

static var done := false

const GOLD := Color(0.84, 0.69, 0.42)
const WHITE := Color(0.96, 0.96, 0.98)
const T_LOGO_END := 4.6
const T_LEGAL_IN := 4.9
const T_END := 10.8

var t := 0.0
var u := 1.0
var vs := Vector2(1280, 720)
var cb: Callable
var finishing := false
var legal: Control
var legal_skip_at := 0.0
var _cl: CanvasLayer


static func start(host: Node, on_done: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	host.add_child(cl)
	var s = load("res://game/splash.gd").new()
	s.cb = on_done
	s._cl = cl
	cl.add_child(s)


func _ready() -> void:
	vs = get_viewport().get_visible_rect().size
	u = clampf(minf(vs.x, vs.y) / 720.0, 0.55, 2.2)
	if vs.y > vs.x:
		u = clampf(vs.x / 720.0, 0.55, 2.2)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_legal()


func _build_legal() -> void:
	legal = VBoxContainer.new()
	legal.modulate.a = 0.0
	legal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legal.add_theme_constant_override("separation", int(14 * u))
	var w := minf(vs.x * 0.82, 900.0 * u)
	legal.custom_minimum_size = Vector2(w, 0)
	legal.position = Vector2((vs.x - w) * 0.5, vs.y * 0.06)
	add_child(legal)
	var mk := func(text: String, fs: int, col: Color, bold_outline := 0) -> Label:
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(w, 0)
		l.add_theme_font_size_override("font_size", int(fs * u))
		l.add_theme_color_override("font_color", col)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bold_outline > 0:
			l.add_theme_constant_override("outline_size", bold_outline)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		legal.add_child(l)
		return l
	mk.call("©  2026  SABAK STUDIOS", 42, GOLD)
	mk.call("ALL RIGHTS RESERVED  -  جميع الحقوق محفوظة", 22, Color(0.7, 0.7, 0.74))
	var line := ColorRect.new()
	line.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	line.custom_minimum_size = Vector2(w * 0.5, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legal.add_child(line)
	mk.call("SALEEL AL HADID, including its code, characters, artwork, sounds, music and design, is the exclusive property of Sabak Studios and is protected by copyright and international law.", 24, Color(0.86, 0.86, 0.9))
	mk.call("Copying, redistributing, modifying, decompiling, reverse engineering, extracting assets from, or selling this game or any part of it without written permission is STRICTLY PROHIBITED. Violators will be prosecuted to the fullest extent of the law.", 24, Color(1.0, 0.82, 0.78))
	mk.call("لعبة «سليل الحديد» بكل ما فيها من برمجة وشخصيات ورسومات وأصوات وموسيقى وتصميم هي ملكية حصرية لـ Sabak Studios ومحمية بقوانين حقوق النشر.", 25, Color(0.86, 0.86, 0.9))
	mk.call("يُمنع منعاً باتاً نسخ اللعبة أو أي جزء منها أو توزيعها أو تعديلها أو فك تشفيرها أو استخراج ملفاتها أو بيعها دون إذن كتابي. وكل مخالف سيُلاحَق قانونياً بأقصى ما يسمح به القانون.", 25, Color(1.0, 0.82, 0.78))


func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _process(dt: float) -> void:
	t += dt
	var la := 0.0
	if t >= T_LEGAL_IN:
		la = clampf((t - T_LEGAL_IN) / 0.8, 0.0, 1.0)
	legal.modulate.a = la
	if t >= T_END and not finishing:
		_finish()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var pressed := false
	if e is InputEventScreenTouch:
		pressed = e.pressed
	elif e is InputEventMouseButton:
		pressed = e.pressed
	elif e is InputEventKey:
		pressed = e.pressed
	if not pressed or finishing:
		return
	if t < T_LOGO_END and t > 1.6:
		t = T_LEGAL_IN
	elif t >= T_LEGAL_IN + 1.6:
		_finish()


func _finish() -> void:
	finishing = true
	done = true
	if cb.is_valid():
		cb.call()   # the intro starts under us (black) while we fade out
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func():
		if is_instance_valid(_cl):
			_cl.queue_free())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.0, 0.0, 1.0))
	var logo_a := 1.0
	if t > T_LOGO_END - 0.5:
		logo_a = clampf((T_LOGO_END - t) / 0.5, 0.0, 1.0)
	if logo_a <= 0.0:
		return
	var c := Vector2(vs.x * 0.5, vs.y * (0.40 if t < T_LEGAL_IN else 0.3))
	var zoom := 1.0 + 0.05 * clampf(t / 4.5, 0.0, 1.0)
	draw_set_transform(c, 0.0, Vector2(zoom, zoom))
	var r := 62.0 * u
	var off := r * 0.56
	var lw := maxf(2.0, 3.2 * u)
	var p1 := _ease_out((t - 0.3) / 1.3)
	var p2 := _ease_out((t - 0.75) / 1.3)
	var wc := Color(WHITE.r, WHITE.g, WHITE.b, logo_a)
	var gc := Color(GOLD.r, GOLD.g, GOLD.b, logo_a)
	# soft halo that breathes once the rings have closed
	var halo := clampf((t - 1.6) / 1.0, 0.0, 1.0) * (0.5 + 0.5 * sin(t * 2.2))
	for i in 5:
		var rr := r * (1.0 + 0.1 * float(i))
		draw_arc(Vector2(off, 0), rr, 0.0, TAU, 72, Color(GOLD.r, GOLD.g, GOLD.b, 0.035 * halo * logo_a * (5 - i)), lw * (2.0 + i), true)
	if p1 > 0.0:
		draw_arc(Vector2(-off, 0), r, -PI * 0.5, -PI * 0.5 + TAU * p1, 96, wc, lw, true)
	if p2 > 0.0:
		draw_arc(Vector2(off, 0), r, -PI * 0.5, -PI * 0.5 + TAU * p2, 96, gc, lw, true)
	# lettering
	var font: Font = ThemeDB.fallback_font
	var fs := int(58.0 * u)
	var word := "SABAK"
	var spread := lerpf(1.7, 1.0, _ease_out((t - 1.7) / 1.8))
	var gap := fs * 0.52 * spread
	var widths := []
	var total := 0.0
	for i in word.length():
		var wch := font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(wch)
		total += wch
	total += gap * (word.length() - 1)
	var x := -total * 0.5
	var base_y := r + 78.0 * u
	for i in word.length():
		var ia := _ease_out((t - 1.7 - 0.11 * i) / 0.7)
		var wave := maxf(0.0, sin(t * 2.6 - float(i) * 0.7 - 6.0)) * clampf((t - 3.0) / 0.6, 0.0, 1.0)
		var col := WHITE.lerp(Color(1.0, 0.88, 0.55), wave * 0.8)
		col.a = ia * logo_a
		draw_string(font, Vector2(x, base_y + (1.0 - ia) * 14.0 * u), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += widths[i] + gap
	var sub := "STUDIOS"
	var sfs := int(19.0 * u)
	var sa := _ease_out((t - 2.7) / 0.9) * logo_a
	var sgap := sfs * 1.05
	var sw := []
	var stot := 0.0
	for i in sub.length():
		var w2 := font.get_string_size(sub[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		sw.append(w2)
		stot += w2
	stot += sgap * (sub.length() - 1)
	var sx := -stot * 0.5
	for i in sub.length():
		draw_string(font, Vector2(sx, base_y + 62.0 * u), sub[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.62, 0.6, 0.58, sa))
		sx += sw[i] + sgap
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
