extends Node
# The royal court: the ADVISOR (understands Arabic + English), the MESSENGER prompt,
# scouts who report enemy sightings, and the castle names.

const AdvisorS := preload("res://game/advisor.gd")

var kingdom
var battle
var mapv
var root: Control
var panel: PanelContainer
var log_lbl: Label
var edit: LineEdit
var lang_btn: Button
var talk_btn: Button
var talk_kind := ""
var is_open := false
var lang_ar := false
var lines: Array = []
var pending := ""              # "war" while waiting for yes / no
var scout_cd := 0.0
var scout_seen := {}
var tick := 0.0

const NAMES_EN := ["Castle Eaglecrest", "Castle Blackthorn"]
const NAMES_AR := ["قلعة النسر", "قلعة الشوك الأسود"]


static func castle_name(t: int, ar := false) -> String:
	return NAMES_AR[t] if ar else NAMES_EN[t]


func _L(en: String, ar: String) -> String:
	return ar if lang_ar else en


# ================================================================== UI
func build_ui(r: Control, u: float, vs: Vector2) -> void:
	root = r
	var mk := func(text: String, pos: Vector2, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.position = pos * u
		b.size = Vector2(150, 58) * u
		b.pressed.connect(cb)
		root.add_child(b)
		return b
	mk.call("MAP", Vector2(180, 122), func(): mapv.toggle())
	mk.call("ADVISOR", Vector2(340, 122), func(): toggle())
	talk_btn = mk.call("TALK", Vector2(20, 186), func(): _talk())
	talk_btn.size = Vector2(190, 62) * u
	talk_btn.visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(vs.x * 0.5 - 360 * u, 40 * u)
	panel.custom_minimum_size = Vector2(720, 100) * u
	panel.visible = false
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(head)
	var tl := Label.new()
	tl.text = "ROYAL ADVISOR"
	tl.add_theme_font_size_override("font_size", int(26 * u))
	tl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	lang_btn = Button.new()
	lang_btn.text = "EN"
	lang_btn.custom_minimum_size = Vector2(80, 46) * u
	lang_btn.pressed.connect(func():
		lang_ar = not lang_ar
		lang_btn.text = "AR" if lang_ar else "EN"
		_say(_L("At your service, my king.", "في خدمتك يا مولاي.")))
	head.add_child(lang_btn)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(60, 46) * u
	x.pressed.connect(close)
	head.add_child(x)
	log_lbl = Label.new()
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_lbl.custom_minimum_size = Vector2(690, 230) * u
	log_lbl.text_direction = Control.TEXT_DIRECTION_AUTO
	log_lbl.add_theme_font_size_override("font_size", int(23 * u))
	log_lbl.add_theme_color_override("font_color", Color(0.93, 0.93, 0.97))
	vb.add_child(log_lbl)
	var hint := Label.new()
	hint.text = "Type, or tap the microphone on your keyboard to speak. Arabic or English."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(690, 0) * u
	hint.add_theme_font_size_override("font_size", int(17 * u))
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	vb.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(row)
	edit = LineEdit.new()
	edit.placeholder_text = "e.g. build 2 houses / ابني ثكنة وجيب 5 سيافة"
	edit.custom_minimum_size = Vector2(500, 62) * u
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_direction = Control.TEXT_DIRECTION_AUTO
	edit.add_theme_font_size_override("font_size", int(24 * u))
	edit.text_submitted.connect(func(t): _submit())
	row.add_child(edit)
	var send := Button.new()
	send.text = "SEND"
	send.custom_minimum_size = Vector2(150, 62) * u
	send.pressed.connect(_submit)
	row.add_child(send)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if battle.modal and not is_open:
		return
	if kingdom.ui.panel.visible:
		kingdom._toggle_panel()
	is_open = true
	panel.visible = true
	battle.modal = true
	if lines.is_empty():
		_say(_L("At your service, my king. Tell me what to do - build, train, march, guard the castle, or send a letter.", "في خدمتك يا مولاي. قلّي شنو تبي: بناء، تدريب، هجوم، حراسة القلعة أو رسالة."))
	edit.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	panel.visible = false
	battle.modal = false
	edit.release_focus()


func _say(text: String, who := "ADVISOR") -> void:
	lines.append("%s: %s" % [who if not lang_ar or who != "ADVISOR" else "المستشار", text])
	while lines.size() > 6:
		lines.pop_front()
	if log_lbl != null:
		log_lbl.text = "\n".join(lines)


func _submit() -> void:
	var txt := edit.text.strip_edges()
	if txt.is_empty():
		return
	edit.text = ""
	if AdvisorS.is_arabic(txt):
		lang_ar = true
		lang_btn.text = "AR"
	elif txt.length() > 2:
		lang_ar = false
		lang_btn.text = "EN"
	lines.append("%s %s" % [("أنت:" if lang_ar else "YOU:"), txt])
	run(txt)
	edit.grab_focus()


# ================================================================== running orders
func run(text: String) -> void:
	var acts: Array = AdvisorS.parse(text)
	for a in acts:
		_do(a)


func _soldier_count() -> int:
	var n := 0
	for u in battle.units.values():
		if u.team == kingdom.my_team and not u.dead and u.kind != "villager" and u.kind != "hero":
			n += 1
	return n


func _repeat(act: String, n: int, data := {}) -> int:
	var k := clampi(n, 1, 12)
	for i in k:
		kingdom.cmd(act, data)
	return k


func _do(a: Dictionary) -> void:
	var act: String = a.get("act", "unknown")
	var t: int = kingdom.my_team
	if act != "yes" and act != "no" and act != "unknown":
		if pending != "" :
			pending = ""
	match act:
		"hi":
			_say(_L("Peace be upon you, my king!", "السلام عليك يا مولاي!"))
		"thanks":
			_say(_L("It is my honour.", "هذا واجبي يا مولاي."))
		"help":
			_say(_L("Try: 'build 2 houses', 'train 5 archers', 'buy food', 'upgrade the castle', 'attack', 'hold the gate', 'keep 30% to guard', 'where is the enemy', 'send a letter saying ...'.", "جرّب: 'ابني بيتين'، 'درّب 5 رماة'، 'اشتري اكل'، 'طوّر القلعة'، 'هاجم'، 'ثبّتهم عند البوابة'، 'خلي 30% يحرسو القلعة'، 'وين العدو'، 'ارسل رسالة تقول ...'."))
		"map":
			close()
			mapv.open()
		"house":
			var k := _repeat("house", int(a.n))
			_say(_L("Building %d house(s)." % k, "نبني %d بيت." % k))
		"barracks":
			var k2 := _repeat("barracks", int(a.n))
			_say(_L("Barracks ordered.", "تم طلب بناء الثكنة."))
		"upgrade":
			kingdom.cmd("upgrade")
			_say(_L("Developing the castle.", "نطوّر القلعة."))
		"villager":
			var k3 := _repeat("villager", int(a.n))
			_say(_L("Hiring %d villager(s)." % k3, "نوظف %d فلاح." % k3))
		"buyfood":
			var k4 := _repeat("buyfood", int(a.n))
			_say(_L("Buying food %d time(s)." % k4, "نشتري الأكل %d مرة." % k4))
		"train":
			var kd: String = a.kind
			var k5 := _repeat("train", int(a.n), {"kind": kd})
			var nm: Array = {"sword": ["swordsmen", "سيافة"], "archer": ["archers", "رماة"], "cav": ["cavalry", "فرسان"]}[kd]
			_say(_L("Training %d %s." % [k5, nm[0]], "ندرّب %d من %s." % [k5, nm[1]]))
		"war":
			if battle.war:
				_say(_L("We are already at war, my king!", "نحن في حرب أصلاً يا مولاي!"))
			else:
				pending = "war"
				_say(_L("Declare war on %s? Say YES to confirm." % castle_name(1 - t), "نعلن الحرب على %s؟ قل نعم للتأكيد." % castle_name(1 - t, true)))
		"yes":
			if pending == "war":
				pending = ""
				kingdom.cmd("war")
				_say(_L("War is declared! The army will march.", "أُعلنت الحرب! الجيش سيزحف."))
			else:
				_say(_L("Yes, my king? Tell me what to do.", "نعم يا مولاي؟ قلّي شنو تبي."))
		"no":
			if pending != "":
				pending = ""
				_say(_L("As you wish. Cancelled.", "كما تأمر. تم الإلغاء."))
			else:
				_say(_L("As you wish.", "كما تأمر."))
		"letter":
			var text: String = String(a.get("text", "")).strip_edges()
			if text.is_empty():
				close()
				kingdom._show_compose("")
				_say(_L("Write your words, my king.", "اكتب كلامك يا مولاي."))
			else:
				kingdom.cmd("letter", {"text": text.substr(0, 240)})
				_say(_L("The messenger rides with your letter: \"%s\"" % text, "الرسول انطلق بالرسالة: \"%s\"" % text))
		"garrison":
			var pct: int = int(a.get("pct", -1))
			var n: int = int(a.get("n", 0))
			var total := _soldier_count()
			if pct < 0:
				pct = 0 if n <= 0 else clampi(int(round(100.0 * n / maxf(total, 1.0))), 0, 100)
			pct = clampi(pct, 0, 100)
			mapv.set_garrison(pct)
			_say(_L("%d%% of the soldiers will stay and guard the castle." % pct, "%d%% من الجنود يبقو يحرسو القلعة." % pct))
		"order":
			_order(a)
		"status":
			_status(String(a.get("what", "all")))
		"enemy_where":
			_enemy_where()
		_:
			_say(_L("I did not understand, my king. Say 'help' to hear what I can do.", "ما فهمت يا مولاي. قل 'مساعدة' وانا نقولك شنو نقدر نسوي."))


func _order(a: Dictionary) -> void:
	var t: int = kingdom.my_team
	var mode: int = int(a.mode)
	var mask: int = int(a.mask)
	var where: String = String(a.where)
	var pos := Vector3.ZERO
	var h = battle.heroes.get(battle.my_id)
	if where == "home":
		pos = kingdom.home_pos(t)
	elif where == "gate":
		pos = kingdom.gate_in(t) + Vector3(0, 0, -kingdom.dz_of(t) * -8.0)
		pos = Vector3(0, 0, -kingdom.dz_of(t) * 62.0)
	elif where == "here":
		pos = h.position if h != null else kingdom.home_pos(t)
	battle.order_at(mode, mask, pos, -1)
	var en := ""
	var ar := ""
	match mode:
		1:
			en = "The army advances on %s!" % castle_name(1 - t)
			ar = "الجيش يتقدم نحو %s!" % castle_name(1 - t, true)
		3:
			en = "CHARGE!"
			ar = "هجووم!"
		4:
			en = "Falling back to the castle."
			ar = "ننسحب للقلعة."
		2:
			en = "Holding position."
			ar = "نثبت في المكان."
		_:
			en = "They follow you."
			ar = "يتبعونك."
	_say(_L(en, ar))
	if mode == 1 or mode == 3:
		close()


func _status(what: String) -> void:
	var t: int = kingdom.my_team
	var vn := 0
	var sw := 0
	var ar_ := 0
	var cv := 0
	for u in battle.units.values():
		if u.team != t or u.dead:
			continue
		match u.kind:
			"villager": vn += 1
			"sword": sw += 1
			"archer": ar_ += 1
			"cav": cv += 1
	var en := "Gold %d, food %d. Villagers %d. Soldiers: %d swords, %d archers, %d cavalry. Castle %d/%d, level %d." % [int(kingdom.gold[t]), int(kingdom.food[t]), vn, sw, ar_, cv, int(kingdom.castle_hp[t]), kingdom.CASTLE_HP[kingdom.level[t] - 1], kingdom.level[t]]
	var ar := "الذهب %d، الأكل %d. الفلاحين %d. الجنود: %d سيافة، %d رماة، %d فرسان. القلعة %d/%d، مستوى %d." % [int(kingdom.gold[t]), int(kingdom.food[t]), vn, sw, ar_, cv, int(kingdom.castle_hp[t]), kingdom.CASTLE_HP[kingdom.level[t] - 1], kingdom.level[t]]
	_say(_L(en, ar))


func _zone(p: Vector3) -> Array:
	var t: int = kingdom.my_team
	var dz: float = kingdom.dz_of(t)
	var d: float = -dz * p.z          # + = toward my castle side... (my castle sits at -dz*73)
	var depth: float = p.z * -dz      # distance along my axis (positive behind my front wall)
	var gate := Vector3(0, 0, -dz * 73.0)
	var dist := int(p.distance_to(gate))
	var side_en := "in the middle"
	var side_ar := "في الوسط"
	if p.x < -20.0:
		side_en = "on the left flank"
		side_ar = "على الجناح الأيسر"
	elif p.x > 20.0:
		side_en = "on the right flank"
		side_ar = "على الجناح الأيمن"
	if depth > 60.0 and absf(d) < 0.0:
		pass
	return [dist, side_en, side_ar]


func _enemy_where() -> void:
	var s: Array = mapv.enemy_sightings()
	var t: int = kingdom.my_team
	if s.is_empty():
		_say(_L("No enemy in sight, my king. The fog hides them - send scouts or advance.", "ما نشوف العدو يا مولاي. الضباب يخبّيهم - ابعث كشافة او تقدّم."))
		return
	var cx := 0.0
	var cz := 0.0
	for e in s:
		cx += e.pos.x
		cz += e.pos.z
	cx /= s.size()
	cz /= s.size()
	var z: Array = _zone(Vector3(cx, 0, cz))
	_say(_L("%d soldiers of %s, about %d m from our gate, %s." % [s.size(), castle_name(1 - t), z[0], z[1]], "%d جندي من %s، تقريباً %d متر من بوابتنا، %s." % [s.size(), castle_name(1 - t, true), z[0], z[2]]))
	mapv.add_ping(Vector3(cx, 0, cz))


# ================================================================== scouts / reports
func _process(dt: float) -> void:
	if kingdom == null or battle == null or not kingdom.vis_ready:
		return
	scout_cd = maxf(0.0, scout_cd - dt)
	tick -= dt
	if tick > 0.0:
		return
	tick = 0.4
	_update_talk()
	if not battle.war or battle.over:
		return
	var s: Array = mapv.enemy_sightings()
	if s.is_empty():
		return
	var t: int = kingdom.my_team
	var dz: float = kingdom.dz_of(t)
	var gate := Vector3(0, 0, -dz * 73.0)
	var close_n := 0
	var cx := 0.0
	var cz := 0.0
	for e in s:
		if e.pos.distance_to(gate) < 80.0:
			close_n += 1
			cx += e.pos.x
			cz += e.pos.z
	if close_n == 0 or scout_cd > 0.0:
		return
	scout_cd = 45.0
	cx /= close_n
	cz /= close_n
	var z: Array = _zone(Vector3(cx, 0, cz))
	mapv.add_ping(Vector3(cx, 0, cz))
	battle.sfx.play_ui("horn", -2.0)
	var en := "My king! A scout reports: %d soldiers of %s are near - about %d m from our gate, %s." % [close_n, castle_name(1 - t), z[0], z[1]]
	var ar := "يا مولاي! الكشاف يبلغ: %d جندي من %s قريبين - حوالي %d متر من البوابة، %s." % [close_n, castle_name(1 - t, true), z[0], z[2]]
	_say(_L(en, ar), "SCOUT" if not lang_ar else "الكشاف")
	_scout_modal(en, ar)


func _scout_modal(en: String, ar: String) -> void:
	if battle.modal:
		battle._toast(_L(en, ar), 5.0)
		return
	var u: float = battle.ui_u
	var m: Array = kingdom._modal(_L("A SCOUT HAS ARRIVED", "وصل الكشاف"), u)
	var dim: Control = m[0]
	var vb: VBoxContainer = m[1]
	var body := Label.new()
	body.text = _L(en, ar)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 120) * u
	body.text_direction = Control.TEXT_DIRECTION_AUTO
	body.add_theme_font_size_override("font_size", int(27 * u))
	body.add_theme_color_override("font_color", Color(0.2, 0.1, 0.03))
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * u))
	vb.add_child(row)
	var b1 := Button.new()
	b1.text = "SHOW MAP"
	b1.custom_minimum_size = Vector2(240, 62) * u
	b1.pressed.connect(func():
		kingdom._close_modal(dim)
		mapv.open())
	row.add_child(b1)
	var b2 := Button.new()
	b2.text = "Understood"
	b2.custom_minimum_size = Vector2(220, 62) * u
	b2.pressed.connect(func(): kingdom._close_modal(dim))
	row.add_child(b2)


# ================================================================== talking to NPCs
func _update_talk() -> void:
	talk_kind = ""
	if kingdom.fortress != null and not battle.modal:
		var h = battle.heroes.get(battle.my_id)
		if h != null:
			if kingdom.fortress.npc_near("messenger", h.position, 7.0):
				talk_kind = "messenger"
			elif kingdom.fortress.npc_near("advisor", h.position, 7.0):
				talk_kind = "advisor"
	talk_btn.visible = talk_kind != ""
	if talk_kind == "messenger":
		talk_btn.text = "TALK: MESSENGER"
	elif talk_kind == "advisor":
		talk_btn.text = "TALK: ADVISOR"


func _talk() -> void:
	if talk_kind == "advisor":
		open()
	elif talk_kind == "messenger":
		kingdom._show_compose("")
