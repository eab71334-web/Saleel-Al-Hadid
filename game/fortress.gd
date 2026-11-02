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
var flag_segs := []     # [node, phase] waving banner pieces
var flag_t := 0.0


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
	var CKit = load("res://game/castlekit.gd")
	var CC: Dictionary = CKit.merged(load("res://game/profile.gd").castle) if t == battle.my_team else CKit.DEF
	var stone := _m(CKit.WALL[int(CC.wall)], 0.95)
	var stone_d := _m(CKit.WALL[int(CC.wall)].darkened(0.24), 0.95)
	if t == battle.my_team and int(CC.banner) > 0:
		tc = CKit.BANNER[int(CC.banner)]
	var cloth := _m(tc, 0.8, 0.0, 0.5)
	var gold_m := _m(Color(1.0, 0.78, 0.25), 0.9, 0.25, 0.3)
	var wood := _m(Color(0.32, 0.2, 0.1), 0.9)
	var cobble := _m(Color(0.5, 0.46, 0.4), 1.0)
	var road := _m(Color(0.5, 0.4, 0.28), 1.0)
	var roofm := _m(CKit.ROOF[int(CC.roof)], 0.85)
	var flame := _m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0)

	# side + rear walls
	for sx in [-36.0, 36.0]:
		_b(root, Vector3(3, 9, 48), stone, Vector3(sx, 4.5, b * 24.0))
		for i in 12:
			_b(root, Vector3(3.3, 1.6, 2.2), stone, Vector3(sx, 9.8, b * (2.0 + i * 4.0)), false)
	# rear wall with a postern gate (the way to the fields, forest and mines behind the castle)
	_b(root, Vector3(9.6, 9, 3), stone, Vector3(-31.2, 4.5, b * 48.0))
	_b(root, Vector3(57.6, 9, 3), stone, Vector3(7.2, 4.5, b * 48.0))
	_b(root, Vector3(5.6, 2.2, 3), stone_d, Vector3(-24.0, 7.9, b * 48.0))
	for i in 18:
		if i == 2 or i == 3:
			continue
		_b(root, Vector3(2.2, 1.6, 3.3), stone, Vector3(-34 + i * 4.0, 9.8, b * 48.0), false)
	var post_door := _b(root, Vector3(4.8, 5.6, 0.5), wood, Vector3(-24.0, 2.8, b * 48.0), false)
	for tx in [-26.8, -21.2]:
		_b(root, Vector3(0.9, 6.4, 3.4), stone_d, Vector3(tx, 3.2, b * 48.0))
	# wall walk + two stairways (soldiers and ballistas climb them)
	var wy: float = 6.8
	var plank_m := _m(Color(0.5, 0.36, 0.2), 0.9)
	for sg in [-1.0, 1.0]:
		var wb := BoxMesh.new()
		wb.size = Vector3(28.0, 0.5, 4.2)
		battle._mesh(root, wb, plank_m, Vector3(sg * 20.0, wy - 0.25, b * 3.7), Vector3.ZERO, true)
		for px in [-8.0, 0.0, 8.0]:
			_b(root, Vector3(0.6, wy - 0.5, 0.6), wood, Vector3(sg * 20.0 + px, (wy - 0.5) * 0.5, b * 5.6), false)
		var ang_r := atan2(wy, 20.0)
		var rl := sqrt(20.0 * 20.0 + wy * wy)
		var rb := BoxMesh.new()
		rb.size = Vector3(3.6, 0.3, rl)
		battle._mesh(root, rb, plank_m, Vector3(sg * 12.0, wy * 0.5 - 0.15, b * 14.0), Vector3(ang_r * b, 0, 0), true)
		for i in 15:
			var f2 := float(i) / 14.0
			var sb := BoxMesh.new()
			sb.size = Vector3(3.6, 0.14, 0.3)
			battle._mesh(root, sb, wood, Vector3(sg * 12.0, wy * (1.0 - f2) + 0.02, b * (4.0 + 20.0 * f2)), Vector3.ZERO, false)
		for rx in [-1.9, 1.9]:
			var rr := BoxMesh.new()
			rr.size = Vector3(0.12, 0.12, rl)
			battle._mesh(root, rr, wood, Vector3(sg * 12.0 + rx, wy * 0.5 + 0.9, b * 14.0), Vector3(ang_r * b, 0, 0), false)
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
	var yard: Node3D = null
	if battle.sea:
		yard = Node3D.new()
		yard.visible = false
		root.add_child(yard)
		var plank := _m(Color(0.6, 0.43, 0.24), 0.9)
		var tile := _m(Color(0.55, 0.2, 0.14), 0.85)
		# warehouse by the shore, rear of the castle
		var yz: float = battle.coast_r - battle.ring_r - 7.0
		_b(yard, Vector3(13, 5, 7), wood, Vector3(0, 2.5, b * yz))
		var roofp := PrismMesh.new()
		roofp.size = Vector3(14.5, 3.2, 8.0)
		battle._mesh(yard, roofp, tile, Vector3(0, 6.6, b * yz), Vector3.ZERO, true)
		_b(yard, Vector3(4.0, 3.6, 0.3), _m(Color(0.2, 0.12, 0.07)), Vector3(0, 1.8, b * (yz + 3.6)))
		_b(yard, Vector3(5.0, 0.3, 3.0), plank, Vector3(7.5, 0.3, b * (yz + 1.0)))
		# pier into the water, with mooring posts
		for pz in 4:
			_b(yard, Vector3(5.0, 0.35, 5.0), plank, Vector3(0, 0.45, b * (yz + 5.0 + pz * 5.0)), false)
		for pz2 in 5:
			for sx in [-2.6, 2.6]:
				_c(yard, 0.22, 0.22, 2.0, wood, Vector3(sx, 0.3, b * (yz + 4.0 + pz2 * 4.5)), 6)
		for ix in [-1.0, 1.0]:
			_b(yard, Vector3(0.2, 3.4, 0.2), wood, Vector3(ix * 6.0, 2.0, b * (yz + 1.5)))
		_b(yard, Vector3(12.4, 0.5, 0.3), cloth, Vector3(0, 3.8, b * (yz + 3.7)))
	_detail_fort(t, root, b, stone, stone_d, cloth, gold_m, wood)
	kingdom.extras[t] = {"l2": l2, "l3": l3, "yard": yard, "post": post_door}
	var fire_pos := [Vector3(-36, 17, 0), Vector3(33, 11, 0), Vector3(2, 10, b * 38.0)]
	for fp in fire_pos:
		kingdom.fires[t].append(kingdom._make_fire(root, fp))

	# gate guards (decoration)
	for sx in [-7.5, 7.5]:
		var g = _puppet("sword", t, kingdom.lw(t, Vector3(sx, 0, -70.0)))
		g.tyaw = kingdom.ang(t)
		guards.append(g)


