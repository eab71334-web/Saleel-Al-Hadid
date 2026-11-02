extends RefCounted
# 3D models of the town buildings and the resource nodes (all built from primitives).
# Every building faces +z (towards the castle gate). Origin = centre of the footprint on the ground.

static var _mc := {}


static func mat(b, c: Color, rough := 0.9, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [c.to_html(), rough, metal, emis]
	if _mc.has(key):
		return _mc[key]
	var m: StandardMaterial3D = b._mat(c, rough, metal, emis)
	_mc[key] = m
	return m


static func box(b, p: Node, sz: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return b._mesh(p, b._box(sz), m, pos, rot, shadow)


static func cyl(b, p: Node, top: float, bot: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 10) -> MeshInstance3D:
	return b._mesh(p, b._cyl(top, bot, h, seg), m, pos, rot, true)


static func prism(b, p: Node, sz: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = sz
	return b._mesh(p, pm, m, pos, Vector3.ZERO, true)


static func blob(b, p: Node, r: float, sc: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = b._mesh(p, b._sph_mesh(r), m, pos, Vector3.ZERO, true)
	mi.scale = sc
	return mi


# ------------------------------------------------------------------ buildings
static func make(town, t: int, type: String) -> Node3D:
	var b = town.battle
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "model"
	root.add_child(model)
	var def: Dictionary = town.DEFS[type]
	var hx: float = def.hx
	var hz: float = def.hz
	match type:
		"house":
			var h: Node3D = town.kingdom._make_house(t)
			model.add_child(h)
		"barracks":
			var h2: Node3D = town.kingdom._make_barracks(t)
			model.add_child(h2)
		"woodcutter":
			_woodcutter(b, model)
		"quarry":
			_quarry(b, model)
		"mine":
			_mine(b, model)
		"farm":
			_farm(b, model, hx, hz)
		"hunter":
			_hunter(b, model)
		"mill":
			_mill(b, model, root)
		"bakery":
			_bakery(b, model, root)
		"storehouse":
			_storehouse(b, model)
		"market":
			_market(b, model, t)
		"smithy":
			_smithy(b, model, root)
		"stable":
			_stable(b, model)
		"church":
			_church(b, model)
		"well":
			_well(b, model)
	# construction site: foundation and scaffolding
	var site := Node3D.new()
	site.name = "site"
	root.add_child(site)
	var dirt := mat(b, Color(0.5, 0.42, 0.3), 1.0)
	var wood := mat(b, Color(0.55, 0.4, 0.22), 0.9)
	var plank := mat(b, Color(0.7, 0.55, 0.32), 0.9)
	box(b, site, Vector3(hx * 2.0, 0.2, hz * 2.0), dirt, Vector3(0, 0.1, 0), Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cyl(b, site, 0.1, 0.12, 3.4, wood, Vector3(sx * (hx - 0.2), 1.7, sz * (hz - 0.2)))
	for lvl in [1.1, 2.3]:
		box(b, site, Vector3(hx * 2.0 - 0.3, 0.1, 0.1), wood, Vector3(0, lvl, hz - 0.2))
		box(b, site, Vector3(hx * 2.0 - 0.3, 0.1, 0.1), wood, Vector3(0, lvl, -hz + 0.2))
		box(b, site, Vector3(0.1, 0.1, hz * 2.0 - 0.3), wood, Vector3(hx - 0.2, lvl, 0))
		box(b, site, Vector3(0.1, 0.1, hz * 2.0 - 0.3), wood, Vector3(-hx + 0.2, lvl, 0))
	box(b, site, Vector3(1.4, 0.5, 0.9), plank, Vector3(hx * 0.5, 0.45, hz * 0.4))
	return root


static func update(town, n: Node3D, bd: Dictionary, spin: float) -> void:
	var prog: float = float(bd.prog)
	var model: Node3D = n.get_node("model")
	var site: Node3D = n.get_node("site")
	var done := prog >= 1.0
	site.visible = not done
	model.visible = prog > 0.05
	if done:
		model.scale = Vector3.ONE
	else:
		model.scale = Vector3(1.0, lerpf(0.1, 1.0, prog), 1.0)
	var working: bool = done and int(bd.present) > 0
	var blades = n.get_meta("blades") if n.has_meta("blades") else null
	if blades != null:
		if working:
			blades.rotation.z += 1.2 * town.get_process_delta_time()
		else:
			blades.rotation.z += 0.12 * town.get_process_delta_time()
	var smoke = n.get_meta("smoke") if n.has_meta("smoke") else null
	if smoke != null:
		smoke.emitting = working or (done and String(bd.type) == "smithy")
	var glow = n.get_meta("glow") if n.has_meta("glow") else null
	if glow != null:
		glow.visible = done


static func _smoke(b, parent: Node, pos: Vector3) -> CPUParticles3D:
	var sm := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.8
	var sm_mat := StandardMaterial3D.new()
	sm_mat.albedo_color = Color(0.75, 0.75, 0.78, 0.5)
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = sm_mat
	sm.mesh = m
	sm.amount = 8
	sm.lifetime = 3.2
	sm.direction = Vector3.UP
	sm.spread = 12.0
	sm.initial_velocity_min = 1.0
	sm.initial_velocity_max = 1.8
	sm.gravity = Vector3(0.25, 0.4, 0)
	sm.scale_amount_min = 0.5
	sm.scale_amount_max = 1.5
	sm.position = pos
	sm.emitting = false
	parent.add_child(sm)
	return sm


static func _woodcutter(b, p: Node3D) -> void:
	var logw := mat(b, Color(0.4, 0.27, 0.14))
	var roof := mat(b, Color(0.3, 0.22, 0.12))
	var dark := mat(b, Color(0.18, 0.11, 0.06))
	var logc := mat(b, Color(0.58, 0.4, 0.2))
	box(b, p, Vector3(3.2, 2.0, 2.6), logw, Vector3(-0.6, 1.0, -0.6))
	prism(b, p, Vector3(3.8, 1.3, 3.2), roof, Vector3(-0.6, 2.65, -0.6))
	box(b, p, Vector3(0.8, 1.5, 0.08), dark, Vector3(-0.6, 0.75, 0.72), Vector3.ZERO, false)
	for i in 3:
		for j in 3 - i:
			cyl(b, p, 0.28, 0.28, 2.0, logc, Vector3(1.6 + (j - (2 - i) * 0.5) * 0.58, 0.3 + i * 0.5, 0.2), Vector3(0, 0, PI / 2.0))
	cyl(b, p, 0.4, 0.45, 0.6, logc, Vector3(-2.0, 0.3, 1.2))
	box(b, p, Vector3(0.08, 0.9, 0.08), dark, Vector3(-2.0, 0.85, 1.2), Vector3(0, 0, 0.7))
	box(b, p, Vector3(0.45, 0.2, 0.05), mat(b, Color(0.7, 0.72, 0.78), 0.5, 0.6), Vector3(-1.75, 1.2, 1.2), Vector3(0, 0, 0.7))


static func _quarry(b, p: Node3D) -> void:
	var pit := mat(b, Color(0.32, 0.31, 0.3))
	var cut := mat(b, Color(0.7, 0.69, 0.66))
	var cut2 := mat(b, Color(0.6, 0.59, 0.57))
	var wood := mat(b, Color(0.45, 0.31, 0.16))
	box(b, p, Vector3(6.6, 0.14, 5.6), pit, Vector3(0, 0.07, -0.2), Vector3.ZERO, false)
	for i in 6:
		var c := cut if i % 2 == 0 else cut2
		box(b, p, Vector3(1.4, 0.9, 1.0), c, Vector3(-2.2 + (i % 3) * 1.5, 0.45 + (i / 3) * 0.9, 2.1), Vector3(0, 0.1 * i, 0))
	box(b, p, Vector3(2.2, 1.6, 1.6), cut2, Vector3(2.0, 0.8, -1.8), Vector3(0, 0.3, 0))
	cyl(b, p, 0.14, 0.18, 4.8, wood, Vector3(-2.4, 2.4, -1.6))
	box(b, p, Vector3(3.8, 0.2, 0.2), wood, Vector3(-0.6, 4.7, -1.6))
	box(b, p, Vector3(0.05, 2.2, 0.05), mat(b, Color(0.25, 0.2, 0.12)), Vector3(1.1, 3.55, -1.6))
	box(b, p, Vector3(0.9, 0.7, 0.9), cut, Vector3(1.1, 2.3, -1.6))
	box(b, p, Vector3(1.1, 0.5, 0.7), wood, Vector3(0.4, 0.5, 0.2))


static func _mine(b, p: Node3D) -> void:
	var rock := mat(b, Color(0.38, 0.35, 0.34))
	var rock2 := mat(b, Color(0.3, 0.28, 0.28))
	var wood := mat(b, Color(0.45, 0.31, 0.16))
	var black := mat(b, Color(0.03, 0.03, 0.04))
	blob(b, p, 3.0, Vector3(1.1, 0.8, 1.0), rock, Vector3(0, 0.6, -1.4))
	blob(b, p, 2.0, Vector3(1.2, 0.7, 1.1), rock2, Vector3(-2.2, 0.4, -0.4))
	box(b, p, Vector3(2.2, 2.2, 0.4), black, Vector3(0, 1.2, 1.2), Vector3.ZERO, false)
	for sx in [-1.2, 1.2]:
		box(b, p, Vector3(0.35, 2.6, 0.35), wood, Vector3(sx, 1.3, 1.45))
	box(b, p, Vector3(3.0, 0.35, 0.45), wood, Vector3(0, 2.65, 1.45))
	for sx2 in [-0.55, 0.55]:
		box(b, p, Vector3(0.1, 0.08, 4.0), mat(b, Color(0.3, 0.3, 0.33), 0.5, 0.6), Vector3(sx2, 0.06, 2.6), Vector3.ZERO, false)
	box(b, p, Vector3(1.3, 0.6, 0.9), wood, Vector3(0, 0.5, 3.0))
	box(b, p, Vector3(1.1, 0.25, 0.7), mat(b, Color(0.7, 0.35, 0.15), 0.8, 0.1, 0.4), Vector3(0, 0.9, 3.0))
	blob(b, p, 0.18, Vector3.ONE, mat(b, Color(1.0, 0.75, 0.3), 0.5, 0.0, 3.0), Vector3(1.3, 2.2, 1.7))


static func _farm(b, p: Node3D, hx: float, hz: float) -> void:
	var soil := mat(b, Color(0.34, 0.24, 0.13), 1.0)
	var wheat := mat(b, Color(0.82, 0.68, 0.25), 0.95)
	var green := mat(b, Color(0.5, 0.62, 0.2), 0.95)
	var wood := mat(b, Color(0.45, 0.31, 0.16))
	box(b, p, Vector3(hx * 2.0 - 0.4, 0.14, hz * 2.0 - 0.4), soil, Vector3(0, 0.07, 0), Vector3.ZERO, false)
	for i in 8:
		var c := wheat if i % 3 != 2 else green
		box(b, p, Vector3(0.75, 0.55, hz * 2.0 - 2.4), c, Vector3(-hx + 1.4 + i * 1.25, 0.4, -0.3), Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(b, p, Vector3(0.18, 0.9, 0.18), wood, Vector3(sx * (hx - 0.3), 0.45, sz * (hz - 0.3)))
	box(b, p, Vector3(0.1, 1.8, 0.1), wood, Vector3(hx - 1.2, 0.9, hz - 1.3))
	box(b, p, Vector3(1.2, 0.1, 0.1), wood, Vector3(hx - 1.2, 1.5, hz - 1.3))
	blob(b, p, 0.22, Vector3.ONE, mat(b, Color(0.8, 0.7, 0.4)), Vector3(hx - 1.2, 1.95, hz - 1.3))
	cyl(b, p, 0.45, 0.45, 0.8, mat(b, Color(0.8, 0.66, 0.3)), Vector3(-hx + 0.9, 0.45, hz - 0.9), Vector3(0, 0, PI / 2.0))


static func _hunter(b, p: Node3D) -> void:
	var logw := mat(b, Color(0.36, 0.25, 0.14))
	var roof := mat(b, Color(0.25, 0.3, 0.16))
	var hide := mat(b, Color(0.62, 0.45, 0.28))
	box(b, p, Vector3(2.8, 1.8, 2.4), logw, Vector3(0, 0.9, -0.5))
	prism(b, p, Vector3(3.4, 1.2, 3.0), roof, Vector3(0, 2.4, -0.5))
	box(b, p, Vector3(0.7, 1.3, 0.08), mat(b, Color(0.16, 0.1, 0.06)), Vector3(0, 0.65, 0.72), Vector3.ZERO, false)
	for sx in [-0.9, 0.9]:
		cyl(b, p, 0.07, 0.07, 1.7, logw, Vector3(sx + 0.0, 0.85, 1.9))
	box(b, p, Vector3(2.0, 0.8, 0.05), hide, Vector3(0, 1.1, 1.9))
	for sx2 in [-0.35, 0.35]:
		box(b, p, Vector3(0.06, 0.5, 0.06), mat(b, Color(0.85, 0.82, 0.7)), Vector3(sx2, 2.2, 0.9), Vector3(0, 0, sx2 * 0.8), false)


static func _mill(b, p: Node3D, root: Node3D) -> void:
	var stone := mat(b, Color(0.8, 0.76, 0.66))
	var cap := mat(b, Color(0.38, 0.24, 0.14))
	var wood := mat(b, Color(0.5, 0.35, 0.18))
	var cloth := mat(b, Color(0.9, 0.86, 0.75))
	cyl(b, p, 1.5, 2.6, 5.2, stone, Vector3(0, 2.6, 0), Vector3.ZERO, 12)
	cyl(b, p, 0.0, 2.0, 1.8, cap, Vector3(0, 6.1, 0), Vector3.ZERO, 12)
	box(b, p, Vector3(1.0, 1.7, 0.1), mat(b, Color(0.2, 0.12, 0.07)), Vector3(0, 0.85, 2.5), Vector3.ZERO, false)
	var hub := Node3D.new()
	hub.position = Vector3(0, 5.3, 2.0)
	p.add_child(hub)
	b._mesh(hub, b._box(Vector3(0.5, 0.5, 0.9)), wood, Vector3.ZERO, Vector3.ZERO, true)
	var bl := Node3D.new()
	bl.position = Vector3(0, 0, 0.5)
	hub.add_child(bl)
	for k in 2:
		var arm: MeshInstance3D = b._mesh(bl, b._box(Vector3(0.28, 8.6, 0.14)), wood, Vector3.ZERO, Vector3(0, 0, k * PI / 2.0), true)
	for k2 in 4:
		var a: float = k2 * PI / 2.0
		var sail: MeshInstance3D = b._mesh(bl, b._box(Vector3(1.2, 3.2, 0.06)), cloth, Vector3(-sin(a) * 2.9 + cos(a) * 0.7, cos(a) * 2.9 + sin(a) * 0.7, 0.0), Vector3(0, 0, a), false)
	root.set_meta("blades", bl)


static func _bakery(b, p: Node3D, root: Node3D) -> void:
	var wall := mat(b, Color(0.9, 0.82, 0.62))
	var roof := mat(b, Color(0.62, 0.28, 0.18))
	var dark := mat(b, Color(0.2, 0.12, 0.07))
	var stone := mat(b, Color(0.5, 0.47, 0.44))
	box(b, p, Vector3(4.4, 2.6, 3.6), wall, Vector3(0, 1.3, -0.4))
	prism(b, p, Vector3(5.0, 1.9, 4.2), roof, Vector3(0, 3.55, -0.4))
	box(b, p, Vector3(0.9, 1.6, 0.1), dark, Vector3(-1.0, 0.8, 1.42), Vector3.ZERO, false)
	box(b, p, Vector3(1.8, 0.9, 0.1), mat(b, Color(1.0, 0.65, 0.25), 0.5, 0.0, 1.6), Vector3(1.1, 1.0, 1.42), Vector3.ZERO, false)
	box(b, p, Vector3(0.7, 2.6, 0.7), stone, Vector3(1.5, 3.7, -1.2))
	root.set_meta("smoke", _smoke(b, root, Vector3(1.5, 5.2, -1.2)))
	box(b, p, Vector3(1.6, 0.8, 0.9), mat(b, Color(0.55, 0.38, 0.2)), Vector3(-1.4, 0.5, 2.2))
	for i in 4:
		blob(b, p, 0.22, Vector3(1.6, 0.8, 0.9), mat(b, Color(0.82, 0.58, 0.26)), Vector3(-1.9 + i * 0.5, 1.0, 2.2))


static func _storehouse(b, p: Node3D) -> void:
	var wall := mat(b, Color(0.5, 0.36, 0.2))
	var roof := mat(b, Color(0.28, 0.2, 0.14))
	var dark := mat(b, Color(0.2, 0.12, 0.07))
	var crate := mat(b, Color(0.65, 0.5, 0.28))
	box(b, p, Vector3(5.6, 3.0, 4.6), wall, Vector3(0, 1.5, -0.6))
	prism(b, p, Vector3(6.4, 2.2, 5.4), roof, Vector3(0, 4.1, -0.6))
	box(b, p, Vector3(2.4, 2.4, 0.12), dark, Vector3(0, 1.2, 1.72), Vector3.ZERO, false)
	for i in 3:
		box(b, p, Vector3(0.9, 0.9, 0.9), crate, Vector3(-2.4 + i * 1.0, 0.45, 2.6), Vector3(0, 0.2 * i, 0))
	cyl(b, p, 0.4, 0.4, 0.9, mat(b, Color(0.4, 0.27, 0.14)), Vector3(2.4, 0.45, 2.6))
	cyl(b, p, 0.4, 0.4, 0.9, mat(b, Color(0.4, 0.27, 0.14)), Vector3(3.0, 0.45, 2.2))


static func _market(b, p: Node3D, t: int) -> void:
	var base := mat(b, Color(0.6, 0.56, 0.5), 0.95)
	var wood := mat(b, Color(0.45, 0.31, 0.16))
	box(b, p, Vector3(7.6, 0.1, 6.4), base, Vector3(0, 0.05, 0), Vector3.ZERO, false)
	var cols := [Color(0.8, 0.2, 0.2), Color(0.9, 0.85, 0.7), Color(0.2, 0.45, 0.75)]
	var goods := [Color(0.9, 0.4, 0.2), Color(0.8, 0.75, 0.3), Color(0.4, 0.7, 0.3)]
	for i in 3:
		var sx: float = -2.5 + i * 2.5
		box(b, p, Vector3(2.0, 0.8, 1.0), wood, Vector3(sx, 0.4, 0.4))
		for px in [-0.95, 0.95]:
			cyl(b, p, 0.06, 0.06, 2.4, wood, Vector3(sx + px, 1.2, 0.9))
			cyl(b, p, 0.06, 0.06, 2.4, wood, Vector3(sx + px, 1.2, -0.1))
		var aw := PrismMesh.new()
		aw.size = Vector3(2.4, 0.6, 1.8)
		b._mesh(p, aw, mat(b, cols[i], 0.8), Vector3(sx, 2.6, 0.4), Vector3.ZERO, true)
		for k in 4:
			blob(b, p, 0.2, Vector3.ONE, mat(b, goods[i]), Vector3(sx - 0.7 + k * 0.45, 0.95, 0.4))
	cyl(b, p, 0.08, 0.1, 5.0, wood, Vector3(0, 2.5, -2.4))
	box(b, p, Vector3(1.3, 0.8, 0.05), mat(b, b.team_col(t), 0.8, 0.0, 0.5), Vector3(0.7, 4.5, -2.4))


static func _smithy(b, p: Node3D, root: Node3D) -> void:
	var stone := mat(b, Color(0.4, 0.38, 0.38))
	var roof := mat(b, Color(0.2, 0.18, 0.18))
	var steel := mat(b, Color(0.7, 0.72, 0.78), 0.4, 0.6)
	var glow_m := mat(b, Color(1.0, 0.5, 0.15), 0.5, 0.0, 3.0)
	box(b, p, Vector3(5.2, 2.6, 4.0), stone, Vector3(0, 1.3, -0.5))
	prism(b, p, Vector3(5.8, 1.6, 4.6), roof, Vector3(0, 3.4, -0.5))
	box(b, p, Vector3(0.9, 4.4, 0.9), stone, Vector3(-1.9, 3.4, -1.7))
	var g := Node3D.new()
	root.add_child(g)
	var fl: MeshInstance3D = b._mesh(g, b._box(Vector3(1.4, 0.9, 0.3)), glow_m, Vector3(-1.9, 0.9, 1.55), Vector3.ZERO, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.55, 0.25)
	lamp.light_energy = 1.2
	lamp.omni_range = 9.0
	lamp.position = Vector3(-1.9, 1.4, 2.4)
	g.add_child(lamp)
	root.set_meta("glow", g)
	root.set_meta("smoke", _smoke(b, root, Vector3(-1.9, 5.8, -1.7)))
	cyl(b, p, 0.4, 0.5, 0.8, mat(b, Color(0.4, 0.27, 0.14)), Vector3(1.4, 0.4, 2.3))
	box(b, p, Vector3(1.0, 0.35, 0.5), steel, Vector3(1.4, 0.95, 2.3))
	for i in 3:
		box(b, p, Vector3(0.08, 1.5, 0.04), steel, Vector3(0.2 + i * 0.35, 1.2, 1.55), Vector3(0, 0, 0.1 * (i - 1)), false)


static func _stable(b, p: Node3D) -> void:
	var wall := mat(b, Color(0.5, 0.34, 0.2))
	var roof := mat(b, Color(0.32, 0.2, 0.12))
	var fence := mat(b, Color(0.6, 0.45, 0.25))
	var horse := mat(b, Color(0.42, 0.26, 0.14))
	box(b, p, Vector3(7.0, 2.8, 3.8), wall, Vector3(0, 1.4, -1.4))
	prism(b, p, Vector3(7.8, 2.2, 4.6), roof, Vector3(0, 3.9, -1.4))
	for i in 3:
		box(b, p, Vector3(1.4, 2.0, 0.1), mat(b, Color(0.16, 0.1, 0.06)), Vector3(-2.2 + i * 2.2, 1.0, 0.52), Vector3.ZERO, false)
	for sx in [-3.8, 3.8]:
		box(b, p, Vector3(0.14, 1.2, 3.0), fence, Vector3(sx, 0.6, 1.9))
	box(b, p, Vector3(7.6, 0.14, 0.14), fence, Vector3(0, 1.0, 3.3))
	box(b, p, Vector3(7.6, 0.14, 0.14), fence, Vector3(0, 0.5, 3.3))
	box(b, p, Vector3(1.6, 0.8, 0.6), horse, Vector3(-1.5, 1.2, 2.1))
	box(b, p, Vector3(0.4, 0.8, 0.5), horse, Vector3(-0.6, 1.7, 2.1), Vector3(0, 0, -0.5))
	for lx in [-1.9, -1.1]:
		box(b, p, Vector3(0.14, 0.8, 0.14), horse, Vector3(lx, 0.4, 2.1))
	box(b, p, Vector3(1.2, 0.8, 0.8), mat(b, Color(0.8, 0.68, 0.3)), Vector3(2.5, 0.4, 2.3))


static func _church(b, p: Node3D) -> void:
	var stone := mat(b, Color(0.82, 0.8, 0.74))
	var roof := mat(b, Color(0.3, 0.3, 0.36))
	var gold_m := mat(b, Color(1.0, 0.8, 0.3), 0.4, 0.4, 0.6)
	var glass := mat(b, Color(0.4, 0.6, 0.95), 0.3, 0.0, 1.6)
	var dark := mat(b, Color(0.2, 0.12, 0.07))
	box(b, p, Vector3(5.2, 4.4, 7.4), stone, Vector3(0, 2.2, 1.0))
	prism(b, p, Vector3(5.9, 2.6, 8.0), roof, Vector3(0, 5.7, 1.0))
	box(b, p, Vector3(2.8, 9.0, 2.8), stone, Vector3(0, 4.5, -3.2))
	var sp: MeshInstance3D = b._mesh(p, b._cyl(0.0, 1.9, 4.2, 4), roof, Vector3(0, 11.1, -3.2), Vector3(0, PI / 4.0, 0), true)
	box(b, p, Vector3(0.18, 1.5, 0.18), gold_m, Vector3(0, 13.9, -3.2))
	box(b, p, Vector3(0.9, 0.18, 0.18), gold_m, Vector3(0, 13.7, -3.2))
	box(b, p, Vector3(1.6, 2.8, 0.12), dark, Vector3(0, 1.4, 4.74), Vector3.ZERO, false)
	for sx in [-1.6, 1.6]:
		box(b, p, Vector3(0.12, 1.8, 0.8), glass, Vector3(sx * 1.6, 2.8, 0.8), Vector3.ZERO, false)
		box(b, p, Vector3(0.6, 1.4, 0.12), glass, Vector3(sx * 0.6, 3.0, 4.75), Vector3.ZERO, false)
	box(b, p, Vector3(0.9, 1.2, 0.12), glass, Vector3(0, 7.2, -1.78), Vector3.ZERO, false)


static func _well(b, p: Node3D) -> void:
	var stone := mat(b, Color(0.55, 0.53, 0.5))
	var wood := mat(b, Color(0.45, 0.31, 0.16))
	cyl(b, p, 1.2, 1.3, 1.0, stone, Vector3(0, 0.5, 0), Vector3.ZERO, 14)
	cyl(b, p, 0.9, 0.9, 0.06, mat(b, Color(0.1, 0.25, 0.4), 0.2), Vector3(0, 0.98, 0), Vector3.ZERO, 14)
	for sx in [-1.0, 1.0]:
		cyl(b, p, 0.08, 0.08, 2.4, wood, Vector3(sx, 1.7, 0))
	prism(b, p, Vector3(3.0, 0.9, 1.8), mat(b, Color(0.4, 0.22, 0.14)), Vector3(0, 3.1, 0))
	box(b, p, Vector3(0.4, 0.3, 0.4), wood, Vector3(0, 1.8, 0))


# ------------------------------------------------------------------ resource nodes
static func build_node(b, root: Node3D, kind: String, r: float, rng: RandomNumberGenerator) -> void:
	var items := []
	if kind == "wood":
		var trunk := mat(b, Color(0.3, 0.2, 0.1))
		var greens := [mat(b, Color(0.1, 0.3, 0.12)), mat(b, Color(0.14, 0.38, 0.14)), mat(b, Color(0.2, 0.34, 0.1))]
		for i in 9:
			var a := rng.randf() * TAU
			var rad := sqrt(rng.randf()) * (r - 1.0)
			var tn := Node3D.new()
			tn.position = Vector3(cos(a) * rad, 0, sin(a) * rad)
			tn.scale = Vector3.ONE * rng.randf_range(0.85, 1.5)
			root.add_child(tn)
			cyl(b, tn, 0.3, 0.4, 2.0, trunk, Vector3(0, 1.0, 0), Vector3.ZERO, 7)
			var lm: Material = greens[i % 3]
			b._mesh(tn, b._cyl(0.0, 2.2, 4.4, 9), lm, Vector3(0, 4.0, 0), Vector3.ZERO, true)
			b._mesh(tn, b._cyl(0.0, 1.6, 3.4, 9), lm, Vector3(0, 6.1, 0), Vector3.ZERO, true)
			items.append(tn)
	elif kind == "stone":
		var greys := [mat(b, Color(0.62, 0.61, 0.6)), mat(b, Color(0.52, 0.51, 0.5)), mat(b, Color(0.7, 0.68, 0.64))]
		for i in 7:
			var a2 := rng.randf() * TAU
			var rad2 := sqrt(rng.randf()) * (r - 1.2)
			var bl := blob(b, root, rng.randf_range(0.9, 1.7), Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.6, 1.1), rng.randf_range(0.9, 1.4)), greys[i % 3], Vector3(cos(a2) * rad2, 0.5, sin(a2) * rad2))
			items.append(bl)
	else:
		var dk := mat(b, Color(0.28, 0.24, 0.24))
		var rust := mat(b, Color(0.75, 0.38, 0.16), 0.6, 0.2, 0.7)
		for i in 6:
			var a3 := rng.randf() * TAU
			var rad3 := sqrt(rng.randf()) * (r - 1.2)
			var bl2 := blob(b, root, rng.randf_range(0.9, 1.5), Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.9, 1.3)), dk, Vector3(cos(a3) * rad3, 0.45, sin(a3) * rad3))
			items.append(bl2)
			for k in 3:
				box(b, bl2, Vector3(0.35, 0.2, 0.3), rust, Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.2, 0.9), rng.randf_range(-0.8, 0.8)), Vector3(rng.randf(), rng.randf(), 0), false)
	root.set_meta("items", items)
	root.set_meta("kind", kind)


static func update_node(root: Node3D, n: Dictionary) -> void:
	var items: Array = root.get_meta("items") if root.has_meta("items") else []
	if items.is_empty():
		return
	var ratio: float = clampf(float(n.amt) / float(n.max), 0.0, 1.0)
	var show := int(ceil(ratio * float(items.size())))
	for i in items.size():
		items[i].visible = i < show
	if String(n.kind) != "wood":
		root.scale = Vector3.ONE * (0.55 + 0.45 * ratio)
