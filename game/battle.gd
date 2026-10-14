extends Node3D
# Battle: world, armies, AI commander, camera, HUD, effects, host-authoritative networking.

const UnitS := preload("res://game/unit.gd")
const ArrowS := preload("res://game/arrow.gd")
const SfxS := preload("res://game/sfx.gd")
const KingdomS := preload("res://game/kingdom.gd")
const BattleMapS := preload("res://game/battlemap.gd")

# Horse riding for the player is switched off until the horse models/animations are ready.
const HORSE_RIDING := false

const FOLLOW := 0
const ADVANCE := 1
const HOLD := 2
const CHARGE := 3
const RETREAT := 4
const KIND_IDS := ["sword", "archer", "cav", "hero", "villager"]
const LocS := preload("res://game/loc.gd")
const SettingsS := preload("res://game/settings.gd")
const MODE_NAMES := ["Follow me", "Advance", "Hold here", "Charge!", "Retreat"]

var cfg := {}
var net
var sfx
var units := {}
var by_team := [[], []]
var nk := 2
var ring_r := 73.0
const TEAM_COLS := [Color(0.12, 0.32, 0.95), Color(0.9, 0.12, 0.1), Color(0.14, 0.68, 0.24), Color(0.95, 0.76, 0.1), Color(0.62, 0.22, 0.85), Color(0.96, 0.5, 0.08)]
const TEAM_NAMES := ["Blue", "Red", "Green", "Yellow", "Purple", "Orange"]
var heroes := {}
var orders := {}
var hunt := {}
var grid := {}
var next_id := 1
var is_srv := true
var my_id := 1
var my_team := 0
var running := false
var intro := true
var over := false
var cam: Camera3D
var cam_yaw := 0.0
var loc_t := 0.0
var cam_pitch := 0.38
var cam_dist := 8.5
var cam_focus := Vector3.ZERO
var spec_pos := Vector3.ZERO
var shake := 0.0
var snap_t := 0.0
var ai_t := 0.0
var end_t := 0.0
var hud_t := 0.0
var send_t := 0.0
var ai_teams := []
var sel := 7
var local_rally := 0.0
var local_mount := 0.0
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var look_id := -1
var rects: Array = []
var hud := {}
var ui_u := 1.0
var vs := Vector2(1280, 720)
var game_time := 0.0
var kingdom = null
var castle_roots := [null, null]
var admin := false
var admin_view := -1
var admin_ctrl := false
var reveal := false
var war := false
var war_t0 := 0.0
var duel_active := false
var duel_teams := [-1, -1]
var duel_r := 9.5
var duel_center := Vector3.ZERO
var freeze_others := false
var modal := false
var cine := {}
var garrison := {}
var banner_tw: Tween = null


func _ready() -> void:
	net = get_node("/root/Main/Net")
	is_srv = multiplayer.is_server()
	my_id = multiplayer.get_unique_id()
	var me: Dictionary = net.players.get(my_id, {"idx": 0})
	if String(cfg.get("mode", "battle")) == "kingdom":
		nk = clampi(int(cfg.get("kingdoms", 2)), 2, 6)
	ring_r = 73.0 if nk <= 4 else (78.0 if nk == 5 else 92.0)
	by_team = []
	castle_roots = []
	for i in nk:
		by_team.append([])
		castle_roots.append(null)
	my_team = int(me.idx) % nk
	_build_world()
	sfx = SfxS.new()
	sfx.name = "Sfx"
	add_child(sfx)
	_build_hud()
	cam_yaw = ang(my_team)
	if String(cfg.get("mode", "battle")) == "kingdom":
		kingdom = KingdomS.new()
		kingdom.name = "Kingdom"
		kingdom.battle = self
		add_child(kingdom)
		kingdom.setup()
	if is_srv:
		_spawn_all()
	_intro()



# ================================================================== ring geometry
# Each kingdom has a local frame (its castle gate at local z=-73, interior behind it).
# Kingdom t is that frame rotated by ang(t) around the map centre; with 2 kingdoms the
# gates are at z=-73 and z=+73 as before, with 6 they sit on a ring.
func ang(t: int) -> float:
	return TAU * float(t) / float(nk)


func lw(t: int, v: Vector3) -> Vector3:
	return Basis(Vector3.UP, ang(t)) * (v + Vector3(0, 0, 73.0 - ring_r))


func wl(t: int, p: Vector3) -> Vector3:
	return Basis(Vector3.UP, -ang(t)) * p - Vector3(0, 0, 73.0 - ring_r)


func rotv(t: int, v: Vector3) -> Vector3:
	return Basis(Vector3.UP, ang(t)) * v


func team_col(t: int) -> Color:
	return TEAM_COLS[t % 6]


func team_name(t: int) -> String:
	return TEAM_NAMES[t % 6]


# Who the local player's orders are given for (admin mode can take over an AI kingdom, offline only).
func ctrl_owner() -> int:
	if admin and admin_ctrl and admin_view >= 0 and admin_view != my_team and not net.online:
		return -100 - admin_view
	return my_id


func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	if kingdom == null:
		return true
	return kingdom.at_war(a, b)


# Teams this team is fighting right now.
func foes_of(t: int) -> Array:
	var r := []
	for i in nk:
		if i != t and hostile(t, i):
			r.append(i)
	return r


# The kingdom this team marches against: the nearest alive hostile one (or, in peace, the nearest alive neighbour).
func foe(t: int) -> int:
	if nk == 2:
		return 1 - t
	var best := -1
	var bd := 1e18
	var hos := foes_of(t)
	for i in nk:
		if i == t or (kingdom != null and kingdom.fallen[i]):
			continue
		if not hos.is_empty() and not hos.has(i):
			continue
		var d: float = lw(t, Vector3(0, 0, -73.0)).distance_squared_to(lw(i, Vector3(0, 0, -73.0)))
		if d < bd:
			bd = d
			best = i
	return best if best >= 0 else (t + 1) % nk


func hostile_units(t: int) -> Array:
	var r := []
	for i in nk:
		if hostile(t, i):
			r.append_array(by_team[i])
	return r