func _flag(parent: Node3D, pos: Vector3, w: float, h: float, col: Material, trim: Material, phase := 0.0, emblem := true) -> void:
	# a hanging banner made of 5 chained cloth strips that sway in the wind
	var pole := _b(parent, Vector3(0.14, h * 1.25, 0.14), trim, pos + Vector3(0, h * 0.1, 0), false)
	var segs := 5
	var sw := w / segs
	var prev: Node3D = parent
	var at := pos + Vector3(0.07, h * 0.4, 0)
	for i in segs:
		var s := Node3D.new()
		prev.add_child(s)
		s.position = at if i == 0 else Vector3(sw, 0, 0)
		_b(s, Vector3(sw, h * (1.0 - i * 0.06), 0.05), col, Vector3(sw * 0.5, 0, 0), false)
		if i == 1 and emblem:
			_b(s, Vector3(sw * 0.7, sw * 0.7, 0.07), trim, Vector3(sw * 0.5, 0.0, 0), false)
		flag_segs.append([s, phase + i * 0.55])
		prev = s
	_b(parent, Vector3(0.5, 0.5, 0.5), trim, pos + Vector3(0, h * 0.75, 0), false)


func _detail_fort(t: int, root: Node3D, b: float, stone: Material, stone_d: Material, cloth: Material, gold_m: Material, wood: Material) -> void:
	var stone_l := _m(Color(0.66, 0.64, 0.6), 0.95)
	var slit := _m(Color(0.04, 0.03, 0.03), 1.0)
	var moss := _m(Color(0.3, 0.38, 0.24), 1.0)
	var cloth_d := _m(battle.team_col(t).darkened(0.45), 0.8)
	# side walls: plinth, courses, arrow slits, buttresses, corbels under the parapet
	for sx in [-36.0, 36.0]:
		var o := signf(sx)
		_b(root, Vector3(4.6, 1.6, 49.0), stone_d, Vector3(sx, 0.8, b * 24.0))
		for k in 3:
			_b(root, Vector3(3.15, 0.18, 48.6), stone_d, Vector3(sx, 2.4 + k * 2.1, b * 24.0), false)
		for i in 7:
			var z := 5.0 + i * 6.5
			_b(root, Vector3(0.3, 1.5, 0.35), slit, Vector3(sx + o * 1.52, 5.0, b * z), false)
			_b(root, Vector3(0.3, 0.35, 1.0), slit, Vector3(sx + o * 1.52, 5.5, b * z), false)
		for i in 5:
			var z2 := 8.0 + i * 9.0
			_b(root, Vector3(2.0, 8.0, 2.4), stone_l, Vector3(sx + o * 2.0, 4.0, b * z2))
			_b(root, Vector3(2.2, 0.8, 2.6), stone_d, Vector3(sx + o * 2.0, 8.2, b * z2), false)
		for i in 24:
			_b(root, Vector3(0.6, 0.7, 0.8), stone_d, Vector3(sx + o * 1.7, 8.4, b * (1.0 + i * 2.0)), false)
		for i in 5:
			_b(root, Vector3(0.18, 1.5, 4.0), moss, Vector3(sx + o * 1.52, 1.2 + (i % 2) * 0.6, b * (6.0 + i * 8.5)), false)
		# banners down the outer face
		for i in 3:
			var bz := 10.0 + i * 14.0
			_b(root, Vector3(0.1, 4.6, 2.2), cloth, Vector3(sx + o * 1.58, 5.4, b * bz), false)
			_b(root, Vector3(0.12, 0.35, 2.4), gold_m, Vector3(sx + o * 1.6, 7.8, b * bz), false)
			_b(root, Vector3(0.14, 1.0, 1.0), gold_m, Vector3(sx + o * 1.62, 5.6, b * bz), false)
			battle._mesh(root, battle._cyl(0.0, 1.1, 1.0, 3), cloth_d, Vector3(sx + o * 1.58, 2.6, b * bz), Vector3(0, 0, PI), false)
	# towers: stone bands, arrow slits, corbelled lookout ring, gold finial, waving banner
	var tw := [[Vector3(-36, 0, b * 48.0), 4.6, 16.0, 19.0], [Vector3(36, 0, b * 48.0), 4.6, 16.0, 19.0], [Vector3(-36, 0, b * 24.0), 3.6, 13.0, 15.5], [Vector3(36, 0, b * 24.0), 3.6, 13.0, 15.5]]
	var idx := 0
	for tdef in tw:
		var p: Vector3 = tdef[0]
		var r: float = tdef[1]
		var h: float = tdef[2]
		var roof_y: float = tdef[3]
		for k in 3:
			_c(root, r + 0.2, r + 0.2, 0.3, stone_d, Vector3(p.x, 1.0 + k * (h / 3.2), p.z), 16)
		_c(root, r + 0.9, r + 0.5, 1.0, stone_d, Vector3(p.x, h - 0.2, p.z), 16)
		for ang in 8:
			var a := float(ang) / 8.0 * TAU
			_b(root, Vector3(0.8, 1.2, 0.8), stone, Vector3(p.x + cos(a) * (r + 0.8), h + 0.7, p.z + sin(a) * (r + 0.8)), false)
		for ang in 6:
			var a2 := float(ang) / 6.0 * TAU + 0.5
			_b(root, Vector3(0.3, 1.6, 0.3), slit, Vector3(p.x + cos(a2) * (r + 0.02), h * 0.55, p.z + sin(a2) * (r + 0.02)), false)
		# roof bands
		battle._mesh(root, battle._sph_mesh(0.7), gold_m, Vector3(p.x, roof_y + 6.4, p.z), Vector3.ZERO, false)
		_c(root, r * 0.98, r * 1.04, 0.35, gold_m, Vector3(p.x, roof_y - 0.3, p.z), 16)
		_flag(root, Vector3(p.x, roof_y + 8.2, p.z), 3.4, 1.8, cloth, gold_m, float(idx) * 1.3)
		idx += 1
	# gatehouse: lintel with crest, portcullis spikes, hanging banners and braziers
	_b(root, Vector3(13.6, 1.4, 4.2), stone_d, Vector3(0, 9.9, 0))
	_b(root, Vector3(13.7, 0.16, 4.3), gold_m, Vector3(0, 10.62, 0), false)
	_b(root, Vector3(3.4, 3.4, 0.4), cloth, Vector3(0, 12.5, 2.0 * b * -1.0), false)
	_b(root, Vector3(1.4, 2.2, 0.5), gold_m, Vector3(0, 12.5, 2.05 * b * -1.0), false)
	_b(root, Vector3(2.4, 0.7, 0.5), gold_m, Vector3(0, 13.4, 2.05 * b * -1.0), false)
	for sx in [-4.2, -2.8, -1.4, 0.0, 1.4, 2.8, 4.2]:
		battle._mesh(root, battle._cyl(0.0, 0.22, 1.1, 6), _m(Color(0.25, 0.25, 0.28), 0.4, 0.7), Vector3(sx, 8.4, 0.0), Vector3(PI, 0, 0), false)
	for sx in [-9.2, 9.2]:
		_b(root, Vector3(0.7, 0.5, 0.7), _m(Color(0.2, 0.2, 0.22), 0.5, 0.6), Vector3(sx, 2.3, b * -1.5 * -1.0))
		battle._mesh(root, battle._cyl(0.0, 0.5, 0.9, 8), _m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0), Vector3(sx, 3.0, b * 1.5), Vector3.ZERO, false)
	# courtyard dressing: crates, barrels, hay, weapon racks, a training dummy
	var barrel := _m(Color(0.4, 0.26, 0.13), 0.9)
	var hay := _m(Color(0.85, 0.72, 0.3), 1.0)
	for i in 6:
		var sx2 := -30.0 + i * 3.2
		_c(root, 0.55, 0.62, 1.1, barrel, Vector3(sx2, 0.55, b * 44.5), 10)
		_b(root, Vector3(0.9, 0.8, 0.9), wood, Vector3(sx2 + 1.4, 0.4, b * 45.0), false)
	for i in 3:
		_b(root, Vector3(1.6, 1.2, 1.2), hay, Vector3(26.0 + i * 1.8, 0.6, b * 44.0), false)
	for sx3 in [-27.0, 27.0]:
		_b(root, Vector3(0.2, 2.2, 0.2), wood, Vector3(sx3 - 1.0, 1.1, b * 9.0), false)
		_b(root, Vector3(0.2, 2.2, 0.2), wood, Vector3(sx3 + 1.0, 1.1, b * 9.0), false)
		_b(root, Vector3(2.2, 0.15, 0.3), wood, Vector3(sx3, 1.6, b * 9.0), false)
		for k in 4:
			_b(root, Vector3(0.06, 2.0, 0.06), _m(Color(0.7, 0.72, 0.78), 0.3, 0.9), Vector3(sx3 - 0.75 + k * 0.5, 1.9, b * 9.0), false)
	var dum := Vector3(-20.0, 0, b * 12.0)
	_b(root, Vector3(0.18, 1.8, 0.18), wood, dum + Vector3(0, 0.9, 0), false)
	_b(root, Vector3(1.0, 0.16, 0.16), wood, dum + Vector3(0, 1.5, 0), false)
	battle._mesh(root, battle._sph_mesh(0.28), hay, dum + Vector3(0, 2.0, 0), Vector3.ZERO, false)
	_b(root, Vector3(0.7, 0.8, 0.3), hay, dum + Vector3(0, 1.1, 0), false)
	_yard_zones(t, root, b, stone, stone_d, cloth, gold_m, wood)


