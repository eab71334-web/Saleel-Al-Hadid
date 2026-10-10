extends Node
# Kingdom mode: build a city, feed it, train soldiers, write letters, declare war,
# siege the enemy castle, and settle it in a duel of kings.
# Host-authoritative: the host simulates everything, clients get a small state
# dictionary 4 times a second plus a few reliable events.

const PLOT_LX := [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]
const PLOT_LD := [10.0, 19.0]
const NSLOTS := 12
const HOUSE_ORDER := [2, 3, 1, 4, 0, 5, 8, 9, 7, 10, 6, 11]
const BARRACKS_ORDER := [0, 5, 6, 11, 1, 4, 7, 10]

const START_GOLD := 120.0
const START_FOOD := 80.0
const HOUSE_COST := 80
const BARRACKS_COST := 150
const VILLAGER_FOOD := 20
const BUY_GOLD := 30
const BUY_FOOD := 40
const BASE_CAP := 4
const HOUSE_CAP := 4
const TREE_MAX := 80.0
const TREES_PER_TEAM := 12
const CASTLE_HP := [2500.0, 3600.0, 5200.0]
const UPGRADE := [[150, 60], [320, 140]]
const SLOT_LIMIT := [6, 9, 12]
# kind: [gold, food, seconds, castle level needed]
const TRAIN := {"sword": [30, 20, 4.0, 1], "archer": [40, 25, 5.0, 2], "cav": [90, 50, 7.0, 3]}
const SIEGE_MULT := 0.2
const FOOD_UPKEEP := 0.08
const LETTER_CD := 10.0
const MSG_SPEED := 15.0
const TOWER_RANGE := 30.0
const TOWER_DMG := 11.0
const DUEL_TRIGGER := 20.0
const DUEL_R0 := 9.5
const DUEL_R1 := 3.5
const DUEL_SHRINK := 45.0
const KING_RESPAWN := 15.0

var battle
var net
var is_srv := true
var my_team := 0

var gold := [START_GOLD, START_GOLD]
var food := [START_FOOD, START_FOOD]
var level := [1, 1]
var slots := [[], []]
var castle_hp := [CASTLE_HP[0], CASTLE_HP[0]]
var fallen := [false, false]
var tree_pos := [[], []]
var tree_food := [[], []]
var pop_used := [0, 0]
var vill_n := [0, 0]
var soldier_n := [0, 0]
var queue := [[], []]
var letter_cd := [0.0, 0.0]

var plot_type := [[], []]
var plot_nodes := [[], []]
var plot_marks := [[], []]
var tree_nodes := [[], []]
var extras := [{}, {}]
var fires := [[], []]
var vis_ready := false

var msgs := {}
var next_msg := 1
var duel_t := 0.0
var duel_done := false
var duel_ring: MeshInstance3D = null
var respawn := {}
var ai_next := [0.0, 0.0]
var ai_info := [{}, {}]
var ai_replies := []
var inbox := []
var tower_cd := 1.0
var econ_t := 0.0
var state_t := 0.0
var ui_t := 0.0
var war_confirm := 0.0

var ui := {}


# ================================================================== helpers
func dz_of(t: int) -> float:
	return 1.0 if t == 0 else -1.0


func team_of(owner: int) -> int:
	if owner < 0:
		return -100 - owner
	var p: Dictionary = net.players.get(owner, {"idx": 0})
	return int(p.idx) % 2


func owner_of_team(t: int) -> int:
	for id in net.players.keys():
		if team_of(id) == t:
			return id
	return -100 - t


func king_name(t: int) -> String:
	for id in net.players.keys():
		if team_of(id) == t:
			return String(net.players[id].name)
	return "King of %s (AI)" % ("Blue" if t == 0 else "Red")


func plot_pos(t: int, i: int) -> Vector3:
	var lx: float = PLOT_LX[i % 6]
	var ld: float = PLOT_LD[i / 6]
	return Vector3(lx, 0.0, dz_of(t) * (-71.5 + ld))


func depot(t: int) -> Vector3:
	return Vector3(0.0, 0.0, dz_of(t) * -67.0)


func castle_gate(t: int) -> Vector3:
	return Vector3(0.0, 0.0, dz_of(t) * -70.0)


func castle_alive(t: int) -> bool:
	return not fallen[t] and castle_hp[t] > 0.0


func count_slots(t: int, typ: int) -> int:
	var n := 0
	for v in slots[t]:
		if int(v) == typ:
			n += 1
	return n


func used_slots(t: int) -> int:
	return NSLOTS - count_slots(t, 0)


func pop_cap(t: int) -> int:
	return BASE_CAP + HOUSE_CAP * count_slots(t, 1)


func free_slot(t: int, order: Array) -> int:
	if used_slots(t) >= SLOT_LIMIT[level[t] - 1]:
		return -1
	for i in order:
		if int(slots[t][i]) == 0:
			return i
	return -1


func queued(t: int, kind: String) -> int:
	var n := 0
	for q in queue[t]:
		if q.kind == kind:
			n += 1
	return n


