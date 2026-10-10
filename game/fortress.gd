extends Node
# The walled city of each kingdom: walls, towers, animated gate, courtyard, keep,
# townsfolk and the two helpers you can talk to (messenger + advisor).
# Everything is parented to the castle root so it collapses together when the castle falls.

const UnitS := preload("res://game/unit.gd")

var kingdom
var battle
var gate_l := [null, null]
var gate_r := [null, null]
var gate_amt := [0.0, 0.0]
var gate_prev := [false, false]
var folk := [[], []]
var folk_state := [[], []]
var npcs := {}          # "messenger" / "advisor" -> puppet unit of MY team
var guards := []
var rng := RandomNumberGenerator.new()


func _m(c: Color, rough := 0.9, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	return battle._mat(c, rough, metal, emis)


func _b(parent: Node, sz: Vector3, mat: Material, p: Vector3, shadow := true) -> MeshInstance3D:
	return battle._mesh(parent, battle._box(sz), mat, p, Vector3.ZERO, shadow)


func _c(parent: Node, top: float, bot: float, h: float, mat: Material, p: Vector3, seg := 14) -> MeshInstance3D:
	return battle._mesh(parent, battle._cyl(top, bot, h, seg), mat, p)


# ================================================================== build
func build() -> void:
	rng.seed = 1234
	for t in 2:
		_build_fort(t)
	for t in 2:
		_sync_folk(t)
	_make_npcs()


func _build_fort(t: int) -> void:
	var dz: float = kingdom.dz_of(t)
	var b := -dz                       # local z direction towards the back of the castle
	var root: Node3D = battle.castle_roots[t]
	var tc := Color(0.12, 0.32, 0.95) if t == 0 else Color(0.9, 0.12, 0.1)
	var stone := _m(Color(0.55, 0.53, 0.5), 0.95)
	var stone_d := _m(Color(0.42, 0.4, 0.38), 0.95)
	var cloth := _m(tc, 0.8, 0.0, 0.5)
	var gold_m := _m(Color(1.0, 0.78, 0.25), 0.9, 0.25, 0.3)
	var wood := _m(Color(0.32, 0.2, 0.1), 0.9)
	var cobble := _m(Color(0.46, 0.44, 0.41), 1.0)
	var road := _m(Color(0.62, 0.58, 0.5), 1.0)
	var roofm := _m(Color(0.34, 0.17, 0.12), 0.85)
	var flame := _m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0)

	# side + rear walls
	for sx in [-36.0, 36.0]:
		_b(root, Vector3(3, 9, 48), stone, Vector3(sx, 4.5, b * 24.0))
		for i in 12:
			_b(root, Vector3(3.3, 1.6, 2.2), stone, Vector3(sx, 9.8, b * (2.0 + i * 4.0)), false)
	_b(root, Vector3(72, 9, 3), stone, Vector3(0, 4.5, b * 48.0))
	for i in 18:
		_b(root, Vector3(2.2, 1.6, 3.3), stone, Vector3(-34 + i * 4.0, 9.8, b * 48.0), false)
	# towers (rear corners + mid sides)
	for sx in [-36.0, 36.0]:
		_c(root, 4.4, 4.6, 16.0, stone, Vector3(sx, 8, b * 48.0))
		_c(root, 0.0, 6.0, 6.5, cloth, Vector3(sx, 19, b * 48.0))
		_b(root, Vector3(0.2, 5, 0.2), stone, Vector3(sx, 24, b * 48.0), false)
		_b(root, Vector3(3.2, 2.0, 0.1), cloth, Vector3(sx + 1.7, 25, b * 48.0), false)
		_c(root, 3.4, 3.6, 13.0, stone, Vector3(sx, 6.5, b * 24.0))
		_c(root, 0.0, 4.8, 5.0, cloth, Vector3(sx, 15.5, b * 24.0))
	# gate frame pillars and the two door leaves
	for sx in [-5.7, 5.7]:
		_b(root, Vector3(1.6, 9.6, 3.8), stone_d, Vector3(sx, 4.8, 0))
	for side in 2:
		var hx := -5.0 if side == 0 else 5.0
		var piv := Node3D.new()
		piv.position = Vector3(hx, 0, 0)
		root.add_child(piv)
		var leaf_dir := 1.0 if side == 0 else -1.0
		_b(piv, Vector3(5.0, 7.0, 0.5), wood, Vector3(2.5 * leaf_dir, 3.5, 0))
		for k in 3:
			_b(piv, Vector3(5.0, 0.25, 0.62), _m(Color(0.2, 0.2, 0.22), 0.5, 0.6), Vector3(2.5 * leaf_dir, 1.2 + k * 2.2, 0), false)
		if side == 0:
			gate_l[t] = piv
		else:
			gate_r[t] = piv

	# courtyard ground, road, plaza
	_b(root, Vector3(70, 0.12, 46), cobble, Vector3(0, 0.06, b * 25.0), false)
	_b(root, Vector3(7, 0.14, 40), road, Vector3(0, 0.07, b * 22.0), false)
	_c(root, 6.5, 6.5, 0.16, road, Vector3(0, 0.08, b * 19.0), 24)
	# well
	_c(root, 1.3, 1.4, 1.1, stone, Vector3(0, 0.55, b * 19.0), 16)
	for sx in [-1.1, 1.1]:
		_b(root, Vector3(0.18, 2.6, 0.18), wood, Vector3(sx, 1.9, b * 19.0), false)
	var pm := PrismMesh.new()
	pm.size = Vector3(3.0, 1.0, 2.0)
	battle._mesh(root, pm, roofm, Vector3(0, 3.5, b * 19.0), Vector3.ZERO, false)
	# market stalls
	for sx in [-12.0, 12.0]:
		_b(root, Vector3(3.2, 1.1, 1.6), wood, Vector3(sx, 0.55, b * 19.0))
		for px in [-1.5, 1.5]:
			_b(root, Vector3(0.12, 2.4, 0.12), wood, Vector3(sx + px, 1.2, b * 19.0 + 0.8), false)
		var aw := PrismMesh.new()
		aw.size = Vector3(3.6, 0.7, 2.4)
		battle._mesh(root, aw, cloth, Vector3(sx, 2.6, b * 19.0), Vector3.ZERO, false)
		for k in 4:
			_b(root, Vector3(0.45, 0.4, 0.45), _m(Color(0.9, 0.6 - 0.1 * k, 0.2)), Vector3(sx - 1.1 + k * 0.7, 1.3, b * 19.0), false)
	# torch posts near the gate (inside) and by the keep
	for pos in [Vector3(-8, 0, 3.5), Vector3(8, 0, 3.5), Vector3(-8, 0, 33), Vector3(8, 0, 33)]:
		_b(root, Vector3(0.2, 2.6, 0.2), wood, Vector3(pos.x, 1.3, b * pos.z), false)
		battle._mesh(root, battle._cyl(0.0, 0.4, 0.8, 8), flame, Vector3(pos.x, 2.9, b * pos.z), Vector3.ZERO, false)
	for lp in [Vector3(0, 5, 19), Vector3(0, 5, 33)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.35)
		l.light_energy = 1.4
		l.omni_range = 24.0
		l.position = Vector3(lp.x, lp.y, b * lp.z)
		root.add_child(l)

	# the keep (grows with the castle level)
	var kz := b * 39.0
	_b(root, Vector3(18, 11, 12), stone, Vector3(0, 5.5, kz))
	var kr := PrismMesh.new()
	kr.size = Vector3(19.5, 5.0, 13.5)
	battle._mesh(root, kr, cloth, Vector3(0, 13.5, kz), Vector3.ZERO, true)
	_b(root, Vector3(3.6, 4.6, 0.3), _m(Color(0.15, 0.1, 0.07)), Vector3(0, 2.3, kz - b * 6.05), false)
	for sx in [-5.5, 5.5]:
		_b(root, Vector3(1.2, 1.8, 0.2), _m(Color(1.0, 0.8, 0.4), 0.5, 0.0, 2.0), Vector3(sx, 6.5, kz - b * 6.05), false)
	_b(root, Vector3(0.25, 6.0, 0.25), stone, Vector3(0, 19.5, kz), false)
	_b(root, Vector3(3.6, 2.2, 0.12), cloth, Vector3(1.9, 20.5, kz), false)
	var l2 := Node3D.new()
	l2.visible = false
	root.add_child(l2)
	for sx in [-10.0, 10.0]:
		_c(l2, 3.0, 3.2, 16.0, stone, Vector3(sx, 8.0, kz))
		_c(l2, 0.0, 4.2, 5.5, cloth, Vector3(sx, 18.7, kz))
	_c(l2, 5.0, 5.4, 9.0, stone, Vector3(0, 15.5, kz))
	_c(l2, 0.0, 6.4, 7.0, cloth, Vector3(0, 23.5, kz))
	var l3 := Node3D.new()
	l3.visible = false
	root.add_child(l3)
	for sx in [-10.0, 10.0]:
		battle._mesh(l3, battle._cyl(0.0, 4.4, 5.0, 14), gold_m, Vector3(sx, 19.0, kz))
	battle._mesh(l3, battle._sph_mesh(1.3), gold_m, Vector3(0, 28.5, kz), Vector3.ZERO, false)
	for sx in [-17.0, 17.0]:
		_c(l3, 2.4, 2.6, 11.0, stone, Vector3(sx, 5.5, b * 25.0))
		battle._mesh(l3, battle._cyl(0.0, 3.4, 4.0, 12), gold_m, Vector3(sx, 13.0, b * 25.0))
	kingdom.extras[t] = {"l2": l2, "l3": l3}
	var fire_pos := [Vector3(-36, 17, 0), Vector3(33, 11, 0), Vector3(2, 10, b * 38.0)]
	for fp in fire_pos:
		kingdom.fires[t].append(kingdom._make_fire(root, fp))

	# gate guards (decoration)
	for sx in [-7.5, 7.5]:
		var g = _puppet("sword", t, Vector3(sx, 0, 0) + Vector3(0, 0, -dz * 70.0))
		g.tyaw = 0.0 if t == 0 else PI
		guards.append(g)


