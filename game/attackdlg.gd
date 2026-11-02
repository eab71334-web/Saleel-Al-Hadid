extends Control
# The advisor pops up when you tap an enemy castle on the war map: pick how many of each unit, confirm, hear the order.

const LocS := preload("res://game/loc.gd")
var kingdom
var battle
var mapv
var target := -1
var talking := 0.0
var blink_t := 0.0
var t := 0.0
var speech: Label
var title: Label
var info: Label
var sliders := {}
var vals := {}
var lbls := {}
var confirm: Button
var grp_btn: Button
var face: Control
var _type_txt := ""
var _type_i := 0.0
var _u := 1.0
var _avail := {}


func build(u: float, vs: Vector2) -> void:
	_u = u
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.97)
	sb.border_color = Color(0.9, 0.7, 0.25)
	sb.set_border_width_all(int(4 * u))
	sb.set_corner_radius_all(int(18 * u))
	sb.content_margin_left = 20 * u
	sb.content_margin_right = 20 * u
	sb.content_margin_top = 14 * u
	sb.content_margin_bottom = 14 * u
	sb.shadow_size = int(16 * u)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", sb)
	var pw := minf(vs.x - 40 * u, 980 * u)
	panel.custom_minimum_size = Vector2(pw, 0)
	panel.position = Vector2((vs.x - pw) * 0.5, 6 * u)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(18 * u))
	panel.add_child(hb)
	face = Control.new()
	face.custom_minimum_size = Vector2(220, 260) * u
	face.draw.connect(_draw_face)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(face)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", int(8 * u))
	hb.add_child(vb)
	title = Label.new()
	title.add_theme_font_size_override("font_size", int(30 * u))
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vb.add_child(title)
	speech = Label.new()
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size = Vector2(0, 70 * u)
	speech.add_theme_font_size_override("font_size", int(22 * u))
	speech.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vb.add_child(speech)
	var kinds := [["sword", "Swordsmen"], ["archer", "Archers"], ["cav", "Cavalry"], ["ballista", "Ballistas"], ["catapult", "Catapults"]]
	for kd in kinds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(10 * u))
		vb.add_child(row)
		var l := Label.new()
		l.custom_minimum_size = Vector2(250, 0) * u
		l.add_theme_font_size_override("font_size", int(23 * u))
		row.add_child(l)
		var s := HSlider.new()
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(200, 46) * u
		s.step = 1
		var key: String = kd[0]
		var nm: String = kd[1]
		s.value_changed.connect(func(v):
			vals[key] = int(v)
			lbls[key].text = "%s: %d / %d" % [nm, int(v), int(_avail.get(key, 0))])
		row.add_child(s)
		sliders[key] = s
		lbls[key] = l
		vals[key] = 0
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(pr)
	for p in [["ALL", 1.0], ["HALF", 0.5], ["NONE", 0.0]]:
		var b := Button.new()
		b.text = p[0]
		b.custom_minimum_size = Vector2(120, 52) * u
		var f: float = p[1]
		b.pressed.connect(func(): _preset(f))
		pr.add_child(b)
	info = Label.new()
	info.add_theme_font_size_override("font_size", int(19 * u))
	info.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", int(10 * u))
	vb.add_child(fr)
	confirm = Button.new()
	confirm.text = "CONFIRM ATTACK"
	confirm.custom_minimum_size = Vector2(0, 74) * u
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.55, 0.1, 0.08)
	cs.border_color = Color(1, 0.8, 0.3)
	cs.set_border_width_all(int(3 * u))
	cs.set_corner_radius_all(int(12 * u))
	confirm.add_theme_stylebox_override("normal", cs)
	confirm.add_theme_font_size_override("font_size", int(30 * u))
	confirm.pressed.connect(_confirm)
	fr.add_child(confirm)
	grp_btn = Button.new()
	grp_btn.text = "SEND SELECTED GROUPS"
	grp_btn.custom_minimum_size = Vector2(300, 74) * u
	grp_btn.add_theme_font_size_override("font_size", int(22 * u))
	grp_btn.pressed.connect(_confirm_groups)
	fr.add_child(grp_btn)
	var cn := Button.new()
	cn.text = "CANCEL"
	cn.custom_minimum_size = Vector2(170, 74) * u
	cn.pressed.connect(close)
	fr.add_child(cn)


