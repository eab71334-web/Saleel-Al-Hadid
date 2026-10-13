extends Node
# The walled city of each kingdom: walls, towers, animated gate, courtyard, keep,
# townsfolk and the two helpers you can talk to (messenger + advisor).
# Everything is parented to the castle root so it collapses together when the castle falls.

const UnitS := preload("res://game/unit.gd")
const LocS := preload("res://game/loc.gd")

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
var shell := [[], []]        # keep parts that open up when you stand inside
var shell_ghost := [[], []]  # side walls that turn see-through
var piles := [[], []]
var board := [null, null]
var throne_pos := [Vector3.ZERO, Vector3.ZERO]
var inside_keep := false
var board_t := 0.0
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
	var n: int = kingdom.nk
	gate_l = []; gate_r = []; gate_amt = []; gate_prev = []; folk = []; folk_state = []
	shell = []; shell_ghost = []; piles = []; board = []; throne_pos = []
	for t in n:
		gate_l.append(null); gate_r.append(null); gate_amt.append(0.0); gate_prev.append(false)
		folk.append([]); folk_state.append([]); shell.append([]); shell_ghost.append([])
		piles.append([]); board.append(null); throne_pos.append(Vector3.ZERO)
	for t in n:
		_build_fort(t)
	for t in n:
		_sync_folk(t)
	_make_npcs()


func _build_fort(t: int) -> void:
	var b := -1.0                      # local z direction towards the back of the castle (root is rotated per kingdom)
	var root: Node3D = battle.castle_roots[t]
	var tc: Color = battle.team_col(t)
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

	# the keep = the throne hall (hollow, walkable, with a ceiling)
	var kz := b * 38.5
	_build_keep(t, root, b, kz, tc, stone, stone_d, cloth, gold_m, wood)
	var l2 := Node3D.new()
	l2.visible = false
	root.add_child(l2)
	for sx in [-13.5, 13.5]:
		_c(l2, 3.0, 3.2, 16.0, stone, Vector3(sx, 8.0, kz))
		_c(l2, 0.0, 4.2, 5.5, cloth, Vector3(sx, 18.7, kz))
	_c(l2, 5.0, 5.4, 9.0, stone, Vector3(0, 15.5, kz))
	_c(l2, 0.0, 6.4, 7.0, cloth, Vector3(0, 23.5, kz))
	var l3 := Node3D.new()
	l3.visible = false
	root.add_child(l3)
	for sx in [-13.5, 13.5]:
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
		var g = _puppet("sword", t, kingdom.lw(t, Vector3(sx, 0, -70.0)))
		g.tyaw = kingdom.ang(t)
		guards.append(g)