# ================================================================== castle zones + hall dressing
func _checker() -> StandardMaterial3D:
	var img := Image.create(7, 5, false, Image.FORMAT_RGB8)
	for y in 5:
		for x in 7:
			img.set_pixel(x, y, Color(0.88, 0.85, 0.78) if (x + y) % 2 == 0 else Color(0.42, 0.38, 0.34))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.45
	return m


func _armor(parent: Node3D, pos: Vector3, yaw: float, tc: Color) -> void:
	var steel := _m(Color(0.66, 0.69, 0.76), 0.35, 0.8)
	var dk := _m(Color(0.22, 0.2, 0.22), 0.6, 0.5)
	var cl := _m(tc, 0.8)
	var gd := _m(Color(1.0, 0.78, 0.25), 0.3, 0.9)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	_b(n, Vector3(1.3, 0.3, 1.3), dk, Vector3(0, 0.15, 0), false)
	for sx in [-0.25, 0.25]:
		_b(n, Vector3(0.36, 1.1, 0.34), steel, Vector3(sx, 0.85, 0), false)
		_b(n, Vector3(0.38, 0.3, 0.55), dk, Vector3(sx, 0.45, 0.08), false)
	_b(n, Vector3(0.95, 1.05, 0.55), steel, Vector3(0, 1.95, 0), false)
	_b(n, Vector3(0.7, 0.9, 0.06), cl, Vector3(0, 1.85, 0.3), false)
	_b(n, Vector3(0.95, 0.14, 0.58), gd, Vector3(0, 1.45, 0), false)
	_b(n, Vector3(0.58, 0.58, 0.58), steel, Vector3(0, 2.8, 0), false)
	_b(n, Vector3(0.5, 0.08, 0.1), dk, Vector3(0, 2.8, 0.3), false)
	_b(n, Vector3(0.1, 0.4, 0.5), cl, Vector3(0, 3.2, -0.05), false)
	for sx2 in [-0.62, 0.62]:
		_b(n, Vector3(0.36, 0.36, 0.4), steel, Vector3(sx2, 2.35, 0), false)
		_b(n, Vector3(0.26, 0.9, 0.26), steel, Vector3(sx2, 1.8, 0), false)
	_b(n, Vector3(0.07, 4.2, 0.07), _m(Color(0.4, 0.28, 0.14), 0.9), Vector3(0.7, 2.1, 0.2), false)
	_b(n, Vector3(0.2, 0.5, 0.06), steel, Vector3(0.7, 4.3, 0.2), false)
	_b(n, Vector3(0.12, 0.8, 0.8), cl, Vector3(-0.78, 1.9, 0.1), false)
	_b(n, Vector3(0.14, 0.12, 0.84), gd, Vector3(-0.78, 2.35, 0.1), false)