func has_arabic(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0600 and c <= 0x06FF:
			return true
	return false


# ================================================================== setup
func setup() -> void:
	net = battle.net
	is_srv = battle.is_srv
	my_team = battle.my_team
	for t in 2:
		var a := []
		a.resize(NSLOTS)
		a.fill(0)
		slots[t] = a
		var b := []
		b.resize(NSLOTS)
		b.fill(0)
		plot_type[t] = b
		var c := []
		c.resize(NSLOTS)
		c.fill(null)
		plot_nodes[t] = c
		var d := []
		d.resize(NSLOTS)
		d.fill(null)
		plot_marks[t] = d
		slots[t][2] = 1
		slots[t][3] = 1
	_make_trees()
	_make_plot_marks()
	_make_extras()
	_refresh_visuals()
	vis_ready = true
	_build_ui()


func _make_plot_marks() -> void:
	var dirt: StandardMaterial3D = battle._mat(Color(0.33, 0.25, 0.15), 1.0)
	var bm: BoxMesh = battle._box(Vector3(5.2, 0.06, 4.4))
	for t in 2:
		for i in NSLOTS:
			var m: MeshInstance3D = battle._mesh(battle, bm, dirt, plot_pos(t, i) + Vector3(0, 0.03, 0), Vector3.ZERO, false)
			plot_marks[t][i] = m


func _make_trees() -> void:
	var trunk: StandardMaterial3D = battle._mat(Color(0.32, 0.21, 0.11))
	var leaf: StandardMaterial3D = battle._mat(Color(0.17, 0.42, 0.14))
	var fruit_mat: StandardMaterial3D = battle._mat(Color(0.95, 0.3, 0.12), 0.5, 0.0, 0.6)
	var tm: CylinderMesh = battle._cyl(0.25, 0.38, 2.2, 8)
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 3.0
	sm.radial_segments = 12
	sm.rings = 6
	var fm := SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.4
	fm.radial_segments = 6
	fm.rings = 3
	for t in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + t
		for i in TREES_PER_TEAM:
			var side := -1.0 if i % 2 == 0 else 1.0
			var x := side * rng.randf_range(46.0, 68.0)
			var ld := rng.randf_range(6.0, 36.0)
			var p := Vector3(x, 0.0, dz_of(t) * (-71.5 + ld))
			tree_pos[t].append(p)
			tree_food[t].append(TREE_MAX)
			var root := Node3D.new()
			root.position = p
			battle.add_child(root)
			battle._mesh(root, tm, trunk, Vector3(0, 1.1, 0), Vector3.ZERO, false)
			battle._mesh(root, sm, leaf, Vector3(0, 3.5, 0), Vector3.ZERO, true)
			var fr := Node3D.new()
			root.add_child(fr)
			for k in 9:
				var a := float(k) / 9.0 * TAU + rng.randf() * 0.5
				battle._mesh(fr, fm, fruit_mat, Vector3(cos(a) * 1.45, 3.2 + rng.randf_range(-0.7, 0.8), sin(a) * 1.45), Vector3.ZERO, false)
			tree_nodes[t].append(fr)


func _make_extras() -> void:
	var stone: StandardMaterial3D = battle._mat(Color(0.58, 0.56, 0.53), 0.95)
	var gold_m: StandardMaterial3D = battle._mat(Color(1.0, 0.78, 0.25), 0.9, 0.25, 0.3)
	for t in 2:
		var root: Node3D = battle.castle_roots[t]
		var tc := Color(0.12, 0.32, 0.95) if t == 0 else Color(0.9, 0.12, 0.1)
		var cloth: StandardMaterial3D = battle._mat(tc, 0.8, 0.0, 0.5)
		var l2 := Node3D.new()
		l2.visible = false
		root.add_child(l2)
		battle._mesh(l2, battle._cyl(7.0, 7.4, 11.0, 20), stone, Vector3(0, 14.5, 0))
		battle._mesh(l2, battle._cyl(0.0, 8.6, 8.0, 20), cloth, Vector3(0, 24.0, 0))
		battle._mesh(l2, battle._box(Vector3(0.25, 6.0, 0.25)), stone, Vector3(0, 31.0, 0), Vector3.ZERO, false)
		battle._mesh(l2, battle._box(Vector3(4.0, 2.4, 0.12)), cloth, Vector3(2.1, 32.0, 0), Vector3.ZERO, false)
		var l3 := Node3D.new()
		l3.visible = false
		root.add_child(l3)
		for sx in [-18.0, 18.0]:
			battle._mesh(l3, battle._cyl(3.2, 3.4, 12.0, 14), stone, Vector3(sx, 15.0, 0))
			battle._mesh(l3, battle._cyl(0.0, 4.2, 5.0, 14), gold_m, Vector3(sx, 23.5, 0))
		battle._mesh(l3, battle._sph_mesh(1.1), gold_m, Vector3(0, 35.4, 0), Vector3.ZERO, false)
		extras[t] = {"l2": l2, "l3": l3}
		# damage fires and smoke
		var fire_pos := [Vector3(-36, 17, 0), Vector3(33, 11, 0), Vector3(2, 10, 1)]
		for fp in fire_pos:
			fires[t].append(_make_fire(root, fp))


func _make_fire(parent: Node3D, p: Vector3) -> Dictionary:
	var fire := CPUParticles3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3.ONE * 0.5
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.5, 0.1)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.1)
	fmat.emission_energy_multiplier = 3.0
	fm.material = fmat
	fire.mesh = fm
	fire.amount = 14
	fire.lifetime = 1.0
	fire.direction = Vector3.UP
	fire.spread = 25.0
	fire.initial_velocity_min = 2.0
	fire.initial_velocity_max = 4.0
	fire.gravity = Vector3(0, 1.0, 0)
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 1.6
	fire.position = p
	fire.emitting = false
	parent.add_child(fire)
	var smoke := CPUParticles3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE * 1.2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.15, 0.15, 0.16, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	smoke.mesh = sm
	smoke.amount = 10
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 2.5
	smoke.initial_velocity_max = 4.5
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.4
	smoke.position = p + Vector3(0, 1.5, 0)
	smoke.emitting = false
	parent.add_child(smoke)
	return {"fire": fire, "smoke": smoke}


# ================================================================== buildings
func _make_house(t: int) -> Node3D:
	var n := Node3D.new()
	var wall: StandardMaterial3D = battle._mat(Color(0.86, 0.79, 0.62), 0.95)
	var roofc := Color(0.2, 0.34, 0.72) if t == 0 else Color(0.72, 0.2, 0.17)
	var roof: StandardMaterial3D = battle._mat(roofc, 0.8)
	var dark: StandardMaterial3D = battle._mat(Color(0.25, 0.16, 0.09), 0.9)
	var glow: StandardMaterial3D = battle._mat(Color(1.0, 0.8, 0.4), 0.5, 0.0, 2.0)
	var stone: StandardMaterial3D = battle._mat(Color(0.5, 0.48, 0.45), 0.95)
	battle._mesh(n, battle._box(Vector3(5.0, 2.8, 4.2)), wall, Vector3(0, 1.4, 0), Vector3.ZERO, true)
	var pm := PrismMesh.new()
	pm.size = Vector3(5.7, 1.9, 4.8)
	battle._mesh(n, pm, roof, Vector3(0, 3.75, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(0.9, 1.7, 0.1)), dark, Vector3(0, 0.85, 2.11), Vector3.ZERO, false)
	for sx in [-1.6, 1.6]:
		battle._mesh(n, battle._box(Vector3(0.7, 0.7, 0.1)), glow, Vector3(sx, 1.7, 2.11), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.55, 1.3, 0.55)), stone, Vector3(1.7, 3.9, -1.1), Vector3.ZERO, false)
	return n


func _make_barracks(t: int) -> Node3D:
	var n := Node3D.new()
	var tc := Color(0.12, 0.32, 0.95) if t == 0 else Color(0.9, 0.12, 0.1)
	var wall: StandardMaterial3D = battle._mat(Color(0.38, 0.27, 0.19), 0.95)
	var roof: StandardMaterial3D = battle._mat(Color(0.2, 0.17, 0.16), 0.85)
	var dark: StandardMaterial3D = battle._mat(Color(0.14, 0.09, 0.06), 0.9)
	var steel: StandardMaterial3D = battle._mat(Color(0.75, 0.77, 0.82), 0.9, 0.3)
	var cloth: StandardMaterial3D = battle._mat(tc, 0.8, 0.0, 0.7)
	battle._mesh(n, battle._box(Vector3(8.0, 3.6, 6.0)), wall, Vector3(0, 1.8, 0), Vector3.ZERO, true)
	var pm := PrismMesh.new()
	pm.size = Vector3(8.8, 2.4, 6.8)
	battle._mesh(n, pm, roof, Vector3(0, 4.8, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(2.4, 2.6, 0.12)), dark, Vector3(0, 1.3, 3.02), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.18, 7.0, 0.18)), dark, Vector3(-3.7, 3.5, 3.3), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(2.0, 1.3, 0.08)), cloth, Vector3(-2.7, 6.2, 3.3), Vector3.ZERO, false)
	for k in 3:
		battle._mesh(n, battle._box(Vector3(0.08, 2.2, 0.08)), steel, Vector3(2.4 + k * 0.5, 1.3, 3.1), Vector3(0, 0, 0.12 * (k - 1)), false)
	return n


func _set_plot(t: int, i: int, typ: int, animate: bool) -> void:
	var old = plot_nodes[t][i]
	if old != null and is_instance_valid(old):
		old.queue_free()
	plot_nodes[t][i] = null
	plot_type[t][i] = typ
	var mark = plot_marks[t][i]
	if mark != null:
		mark.visible = typ == 0
	if typ == 0:
		return
	var n: Node3D = _make_house(t) if typ == 1 else _make_barracks(t)
	n.position = plot_pos(t, i)
	n.rotation.y = 0.0 if t == 0 else PI
	battle.add_child(n)
	plot_nodes[t][i] = n
	if animate:
		n.scale = Vector3(1.0, 0.02, 1.0)
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector3.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		battle._burst(n.position + Vector3(0, 1.0, 0), Color(0.62, 0.5, 0.38), 18, 4.5, false)
		battle.sfx.play("hammer", n.position, 0.0)