func _puppet(kind: String, t: int, pos: Vector3):
	var u = UnitS.new()
	u.uid = -1
	u.position = pos
	battle.add_child(u)
	u.setup(kind, t, -500, battle)
	u.puppet = true
	u.tpos = pos
	u.rotation.y = 0.0 if t == 0 else PI
	u.tyaw = u.rotation.y
	return u


# ================================================================== townsfolk + NPCs
func _folk_target(t: int) -> int:
	return clampi(4 + 2 * kingdom.count_slots(t, 1), 4, 26)


func _sync_folk(t: int) -> void:
	var want := _folk_target(t)
	while folk[t].size() < want:
		var dz: float = kingdom.dz_of(t)
		var p := Vector3(rng.randf_range(-24.0, 24.0), 0, -dz * rng.randf_range(80.0, 112.0))
		var f = _puppet("villager", t, p)
		folk[t].append(f)
		folk_state[t].append({"wait": rng.randf_range(0.0, 3.0), "to": p})


func sync() -> void:
	for t in 2:
		_sync_folk(t)


func _make_npcs() -> void:
	var t: int = kingdom.my_team
	var dz: float = kingdom.dz_of(t)
	var defs := {"messenger": [-5.0, "MESSENGER"], "advisor": [5.0, "ADVISOR"]}
	for k in defs.keys():
		var p := Vector3(defs[k][0], 0, -dz * 92.0)
		var u = _puppet("villager", t, p)
		u.tyaw = u.rotation.y
		npcs[k] = u
		var lb := Label3D.new()
		lb.text = defs[k][1]
		lb.font_size = 54
		lb.pixel_size = 0.01
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.outline_size = 14
		lb.modulate = Color(1.0, 0.9, 0.5)
		lb.position = Vector3(0, 2.7, 0)
		u.add_child(lb)
		var hat_col := Color(0.8, 0.15, 0.15) if k == "messenger" else Color(1.0, 0.78, 0.25)
		battle._mesh(u.body, battle._box(Vector3(0.46, 0.14, 0.46)), _m(hat_col, 0.6, 0.2 if k == "advisor" else 0.0, 0.0), Vector3(0, 1.98, 0.03), Vector3.ZERO, false)
		if k == "messenger":
			battle._mesh(u.body, battle._box(Vector3(0.1, 0.1, 0.5)), _m(Color(0.96, 0.92, 0.8), 0.9, 0.0, 0.4), Vector3(0.3, 1.2, 0.35), Vector3.ZERO, false)
		else:
			battle._mesh(u.body, battle._box(Vector3(0.66, 0.9, 0.34)), _m(Color(0.45, 0.12, 0.5), 0.9), Vector3(0, 0.75, 0), Vector3.ZERO, false)