# ================================================================== world
func _mat(c: Color, rough := 0.9, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


func _mesh(parent: Node, mesh: Mesh, mat: Material, p: Vector3, r := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = p
	m.rotation = r
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.78)
	sm.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sm.ground_horizon_color = Color(0.5, 0.58, 0.5)
	sm.ground_bottom_color = Color(0.2, 0.26, 0.2)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.74, 0.84)
	env.fog_density = 0.0011
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.12
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -40, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75.0
	add_child(sun)

	cam = Camera3D.new()
	cam.far = 500.0
	cam.fov = 66.0
	cam.current = true
	add_child(cam)

	# ground
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	_mesh(self, pm, _mat(Color(0.22, 0.4, 0.14), 1.0), Vector3.ZERO, Vector3.ZERO, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dirt := _mat(Color(0.38, 0.29, 0.18), 1.0)
	for i in 22:
		var c := _cyl(rng.randf_range(3, 9), rng.randf_range(3, 9), 0.04, 12)
		_mesh(self, c, dirt, Vector3(rng.randf_range(-85, 85), 0.02, rng.randf_range(-60, 60)), Vector3.ZERO, false)
	# trees
	var trunk := _mat(Color(0.3, 0.2, 0.1))
	var leaf := [_mat(Color(0.1, 0.3, 0.12)), _mat(Color(0.14, 0.38, 0.14)), _mat(Color(0.2, 0.34, 0.1))]
	var tm := _cyl(0.3, 0.4, 2.0, 8)
	var cm1 := _cyl(0.0, 2.3, 4.5, 10)
	var cm2 := _cyl(0.0, 1.7, 3.5, 10)
	var placed := 0
	while placed < 110:
		var x := rng.randf_range(-190, 190)
		var z := rng.randf_range(-190, 190)
		if nk > 2:
			if Vector2(x, z).length() < ring_r + 78.0:
				continue
		elif absf(x) < 108 and absf(z) < (140 if String(cfg.get("mode", "battle")) == "kingdom" else 96):
			continue
		var t := Node3D.new()
		t.position = Vector3(x, 0, z)
		t.scale = Vector3.ONE * rng.randf_range(0.9, 2.0)
		add_child(t)
		_mesh(t, tm, trunk, Vector3(0, 1.0, 0), Vector3.ZERO, false)
		var lm: Material = leaf[placed % 3]
		_mesh(t, cm1, lm, Vector3(0, 4.0, 0), Vector3.ZERO, false)
		_mesh(t, cm2, lm, Vector3(0, 6.2, 0), Vector3.ZERO, false)
		placed += 1
	# mountains
	var rock := _mat(Color(0.42, 0.4, 0.45))
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var r := 300.0
		_mesh(self, _cyl(0.0, rng.randf_range(50, 90), rng.randf_range(60, 110), 8), rock, Vector3(cos(a) * r, 30, sin(a) * r), Vector3.ZERO, false)
	# castles
	for i in nk:
		_castle(i)


func _castle(team: int) -> void:
	var stone := _mat(Color(0.55, 0.53, 0.5), 0.95)
	var tc := team_col(team)
	var cloth := _mat(tc, 0.8, 0.0, 0.5)
	var root := Node3D.new()
	root.position = lw(team, Vector3(0, 0, -73.0))
	root.rotation.y = ang(team)
	add_child(root)
	castle_roots[team] = root
	var kmode := String(cfg.get("mode", "battle")) == "kingdom"
	if kmode:
		# front wall with an opening for the (animated) gate
		_mesh(root, _box(Vector3(29.5, 9, 3)), stone, Vector3(-20.25, 4.5, 0))
		_mesh(root, _box(Vector3(29.5, 9, 3)), stone, Vector3(20.25, 4.5, 0))
		_mesh(root, _box(Vector3(11, 2.6, 3)), stone, Vector3(0, 7.7, 0))
	else:
		_mesh(root, _box(Vector3(70, 9, 3)), stone, Vector3(0, 4.5, 0))
	for i in 18:
		if kmode and absf(-34 + i * 4.0) < 6.0:
			continue
		_mesh(root, _box(Vector3(2.2, 1.6, 3.3)), stone, Vector3(-34 + i * 4.0, 9.8, 0), Vector3.ZERO, false)
	if not kmode:
		_mesh(root, _box(Vector3(10, 7, 3.4)), _mat(Color(0.18, 0.12, 0.08)), Vector3(0, 3.5, 0.1))
	for sx in [-36.0, 36.0]:
		_mesh(root, _cyl(4.4, 4.6, 16, 14), stone, Vector3(sx, 8, 0))
		_mesh(root, _cyl(0.0, 6.0, 6.5, 14), cloth, Vector3(sx, 19, 0))
		_mesh(root, _box(Vector3(0.2, 5, 0.2)), stone, Vector3(sx, 24, 0), Vector3.ZERO, false)
		_mesh(root, _box(Vector3(3.2, 2.0, 0.1)), cloth, Vector3(sx + 1.7, 25, 0), Vector3.ZERO, false)
	var fz := 3.0
	for sx in [-6.0, 6.0]:
		_mesh(root, _cyl(0.2, 0.25, 3.0, 8), stone, Vector3(sx, 1.5, fz), Vector3.ZERO, false)
		_mesh(root, _cyl(0.0, 0.45, 0.8, 8), _mat(Color(1.0, 0.5, 0.15), 0.5, 0.0, 4.0), Vector3(sx, 3.3, fz), Vector3.ZERO, false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.2
		l.omni_range = 22.0
		l.position = Vector3(sx, 4.0, fz)
		root.add_child(l)


# ================================================================== armies
func _spawn_all() -> void:
	var tp := []
	for i in nk:
		tp.append([])
	for id in net.players.keys():
		tp[int(net.players[id].idx) % nk].append(id)
	for t in nk:
		var lst: Array = tp[t]
		if lst.is_empty():
			ai_teams.append(t)
			_spawn_army(-100 - t, t, 0.0)
		else:
			for i in lst.size():
				_spawn_army(lst[i], t, (i - (lst.size() - 1) * 0.5) * 34.0)


func _spawn_army(owner: int, team: int, cx: float) -> void:
	var dz := 1.0 if team == 0 else -1.0
	var bz := -52.0 * dz
	if kingdom != null:
		orders[owner] = {}
		var hp: Vector3 = kingdom.home_pos(team)
		var king = _make_unit("hero", team, owner, hp + rotv(team, Vector3(cx, 0, -4.0)))
		for k in ["sword", "archer", "cav"]:
			orders[owner][k] = {"mode": HOLD, "pos": hp}
		for i in 2:
			_make_unit("villager", team, owner, kingdom.depot(team) + rotv(team, Vector3((i * 2 - 1) * 2.0, 0, 0)))
		return
	var ns: int = int(cfg.get("sword", 40))
	var na: int = int(cfg.get("archer", 20))
	var nc: int = int(cfg.get("cav", 10))
	orders[owner] = {}
	var hero = _make_unit("hero", team, owner, Vector3(cx, 0, bz - dz * 3.0))
	for i in ns:
		var u = _make_unit("sword", team, owner, Vector3(cx + (i % 10 - 4.5) * 1.7, 0, bz + dz * (6.0 + floorf(i / 10.0) * 1.8)))
		u.slot = u.position - hero.position
	for i in na:
		var u = _make_unit("archer", team, owner, Vector3(cx + (i % 10 - 4.5) * 1.7, 0, bz - dz * floorf(i / 10.0) * 1.8))
		u.slot = u.position - hero.position
	for i in nc:
		var side := -1.0 if i % 2 == 0 else 1.0
		var u = _make_unit("cav", team, owner, Vector3(cx + side * (14.0 + float((i / 2) % 4) * 2.2), 0, bz + dz * (3.0 + floorf(i / 8.0) * 2.5)))
		u.slot = u.position - hero.position
	for k in ["sword", "archer", "cav"]:
		orders[owner][k] = {"mode": HOLD, "pos": hero.position}


func _make_unit(kind: String, team: int, owner: int, pos: Vector3, id := -1):
	var u = UnitS.new()
	if id >= 0:
		u.uid = id
	else:
		u.uid = next_id
		next_id += 1
	u.position = pos
	add_child(u)
	u.setup(kind, team, owner, self)
	u.rotation.y = ang(team)
	u.tpos = pos
	u.tyaw = u.rotation.y
	u.puppet = not is_srv
	u.last_seen = game_time
	units[u.uid] = u
	if kind == "hero":
		heroes[owner] = u
		if owner == my_id:
			u.add_marker()
	return u


func remove_unit(u) -> void:
	units.erase(u.uid)
	if heroes.get(u.owner_id) == u and u.kind == "hero":
		pass
	if is_instance_valid(u):
		u.queue_free()


# ================================================================== queries (host)
func separation(u) -> Vector3:
	var cx := floori(u.position.x / 2.0)
	var cz := floori(u.position.z / 2.0)
	var push := Vector3.ZERO
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l = grid.get(Vector2i(cx + dx, cz + dz))
			if l == null:
				continue
			for o in l:
				if o == u:
					continue
				var d: Vector3 = u.position - o.position
				d.y = 0.0
				var dl := d.length()
				if dl < 1.1 and dl > 0.001:
					push += d / dl * (1.1 - dl)
				elif dl <= 0.001:
					push += Vector3(randf() - 0.5, 0, randf() - 0.5)
	return push.limit_length(2.5)


func is_garrison(u) -> bool:
	var pct: int = int(garrison.get(u.owner_id, 0))
	return pct > 0 and (u.uid * 37) % 100 < pct


# Order from the map: place groups at a point (HOLD), attack, or garrison share.
@rpc("any_peer", "reliable")
func order_at_msg(mode: int, mask: int, x: float, z: float, gar: int) -> void:
	if is_srv:
		_order_at(multiplayer.get_remote_sender_id(), mode, mask, Vector3(x, 0, z), gar)


func order_at(mode: int, mask: int, pos: Vector3, gar := -1) -> void:
	if intro or over:
		return
	if is_srv:
		_order_at(ctrl_owner(), mode, mask, pos, gar)
	else:
		order_at_msg.rpc_id(1, mode, mask, pos.x, pos.z, gar)


func _order_at(owner: int, mode: int, mask: int, pos: Vector3, gar: int) -> void:
	if not orders.has(owner):
		orders[owner] = {}
	var ks := ["sword", "archer", "cav"]
	for i in 3:
		if (mask & (1 << i)) != 0:
			orders[owner][ks[i]] = {"mode": mode, "pos": pos}
	if gar >= 0:
		garrison[owner] = clampi(gar, 0, 100)
	if kingdom != null and (mode == ADVANCE or mode == CHARGE):
		kingdom.on_march(owner)


# ---- targeted attack from the war map: send N soldiers of each kind against one kingdom (target -2 = call everyone back)
func strike(target: int, ns: int, na: int, nc: int) -> void:
	if intro or over or kingdom == null:
		return
	if is_srv:
		_strike(ctrl_owner(), target, ns, na, nc)
	else:
		strike_msg.rpc_id(1, target, ns, na, nc)


@rpc("any_peer", "reliable")
func strike_msg(target: int, ns: int, na: int, nc: int) -> void:
	if is_srv:
		_strike(multiplayer.get_remote_sender_id(), target, ns, na, nc)


func _strike(owner: int, target: int, ns: int, na: int, nc: int) -> void:
	var t: int = kingdom.team_of(owner)
	if t < 0 or t >= nk or kingdom.fallen[t]:
		return
	if target == -2:
		for u in by_team[t]:
			u.strike_foe = -1
		if not orders.has(owner):
			orders[owner] = {}
		for k in ["sword", "archer", "cav"]:
			orders[owner][k] = {"mode": 2, "pos": kingdom.home_pos(t)}
		return
	if target == t or target < 0 or target >= nk or kingdom.fallen[target]:
		return
	if not kingdom.at_war(t, target):
		kingdom._cmd(owner, "war", {"to": target})
	if not kingdom.at_war(t, target):
		return
	var want := {"sword": ns, "archer": na, "cav": nc}
	for k in want.keys():
		var n: int = want[k]
		# soldiers that are idle first, then those already on another campaign
		for pass_i in 2:
			for u in by_team[t]:
				if n <= 0:
					break
				if u.dead or u.kind != k:
					continue
				if (pass_i == 0 and u.strike_foe >= 0) or (pass_i == 1 and u.strike_foe == target):
					continue
				u.strike_foe = target
				n -= 1
	kingdom.on_march(owner)


func team_king(t: int):
	for e in by_team[t]:
		if not e.dead and e.kind == "hero":
			return e
	return null


func duel_other(t: int) -> int:
	if duel_teams[0] == t:
		return duel_teams[1]
	if duel_teams[1] == t:
		return duel_teams[0]
	return -1


func nearest_enemy(u, r: float):
	if kingdom != null:
		if not war or u.kind == "villager":
			return null
		if duel_active:
			var ot := duel_other(u.team)
			var k = team_king(ot) if ot >= 0 else null
			if u.kind == "hero" and k != null and u.position.distance_squared_to(k.position) < r * r:
				return k
			return null
	var best = null
	var bd := r * r
	for ti in nk:
		if not hostile(u.team, ti):
			continue
		for e in by_team[ti]:
			if e.dead or e.kind == "villager":
				continue
			var d: float = u.position.distance_squared_to(e.position)
			if d < bd:
				bd = d
				best = e
	return best


func pick_target(u):
	if kingdom != null:
		if not war:
			return null
		if duel_active:
			if u.kind != "hero":
				return null
			var ot := duel_other(u.team)
			return team_king(ot) if ot >= 0 else null
	var h = hunt.get(u.team)
	if u.kind == "cav" and h != null and is_instance_valid(h) and not h.dead and randf() < 0.85:
		return h
	var best = null
	var bs := 1e18
	for ti in nk:
		if not hostile(u.team, ti):
			continue
		for e in by_team[ti]:
			if e.dead or e.kind == "villager":
				continue
			var d: float = u.position.distance_squared_to(e.position)
			var s := d
			if u.kind == "cav" and e.kind == "archer":
				s *= 0.3
			elif u.kind == "archer":
				s = d * (0.4 + e.hp / e.max_hp)
			if e.kind == "hero":
				s *= 0.7
			if s < bs:
				bs = s
				best = e
	return best


func enemy_front(u) -> Vector3:
	var t = nearest_enemy(u, 1e9)
	if t != null:
		return t.position
	if kingdom != null:
		var ft := foe(u.team)
		if u.strike_foe >= 0 and kingdom.castle_alive(u.strike_foe):
			ft = u.strike_foe
		if kingdom.castle_alive(ft):
			var g: Vector3 = kingdom.gate_out(ft)
			return g
	return Vector3(u.position.x, 0, 0)


func get_order(owner: int, kind: String) -> Dictionary:
	var o: Dictionary = orders.get(owner, {})
	return o.get(kind, {"mode": HOLD, "pos": Vector3.ZERO})


func anchor_for(u, ord: Dictionary) -> Vector3:
	var mode: int = ord.mode
	var dz := 1.0 if u.team == 0 else -1.0
	if mode == RETREAT:
		if kingdom != null:
			return kingdom.home_pos(u.team)
		return Vector3(u.position.x * 0.9, 0, -64.0 * dz)
	if mode == FOLLOW:
		var h = heroes.get(u.owner_id)
		if h != null and is_instance_valid(h) and not h.dead:
			return h.position + u.slot
		return u.position
	return ord.pos + u.slot


# ================================================================== AI commander
func _ai_think(t: int) -> void:
	var owner := -100 - t
	var mine: Array = by_team[t]
	var theirs: Array = by_team[1 - t]
	if mine.is_empty() or theirs.is_empty() or not orders.has(owner):
		return
	var my_pow := 0.0
	var th_pow := 0.0
	var mc := Vector3.ZERO
	var tc := Vector3.ZERO
	var enemy_hero = null
	for u in mine:
		my_pow += u.hp * (1.3 if u.kind == "cav" else 1.0)
		mc += u.position
	for u in theirs:
		th_pow += u.hp * (1.3 if u.kind == "cav" else 1.0)
		tc += u.position
		if u.kind == "hero":
			enemy_hero = u
	mc /= mine.size()
	tc /= theirs.size()
	var ratio := my_pow / maxf(th_pow, 1.0)
	var dz := 1.0 if t == 0 else -1.0
	var dist := mc.distance_to(tc)
	# assassinate an exposed enemy commander with cavalry
	hunt[t] = null
	if enemy_hero != null:
		var near := 0
		for u in theirs:
			if u != enemy_hero and u.position.distance_to(enemy_hero.position) < 14.0:
				near += 1
		if near < 6:
			hunt[t] = enemy_hero
	var base := Vector3(0, 0, -52.0 * dz)
	var line := Vector3(0, 0, -34.0 * dz)
	var o: Dictionary = orders[owner]
	var pressure := game_time > 45.0
	if ratio > 1.25 or pressure:
		o.sword = {"mode": ADVANCE, "pos": line}
		o.archer = {"mode": ADVANCE, "pos": line}
		o.cav = {"mode": CHARGE, "pos": line}
	elif ratio >= 0.7:
		var close := dist < 34.0
		o.sword = {"mode": ADVANCE if close else HOLD, "pos": line}
		o.archer = {"mode": HOLD, "pos": line + Vector3(0, 0, -4.0 * dz)}
		o.cav = {"mode": CHARGE if (hunt[t] != null or close) else HOLD, "pos": line}
	elif ratio >= 0.4:
		o.sword = {"mode": HOLD, "pos": base}
		o.archer = {"mode": HOLD, "pos": base + Vector3(0, 0, -6.0 * dz)}
		o.cav = {"mode": CHARGE if hunt[t] != null else HOLD, "pos": base}
	else:
		o.sword = {"mode": CHARGE, "pos": base}
		o.archer = {"mode": HOLD, "pos": base}
		o.cav = {"mode": CHARGE, "pos": base}


# ================================================================== combat (host)
func melee_hit(a, t, dmg: float, pw: bool, charge: bool) -> void:
	t.take_damage(dmg)
	var p: Vector3 = t.position + Vector3(0, 1.2, 0)
	var k := 4 if charge else 0
	if pw or charge:
		var kb: Vector3 = t.position - a.position
		kb.y = 0.0
		if kb.length() > 0.01 and t.kind != "hero":
			t.position += kb.normalized() * 1.6
	_fx(k, p)
	if net.online:
		fx.rpc(k, p)


func fire_arrow(u, t) -> void:
	var fwd := Vector3(sin(u.rotation.y), 0, cos(u.rotation.y))
	var from: Vector3 = u.position + Vector3(0, 1.5, 0) + fwd * 0.4
	var dist: float = u.position.distance_to(t.position)
	var dur := clampf(dist / 28.0, 0.35, 1.6)
	var tf := Vector3(sin(t.rotation.y), 0, cos(t.rotation.y))
	var to: Vector3 = t.position + tf * t.sim_speed * dur * 0.8 + Vector3(0, 1.0, 0)
	var dmg: float = UnitS.KINDS.archer.dmg * (1.35 if u.buff_t > 0.0 else 1.0)
	_spawn_arrow(from, to, dur, u.team, dmg, true)
	sfx.play("twang", from, -8.0)
	if net.online:
		arrow_fx.rpc(from, to, dur)


func _spawn_arrow(from: Vector3, to: Vector3, dur: float, team: int, dmg: float, live: bool) -> void:
	var a = ArrowS.new()
	a.battle = self
	a.from_p = from
	a.to_p = to
	a.dur = dur
	a.team = team
	a.dmg = dmg
	a.live = live
	add_child(a)


func arrow_land(a) -> void:
	var best = null
	var bd := 2.0
	for ti in nk:
		if not hostile(a.team, ti):
			continue
		for e in by_team[ti]:
			if e.dead or e.kind == "villager":
				continue
			var d := Vector2(e.position.x - a.to_p.x, e.position.z - a.to_p.z).length()
			if d < bd:
				bd = d
				best = e
	if best != null:
		best.take_damage(a.dmg)
		var p: Vector3 = best.position + Vector3(0, 1.2, 0)
		_fx(1, p)
		if net.online:
			fx.rpc(1, p)


func on_death(u) -> void:
	var p: Vector3 = u.position + Vector3(0, 1.0, 0)
	_fx(2, p)
	if net.online:
		fx.rpc(2, p)
	if u.kind == "hero":
		_fx(6, p)
		if net.online:
			fx.rpc(6, p)
		if kingdom != null:
			kingdom.on_king_death(u)


func _check_end(dt: float) -> void:
	end_t -= dt
	if end_t > 0.0:
		return
	end_t = 0.5
	if kingdom != null:
		return
	if by_team[0].is_empty() or by_team[1].is_empty():
		over = true
		var winner := 1 if by_team[0].is_empty() else 0
		_end(winner)
		if net.online:
			end_msg.rpc(winner)


# ================================================================== rpcs
@rpc("authority", "unreliable_ordered")
func snap(d: PackedFloat64Array) -> void:
	if is_srv:
		return
	var n := d.size() / 9
	for i in n:
		var o := i * 9
		var id := int(d[o])
		var u = units.get(id)
		if u == null:
			u = _make_unit(KIND_IDS[int(d[o + 1])], int(d[o + 2]), int(d[o + 3]), Vector3(d[o + 4], 0, d[o + 5]), id)
			u.rotation.y = d[o + 6]
		u.tpos = Vector3(d[o + 4], 0, d[o + 5])
		u.tyaw = d[o + 6]
		u.hp = d[o + 7]
		u.last_seen = game_time
		var fl := int(d[o + 8])
		var m := (fl & 2) != 0
		if m != u.mounted:
			u.set_mounted(m)
		if u.kind == "villager":
			u.set_carry((fl & 4) != 0)
		if (fl & 1) != 0 and u.swing < 0.3:
			u.swing = 1.0
		if u.hp <= 0.0 and not u.dead:
			u.die()


@rpc("authority", "unreliable")
func fx(kind: int, p: Vector3) -> void:
	_fx(kind, p)


@rpc("authority", "unreliable")
func arrow_fx(a: Vector3, b: Vector3, dur: float) -> void:
	_spawn_arrow(a, b, dur, 0, 0.0, false)
	sfx.play("twang", a, -8.0)


# Kingdom mode: the match ends (castle destroyed or a king fell in the duel).
func finish(winner: int, _why := "") -> void:
	if over or not is_srv:
		return
	over = true
	_end(winner)
	if net.online:
		end_msg.rpc(winner)


func fire_arrow_pos(from: Vector3, t, team: int, dmg: float) -> void:
	var dist: float = from.distance_to(t.position)
	var dur := clampf(dist / 30.0, 0.4, 1.6)
	var to: Vector3 = t.position + Vector3(0, 1.0, 0)
	_spawn_arrow(from, to, dur, team, dmg, true)
	sfx.play("twang", from, -4.0)
	if net.online:
		arrow_fx.rpc(from, to, dur)


# A soldier hits the enemy castle wall (kingdom war).
func castle_hit(u, dmg: float) -> void:
	if kingdom == null:
		return
	var ft: int = kingdom.target_castle(u)
	if ft < 0:
		return
	kingdom.damage_castle(ft, dmg * kingdom.SIEGE_MULT, u.team)
	var p: Vector3 = lw(ft, Vector3(0, 4.0, -71.0))
	p.x = u.position.x
	p.z = u.position.z
	_fx(0, p)
	if net.online:
		fx.rpc(0, p)


func _sph_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


# Big centred title text (e.g. "WAR!").
func banner(text: String, col: Color, secs: float) -> void:
	if not hud.has("banner"):
		return
	var b: Label = hud.banner
	b.text = LocS.t(text)
	b.add_theme_color_override("font_color", col)
	b.modulate.a = 0.0
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(1.5, 1.5)
	if banner_tw != null and banner_tw.is_valid():
		banner_tw.kill()
	banner_tw = create_tween()
	banner_tw.tween_property(b, "modulate:a", 1.0, 0.25)
	banner_tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.tween_interval(maxf(0.2, secs - 0.9))
	banner_tw.tween_property(b, "modulate:a", 0.0, 0.6)
	sfx.play_ui("horn", -3.0)


# Cinematic orbit around a point (cut-scene camera) with letterbox bars.
func cine_orbit(c: Vector3, radius: float, height: float, secs: float, turns: float) -> void:
	if intro or over:
		return
	var a0 := cam_yaw + PI
	if cam != null:
		a0 = atan2(cam.position.x - c.x, cam.position.z - c.z)
	cine = {"mode": "orbit", "c": c, "r": radius, "h": height, "t": 0.0, "dur": secs, "a0": a0, "turns": turns}
	_cine_bars(secs)


func cine_shot(from_a: Vector3, from_b: Vector3, look_a: Vector3, look_b: Vector3, secs: float) -> void:
	if intro or over:
		return
	cine = {"mode": "shot", "a": from_a, "b": from_b, "la": look_a, "lb": look_b, "t": 0.0, "dur": secs}
	_cine_bars(secs)


func _cine_bars(secs: float) -> void:
	var tb := create_tween()
	tb.tween_property(hud.bar_top, "size:y", vs.y * 0.09, 0.4)
	tb.parallel().tween_property(hud.bar_bot, "size:y", vs.y * 0.09, 0.4)
	tb.tween_interval(maxf(0.1, secs - 0.8))
	tb.tween_property(hud.bar_top, "size:y", 0.0, 0.4)
	tb.parallel().tween_property(hud.bar_bot, "size:y", 0.0, 0.4)


func _cine_step(dt: float) -> void:
	cine.t += dt
	var k: float = clampf(cine.t / cine.dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	if cine.mode == "shot":
		cam.position = Vector3(cine.a).lerp(Vector3(cine.b), e)
		cam.look_at(Vector3(cine.la).lerp(Vector3(cine.lb), e))
		if cine.t >= cine.dur:
			cine = {}
		return
	var a: float = cine.a0 + e * TAU * float(cine.turns) * 0.5
	var c: Vector3 = cine.c
	var r: float = lerpf(float(cine.r), float(cine.r) * 0.8, e)
	cam.position = c + Vector3(sin(a) * r, lerpf(float(cine.h), float(cine.h) * 0.7, e), cos(a) * r)
	cam.look_at(c + Vector3(0, 3.0, 0))
	if cine.t >= cine.dur:
		cine = {}


@rpc("authority", "reliable")
func end_msg(winner: int) -> void:
	if is_srv:
		return
	over = true
	_end(winner)


@rpc("any_peer", "unreliable")
func input_msg(mv: Vector2) -> void:
	if not is_srv:
		return
	var h = heroes.get(multiplayer.get_remote_sender_id())
	if h != null and is_instance_valid(h) and not h.dead:
		h.move_in = Vector3(mv.x, 0, mv.y)


@rpc("any_peer", "reliable")
func action_msg(act: String, arg: int) -> void:
	if is_srv:
		_do_action(multiplayer.get_remote_sender_id(), act, arg)


func _act(act: String, arg := 0) -> void:
	if intro or over:
		return
	if is_srv:
		_do_action(my_id, act, arg)
	else:
		action_msg.rpc_id(1, act, arg)


func _do_action(owner: int, act: String, arg: int) -> void:
	var h = heroes.get(owner)
	if h == null or not is_instance_valid(h) or h.dead or not running:
		return
	match act:
		"mount":
			if not HORSE_RIDING:
				if owner == my_id:
					_toast("Horse riding - coming soon!", 2.5)
				return
			if h.mount_cd <= 0.0:
				h.mount_cd = 1.0
				h.set_mounted(not h.mounted)
		"power":
			h.power_req = true
		"rally":
			if h.rally_cd <= 0.0:
				h.rally_cd = 25.0
				for u in by_team[h.team]:
					if u.position.distance_to(h.position) < 26.0:
						u.buff_t = 10.0
						u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.15)
				_fx(3, h.position)
				if net.online:
					fx.rpc(3, h.position)
		"order":
			var mode := arg >> 3
			var mask := arg & 7
			var o: Dictionary = orders[owner]
			var ks := ["sword", "archer", "cav"]
			for i in 3:
				if (mask & (1 << i)) != 0:
					o[ks[i]] = {"mode": mode, "pos": h.position}
			if kingdom != null and (mode == ADVANCE or mode == CHARGE):
				kingdom.on_march(owner)


func _send_snap() -> void:
	if not net.online:
		return
	var d := PackedFloat64Array()
	var n := 0
	for u in units.values():
		var fl := (1 if u.swing > 0.6 else 0) | (2 if u.mounted else 0) | (4 if u.carry > 0 else 0)
		d.append_array(PackedFloat64Array([u.uid, KIND_IDS.find(u.kind), u.team, u.owner_id, u.position.x, u.position.z, u.rotation.y, u.hp, fl]))
		n += 1
		if n >= 12:
			snap.rpc(d)
			d = PackedFloat64Array()
			n = 0
	if n > 0:
		snap.rpc(d)


# ================================================================== effects
func _fx(kind: int, p: Vector3) -> void:
	match kind:
		0:
			sfx.play("clang", p)
			_burst(p, Color(1.0, 0.85, 0.4), 14, 5.0, true)
		1:
			sfx.play("thud", p, -4.0)
			_burst(p, Color(0.5, 0.4, 0.3), 6, 2.5, false)
		2:
			sfx.play("death", p, -3.0)
			_burst(p, Color(0.45, 0.35, 0.25), 10, 3.0, false)
		3:
			_rally_fx(p)
		4:
			sfx.play("clang", p, 2.0)
			sfx.play("thud", p, 2.0)
			_burst(p, Color(1.0, 0.9, 0.5), 26, 7.0, true)
			shake = minf(shake + 0.2, 0.6)
		6:
			_slowmo(0.3, 1.6)
	if kind != 3 and cam != null and cam.global_position.distance_to(p) < 22.0:
		shake = minf(shake + 0.015, 0.5)


func _burst(p: Vector3, col: Color, n: int, spd: float, glow: bool) -> void:
	if get_child_count() > 900:
		return
	var pr := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if glow:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 3.0
	m.material = mat
	pr.mesh = m
	pr.amount = n
	pr.one_shot = true
	pr.explosiveness = 1.0
	pr.lifetime = 0.6
	pr.direction = Vector3.UP
	pr.spread = 70.0
	pr.initial_velocity_min = spd * 0.4
	pr.initial_velocity_max = spd
	pr.gravity = Vector3(0, -12, 0)
	pr.position = p
	add_child(pr)
	pr.emitting = true
	get_tree().create_timer(1.3).timeout.connect(pr.queue_free)


func _rally_fx(p: Vector3) -> void:
	sfx.play("horn", p, 4.0)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 32
	ring.mesh = t
	var mat := _mat(Color(1.0, 0.85, 0.3, 0.9), 0.5, 0.0, 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(p.x, 0.3, p.z)
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(26, 1, 26), 0.9)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(ring.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.light_energy = 8.0
	l.omni_range = 40.0
	l.position = p + Vector3(0, 3, 0)
	add_child(l)
	var tl := create_tween()
	tl.tween_property(l, "light_energy", 0.0, 1.0)
	tl.tween_callback(l.queue_free)
	shake = minf(shake + 0.3, 0.6)


func _slowmo(scale: float, secs: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(secs * scale, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ================================================================== intro / end
func _intro() -> void:
	intro = true
	sfx.play_ui("horn", -2.0)
	var tw := create_tween()
	tw.tween_method(_intro_step, 0.0, 1.0, 7.0)
	tw.tween_callback(_intro_done)
	var tb := create_tween()
	tb.tween_property(hud.bar_top, "size:y", vs.y * 0.12, 0.8)
	tb.parallel().tween_property(hud.bar_bot, "size:y", vs.y * 0.12, 0.8)
	hud.title.text = "KINGDOM" if kingdom != null else "MEDIEVAL WARS"
	hud.title.modulate.a = 0.0
	var tt := create_tween()
	tt.tween_property(hud.title, "modulate:a", 1.0, 1.2)
	tt.tween_interval(3.2)
	tt.tween_property(hud.title, "modulate:a", 0.0, 1.5)


func _intro_step(t: float) -> void:
	var dz := 1.0 if my_team == 0 else -1.0
	var h = heroes.get(my_id)
	var hp: Vector3 = h.position if h != null else Vector3(0, 0, -52.0 * dz)
	if kingdom != null:
		var kpos: Vector3 = h.position if h != null else kingdom.home_pos(my_team)
		var fin := kpos + Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)).normalized() * 8.5 + Vector3(0, 4.0, 0)
		var a: Vector3
		var look: Vector3
		if t < 0.45:
			var k := t / 0.45
			var e := k * k * (3.0 - 2.0 * k)
			a = lw(my_team, Vector3(-60, 40, -36.0)).lerp(lw(my_team, Vector3(0, 11, -62.0)), e)
			look = lw(my_team, Vector3(0, 6, -100.0)).lerp(lw(my_team, Vector3(0, 5, -80.0)), e)
		elif t < 0.75:
			var k2 := (t - 0.45) / 0.3
			var e2 := k2 * k2 * (3.0 - 2.0 * k2)
			a = lw(my_team, Vector3(0, 11, -62.0)).lerp(lw(my_team, Vector3(0, 9, -84.0)), e2)
			look = lw(my_team, Vector3(0, 5, -80.0)).lerp(lw(my_team, Vector3(0, 6, -112.0)), e2)
		else:
			var k3 := (t - 0.75) / 0.25
			var e3 := k3 * k3 * (3.0 - 2.0 * k3)
			a = lw(my_team, Vector3(0, 9, -84.0)).lerp(fin, e3)
			look = lw(my_team, Vector3(0, 6, -112.0)).lerp(kpos + Vector3(0, 1.8, 0), e3)
		cam.position = a
		cam.look_at(look)
		return
	var p0 := Vector3(75, 42, 105.0 * dz)
	var p1 := Vector3(-45, 16, 18.0 * dz)
	var p2 := hp + Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)).normalized() * 8.5 + Vector3(0, 4.0, 0)
	var e := t * t * (3.0 - 2.0 * t)
	var a := p0.lerp(p1, e)
	var b := p1.lerp(p2, e)
	cam.position = a.lerp(b, e)
	var look := Vector3(0, 3, 70.0 * dz).lerp(hp + Vector3(0, 1.8, 0), e)
	cam.look_at(look)


func _intro_done() -> void:
	intro = false
	running = true
	var tb := create_tween()
	tb.tween_property(hud.bar_top, "size:y", 0.0, 0.6)
	tb.parallel().tween_property(hud.bar_bot, "size:y", 0.0, 0.6)
	if kingdom != null:
		_toast("Build your city: open CITY. Hire villagers, build houses, train soldiers.", 7.0)
	else:
		_toast("Pick a group, then an order. Advance to attack!", 5.0)


func _end(winner: int) -> void:
	var won := winner == my_team
	hud.title.text = "VICTORY!" if won else "DEFEAT"
	hud.title.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if won else Color(0.9, 0.2, 0.2))
	hud.title.modulate.a = 0.0
	create_tween().tween_property(hud.title, "modulate:a", 1.0, 1.0)
	_slowmo(0.35, 2.0)
	sfx.play_ui("horn")
	hud.menu_btn.visible = true
	var tb := create_tween()
	tb.tween_property(hud.bar_top, "size:y", vs.y * 0.1, 1.0)
	tb.parallel().tween_property(hud.bar_bot, "size:y", vs.y * 0.1, 1.0)


