extends Control
# AAA-style main menu laid over the 3D lobby: profile card, animated logo, big PLAY button with shine,
# tiles with icons, hover / press feedback + sounds, staggered slide-in, scrolling news ticker.

const UiFx := preload("res://game/uifx.gd")
const ProfS := preload("res://game/profile.gd")
const LocS := preload("res://game/loc.gd")
const Snd := preload("res://game/uisnd.gd")
const EmblemS := preload("res://game/emblem.gd")

const GOLD := Color(1.0, 0.82, 0.35)
const TIPS := [
	"Tip: hold BLOCK just before a hit lands to parry and stagger your enemy.",
	"Tip: a king who stands near his soldiers makes them fight harder.",
	"Tip: lock blades with an enemy king and tap fast - then choose his fate.",
	"Tip: customize your king and castle - your banner flies over your realm.",
	"Tip: build farms and mills early - an army marches on its stomach.",
	"Tip: walls and towers hold the gate - archers on the walls win sieges.",
]

var main                      # the Main node (menu actions + shared labels)
var actions: Dictionary = {}  # id -> Callable
var ticker: Label
var ticker_clip: Control
var t := 0.0
var tick_x := 0.0
var play_glow: StyleBoxFlat
var shine: ColorRect
var play_btn: Button
var right: VBoxContainer
var intro_items: Array = []
var busy := false
var instant := false         # true: buttons run their action at once (in-game HUD)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_vignette()
	_logo()
	_profile_card()
	_right_column()
	_top_icons()
	_ticker()
	_intro()


# ------------------------------------------------------------------ helpers
func _lbl(p: Control, text: String, size: int, col := Color.WHITE, outline := -1) -> Label:
	var l := Label.new()
	l.text = LocS.t(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", outline if outline >= 0 else maxi(3, size / 7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l


func _grad(top: Color, bot: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bot)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	return gt


func _vignette() -> void:
	var tr := TextureRect.new()
	tr.texture = _grad(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tr.offset_bottom = 170
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var bt := TextureRect.new()
	bt.texture = _grad(Color(0, 0, 0, 0), Color(0, 0, 0, 0.7))
	bt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bt.offset_top = -170
	bt.stretch_mode = TextureRect.STRETCH_SCALE
	bt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bt)
	# soft dark panel behind the buttons so they stay readable over any scenery
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.01, 0.04, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 128
	gt.height = 8
	var side := TextureRect.new()
	side.texture = gt
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -560
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)


func _logo() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -250
	box.offset_right = 410
	box.offset_top = 8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var title := _lbl(box, "SALEEL AL HADID", 62 if LocS.lang != "ar" else 60, GOLD, 12)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_color_override("font_shadow_color", Color(0.8, 0.35, 0.05, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	main._title_lbl = title
	var sub := _lbl(box, "Swords  -  Bows  -  Kingdoms", 24, Color(0.9, 0.86, 0.95), 5)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	intro_items.append([box, Vector2(0, -90)])


func _profile_card() -> void:
	var pc := PanelContainer.new()
	pc.position = Vector2(16, 12)
	pc.custom_minimum_size = Vector2(340, 0)
	var st := UiFx.plate(16.0, 0.8)
	st.content_margin_left = 12
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var em := EmblemS.new()
	em.custom_minimum_size = Vector2(70, 70)
	hb.add_child(em)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var nm: String = ProfS.king_name
	if nm == "":
		nm = LocS.t("Your King")
	var nl := _lbl(vb, nm, 26, Color(1, 0.95, 0.8))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.clip_text = true
	var prog: Array = ProfS.rank_progress()
	var rl := _lbl(vb, LocS.t(ProfS.rank_name()) + "  -  " + LocS.t("Renown") + " %d" % ProfS.renown, 20, Color(1.0, 0.82, 0.45))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = maxf(float(prog[1]), 1.0)
	bar.value = float(prog[0])
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(7)
	bg.border_color = Color(0.6, 0.45, 0.2)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.95, 0.7, 0.2)
	fg.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bar)
	var wl := _lbl(vb, "%d " % ProfS.games + LocS.t("battles") + "  -  %d " % ProfS.wins + LocS.t("victories"), 16, Color(0.8, 0.8, 0.9), 3)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wl.autowrap_mode = TextServer.AUTOWRAP_OFF
	intro_items.append([pc, Vector2(-380, 0)])


