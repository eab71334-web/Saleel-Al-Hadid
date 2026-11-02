extends Control
# Cinematic title sequence (after the studio logo): dusk, glowing light streaks,
# the king leading his iron army toward the camera, then the title. Tap to skip.

const T_TITLE := 5.2
const T_END := 10.5
var t := 0.0
var u := 1.0
var vs := Vector2(1280, 720)
var cb: Callable
var cam: Camera3D
var world: Node3D
var soldiers: Array = []
var streaks: Array = []
var king: Node3D
var cape: MeshInstance3D
var title_box: Control
var ar_lbl: Label
var en_lbl: Label
var bar: ColorRect
var tag: Label
var white: ColorRect
var black: ColorRect
var skip: Label
var finishing := false
var _cl: CanvasLayer
var lights: Array = []
static var done := false


static func start(host: Node, on_done: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 110
	host.add_child(cl)
	var s = load("res://game/intro.gd").new()
	s.cb = on_done
	s._cl = cl
	cl.add_child(s)


func _mat(c: Color, rim := 0.0, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.4
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


func _box(parent: Node3D, sz: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _soldier(is_king: bool) -> Node3D:
	var n := Node3D.new()
	var dark := _mat(Color(0.05, 0.05, 0.07), 0.9)
	var steel := _mat(Color(0.16, 0.17, 0.2), 0.9)
	var gold := _mat(Color(1.0, 0.75, 0.25), 0.0, 1.6)
	var sc := 1.25 if is_king else 1.0
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "L%d" % side
		leg.position = Vector3(0.16 * side, 0.9, 0)
		n.add_child(leg)
		_box(leg, Vector3(0.18, 0.9, 0.2), Vector3(0, -0.45, 0), dark)
	var torso := Node3D.new()
	torso.name = "T"
	torso.position = Vector3(0, 0.9, 0)
	n.add_child(torso)
	_box(torso, Vector3(0.58, 0.72, 0.32), Vector3(0, 0.38, 0), steel)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	head.mesh = sm
	head.material_override = steel
	head.position = Vector3(0, 0.95, 0)
	torso.add_child(head)
	if is_king:
		for i in 5:
			var a := i * TAU / 5.0
			_box(torso, Vector3(0.06, 0.16, 0.06), Vector3(cos(a) * 0.13, 1.16, sin(a) * 0.13), gold)
		_box(torso, Vector3(0.3, 0.06, 0.3), Vector3(0, 1.08, 0), gold)
		# cape
		cape = _box(torso, Vector3(0.62, 1.1, 0.04), Vector3(0, 0.3, 0.2), _mat(Color(0.5, 0.04, 0.05), 0.6))
		_box(torso, Vector3(0.66, 0.08, 0.36), Vector3(0, 0.74, 0), gold)
	else:
		_box(torso, Vector3(0.34, 0.12, 0.34), Vector3(0, 1.06, 0), steel)
	# arms, spear, shield
	_box(torso, Vector3(0.14, 0.6, 0.14), Vector3(0.38, 0.4, 0), dark)
	_box(torso, Vector3(0.14, 0.6, 0.14), Vector3(-0.38, 0.4, 0), dark)
	if is_king:
		var sw := _box(torso, Vector3(0.07, 1.5, 0.03), Vector3(0.45, 0.95, -0.1), _mat(Color(0.8, 0.85, 0.95), 0.0, 1.2))
		sw.rotation.z = -0.25
	else:
		var sp := _box(torso, Vector3(0.05, 2.5, 0.05), Vector3(0.45, 0.9, -0.08), dark)
		sp.rotation.z = -0.08
		_box(torso, Vector3(0.05, 0.28, 0.05), Vector3(0.45 + 0.2, 2.1, -0.08), _mat(Color(0.7, 0.75, 0.85), 0.0, 0.8)).rotation.z = -0.08
		_box(torso, Vector3(0.1, 0.6, 0.46), Vector3(-0.5, 0.4, 0.0), _mat(Color(0.12, 0.05, 0.05), 0.8))
	n.scale = Vector3.ONE * sc
	return n


func _ready() -> void:
	vs = get_viewport().get_visible_rect().size
	u = clampf(minf(vs.x, vs.y) / 720.0, 0.55, 2.2)
	position = Vector2.ZERO
	size = vs
	mouse_filter = Control.MOUSE_FILTER_STOP
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.position = Vector2.ZERO
	svc.size = vs
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(vs)
	sv.msaa_3d = Viewport.MSAA_DISABLED
	svc.add_child(sv)
	world = Node3D.new()
	sv.add_child(world)
	_build_world()
	_build_ui()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.03, 0.05, 0.16)
	psm.sky_horizon_color = Color(0.95, 0.42, 0.12)
	psm.ground_horizon_color = Color(0.2, 0.08, 0.05)
	psm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	psm.sky_curve = 0.1
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.2, 0.3)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.fog_light_color = Color(0.32, 0.12, 0.07)
	env.fog_density = 0.007
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.25
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-8, 160, 0)
	sun.light_color = Color(1.0, 0.55, 0.25)
	sun.light_energy = 0.5
	world.add_child(sun)
	# ground
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	gm.mesh = pm
	var gmat := _mat(Color(0.035, 0.03, 0.04))
	gmat.roughness = 0.95
	gmat.metallic = 0.0
	gm.material_override = gmat
	world.add_child(gm)
	# distant castle silhouette on the horizon
	var cas := Node3D.new()
	cas.position = Vector3(26, 0, -120)
	world.add_child(cas)
	var cm := _mat(Color(0.03, 0.03, 0.05), 0.5)
	_box(cas, Vector3(30, 10, 6), Vector3(0, 5, 0), cm)
	for tx in [-17, -6, 6, 17]:
		_box(cas, Vector3(5, 20, 5), Vector3(tx, 10, 0), cm)
		_box(cas, Vector3(6.4, 2, 6.4), Vector3(tx, 20.6, 0), cm)
	_box(cas, Vector3(8, 30, 8), Vector3(0, 15, -2), cm)
	var win := _mat(Color(1, 0.7, 0.25), 0.0, 3.0)
	for wy in [8.0, 14.0, 22.0]:
		_box(cas, Vector3(0.9, 1.6, 0.2), Vector3(0, wy, 2.1), win)
	# golden light streaks (diagonal, like the reference video)
	var streak_m := StandardMaterial3D.new()
	streak_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_m.albedo_color = Color(1.0, 0.72, 0.2, 0.7)
	streak_m.emission_enabled = true
	streak_m.emission = Color(1.0, 0.6, 0.1)
	streak_m.emission_energy_multiplier = 3.0
	streak_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 26:
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(randf_range(10, 34), randf_range(0.06, 0.22))
		s.mesh = q
		s.material_override = streak_m
		s.position = Vector3(randf_range(-30, 30), randf_range(1.2, 14), randf_range(-90, -4))
		s.rotation_degrees = Vector3(0, randf_range(-8, 8), randf_range(18, 32))
		s.set_meta("sp", randf_range(14, 40))
		world.add_child(s)
		streaks.append(s)
	# army: king in front, ranks behind
	king = _soldier(true)
	king.position = Vector3(0, 0, -34)
	king.rotation.y = PI
	world.add_child(king)
	soldiers.append(king)
	for r in 7:
		for c in range(-3, 4):
			if r == 0 and abs(c) < 1:
				continue
			var s := _soldier(false)
			s.position = Vector3(c * 1.9 + randf_range(-0.3, 0.3), 0, -34 - 3.2 - r * 2.6 - abs(c) * 0.9)
			s.rotation.y = PI
			s.set_meta("ph", randf() * TAU)
			world.add_child(s)
			soldiers.append(s)
	# banners
	for bx in [-6, 6]:
		var pole := _box(world, Vector3(0.1, 7, 0.1), Vector3(bx, 3.5, -8), _mat(Color(0.06, 0.05, 0.05)))
		var fl := _box(world, Vector3(1.6, 1.0, 0.04), Vector3(bx + 0.9, 6.3, -8), _mat(Color(0.5, 0.05, 0.06), 0.4))
		fl.set_meta("flag", true)
	# torches
	for tp in [Vector3(-5, 1.6, 0), Vector3(5, 1.6, 0), Vector3(-5, 1.6, -14), Vector3(5, 1.6, -14), Vector3(-5, 1.6, -28), Vector3(5, 1.6, -28)]:
		var l := OmniLight3D.new()
		l.position = tp
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 1.4
		l.omni_range = 7.0
		world.add_child(l)
		lights.append(l)
		_box(world, Vector3(0.12, 0.3, 0.12), tp, _mat(Color(1, 0.6, 0.15), 0.0, 4.0))
	# embers
	var em := CPUParticles3D.new()
	em.amount = 90
	em.lifetime = 5.0
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(14, 0.2, 14)
	em.direction = Vector3(0.3, 1, 0)
	em.spread = 25.0
	em.initial_velocity_min = 1.2
	em.initial_velocity_max = 3.0
	em.gravity = Vector3(0, 0.3, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var emm := StandardMaterial3D.new()
	emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	emm.albedo_color = Color(1.0, 0.65, 0.2)
	emm.emission_enabled = true
	emm.emission = Color(1, 0.55, 0.1)
	emm.emission_energy_multiplier = 4.0
	qm.material = emm
	em.mesh = qm
	em.position = Vector3(0, 0, 0)
	world.add_child(em)
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 500
	cam.position = Vector3(-1.6, 0.5, 9)
	world.add_child(cam)
	cam.current = true


func _build_ui() -> void:
	white = ColorRect.new()
	white.color = Color(1, 0.8, 0.45, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	# letterbox bars (cinema)
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, vs.y * 0.09)
	top.size = Vector2(vs.x, vs.y * 0.09)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var bot := ColorRect.new()
	bot.color = Color.BLACK
	bot.position = Vector2(0, vs.y * 0.91)
	bot.size = Vector2(vs.x, vs.y * 0.09)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)
	title_box = Control.new()
	title_box.position = Vector2(vs.x * 0.5, vs.y * 0.3)
	title_box.size = Vector2(vs.x * 0.46, vs.y * 0.4)
	title_box.modulate.a = 0.0
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_box)
	ar_lbl = Label.new()
	ar_lbl.text = "سليل الحديد"
	ar_lbl.add_theme_font_size_override("font_size", int(96 * u))
	ar_lbl.add_theme_color_override("font_color", Color(1, 0.82, 0.38))
	ar_lbl.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02))
	ar_lbl.add_theme_constant_override("outline_size", int(14 * u))
	ar_lbl.size = Vector2(title_box.size.x, 130 * u)
	ar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(ar_lbl)
	bar = ColorRect.new()
	bar.color = Color(1, 0.7, 0.2)
	bar.position = Vector2(title_box.size.x * 0.5, 150 * u)
	bar.size = Vector2(0, 4 * u)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(bar)
	en_lbl = Label.new()
	en_lbl.text = "SALEEL AL HADID"
	en_lbl.add_theme_font_size_override("font_size", int(44 * u))
	en_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	en_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	en_lbl.add_theme_constant_override("outline_size", int(10 * u))
	en_lbl.position = Vector2(0, 168 * u)
	en_lbl.size = Vector2(title_box.size.x, 60 * u)
	en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(en_lbl)
	tag = Label.new()
	tag.text = "SABAK STUDIOS  ·  A MEDIEVAL WAR EPIC"
	tag.add_theme_font_size_override("font_size", int(20 * u))
	tag.add_theme_color_override("font_color", Color(0.86, 0.72, 0.45))
	tag.position = Vector2(0, 236 * u)
	tag.size = Vector2(title_box.size.x, 30 * u)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(tag)
	skip = Label.new()
	skip.text = "tap to skip"
	skip.add_theme_font_size_override("font_size", int(18 * u))
	skip.modulate = Color(1, 1, 1, 0.45)
	skip.position = Vector2(vs.x - 160 * u, vs.y * 0.91 + 6 * u)
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)