# ================================================================== HUD / input
func _tbtn(parent: Node, txt: String, pos: Vector2, sz: Vector2, cb: Callable, fs := 24) -> Dictionary:
	var b := TouchScreenButton.new()
	var sh := RectangleShape2D.new()
	sh.size = sz
	b.shape = sh
	b.position = pos + sz * 0.5
	parent.add_child(b)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = sz
	bg.position = -sz * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	var lb := Label.new()
	lb.text = txt
	lb.size = sz
	lb.position = -sz * 0.5
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_size_override("font_size", int(fs * ui_u))
	b.add_child(lb)
	b.pressed.connect(cb)
	rects.append(Rect2(pos, sz))
	return {"btn": b, "bg": bg, "lbl": lb}


func _circle_panel(sz: float, col: Color) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(sz))
	p.add_theme_stylebox_override("panel", s)
	p.size = Vector2(sz, sz)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_hud() -> void:
	vs = get_viewport().get_visible_rect().size
	ui_u = clampf(minf(vs.x, vs.y) / 720.0, 0.6, 2.2)
	if vs.y > vs.x:
		ui_u = clampf(vs.x / 720.0, 0.6, 2.2)
	var u := ui_u
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	hud["root"] = root

	hud["top"] = Label.new()
	hud.top.position = Vector2(20, 12) * u
	hud.top.add_theme_font_size_override("font_size", int(22 * u))
	hud.top.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.top.add_theme_constant_override("outline_size", 6)
	root.add_child(hud.top)

	hud["hp"] = ProgressBar.new()
	hud.hp.position = Vector2(20, 56) * u
	hud.hp.size = Vector2(300, 18) * u
	hud.hp.show_percentage = false
	hud.hp.max_value = 450.0
	hud.hp.value = 450.0
	hud.hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud.hp)

	hud["msg"] = Label.new()
	hud.msg.position = Vector2(vs.x * 0.16, vs.y * 0.34)
	hud.msg.size = Vector2(vs.x * 0.68, 60 * u)
	hud.msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.msg.add_theme_font_size_override("font_size", int(27 * u))
	hud.msg.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.msg.add_theme_constant_override("outline_size", 8)
	hud.msg.modulate.a = 0.0
	root.add_child(hud.msg)

	hud["title"] = Label.new()
	hud.title.position = Vector2(0, vs.y * 0.38)
	hud.title.size = Vector2(vs.x, 120 * u)
	hud.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.title.add_theme_font_size_override("font_size", int(84 * u))
	hud.title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	hud.title.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
	hud.title.add_theme_constant_override("outline_size", 14)
	hud.title.modulate.a = 0.0
	root.add_child(hud.title)

	hud["banner"] = Label.new()
	hud.banner.position = Vector2(0, vs.y * 0.22)
	hud.banner.size = Vector2(vs.x, 90 * u)
	hud.banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.banner.add_theme_font_size_override("font_size", int(64 * u))
	hud.banner.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
	hud.banner.add_theme_constant_override("outline_size", int(14 * u))
	hud.banner.modulate.a = 0.0
	hud.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud.banner)

	hud["bar_top"] = ColorRect.new()
	hud.bar_top.color = Color.BLACK
	hud.bar_top.size = Vector2(vs.x, 0)
	hud.bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud.bar_top)
	hud["bar_bot"] = ColorRect.new()
	hud.bar_bot.color = Color.BLACK
	hud.bar_bot.size = Vector2(vs.x, 0)
	hud.bar_bot.position.y = vs.y
	hud.bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud.bar_bot)
	hud.bar_bot.resized.connect(func(): hud.bar_bot.position.y = vs.y - hud.bar_bot.size.y)

	hud["menu_btn"] = Button.new()
	hud.menu_btn.text = "Main Menu"
	hud.menu_btn.size = Vector2(260, 80) * u
	hud.menu_btn.position = Vector2(vs.x * 0.5 - 130 * u, vs.y * 0.62)
	hud.menu_btn.add_theme_font_size_override("font_size", int(30 * u))
	hud.menu_btn.visible = false
	hud.menu_btn.pressed.connect(func(): get_node("/root/Main").back_to_menu())
	root.add_child(hud.menu_btn)

	var ob := Button.new()
	ob.text = "Settings"
	ob.position = Vector2(vs.x - 400 * u, 90 * u)
	ob.size = Vector2(190, 52) * u
	ob.add_theme_font_size_override("font_size", int(20 * u))
	ob.pressed.connect(_open_options)
	root.add_child(ob)
	hud["opt_btn"] = ob
	if String(cfg.get("mode", "battle")) != "kingdom":
		var bm = BattleMapS.new()
		bm.name = "BattleMap"
		bm.battle = self
		add_child(bm)
		bm.build_ui(root, u, vs)

	# joystick
	hud["stick_base"] = _circle_panel(150 * u, Color(1, 1, 1, 0.12))
	hud["stick_knob"] = _circle_panel(64 * u, Color(1, 1, 1, 0.35))
	root.add_child(hud.stick_base)
	root.add_child(hud.stick_knob)

	# touch buttons (TouchScreenButton = true multi-touch)
	var tl := Node2D.new()
	root.add_child(tl)
	hud["tl"] = tl
	_tbtn(tl, "STRIKE", Vector2(vs.x - 170 * u, vs.y - 170 * u), Vector2(150, 150) * u, func(): _act("power"), 26)
	hud["mount"] = _tbtn(tl, "MOUNT" if HORSE_RIDING else "HORSE\nSOON", Vector2(vs.x - 290 * u, vs.y - 120 * u), Vector2(110, 100) * u, func(): _act("mount"), 20)
	if not HORSE_RIDING:
		hud.mount.bg.color = Color(0.15, 0.15, 0.15, 0.55)
		hud.mount.lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hud["rally"] = _tbtn(tl, "RALLY", Vector2(vs.x - 290 * u, vs.y - 230 * u), Vector2(110, 100) * u, func(): _rally_press(), 22)
	var gx := vs.x - 200 * u
	var names := ["SWD", "ARC", "CAV"]
	hud["chips"] = []
	for i in 3:
		var bit := 1 << i
		var c := _tbtn(tl, names[i], Vector2(gx + i * 66 * u, 90 * u), Vector2(62, 52) * u, func(): _toggle_sel(bit), 20)
		hud.chips.append(c)
	for i in 5:
		var mode := i
		_tbtn(tl, MODE_NAMES[i], Vector2(gx, 150 * u + i * 62 * u), Vector2(192, 56) * u, func(): _order(mode), 22)
	_refresh_chips()