func _refresh_visuals() -> void:
	for t in 2:
		for i in NSLOTS:
			var want: int = int(slots[t][i])
			if want != int(plot_type[t][i]):
				_set_plot(t, i, want, vis_ready)
		for i in tree_nodes[t].size():
			var fr: Node3D = tree_nodes[t][i]
			var r: float = clampf(float(tree_food[t][i]) / TREE_MAX, 0.0, 1.0)
			fr.visible = r > 0.12
			fr.scale = Vector3.ONE * (0.55 + 0.45 * r)
		var ex: Dictionary = extras[t]
		if not ex.is_empty():
			var was2: bool = ex.l2.visible
			ex.l2.visible = level[t] >= 2
			ex.l3.visible = level[t] >= 3
			if vis_ready and ex.l2.visible and not was2:
				battle._burst(Vector3(0, 14, -73.0 * dz_of(t)), Color(1, 0.9, 0.5), 30, 8.0, true)
		var maxhp: float = CASTLE_HP[level[t] - 1]
		var ratio: float = castle_hp[t] / maxhp
		for k in fires[t].size():
			var on: bool = ratio < (0.7 - 0.2 * k) and not fallen[t] or (fallen[t] and k < 2)
			fires[t][k].fire.emitting = on
			fires[t][k].smoke.emitting = on


# ================================================================== state sync
func _state() -> Dictionary:
	var tf0 := []
	var tf1 := []
	for v in tree_food[0]:
		tf0.append(int(v))
	for v in tree_food[1]:
		tf1.append(int(v))
	return {
		"w": battle.war, "g": [int(gold[0]), int(gold[1])], "f": [int(food[0]), int(food[1])],
		"l": [level[0], level[1]], "s": [slots[0], slots[1]],
		"h": [int(castle_hp[0]), int(castle_hp[1])], "tf": [tf0, tf1],
		"pu": [pop_used[0], pop_used[1]], "vn": [vill_n[0], vill_n[1]], "sn": [soldier_n[0], soldier_n[1]],
		"q": [queue[0].size(), queue[1].size()], "fl": [fallen[0], fallen[1]],
	}


func _apply_state(s: Dictionary) -> void:
	battle.war = bool(s.w)
	gold = [float(s.g[0]), float(s.g[1])]
	food = [float(s.f[0]), float(s.f[1])]
	level = [int(s.l[0]), int(s.l[1])]
	slots = [s.s[0].duplicate(), s.s[1].duplicate()]
	castle_hp = [float(s.h[0]), float(s.h[1])]
	for t in 2:
		for i in tree_food[t].size():
			tree_food[t][i] = float(s.tf[t][i])
	pop_used = [int(s.pu[0]), int(s.pu[1])]
	vill_n = [int(s.vn[0]), int(s.vn[1])]
	soldier_n = [int(s.sn[0]), int(s.sn[1])]
	var q0: int = int(s.q[0])
	var q1: int = int(s.q[1])
	queue = [_fake_q(q0), _fake_q(q1)]
	fallen = [bool(s.fl[0]), bool(s.fl[1])]
	_refresh_visuals()


func _fake_q(n: int) -> Array:
	var a := []
	for i in n:
		a.append({"kind": "?", "t": 1.0, "owner": 0})
	return a


@rpc("authority", "reliable")
func state_msg(s: Dictionary) -> void:
	if is_srv:
		return
	_apply_state(s)


@rpc("authority", "reliable")
func ev_msg(kind: String, data: Dictionary) -> void:
	if is_srv:
		return
	_ev(kind, data)


@rpc("any_peer", "reliable")
func cmd_msg(act: String, data: Dictionary) -> void:
	if not is_srv:
		return
	_cmd(multiplayer.get_remote_sender_id(), act, data)


func ev_all(kind: String, data: Dictionary) -> void:
	_ev(kind, data)
	if net.online:
		ev_msg.rpc(kind, data)


func cmd(act: String, data := {}) -> void:
	if battle.over:
		return
	if is_srv:
		_cmd(battle.my_id, act, data)
	else:
		cmd_msg.rpc_id(1, act, data)


func toast_team(t: int, text: String) -> void:
	ev_all("toast", {"team": t, "text": text})


# ================================================================== commands (host)
func _cmd(owner: int, act: String, data: Dictionary) -> void:
	if battle.over or not battle.running:
		return
	var t := team_of(owner)
	var human := owner >= 0
	match act:
		"villager":
			if food[t] < VILLAGER_FOOD:
				if human: toast_team(t, "Not enough food!")
				return
			if pop_used[t] >= pop_cap(t):
				if human: toast_team(t, "Build more houses first!")
				return
			if queue[t].size() >= 8:
				return
			food[t] -= VILLAGER_FOOD
			queue[t].append({"kind": "villager", "t": 3.0, "owner": owner})
		"house":
			if gold[t] < HOUSE_COST:
				if human: toast_team(t, "Not enough gold!")
				return
			var i := free_slot(t, HOUSE_ORDER)
			if i < 0:
				if human: toast_team(t, "No free land - upgrade your castle!")
				return
			gold[t] -= HOUSE_COST
			slots[t][i] = 1
			battle.sfx.play_ui("coin", -6.0) if t == my_team else null
		"barracks":
			var maxb := 1 if level[t] < 3 else 2
			if count_slots(t, 2) >= maxb:
				if human: toast_team(t, "Barracks limit reached" + ("" if level[t] >= 3 else " (upgrade castle for another)"))
				return
			if gold[t] < BARRACKS_COST:
				if human: toast_team(t, "Not enough gold!")
				return
			var j := free_slot(t, BARRACKS_ORDER)
			if j < 0:
				if human: toast_team(t, "No free land - upgrade your castle!")
				return
			gold[t] -= BARRACKS_COST
			slots[t][j] = 2
		"upgrade":
			if level[t] >= 3:
				return
			var cost: Array = UPGRADE[level[t] - 1]
			if gold[t] < cost[0] or food[t] < cost[1]:
				if human: toast_team(t, "Need %d gold and %d food" % [cost[0], cost[1]])
				return
			gold[t] -= cost[0]
			food[t] -= cost[1]
			var oldmax: float = CASTLE_HP[level[t] - 1]
			level[t] += 1
			castle_hp[t] += CASTLE_HP[level[t] - 1] - oldmax
			ev_all("level", {"team": t, "lvl": level[t]})
		"buyfood":
			if gold[t] < BUY_GOLD:
				if human: toast_team(t, "Not enough gold!")
				return
			gold[t] -= BUY_GOLD
			food[t] += BUY_FOOD
		"train":
			var kind: String = String(data.get("kind", "sword"))
			if not TRAIN.has(kind):
				return
			var info: Array = TRAIN[kind]
			if level[t] < info[3]:
				if human: toast_team(t, "Castle level %d needed" % info[3])
				return
			if count_slots(t, 2) < 1:
				if human: toast_team(t, "Build a barracks first!")
				return
			if gold[t] < info[0] or food[t] < info[1]:
				if human: toast_team(t, "Need %d gold and %d food" % [info[0], info[1]])
				return
			if pop_used[t] >= pop_cap(t):
				if human: toast_team(t, "Build more houses first!")
				return
			if queue[t].size() >= 8:
				return
			gold[t] -= info[0]
			food[t] -= info[1]
			queue[t].append({"kind": kind, "t": info[2], "owner": owner})
		"letter":
			var text: String = String(data.get("text", "")).strip_edges()
			if text.is_empty():
				return
			if letter_cd[t] > 0.0:
				if human: toast_team(t, "Your messenger is still preparing (%ds)" % ceili(letter_cd[t]))
				return
			letter_cd[t] = LETTER_CD
			_send_letter(t, text.substr(0, 240), owner)
		"war":
			if battle.war or fallen[0] or fallen[1]:
				return
			battle.war = true
			battle.war_t0 = battle.game_time
			ev_all("war", {"by": t})
	state_t = 0.0


