extends Node3D
# A soldier: "sword", "archer", "cav" or "hero" (the player's commander).
# Model faces +Z. Simulated only on the host; clients run it as a puppet.

const M_FOLLOW := 0
const M_ADVANCE := 1
const M_HOLD := 2
const M_CHARGE := 3
const M_RETREAT := 4

const KINDS := {
	"sword": {"hp": 100.0, "speed": 4.4, "dmg": 14.0, "range": 2.0, "cd": 0.8},
	"archer": {"hp": 60.0, "speed": 3.9, "dmg": 12.0, "range": 26.0, "cd": 1.9},
	"cav": {"hp": 150.0, "speed": 9.0, "dmg": 20.0, "range": 2.4, "cd": 1.0},
	"hero": {"hp": 450.0, "speed": 5.2, "dmg": 36.0, "range": 2.6, "cd": 0.6},
	"villager": {"hp": 40.0, "speed": 3.4, "dmg": 0.0, "range": 1.5, "cd": 1.0},
}

const Models := preload("res://game/models.gd")

static var _cache := {}

var rig = null      # custom model rig (see models.gd), null = procedural body
var hrig = null     # custom horse rig
var ride_y := 0.85
var _sw_prev := 0.0
var battle
var uid := 0
var kind := "sword"
var team := 0
var owner_id := 0
var hp := 100.0
var max_hp := 100.0
var mounted := false
var puppet := false
var dead := false
var base_speed := 4.0
var atk_cd := 0.0
var swing := 0.0
var power := false
var power_req := false
var target = null
var think_t := 0.0
var move_in := Vector3.ZERO
var buff_t := 0.0
var rally_cd := 0.0
var mount_cd := 0.0
var last_seen := 0.0
var tpos := Vector3.ZERO
var tyaw := 0.0
var sim_speed := 0.0
var anim_t := 0.0
var slot := Vector3.ZERO
var flash := 0.0
var sc := 1.0
var body: Node3D
var arm: Node3D
var horse: Node3D
var legs := []
var hlegs := []
var bar: MeshInstance3D
var bar_mat: StandardMaterial3D
var carry_node: Node3D = null
var carry := 0
var vstate := 0
var vtree := -1
var vtimer := 0.0
var _vswing := 0.0
var _dt := 0.016


# ---------------------------------------------------------------- cached assets
static func _cm(key: String, mk: Callable):
	if not _cache.has(key):
		_cache[key] = mk.call()
	return _cache[key]


func _box(sz: Vector3) -> Mesh:
	return _cm("b%s" % sz, func():
		var b := BoxMesh.new()
		b.size = sz
		return b)


func _cap(r: float, h: float) -> Mesh:
	return _cm("c%s_%s" % [r, h], func():
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = h
		c.radial_segments = 12
		c.rings = 3
		return c)


func _sph(r: float) -> Mesh:
	return _cm("s%s" % r, func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 14
		s.rings = 7
		return s)


func _cyl(r: float, h: float) -> Mesh:
	return _cm("y%s_%s" % [r, h], func():
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 14
		c.rings = 1
		return c)


func _mat(c: Color, metal := 0.0, rough := 0.7, emis := 0.0) -> StandardMaterial3D:
	return _cm("m%s_%s_%s_%s" % [c, metal, rough, emis], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		if emis > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emis
		return m)