func npc_near(kind: String, p: Vector3, r := 5.5) -> bool:
	var u = npcs.get(kind)
	return u != null and is_instance_valid(u) and Vector2(u.position.x - p.x, u.position.z - p.z).length() < r


# ================================================================== per-frame
func _process(dt: float) -> void:
	if kingdom == null or battle == null:
		return
	# gates swing open / closed
	for t in 2:
		var open: bool = kingdom.gate_open[t]
		if open != gate_prev[t]:
			gate_prev[t] = open
			var gp := Vector3(0, 3, -kingdom.dz_of(t) * 73.0)
			battle.sfx.play("thud", gp, -2.0, 0.55)
		gate_amt[t] = move_toward(gate_amt[t], 1.0 if open else 0.0, dt * 1.4)
		var a: float = deg_to_rad(100.0) * kingdom.dz_of(t) * gate_amt[t]
		if gate_l[t] != null:
			gate_l[t].rotation.y = a
			gate_r[t].rotation.y = -a
	# townsfolk wander inside the walls
	for t in 2:
		if kingdom.fallen[t]:
			continue
		var dz: float = kingdom.dz_of(t)
		for i in folk[t].size():
			var f = folk[t][i]
			var st: Dictionary = folk_state[t][i]
			if st.wait > 0.0:
				st.wait -= dt
				continue
			var to: Vector3 = st.to
			var d: Vector3 = to - f.tpos
			d.y = 0.0
			if d.length() < 0.6:
				st.wait = rng.randf_range(1.5, 6.0)
				var tx := rng.randf_range(-27.0, 27.0)
				var tz := -dz * rng.randf_range(80.5, 117.0)
				if rng.randf() < 0.45:
					tx = rng.randf_range(-9.0, 9.0)
					tz = -dz * rng.randf_range(80.5, 100.0)
				st.to = Vector3(tx, 0, tz)
			else:
				var step := d.normalized() * 1.6 * dt
				f.tpos += step
				f.tyaw = atan2(d.x, d.z)