func _send_letter(from_t: int, text: String, owner: int) -> void:
	var id := next_msg
	next_msg += 1
	var dist := absf(depot(0).z - depot(1).z)
	msgs[id] = {"from": from_t, "t": 0.0, "dur": dist / MSG_SPEED, "text": text, "owner": owner, "node": null}
	ev_all("msg_spawn", {"id": id, "from": from_t})
	if owner >= 0:
		toast_team(from_t, "Messenger sent!")


# ================================================================== events (all peers)
func _ev(kind: String, d: Dictionary) -> void:
	match kind:
		"toast":
			var tt: int = int(d.team)
			if tt == -1 or tt == my_team:
				battle._toast(String(d.text), 2.6)
		"level":
			var t: int = int(d.team)
			battle.sfx.play("horn", Vector3(0, 10, -73.0 * dz_of(t)), 2.0)
			if t == my_team:
				battle.banner("CASTLE LEVEL %d" % int(d.lvl), Color(1.0, 0.85, 0.3), 1.6)
		"war":
			var by: int = int(d.by)
			battle.war = true
			battle.war_t0 = battle.game_time
			battle.sfx.play_ui("horn", 2.0)
			var mine_declared := by == my_team
			battle.banner("WAR!" if mine_declared else "%s DECLARES WAR!" % king_name(by).to_upper(), Color(1.0, 0.25, 0.2), 3.0)
			var enemy_c := Vector3(0, 6, 73.0 * dz_of(my_team))
			battle.cine_orbit(Vector3(0, 6, -73.0 * dz_of(1 - my_team)) if not mine_declared else Vector3(0, 6, -73.0 * dz_of(1 - my_team)), 70.0, 28.0, 4.0, 0.7)
		"msg_spawn":
			_vis_msg_spawn(int(d.id), int(d.from))
		"msg_end":
			_vis_msg_end(int(d.id), bool(d.ok))
		"letter":
			if int(d.to) == my_team:
				battle.sfx.play_ui("bell")
				_show_reader(String(d.name), String(d.text))
		"duel_start":
			_duel_visual_start(Vector3(d.c))
		"duel_end":
			_duel_visual_end()
		"castle_fall":
			_castle_fall_visual(int(d.team))
		"king_down":
			if int(d.team) == my_team:
				battle._toast("Your king has fallen! He will return soon...", 3.0)
			else:
				battle._toast("The enemy king has fallen!", 3.0)


func _castle_fall_visual(t: int) -> void:
	var root: Node3D = battle.castle_roots[t]
	var dz := dz_of(t)
	var cz := -73.0 * dz
	battle.cine_orbit(Vector3(0, 6, cz), 48.0, 24.0, 6.5, 1.1)
	battle._slowmo(0.45, 3.5)
	battle.banner("THE CASTLE FALLS!", Color(1.0, 0.6, 0.2), 3.5)
	var tw := create_tween()
	tw.tween_property(root, "scale:y", 0.1, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(root, "rotation:x", 0.07 * dz, 3.0)
	for i in 14:
		var tm := get_tree().create_timer(0.2 + i * 0.22)
		tm.timeout.connect(func():
			var p := Vector3(randf_range(-34.0, 34.0), randf_range(2.0, 12.0), cz)
			battle._burst(p, Color(0.5, 0.46, 0.4), 22, 7.0, false)
			battle.sfx.play("thud", p, 6.0, 0.7)
			battle.shake = minf(battle.shake + 0.25, 0.7))
	for k in fires[t].size():
		fires[t][k].fire.emitting = true
		fires[t][k].smoke.emitting = true


# ================================================================== messengers
func _msg_point(from_t: int, p: float) -> Vector3:
	var z0: float = depot(from_t).z
	var z1: float = depot(1 - from_t).z
	var z := lerpf(z0, z1, p)
	var lane := 14.0 * sin(p * PI) * (1.0 if from_t == 0 else -1.0)
	return Vector3(lane, 0.0, z)


func _make_rider(t: int) -> Node3D:
	var n := Node3D.new()
	var tc := Color(0.12, 0.32, 0.95) if t == 0 else Color(0.9, 0.12, 0.1)
	var hm: StandardMaterial3D = battle._mat(Color(0.55, 0.38, 0.22), 0.0, 0.8)
	var dark: StandardMaterial3D = battle._mat(Color(0.12, 0.08, 0.05), 0.0, 0.9)
	var cloth: StandardMaterial3D = battle._mat(tc, 0.0, 0.8, 0.4)
	var skin: StandardMaterial3D = battle._mat(Color(0.86, 0.66, 0.52), 0.0, 0.9)
	var paper: StandardMaterial3D = battle._mat(Color(0.96, 0.92, 0.8), 0.0, 0.9, 0.5)
	var wax: StandardMaterial3D = battle._mat(Color(0.7, 0.1, 0.1), 0.0, 0.6, 0.8)
	battle._mesh(n, battle._box(Vector3(0.6, 0.65, 1.6)), hm, Vector3(0, 1.0, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(0.28, 0.7, 0.3)), hm, Vector3(0, 1.45, 0.8), Vector3(-0.5, 0, 0), false)
	battle._mesh(n, battle._box(Vector3(0.24, 0.26, 0.55)), hm, Vector3(0, 1.75, 1.15), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.08, 0.7, 0.1)), dark, Vector3(0, 0.95, -0.88), Vector3.ZERO, false)
	for sx in [-0.2, 0.2]:
		for sz in [0.6, -0.6]:
			battle._mesh(n, battle._box(Vector3(0.14, 0.7, 0.14)), hm, Vector3(sx, 0.35, sz), Vector3.ZERO, false)
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 0.95
	battle._mesh(n, cap, cloth, Vector3(0, 1.75, -0.05), Vector3.ZERO, true)
	var hd := SphereMesh.new()
	hd.radius = 0.17
	hd.height = 0.34
	battle._mesh(n, hd, skin, Vector3(0, 2.35, -0.02), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.42, 0.1, 0.42)), cloth, Vector3(0, 2.52, -0.02), Vector3.ZERO, false)
	# the scroll, held out in front
	var sc := CylinderMesh.new()
	sc.top_radius = 0.07
	sc.bottom_radius = 0.07
	sc.height = 0.6
	sc.radial_segments = 8
	battle._mesh(n, sc, paper, Vector3(0.3, 1.9, 0.35), Vector3(PI / 2.0, 0, 0.0), false)
	battle._mesh(n, battle._sph_mesh(0.08), wax, Vector3(0.3, 1.9, 0.55), Vector3.ZERO, false)
	# dust
	var pr := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.22
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.66, 0.55, 0.4, 0.7)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	pr.mesh = bm
	pr.amount = 14
	pr.lifetime = 0.9
	pr.direction = Vector3(0, 0.6, -1)
	pr.spread = 30.0
	pr.initial_velocity_min = 1.0
	pr.initial_velocity_max = 3.0
	pr.gravity = Vector3(0, -1.0, 0)
	pr.position = Vector3(0, 0.2, -1.0)
	n.add_child(pr)
	pr.emitting = true
	return n