# ================================================================== the throne hall
func _build_keep(t: int, root: Node3D, b: float, kz: float, tc: Color, stone: Material, stone_d: Material, cloth: Material, gold_m: Material, wood: Material) -> void:
	var marble := _m(Color(0.86, 0.83, 0.76), 0.5)
	var carpet := _m(tc.darkened(0.25), 0.95)
	var dark := _m(Color(0.22, 0.13, 0.07), 0.9)
	var lamp := _m(Color(1.0, 0.8, 0.4), 0.5, 0.0, 3.0)
	var hall_wall := _m(Color(0.62, 0.58, 0.52), 0.95)
	var ghost: Array = shell_ghost[t]
	var cut: Array = shell[t]
	# floor + carpet + dais
	_b(root, Vector3(21, 0.3, 15), marble, Vector3(0, 0.15, kz), false)
	_b(root, Vector3(4.2, 0.34, 14), carpet, Vector3(0, 0.17, kz), false)
	_b(root, Vector3(11, 0.6, 4.2), marble, Vector3(0, 0.45, kz + b * 5.4), false)
	_b(root, Vector3(8, 0.6, 3.2), marble, Vector3(0, 0.9, kz + b * 5.6), false)
	# walls
	ghost.append(_b(root, Vector3(1.0, 11.0, 15.0), hall_wall, Vector3(-10.5, 5.5, kz)))
	ghost.append(_b(root, Vector3(1.0, 11.0, 15.0), hall_wall, Vector3(10.5, 5.5, kz)))
	ghost.append(_b(root, Vector3(22, 11.0, 1.0), hall_wall, Vector3(0, 5.5, kz + b * 7.0)))
	for sx in [-6.7, 6.7]:
		cut.append(_b(root, Vector3(8.6, 11.0, 1.0), hall_wall, Vector3(sx, 5.5, kz - b * 7.0)))
	cut.append(_b(root, Vector3(4.8, 6.0, 1.0), hall_wall, Vector3(0, 8.0, kz - b * 7.0)))
	for sx in [-2.5, 2.5]:
		_b(root, Vector3(0.4, 5.0, 1.3), dark, Vector3(sx, 2.5, kz - b * 7.0), false)
	_b(root, Vector3(5.4, 0.5, 1.3), dark, Vector3(0, 5.2, kz - b * 7.0), false)
	# ceiling + roof
	cut.append(_b(root, Vector3(22, 0.6, 15), dark, Vector3(0, 10.8, kz)))
	for i in 5:
		cut.append(_b(root, Vector3(22, 0.5, 0.6), wood, Vector3(0, 10.4, kz + b * (-6.0 + i * 3.0)), false))
	var kr := PrismMesh.new()
	kr.size = Vector3(23.5, 5.0, 16.5)
	cut.append(battle._mesh(root, kr, cloth, Vector3(0, 13.5, kz), Vector3.ZERO, true))
	# pillars + lamps
	for sx in [-6.0, 6.0]:
		for k in 3:
			var pz := kz + b * (-4.0 + k * 3.5)
			_c(root, 0.55, 0.65, 10.4, marble, Vector3(sx, 5.4, pz), 12)
			_c(root, 0.9, 0.9, 0.4, gold_m, Vector3(sx, 0.5, pz), 12)
			_c(root, 0.9, 0.9, 0.4, gold_m, Vector3(sx, 10.2, pz), 12)
	for sx in [-9.8, 9.8]:
		for k in 3:
			var wz := kz + b * (-4.0 + k * 4.0)
			_b(root, Vector3(0.3, 0.9, 0.3), lamp, Vector3(sx, 5.0, wz), false)
			# banner
			_b(root, Vector3(0.12, 3.6, 1.6), cloth, Vector3(sx * 0.99, 7.4, wz + b * 1.6), false)
	var hl := OmniLight3D.new()
	hl.light_color = Color(1.0, 0.8, 0.5)
	hl.light_energy = 2.2
	hl.omni_range = 20.0
	hl.position = Vector3(0, 8.0, kz)
	root.add_child(hl)
	# chandelier
	_c(root, 1.4, 1.4, 0.2, gold_m, Vector3(0, 8.6, kz), 14)
	for a in 6:
		var an := a * TAU / 6.0
		_b(root, Vector3(0.18, 0.5, 0.18), lamp, Vector3(cos(an) * 1.3, 8.9, kz + sin(an) * 1.3), false)
	# the throne
	var tz := kz + b * 5.8
	throne_pos[t] = Vector3(0.0, 0.0, 0.0)
	_b(root, Vector3(2.0, 0.7, 1.7), gold_m, Vector3(0, 1.55, tz), false)
	_b(root, Vector3(1.6, 0.25, 1.4), carpet, Vector3(0, 1.97, tz), false)
	_b(root, Vector3(2.2, 4.2, 0.45), gold_m, Vector3(0, 3.5, tz + b * 0.85))
	_b(root, Vector3(1.6, 3.4, 0.2), carpet, Vector3(0, 3.5, tz + b * 0.6), false)
	for sx in [-1.1, 1.1]:
		_b(root, Vector3(0.28, 1.0, 1.6), gold_m, Vector3(sx, 2.3, tz), false)
	for sx in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		battle._mesh(root, battle._cyl(0.0, 0.17, 0.6, 6), gold_m, Vector3(sx, 5.9, tz + b * 0.85), Vector3.ZERO, false)
	battle._mesh(root, battle._sph_mesh(0.22), _m(Color(0.9, 0.1, 0.15), 0.3, 0.2, 1.0), Vector3(0, 5.5, tz + b * 0.6), Vector3.ZERO, false)
	# royal standard behind the throne
	_b(root, Vector3(8.0, 6.0, 0.15), cloth, Vector3(0, 6.3, kz + b * 6.4), false)
	_b(root, Vector3(2.4, 2.4, 0.2), gold_m, Vector3(0, 6.3, kz + b * 6.3), false)
	# treasury: chests + gold piles on the left
	for k in 3:
		var cz := kz + b * (-3.5 + k * 3.2)
		_b(root, Vector3(1.8, 1.0, 1.2), wood, Vector3(-8.2, 0.8, cz))
		_b(root, Vector3(1.9, 0.35, 1.3), gold_m, Vector3(-8.2, 1.45, cz), false)
	var spots := [Vector3(-7.0, 0, -4.2), Vector3(-7.0, 0, -2.4), Vector3(-5.2, 0, -4.4), Vector3(-5.2, 0, -2.0), Vector3(-7.4, 0, 0.4), Vector3(-5.4, 0, 1.0), Vector3(-7.4, 0, 2.6), Vector3(-5.4, 0, 3.2), Vector3(-7.0, 0, 5.0), Vector3(-5.0, 0, 5.2)]
	for i in spots.size():
		var pile := Node3D.new()
		pile.position = Vector3(spots[i].x, 0.32, kz + b * spots[i].z)
		root.add_child(pile)
		var layers := 5
		for ly in layers:
			var cm: Mesh = battle._cyl(0.35 + (layers - ly) * 0.12, 0.45 + (layers - ly) * 0.14, 0.2, 10)
			battle._mesh(pile, cm, gold_m, Vector3(0, 0.1 + ly * 0.2, 0), Vector3.ZERO, false)
		pile.visible = false
		piles[t].append(pile)
	# crown stand + war table on the right
	_c(root, 0.5, 0.7, 1.6, marble, Vector3(7.6, 0.8, kz + b * 4.6), 10)
	_c(root, 0.45, 0.45, 0.35, gold_m, Vector3(7.6, 1.8, kz + b * 4.6), 12)
	for a in 5:
		var an2 := a * TAU / 5.0
		battle._mesh(root, battle._cyl(0.0, 0.1, 0.4, 5), gold_m, Vector3(7.6 + cos(an2) * 0.4, 2.15, kz + b * 4.6 + sin(an2) * 0.4), Vector3.ZERO, false)
	_b(root, Vector3(3.4, 0.9, 2.2), wood, Vector3(7.4, 0.55, kz - b * 1.6))
	_b(root, Vector3(3.0, 0.06, 1.8), _m(Color(0.85, 0.78, 0.55), 0.9), Vector3(7.4, 1.03, kz - b * 1.6), false)
	# sign boards above the entrance + back wall
	var bd := Label3D.new()
	bd.text = "THE ROYAL COURT"
	bd.font_size = 64
	bd.pixel_size = 0.012
	bd.outline_size = 14
	bd.modulate = Color(1.0, 0.88, 0.45)
	bd.position = Vector3(0, 9.3, kz - b * 7.6)
	bd.rotation.y = 0.0 if b < 0.0 else PI
	root.add_child(bd)
	var st := Label3D.new()
	st.font_size = 48
	st.pixel_size = 0.011
	st.outline_size = 12
	st.modulate = Color(1.0, 0.92, 0.7)
	st.position = Vector3(0, 8.2, kz + b * 6.3)
	st.rotation.y = PI if b > 0.0 else 0.0
	root.add_child(st)
	board[t] = st
	throne_pos[t] = Vector3(0.0, 0.0, 0.0)
	_set_throne_world(t, kz, b)


