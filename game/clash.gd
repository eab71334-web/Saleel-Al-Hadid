extends Node
const LocS := preload("res://game/loc.gd")
# Blade-lock of the two kings in a duel: tap to out-push your rival, then decide his fate.
# Solo / AI only (never runs in online rooms).

var battle
var kingdom
var state := ""            # "" | lock | won | end
var pk                     # player's king
var ek                     # rival king
var p := 0.5               # tug-of-war: 1 = you win, 0 = he wins
var t := 0.0
var cd := 6.0
var mid := Vector3.ZERO
var dirv := Vector3.FORWARD
var hidden: Array = []
var layer: CanvasLayer
var ov: Control
var meter_l: ColorRect
var meter_r: ColorRect
var pointer: ColorRect
var tap_btn: Button
var hint: Label
var choice_box: Control
var sword_cp: Node3D
var guards: Array = []
var march_t := -1.0
var spark_t := 0.0
var clang_t := 0.0
var winner_t := 0
var loser_t := 0


func update(dt: float) -> void:
	match state:
		"":
			cd -= dt
			if cd > 0.0 or battle.net.online or battle.over:
				return
			pk = battle.heroes.get(battle.my_id)
			if pk == null or not is_instance_valid(pk) or pk.dead:
				return
			ek = null
			for ot in kingdom.nk:
				if ot != pk.team and kingdom.at_war(pk.team, ot):
					var kk = battle.team_king(ot)
					if kk != null and not kk.dead and pk.position.distance_to(kk.position) < 4.0:
						ek = kk
						break
			if ek == null:
				return
			if pk.swing > 0.3 and ek.swing > 0.3 and randf() < 0.5:
				_start()
		"lock":
			_tick_lock(dt)
		"end":
			_tick_march(dt)


# ------------------------------------------------------------------ the lock
func _start() -> void:
	state = "lock"
	t = 0.0
	p = 0.5
	var d: Vector3 = ek.position - pk.position
	d.y = 0.0
	dirv = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	mid = (pk.position + ek.position) * 0.5
	mid.y = 0.0
	pk.position = mid - dirv * 0.95
	ek.position = mid + dirv * 0.95
	pk.rotation.y = atan2(dirv.x, dirv.z)
	ek.rotation.y = atan2(-dirv.x, -dirv.z)
	for k in [pk, ek]:
		k.clash_lock = true
		k.blocking = false
		k.swing = 0.0
		k.pose_mode = "lock"
	pk.pose_side = 1.0
	ek.pose_side = -1.0
	var side: Vector3 = dirv.cross(Vector3.UP).normalized()
	battle.cine_shot(mid + side * 5.2 + Vector3(0, 1.5, 0), mid + side * 3.6 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.5, 0), mid + Vector3(0, 1.6, 0), 14.0)
	_hide_hud()
	_build_overlay()
	_say("BLADES LOCKED!", Color(1.0, 0.8, 0.3), 1.6)


func _hide_hud() -> void:
	hidden.clear()
	var cands: Array = [battle.hud.root.get_parent()]
	if kingdom.ui.has("root"):
		cands.append(kingdom.ui.root.get_parent())
	for cl in cands:
		if cl is CanvasLayer and cl.visible:
			cl.visible = false
			hidden.append(cl)


func _show_hud() -> void:
	for c in hidden:
		if is_instance_valid(c):
			c.visible = true
	hidden.clear()