func _open_options() -> void:
	if modal and not hud.has("opt_panel"):
		return
	if hud.has("opt_panel"):
		hud.opt_panel.queue_free()
		hud.erase("opt_panel")
		modal = false
		return
	var u := ui_u
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.root.add_child(dim)
	hud["opt_panel"] = dim
	modal = true
	var pc := PanelContainer.new()
	pc.position = Vector2(vs.x * 0.5 - 250 * u, 60 * u)
	dim.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * u))
	pc.add_child(vb)
	var mk := func(text: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(500, 62) * u
		b.add_theme_font_size_override("font_size", int(26 * u))
		b.pressed.connect(cb)
		vb.add_child(b)
		return b
	var qb: Button = mk.call("Quality: %s" % SettingsS.quality_name(), func(): pass)
	var fb: Button = mk.call("Frame rate: %d" % SettingsS.fps, func(): pass)
	var sb: Button = mk.call("FPS counter: %s" % ("ON" if SettingsS.show_fps else "OFF"), func(): pass)
	var refresh := func():
		qb.text = LocS.t("Quality: %s" % SettingsS.quality_name())
		fb.text = LocS.t("Frame rate: %d" % SettingsS.fps)
		sb.text = LocS.t("FPS counter: %s" % ("ON" if SettingsS.show_fps else "OFF"))
	refresh.call()
	qb.pressed.connect(func():
		SettingsS.quality = (SettingsS.quality + 1) % 3
		SettingsS.save()
		SettingsS.apply_scene(self)
		refresh.call())
	fb.pressed.connect(func():
		SettingsS.fps = {30: 60, 60: 120, 120: 30}[SettingsS.fps]
		SettingsS.save()
		SettingsS.apply_global()
		refresh.call())
	sb.pressed.connect(func():
		SettingsS.show_fps = not SettingsS.show_fps
		SettingsS.save()
		refresh.call())
	mk.call("Main Menu", func(): get_node("/root/Main").back_to_menu())
	mk.call("Close", func(): _open_options())


func _toggle_sel(bit: int) -> void:
	sel ^= bit
	if sel == 0:
		sel = bit
	_refresh_chips()


func _refresh_chips() -> void:
	for i in 3:
		var on := (sel & (1 << i)) != 0
		hud.chips[i].bg.color = Color(0.9, 0.7, 0.2, 0.75) if on else Color(0, 0, 0, 0.5)


func _order(mode: int) -> void:
	_act("order", (mode << 3) | sel)
	_toast(MODE_NAMES[mode], 1.2)
	sfx.play_ui("twang", -10.0)


func _rally_press() -> void:
	if local_rally > 0.0:
		return
	local_rally = 25.0
	_act("rally")


func _toast(text: String, secs: float) -> void:
	hud.msg.text = LocS.t(text)
	hud.msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(hud.msg, "modulate:a", 0.0, 0.6)


func _in_button(p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: _act("power")
			KEY_E: _act("mount")
			KEY_Q: _rally_press()
			KEY_1: _order(FOLLOW)
			KEY_2: _order(ADVANCE)
			KEY_3: _order(HOLD)
			KEY_4: _order(CHARGE)
			KEY_5: _order(RETREAT)
		return
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		cam_yaw -= e.relative.x * 0.005
		cam_pitch = clampf(cam_pitch + e.relative.y * 0.004, 0.12, 1.2)
		return
	if intro or over:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if _in_button(e.position):
				return
			if e.position.x < vs.x * 0.42 and e.position.y > vs.y * 0.3 and stick_id == -1:
				stick_id = e.index
				stick_origin = e.position
				stick_vec = Vector2.ZERO
			elif e.position.x > vs.x * 0.42 and look_id == -1:
				look_id = e.index
		else:
			if e.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
			if e.index == look_id:
				look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_vec = ((e.position - stick_origin) / (80.0 * ui_u)).limit_length(1.0)
		elif e.index == look_id:
			cam_yaw -= e.relative.x * 0.006
			cam_pitch = clampf(cam_pitch + e.relative.y * 0.004, 0.12, 1.2)


# ================================================================== frame loop
func _physics_process(dt: float) -> void:
	game_time += dt
	if not is_srv:
		return
	for i in nk:
		by_team[i] = []
	grid.clear()
	for u in units.values():
		if u.dead:
			continue
		by_team[u.team].append(u)
		var key := Vector2i(floori(u.position.x / 2.0), floori(u.position.z / 2.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(u)
	if running and not over:
		ai_t -= dt
		if ai_t <= 0.0:
			ai_t = 1.2
			if kingdom == null:
				for t in ai_teams:
					_ai_think(t)
		_check_end(dt)
	snap_t -= dt
	if snap_t <= 0.0:
		snap_t = 0.1
		_send_snap()


func _process(dt: float) -> void:
	# clients: drop units the host no longer reports
	if not is_srv:
		for u in units.values():
			if game_time - u.last_seen > 2.5:
				remove_unit(u)
	local_rally = maxf(0.0, local_rally - dt)
	loc_t -= dt
	if loc_t <= 0.0:
		loc_t = 0.3
		LocS.apply_tree(hud.root)
		if kingdom != null and kingdom.ui.has("root"):
			LocS.apply_tree(kingdom.ui.root)
	# movement input -> world direction
	var v := stick_vec
	var k := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): k.x -= 1.0
	if Input.is_key_pressed(KEY_D): k.x += 1.0
	if Input.is_key_pressed(KEY_W): k.y -= 1.0
	if Input.is_key_pressed(KEY_S): k.y += 1.0
	if k.length() > 0.1:
		v = k.limit_length(1.0)
	var f := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var r := f.cross(Vector3.UP)
	var mv := f * (-v.y) + r * v.x
	if intro or over:
		mv = Vector3.ZERO
	var h = heroes.get(my_id)
	if is_srv:
		var drv = null
		if admin and admin_ctrl and kingdom != null and kingdom.vteam() != my_team and not net.online:
			for uu in units.values():
				if uu.kind == "hero" and uu.team == kingdom.vteam() and not uu.dead:
					drv = uu
					uu.driven = true
					break
		for uu2 in units.values():
			if uu2.driven and uu2 != drv:
				uu2.driven = false
				uu2.move_in = Vector3.ZERO
		if drv != null:
			drv.move_in = mv
			if h != null and is_instance_valid(h):
				h.move_in = Vector3.ZERO
		elif h != null and is_instance_valid(h):
			h.move_in = mv
	else:
		send_t -= dt
		if send_t <= 0.0:
			send_t = 0.05
			input_msg.rpc_id(1, Vector2(mv.x, mv.z))
	_update_camera(dt, h)
	_update_hud(dt, h, v)


func _update_camera(dt: float, h) -> void:
	if intro:
		return
	if not cine.is_empty():
		_cine_step(dt)
		return
	if admin and kingdom != null and kingdom.vteam() != my_team:
		h = null
		for uu in units.values():
			if uu.kind == "hero" and uu.team == kingdom.vteam() and not uu.dead:
				h = uu
				break
		if h == null:
			spec_pos = kingdom.home_pos(kingdom.vteam())
	var alive: bool = h != null and is_instance_valid(h) and not h.dead
	if alive:
		cam_focus = cam_focus.lerp(h.position, clampf(dt * 9.0, 0.0, 1.0))
	else:
		cam_focus = cam_focus.lerp(spec_pos, clampf(dt * 2.0, 0.0, 1.0))
	var dist := cam_dist * (1.4 if (alive and h.mounted) else 1.0)
	if not alive:
		dist = 22.0
	var off := Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch)) * dist
	var tgt := cam_focus + Vector3(0, 1.8, 0)
	cam.position = cam.position.lerp(tgt + off, clampf(dt * 10.0, 0.0, 1.0))
	cam.look_at(tgt)
	shake = maxf(0.0, shake - dt * 1.3)
	cam.h_offset = randf_range(-1.0, 1.0) * shake
	cam.v_offset = randf_range(-1.0, 1.0) * shake


func _update_hud(dt: float, h, v: Vector2) -> void:
	var u := ui_u
	var base: Vector2 = stick_origin if stick_id != -1 else Vector2(130, vs.y - 130) * u
	hud.stick_base.position = base - hud.stick_base.size * 0.5
	hud.stick_knob.position = base + v * 60.0 * u - hud.stick_knob.size * 0.5
	hud.rally.lbl.text = LocS.t("RALLY" if local_rally <= 0.0 else "%ds" % ceili(local_rally))
	hud.rally.bg.color = Color(0, 0, 0, 0.5) if local_rally > 0.0 else Color(0.8, 0.6, 0.1, 0.7)
	hud_t -= dt
	if hud_t > 0.0:
		return
	hud_t = 0.4
	var mine := 0
	var enemy := 0
	var sp := Vector3.ZERO
	for x in units.values():
		if x.dead or x.kind == "villager":
			continue
		if x.team == my_team:
			mine += 1
			sp += x.position
		else:
			enemy += 1
	if mine > 0:
		spec_pos = sp / mine
	hud.top.text = LocS.t(("ARMY: %d   ENEMY: %d" if kingdom != null else "YOUR ARMY: %d     ENEMY: %d") % [mine, enemy])
	if h != null and is_instance_valid(h):
		hud.hp.value = h.hp
		hud.hp.max_value = h.max_hp