func _vis_msg_spawn(id: int, from_t: int) -> void:
	var node := _make_rider(from_t)
	battle.add_child(node)
	node.position = _msg_point(from_t, 0.0)
	var m: Dictionary
	if msgs.has(id):
		m = msgs[id]
	else:
		var dist := absf(depot(0).z - depot(1).z)
		m = {"from": from_t, "t": 0.0, "dur": dist / MSG_SPEED, "text": "", "owner": 0}
		msgs[id] = m
	m["node"] = node
	battle.sfx.play("horn", node.position, -6.0, 1.6)


func _vis_msg_end(id: int, ok: bool) -> void:
	if not msgs.has(id):
		return
	var m: Dictionary = msgs[id]
	var node = m.get("node")
	if node != null and is_instance_valid(node):
		battle._burst(node.position + Vector3(0, 1.5, 0), Color(0.95, 0.9, 0.7) if ok else Color(0.8, 0.2, 0.2), 16, 4.0, true)
		node.queue_free()
	msgs.erase(id)


func _tick_messengers(dt: float) -> void:
	var done := []
	for id in msgs.keys():
		var m: Dictionary = msgs[id]
		m.t += dt
		var p: float = clampf(m.t / m.dur, 0.0, 1.0)
		var node = m.get("node")
		if node != null and is_instance_valid(node):
			var a := _msg_point(m.from, p)
			var b := _msg_point(m.from, minf(p + 0.02, 1.0))
			node.position = a + Vector3(0, absf(sin(m.t * 9.0)) * 0.22, 0)
			if b.distance_to(a) > 0.01:
				node.rotation.y = atan2(b.x - a.x, b.z - a.z)
		if is_srv:
			if p >= 1.0:
				done.append([id, true])
			elif battle.war:
				var pos := _msg_point(m.from, p)
				for e in battle.by_team[1 - int(m.from)]:
					if e.dead or e.kind == "villager":
						continue
					if Vector2(e.position.x - pos.x, e.position.z - pos.z).length() < 3.0:
						done.append([id, false])
						break
	for pair in done:
		var id: int = pair[0]
		if not msgs.has(id):
			continue
		var m: Dictionary = msgs[id]
		var ok: bool = pair[1]
		var from_t: int = int(m.from)
		var text: String = String(m.text)
		var owner: int = int(m.owner)
		ev_all("msg_end", {"id": id, "ok": ok})
		if ok:
			ev_all("letter", {"to": 1 - from_t, "from": from_t, "name": king_name(from_t), "text": text})
			_ai_read_letter(1 - from_t, from_t, text)
			if owner >= 0:
				toast_team(from_t, "Your letter was delivered.")
		else:
			toast_team(-1, "A messenger was cut down on the road!")


# ================================================================== host simulation
func _physics_process(dt: float) -> void:
	if not is_srv or not battle.running or battle.over:
		return
	for t in 2:
		letter_cd[t] = maxf(0.0, letter_cd[t] - dt)
	econ_t += dt
	if econ_t >= 0.25:
		var step := econ_t
		econ_t = 0.0
		_econ(step)
	_tower_tick(dt)
	_tick_duel(dt)
	_tick_respawn(dt)
	for r in ai_replies:
		r.t -= dt
	while not ai_replies.is_empty() and ai_replies[0].t <= 0.0:
		var r: Dictionary = ai_replies.pop_front()
		_send_letter(int(r.team), String(r.text), -100 - int(r.team))
	for t in battle.ai_teams:
		ai_next[t] -= dt
		if ai_next[t] <= 0.0:
			ai_next[t] = 1.5
			_ai_tick(t)
	state_t -= dt
	if state_t <= 0.0:
		state_t = 0.25
		var s := _state()
		_refresh_visuals()
		if net.online:
			state_msg.rpc(s)


func _econ(dt: float) -> void:
	var vn := [0, 0]
	var sn := [0, 0]
	for u in battle.units.values():
		if u.dead:
			continue
		if u.kind == "villager":
			vn[u.team] += 1
		elif u.kind != "hero":
			sn[u.team] += 1
	vill_n = vn
	soldier_n = sn
	for t in 2:
		var houses := count_slots(t, 1)
		gold[t] += (houses * 0.5 + vn[t] * 0.1) * dt
		# everybody eats
		food[t] = maxf(0.0, food[t] - float(vn[t] + sn[t]) * FOOD_UPKEEP * dt)
		pop_used[t] = vn[t] + sn[t] + queue[t].size()
		# trees regrow
		for i in tree_food[t].size():
			tree_food[t][i] = minf(TREE_MAX, float(tree_food[t][i]) + 0.4 * dt)
		# training (up to 3 at once)
		var q: Array = queue[t]
		var k := 0
		while k < mini(3, q.size()):
			q[k].t -= dt
			if q[k].t <= 0.0:
				var item: Dictionary = q.pop_at(k)
				_spawn_trained(t, item)
			else:
				k += 1


func _spawn_trained(t: int, item: Dictionary) -> void:
	var kind: String = item.kind
	var owner: int = item.owner
	var dz := dz_of(t)
	if kind == "villager":
		var p := depot(t) + Vector3(randf_range(-3.0, 3.0), 0, 0)
		battle._make_unit("villager", t, owner, p)
		return
	var bpos := depot(t)
	for i in NSLOTS:
		if int(slots[t][i]) == 2:
			bpos = plot_pos(t, i) + Vector3(0, 0, dz * 5.0)
			break
	var u = battle._make_unit(kind, t, owner, bpos + Vector3(randf_range(-1.5, 1.5), 0, 0))
	var n := 0
	for o in battle.units.values():
		if o != u and not o.dead and o.team == t and o.kind == kind:
			n += 1
	if kind == "sword":
		u.slot = Vector3((n % 12 - 5.5) * 1.7, 0, -dz * (3.0 + floorf(n / 12.0) * 1.8))
	elif kind == "archer":
		u.slot = Vector3((n % 12 - 5.5) * 1.7, 0, -dz * (9.0 + floorf(n / 12.0) * 1.8))
	else:
		var side := -1.0 if n % 2 == 0 else 1.0
		u.slot = Vector3(side * (14.0 + float((n / 2) % 4) * 2.2), 0, -dz * (3.0 + floorf(n / 8.0) * 2.5))
	if not battle.orders.has(owner):
		battle.orders[owner] = {}
		for k in ["sword", "archer", "cav"]:
			battle.orders[owner][k] = {"mode": 2, "pos": Vector3(0, 0, -42.0 * dz)}
	battle.sfx.play("horn", u.position, -8.0, 1.8)


# ---- villager services (called from unit.gd) ----
func pick_tree(t: int, from: Vector3) -> int:
	var best := -1
	var bs := 1e9
	for i in tree_pos[t].size():
		if float(tree_food[t][i]) < 10.0:
			continue
		var s: float = from.distance_to(tree_pos[t][i]) + randf() * 12.0
		if s < bs:
			bs = s
			best = i
	return best


func tree_has_food(t: int, i: int) -> bool:
	return i >= 0 and i < tree_food[t].size() and float(tree_food[t][i]) >= 1.0


func tree_at(t: int, i: int) -> Vector3:
	return tree_pos[t][i]


func take_food(t: int, i: int, n: float) -> int:
	var got := minf(n, float(tree_food[t][i]))
	tree_food[t][i] = float(tree_food[t][i]) - got
	return int(got)


func deposit(t: int, n: int) -> void:
	food[t] += n


# ---- castle, towers ----
func damage_castle(t: int, amount: float) -> void:
	if not is_srv or fallen[t] or not battle.war:
		return
	castle_hp[t] = maxf(0.0, castle_hp[t] - amount)
	if castle_hp[t] <= 0.0:
		fallen[t] = true
		ev_all("castle_fall", {"team": t})
		var timer := get_tree().create_timer(6.5)
		timer.timeout.connect(func(): battle.finish(1 - t, "castle"))


