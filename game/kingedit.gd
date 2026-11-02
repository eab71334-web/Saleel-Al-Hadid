extends Control
# King customisation: a live 3D preview (real in-game rig) on the left, option rows on the right.
# Drag = orbit camera (with inertia), pinch / wheel / buttons = zoom, the king's head follows the camera
# and sweeps slowly when idle.

const KL := preload("res://game/kinglook.gd")
const UnitS := preload("res://game/unit.gd")
const RigS := preload("res://game/rig.gd")
const ProfS := preload("res://game/profile.gd")
const LocS := preload("res://game/loc.gd")
const UiFx := preload("res://game/uifx.gd")

const GOLD := Color(1.0, 0.82, 0.35)

const TABS := [
	["Face", ["skin", "eye", "hair", "haircol", "beard", "scar", "patch"]],
	["Crown", ["helm", "crown", "gem"]],
	["Armor", ["armor", "cape", "pauld", "emblem"]],
	["Arms", ["blade", "epithet"]],
]
const NAMES := {
	"skin": "Skin", "eye": "Eyes", "hair": "Hair", "haircol": "Hair color", "beard": "Beard", "scar": "Scar", "patch": "Eye patch",
	"helm": "Headgear", "crown": "Crown", "gem": "Gem", "armor": "Armor", "cape": "Cape", "pauld": "Shoulders",
	"emblem": "Chest emblem", "blade": "Blade", "epithet": "Title",
}
const VALS := {
	"hair": ["Bald", "Short", "Long", "Topknot", "Mohawk"],
	"beard": ["Clean", "Stubble", "Full beard", "Braided beard"],
	"helm": ["Helmet + crown", "Crown only", "Helmet only"],
	"crown": ["Spiked", "Arched", "Laurel", "Horned"],
	"pauld": ["Plain", "Spiked", "Fur"],
	"emblem": ["None", "Cross", "Diamond", "Star"],
	"scar": ["No", "Yes"], "patch": ["No", "Yes"],
	"epithet": ["No title", "the Iron", "the Just", "the Lionheart", "the Conqueror", "the Wise", "the Black"],
}
const COLORS := ["skin", "eye", "haircol", "gem", "armor", "cape", "blade"]

class Stub extends Node:
	var HORSE_RIDING := false
	var my_id := -9
	var running := false
	var over := false
	var winner_team := -1
	func team_col(_t: int) -> Color:
		return Color(0.72, 0.12, 0.12)

var back: Callable
var L: Dictionary = {}
var tab := 0
var vp: SubViewport
var pvc: SubViewportContainer
var cam: Camera3D
var king
var stub := Stub.new()
var rows_box: VBoxContainer
var tab_btns: Array = []
var plate: Label
var hint: Label
var auto_btn: Button
# camera state
var yaw := 0.35
var pitch := 0.1
var yaw_vel := 0.0
var dist := 3.4
var tdist := 3.4
var focus_t := 0.0
var focus_yaw := 0.0
var idle_t := 0.0
var hy := 0.0
var auto_rot := false
var dragging := false
var touches := {}
var pinch_d := 0.0
var t_all := 0.0
var lights: Array = []
var _built := false