func _add(parent: Node3D, mesh: Mesh, mat: Material, p := Vector3.ZERO, r := Vector3.ZERO, shadow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = p
	m.rotation = r
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


# ---------------------------------------------------------------- setup
func setup(k: String, t: int, o: int, b) -> void:
	kind = k
	team = t
	owner_id = o
	battle = b
	var s: Dictionary = KINDS[k]
	max_hp = s.hp
	hp = max_hp
	base_speed = s.speed
	anim_t = randf() * 10.0
	_build()
	if k == "cav" or (k == "hero" and o < 0 and battle.HORSE_RIDING):
		set_mounted(true)


func _build() -> void:
	var hero := kind == "hero"
	sc = 1.22 if hero else 1.0
	var tc := Color(0.12, 0.32, 0.95) if team == 0 else Color(0.9, 0.12, 0.1)
	var cloth := _mat(tc, 0.0, 0.8)
	var glow := _mat(tc, 0.0, 0.6, 0.6)
	var steel := _mat(Color(0.72, 0.74, 0.8), 0.9, 0.3)
	var gold := _mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var skin := _mat(Color(0.86, 0.66, 0.52), 0.0, 0.9)
	var dark := _mat(Color(0.2, 0.15, 0.12), 0.0, 0.9)
	var wood := _mat(Color(0.45, 0.3, 0.15), 0.0, 0.9)
	var green := _mat(Color(0.2, 0.38, 0.18), 0.0, 0.9)

	body = Node3D.new()
	body.scale = Vector3.ONE * sc
	add_child(body)

	# optional custom model (game/models/<kind>.glb)
	if kind == "villager":
		_build_villager(tc)
		return
	var custom = Models.build(kind)
	if custom != null:
		rig = custom
		sc = 1.0
		body.scale = Vector3.ONE
		body.add_child(rig.root)
		_team_ring(tc)
		arm = Node3D.new()
		body.add_child(arm)
		_make_bar(hero)
		return

	_add(body, _cap(0.27, 1.0), green if kind == "archer" else cloth, Vector3(0, 1.05, 0), Vector3.ZERO, true)
	if kind != "archer":
		_add(body, _box(Vector3(0.5, 0.42, 0.1)), steel, Vector3(0, 1.2, 0.2))
	for sx in [-0.12, 0.12]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.8, 0)
		body.add_child(hip)
		_add(hip, _box(Vector3(0.17, 0.8, 0.2)), dark, Vector3(0, -0.4, 0))
		legs.append(hip)
	_add(body, _sph(0.17), skin, Vector3(0, 1.78, 0.05))
	if kind == "archer":
		_add(body, _sph(0.23), green, Vector3(0, 1.86, -0.03))
	else:
		_add(body, _sph(0.22), steel, Vector3(0, 1.88, -0.02))
	if hero:
		_add(body, _box(Vector3(0.07, 0.34, 0.5)), glow, Vector3(0, 2.15, -0.05))
		_add(body, _box(Vector3(0.55, 1.0, 0.05)), glow, Vector3(0, 1.2, -0.3))
		_add(body, _box(Vector3(0.05, 2.4, 0.05)), wood, Vector3(0, 2.0, -0.38))
		_add(body, _box(Vector3(0.7, 0.55, 0.03)), glow, Vector3(0.38, 3.0, -0.38))
		_add(body, _sph(0.09), gold, Vector3(0, 3.25, -0.38))
		_add(body, _box(Vector3(0.62, 0.12, 0.38)), gold, Vector3(0, 1.55, 0.0))

	arm = Node3D.new()
	arm.position = Vector3(0.38, 1.4, 0.05)
	body.add_child(arm)
	if kind == "cav":
		_add(arm, _box(Vector3(0.05, 0.05, 2.7)), wood, Vector3(0, 0, 1.0))
		_add(arm, _box(Vector3(0.09, 0.09, 0.35)), steel, Vector3(0, 0, 2.45))
		_add(arm, _box(Vector3(0.3, 0.3, 0.03)), glow, Vector3(0, 0.12, 1.7))
	elif kind == "archer":
		_add(arm, _box(Vector3(0.03, 0.03, 0.35)), wood, Vector3(0, 0, 0.3))
		_add(body, _box(Vector3(0.05, 1.15, 0.05)), wood, Vector3(-0.38, 1.35, 0.3))
		_add(body, _box(Vector3(0.012, 1.05, 0.012)), _mat(Color(0.9, 0.9, 0.8)), Vector3(-0.38, 1.35, 0.22))
		_add(body, _box(Vector3(0.14, 0.55, 0.14)), wood, Vector3(0.15, 1.4, -0.32))
	else:
		var bl := 1.25 if hero else 1.0
		_add(arm, _box(Vector3(0.07, 0.02, 1.0 * bl)), steel, Vector3(0, 0, 0.18 + 0.5 * bl))
		_add(arm, _box(Vector3(0.3, 0.04, 0.06)), gold, Vector3(0, 0, 0.18))
		_add(arm, _box(Vector3(0.04, 0.04, 0.22)), dark, Vector3(0, 0, 0.02))
	if kind != "archer":
		var sh := Node3D.new()
		sh.position = Vector3(-0.42, 1.2, 0.15)
		sh.rotation = Vector3(PI / 2.0, 0, 0)
		body.add_child(sh)
		_add(sh, _cyl(0.36, 0.05), steel)
		_add(sh, _cyl(0.30, 0.07), cloth, Vector3(0, 0.01, 0))
		_add(sh, _sph(0.07), gold, Vector3(0, 0.05, 0))

	_make_bar(hero)