func _tower_tick(dt: float) -> void:
	if not battle.war:
		return
	tower_cd -= dt
	if tower_cd > 0.0:
		return
	tower_cd = 1.7
	for t in 2:
		if fallen[t]:
			continue
		for side in [-1.0, 1.0]:
			var tp := Vector3(side * 36.0, 20.0, -73.0 * dz_of(t))
			var best = null
			var bd := TOWER_RANGE * TOWER_RANGE
			for e in battle.by_team[1 - t]:
				if e.dead:
					continue
				var d: float = Vector2(e.position.x - tp.x, e.position.z - tp.z).length_squared()
				if d < bd:
					bd = d
					best = e
			if best != null:
				battle.fire_arrow_pos(tp, best, t, TOWER_DMG * (0.8 + 0.1 * level[t]))


# ---- king duel ----
func _tick_duel(dt: float) -> void:
	if not battle.war or duel_done or battle.over:
		return
	if not battle.duel_active:
		var a = battle.team_king(0)
		var b = battle.team_king(1)
		if a != null and b != null and a.position.distance_to(b.position) < DUEL_TRIGGER:
			var c: Vector3 = (a.position + b.position) * 0.5
			c.y = 0.0
			battle.duel_center = c
			battle.duel_r = DUEL_R0
			battle.duel_active = true
			battle.freeze_others = true
			duel_t = 0.0
			for k in [a, b]:
				var off: Vector3 = k.position - c
				off.y = 0.0
				if off.length() > DUEL_R0 - 1.0:
					k.position = c + off.normalized() * (DUEL_R0 - 1.0)
			ev_all("duel_start", {"c": c})
	else:
		duel_t += dt
		battle.duel_r = lerpf(DUEL_R0, DUEL_R1, clampf(duel_t / DUEL_SHRINK, 0.0, 1.0))


func on_king_death(u) -> void:
	if not is_srv:
		return
	if battle.duel_active:
		battle.duel_active = false
		battle.freeze_others = false
		duel_done = true
		ev_all("duel_end", {"loser": u.team})
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(func(): battle.finish(1 - u.team, "duel"))
		return
	respawn[u.team] = {"t": KING_RESPAWN, "owner": u.owner_id}
	ev_all("king_down", {"team": u.team})


func _tick_respawn(dt: float) -> void:
	for t in respawn.keys():
		respawn[t].t -= dt
		if respawn[t].t <= 0.0:
			var owner: int = respawn[t].owner
			respawn.erase(t)
			var dz := dz_of(t)
			var h = battle._make_unit("hero", t, owner, Vector3(0, 0, -42.0 * dz))
			battle.sfx.play("horn", h.position, 0.0, 1.3)
			break