func _ready() -> void:
	ProfS.load_all()
	L = KL.merged(ProfS.look)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stub)
	_make_ui()
	_make_scene()
	_rebuild_king()
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
	plate = _lbl(self, "", 34, GOLD)
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
	_btn(cb, "Face", func(): _go(1.55, 0.35), 0, 50, 22)
	_btn(cb, "Bust", func(): _go(3.1, 0.2), 0, 50, 22)
	_btn(cb, "Full", func(): _go(5.4, 0.0), 0, 50, 22)
	_btn(cb, "-", func(): tdist = clampf(tdist * 1.25, 0.9, 7.0), 56, 50, 28)
	_btn(cb, "+", func(): tdist = clampf(tdist * 0.8, 0.9, 7.0), 56, 50, 28)
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
	_lbl(vb, "CUSTOMIZE KING", 34, GOLD)
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
		L = KL.random_look()
		_changed("skin")
		_show_tab(tab), 0, 54, 21)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rs := _btn(ab, "Reset", func():
		L = KL.DEF.duplicate()
		_changed("skin")
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
	if id == "cape" and v == 0:
		return LocS.t("Team color")
	return "%d / %d" % [v + 1, int(KL.OPTS[id])]


func _swatch(id: String) -> Color:
	var v: int = int(L[id])
	match id:
		"skin": return KL.SKIN[v]
		"eye": return KL.EYE[v]
		"haircol": return KL.HAIR[v]
		"gem": return KL.GEM[v]
		"armor": return KL.ARMOR[v][0]
		"cape": return Color(0.72, 0.12, 0.12) if v == 0 else KL.CAPE[v]
		"blade": return KL.BLADE[v]
	return Color.WHITE


func _row(id: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	rows_box.add_child(box)
	_lbl(box, NAMES[id], 22, Color(0.9, 0.8, 0.55))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	var n: int = int(KL.OPTS[id])
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
	_rebuild_king()
	match id:
		"skin", "eye", "hair", "haircol", "beard", "scar", "patch":
			_focus(1.7, 0.35)
		"helm", "crown", "gem":
			_focus(2.2, 0.45)
		"emblem", "armor":
			_focus(3.4, 0.0)
		"pauld":
			_focus(3.0, 0.8)
		"cape":
			_focus(5.0, 2.9)
		"blade":
			_focus(4.4, -0.7)
		"epithet":
			_focus(3.2, 0.2)


func _focus(d: float, y: float) -> void:
	tdist = d
	focus_yaw = y
	focus_t = 1.6


func _go(d: float, y: float) -> void:
	_focus(d, y)


func _save_back() -> void:
	ProfS.look = L.duplicate()
	ProfS.save()
	KL.force = {}
	if back.is_valid():
		back.call()


# ------------------------------------------------------------------ 3D scene
func _make_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.5)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.07, 0.09)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 28, 0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.6, 2.8, -2.4)
	rim.light_color = Color(0.45, 0.6, 1.0)
	rim.light_energy = 1.6
	rim.omni_range = 9.0
	vp.add_child(rim)
	for sx in [-1, 1]:
		var tl := OmniLight3D.new()
		tl.position = Vector3(2.4 * sx, 2.3, 1.2)
		tl.light_color = Color(1.0, 0.6, 0.25)
		tl.light_energy = 0.7
		tl.omni_range = 7.0
		vp.add_child(tl)
		lights.append(tl)
	# stage: floor, pedestal, curtain, pillars, embers
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.14, 0.13, 0.15)
	stone.roughness = 0.9
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_m.mesh = pm
	floor_m.material_override = stone
	vp.add_child(floor_m)
	var ped := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.25
	cy.bottom_radius = 1.4
	cy.height = 0.18
	ped.mesh = cy
	ped.position.y = 0.09
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.18, 0.18)
	pmat.roughness = 0.7
	ped.material_override = pmat
	vp.add_child(ped)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.22
	tm.outer_radius = 1.3
	ring.mesh = tm
	ring.position.y = 0.19
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.78, 0.25)
	gm.metallic = 1.0
	gm.roughness = 0.25
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.7, 0.2)
	gm.emission_energy_multiplier = 0.5
	ring.material_override = gm
	vp.add_child(ring)
	var cur := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(12, 7)
	cur.mesh = qm
	cur.position = Vector3(0, 3.4, -3.2)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.03, 0.05)
	cm.roughness = 1.0
	cur.material_override = cm
	vp.add_child(cur)
	for sx in [-1, 1]:
		for z in [-3.0, 0.0]:
			var pl := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.28
			pc.bottom_radius = 0.34
			pc.height = 6.0
			pl.mesh = pc
			pl.position = Vector3(4.2 * sx - (0.0 if z == -3.0 else 0.6 * sx), 3.0, z - 0.2)
			pl.material_override = stone
			vp.add_child(pl)
	var em := CPUParticles3D.new()
	em.amount = 50
	em.lifetime = 6.0
	em.preprocess = 6.0
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(3.0, 0.2, 2.5)
	em.direction = Vector3(0, 1, 0)
	em.spread = 15.0
	em.gravity = Vector3(0.02, 0.12, 0)
	em.initial_velocity_min = 0.2
	em.initial_velocity_max = 0.5
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_color = Color(1.0, 0.75, 0.3)
	sm.material = emat
	em.mesh = sm
	em.position = Vector3(0, 0.3, 0)
	vp.add_child(em)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.current = true
	cam.far = 60.0
	vp.add_child(cam)
	_update_cam(0.0)