func _build_villager(tc: Color) -> void:
	sc = 0.95
	body.scale = Vector3.ONE * sc
	var tunic := _mat(Color(0.52, 0.4, 0.26), 0.0, 0.9)
	var sash := _mat(tc, 0.0, 0.8)
	var skin := _mat(Color(0.86, 0.66, 0.52), 0.0, 0.9)
	var dark := _mat(Color(0.25, 0.18, 0.12), 0.0, 0.9)
	var straw := _mat(Color(0.85, 0.72, 0.35), 0.0, 0.95)
	var wood := _mat(Color(0.45, 0.3, 0.15), 0.0, 0.9)
	var red := _mat(Color(0.95, 0.3, 0.12), 0.5, 0.0, 0.6)
	var custom = Models.build("villager")
	if custom != null:
		rig = custom
		sc = 1.0
		body.scale = Vector3.ONE
		body.add_child(rig.root)
		_team_ring(tc)
	else:
		_add(body, _cap(0.26, 0.95), tunic, Vector3(0, 1.0, 0), Vector3.ZERO, true)
		_add(body, _box(Vector3(0.54, 0.1, 0.34)), sash, Vector3(0, 0.95, 0))
		for sx in [-0.11, 0.11]:
			var hip := Node3D.new()
			hip.position = Vector3(sx, 0.75, 0)
			body.add_child(hip)
			_add(hip, _box(Vector3(0.15, 0.75, 0.18)), dark, Vector3(0, -0.375, 0))
			legs.append(hip)
		_add(body, _sph(0.16), skin, Vector3(0, 1.72, 0.03))
		_add(body, _cyl(0.3, 0.03), straw, Vector3(0, 1.84, 0.03))
		_add(body, _cyl(0.15, 0.14), straw, Vector3(0, 1.92, 0.03))
	# basket on the back, shown while carrying fruit
	carry_node = Node3D.new()
	carry_node.position = Vector3(0, 1.1, -0.3)
	carry_node.visible = false
	body.add_child(carry_node)
	_add(carry_node, _box(Vector3(0.42, 0.34, 0.26)), wood)
	for i in 4:
		_add(carry_node, _sph(0.09), red, Vector3(-0.15 + i * 0.1, 0.2, 0.0))
	arm = Node3D.new()
	arm.position = Vector3(0.34, 1.25, 0.05)
	body.add_child(arm)
	_add(arm, _box(Vector3(0.04, 0.04, 0.7)), wood, Vector3(0, 0, 0.3))
	_make_bar(false)
	bar.position.y = 2.3


func set_carry(v: bool) -> void:
	if carry_node != null:
		carry_node.visible = v


func _team_ring(tc: Color) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.62
	t.rings = 20
	m.mesh = t
	m.material_override = _mat(tc, 0.0, 0.5, 1.5)
	m.position.y = 0.04
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _make_bar(hero: bool) -> void:
	bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.11)
	bar.mesh = q
	bar_mat = StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_mat.billboard_keep_scale = true
	bar_mat.albedo_color = Color(0.2, 0.9, 0.2)
	bar_mat.no_depth_test = true
	bar.material_override = bar_mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position = Vector3(0, 2.6 if not hero else 3.7, 0)
	bar.visible = false
	add_child(bar)