# ================================================================== visuals: duel
func _duel_visual_start(c: Vector3) -> void:
	battle.duel_active = true
	battle.freeze_others = true
	battle.duel_center = c
	battle.duel_r = DUEL_R0
	duel_t = 0.0
	if duel_ring != null and is_instance_valid(duel_ring):
		duel_ring.queue_free()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = battle._mat(Color(1.0, 0.45, 0.12), 0.5, 0.0, 4.0)
	ring.position = c + Vector3(0, 0.15, 0)
	ring.scale = Vector3(DUEL_R0, 3.0, DUEL_R0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	battle.add_child(ring)
	duel_ring = ring
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 4.0
	l.omni_range = 30.0
	l.position = Vector3(0, 3.0, 0)
	ring.add_child(l)
	battle.sfx.play_ui("horn", 3.0)
	battle.banner("DUEL OF KINGS", Color(1.0, 0.7, 0.2), 2.8)
	battle.cine_orbit(c + Vector3(0, 1.5, 0), 17.0, 6.5, 3.8, 1.5)
	battle._slowmo(0.55, 1.4)


func _duel_visual_end() -> void:
	battle.duel_active = false
	battle.freeze_others = false
	if duel_ring != null and is_instance_valid(duel_ring):
		duel_ring.queue_free()
	duel_ring = null


# ================================================================== AI king (host)
func _ai_tick(t: int) -> void:
	var owner := -100 - t
	var lv: int = level[t]
	var houses := count_slots(t, 1)
	var barr := count_slots(t, 2)
	var info: Dictionary = ai_info[t]
	if not info.has("greeted") and battle.game_time > 30.0:
		info["greeted"] = true
		var txt := "Greetings, neighbour king. My lands prosper - see that yours do too."
		_send_letter(t, txt, owner)
	var actions := 0
	# villagers
	var want_v := 5 + 2 * lv
	if vill_n[t] + queued(t, "villager") < want_v and food[t] >= VILLAGER_FOOD and pop_used[t] < pop_cap(t):
		_cmd(owner, "villager", {})
		actions += 1
	# housing
	if actions < 2 and (pop_used[t] >= pop_cap(t) - 2 or houses < 2 + lv * 2) and gold[t] >= HOUSE_COST and free_slot(t, HOUSE_ORDER) >= 0:
		if barr >= 1 or houses < 4 or gold[t] > HOUSE_COST + 60:
			_cmd(owner, "house", {})
			actions += 1
	# castle upgrade
	if actions < 2 and lv < 3 and houses >= 2 + 2 * lv:
		var cost: Array = UPGRADE[lv - 1]
		if gold[t] >= cost[0] and food[t] >= cost[1]:
			_cmd(owner, "upgrade", {})
			actions += 1
	# barracks
	if actions < 2 and barr < (1 if lv < 3 else 2) and houses >= 3 and gold[t] >= BARRACKS_COST + 20:
		_cmd(owner, "barracks", {})
		actions += 1
	# recruit
	if actions < 2 and barr >= 1 and vill_n[t] >= 3:
		var roll := randf()
		var kind := "sword"
		if lv >= 3 and roll > 0.8:
			kind = "cav"
		elif lv >= 2 and roll > 0.45:
			kind = "archer"
		var inf: Array = TRAIN[kind]
		if gold[t] >= inf[0] and food[t] >= inf[1] + 10 and pop_used[t] < pop_cap(t):
			_cmd(owner, "train", {"kind": kind})
	# food buying when starving
	if food[t] < 15 and gold[t] > 90:
		_cmd(owner, "buyfood", {})
	# army orders once the war has begun
	if battle.war:
		var mine_n: int = soldier_n[t]
		var their_n: int = soldier_n[1 - t]
		var mode := 2
		if mine_n >= 5 and (mine_n >= their_n * 0.7 or fallen[1 - t] or their_n == 0):
			mode = 1
		var dzw := dz_of(t)
		if not battle.orders.has(owner):
			battle.orders[owner] = {}
		for kk in ["sword", "archer", "cav"]:
			battle.orders[owner][kk] = {"mode": mode, "pos": Vector3(0, 0, -42.0 * dzw)}
	# war decision
	if not battle.war and battle.game_time > 150.0:
		var mine: int = soldier_n[t]
		var theirs: int = soldier_n[1 - t]
		if mine >= 10 + lv or (mine >= 7 and mine > theirs * 1.8):
			_send_letter(t, "I have waited long enough. My armies march - defend your castle!", owner)
			_cmd(owner, "war", {})


func _ai_read_letter(to_t: int, from_t: int, text: String) -> void:
	if not battle.ai_teams.has(to_t):
		return
	var low := text.to_lower()
	var ar := has_arabic(text)
	var reply := ""
	var warlike := false
	for k in ["war", "attack", "fight", "destroy", "حرب", "هجوم", "اقاتل", "سأدمر"]:
		if low.contains(k):
			warlike = true
	var peaceful := false
	for k in ["peace", "truce", "ally", "friend", "سلام", "هدنة", "تحالف", "صديق"]:
		if low.contains(k):
			peaceful = true
	if warlike:
		reply = "كلماتك تسليني. جيوشي سترد عليك." if ar else "Your threats amuse me, king. My armies will answer."
	elif peaceful:
		reply = "السلام رفاهية للأقوياء... احرس حدودك." if ar else "Peace is a luxury for the strong... guard your borders."
	else:
		var en := ["I read your letter. A king should guard his walls, not his words.", "Send as many letters as you wish; my walls are high.", "Your message reached me. Let us see who rules this valley."]
		var arr := ["قرأت رسالتك. على الملك أن يحرس أسواره لا كلماته.", "أرسل ما شئت من الرسائل، فأسواري عالية.", "وصلتني رسالتك. لنرَ من سيحكم هذا الوادي."]
		reply = (arr if ar else en)[randi() % 3]
	ai_replies.append({"t": 4.0, "team": to_t, "text": reply})


# ================================================================== UI
func _theme(u: float) -> Theme:
	var th := Theme.new()
	th.default_font_size = int(22 * u)
	var sb := func(c: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.border_color = border
		s.set_border_width_all(int(2 * u))
		s.set_corner_radius_all(int(8 * u))
		s.content_margin_left = 10 * u
		s.content_margin_right = 10 * u
		s.content_margin_top = 6 * u
		s.content_margin_bottom = 6 * u
		return s
	th.set_stylebox("normal", "Button", sb.call(Color(0.14, 0.12, 0.1, 0.92), Color(0.75, 0.6, 0.25)))
	th.set_stylebox("hover", "Button", sb.call(Color(0.24, 0.2, 0.14, 0.95), Color(1.0, 0.8, 0.3)))
	th.set_stylebox("pressed", "Button", sb.call(Color(0.5, 0.38, 0.12, 0.98), Color(1.0, 0.85, 0.4)))
	th.set_stylebox("disabled", "Button", sb.call(Color(0.1, 0.1, 0.1, 0.8), Color(0.3, 0.3, 0.3)))
	th.set_color("font_color", "Button", Color(1.0, 0.93, 0.75))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_stylebox("panel", "PanelContainer", sb.call(Color(0.07, 0.06, 0.08, 0.93), Color(0.75, 0.6, 0.25)))
	return th


func _parch(u: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.89, 0.8, 0.6)
	s.border_color = Color(0.45, 0.3, 0.12)
	s.set_border_width_all(int(6 * u))
	s.set_corner_radius_all(int(12 * u))
	s.content_margin_left = 26 * u
	s.content_margin_right = 26 * u
	s.content_margin_top = 20 * u
	s.content_margin_bottom = 20 * u
	return s


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var u: float = battle.ui_u
	var vs: Vector2 = battle.vs
	var cl := CanvasLayer.new()
	cl.layer = 7
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme(u)
	cl.add_child(root)
	ui["root"] = root
	var rl := Label.new()
	rl.position = Vector2(20, 84) * u
	rl.add_theme_font_size_override("font_size", int(23 * u))
	rl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	rl.add_theme_color_override("font_outline_color", Color.BLACK)
	rl.add_theme_constant_override("outline_size", int(6 * u))
	root.add_child(rl)
	ui["res"] = rl
	var city := Button.new()
	city.text = "CITY"
	city.position = Vector2(20, 122) * u
	city.size = Vector2(150, 58) * u
	city.pressed.connect(_toggle_panel)
	root.add_child(city)
	ui["city"] = city
	# castle bars + status
	var cx := vs.x * 0.5
	var mk_bar := func(x: float, col: Color, title: String) -> ProgressBar:
		var pb := ProgressBar.new()
		pb.position = Vector2(x, 30 * u)
		pb.size = Vector2(250 * u, 16 * u)
		pb.show_percentage = false
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		pb.add_theme_stylebox_override("fill", fill)
		root.add_child(pb)
		var lb := Label.new()
		lb.text = title
		lb.position = Vector2(x, 4 * u)
		lb.add_theme_font_size_override("font_size", int(18 * u))
		lb.add_theme_color_override("font_outline_color", Color.BLACK)
		lb.add_theme_constant_override("outline_size", int(5 * u))
		root.add_child(lb)
		return pb
	var mine_col := Color(0.2, 0.45, 1.0) if my_team == 0 else Color(1.0, 0.25, 0.2)
	var their_col := Color(1.0, 0.25, 0.2) if my_team == 0 else Color(0.2, 0.45, 1.0)
	ui["bar_me"] = mk_bar.call(cx - 262 * u, mine_col, "YOUR CASTLE")
	ui["bar_foe"] = mk_bar.call(cx + 12 * u, their_col, "ENEMY CASTLE")
	var st := Label.new()
	st.position = Vector2(cx - 120 * u, 52 * u)
	st.size = Vector2(240, 30) * u
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", int(22 * u))
	st.add_theme_color_override("font_outline_color", Color.BLACK)
	st.add_theme_constant_override("outline_size", int(6 * u))
	root.add_child(st)
	ui["status"] = st
	# city panel
	var panel := PanelContainer.new()
	panel.position = Vector2(cx - 330 * u, 78 * u)
	panel.visible = false
	root.add_child(panel)
	ui["panel"] = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tl := _label(head, "YOUR KINGDOM", int(26 * u), Color(1.0, 0.85, 0.4))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(60, 46) * u
	close.pressed.connect(_toggle_panel)
	head.add_child(close)
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", int(8 * u))
	g1.add_theme_constant_override("v_separation", int(8 * u))
	vb.add_child(g1)
	var mkb := func(parent: Node, key: String, cb: Callable, w: float) -> Button:
		var b := Button.new()
		b.custom_minimum_size = Vector2(w, 66) * u
		b.pressed.connect(cb)
		parent.add_child(b)
		ui[key] = b
		return b
	mkb.call(g1, "b_vill", func(): cmd("villager"), 318.0)
	mkb.call(g1, "b_food", func(): cmd("buyfood"), 318.0)
	mkb.call(g1, "b_house", func(): cmd("house"), 318.0)
	mkb.call(g1, "b_barr", func(): cmd("barracks"), 318.0)
	mkb.call(g1, "b_up", func(): cmd("upgrade"), 318.0)
	var sp := Control.new()
	g1.add_child(sp)
	_label(vb, "TRAIN SOLDIERS", int(20 * u), Color(0.8, 0.8, 0.85))
	var g2 := HBoxContainer.new()
	g2.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g2)
	mkb.call(g2, "b_sword", func(): cmd("train", {"kind": "sword"}), 208.0)
	mkb.call(g2, "b_archer", func(): cmd("train", {"kind": "archer"}), 208.0)
	mkb.call(g2, "b_cav", func(): cmd("train", {"kind": "cav"}), 208.0)
	var g3 := HBoxContainer.new()
	g3.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g3)
	mkb.call(g3, "b_letter", func(): _show_compose(""), 318.0)
	mkb.call(g3, "b_war", func(): _war_press(), 318.0)


func _toggle_panel() -> void:
	var p: PanelContainer = ui.panel
	p.visible = not p.visible
	_update_ui(true)
	battle.sfx.play_ui("coin", -10.0)


func _war_press() -> void:
	if battle.war:
		return
	if war_confirm > 0.0:
		war_confirm = 0.0
		cmd("war")
		_toggle_panel()
	else:
		war_confirm = 3.0
		_update_ui(true)