func _preset(f: float) -> void:
	for k in sliders.keys():
		sliders[k].value = roundi(float(_avail.get(k, 0)) * f)


func _confirm_groups() -> void:
	if mapv.gsel == 0:
		return
	grp_btn.disabled = true
	var ar: bool = LocS.lang == "ar"
	var nm: String = LocS.t(battle.team_name(target)) if ar else battle.team_name(target)
	_say(("الهجوم بالمجموعات المختارة على قلعة %s!" % nm) if ar else "The chosen groups march on the castle of %s!" % nm)
	battle.strike_groups(target, mapv.gsel)
	battle.sfx.play_ui("horn", 2.0)
	battle.sfx.set_theme("epic_attack")
	battle.banner(("الهجوم على %s" % nm) if ar else "ATTACK ON %s" % nm.to_upper(), battle.team_col(target), 3.0)
	get_tree().create_timer(60.0).timeout.connect(func():
		if battle != null and is_instance_valid(battle) and battle.sfx != null:
			battle.sfx.set_theme("epic"))
	get_tree().create_timer(2.0).timeout.connect(func():
		close()
		mapv.close())


func open(tt: int) -> void:
	target = tt
	grp_btn.visible = mapv.gsel != 0
	grp_btn.disabled = false
	var vt: int = kingdom.vteam()
	_avail = {"sword": 0, "archer": 0, "cav": 0, "ballista": 0, "catapult": 0}
	for u in battle.by_team[vt]:
		if not u.dead and _avail.has(u.kind):
			_avail[u.kind] += 1
	for k in sliders.keys():
		sliders[k].max_value = maxi(int(_avail[k]), 1)
		sliders[k].editable = int(_avail[k]) > 0
		sliders[k].value = roundi(float(_avail[k]) * 0.6)
		vals[k] = int(sliders[k].value)
	var nm: String = LocS.t(battle.team_name(tt)) if LocS.lang == "ar" else battle.team_name(tt)
	title.text = ("الهجوم على قلعة %s" % nm) if LocS.lang == "ar" else ("Attack the castle of %s" % nm)
	var war: bool = kingdom.at_war(vt, tt)
	info.text = LocS.t("You are already at war with them.") if war else LocS.t("This will DECLARE WAR on them.")
	_say(("مولاي، كم جندي نرسل إلى قلعة %s؟" % nm) if LocS.lang == "ar" else "My king, how many men do we send against %s?" % nm)
	visible = true
	confirm.disabled = false
	LocS.apply_tree(self)


func close() -> void:
	visible = false
	DisplayServer.tts_stop() if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) else null


func _say(s: String) -> void:
	_type_txt = s
	_type_i = 0.0
	talking = 2.0


func _speak(s: String) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var v: PackedStringArray = DisplayServer.tts_get_voices_for_language("ar" if LocS.lang == "ar" else "en")
	if v.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(s, v[0], 90, 0.85, 1.0)


func _confirm() -> void:
	var total: int = int(vals.sword) + int(vals.archer) + int(vals.cav) + int(vals.ballista) + int(vals.catapult)
	if total <= 0:
		_say(LocS.t("Send at least one soldier, my king."))
		return
	confirm.disabled = true
	var nm: String = LocS.t(battle.team_name(target)) if LocS.lang == "ar" else battle.team_name(target)
	var ar: bool = LocS.lang == "ar"
	var order := ("تأكيد هجوم! استعدوا يا أبطال، الهجوم على قلعة %s! للنصر والمجد!" % nm) if ar else "Attack confirmed! Ready yourselves, warriors - we march on the castle of %s! For glory!" % nm
	_say(order)
	_speak(order)
	battle.strike(target, int(vals.sword), int(vals.archer), int(vals.cav), int(vals.ballista), int(vals.catapult))
	battle.sfx.play_ui("horn", 2.0)
	battle.sfx.set_theme("epic_attack")
	battle.banner(("الهجوم على %s" % nm) if ar else "ATTACK ON %s" % nm.to_upper(), battle.team_col(target), 3.0)
	get_tree().create_timer(60.0).timeout.connect(func():
		if battle != null and is_instance_valid(battle) and battle.sfx != null:
			battle.sfx.set_theme("epic"))
	get_tree().create_timer(3.2).timeout.connect(func():
		close()
		mapv.close())