func _build_horse() -> void:
	var hr = Models.build("horse")
	if hr != null:
		hrig = hr
		horse = Node3D.new()
		add_child(horse)
		horse.add_child(hr.root)
		ride_y = Models.HORSE_RIDE_Y
		return
	horse = Node3D.new()
	add_child(horse)
	var white := kind == "hero"
	var hm := _mat(Color(0.92, 0.92, 0.9) if white else Color(0.32, 0.18, 0.1), 0.0, 0.8)
	var dark := _mat(Color(0.1, 0.07, 0.05), 0.0, 0.9)
	var tc := Color(0.12, 0.32, 0.95) if team == 0 else Color(0.9, 0.12, 0.1)
	_add(horse, _box(Vector3(0.6, 0.65, 1.6)), hm, Vector3(0, 1.0, 0), Vector3.ZERO, true)
	_add(horse, _box(Vector3(0.66, 0.67, 0.9)), _mat(tc, 0.0, 0.8), Vector3(0, 1.02, -0.05))
	_add(horse, _box(Vector3(0.28, 0.7, 0.3)), hm, Vector3(0, 1.45, 0.8), Vector3(-0.5, 0, 0))
	_add(horse, _box(Vector3(0.24, 0.26, 0.55)), hm, Vector3(0, 1.75, 1.15))
	_add(horse, _box(Vector3(0.06, 0.6, 0.2)), dark, Vector3(0, 1.5, 0.62), Vector3(-0.5, 0, 0))
	_add(horse, _box(Vector3(0.08, 0.7, 0.1)), dark, Vector3(0, 0.95, -0.88))
	for sx in [-0.2, 0.2]:
		for sz in [0.6, -0.6]:
			var pv := Node3D.new()
			pv.position = Vector3(sx, 0.7, sz)
			horse.add_child(pv)
			_add(pv, _box(Vector3(0.14, 0.7, 0.14)), hm, Vector3(0, -0.35, 0))
			hlegs.append(pv)


func add_marker() -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.95
	t.outer_radius = 1.12
	t.rings = 24
	m.mesh = t
	m.material_override = _mat(Color(1.0, 0.85, 0.3), 0.0, 0.5, 2.0)
	m.position.y = 0.05
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func set_mounted(m: bool) -> void:
	mounted = m
	if m and horse == null:
		_build_horse()
	if horse:
		horse.visible = m
	for l in legs:
		l.visible = not m
	if bar:
		bar.position.y = (2.6 if kind != "hero" else 3.7) + (0.9 if m else 0.0)


# ---------------------------------------------------------------- animation (all peers)
func _process(dt: float) -> void:
	if puppet and not dead:
		var np := position.lerp(tpos, clampf(dt * 12.0, 0.0, 1.0))
		sim_speed = lerpf(sim_speed, (np - position).length() / maxf(dt, 0.0001), clampf(dt * 8.0, 0.0, 1.0))
		position = np
		rotation.y = lerp_angle(rotation.y, tyaw, clampf(dt * 12.0, 0.0, 1.0))
	flash = maxf(0.0, flash - dt * 4.0)
	if dead:
		return
	var mv := sim_speed > 0.4
	anim_t += dt * (1.0 + sim_speed * 0.5)
	var ph := sin(anim_t * 7.0)
	if rig != null or hrig != null:
		_model_anim()
	for i in legs.size():
		legs[i].rotation.x = ph * 0.8 * (1.0 if i == 0 else -1.0) * (1.0 if mv else 0.0)
	for i in hlegs.size():
		hlegs[i].rotation.x = ph * 0.7 * (1.0 if i % 3 == 0 else -1.0) * (1.0 if mv else 0.0)
	body.position.y = (ride_y if mounted else 0.0) + (absf(ph) * 0.05 if (mv and rig == null) else 0.0)
	body.scale = Vector3.ONE * sc * (1.0 + flash * 0.1)
	if swing > 0.0:
		swing = maxf(0.0, swing - dt * (1.5 if power else 2.4))
		var s := 1.0 - swing
		arm.rotation.x = lerpf(-1.8, 1.0, s * s)
	else:
		arm.rotation.x = lerpf(arm.rotation.x, -0.5, clampf(dt * 8.0, 0.0, 1.0))
	var show := hp < max_hp
	bar.visible = show
	if show:
		var r := clampf(hp / max_hp, 0.0, 1.0)
		bar.scale.x = maxf(r, 0.02)
		bar_mat.albedo_color = Color(1.0 - r, r, 0.15)