# big centre-screen caption on our own layer (the normal HUD layer is hidden during the scene)
func _say(text: String, col: Color, secs: float) -> void:
	if ov == null or not is_instance_valid(ov):
		battle.banner(text, col, secs)
		return
	var u: float = battle.ui_u
	var l := Label.new()
	l.text = LocS.t(text)
	l.position = Vector2(0, battle.vs.y * 0.3)
	l.size = Vector2(battle.vs.x, 90 * u)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(66 * u))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", int(14 * u))
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.5, 1.5)
	l.modulate.a = 0.0
	ov.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.2, secs - 0.8))
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _build_overlay() -> void:
	var u: float = battle.ui_u
	var vs: Vector2 = battle.vs
	layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	ov = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ov)
	var mw: float = minf(vs.x * 0.62, 900.0 * u)
	var mx: float = (vs.x - mw) * 0.5
	var my: float = vs.y * 0.14
	var frame := ColorRect.new()
	frame.color = Color(0.86, 0.68, 0.28)
	frame.position = Vector2(mx - 5 * u, my - 5 * u)
	frame.size = Vector2(mw + 10 * u, 40 * u)
	ov.add_child(frame)
	meter_l = ColorRect.new()
	meter_l.color = battle.team_col(pk.team)
	meter_l.position = Vector2(mx, my)
	meter_l.size = Vector2(mw * 0.5, 30 * u)
	ov.add_child(meter_l)
	meter_r = ColorRect.new()
	meter_r.color = battle.team_col(ek.team)
	meter_r.position = Vector2(mx + mw * 0.5, my)
	meter_r.size = Vector2(mw * 0.5, 30 * u)
	ov.add_child(meter_r)
	pointer = ColorRect.new()
	pointer.color = Color(1, 1, 1)
	pointer.size = Vector2(10 * u, 56 * u)
	pointer.position = Vector2(mx + mw * 0.5 - 5 * u, my - 13 * u)
	ov.add_child(pointer)
	ov.set_meta("mx", mx)
	ov.set_meta("mw", mw)
	var nm := func(txt: String, x: float, al: int, col: Color):
		var l := Label.new()
		l.text = txt
		l.position = Vector2(x, my - 46 * u)
		l.size = Vector2(mw * 0.5, 36 * u)
		l.horizontal_alignment = al
		l.add_theme_font_size_override("font_size", int(24 * u))
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", int(6 * u))
		ov.add_child(l)
	nm.call(String(kingdom.king_name(pk.team)).to_upper(), mx, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	nm.call(String(kingdom.king_name(ek.team)).to_upper(), mx + mw * 0.5, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.85, 0.8))
	hint = Label.new()
	hint.text = LocS.t("TAP! TAP! TAP!")
	hint.position = Vector2(0, vs.y * 0.24)
	hint.size = Vector2(vs.x, 70 * u)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", int(52 * u))
	hint.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	hint.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.02))
	hint.add_theme_constant_override("outline_size", int(12 * u))
	ov.add_child(hint)
	tap_btn = Button.new()
	tap_btn.text = LocS.t("TAP!")
	var bs: float = 210.0 * u
	tap_btn.position = Vector2(vs.x * 0.5 - bs * 0.5, vs.y - bs - 22 * u)
	tap_btn.size = Vector2(bs, bs)
	tap_btn.add_theme_font_size_override("font_size", int(46 * u))
	preload("res://game/uifx.gd").style_btn(tap_btn, u)
	tap_btn.add_theme_font_size_override("font_size", int(46 * u))
	tap_btn.button_down.connect(_tap)
	ov.add_child(tap_btn)


func _tap() -> void:
	if state != "lock":
		return
	p = minf(1.0, p + 0.042)
	var tw := tap_btn.create_tween()
	tap_btn.pivot_offset = tap_btn.size * 0.5
	tap_btn.scale = Vector2(0.9, 0.9)
	tw.tween_property(tap_btn, "scale", Vector2.ONE, 0.09)


func _tick_lock(dt: float) -> void:
	t += dt
	var rate := 0.16
	match preload("res://game/profile.gd").diff:
		"easy":
			rate = 0.12
		"hard":
			rate = 0.21
	p -= (rate + 0.05 * sin(t * 3.0)) * dt
	p = clampf(p, 0.0, 1.0)
	pk.pose_push = (p - 0.5) * 2.0
	ek.pose_push = -(p - 0.5) * 2.0
	var mx: float = ov.get_meta("mx")
	var mw: float = ov.get_meta("mw")
	meter_l.size.x = mw * p
	meter_r.position.x = mx + mw * p
	meter_r.size.x = mw * (1.0 - p)
	pointer.position.x = mx + mw * p - pointer.size.x * 0.5
	hint.modulate.a = 0.6 + 0.4 * sin(t * 12.0)
	hint.scale = Vector2.ONE * (1.0 + 0.04 * sin(t * 12.0))
	hint.pivot_offset = hint.size * 0.5
	spark_t -= dt
	if spark_t <= 0.0:
		spark_t = 0.12
		battle._burst(mid + Vector3(0, 1.55, 0), Color(1.0, 0.85, 0.4), 5, 4.0, true)
	clang_t -= dt
	if clang_t <= 0.0:
		clang_t = 0.32
		battle.sfx.play("clang", mid, -2.0, randf_range(0.9, 1.3))
	if p >= 1.0 or (t > 11.0 and p >= 0.5):
		_win()
	elif p <= 0.0 or t > 11.0:
		_lose()