func _set_throne_world(t: int, kz: float, b: float) -> void:
	# world position of the spot in front of the throne
	var root: Node3D = battle.castle_roots[t]
	throne_pos[t] = root.to_global(Vector3(0, 0, kz + b * 2.2))


func hall_pos(t: int) -> Vector3:
	return kingdom.lw(t, Vector3(0, 0, -111.5))


func in_hall(t: int, p: Vector3) -> bool:
	var l: Vector3 = kingdom.wl(t, p)
	var d: float = -l.z
	return d > 104.0 and d < 119.0 and absf(l.x) < 10.2


func refresh_hall(t: int) -> void:
	var g: float = kingdom.gold[t]
	var th := [30.0, 80.0, 150.0, 250.0, 400.0, 600.0, 900.0, 1300.0, 1800.0, 2500.0]
	for i in piles[t].size():
		piles[t][i].visible = g >= float(th[i])
	if board[t] != null and t == kingdom.my_team:
		var tt := "KING %s" % kingdom.king_name(t)
		var txt := "%s\n%s\n%s\n%s" % [LocS.t(tt), LocS.t("Rank: %s" % LocS.t(kingdom.rank_of(t))), LocS.t("Treasury: %d gold" % int(g)), LocS.t("Villagers: %d   Soldiers: %d" % [kingdom.vill_n[t], kingdom.soldier_n[t]])]
		board[t].text = txt
	elif board[t] != null:
		board[t].text = ""