func _process(dt: float) -> void:
	if battle == null:
		return
	_tick_messengers(dt)
	war_confirm = maxf(0.0, war_confirm - dt)
	if battle.duel_active:
		if not is_srv:
			duel_t += dt
			battle.duel_r = lerpf(DUEL_R0, DUEL_R1, clampf(duel_t / DUEL_SHRINK, 0.0, 1.0))
		if duel_ring != null and is_instance_valid(duel_ring):
			var r: float = battle.duel_r
			duel_ring.scale = Vector3(r, 3.0, r)
	ui_t -= dt
	if ui_t <= 0.0:
		ui_t = 0.25
		_update_ui(false)


func _update_ui(force: bool) -> void:
	if ui.is_empty():
		return
	var t := my_team
	var houses := count_slots(t, 1)
	var res: Label = ui.res
	res.text = "GOLD %d    FOOD %d    POP %d/%d    VILLAGERS %d    LV %d" % [int(gold[t]), int(food[t]), pop_used[t], pop_cap(t), vill_n[t], level[t]]
	var bm: ProgressBar = ui.bar_me
	var bf: ProgressBar = ui.bar_foe
	bm.max_value = CASTLE_HP[level[t] - 1]
	bm.value = castle_hp[t]
	bf.max_value = CASTLE_HP[level[1 - t] - 1]
	bf.value = castle_hp[1 - t]
	var st: Label = ui.status
	if battle.duel_active:
		st.text = "DUEL OF KINGS"
		st.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	elif battle.war:
		st.text = "WAR"
		st.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	else:
		st.text = "PEACE"
		st.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	var panel: PanelContainer = ui.panel
	if not panel.visible and not force:
		return
	var set_b := func(key: String, text: String, ok: bool):
		var b: Button = ui[key]
		b.text = text
		b.disabled = not ok
	var cap := pop_cap(t)
	set_b.call("b_vill", "Hire Villager\n%d food" % VILLAGER_FOOD, food[t] >= VILLAGER_FOOD and pop_used[t] < cap)
	set_b.call("b_food", "Buy Food\n%d gold -> %d food" % [BUY_GOLD, BUY_FOOD], gold[t] >= BUY_GOLD)
	set_b.call("b_house", "Build House (%d/%d)\n%d gold" % [used_slots(t), SLOT_LIMIT[level[t] - 1], HOUSE_COST], gold[t] >= HOUSE_COST and free_slot(t, HOUSE_ORDER) >= 0)
	var maxb := 1 if level[t] < 3 else 2
	set_b.call("b_barr", "Barracks (%d/%d)\n%d gold" % [count_slots(t, 2), maxb, BARRACKS_COST], gold[t] >= BARRACKS_COST and count_slots(t, 2) < maxb and free_slot(t, BARRACKS_ORDER) >= 0)
	if level[t] < 3:
		var c: Array = UPGRADE[level[t] - 1]
		set_b.call("b_up", "Develop Castle -> Lv%d\n%d gold, %d food" % [level[t] + 1, c[0], c[1]], gold[t] >= c[0] and food[t] >= c[1])
	else:
		set_b.call("b_up", "Castle at max level", false)
	var barr_ok: bool = count_slots(t, 2) >= 1 and pop_used[t] < cap
	for pair in [["b_sword", "sword", "Swordsman"], ["b_archer", "archer", "Archer"], ["b_cav", "cav", "Cavalry"]]:
		var inf: Array = TRAIN[pair[1]]
		var txt: String = "%s\n%dg %df" % [pair[2], inf[0], inf[1]]
		if level[t] < inf[3]:
			txt = "%s\nCastle Lv%d" % [pair[2], inf[3]]
		set_b.call(pair[0], txt, barr_ok and level[t] >= inf[3] and gold[t] >= inf[0] and food[t] >= inf[1])
	set_b.call("b_letter", "Write Letter\nsend a messenger", true)
	var wb: Button = ui.b_war
	if battle.war:
		wb.text = "WAR IS ON"
		wb.disabled = true
	else:
		wb.disabled = false
		wb.text = "TAP AGAIN TO CONFIRM" if war_confirm > 0.0 else "Declare War\nattack the other king"


func _modal(title: String, user: float) -> Array:
	var u: float = user
	var vs: Vector2 = battle.vs
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _parch(u))
	pc.position = Vector2(vs.x * 0.5 - 360 * u, 40 * u)
	pc.custom_minimum_size = Vector2(720, 300) * u
	dim.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * u))
	pc.add_child(vb)
	_label(vb, title, int(28 * u), Color(0.35, 0.18, 0.05))
	battle.modal = true
	return [dim, vb]


func _close_modal(dim: Control) -> void:
	dim.queue_free()
	battle.modal = false
	if not inbox.is_empty():
		var nx: Dictionary = inbox.pop_front()
		_show_reader.call_deferred(String(nx.from), String(nx.text))


func _show_compose(prefill: String) -> void:
	var u: float = battle.ui_u
	if ui.panel.visible:
		_toggle_panel()
	var m := _modal("WRITE A LETTER TO THE OTHER KING", u)
	var dim: Control = m[0]
	var vb: VBoxContainer = m[1]
	var te := TextEdit.new()
	te.placeholder_text = "Write your message here..."
	te.text = prefill
	te.custom_minimum_size = Vector2(660, 190) * u
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.text_direction = Control.TEXT_DIRECTION_AUTO
	te.add_theme_font_size_override("font_size", int(26 * u))
	te.add_theme_color_override("font_color", Color(0.22, 0.12, 0.04))
	te.add_theme_color_override("font_placeholder_color", Color(0.5, 0.38, 0.22))
	te.add_theme_color_override("caret_color", Color(0.4, 0.1, 0.05))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.95, 0.88, 0.7)
	bg.set_corner_radius_all(int(6 * u))
	te.add_theme_stylebox_override("normal", bg)
	te.add_theme_stylebox_override("focus", bg)
	vb.add_child(te)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12 * u))
	vb.add_child(row)
	var send := Button.new()
	send.text = "SEND MESSENGER"
	send.custom_minimum_size = Vector2(330, 62) * u
	send.pressed.connect(func():
		var txt := te.text.strip_edges()
		if txt.is_empty():
			battle._toast("The paper is empty!", 1.5)
			return
		cmd("letter", {"text": txt.substr(0, 240)})
		_close_modal(dim))
	row.add_child(send)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(200, 62) * u
	cancel.pressed.connect(func(): _close_modal(dim))
	row.add_child(cancel)
	te.grab_focus()


func _show_reader(from_name: String, text: String) -> void:
	if battle.modal:
		inbox.append({"from": from_name, "text": text})
		battle._toast("A messenger has arrived - read the letter when you finish.", 3.0)
		return
	var u: float = battle.ui_u
	var m := _modal("A MESSENGER HAS ARRIVED", u)
	var dim: Control = m[0]
	var vb: VBoxContainer = m[1]
	_label(vb, "Letter from %s:" % from_name, int(22 * u), Color(0.45, 0.25, 0.08))
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 150) * u
	body.text_direction = Control.TEXT_DIRECTION_AUTO
	body.add_theme_font_size_override("font_size", int(28 * u))
	body.add_theme_color_override("font_color", Color(0.2, 0.1, 0.03))
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12 * u))
	vb.add_child(row)
	var reply := Button.new()
	reply.text = "Write Reply"
	reply.custom_minimum_size = Vector2(260, 62) * u
	reply.pressed.connect(func():
		_close_modal(dim)
		_show_compose(""))
	row.add_child(reply)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 62) * u
	close.pressed.connect(func(): _close_modal(dim))
	row.add_child(close)