func _model_anim() -> void:
	if rig != null:
		if swing > 0.9 and _sw_prev <= 0.9 and Models.has_anim(rig, "attack"):
			Models.play(rig, "attack", true)
		if not Models.busy(rig):
			var want := "idle"
			if mounted:
				want = "ride"
			elif sim_speed > 5.0:
				want = "run"
			elif sim_speed > 0.4:
				want = "walk"
			var used: String = Models.play(rig, want)
			if used == "walk":
				rig.player.speed_scale = clampf(sim_speed / 4.2, 0.6, 1.8)
			elif used == "run":
				rig.player.speed_scale = clampf(sim_speed / 7.0, 0.6, 1.8)
			elif rig.player != null:
				rig.player.speed_scale = 1.0
	_sw_prev = swing
	if hrig != null and horse != null and horse.visible:
		var hw := "idle"
		if sim_speed > 5.0:
			hw = "run"
		elif sim_speed > 0.4:
			hw = "walk"
		var hu: String = Models.play(hrig, hw)
		if hu == "walk" and hrig.player != null:
			hrig.player.speed_scale = clampf(sim_speed / 3.0, 0.6, 1.8)
		elif hu == "run" and hrig.player != null:
			hrig.player.speed_scale = clampf(sim_speed / 8.0, 0.6, 1.8)


# ---------------------------------------------------------------- simulation (host only)
func spd() -> float:
	var s := base_speed
	if kind == "hero" and mounted:
		s *= 1.85
	if kind == "hero" and owner_id < 0:
		s *= 0.8
	if buff_t > 0.0:
		s *= 1.15
	return s


func _physics_process(dt: float) -> void:
	if puppet or dead or battle == null or not battle.running:
		return
	_dt = dt
	atk_cd -= dt
	buff_t -= dt
	rally_cd -= dt
	mount_cd -= dt
	if battle.freeze_others and kind != "hero":
		_stop()
		return
	if kind == "villager":
		_villager()
		return
	if kind == "hero" and owner_id >= 0:
		_hero()
	else:
		_ai()
	if kind == "hero" and battle.duel_active:
		_duel_clamp()


func _duel_clamp() -> void:
	var off: Vector3 = position - battle.duel_center
	off.y = 0.0
	var lim: float = battle.duel_r - 0.6
	if off.length() > lim:
		var np: Vector3 = battle.duel_center + off.normalized() * lim
		position.x = np.x
		position.z = np.z