# a menu button: custom content (icon + text) inside a styled Button
func _mbtn(id: String, text: String, icon: String, size: Vector2, font: int, accent := false, vertical := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var base := Color(0.14, 0.1, 0.09, 0.9)
	var top := Color(0.3, 0.2, 0.12, 0.95)
	var brd := Color(0.85, 0.66, 0.28)
	if accent:
		base = Color(0.5, 0.08, 0.07, 0.96)
		top = Color(0.78, 0.2, 0.12, 0.98)
		brd = Color(1.0, 0.85, 0.45)
	var mk := func(bgc: Color, bc: Color, grow: int) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bgc
		s.border_color = bc
		s.set_border_width_all(3)
		s.border_width_bottom = 5
		s.set_corner_radius_all(14)
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 6 + grow
		s.shadow_offset = Vector2(0, 3)
		s.anti_aliasing = true
		return s
	b.add_theme_stylebox_override("normal", mk.call(base, brd, 0))
	b.add_theme_stylebox_override("hover", mk.call(top, Color(1, 0.93, 0.6), 4))
	b.add_theme_stylebox_override("pressed", mk.call(base.darkened(0.2), brd, 0))
	b.add_theme_stylebox_override("focus", mk.call(base, brd, 0))
	# inner glossy highlight
	var gl := ColorRect.new()
	gl.color = Color(1, 1, 1, 0.07)
	gl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gl.offset_left = 4
	gl.offset_right = -4
	gl.offset_top = 4
	gl.offset_bottom = size.y * 0.42
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(gl)
	var cont: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.alignment = BoxContainer.ALIGNMENT_CENTER
	cont.add_theme_constant_override("separation", 6 if vertical else 14)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cont)
	var isz: int = int(size.y * (0.42 if vertical else 0.56))
	if icon != "":
		var tr := TextureRect.new()
		tr.texture = UiFx.icon(icon, isz)
		tr.custom_minimum_size = Vector2(isz, isz)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont.add_child(tr)
	var l := _lbl(cont, text, font, Color(1, 0.96, 0.85) if not accent else Color(1, 1, 0.92))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if vertical else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(size.x - 24 if vertical else 0, 0)
	b.pivot_offset = size * 0.5
	b.mouse_entered.connect(func():
		Snd.play(self, "hover", -16.0)
		create_tween().tween_property(b, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.pressed.connect(func(): _press(b, id))
	return b


func _press(b: Button, id: String) -> void:
	if instant:
		Snd.play(self, "click", -6.0)
		if actions.has(id):
			(actions[id] as Callable).call()
		return
	if busy:
		return
	busy = true
	Snd.play(self, "click", -6.0)
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06)
	tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.08)
	await tw.finished
	# fade out then run the action
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	Snd.play(self, "whoosh", -12.0)
	var f := create_tween()
	f.tween_property(fade, "color:a", 1.0, 0.18)
	await f.finished
	busy = false
	if actions.has(id):
		(actions[id] as Callable).call()


func _right_column() -> void:
	right = VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.5
	right.anchor_bottom = 0.5
	right.offset_left = -440
	right.offset_right = -22
	right.offset_top = -232
	right.offset_bottom = 250
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	play_btn = _mbtn("play", "PLAY", "sword", Vector2(418, 112), 46, true)
	right.add_child(play_btn)
	# shine sweep across the PLAY button
	shine = ColorRect.new()
	shine.color = Color(1, 1, 1, 0.28)
	shine.size = Vector2(46, 220)
	shine.rotation = 0.35
	shine.position = Vector2(-120, -50)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_btn.add_child(shine)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(grid)
	var defs := [["throne", "THRONE HALL", "city"], ["king", "CUSTOMIZE KING", "advisor"], ["castle", "CUSTOMIZE CASTLE", "house"], ["local", "LOCAL (Wi-Fi)", "flag"]]
	var items: Array = [play_btn]
	for d in defs:
		var tb := _mbtn(d[0], d[1], d[2], Vector2(203, 118), 18, false, true)
		grid.add_child(tb)
		items.append(tb)
	var sb := _mbtn("settings", "Settings", "gear", Vector2(418, 62), 26)
	right.add_child(sb)
	items.append(sb)
	for i in items.size():
		intro_items.append([items[i], Vector2(460, 0), 0.25 + i * 0.09])
	# status + update widgets live under the buttons
	main._status = _lbl(right, "", 22, Color(1, 0.5, 0.4))
	main._status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._upd_label = _lbl(right, "", 20, Color(0.7, 0.85, 1.0))
	main._upd_btn = Button.new()
	main._upd_btn.text = LocS.t("Download update")
	main._upd_btn.custom_minimum_size = Vector2(0, 56)
	main._upd_btn.visible = false
	main._upd_btn.pressed.connect(func(): main.updater.download())
	right.add_child(main._upd_btn)