func _hall_extras(t: int, root: Node3D, b: float, kz: float, tc: Color, marble: Material, gold_m: Material, wood: Material, cloth: Material, dark: Material, lamp: Material) -> void:
	var glass_b := _m(Color(0.25, 0.45, 0.9), 0.3, 0.0, 1.6)
	var glass_g := _m(Color(1.0, 0.75, 0.25), 0.3, 0.0, 1.6)
	var glass_r := _m(Color(0.85, 0.2, 0.25), 0.3, 0.0, 1.4)
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.albedo_color = Color(1.0, 0.92, 0.65, 0.10)
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	# gold-bordered rug with a medallion
	_b(root, Vector3(4.9, 0.12, 14.2), gold_m, Vector3(0, 0.3, kz), false)
	_b(root, Vector3(4.4, 0.14, 13.8), _m(tc.darkened(0.3), 0.95), Vector3(0, 0.31, kz), false)
	for k in 5:
		_c(root, 0.9 - k * 0.12, 0.9 - k * 0.12, 0.05, gold_m if k % 2 == 0 else _m(tc.darkened(0.1), 0.9), Vector3(0, 0.4 + k * 0.01, kz - b * 1.0), 20)
	for k2 in 4:
		_b(root, Vector3(0.5, 0.05, 0.5), gold_m, Vector3(0, 0.41, kz + b * (2.0 + k2 * 1.2)), false).rotation.y = PI * 0.25
	# stained-glass windows with soft light shafts
	for sx in [-9.95, 9.95]:
		var o := signf(sx)
		for k3 in 3:
			var wz := kz + b * (-4.0 + k3 * 4.0)
			_b(root, Vector3(0.3, 6.4, 2.6), dark, Vector3(sx, 5.8, wz), false)
			var gm: Material = [glass_b, glass_g, glass_r][k3]
			_b(root, Vector3(0.2, 5.6, 2.0), gm, Vector3(sx - o * 0.06, 5.8, wz), false)
			battle._mesh(root, battle._cyl(1.0, 1.0, 0.2, 14), gm, Vector3(sx - o * 0.06, 8.7, wz), Vector3(0, 0, PI * 0.5), false)
			_b(root, Vector3(0.24, 5.6, 0.14), dark, Vector3(sx - o * 0.08, 5.8, wz), false)
			_b(root, Vector3(0.24, 0.14, 2.0), dark, Vector3(sx - o * 0.08, 6.2, wz), false)
			var sh := _b(root, Vector3(0.05, 8.0, 1.8), beam, Vector3(sx - o * 2.6, 4.2, wz), false)
			sh.rotation.z = o * 0.55
	# armour statues between the windows, guards flank the carpet
	for sx2 in [-9.0, 9.0]:
		for k4 in 2:
			_armor(root, Vector3(sx2, 0.3, kz + b * (-2.0 + k4 * 4.0)), PI * 0.5 * -signf(sx2), tc)
	# hanging banners on the pillars
	for sx3 in [-6.0, 6.0]:
		for k5 in 3:
			var pz := kz + b * (-4.0 + k5 * 3.5)
			_b(root, Vector3(1.0, 4.6, 0.08), cloth, Vector3(sx3 * 0.82, 7.4, pz), false)
			_b(root, Vector3(1.1, 0.2, 0.12), gold_m, Vector3(sx3 * 0.82, 9.8, pz), false)
			battle._mesh(root, battle._cyl(0.0, 0.55, 0.9, 3), _m(tc.darkened(0.3), 0.8), Vector3(sx3 * 0.82, 4.55, pz), Vector3(0, 0, PI), false)
	# braziers on the dais and at the entrance
	for pos in [Vector3(-4.8, 0, 5.2), Vector3(4.8, 0, 5.2), Vector3(-2.8, 0, -6.2), Vector3(2.8, 0, -6.2)]:
		_c(root, 0.5, 0.3, 1.4, _m(Color(0.2, 0.2, 0.22), 0.4, 0.7), Vector3(pos.x, 1.0, kz + b * pos.z), 10)
		_c(root, 0.6, 0.5, 0.3, gold_m, Vector3(pos.x, 1.8, kz + b * pos.z), 10)
		battle._mesh(root, battle._cyl(0.0, 0.42, 0.9, 7), _m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0), Vector3(pos.x, 2.3, kz + b * pos.z), Vector3.ZERO, false)
	# royal crest over the throne: shield with crossed swords
	_b(root, Vector3(1.5, 1.9, 0.2), _m(Color(0.7, 0.72, 0.8), 0.4, 0.7), Vector3(0, 9.7, kz + b * 6.3), false)
	_b(root, Vector3(1.2, 1.6, 0.24), _m(tc, 0.7), Vector3(0, 9.7, kz + b * 6.2), false)
	for sg in [-1.0, 1.0]:
		_b(root, Vector3(0.1, 2.4, 0.1), _m(Color(0.85, 0.87, 0.92), 0.3, 0.9), Vector3(0, 9.7, kz + b * 6.1), false).rotation.z = sg * 0.7
	# library wall: bookshelves on the right, a scribe desk with a candle
	for k6 in 2:
		var bz := kz + b * (2.5 + k6 * 2.4)
		_b(root, Vector3(1.0, 4.0, 2.2), wood, Vector3(9.5, 2.0, bz), false)
		for r in 4:
			for c in 6:
				_b(root, Vector3(0.7, 0.7, 0.26), _m(Color.from_hsv(float((r * 6 + c + k6 * 5) % 9) / 9.0, 0.55, 0.65), 0.9), Vector3(9.3, 0.6 + r * 0.95, bz - 0.95 + c * 0.38), false)
	_b(root, Vector3(2.0, 0.9, 1.0), wood, Vector3(7.0, 0.75, kz + b * 1.0), false)
	_b(root, Vector3(0.9, 0.06, 0.6), _m(Color(0.9, 0.85, 0.65), 0.9), Vector3(7.0, 1.23, kz + b * 1.0), false)
	_c(root, 0.07, 0.07, 0.35, _m(Color(0.95, 0.9, 0.8), 0.9), Vector3(7.5, 1.45, kz + b * 1.0), 6)
	battle._mesh(root, battle._sph_mesh(0.07), lamp, Vector3(7.5, 1.7, kz + b * 1.0), Vector3.ZERO, false)
	# dais gets a third step and gold trim
	_b(root, Vector3(13.0, 0.3, 5.2), marble, Vector3(0, 0.3, kz + b * 5.0), false)
	_b(root, Vector3(13.2, 0.08, 0.2), gold_m, Vector3(0, 0.46, kz + b * 2.5), false)
	# royal guards (puppets) stand along the carpet
	var gpos := [Vector3(-3.0, 0.3, -3.2), Vector3(3.0, 0.3, -3.2), Vector3(-3.0, 0.3, 1.0), Vector3(3.0, 0.3, 1.0), Vector3(-2.2, 1.0, 5.2), Vector3(2.2, 1.0, 5.2)]
	for gp in gpos:
		var wp: Vector3 = kingdom.lw(t, Vector3(gp.x, gp.y, -73.0 + kz + b * gp.z))
		var g = _puppet("sword", t, wp)
		g.tyaw = kingdom.ang(t) + (PI * 0.5 if gp.x < 0.0 else -PI * 0.5)
		g.rotation.y = g.tyaw
		guards.append(g)