func _puppet(kind: String, t: int, pos: Vector3):
	var u = UnitS.new()
	u.uid = -1
	u.position = pos
	battle.add_child(u)
	u.setup(kind, t, -500, battle)
	u.puppet = true
	u.tpos = pos
	u.rotation.y = kingdom.ang(t)
	u.tyaw = u.rotation.y
	return u


# ================================================================== townsfolk + NPCs
func _folk_target(t: int) -> int:
	return clampi(4 + 2 * kingdom.count_slots(t, 1), 4, 26)


func _sync_folk(t: int) -> void:
	var want := _folk_target(t)
	while folk[t].size() < want:
		var p: Vector3 = kingdom.lw(t, Vector3(rng.randf_range(-24.0, 24.0), 0, -rng.randf_range(80.0, 112.0)))
		var f = _puppet("villager", t, p)
		folk[t].append(f)
		folk_state[t].append({"wait": rng.randf_range(0.0, 3.0), "to": p})


func sync() -> void:
	for t in kingdom.nk:
		_sync_folk(t)


func _make_npcs() -> void:
	var t: int = kingdom.my_team
	var defs := {"messenger": [-5.0, "MESSENGER"], "advisor": [5.0, "ADVISOR"]}
	for k in defs.keys():
		var p: Vector3 = kingdom.lw(t, Vector3(defs[k][0], 0, -92.0))
		var u = _puppet("villager", t, p)
		u.tyaw = u.rotation.y
		npcs[k] = u
		var lb := Label3D.new()
		lb.text = defs[k][1]
		lb.font_size = 54
		lb.pixel_size = 0.0007
		lb.fixed_size = true
		lb.visibility_range_end = 22.0
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
	board_t -= dt
	if board_t <= 0.0:
		board_t = 0.5
		for t in kingdom.nk:
			refresh_hall(t)
	var hh = battle.heroes.get(battle.my_id)
	var now_in: bool = hh != null and is_instance_valid(hh) and not hh.dead and in_hall(kingdom.my_team, hh.position)
	if now_in != inside_keep:
		inside_keep = now_in
		var mt: int = kingdom.my_team
		for n in shell[mt]:
			n.visible = not now_in
		for n in shell_ghost[mt]:
			n.transparency = 0.8 if now_in else 0.0
	# gates swing open / closed
	for t in kingdom.nk:
		var open: bool = kingdom.gate_open[t]
		if open != gate_prev[t]:
			gate_prev[t] = open
			var gp: Vector3 = kingdom.lw(t, Vector3(0, 3, -73.0))
			battle.sfx.play("thud", gp, -2.0, 0.55)
		gate_amt[t] = move_toward(gate_amt[t], 1.0 if open else 0.0, dt * 1.4)
		var a: float = deg_to_rad(100.0) * gate_amt[t]
		if gate_l[t] != null:
			gate_l[t].rotation.y = a
			gate_r[t].rotation.y = -a
	# townsfolk wander inside the walls
	for t in kingdom.nk:
		if kingdom.fallen[t]:
			continue
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
				var tz := -rng.randf_range(80.5, 117.0)
				if rng.randf() < 0.45:
					tx = rng.randf_range(-9.0, 9.0)
					tz = -rng.randf_range(80.5, 100.0)
				st.to = kingdom.lw(t, Vector3(tx, 0, tz))
			else:
				var step := d.normalized() * 1.6 * dt
				f.tpos += step
				f.tyaw = atan2(d.x, d.z)