func _rebuild_king() -> void:
	if king != null and is_instance_valid(king):
		var rot: float = king.rotation.y
		king.get_parent().remove_child(king)
		king.free()
		king = null
		KL.force = L.duplicate()
		king = _spawn()
		king.rotation.y = rot
	else:
		KL.force = L.duplicate()
		king = _spawn()
	KL.force = {}
	_update_plate()


func _spawn():
	var u = UnitS.new()
	vp.add_child(u)
	u.setup("hero", 0, 1, stub)
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.position = Vector3(0, 0.18, 0)
	if u.bar != null:
		u.bar.visible = false
	return u


func _update_plate() -> void:
	var nm: String = ProfS.king_name
	if nm == "":
		nm = LocS.t("Your King")
	var ep: int = int(L.epithet)
	if ep > 0:
		nm += " " + LocS.t(KL.EPITHET[ep])
	plate.text = nm


# ------------------------------------------------------------------ camera + animation
func _update_cam(dt: float) -> void:
	dist = lerpf(dist, tdist, clampf(dt * 6.0, 0.0, 1.0)) if dt > 0.0 else tdist
	var f := smoothstep(1.5, 5.4, dist)
	var ty := lerpf(2.25, 1.45, f) + 0.18
	var tg := Vector3(0, ty, 0)
	var c := cos(pitch)
	cam.position = tg + Vector3(sin(yaw) * c, sin(pitch), cos(yaw) * c) * dist
	cam.look_at(tg, Vector3.UP)


func _process(dt: float) -> void:
	if not _built or king == null or not is_instance_valid(king):
		return
	t_all += dt
	idle_t += dt
	if focus_t > 0.0:
		focus_t -= dt
		yaw = lerp_angle(yaw, focus_yaw, clampf(dt * 4.0, 0.0, 1.0))
	if not dragging:
		yaw += yaw_vel * dt
		yaw_vel = lerpf(yaw_vel, 0.0, clampf(dt * 3.0, 0.0, 1.0))
	yaw = wrapf(yaw, -PI, PI)
	if auto_rot:
		king.rotation.y += dt * 0.6
	_update_cam(dt)
	for i in lights.size():
		var l: OmniLight3D = lights[i]
		l.light_energy = 0.7 + sin(t_all * 11.0 + i * 2.0) * 0.1 + sin(t_all * 23.0 + i) * 0.05
	RigS.animate(king, dt)
	# head: follow the camera while it is being moved, otherwise sweep slowly side to side
	var rel := wrapf(yaw - king.rotation.y, -PI, PI)
	var follow: float = clampf(rel, -1.0, 1.0)
	var sweep: float = sin(t_all * 0.7) * 0.6
	var want := follow if idle_t < 3.0 else lerpf(follow, sweep, clampf((idle_t - 3.0) * 0.5, 0.0, 1.0))
	hy = lerpf(hy, want, clampf(dt * 4.0, 0.0, 1.0))
	var rg: Dictionary = king.rg
	if rg.has("head"):
		rg.head.rotation.y = hy
		rg.head.rotation.x = sin(t_all * 0.5) * 0.04 - 0.02
	if rg.has("torso"):
		rg.torso.rotation.y = hy * 0.25


# ------------------------------------------------------------------ input
func _pv_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed and touches.size() < 2
			if mb.pressed:
				focus_t = 0.0
				yaw_vel = 0.0
				idle_t = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			tdist = clampf(tdist * 0.9, 0.9, 7.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tdist = clampf(tdist * 1.1, 0.9, 7.0)
	elif e is InputEventMouseMotion and dragging and touches.size() < 2:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * 0.009
		pitch = clampf(pitch + mm.relative.y * 0.006, -0.25, 0.75)
		yaw_vel = -mm.velocity.x * 0.009
		idle_t = 0.0
		focus_t = 0.0
	elif e is InputEventMagnifyGesture:
		tdist = clampf(tdist / (e as InputEventMagnifyGesture).factor, 0.9, 7.0)


func _input(e: InputEvent) -> void:
	# pinch (two fingers) on the preview
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
					tdist = clampf(tdist * pinch_d / d, 0.9, 7.0)
				pinch_d = d
				idle_t = 0.0
				focus_t = 0.0
