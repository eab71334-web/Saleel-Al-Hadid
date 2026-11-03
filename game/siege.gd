extends RefCounted
# Detailed siege engines with real mechanics:
#   catapult -> counterweight TREBUCHET (hinged counterweight, sling, windlass, wheels)
#   ballista -> torsion BALLISTA (twisted-sinew skeins, flexing bow arms, string, slider, windlass, bolt)
# build(u, team_colour) fills u.body and stores the moving parts; animate(u, dt) is called every frame.

const A0 := -0.55         # trebuchet: arm cocked (long end down at the rear)
const A_END := 3.35       # arm after the throw
const RELEASE_K := 0.67   # share of the throw at which the stone leaves the sling
const FIRE_T := 1.7       # seconds the throw lasts
const HUB_Y := 3.7        # trebuchet axle height
const ARM_LONG := 5.2
const ARM_SHORT := 1.5
const SLING := 2.4


static func _m(c: Color, metal := 0.0, rough := 0.85, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


static func _b(p: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi


# cylinder whose axis is X (axis = 0), Y (1) or Z (2)
static func _c(p: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, axis := 1, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if axis == 0:
		mi.rotation = Vector3(0, 0, PI / 2.0)
	elif axis == 2:
		mi.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(mi)
	return mi


static func _s(p: Node3D, r: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


# a square beam / rope between two points (a MeshInstance3D of a unit-length box that we can re-aim every frame)
static func _beam(p: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material, thick2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, thick2 if thick2 > 0.0 else thick, 1.0)
	mi.mesh = bm
	mi.material_override = mat
	p.add_child(mi)
	aim(mi, a, b)
	return mi


static func aim(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var up := Vector3.UP if absf(d.normalized().y) < 0.97 else Vector3.RIGHT
	var bs := Basis.looking_at(d / l, up)
	mi.transform = Transform3D(bs * Basis.from_scale(Vector3(1, 1, l)), (a + b) * 0.5)


static func _wheel(p: Node3D, pos: Vector3, r: float, thick: float, wood: Material, iron: Material) -> Node3D:
	var w := Node3D.new()
	w.position = pos
	p.add_child(w)
	var spin := Node3D.new()
	w.add_child(spin)
	_c(spin, r, r, thick, wood, Vector3.ZERO, 0, 16)
	_c(spin, r * 1.04, r * 1.04, thick * 0.55, iron, Vector3.ZERO, 0, 16)
	_c(spin, r * 0.22, r * 0.22, thick * 1.5, iron, Vector3.ZERO, 0, 8)
	for i in 4:
		var ang := float(i) * PI / 4.0
		_b(spin, Vector3(thick * 1.25, r * 2.0 * 0.96, r * 0.12), wood, Vector3.ZERO, Vector3(ang, 0, 0), false)
	w.set_meta("spin", spin)
	w.set_meta("r", r)
	return w


static func build(u, tc: Color) -> void:
	if u.kind == "catapult":
		_build_trebuchet(u, tc)
	else:
		_build_ballista(u, tc)


# ============================================================ TREBUCHET
static func _build_trebuchet(u, tc: Color) -> void:
	var body: Node3D = u.body
	var wood := _m(Color(0.5, 0.34, 0.17), 0.0, 0.9)
	var dwood := _m(Color(0.3, 0.19, 0.1), 0.0, 0.9)
	var lwood := _m(Color(0.62, 0.45, 0.25), 0.0, 0.9)
	var iron := _m(Color(0.26, 0.27, 0.3), 0.75, 0.5)
	var rope := _m(Color(0.72, 0.62, 0.42), 0.0, 1.0)
	var stone := _m(Color(0.46, 0.45, 0.43), 0.0, 0.95)
	var cloth := _m(tc, 0.0, 0.8, 0.35)
	var sg := {}
	# ---- sled base
	for sx in [-1.25, 1.25]:
		_b(body, Vector3(0.38, 0.34, 8.2), dwood, Vector3(sx, 0.42, -1.4))
		_b(body, Vector3(0.1, 0.36, 8.25), iron, Vector3(sx + signf(sx) * 0.2, 0.42, -1.4), Vector3.ZERO, false)
	for z in [-4.6, -2.2, 0.0, 2.0]:
		_b(body, Vector3(3.0, 0.3, 0.42), wood, Vector3(0, 0.55, z))
	# ---- twin A-frames
	for sx in [-1.0, 1.0]:
		var top := Vector3(sx, HUB_Y, 0.0)
		_beam(body, Vector3(sx, 0.55, 1.75), top, 0.36, wood)
		_beam(body, Vector3(sx, 0.55, -1.75), top, 0.36, wood)
		_b(body, Vector3(0.22, 0.7, 0.7), iron, Vector3(sx + signf(sx) * 0.12, HUB_Y, 0.0), Vector3.ZERO, false)
		# cross rails
		_beam(body, Vector3(sx, 1.5, 1.05), Vector3(sx, 1.5, -1.05), 0.22, lwood)
		_beam(body, Vector3(sx, 2.4, 0.55), Vector3(sx, 2.4, -0.55), 0.2, lwood)
	# diagonal bracing between the frames
	_beam(body, Vector3(-1.0, 0.6, 1.5), Vector3(1.0, 2.6, 0.4), 0.14, dwood)
	_beam(body, Vector3(1.0, 0.6, 1.5), Vector3(-1.0, 2.6, 0.4), 0.14, dwood)
	_beam(body, Vector3(-1.0, 0.6, -1.5), Vector3(1.0, 2.6, -0.4), 0.14, dwood)
	_beam(body, Vector3(1.0, 0.6, -1.5), Vector3(-1.0, 2.6, -0.4), 0.14, dwood)
	# axle
	_c(body, 0.19, 0.19, 2.9, iron, Vector3(0, HUB_Y, 0), 0)
	for sx in [-1.45, 1.45]:
		_c(body, 0.3, 0.3, 0.12, iron, Vector3(sx, HUB_Y, 0), 0)
	# ---- wheels
	var wheels: Array = []
	for z in [-3.9, 1.5]:
		for sx in [-1.7, 1.7]:
			wheels.append(_wheel(body, Vector3(sx, 0.5, z), 0.5, 0.2, lwood, iron))
	# ---- throwing arm
	var pv := Node3D.new()
	pv.position = Vector3(0, HUB_Y, 0)
	body.add_child(pv)
	_beam(pv, Vector3(0, 0, 0.0), Vector3(0, 0, -ARM_LONG * 0.55), 0.46, wood, 0.5)
	_beam(pv, Vector3(0, 0, -ARM_LONG * 0.55), Vector3(0, 0, -ARM_LONG), 0.3, wood, 0.34)
	_beam(pv, Vector3(0, 0, 0.0), Vector3(0, 0, ARM_SHORT), 0.44, wood, 0.5)
	for z in [-0.9, -2.0, -3.1, -4.2]:
		_b(pv, Vector3(0.52 - absf(z) * 0.03, 0.56 - absf(z) * 0.03, 0.13), iron, Vector3(0, 0, z), Vector3.ZERO, false)
	_c(pv, 0.2, 0.2, 0.62, iron, Vector3(0, 0, 0), 0)
	_c(pv, 0.08, 0.08, 0.5, iron, Vector3(0, 0, -ARM_LONG - 0.12), 0)
	# ---- counterweight box on a hinge
	var cw := Node3D.new()
	cw.position = Vector3(0, 0, ARM_SHORT)
	pv.add_child(cw)
	_c(cw, 0.1, 0.1, 1.1, iron, Vector3.ZERO, 0)
	for sx in [-0.5, 0.5]:
		_beam(cw, Vector3(sx, 0, 0), Vector3(sx, -0.55, 0), 0.1, iron)
	_b(cw, Vector3(1.45, 0.14, 1.25), dwood, Vector3(0, -0.62, 0))
	_b(cw, Vector3(1.45, 1.35, 0.12), wood, Vector3(0, -1.3, 0.6))
	_b(cw, Vector3(1.45, 1.35, 0.12), wood, Vector3(0, -1.3, -0.6))
	_b(cw, Vector3(0.12, 1.35, 1.25), wood, Vector3(-0.72, -1.3, 0))
	_b(cw, Vector3(0.12, 1.35, 1.25), wood, Vector3(0.72, -1.3, 0))
	_b(cw, Vector3(1.5, 0.14, 1.3), dwood, Vector3(0, -2.0, 0))
	for i in 7:
		var rr := RandomNumberGenerator.new()
		rr.seed = 31 + i
		_b(cw, Vector3(0.4 + rr.randf() * 0.25, 0.4 + rr.randf() * 0.2, 0.4 + rr.randf() * 0.2), stone, Vector3(-0.35 + float(i % 3) * 0.36, -1.0 - float(i / 3) * 0.32, -0.2 + rr.randf() * 0.4), Vector3(rr.randf(), rr.randf(), 0), false)
	for yy in [-0.9, -1.7]:
		_b(cw, Vector3(1.52, 0.1, 1.32), iron, Vector3(0, yy, 0), Vector3.ZERO, false)
	_b(cw, Vector3(0.9, 0.9, 0.04), cloth, Vector3(0, -1.3, 0.67), Vector3.ZERO, false)
	# ---- sling with pouch and stone
	var sl := Node3D.new()
	sl.position = Vector3(0, 0, -ARM_LONG - 0.12)
	pv.add_child(sl)
	for sx in [-0.14, 0.14]:
		_beam(sl, Vector3(sx, 0, 0), Vector3(sx * 0.5, 0, -SLING), 0.05, rope)
	_b(sl, Vector3(0.5, 0.08, 0.55), _m(Color(0.3, 0.2, 0.12), 0.0, 1.0), Vector3(0, -0.05, -SLING), Vector3.ZERO, false)
	var ball := _s(sl, 0.34, stone, Vector3(0, 0.12, -SLING))
	# ---- windlass at the rear with a rope to the arm
	var drum := Node3D.new()
	drum.position = Vector3(0, 0.95, -5.1)
	body.add_child(drum)
	for sx in [-1.2, 1.2]:
		_beam(body, Vector3(sx, 0.45, -5.1), Vector3(sx, 1.35, -5.1), 0.2, wood)
	_c(drum, 0.3, 0.3, 2.3, wood, Vector3.ZERO, 0)
	for sx in [-0.95, 0.95]:
		_c(drum, 0.36, 0.36, 0.1, iron, Vector3(sx, 0, 0), 0)
		for i in 4:
			var ang := float(i) * PI / 2.0 + 0.4
			_b(drum, Vector3(0.1, 0.1, 1.0), dwood, Vector3(sx * 1.25, sin(ang) * 0.0, 0), Vector3(ang, 0, 0), false)
	var wrope := _beam(body, Vector3.ZERO, Vector3(0, 0, 0.1), 0.06, rope)
	# trigger / release pin near the arm rest
	_b(body, Vector3(0.14, 0.7, 0.14), iron, Vector3(0, 1.0, -3.5))
	_b(body, Vector3(0.4, 0.12, 0.5), dwood, Vector3(0, 1.4, -3.5))
	# banner
	var pole := Vector3(1.0, HUB_Y + 0.5, 0.0)
	_c(body, 0.05, 0.05, 2.4, dwood, pole + Vector3(0, 1.0, 0))
	var flag := _b(body, Vector3(0.05, 0.9, 1.3), cloth, pole + Vector3(0, 1.85, 0.7), Vector3.ZERO, false)
	sg = {"type": "treb", "pv": pv, "cw": cw, "sl": sl, "ball": ball, "drum": drum, "wrope": wrope, "wheels": wheels, "flag": flag, "prev": 0.0, "fire_t": -1.0, "a_rest": A0, "w": 1.0, "wheel_x": 0.0, "was_fire": false}
	u.set_meta("sg", sg)
	u.arm = Node3D.new()
	body.add_child(u.arm)
	_pose_treb(sg, A0, 1.0, 1.0, 0.55, 1.0)


static func _pose_treb(sg: Dictionary, a: float, w: float, loaded: float, sling_r: float, rope_on: float) -> void:
	var pv: Node3D = sg.pv
	pv.rotation.x = a
	(sg.cw as Node3D).rotation.x = -a * 0.92
	(sg.sl as Node3D).rotation.x = sling_r
	(sg.ball as Node3D).visible = loaded > 0.5
	(sg.drum as Node3D).rotation.x = w * 14.0
	# rope from the windlass drum to the arm tip while it is being wound
	var tip := Vector3(0, HUB_Y + ARM_LONG * sin(a), -ARM_LONG * cos(a))
	var wr: MeshInstance3D = sg.wrope
	if rope_on > 0.5:
		aim(wr, Vector3(0, 0.95, -5.1), tip)
	else:
		wr.visible = false


# ============================================================ BALLISTA
const BH := 1.45          # bow height
const BPX := 0.62         # bow arm pivot x
const BPZ := 1.15         # bow arm pivot z
const BL := 1.15          # bow arm length
const PHI0 := 0.06        # arms relaxed
const PHI1 := 0.78        # arms drawn


static func _build_ballista(u, tc: Color) -> void:
	var body: Node3D = u.body
	var wood := _m(Color(0.5, 0.34, 0.17), 0.0, 0.9)
	var dwood := _m(Color(0.3, 0.19, 0.1), 0.0, 0.9)
	var lwood := _m(Color(0.62, 0.45, 0.25), 0.0, 0.9)
	var iron := _m(Color(0.27, 0.28, 0.31), 0.75, 0.5)
	var bronze := _m(Color(0.72, 0.5, 0.2), 0.8, 0.4)
	var sinew := _m(Color(0.62, 0.48, 0.3), 0.0, 1.0)
	var rope := _m(Color(0.85, 0.8, 0.68), 0.0, 1.0)
	var cloth := _m(tc, 0.0, 0.8, 0.35)
	# ---- carriage: base beams, cross pieces, wheels
	for sx in [-0.5, 0.5]:
		_b(body, Vector3(0.24, 0.26, 3.6), dwood, Vector3(sx, 0.62, -0.1))
	for z in [-1.4, 0.0, 1.2]:
		_b(body, Vector3(1.4, 0.2, 0.3), wood, Vector3(0, 0.78, z))
	var wheels: Array = []
	for sx in [-0.88, 0.88]:
		wheels.append(_wheel(body, Vector3(sx, 0.52, 0.3), 0.52, 0.16, lwood, iron))
		_c(body, 0.06, 0.06, 0.4, iron, Vector3(sx * 0.82, 0.52, 0.3), 0)
	_b(body, Vector3(0.18, 0.5, 0.18), dwood, Vector3(0, 0.45, -1.7))      # tail prop
	_b(body, Vector3(0.5, 0.1, 0.5), dwood, Vector3(0, 0.22, -1.7))
	# ---- central stock with groove (slider)
	_b(body, Vector3(0.34, 0.3, 3.5), wood, Vector3(0, 1.1, -0.1))
	_b(body, Vector3(0.12, 0.08, 3.4), dwood, Vector3(0, 1.28, -0.1), Vector3.ZERO, false)
	_b(body, Vector3(0.5, 0.06, 3.5), iron, Vector3(0, 1.0, -0.1), Vector3.ZERO, false)
	# pedestal posts
	for sx in [-0.3, 0.3]:
		_beam(body, Vector3(sx, 0.78, 0.7), Vector3(sx * 0.6, 1.0, 0.3), 0.14, wood)
	# ---- front frame holding the torsion skeins
	for sx in [-BPX, BPX]:
		_b(body, Vector3(0.28, 0.9, 0.28), wood, Vector3(sx * 1.0, BH - 0.05, BPZ + 0.02))
		_c(body, 0.2, 0.2, 0.26, bronze, Vector3(sx, BH + 0.5, BPZ))        # upper washer
		_c(body, 0.2, 0.2, 0.26, bronze, Vector3(sx, BH - 0.5, BPZ))        # lower washer
		_c(body, 0.12, 0.12, 0.8, sinew, Vector3(sx, BH, BPZ), 1, 8)        # twisted sinew skein
		for yy in [-0.18, 0.0, 0.18]:
			_c(body, 0.135, 0.135, 0.06, rope, Vector3(sx, BH + yy, BPZ), 1, 8)
		_c(body, 0.07, 0.07, 0.08, iron, Vector3(sx, BH + 0.66, BPZ), 1, 6)   # tension pin
	_b(body, Vector3(BPX * 2.0 + 0.5, 0.22, 0.34), wood, Vector3(0, BH + 0.72, BPZ))
	_b(body, Vector3(BPX * 2.0 + 0.5, 0.22, 0.34), wood, Vector3(0, BH - 0.72, BPZ))
	_b(body, Vector3(0.36, 1.5, 0.3), dwood, Vector3(0, BH, BPZ + 0.04))
	# ---- bow arms (flex about Y)
	var arms: Array = []
	var tips: Array = []
	for sx in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(sx * BPX, BH, BPZ)
		body.add_child(pv)
		var arm := Node3D.new()
		pv.add_child(arm)
		_beam(arm, Vector3.ZERO, Vector3(sx * BL * 0.55, 0, 0.0), 0.2, wood, 0.22)
		_beam(arm, Vector3(sx * BL * 0.55, 0, 0.0), Vector3(sx * BL, 0, 0.14), 0.13, wood, 0.16)
		_b(arm, Vector3(0.26, 0.28, 0.26), iron, Vector3.ZERO, Vector3.ZERO, false)
		_c(arm, 0.07, 0.07, 0.3, iron, Vector3(sx * BL, 0, 0.14), 1, 6)
		arms.append(pv)
		tips.append(sx)
	# ---- string (two segments, re-aimed every frame), slider claw, bolt
	var s1 := _beam(body, Vector3.ZERO, Vector3(0, 0, 1), 0.035, rope)
	var s2 := _beam(body, Vector3.ZERO, Vector3(0, 0, 1), 0.035, rope)
	var claw := Node3D.new()
	body.add_child(claw)
	_b(claw, Vector3(0.24, 0.14, 0.28), iron, Vector3(0, 0, 0), Vector3.ZERO, false)
	_b(claw, Vector3(0.05, 0.2, 0.08), iron, Vector3(-0.1, 0.03, 0.12), Vector3.ZERO, false)
	_b(claw, Vector3(0.05, 0.2, 0.08), iron, Vector3(0.1, 0.03, 0.12), Vector3.ZERO, false)
	var bolt := Node3D.new()
	body.add_child(bolt)
	_c(bolt, 0.035, 0.035, 1.9, lwood, Vector3(0, 0, 0.55), 2, 6)
	_c(bolt, 0.0, 0.07, 0.34, iron, Vector3(0, 0, 1.68), 2, 6)
	for sy in [-1, 1]:
		_b(bolt, Vector3(0.015, 0.2, 0.34), _m(Color(0.9, 0.85, 0.7), 0.0, 1.0), Vector3(0, 0.0, -0.32), Vector3(0, 0, float(sy) * PI / 2.0 * 0.0), false)
	_b(bolt, Vector3(0.2, 0.015, 0.34), _m(Color(0.9, 0.85, 0.7), 0.0, 1.0), Vector3(0, 0, -0.32), Vector3.ZERO, false)
	# ---- rear windlass with ratchet and two cranks
	var crank := Node3D.new()
	crank.position = Vector3(0, 1.05, -1.55)
	body.add_child(crank)
	_c(crank, 0.14, 0.14, 0.9, wood, Vector3.ZERO, 0)
	for sx in [-0.5, 0.5]:
		_c(crank, 0.22, 0.22, 0.06, iron, Vector3(sx, 0, 0), 0)
		_beam(crank, Vector3(sx, 0, 0), Vector3(sx * 1.35, 0.5, 0), 0.07, dwood)
		_c(crank, 0.05, 0.05, 0.26, wood, Vector3(sx * 1.35, 0.5, 0), 0)
	for sx in [-0.46, 0.46]:
		_beam(body, Vector3(sx, 0.78, -1.55), Vector3(sx, 1.05, -1.55), 0.12, wood)
	# ---- front splinter shield with team cloth and iron bosses
	_b(body, Vector3(1.7, 1.15, 0.12), lwood, Vector3(0, BH + 0.05, BPZ + 0.5))
	for x in [-0.55, 0.0, 0.55]:
		_b(body, Vector3(0.04, 1.15, 0.14), dwood, Vector3(x, BH + 0.05, BPZ + 0.5), Vector3.ZERO, false)
	_b(body, Vector3(0.5, 0.42, 0.05), cloth, Vector3(0.0, BH + 0.05, BPZ + 0.6), Vector3.ZERO, false)
	for p in [Vector3(-0.72, 0.4, 0), Vector3(0.72, 0.4, 0), Vector3(-0.72, -0.3, 0), Vector3(0.72, -0.3, 0)]:
		_s(body, 0.07, iron, Vector3(p.x, BH + 0.05 + p.y, BPZ + 0.58))
	# cut a sight notch so the bolt passes the shield
	_b(body, Vector3(0.18, 0.18, 0.16), _m(Color(0.04, 0.03, 0.02), 0.0, 1.0), Vector3(0, BH - 0.12, BPZ + 0.52), Vector3.ZERO, false)
	var sg := {"type": "ball", "arms": arms, "signs": tips, "s1": s1, "s2": s2, "claw": claw, "bolt": bolt, "crank": crank, "wheels": wheels, "prev": 0.0, "shot_t": -1.0, "d": 1.0, "wheel_x": 0.0}
	u.set_meta("sg", sg)
	u.arm = Node3D.new()
	body.add_child(u.arm)
	_pose_ball(sg, 1.0, 0.0, true)


# d = draw fraction (0 relaxed, 1 fully drawn); over = overshoot flex after release
static func _pose_ball(sg: Dictionary, d: float, over: float, loaded: bool) -> void:
	var phi: float = lerpf(PHI0, PHI1, d) + over
	var half := 0.0
	var tipx := 0.0
	var tipz := BPZ - BL * sin(phi) + 0.14 * cos(phi)
	tipx = BPX + BL * cos(phi) + 0.14 * sin(phi) * 0.0
	# string half-length is fixed by the relaxed position
	var relaxed_x: float = BPX + BL * cos(PHI0)
	half = relaxed_x
	var cz: float = tipz - sqrt(maxf(half * half - tipx * tipx, 0.01))
	var arms: Array = sg.arms
	var signs: Array = sg.signs
	for i in arms.size():
		(arms[i] as Node3D).rotation.y = float(signs[i]) * phi
	var c := Vector3(0, BH, cz)
	var tl := Vector3(-tipx, BH, tipz)
	var tr := Vector3(tipx, BH, tipz)
	aim(sg.s1, tl, c)
	aim(sg.s2, c, tr)
	(sg.claw as Node3D).position = c + Vector3(0, -0.02, 0.0)
	var bolt: Node3D = sg.bolt
	bolt.visible = loaded
	bolt.position = c + Vector3(0, 0.12, 0.05)


# ============================================================ per-frame animation
static func animate(u, dt: float) -> void:
	if not u.has_meta("sg"):
		return
	var sg: Dictionary = u.get_meta("sg")
	var cd: float = float(u.KINDS[u.kind].cd)
	var p: float = 1.0 - clampf(u.atk_cd / cd, 0.0, 1.0)
	# wheels roll with the machine
	var travel: float = u.sim_speed * dt
	for w in sg.wheels:
		var r: float = w.get_meta("r")
		(w.get_meta("spin") as Node3D).rotation.x += travel / r
	var sw: float = u.swing
	var edge: bool = sw > 0.9 and float(sg.prev) <= 0.9
	sg.prev = sw
	if sg.type == "treb":
		_anim_treb(u, sg, dt, p, edge)
	else:
		_anim_ball(u, sg, dt, p, edge)


static func _anim_treb(u, sg: Dictionary, dt: float, p: float, edge: bool) -> void:
	if edge:
		sg.fire_t = 0.0
		sg.was_fire = true
	var a := A0
	var sling_r := 0.55
	var loaded := 1.0
	var w := 1.0
	var rope_on := 1.0
	if float(sg.fire_t) >= 0.0:
		sg.fire_t += dt
		var k: float = clampf(float(sg.fire_t) / FIRE_T, 0.0, 1.0)
		var e: float = k * k * (3.0 - 2.0 * k)
		a = lerpf(A0, A_END, e)
		if k < RELEASE_K:
			sling_r = lerpf(0.55, 1.3, smoothstep(0.0, RELEASE_K, k))
		else:
			sling_r = 1.3 * (1.0 - smoothstep(RELEASE_K, RELEASE_K + 0.16, k))
			loaded = 0.0
		rope_on = 0.0
		# counterweight keeps swinging a little after the throw
		sg.cw_wob = sin(float(sg.fire_t) * 6.5) * 0.18 * (1.0 - k) if k > 0.7 else 0.0
		if k >= 1.0:
			sg.fire_t = -1.0
			sg.a_rest = A_END
			sg.w = 0.0
	elif bool(sg.was_fire):
		# winding the arm back down during the cooldown
		var wp: float = clampf((p - 0.38) / 0.52, 0.0, 1.0)
		var ws: float = wp * wp * (3.0 - 2.0 * wp)
		a = lerpf(A_END, A0, ws)
		w = ws
		loaded = 1.0 if wp >= 0.97 else 0.0
		sling_r = lerpf(0.0, 0.55, ws)
		rope_on = 1.0 if wp > 0.05 else 0.0
		sg.cw_wob = 0.0
	_pose_treb(sg, a, w, loaded, sling_r, rope_on)
	(sg.cw as Node3D).rotation.x += float(sg.get("cw_wob", 0.0))
	(sg.flag as Node3D).rotation.y = sin(Time.get_ticks_msec() * 0.003) * 0.12


static func _anim_ball(u, sg: Dictionary, dt: float, p: float, edge: bool) -> void:
	if edge:
		sg.shot_t = 0.0
	var d := 1.0
	var over := 0.0
	var loaded := true
	if float(sg.shot_t) >= 0.0:
		sg.shot_t += dt
		var t: float = sg.shot_t
		# the string snaps forward in a tenth of a second, the arms overshoot and ring
		d = clampf(1.0 - t / 0.09, 0.0, 1.0)
		over = 0.0 if t < 0.09 else -0.1 * exp(-(t - 0.09) * 9.0) * sin((t - 0.09) * 38.0)
		loaded = t < 0.045
		if t > 0.7:
			sg.shot_t = -2.0
	elif float(sg.shot_t) == -2.0:
		# cranking the string back during the cooldown
		var wp: float = clampf((p - 0.18) / 0.7, 0.0, 1.0)
		d = wp * wp * (3.0 - 2.0 * wp)
		loaded = wp > 0.96
		(sg.crank as Node3D).rotation.x = wp * 16.0
	_pose_ball(sg, d, over, loaded)
