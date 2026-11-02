extends Control
# Castle customisation: live 3D preview of the real castle model + option rows. Drag = orbit, pinch / wheel = zoom.

const CK := preload("res://game/castlekit.gd")
const ProfS := preload("res://game/profile.gd")
const LocS := preload("res://game/loc.gd")
const Lobby := preload("res://game/lobby3d.gd")

const GOLD := Color(1.0, 0.82, 0.35)
const DMIN := 14.0
const DMAX := 150.0

const TABS := [
	["Walls", ["wall", "roof", "tstyle", "tcount"]],
	["Banner", ["banner", "emblem", "glow"]],
	["Keep", ["keep", "gate", "moat", "torch"]],
]
const NAMES := {
	"wall": "Stone", "roof": "Roofs", "tstyle": "Tower style", "tcount": "Towers", "banner": "Banner color", "emblem": "Banner emblem",
	"glow": "Window light", "keep": "Keep", "gate": "Gate", "moat": "Moat", "torch": "Gate torches",
}
const VALS := {
	"tstyle": ["Round spire", "Square spire", "Square crown", "Round crown"],
	"tcount": ["4 towers", "6 towers", "9 towers"],
	"emblem": ["None", "Cross", "Diamond", "Crown", "Sword"],
	"keep": ["Low", "Tall", "Grand"],
	"gate": ["Oak", "Iron", "Gold"],
	"glow": ["Warm", "Ice", "Green", "Ember"],
	"moat": ["No", "Yes"], "torch": ["No", "Yes"],
}
const COLORS := ["wall", "roof", "banner"]

var back: Callable
var L: Dictionary = {}
var tab := 0
var vp: SubViewport
var pvc: SubViewportContainer
var cam: Camera3D
var castle_root: Node3D
var out := {}
var rows_box: VBoxContainer
var tab_btns: Array = []
var plate: Label
var hint: Label
var auto_btn: Button
var yaw := 0.5
var pitch := 0.22
var yaw_vel := 0.0
var dist := 85.0
var tdist := 85.0
var focus_t := 0.0
var focus_yaw := 0.0
var auto_rot := false
var dragging := false
var touches := {}
var pinch_d := 0.0
var t_all := 0.0
var _built := false


func _ready() -> void:
	ProfS.load_all()
	L = CK.merged(ProfS.castle)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_make_ui()
	_make_scene()
	_rebuild()
	_show_tab(0)
	_built = true


