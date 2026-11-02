extends RefCounted
# Castle appearance (palettes + a procedural 3D castle) shared by the main-menu scene,
# the castle customisation screen and the in-game castles (colours only).

const WALL := [Color(0.55, 0.53, 0.5), Color(0.42, 0.42, 0.46), Color(0.62, 0.5, 0.38), Color(0.78, 0.74, 0.66), Color(0.25, 0.25, 0.3), Color(0.5, 0.36, 0.34)]
const ROOF := [Color(0.34, 0.17, 0.12), Color(0.15, 0.25, 0.5), Color(0.15, 0.4, 0.22), Color(0.45, 0.12, 0.14), Color(0.2, 0.2, 0.24), Color(0.55, 0.42, 0.12)]
const BANNER := [Color(0.72, 0.12, 0.12), Color(0.15, 0.3, 0.75), Color(0.12, 0.5, 0.25), Color(0.5, 0.15, 0.6), Color(0.9, 0.55, 0.1), Color(0.08, 0.08, 0.1), Color(0.92, 0.9, 0.85)]
const GLOW := [Color(1.0, 0.72, 0.3), Color(0.5, 0.75, 1.0), Color(0.55, 1.0, 0.6), Color(1.0, 0.45, 0.35)]
const GATE := [Color(0.32, 0.2, 0.1), Color(0.22, 0.22, 0.26), Color(0.95, 0.75, 0.25)]

const OPTS := {"wall": 6, "roof": 6, "banner": 7, "emblem": 5, "tstyle": 4, "tcount": 3, "keep": 3, "gate": 3, "glow": 4, "moat": 2, "torch": 2}
const DEF := {"wall": 0, "roof": 0, "banner": 0, "emblem": 0, "tstyle": 0, "tcount": 0, "keep": 1, "gate": 0, "glow": 0, "moat": 1, "torch": 1}


static func merged(saved: Dictionary) -> Dictionary:
	var C: Dictionary = DEF.duplicate()
	for k in saved.keys():
		if OPTS.has(k):
			C[k] = clampi(int(saved[k]), 0, int(OPTS[k]) - 1)
	return C


static func random_look() -> Dictionary:
	var C: Dictionary = {}
	for k in OPTS.keys():
		C[k] = randi() % int(OPTS[k])
	return C