func _process(dt: float) -> void:
	t += dt
	# camera: low push-in with a slow-motion drift, then settles for the title
	var k := clampf(t / T_TITLE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.2)
	cam.position = Vector3(lerpf(-1.6, 0.0, e), lerpf(0.5, 1.5, e), lerpf(9.0, 5.0, e))
	var look := Vector3(lerpf(1.0, 0.0, e), 1.9, king.position.z + 4.0)
	cam.look_at(look)
	cam.rotation.z = 0.025 * sin(t * 0.9)
	var march := t * 2.6
	for s in soldiers:
		var ph: float = float(s.get_meta("ph", 0.0))
		var sw := sin(march + ph)
		s.position.y = absf(sin(march + ph)) * 0.07
		var l1: Node3D = s.get_node_or_null("L-1")
		var l2: Node3D = s.get_node_or_null("L1")
		if l1:
			l1.rotation.x = sw * 0.55
		if l2:
			l2.rotation.x = -sw * 0.55
		s.position.z += dt * 2.3
	if cape:
		cape.rotation.x = 0.25 + 0.12 * sin(t * 4.0)
	for st in streaks:
		st.position.x += dt * float(st.get_meta("sp"))
		if st.position.x > 40.0:
			st.position.x = -40.0
	for l in lights:
		l.light_energy = 2.0 + 0.5 * sin(t * 13.0 + l.position.x)
	# fades
	if t < 1.2:
		black.color.a = 1.0 - t / 1.2
	elif t > T_END - 0.9:
		black.color.a = clampf((t - (T_END - 0.9)) / 0.9, 0.0, 1.0)
	else:
		black.color.a = 0.0
	# title reveal with a golden flash
	if t > T_TITLE - 0.25 and t < T_TITLE + 0.6:
		white.color.a = 0.55 * (1.0 - absf(t - T_TITLE) / 0.5) if absf(t - T_TITLE) < 0.5 else 0.0
	else:
		white.color.a = 0.0
	if t > T_TITLE:
		var tk := clampf((t - T_TITLE) / 1.2, 0.0, 1.0)
		title_box.modulate.a = tk
		title_box.position.x = vs.x * 0.5 + (1.0 - tk) * 60.0 * u
		bar.size.x = title_box.size.x * 0.8 * tk
		bar.position.x = title_box.size.x * 0.5 - bar.size.x * 0.5
		en_lbl.add_theme_constant_override("outline_size", int(10 * u))
	if t >= T_END and not finishing:
		_finish()


func _input(e: InputEvent) -> void:
	if finishing:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed):
		if t > 0.8:
			get_viewport().set_input_as_handled()
			_finish()


func _finish() -> void:
	finishing = true
	done = true
	if cb.is_valid():
		cb.call()
	if _cl != null and is_instance_valid(_cl):
		_cl.queue_free()