# ------------------------------------------------------------------ UI
func _styled(c: Color, border: Color, r := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(r)
	return s


func _lbl(p: Control, text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = LocS.t(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return l


func _btn(p: Control, text: String, cb: Callable, w := 0.0, h := 52.0, size := 24) -> Button:
	var b := Button.new()
	b.text = LocS.t(text)
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	p.add_child(b)
	return b


func _make_ui() -> void:
	var bgc := ColorRect.new()
	bgc.color = Color(0.04, 0.035, 0.05)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgc)
	# preview (left)
	pvc = SubViewportContainer.new()
	pvc.stretch = true
	pvc.anchor_left = 0.0
	pvc.anchor_top = 0.0
	pvc.anchor_right = 0.6
	pvc.anchor_bottom = 1.0
	pvc.offset_left = 10
	pvc.offset_top = 10
	pvc.offset_bottom = -10
	pvc.offset_right = -6
	pvc.mouse_filter = Control.MOUSE_FILTER_STOP
	pvc.gui_input.connect(_pv_input)
	add_child(pvc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(760, 700)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pvc.add_child(vp)
	var frame := Panel.new()
	frame.anchor_left = 0.0
	frame.anchor_right = 0.6
	frame.anchor_bottom = 1.0
	frame.offset_left = 10
	frame.offset_top = 10
	frame.offset_bottom = -10
	frame.offset_right = -6
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := _styled(Color(0, 0, 0, 0), Color(0.8, 0.6, 0.22), 14)
	fs.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", fs)
	add_child(frame)
	# name plate
	plate = _lbl(self, "Your Castle", 34, GOLD)
	plate.anchor_left = 0.0
	plate.anchor_right = 0.6
	plate.offset_top = 22
	plate.offset_bottom = 70
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = _lbl(self, "Drag to rotate  -  Pinch to zoom", 20, Color(0.85, 0.85, 0.9, 0.85))
	hint.anchor_left = 0.0
	hint.anchor_right = 0.6
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -112
	hint.offset_bottom = -82
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# camera buttons (bottom of preview)
	var cb := HBoxContainer.new()
	cb.anchor_left = 0.0
	cb.anchor_right = 0.6
	cb.anchor_top = 1.0
	cb.anchor_bottom = 1.0
	cb.offset_top = -76
	cb.offset_bottom = -22
	cb.offset_left = 20
	cb.offset_right = -16
	cb.alignment = BoxContainer.ALIGNMENT_CENTER
	cb.add_theme_constant_override("separation", 8)
	add_child(cb)
	_btn(cb, "Keep", func(): _go(42.0, 0.2), 0, 50, 22)
	_btn(cb, "Castle", func(): _go(80.0, 0.5), 0, 50, 22)
	_btn(cb, "Far", func(): _go(120.0, 0.8), 0, 50, 22)
	_btn(cb, "-", func(): tdist = clampf(tdist * 1.25, DMIN, DMAX), 56, 50, 28)
	_btn(cb, "+", func(): tdist = clampf(tdist * 0.8, DMIN, DMAX), 56, 50, 28)
	auto_btn = _btn(cb, "Spin", func():
		auto_rot = not auto_rot
		auto_btn.modulate = Color(1, 0.9, 0.5) if auto_rot else Color.WHITE, 0, 50, 22)
	# right panel
	var pn := PanelContainer.new()
	pn.anchor_left = 0.6
	pn.anchor_right = 1.0
	pn.anchor_bottom = 1.0
	pn.offset_left = 6
	pn.offset_right = -10
	pn.offset_top = 10
	pn.offset_bottom = -10
	pn.add_theme_stylebox_override("panel", _styled(Color(0.1, 0.08, 0.07, 0.96), Color(0.8, 0.6, 0.22), 14))
	add_child(pn)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pn.add_child(vb)
	_lbl(vb, "CUSTOMIZE CASTLE", 34, GOLD)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	vb.add_child(th)
	for i in TABS.size():
		var idx := i
		var b := _btn(th, TABS[i][0], func(): _show_tab(idx), 0, 50, 21)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btns.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 10)
	sc.add_child(rows_box)
	var ab := HBoxContainer.new()
	ab.add_theme_constant_override("separation", 8)
	vb.add_child(ab)
	var rb := _btn(ab, "Randomize", func():
		L = CK.random_look()
		_changed("wall")
		_show_tab(tab), 0, 54, 21)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rs := _btn(ab, "Reset", func():
		L = CK.DEF.duplicate()
		_changed("wall")
		_show_tab(tab), 0, 54, 21)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done := _btn(vb, "SAVE & BACK", func(): _save_back(), 0, 64, 26)
	done.add_theme_stylebox_override("normal", _styled(Color(0.5, 0.12, 0.1, 0.97), Color(1, 0.75, 0.3)))
	done.add_theme_stylebox_override("hover", _styled(Color(0.7, 0.18, 0.12, 1), Color(1, 0.9, 0.5)))


func _show_tab(i: int) -> void:
	tab = i
	for j in tab_btns.size():
		var b: Button = tab_btns[j]
		if j == i:
			b.add_theme_stylebox_override("normal", _styled(Color(0.55, 0.38, 0.1, 1), Color(1, 0.85, 0.4)))
			b.add_theme_color_override("font_color", Color(1, 1, 0.85))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	for id in TABS[i][1]:
		_row(id)


func _val_text(id: String) -> String:
	var v: int = int(L[id])
	if VALS.has(id):
		return LocS.t(VALS[id][v])
	if id == "banner" and v == 0:
		return LocS.t("Red")
	return "%d / %d" % [v + 1, int(CK.OPTS[id])]


func _swatch(id: String) -> Color:
	var v: int = int(L[id])
	match id:
		"wall": return CK.WALL[v]
		"roof": return CK.ROOF[v]
		"banner": return CK.BANNER[v]
	return Color.WHITE


func _row(id: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	rows_box.add_child(box)
	_lbl(box, NAMES[id], 22, Color(0.9, 0.8, 0.55))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var n: int = int(CK.OPTS[id])
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 22)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(46, 34)
	var refresh := func():
		val.text = _val_text(id)
		if COLORS.has(id):
			sw.color = _swatch(id)
	var step := func(d: int):
		L[id] = posmod(int(L[id]) + d, n)
		refresh.call()
		_changed(id)
	_btn(h, "<", func(): step.call(-1), 64, 54, 26)
	if COLORS.has(id):
		h.add_child(sw)
	h.add_child(val)
	_btn(h, ">", func(): step.call(1), 64, 54, 26)
	refresh.call()


func _changed(id: String) -> void:
	_rebuild()
	match id:
		"wall", "roof", "tstyle", "tcount":
			_focus(82.0, 0.6)
		"banner", "emblem":
			_focus(55.0, 0.15)
		"keep", "glow":
			_focus(62.0, 0.35)
		"gate", "torch", "moat":
			_focus(50.0, 0.0)


func _focus(d: float, y: float) -> void:
	tdist = d
	focus_yaw = y
	focus_t = 1.6


func _go(d: float, y: float) -> void:
	_focus(d, y)


func _save_back() -> void:
	ProfS.castle = L.duplicate()
	ProfS.save()
	if back.is_valid():
		back.call()


func _make_scene() -> void:
	var sh := Shader.new()
	sh.code = Lobby.SKY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.28, 0.45)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.14, 0.24)
	env.fog_density = 0.003
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 150, 0)
	moon.light_color = Color(0.7, 0.75, 1.0)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	vp.add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 20, 0)
	fill.light_color = Color(1.0, 0.8, 0.65)
	fill.light_energy = 0.75
	vp.add_child(fill)
	var hill := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 38.0
	cm.bottom_radius = 80.0
	cm.height = 20.0
	cm.radial_segments = 40
	hill.mesh = cm
	hill.material_override = CK._m(Color(0.09, 0.16, 0.09), 1.0)
	hill.position.y = -10.0
	vp.add_child(hill)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	g.mesh = pm
	g.material_override = CK._m(Color(0.07, 0.12, 0.07), 1.0)
	g.position.y = -20.0
	vp.add_child(g)
	castle_root = Node3D.new()
	vp.add_child(castle_root)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 800.0
	cam.current = true
	vp.add_child(cam)
	_update_cam(0.0)