func _yard_zones(t: int, root: Node3D, b: float, stone: Material, stone_d: Material, cloth: Material, gold_m: Material, wood: Material) -> void:
	var tc: Color = battle.team_col(t)
	var curb := _m(Color(0.62, 0.6, 0.56), 0.95)
	var hedge := _m(Color(0.2, 0.42, 0.2), 1.0)
	var flower_r := _m(Color(0.85, 0.2, 0.25), 0.9)
	var flower_y := _m(Color(0.95, 0.8, 0.25), 0.9)
	var flame := _m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 4.0)
	var steel := _m(Color(0.7, 0.72, 0.78), 0.35, 0.8)
	var dark := _m(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	var sign_m := _m(Color(0.26, 0.17, 0.09), 0.9)
	# road curbs and lanterns along the main avenue
	for sx in [-3.7, 3.7]:
		_b(root, Vector3(0.35, 0.3, 40.0), curb, Vector3(sx, 0.2, b * 22.0), false)
	for z in [8.0, 16.0, 26.0, 34.0]:
		for sx2 in [-4.4, 4.4]:
			_b(root, Vector3(0.16, 2.2, 0.16), dark, Vector3(sx2, 1.1, b * z), false)
			_b(root, Vector3(0.4, 0.5, 0.4), flame, Vector3(sx2, 2.4, b * z), false)
			_b(root, Vector3(0.5, 0.1, 0.5), dark, Vector3(sx2, 2.72, b * z), false)
	# plaza ring, hedges and flower beds around the well
	for k in 12:
		var a := float(k) / 12.0 * TAU
		_b(root, Vector3(1.5, 0.22, 0.9), curb, Vector3(sin(a) * 6.6, 0.15, b * 19.0 + cos(a) * 6.6), false).rotation.y = a
	for sg in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bx: float = sg * 8.2
			var bz: float = b * 19.0 + sz * 7.2
			_b(root, Vector3(3.0, 0.7, 1.0), hedge, Vector3(bx, 0.35, bz), false)
			for fk in 4:
				_b(root, Vector3(0.3, 0.3, 0.3), flower_r if (fk + int(sg)) % 2 == 0 else flower_y, Vector3(bx - 1.0 + fk * 0.66, 0.85, bz), false)
	# benches
	for sg2 in [-1.0, 1.0]:
		_b(root, Vector3(2.0, 0.18, 0.6), wood, Vector3(sg2 * 5.2, 0.55, b * 25.5), false)
		_b(root, Vector3(0.14, 0.5, 0.5), wood, Vector3(sg2 * 5.2 - 0.8, 0.3, b * 25.5), false)
		_b(root, Vector3(0.14, 0.5, 0.5), wood, Vector3(sg2 * 5.2 + 0.8, 0.3, b * 25.5), false)
	# keep entrance: wide steps, portal, flanking armour
	for s in 4:
		_b(root, Vector3(9.0 - s * 0.6, 0.3, 1.2), curb, Vector3(0, 0.15 + s * 0.3, b * (30.6 - s * 1.0)), false)
	_b(root, Vector3(1.4, 7.0, 1.4), stone_d, Vector3(-3.4, 3.5, b * 31.0), false)
	_b(root, Vector3(1.4, 7.0, 1.4), stone_d, Vector3(3.4, 3.5, b * 31.0), false)
	_b(root, Vector3(8.2, 1.0, 1.6), stone_d, Vector3(0, 7.2, b * 31.0), false)
	_b(root, Vector3(8.4, 0.14, 1.7), gold_m, Vector3(0, 7.8, b * 31.0), false)
	for sx3 in [-6.4, 6.4]:
		_armor(root, Vector3(sx3, 0.3, b * 29.5), PI if b < 0.0 else 0.0, tc)
	# training yard (left): archery butts + dummies + sign
	var ty := 14.0
	for k2 in 3:
		var tz := b * (ty + k2 * 4.0)
		_b(root, Vector3(0.18, 2.4, 0.18), wood, Vector3(-30.0, 1.2, tz), false)
		_b(root, Vector3(0.2, 0.2, 0.2), wood, Vector3(-30.0, 2.4, tz), false)
		battle._mesh(root, battle._cyl(1.0, 1.0, 0.16, 18), _m(Color(0.9, 0.85, 0.7), 0.9), Vector3(-29.8, 1.7, tz), Vector3(0, 0, PI * 0.5), false)
		battle._mesh(root, battle._cyl(0.66, 0.66, 0.18, 18), flower_r, Vector3(-29.75, 1.7, tz), Vector3(0, 0, PI * 0.5), false)
		battle._mesh(root, battle._cyl(0.3, 0.3, 0.2, 14), _m(Color(0.95, 0.9, 0.7), 0.9), Vector3(-29.7, 1.7, tz), Vector3(0, 0, PI * 0.5), false)
	_b(root, Vector3(0.14, 1.6, 2.0), sign_m, Vector3(-27.0, 2.6, b * 11.0), false)
	var l1 := Label3D.new()
	l1.text = LocS.t("TRAINING YARD")
	l1.font_size = 40
	l1.pixel_size = 0.014
	l1.outline_size = 10
	l1.modulate = Color(1, 0.9, 0.55)
	l1.position = Vector3(-27.1, 2.6, b * 11.0)
	l1.rotation.y = PI * 0.5
	root.add_child(l1)
	# forge corner (right): anvil, glowing furnace, quench barrel, sign
	var fx := 27.0
	var fz := b * 15.0
	_b(root, Vector3(3.2, 2.4, 2.2), stone_d, Vector3(fx, 1.2, fz))
	_b(root, Vector3(1.6, 1.0, 0.3), _m(Color(1.0, 0.45, 0.1), 0.5, 0.0, 3.5), Vector3(fx - 1.62, 1.0, fz), false)
	_b(root, Vector3(0.9, 3.4, 0.9), stone, Vector3(fx, 3.9, fz + b * 0.4), false)
	_b(root, Vector3(1.2, 0.6, 0.8), dark, Vector3(fx - 3.5, 0.8, fz + 1.8), false)
	_b(root, Vector3(1.6, 0.25, 0.7), dark, Vector3(fx - 3.5, 1.2, fz + 1.8), false)
	_c(root, 0.6, 0.7, 1.0, wood, Vector3(fx - 3.2, 0.5, fz - 1.6), 10)
	var l2 := Label3D.new()
	l2.text = LocS.t("FORGE")
	l2.font_size = 40
	l2.pixel_size = 0.014
	l2.outline_size = 10
	l2.modulate = Color(1, 0.8, 0.5)
	l2.position = Vector3(fx - 1.6, 3.2, fz + 1.3)
	l2.rotation.y = -PI * 0.5
	root.add_child(l2)
	# stables (left rear): fenced paddock, hay, trough, sign
	var sz0 := b * 36.0
	for sx4 in [-33.0, -27.0, -21.0]:
		_b(root, Vector3(0.2, 1.4, 0.2), wood, Vector3(sx4, 0.7, sz0 - 3.0 * b), false)
		_b(root, Vector3(0.2, 1.4, 0.2), wood, Vector3(sx4, 0.7, sz0 + 3.0 * b), false)
	for yy in [0.5, 1.1]:
		_b(root, Vector3(12.0, 0.12, 0.12), wood, Vector3(-27.0, yy, sz0 - 3.0 * b), false)
		_b(root, Vector3(12.0, 0.12, 0.12), wood, Vector3(-27.0, yy, sz0 + 3.0 * b), false)
		_b(root, Vector3(0.12, 0.12, 6.0), wood, Vector3(-21.0, yy, sz0), false)
	_b(root, Vector3(3.0, 0.5, 0.8), wood, Vector3(-30.0, 0.35, sz0), false)
	_b(root, Vector3(2.6, 0.12, 0.6), _m(Color(0.3, 0.5, 0.8), 0.2, 0.0, 0.3), Vector3(-30.0, 0.62, sz0), false)
	var l3 := Label3D.new()
	l3.text = LocS.t("STABLES")
	l3.font_size = 40
	l3.pixel_size = 0.014
	l3.outline_size = 10
	l3.modulate = Color(1, 0.9, 0.55)
	l3.position = Vector3(-27.0, 2.2, sz0 - 3.0 * b)
	l3.rotation.y = 0.0 if b < 0.0 else PI
	root.add_child(l3)


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
	_b(root, Vector3(21, 0.3, 15), _checker(), Vector3(0, 0.15, kz), false)
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
	bd.text = LocS.t("THE ROYAL COURT")
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
	_hall_extras(t, root, b, kz, tc, marble, gold_m, wood, cloth, dark, lamp)
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
	var defs := {"messenger": [-5.0, "MESSENGER", -92.0], "advisor": [5.0, "ADVISOR", -92.0], "steward": [15.0, "STEWARD", -88.0]}
	for k in defs.keys():
		var p: Vector3 = kingdom.lw(t, Vector3(defs[k][0], 0, defs[k][2]))
		var u = _puppet("villager", t, p)
		u.set_role(k)
		u.tyaw = u.rotation.y
		npcs[k] = u
		var lb := Label3D.new()
		lb.text = LocS.t(String(defs[k][1]))
		lb.font_size = 54
		lb.pixel_size = 0.0007
		lb.fixed_size = true
		lb.visibility_range_end = 22.0
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.outline_size = 14
		lb.modulate = Color(1.0, 0.9, 0.5)
		lb.position = Vector3(0, 2.9 if k == "advisor" else 2.6, 0)
		u.add_child(lb)


func npc_near(kind: String, p: Vector3, r := 5.5) -> bool:
	var u = npcs.get(kind)
	return u != null and is_instance_valid(u) and Vector2(u.position.x - p.x, u.position.z - p.z).length() < r


# ================================================================== per-frame
func _process(dt: float) -> void:
	if kingdom == null or battle == null:
		return
	flag_t += dt
	for fs in flag_segs:
		fs[0].rotation.y = sin(flag_t * 3.2 + float(fs[1])) * 0.28
		fs[0].rotation.z = sin(flag_t * 2.1 + float(fs[1]) * 1.3) * 0.05
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