static func _m(c: Color, rough := 0.9, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


static func _b(parent: Node3D, sz: Vector3, mat: Material, p: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bot: float, h: float, mat: Material, p: Vector3, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = p
	parent.add_child(mi)
	return mi


static func _multi(parent: Node3D, mesh: Mesh, mat: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


# Builds the castle centred on the origin (ground at y = 0, gate towards +Z).
# Returns {"flags": [Node3D], "lights": [OmniLight3D], "flames": [Node3D]}.
static func build(root: Node3D, C: Dictionary, tc: Color, lights_on := true) -> Dictionary:
	var out := {"flags": [], "lights": [], "flames": []}
	var stone := _m(WALL[int(C.wall)], 0.95)
	var stone_d := _m(WALL[int(C.wall)].darkened(0.22), 0.95)
	var roofm := _m(ROOF[int(C.roof)], 0.8)
	var gold := _m(Color(1.0, 0.78, 0.25), 0.3, 0.9, 0.25)
	var wood := _m(Color(0.32, 0.2, 0.1), 0.9)
	var gatec: Color = GATE[int(C.gate)]
	var gatem := _m(gatec, 0.5 if int(C.gate) > 0 else 0.9, 0.8 if int(C.gate) > 0 else 0.0)
	var banc: Color = tc if int(C.banner) == 0 and tc != Color(0, 0, 0, 0) else BANNER[int(C.banner)]
	if int(C.banner) > 0:
		banc = BANNER[int(C.banner)]
	var cloth := _m(banc, 0.8, 0.0, 0.35)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glowc: Color = GLOW[int(C.glow)]
	var win := _m(glowc.darkened(0.15), 0.5, 0.0, 1.6)
	var HW := 16.0                 # half width of the curtain wall
	var WH := 7.0                  # wall height
	var TH := 2.4                  # thickness
	# ---- curtain walls (front wall has a gate gap)
	_b(root, Vector3(2 * HW + TH, WH, TH), stone, Vector3(0, WH * 0.5, -HW))
	_b(root, Vector3(TH, WH, 2 * HW), stone, Vector3(-HW, WH * 0.5, 0))
	_b(root, Vector3(TH, WH, 2 * HW), stone, Vector3(HW, WH * 0.5, 0))
	var seg := HW - 4.0
	_b(root, Vector3(seg, WH, TH), stone, Vector3(-(HW + 4.0) * 0.5 - 0.0, WH * 0.5, HW))
	_b(root, Vector3(seg, WH, TH), stone, Vector3((HW + 4.0) * 0.5, WH * 0.5, HW))
	_b(root, Vector3(8.0, 2.0, TH), stone_d, Vector3(0, WH - 1.0, HW))        # gate lintel
	# gate: arch frame, door, portcullis
	_b(root, Vector3(0.9, 5.2, TH + 0.5), stone_d, Vector3(-3.6, 2.6, HW))
	_b(root, Vector3(0.9, 5.2, TH + 0.5), stone_d, Vector3(3.6, 2.6, HW))
	_b(root, Vector3(6.4, 4.6, 0.4), gatem, Vector3(0, 2.3, HW - 0.4))
	for i in 7:
		_b(root, Vector3(0.18, 4.4, 0.2), _m(Color(0.15, 0.15, 0.17), 0.5, 0.9), Vector3(-2.7 + i * 0.9, 2.4, HW + 0.2))
	for i in 4:
		_b(root, Vector3(6.2, 0.18, 0.2), _m(Color(0.15, 0.15, 0.17), 0.5, 0.9), Vector3(0, 0.8 + i * 1.1, HW + 0.2))
	# ---- battlements (one multimesh)
	var merlons: Array = []
	for i in 21:
		var x := -HW + i * (2.0 * HW / 20.0)
		merlons.append(Transform3D(Basis(), Vector3(x, WH + 0.6, -HW)))
		if absf(x) > 4.4:
			merlons.append(Transform3D(Basis(), Vector3(x, WH + 0.6, HW)))
	for i in 1:
		pass
	for i in 19:
		var z := -HW + 1.6 + i * (2.0 * HW - 3.2) / 18.0
		merlons.append(Transform3D(Basis(), Vector3(-HW, WH + 0.6, z)))
		merlons.append(Transform3D(Basis(), Vector3(HW, WH + 0.6, z)))
	var mb := BoxMesh.new()
	mb.size = Vector3(1.3, 1.2, 1.3)
	_multi(root, mb, stone, merlons)
	# ---- towers
	var tstyle: int = int(C.tstyle)
	var spots: Array = [Vector3(-HW, 0, -HW), Vector3(HW, 0, -HW), Vector3(-HW, 0, HW), Vector3(HW, 0, HW)]
	if int(C.tcount) >= 1:
		spots.append(Vector3(-HW, 0, 0))
		spots.append(Vector3(HW, 0, 0))
	if int(C.tcount) >= 2:
		spots.append(Vector3(0, 0, -HW))
		spots.append(Vector3(-HW * 0.5, 0, HW))
		spots.append(Vector3(HW * 0.5, 0, HW))
	var wins: Array = []
	for s in spots:
		var th: float = 12.0 + (2.0 if (s.x != 0 and absf(s.z) == HW) else 0.0)
		_tower(root, s, th, tstyle, stone, stone_d, roofm, cloth, gold, out, wins)
	# ---- keep
	var kh: float = [12.0, 16.0, 21.0][int(C.keep)]
	_b(root, Vector3(11.0, kh, 11.0), stone, Vector3(0, kh * 0.5, -3.0))
	_b(root, Vector3(12.6, 1.0, 12.6), stone_d, Vector3(0, kh, -3.0))
	var km: Array = []
	for i in 6:
		for sgn in [-1, 1]:
			km.append(Transform3D(Basis(), Vector3(-5.0 + i * 2.0, kh + 1.1, -3.0 + 6.0 * sgn)))
			if i > 0 and i < 5:
				km.append(Transform3D(Basis(), Vector3(6.0 * sgn, kh + 1.1, -3.0 - 5.0 + i * 2.0)))
	_multi(root, mb, stone, km)
	for sx in [-1, 1]:
		_cyl(root, 1.6, 1.9, kh + 4.0, stone, Vector3(5.6 * sx, (kh + 4.0) * 0.5, -3.0 + 5.6), 10)
		_cyl(root, 0.0, 2.3, 3.2, roofm, Vector3(5.6 * sx, kh + 5.6, -3.0 + 5.6), 10)
	_cyl(root, 0.0, 4.4, 5.0, roofm, Vector3(0, kh + 3.0, -3.0), 4).rotation.y = PI / 4.0
	# keep windows
	for r in range(int(kh / 4.0)):
		for c in 3:
			wins.append(Transform3D(Basis(), Vector3(-3.0 + c * 3.0, 3.2 + r * 3.6, -3.0 + 5.55)))
	# keep banner
	_flag(root, Vector3(0, kh + 5.6, -3.0), 4.4, 2.6, cloth, gold, out, int(C.emblem))
	# window panes
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(0.9, 1.5, 0.15)
	_multi(root, wmesh, win, wins)
	# ---- courtyard clutter: well + a few huts
	_cyl(root, 1.1, 1.2, 1.0, stone_d, Vector3(8.0, 0.5, 6.0), 10)
	for h in [Vector3(-9, 0, 4), Vector3(-9, 0, -8), Vector3(10, 0, -10)]:
		_b(root, Vector3(4.5, 2.6, 4.0), stone_d, h + Vector3(0, 1.3, 0))
		var pr := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(5.2, 2.0, 4.6)
		pr.mesh = pm
		pr.material_override = roofm
		pr.position = h + Vector3(0, 3.6, 0)
		root.add_child(pr)
	# ---- torches at the gate
	if int(C.torch) == 1:
		for sx in [-4.3, 4.3]:
			var tpos := Vector3(sx, 4.0, HW + 1.7)
			_b(root, Vector3(0.18, 1.1, 0.18), wood, tpos)
			var fl := _b(root, Vector3(0.4, 0.5, 0.4), _m(Color(1.0, 0.6, 0.2), 0.5, 0.0, 5.0), tpos + Vector3(0, 0.8, 0))
			out.flames.append(fl)
			if lights_on:
				var ol := OmniLight3D.new()
				ol.position = tpos + Vector3(0, 1.1, 0.3)
				ol.light_color = Color(1.0, 0.62, 0.28)
				ol.light_energy = 1.8
				ol.omni_range = 14.0
				root.add_child(ol)
				out.lights.append(ol)
			var ps := CPUParticles3D.new()
			ps.position = tpos + Vector3(0, 1.0, 0)
			ps.amount = 10
			ps.lifetime = 0.9
			ps.direction = Vector3(0, 1, 0)
			ps.spread = 12.0
			ps.initial_velocity_min = 0.6
			ps.initial_velocity_max = 1.4
			ps.gravity = Vector3(0, 0.6, 0)
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			sm.radial_segments = 5
			sm.rings = 2
			var pmx := StandardMaterial3D.new()
			pmx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pmx.albedo_color = Color(1.0, 0.7, 0.25)
			sm.material = pmx
			ps.mesh = sm
			root.add_child(ps)
	# ---- moat + drawbridge
	if int(C.moat) == 1:
		var water := _m(Color(0.1, 0.25, 0.4), 0.15, 0.4, 0.15)
		var R := HW + 4.6
		_b(root, Vector3(2 * R, 0.3, 3.2), water, Vector3(0, 0.05, -R + 0.6))
		_b(root, Vector3(3.2, 0.3, 2 * R), water, Vector3(-R + 0.6, 0.05, 0))
		_b(root, Vector3(3.2, 0.3, 2 * R), water, Vector3(R - 0.6, 0.05, 0))
		_b(root, Vector3(R - 2.2, 0.3, 3.2), water, Vector3(-(R + 2.2) * 0.5, 0.05, R - 0.6))
		_b(root, Vector3(R - 2.2, 0.3, 3.2), water, Vector3((R + 2.2) * 0.5, 0.05, R - 0.6))
		_b(root, Vector3(4.2, 0.35, 5.2), wood, Vector3(0, 0.12, HW + 2.2))
	return out


static func _tower(root: Node3D, s: Vector3, th: float, style: int, stone, stone_d, roofm, cloth, gold, out: Dictionary, wins: Array) -> void:
	var p := Vector3(s.x, 0, s.z)
	var round_t: bool = style == 0 or style == 3
	if round_t:
		_cyl(root, 3.0, 3.5, th, stone, p + Vector3(0, th * 0.5, 0), 16)
		_cyl(root, 3.8, 3.8, 0.8, stone_d, p + Vector3(0, th + 0.2, 0), 16)
	else:
		_b(root, Vector3(6.2, th, 6.2), stone, p + Vector3(0, th * 0.5, 0))
		_b(root, Vector3(7.2, 0.8, 7.2), stone_d, p + Vector3(0, th + 0.2, 0))
	if style == 0:
		_cyl(root, 0.0, 4.6, 6.0, roofm, p + Vector3(0, th + 3.6, 0), 16)
	elif style == 1:
		_cyl(root, 0.0, 5.0, 5.5, roofm, p + Vector3(0, th + 3.4, 0), 4).rotation.y = PI / 4.0
	else:
		var mer: Array = []
		for i in 8:
			var a := float(i) / 8.0 * TAU
			mer.append(Transform3D(Basis(), p + Vector3(sin(a) * 3.1, th + 1.1, cos(a) * 3.1)))
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 1.2, 1.2)
		_multi(root, bm, stone, mer)
		_b(root, Vector3(0.2, 4.0, 0.2), gold, p + Vector3(0, th + 2.8, 0))
		_flag(root, p + Vector3(0, th + 4.2, 0), 2.4, 1.4, cloth, gold, out, 0)
	if style == 0 or style == 1:
		_flag(root, p + Vector3(0, th + 7.0 if style == 0 else th + 6.2, 0), 2.2, 1.3, cloth, gold, out, 0)
	for k in 2:
		wins.append(Transform3D(Basis(), p + Vector3(0, 3.0 + k * 4.2, 3.2 if not round_t else 3.1)))


static func _flag(root: Node3D, pos: Vector3, w: float, h: float, cloth, gold, out: Dictionary, emblem: int) -> void:
	var pole := _b(root, Vector3(0.14, h + 1.2, 0.14), gold, pos + Vector3(0, (h + 1.2) * 0.5, 0))
	var f := Node3D.new()
	f.position = pos + Vector3(0, h * 0.5 + 0.9, 0)
	root.add_child(f)
	_b(f, Vector3(0.05, h, w), cloth, Vector3(0, 0, w * 0.5 + 0.1))
	# emblem on both faces (thin gold shapes)
	for face in [-1, 1]:
		var ez: float = w * 0.5 + 0.1
		var x: float = 0.05 * face
		match emblem:
			1:
				_b(f, Vector3(0.03, h * 0.7, w * 0.1), gold, Vector3(x, 0, ez))
				_b(f, Vector3(0.03, h * 0.12, w * 0.5), gold, Vector3(x, h * 0.1, ez))
			2:
				_b(f, Vector3(0.03, h * 0.45, h * 0.45), gold, Vector3(x, 0, ez), Vector3(PI / 4.0, 0, 0))
			3:
				_b(f, Vector3(0.03, h * 0.18, w * 0.6), gold, Vector3(x, -h * 0.12, ez))
				for k in 3:
					_b(f, Vector3(0.03, h * 0.3, w * 0.1), gold, Vector3(x, h * 0.08, ez + (k - 1) * w * 0.22))
			4:
				_b(f, Vector3(0.03, h * 0.7, w * 0.07), gold, Vector3(x, 0, ez))
				_b(f, Vector3(0.03, h * 0.08, w * 0.4), gold, Vector3(x, -h * 0.12, ez))
	out.flags.append(f)


static func sway(flags: Array, t: float) -> void:
	for i in flags.size():
		var f: Node3D = flags[i]
		f.rotation.y = sin(t * 2.2 + i * 1.7) * 0.22
		f.rotation.z = sin(t * 3.1 + i) * 0.04


static func flicker(out: Dictionary, t: float) -> void:
	for i in out.lights.size():
		var l: OmniLight3D = out.lights[i]
		l.light_energy = 1.8 + sin(t * 12.0 + i * 3.0) * 0.25 + sin(t * 29.0 + i) * 0.15
	for i in out.flames.size():
		var f: Node3D = out.flames[i]
		f.scale = Vector3(1, 1.0 + sin(t * 17.0 + i * 2.0) * 0.25, 1)