func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	talking = maxf(0.0, talking - dt)
	if _type_i < _type_txt.length():
		_type_i += dt * 38.0
		speech.text = _type_txt.substr(0, int(_type_i))
	else:
		speech.text = _type_txt
	for k in sliders.keys():
		var nmk: String = {"sword": "Swordsmen", "archer": "Archers", "cav": "Cavalry", "ballista": "Ballistas", "catapult": "Catapults"}[k]
		lbls[k].text = LocS.t(nmk) + ": %d / %d" % [int(vals[k]), int(_avail.get(k, 0))]
	face.queue_redraw()


func _draw_face() -> void:
	var s := face.size
	var c := Vector2(s.x * 0.5, s.y * 0.52)
	var k := s.x / 220.0
	# frame
	face.draw_rect(Rect2(Vector2.ZERO, s), Color(0.2, 0.13, 0.08), true)
	face.draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.65, 0.25), false, 4.0 * k)
	# glow behind
	for i in 5:
		face.draw_circle(c + Vector2(0, -10 * k), (110 - i * 14) * k, Color(0.9, 0.6, 0.2, 0.07))
	# robe
	face.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 100 * k, s.y), Vector2(c.x - 70 * k, c.y + 60 * k), Vector2(c.x + 70 * k, c.y + 60 * k), Vector2(c.x + 100 * k, s.y)]), Color(0.45, 0.1, 0.12))
	face.draw_rect(Rect2(c.x - 14 * k, c.y + 60 * k, 28 * k, s.y - c.y - 60 * k), Color(0.9, 0.75, 0.3))
	# head
	face.draw_circle(c, 62 * k, Color(0.86, 0.66, 0.5))
	# beard
	face.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 58 * k, c.y + 5 * k), Vector2(c.x - 40 * k, c.y + 75 * k + sin(t * 2.0) * 2.0), Vector2(c.x, c.y + 95 * k), Vector2(c.x + 40 * k, c.y + 75 * k + sin(t * 2.0) * 2.0), Vector2(c.x + 58 * k, c.y + 5 * k), Vector2(c.x + 30 * k, c.y + 25 * k), Vector2(c.x - 30 * k, c.y + 25 * k)]), Color(0.82, 0.82, 0.86))
	# turban
	face.draw_circle(c + Vector2(0, -52 * k), 58 * k, Color(0.92, 0.9, 0.85))
	face.draw_arc(c + Vector2(0, -52 * k), 44 * k, 0.3, 2.8, 20, Color(0.75, 0.7, 0.62), 4.0 * k)
	face.draw_arc(c + Vector2(0, -40 * k), 52 * k, 0.2, 2.9, 20, Color(0.75, 0.7, 0.62), 4.0 * k)
	face.draw_circle(c + Vector2(0, -60 * k), 9 * k, Color(0.2, 0.7, 0.9))
	# eyes
	var blink: bool = fmod(t, 3.6) < 0.12
	for sx in [-1.0, 1.0]:
		var ep: Vector2 = c + Vector2(sx * 24 * k, -6 * k)
		if blink:
			face.draw_line(ep - Vector2(9 * k, 0), ep + Vector2(9 * k, 0), Color(0.1, 0.07, 0.05), 3.0 * k)
		else:
			face.draw_circle(ep, 9 * k, Color.WHITE)
			face.draw_circle(ep + Vector2(sin(t) * 2.0, 0), 5 * k, Color(0.15, 0.1, 0.05))
		face.draw_line(ep + Vector2(-12 * k, -14 * k), ep + Vector2(12 * k, -10 * k - sx * 3 * k), Color(0.7, 0.7, 0.75), 4.0 * k)
	# nose + mouth
	face.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4 * k), c + Vector2(-8 * k, 18 * k), c + Vector2(8 * k, 18 * k)]), Color(0.78, 0.58, 0.44))
	var open: float = (0.5 + 0.5 * sin(t * 18.0)) if talking > 0.0 else 0.0
	face.draw_rect(Rect2(c.x - 14 * k, c.y + 32 * k, 28 * k, (3.0 + 12.0 * open) * k), Color(0.25, 0.05, 0.05))
	face.draw_line(c + Vector2(-26 * k, 28 * k), c + Vector2(-4 * k, 26 * k), Color(0.82, 0.82, 0.86), 6.0 * k)
	face.draw_line(c + Vector2(26 * k, 28 * k), c + Vector2(4 * k, 26 * k), Color(0.82, 0.82, 0.86), 6.0 * k)