func _rebuild() -> void:
	for c in castle_root.get_children():
		castle_root.remove_child(c)
		c.queue_free()
	var col: Color = CK.BANNER[int(L.banner)] if int(L.banner) > 0 else Color(0.72, 0.12, 0.12)
	out = CK.build(castle_root, L, col)


func _update_cam(dt: float) -> void:
	dist = lerpf(dist, tdist, clampf(dt * 6.0, 0.0, 1.0)) if dt > 0.0 else tdist
	var tg := Vector3(0, 8.0, 0)
	var c := cos(pitch)
	cam.position = tg + Vector3(sin(yaw) * c, sin(pitch), cos(yaw) * c) * dist
	cam.look_at(tg, Vector3.UP)


func _process(dt: float) -> void:
	if not _built:
		return
	t_all += dt
	if focus_t > 0.0:
		focus_t -= dt
		yaw = lerp_angle(yaw, focus_yaw, clampf(dt * 4.0, 0.0, 1.0))
	if not dragging:
		yaw += yaw_vel * dt
		yaw_vel = lerpf(yaw_vel, 0.0, clampf(dt * 3.0, 0.0, 1.0))
	if auto_rot:
		yaw += dt * 0.35
	yaw = wrapf(yaw, -PI, PI)
	_update_cam(dt)
	CK.sway(out.flags, t_all)
	CK.flicker(out, t_all)


func _pv_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed and touches.size() < 2
			if mb.pressed:
				focus_t = 0.0
				yaw_vel = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			tdist = clampf(tdist * 0.9, DMIN, DMAX)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tdist = clampf(tdist * 1.1, DMIN, DMAX)
	elif e is InputEventMouseMotion and dragging and touches.size() < 2:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * 0.009
		pitch = clampf(pitch + mm.relative.y * 0.006, -0.05, 0.9)
		yaw_vel = -mm.velocity.x * 0.009
		focus_t = 0.0
	elif e is InputEventMagnifyGesture:
		tdist = clampf(tdist / (e as InputEventMagnifyGesture).factor, DMIN, DMAX)


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed and pvc.get_global_rect().has_point(st.position):
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		pinch_d = 0.0
		if touches.size() >= 2:
			dragging = false
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if touches.has(sd.index):
			touches[sd.index] = sd.position
			if touches.size() >= 2:
				var ks: Array = touches.keys()
				var d: float = (touches[ks[0]] - touches[ks[1]]).length()
				if pinch_d > 0.0 and d > 1.0:
					tdist = clampf(tdist * pinch_d / d, DMIN, DMAX)
				pinch_d = d
				focus_t = 0.0