# Villager: walk to a fruit tree, pick fruit, carry it to the castle, repeat.
func _villager() -> void:
	var k = battle.kingdom
	if k == null:
		_stop()
		return
	if _vswing > 0.0:
		_vswing -= _dt
	match vstate:
		0:
			vtimer -= _dt
			_stop()
			if vtimer > 0.0:
				return
			if carry > 0:
				vstate = 3
				return
			vtree = k.pick_tree(team, position)
			if vtree >= 0:
				vstate = 1
			else:
				vtimer = 2.0
		1:
			if not k.tree_has_food(team, vtree):
				vstate = 0
				vtimer = 0.3
				return
			var d: Vector3 = k.tree_at(team, vtree) - position
			d.y = 0.0
			if d.length() < 2.6:
				vstate = 2
				vtimer = 2.6
				_vswing = 0.0
			else:
				_move(d, spd())
		2:
			_stop()
			vtimer -= _dt
			var d: Vector3 = k.tree_at(team, vtree) - position
			_face(d)
			if _vswing <= 0.0:
				_vswing = 0.9
				swing = 1.0
			if vtimer <= 0.0:
				carry = k.take_food(team, vtree, 12.0)
				set_carry(carry > 0)
				vstate = 3 if carry > 0 else 0
				vtimer = 0.2
		3:
			var d: Vector3 = k.depot(team) - position
			d.y = 0.0
			if d.length() < 2.0:
				k.deposit(team, carry)
				battle.sfx.play("coin", position, -14.0, 1.1)
				carry = 0
				set_carry(false)
				vstate = 0
				vtimer = 0.4
			else:
				_move(d, spd())


func _face(d: Vector3) -> void:
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(_dt * 10.0, 0.0, 1.0))