func _top_icons() -> void:
	var hb := HBoxContainer.new()
	hb.anchor_left = 1.0
	hb.anchor_right = 1.0
	hb.offset_left = -190
	hb.offset_right = -18
	hb.offset_top = 10
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	var mute := Button.new()
	mute.custom_minimum_size = Vector2(76, 52)
	mute.focus_mode = Control.FOCUS_NONE
	mute.add_theme_font_size_override("font_size", 22)
	mute.text = "Music: On" if not Snd.muted else "Music: Off"
	mute.text = LocS.t(mute.text)
	mute.pressed.connect(func():
		Snd.muted = not Snd.muted
		if main._menu_music != null:
			main._menu_music.stream_paused = Snd.muted
		mute.text = LocS.t("Music: Off" if Snd.muted else "Music: On")
		Snd.play(self, "click", -8.0))
	mute.custom_minimum_size = Vector2(172, 50)
	hb.add_child(mute)
	intro_items.append([hb, Vector2(0, -80), 0.2])


func _ticker() -> void:
	ticker_clip = Control.new()
	ticker_clip.clip_contents = true
	ticker_clip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ticker_clip.offset_top = -40
	ticker_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticker_clip)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_clip.add_child(bg)
	var line := ColorRect.new()
	line.color = Color(0.85, 0.66, 0.28, 0.8)
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_bottom = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_clip.add_child(line)
	var parts: Array = []
	var di: int = abs(hash(ProfS.today())) % ProfS.DAILY.size()
	parts.append(LocS.t("Decree of the day") + ": " + LocS.t(String(ProfS.DAILY[di].text)))
	for tip in TIPS:
		parts.append(LocS.t(tip))
	ticker = Label.new()
	ticker.text = "      *      ".join(parts)
	ticker.add_theme_font_size_override("font_size", 22)
	ticker.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	ticker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ticker.add_theme_constant_override("outline_size", 4)
	ticker.autowrap_mode = TextServer.AUTOWRAP_OFF
	ticker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker.position = Vector2(1300, 4)
	ticker_clip.add_child(ticker)
	tick_x = 1300.0
	var bl := _lbl(self, "build %d" % int(main.Build.BUILD), 15, Color(0.7, 0.7, 0.78, 0.8), 3)
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 12
	bl.offset_top = -66
	bl.offset_bottom = -44
	bl.offset_right = 140


func _intro() -> void:
	Snd.play(self, "whoosh", -10.0)
	for it in intro_items:
		var c: Control = it[0]
		var off: Vector2 = it[1]
		var delay: float = it[2] if it.size() > 2 else 0.05
		c.modulate.a = 0.0
		if c is Button:
			c.pivot_offset = c.custom_minimum_size * 0.5
			c.scale = Vector2(0.7, 0.7)
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(c, "modulate:a", 1.0, 0.01)
			tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var home: Vector2 = c.position
			c.position = home + off
			var tw2 := create_tween()
			tw2.tween_interval(delay)
			tw2.tween_property(c, "modulate:a", 1.0, 0.01)
			tw2.tween_property(c, "position", home, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(dt: float) -> void:
	t += dt
	tick_x -= dt * 70.0
	if ticker != null:
		var w := ticker.get_minimum_size().x
		if tick_x < -w:
			tick_x = ticker_clip.size.x + 20.0
		ticker.position.x = tick_x
	if shine != null and play_btn != null:
		var ph := fmod(t, 3.6) / 1.1
		shine.position.x = lerpf(-120.0, 560.0, clampf(ph, 0.0, 1.0))
		shine.visible = ph < 1.0
	if play_btn != null:
		var k := 0.5 + 0.5 * sin(t * 2.4)
		var st: StyleBox = play_btn.get_theme_stylebox("normal")
		if st is StyleBoxFlat:
			(st as StyleBoxFlat).shadow_color = Color(1.0, 0.45, 0.1, 0.25 + 0.3 * k)
			(st as StyleBoxFlat).shadow_size = int(8 + 10 * k)