func _lose() -> void:
	state = ""
	cd = 14.0
	battle.banner("YOU WERE PUSHED BACK!", Color(1.0, 0.4, 0.3), 1.6)
	pk.hp = maxf(pk.max_hp * 0.1, pk.hp - pk.max_hp * 0.3)
	pk.stagger = 1.0
	pk.position -= dirv * 2.2
	ek.position += dirv * 0.6
	_cleanup()


func _win() -> void:
	state = "won"
	if tap_btn != null:
		tap_btn.queue_free()
	hint.queue_free()
	_say("YOU WON THE CLASH!", Color(1.0, 0.85, 0.3), 2.0)
	battle._slowmo(0.35, 1.0)
	battle.cine_orbit(ek.position + Vector3(0, 1.3, 0), 7.5, 2.6, 6.0, 0.6)
	ek.pose_push = -1.0
	pk.pose_mode = ""
	ek.pose_mode = "kneel"
	sword_cp = preload("res://game/rig.gd").drop_sword(ek)
	var kd: Vector3 = ek.position + dirv * 1.0
	ek.position = kd
	battle._burst(ek.position + Vector3(0, 1.0, 0), Color(0.72, 0.62, 0.45), 14, 4.0, false)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(_show_choices)


func _show_choices() -> void:
	if state != "won":
		return
	var u: float = battle.ui_u
	var vs: Vector2 = battle.vs
	choice_box = Control.new()
	choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(choice_box)
	var cap := Label.new()
	cap.text = LocS.t("The enemy king is at your mercy")
	cap.position = Vector2(0, vs.y * 0.2)
	cap.size = Vector2(vs.x, 60 * u)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", int(40 * u))
	cap.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	cap.add_theme_color_override("font_outline_color", Color(0.15, 0.04, 0.02))
	cap.add_theme_constant_override("outline_size", int(10 * u))
	choice_box.add_child(cap)
	var opts := [["IMPRISON", "capture"], ["BEHEAD", "behead"], ["SPARE", "spare"]]
	var bw: float = minf(vs.x * 0.28, 300.0 * u)
	var gap: float = 18.0 * u
	var x0: float = (vs.x - (bw * 3 + gap * 2)) * 0.5
	for i in 3:
		var b := Button.new()
		b.text = LocS.t(opts[i][0])
		b.position = Vector2(x0 + i * (bw + gap), vs.y - 150 * u)
		b.size = Vector2(bw, 100 * u)
		preload("res://game/uifx.gd").style_btn(b, u)
		b.add_theme_font_size_override("font_size", int(30 * u))
		var key: String = opts[i][1]
		b.pressed.connect(func(): _choose(key))
		choice_box.add_child(b)


func _choose(key: String) -> void:
	if state != "won":
		return
	if choice_box != null:
		choice_box.queue_free()
		choice_box = null
	winner_t = pk.team
	loser_t = ek.team
	kingdom.final_team = loser_t
	match key:
		"behead":
			_behead()
		"spare":
			_spare()
		_:
			_capture()


func _behead() -> void:
	state = "end"
	march_t = -1.0
	pk.clash_lock = false
	pk.combo = 2          # HERO_SEQ[2] = the beheading cut
	pk.atk_cd = 0.0
	pk.rotation.y = atan2(dirv.x, dirv.z)
	ek.pose_mode = ""
	ek.position = pk.position + dirv * 1.7
	battle._slowmo(0.4, 1.4)
	_say("OFF WITH HIS HEAD!", Color(1.0, 0.35, 0.25), 2.0)
	pk._strike(ek, 9999.0, false)
	get_tree().create_timer(2.0).timeout.connect(func():
		_show_hud()
		_free_overlay()
		state = "")