func _move(dir: Vector3, s: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.001:
		sim_speed = lerpf(sim_speed, 0.0, clampf(_dt * 8.0, 0.0, 1.0))
		return
	dir = dir.normalized()
	var push: Vector3 = battle.separation(self)
	var np := position + (dir * s + push * 2.0) * _dt
	np.x = clampf(np.x, -95.0, 95.0)
	np.z = clampf(np.z, -78.0, 78.0)
	sim_speed = lerpf(sim_speed, s, clampf(_dt * 6.0, 0.0, 1.0))
	position = np
	_face(dir)


func _stop() -> void:
	sim_speed = lerpf(sim_speed, 0.0, clampf(_dt * 8.0, 0.0, 1.0))


func _goto(p: Vector3, mult := 1.0) -> void:
	var d := p - position
	d.y = 0.0
	if d.length() < 1.2:
		_stop()
		_face(Vector3(0, 0, 1.0 if team == 0 else -1.0))
	else:
		_move(d, spd() * mult)


func _hero() -> void:
	var s := spd()
	var mvl := move_in.length()
	if mvl > 0.08:
		_move(move_in.normalized(), s * minf(mvl, 1.0))
	else:
		_stop()
	var rng: float = KINDS.hero.range + (0.9 if mounted else 0.0)
	var t = battle.nearest_enemy(self, rng + 0.6)
	if t != null:
		if atk_cd <= 0.0:
			if power_req:
				power_req = false
				_strike(t, 2.3, true)
			else:
				_strike(t, 1.0, false)
		if mvl < 0.08:
			_face(t.position - position)
	elif power_req and atk_cd <= 0.0:
		power_req = false
		atk_cd = 0.8
		swing = 1.0
		power = true


func _ai() -> void:
	think_t -= _dt
	if think_t <= 0.0:
		think_t = 0.3 + randf() * 0.3
		target = battle.pick_target(self)
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
	if battle.duel_active and kind == "hero":
		var kg = battle.team_king(1 - team)
		if kg != null:
			target = kg
			_engage(M_CHARGE)
			return
	var okind := "sword" if kind == "hero" else kind
	var ord: Dictionary = battle.get_order(owner_id, okind)
	var mode: int = ord.mode
	if battle.kingdom != null and battle.war and target == null and kind != "hero" \
			and (mode == M_ADVANCE or mode == M_CHARGE) and battle.kingdom.castle_alive(1 - team):
		if _siege():
			return
	var anchor: Vector3 = battle.anchor_for(self, ord)
	if mode == M_RETREAT:
		_goto(anchor, 1.15)
		return
	var engage_r := 999.0
	if mode == M_HOLD:
		engage_r = 15.0
	elif mode == M_FOLLOW:
		engage_r = 13.0
	elif kind == "hero" and mode != M_CHARGE:
		engage_r = 20.0
	if kind == "archer":
		engage_r = maxf(engage_r, KINDS.archer.range)
	if target != null and position.distance_to(target.position) <= engage_r:
		if (mode == M_HOLD or mode == M_FOLLOW) and position.distance_to(anchor) > 26.0 and kind != "archer":
			_goto(anchor)
		else:
			_engage(mode)
	elif mode == M_ADVANCE or mode == M_CHARGE:
		_goto(battle.enemy_front(self), 1.0)
	else:
		_goto(anchor)


# Attack the enemy castle wall. Returns true while busy with it.
func _siege() -> bool:
	var sgn := 1.0 if team == 0 else -1.0
	var wall_z := 71.5 * sgn
	var reach := 18.0 if kind == "archer" else 3.2
	if absf(position.z - wall_z) <= reach and absf(position.x) < 35.0:
		_stop()
		_face(Vector3(0, 0, sgn))
		if atk_cd <= 0.0:
			var s: Dictionary = KINDS[kind]
			atk_cd = s.cd
			swing = 1.0
			power = false
			var d: float = s.dmg * (1.35 if buff_t > 0.0 else 1.0)
			battle.castle_hit(self, d)
		return true
	var stand := wall_z - sgn * (reach - 1.0 if kind == "archer" else 1.4)
	_goto(Vector3(clampf(position.x, -30.0, 30.0), 0, stand), 1.0)
	return true


func _engage(mode: int) -> void:
	var tp: Vector3 = target.position
	var to := tp - position
	to.y = 0.0
	var d := to.length()
	var s: Dictionary = KINDS["sword" if kind == "hero" else kind]
	if kind == "archer":
		if d < 9.0:
			_move(-to, spd())
		elif d > s.range * 0.92:
			_move(to, spd())
		else:
			_stop()
			_face(to)
		if d <= s.range and atk_cd <= 0.0:
			_shoot(target)
	else:
		var r: float = s.range if kind != "hero" else KINDS.hero.range + (0.9 if mounted else 0.0)
		if d > r * 0.85:
			_move(to, spd() * (1.25 if mode == M_CHARGE else 1.0))
		else:
			_stop()
			_face(to)
		if d <= r + 0.4 and atk_cd <= 0.0:
			_strike(target, 1.0, false)


func _strike(t, mult: float, pw: bool) -> void:
	var s: Dictionary = KINDS[kind]
	atk_cd = s.cd * (1.8 if pw else 1.0)
	swing = 1.0
	power = pw
	var d: float = s.dmg * mult
	if buff_t > 0.0:
		d *= 1.35
	var charge := (kind == "cav" or (kind == "hero" and mounted)) and sim_speed > 6.0
	if charge:
		d *= 1.7
	var to: Vector3 = t.position - position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(to.x, to.z)
	battle.melee_hit(self, t, d, pw, charge)


func _shoot(t) -> void:
	atk_cd = KINDS.archer.cd * randf_range(0.9, 1.15)
	swing = 1.0
	power = false
	var to: Vector3 = t.position - position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(to.x, to.z)
	battle.fire_arrow(self, t)


func take_damage(a: float) -> void:
	if dead:
		return
	hp -= a
	flash = 1.0
	if hp <= 0.0:
		hp = 0.0
		die()
		if battle.is_srv:
			battle.on_death(self)


func die() -> void:
	if dead:
		return
	dead = true
	target = null
	swing = 0.0
	if bar:
		bar.visible = false
	var has_die: bool = rig != null and Models.has_anim(rig, "die")
	if has_die:
		Models.play(rig, "die", true)
	else:
		var tw := create_tween()
		tw.tween_property(body, "rotation:x", -1.5, 0.45)
		tw.parallel().tween_property(body, "position:y", 0.25, 0.45)
	if horse and horse.visible:
		var th := create_tween()
		th.tween_property(horse, "rotation:z", 1.4, 0.5)
		th.parallel().tween_property(horse, "position:y", 0.45, 0.5)
	get_tree().create_timer(7.0).timeout.connect(func(): battle.remove_unit(self))