func _spare() -> void:
	state = "end"
	pk.pose_mode = "sheath"
	ek.pose_mode = "bow"
	pk.rotation.y = atan2(dirv.x, dirv.z)
	_say("MERCY", Color(0.7, 0.9, 1.0), 2.5)
	battle.cine_shot(mid + Vector3(3.5, 1.4, 3.0), mid + Vector3(2.4, 1.6, 2.2), mid + Vector3(0, 1.0, 0), mid + Vector3(0, 1.0, 0), 4.0)
	get_tree().create_timer(3.4).timeout.connect(func():
		pk.pose_mode = ""
		ek.pose_mode = ""
		_show_hud()
		_free_overlay()
		state = ""
		pk.clash_lock = false
		ek.clash_lock = false
		kingdom.duel_end_manual(loser_t, winner_t))


func _capture() -> void:
	state = "end"
	_say("THE KING IS CAPTURED", Color(1.0, 0.8, 0.3), 2.5)
	ek.puppet = true
	ek.tpos = ek.position
	ek.tyaw = ek.rotation.y
	ek.pose_mode = "kneel"
	pk.pose_mode = ""
	pk.clash_lock = false
	guards.clear()
	var ang: float = atan2(dirv.x, dirv.z)
	var right: Vector3 = Vector3(cos(ang), 0, -sin(ang))
	for i in 2:
		var s: float = -1.0 if i == 0 else 1.0
		var g = battle._make_unit("sword", pk.team, pk.owner_id, ek.position - dirv * 9.0 + right * s * 5.0)
		g.puppet = true
		g.tpos = g.position
		g.tyaw = ang
		g.set_meta("side", s)
		guards.append(g)
	march_t = 0.0
	battle.cine_orbit(ek.position + Vector3(0, 1.3, 0), 9.0, 3.0, 9.0, 0.5)


func _tick_march(dt: float) -> void:
	if march_t < 0.0 or guards.is_empty():
		return
	march_t += dt
	var ang: float = atan2(dirv.x, dirv.z)
	var right: Vector3 = Vector3(cos(ang), 0, -sin(ang))
	var heading: Vector3 = (kingdom.home_pos(pk.team) - ek.position)
	heading.y = 0.0
	heading = heading.normalized() if heading.length() > 0.01 else -dirv
	var hang: float = atan2(heading.x, heading.z)
	var hright: Vector3 = Vector3(cos(hang), 0, -sin(hang))
	if march_t < 2.6:
		# the guards run up and take him by the wrists
		for g in guards:
			var s: float = g.get_meta("side")
			var dest: Vector3 = ek.position + right * s * 1.05
			g.tpos = g.tpos.move_toward(dest, dt * 4.5)
			g.tyaw = atan2(ek.position.x - g.tpos.x, ek.position.z - g.tpos.z)
		if march_t > 2.4:
			ek.pose_mode = "held"
			for g in guards:
				g.pose_mode = "grip"
				g.pose_side = -float(g.get_meta("side"))
	elif march_t < 7.5:
		ek.tyaw = hang
		var step: Vector3 = heading * 2.2 * dt
		ek.tpos += step
		for g in guards:
			var s2: float = g.get_meta("side")
			g.tpos = ek.tpos + hright * s2 * 1.05
			g.tyaw = hang
	else:
		march_t = -1.0
		_show_hud()
		_free_overlay()
		state = ""
		for g in guards:
			if is_instance_valid(g):
				g.pose_mode = ""
		ek.clash_lock = false
		kingdom.duel_end_manual(loser_t, winner_t)


func _cleanup() -> void:
	for k in [pk, ek]:
		if is_instance_valid(k):
			k.clash_lock = false
			k.pose_mode = ""
	battle.cine = {}
	_show_hud()
	_free_overlay()


func _free_overlay() -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	layer = null
