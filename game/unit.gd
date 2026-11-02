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
	"ballista": {"hp": 90.0, "speed": 2.8, "dmg": 38.0, "range": 40.0, "cd": 2.6},
	"catapult": {"hp": 130.0, "speed": 2.2, "dmg": 55.0, "range": 50.0, "cd": 4.5},
	"ship": {"hp": 420.0, "speed": 7.5, "dmg": 45.0, "range": 42.0, "cd": 2.4},
	"transport": {"hp": 380.0, "speed": 6.2, "dmg": 0.0, "range": 0.0, "cd": 1.0},
	"fisher": {"hp": 80.0, "speed": 5.0, "dmg": 0.0, "range": 0.0, "cd": 1.0},
}
const SHIPS := ["ship", "transport", "fisher"]
const RANGED := ["archer", "ballista", "catapult", "ship"]

const RigS := preload("res://game/rig.gd")
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
var ranged := false
var is_ship := false
var job := -1            # building id this villager works at
var jstate := 0
var xp := 0              # blows landed (veteran ranks)
var rank_lv := 0
var rk_lbl: Label3D
var cape: Node3D
var shield_n: Node3D
var jwait := 0.0          # 0 walking there, 1 working
var client_loaded := false
var grp := 0             # map group (0 = none)
var gidx := 0
var gn := 1
var loaded = null        # transport this soldier is riding in
var cargo: Array = []
var fish_spot := Vector3.ZERO
var form_dir := 0.0
var aboard = null        # ship the king is sailing on (host)
var pilot_in := Vector3.ZERO   # steering input from the king aboard (ships)
var dest := Vector3.ZERO
var has_dest := false
var sailing := false
var strike_foe := -1     # kingdom this soldier was sent against from the war map
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
var rg := {}
var rigged := false
var gait := 1.0
var gphase := 0.0
var rg_prev_swing := 0.0
var atk_style := 0
var combo := 0
var pre_picked := false
var hit_fx := 0
var killer_style := -1
var death_delay := 0.0
var map_want := false
var blocking := false
var block_t := 0.0
var kick_req := false
var kick_cd := 0.0
var kick_t := 0.0
var focus_on := false
var focus_tgt = null
var clash_lock := false
var pose_mode := ""
var pose_push := 0.0
var pose_side := 1.0
var map_rot := Vector3(2.4, 0.0, 0.0)
var map_t := 0.0
var map_open := 0.0
var stagger := 0.0
var hit_dir := Vector2.ZERO
var hit_from := Vector3.ZERO
var role := ""
var civ_role := ""
var death_t := 0.0
var head_off := false
var death_var := 0
var death_side := 1.0
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
	ranged = RANGED.has(k)
	is_ship = SHIPS.has(k)
	anim_t = randf() * 10.0
	_build()
	if k == "cav" or (k == "hero" and o < 0 and battle.HORSE_RIDING):
		set_mounted(true)


func _build() -> void:
	var hero := kind == "hero"
	sc = 1.22 if hero else 1.0
	var tc: Color = battle.team_col(team)
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
	if kind == "ballista" or kind == "catapult":
		_build_siege(tc)
		return
	if is_ship:
		_build_ship(tc)
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

	RigS.build(self, tc, hero)
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
		shield_n = sh
		_add(sh, _cyl(0.36, 0.05), steel)
		_add(sh, _cyl(0.30, 0.07), cloth, Vector3(0, 0.01, 0))
		_add(sh, _sph(0.07), gold, Vector3(0, 0.05, 0))
		# heraldic cross on the shield face
		_add(sh, _box(Vector3(0.07, 0.03, 0.46)), gold, Vector3(0, 0.07, 0))
		_add(sh, _box(Vector3(0.46, 0.03, 0.07)), gold, Vector3(0, 0.07, 0))
	_dress(hero, tc, cloth, glow, steel, gold, dark, skin, green, wood)

	_make_bar(hero)


func _build_siege(tc: Color) -> void:
	sc = 1.0
	var wood := _mat(Color(0.47, 0.31, 0.15), 0.0, 0.9)
	var dwood := _mat(Color(0.3, 0.19, 0.1), 0.0, 0.9)
	var iron := _mat(Color(0.55, 0.56, 0.6), 0.8, 0.4)
	var cloth := _mat(tc, 0.0, 0.8)
	for sx in [-0.8, 0.8]:
		_add(body, _cyl(0.5, 0.14), dwood, Vector3(sx, 0.5, 0), Vector3(0, 0, PI / 2.0), true)
		_add(body, _cyl(0.1, 0.18), iron, Vector3(sx, 0.5, 0), Vector3(0, 0, PI / 2.0))
	_add(body, _box(Vector3(1.7, 0.12, 0.12)), dwood, Vector3(0, 0.5, 0))
	_add(body, _box(Vector3(1.1, 0.22, 2.4)), wood, Vector3(0, 0.82, 0), Vector3.ZERO, true)
	arm = Node3D.new()
	body.add_child(arm)
	if kind == "ballista":
		_add(body, _box(Vector3(0.2, 0.2, 2.6)), wood, Vector3(0, 1.1, 0.2), Vector3.ZERO, true)
		_add(body, _box(Vector3(2.5, 0.12, 0.16)), dwood, Vector3(0, 1.22, 1.1), Vector3.ZERO, true)
		_add(body, _box(Vector3(0.03, 0.03, 1.1)), _mat(Color(0.9, 0.9, 0.8)), Vector3(0.0, 1.22, 0.55))
		_add(body, _box(Vector3(0.12, 0.5, 0.12)), dwood, Vector3(0, 1.0, -0.6))
		arm.position = Vector3(0, 1.24, 0.1)
		_add(arm, _box(Vector3(0.07, 0.07, 1.6)), iron, Vector3(0, 0, 0.9))
		_add(arm, _box(Vector3(0.16, 0.16, 0.3)), iron, Vector3(0, 0, 1.75))
		_add(body, _box(Vector3(0.6, 0.45, 0.04)), cloth, Vector3(0, 1.6, -0.75))
	else:
		_add(body, _box(Vector3(0.18, 1.5, 0.18)), dwood, Vector3(-0.45, 1.5, -0.2), Vector3.ZERO, true)
		_add(body, _box(Vector3(0.18, 1.5, 0.18)), dwood, Vector3(0.45, 1.5, -0.2), Vector3.ZERO, true)
		_add(body, _box(Vector3(1.1, 0.14, 0.14)), wood, Vector3(0, 2.2, -0.2))
		arm.position = Vector3(0, 2.1, -0.2)
		_add(arm, _box(Vector3(0.2, 0.2, 3.6)), wood, Vector3(0, 0, 1.0), Vector3.ZERO, true)
		_add(arm, _sph(0.45), _mat(Color(0.35, 0.33, 0.3)), Vector3(0, 0.3, 2.7))
		_add(arm, _box(Vector3(0.7, 0.6, 0.6)), iron, Vector3(0, -0.2, -0.8))
		_add(body, _box(Vector3(0.6, 0.45, 0.04)), cloth, Vector3(0, 2.7, -0.2))
	_make_bar(false)
	bar.position.y = 3.2


func _build_boat(tc: Color) -> void:
	sc = 1.0
	var wood := _mat(Color(0.42, 0.27, 0.13), 0.0, 0.9)
	var plank := _mat(Color(0.62, 0.45, 0.25), 0.0, 0.9)
	var dwood := _mat(Color(0.28, 0.18, 0.1), 0.0, 0.9)
	var sail := _mat(Color(0.88, 0.84, 0.72), 0.0, 0.95)
	var cloth := _mat(tc, 0.0, 0.7, 0.4)
	if kind == "fisher":
		_add(body, _box(Vector3(1.5, 0.6, 3.6)), wood, Vector3(0, 0.1, 0), Vector3.ZERO, true)
		var fp := PrismMesh.new()
		fp.size = Vector3(1.5, 0.6, 1.2)
		_add(body, fp, wood, Vector3(0, 0.1, 2.3), Vector3(PI / 2.0, 0, 0), true)
		_add(body, _box(Vector3(1.3, 0.08, 3.4)), plank, Vector3(0, 0.42, 0))
		_add(body, _cyl(0.07, 2.6), dwood, Vector3(0, 1.6, 0.3), Vector3.ZERO, true)
		_add(body, _box(Vector3(1.6, 1.6, 0.05)), sail, Vector3(0.0, 1.7, 0.4), Vector3.ZERO, true)
		_add(body, _box(Vector3(0.3, 0.3, 0.05)), cloth, Vector3(0.0, 2.3, 0.45))
		# net basket
		var net_m := _mat(Color(0.55, 0.5, 0.35), 0.0, 1.0)
		_add(body, _box(Vector3(0.7, 0.35, 0.7)), net_m, Vector3(0, 0.65, -1.1))
		arm = Node3D.new()
		body.add_child(arm)
		_make_bar(false)
		bar.position.y = 3.0
		return
	# transport: broad hull, open deck with cargo crates
	_add(body, _box(Vector3(3.8, 1.2, 8.0)), wood, Vector3(0, 0.2, 0), Vector3.ZERO, true)
	var pr := PrismMesh.new()
	pr.size = Vector3(3.8, 1.2, 2.4)
	_add(body, pr, wood, Vector3(0, 0.2, 5.1), Vector3(PI / 2.0, 0, 0), true)
	_add(body, _box(Vector3(3.9, 0.16, 8.2)), dwood, Vector3(0, 0.85, 0))
	_add(body, _box(Vector3(3.4, 0.1, 7.6)), plank, Vector3(0, 0.88, 0))
	for sx in [-1.9, 1.9]:
		_add(body, _box(Vector3(0.12, 0.7, 7.8)), dwood, Vector3(sx, 1.2, 0))
	for i in 3:
		_add(body, _box(Vector3(1.0, 0.9, 1.0)), plank, Vector3(-0.9 + (i % 2) * 1.6, 1.4, -2.4 + i * 1.4), Vector3(0, i * 0.4, 0))
	_add(body, _cyl(0.15, 5.0), dwood, Vector3(0, 3.4, 1.4), Vector3.ZERO, true)
	_add(body, _box(Vector3(3.2, 2.4, 0.07)), sail, Vector3(0, 3.4, 1.45), Vector3.ZERO, true)
	_add(body, _box(Vector3(3.2, 0.5, 0.09)), cloth, Vector3(0, 3.9, 1.45))
	_add(body, _box(Vector3(2.8, 0.7, 1.6)), wood, Vector3(0, 1.3, -3.4), Vector3.ZERO, true)
	arm = Node3D.new()
	body.add_child(arm)
	_make_bar(false)
	bar.position.y = 6.2


func _build_ship(tc: Color) -> void:
	if kind != "ship":
		_build_boat(tc)
		return
	sc = 1.0
	var wood := _mat(Color(0.42, 0.27, 0.13), 0.0, 0.9)
	var plank := _mat(Color(0.62, 0.45, 0.25), 0.0, 0.9)
	var dwood := _mat(Color(0.28, 0.18, 0.1), 0.0, 0.9)
	var sail := _mat(Color(0.94, 0.9, 0.8), 0.0, 0.95)
	var cloth := _mat(tc, 0.0, 0.7, 0.4)
	var iron := _mat(Color(0.2, 0.2, 0.24), 0.7, 0.4)
	_add(body, _box(Vector3(2.8, 1.0, 7.4)), wood, Vector3(0, 0.15, 0), Vector3.ZERO, true)
	var pr := PrismMesh.new()
	pr.size = Vector3(2.8, 1.0, 2.2)
	_add(body, pr, wood, Vector3(0, 0.15, 4.7), Vector3(PI / 2.0, 0, 0), true)
	_add(body, _box(Vector3(2.9, 0.16, 7.6)), dwood, Vector3(0, 0.7, 0))
	_add(body, _box(Vector3(2.3, 0.1, 6.8)), plank, Vector3(0, 0.72, 0))
	_add(body, _box(Vector3(2.6, 0.7, 2.0)), wood, Vector3(0, 1.1, -2.9), Vector3.ZERO, true)
	for sx in [-1.4, 1.4]:
		_add(body, _box(Vector3(0.1, 0.5, 7.0)), dwood, Vector3(sx, 1.0, 0))
	_add(body, _cyl(0.13, 6.5), dwood, Vector3(0, 4.0, 0.4), Vector3.ZERO, true)
	_add(body, _box(Vector3(3.6, 0.12, 0.12)), dwood, Vector3(0, 5.4, 0.4))
	_add(body, _box(Vector3(3.4, 3.0, 0.07)), sail, Vector3(0, 3.8, 0.45), Vector3.ZERO, true)
	_add(body, _box(Vector3(3.4, 0.5, 0.09)), cloth, Vector3(0, 4.3, 0.45))
	_add(body, _box(Vector3(0.9, 0.5, 0.05)), cloth, Vector3(0.5, 7.0, 0.4))
	arm = Node3D.new()
	body.add_child(arm)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.4]:
			_add(body, _cyl(0.2, 1.3), iron, Vector3(sx * 1.2, 1.1, sz), Vector3(0, 0, sx * PI / 2.0 * 0.9))
	_make_bar(false)
	bar.position.y = 7.6


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
		RigS.build_civ(self, tc, "villager")
	# basket on the back, shown while carrying fruit
	carry_node = Node3D.new()
	carry_node.position = Vector3(0, 1.1, -0.3)
	carry_node.visible = false
	body.add_child(carry_node)
	_add(carry_node, _box(Vector3(0.42, 0.34, 0.26)), wood)
	for i in 4:
		_add(carry_node, _sph(0.09), red, Vector3(-0.15 + i * 0.1, 0.2, 0.0))
	if not rigged:
		arm = Node3D.new()
		arm.position = Vector3(0.34, 1.25, 0.05)
		body.add_child(arm)
		_add(arm, _box(Vector3(0.04, 0.04, 0.7)), wood, Vector3(0, 0, 0.3))
	_make_bar(false)
	bar.position.y = 2.3


# turn a villager into a named NPC (messenger / advisor / steward)
func set_role(r: String) -> void:
	role = r
	for c in body.get_children():
		if c != carry_node:
			c.queue_free()
	legs.clear()
	rg = {}
	rigged = false
	RigS.build_civ(self, battle.team_col(team), r)
	if carry_node != null:
		carry_node.queue_free()
		carry_node = null


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


func _dress(hero: bool, tc: Color, cloth: Material, glow: Material, steel: Material, gold: Material, dark: Material, skin: Material, green: Material, wood: Material) -> void:
	var leather := _mat(Color(0.33, 0.2, 0.1), 0.0, 0.9)
	var white := _mat(Color(0.95, 0.94, 0.9), 0.0, 0.95)
	var trim := _mat(tc.darkened(0.45), 0.0, 0.8)
	# boots
	for l in legs:
		_add(l, _box(Vector3(0.2, 0.2, 0.34)), dark, Vector3(0, -0.74, 0.05))
	# belt + buckle
	_add(body, _box(Vector3(0.54, 0.08, 0.3)), leather, Vector3(0, 0.95, 0.0))
	_add(body, _box(Vector3(0.1, 0.1, 0.04)), gold, Vector3(0, 0.95, 0.16))
	if kind == "archer":
		# hood + feather, bracers, scarf
		_add(body, _cyl(0.25, 0.12), green, Vector3(0, 1.74, 0.0))
		_add(body, _box(Vector3(0.03, 0.03, 0.34)), white, Vector3(0.14, 1.98, -0.1), Vector3(0.5, 0, 0.3))
		_add(body, _box(Vector3(0.5, 0.1, 0.34)), _mat(Color(0.55, 0.35, 0.15), 0.0, 0.9), Vector3(0, 1.58, 0.02))
		_add(body, _box(Vector3(0.1, 0.5, 0.1)), leather, Vector3(0.36, 1.3, 0.08))
		_add(body, _box(Vector3(0.1, 0.5, 0.1)), leather, Vector3(-0.36, 1.3, 0.08))
		return
	# tabard over the armour with a heraldic stripe
	_add(body, _box(Vector3(0.44, 0.62, 0.03)), cloth, Vector3(0, 1.1, 0.24))
	_add(body, _box(Vector3(0.1, 0.62, 0.035)), white if not hero else gold, Vector3(0, 1.1, 0.245))
	_add(body, _box(Vector3(0.44, 0.1, 0.035)), trim, Vector3(0, 0.83, 0.245))
	# cape
	cape = Node3D.new()
	cape.position = Vector3(0, 1.62, -0.24)
	body.add_child(cape)
	var cl: float = 0.95 if not hero else 1.25
	_add(cape, _box(Vector3(0.54, cl, 0.04)), trim, Vector3(0, -cl * 0.5, -0.03))
	if hero:
		_add(cape, _box(Vector3(0.5, 0.1, 0.05)), gold, Vector3(0, -cl + 0.05, -0.03))
	# pauldrons and gauntlets
	for sx in [-0.34, 0.34]:
		_add(body, _sph(0.17), steel, Vector3(sx, 1.46, 0.0))
		_add(body, _box(Vector3(0.14, 0.14, 0.14)), steel, Vector3(sx * 1.1, 1.0, 0.1))
	# helmet details: nasal bar, brow ridge, crest
	_add(body, _box(Vector3(0.03, 0.14, 0.03)), steel, Vector3(0, 1.82, 0.24))
	_add(body, _box(Vector3(0.36, 0.04, 0.05)), steel, Vector3(0, 1.93, 0.2))
	if kind == "cav":
		_add(body, _box(Vector3(0.05, 0.18, 0.4)), glow, Vector3(0, 2.14, -0.04))
	elif not hero:
		_add(body, _box(Vector3(0.04, 0.08, 0.3)), glow, Vector3(0, 2.1, -0.02))
	if hero:
		# crown ring with points and jewels, fur mantle
		_add(body, _cyl(0.245, 0.09), gold, Vector3(0, 2.1, -0.02))
		for i in 6:
			var a := float(i) / 6.0 * TAU
			_add(body, _box(Vector3(0.05, 0.16, 0.05)), gold, Vector3(sin(a) * 0.22, 2.22, cos(a) * 0.22 - 0.02))
		_add(body, _sph(0.045), _mat(Color(0.9, 0.1, 0.15), 0.2, 0.3, 0.8), Vector3(0, 2.13, 0.24))
		for i in 7:
			var b := float(i) / 7.0 * PI + PI * 0.0
			_add(body, _sph(0.11), white, Vector3(cos(b) * 0.36, 1.58, sin(b) * 0.1 - 0.02))
		_add(body, _box(Vector3(0.62, 0.05, 0.34)), gold, Vector3(0, 1.38, 0.02))
		# jewelled sword pommel and cross guard
		_add(arm, _sph(0.06), _mat(Color(0.2, 0.5, 1.0), 0.2, 0.3, 0.9), Vector3(0, 0, -0.08))


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
	var tc: Color = battle.team_col(team)
	_add(horse, _box(Vector3(0.6, 0.65, 1.6)), hm, Vector3(0, 1.0, 0), Vector3.ZERO, true)
	_add(horse, _box(Vector3(0.66, 0.67, 0.9)), _mat(tc, 0.0, 0.8), Vector3(0, 1.02, -0.05))
	_add(horse, _box(Vector3(0.72, 0.5, 0.5)), _mat(tc.darkened(0.3), 0.0, 0.8), Vector3(0, 0.84, 0.02))
	_add(horse, _box(Vector3(0.1, 0.3, 0.1)), _mat(Color(1.0, 0.78, 0.25), 1.0, 0.25), Vector3(0, 1.75, 1.3))
	_add(horse, _box(Vector3(0.04, 0.16, 0.2)), _mat(tc, 0.0, 0.6, 0.6), Vector3(0, 1.98, 1.0))
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
		if rigged:
			RigS.animate_death(self, dt)
		return
	var mv := sim_speed > 0.4
	anim_t += dt * (1.0 + sim_speed * 0.5)
	var ph := sin(anim_t * 7.0)
	if rig != null or hrig != null:
		_model_anim()
	for i in (0 if rigged else legs.size()):
		legs[i].rotation.x = ph * 0.8 * (1.0 if i == 0 else -1.0) * (1.0 if mv else 0.0)
	for i in hlegs.size():
		hlegs[i].rotation.x = ph * 0.7 * (1.0 if i % 3 == 0 else -1.0) * (1.0 if mv else 0.0)
	body.position.y = (ride_y if mounted else 0.0) + (absf(ph) * 0.05 if (mv and rig == null and not rigged) else 0.0)
	body.scale = Vector3.ONE * sc * (1.0 + flash * 0.1)
	if rigged:
		RigS.animate(self, dt)
	elif rig == null and not is_ship and kind != "villager" and cape != null or (rig == null and kind == "archer"):
		var run: float = clampf(sim_speed / 6.0, 0.0, 1.0)
		var breathe := sin(anim_t * 1.6) * 0.012
		# lean into the run, sway with each stride, recoil when hit, breathe when idle
		body.rotation.x = lerpf(body.rotation.x, -0.16 * run + flash * 0.25, clampf(dt * 10.0, 0.0, 1.0))
		body.rotation.z = lerpf(body.rotation.z, (ph * 0.05 * run) if mv else 0.0, clampf(dt * 10.0, 0.0, 1.0))
		body.scale.y += breathe
		if cape != null:
			cape.rotation.x = 0.1 + run * 0.55 + sin(anim_t * 5.0) * (0.04 + 0.08 * run)
			cape.rotation.z = sin(anim_t * 3.3) * 0.04 * (1.0 + run)
		if shield_n != null:
			shield_n.rotation.x = PI / 2.0 + (ph * 0.06 if mv else sin(anim_t * 1.6) * 0.02)
		# lunge forward during the strike
		var lunge := 0.0
		if swing > 0.0:
			lunge = sin((1.0 - swing) * PI) * (0.35 if kind != "archer" else -0.08)
		body.position.z = lerpf(body.position.z, lunge, clampf(dt * 18.0, 0.0, 1.0))
	if swing > 0.0:
		swing = maxf(0.0, swing - dt * ((1.35 if atk_style in [5, 6, 7, 9, 10] else 1.8) if (power or kind == "hero") else 2.4))
		var s := 1.0 - swing
		if not rigged:
			arm.rotation.x = lerpf(-1.8, 1.0, s * s)
	elif not rigged:
		arm.rotation.x = lerpf(arm.rotation.x, -0.5, clampf(dt * 8.0, 0.0, 1.0))
	if is_ship:
		body.position.y = sin(anim_t * 1.6) * 0.13
		body.rotation.z = sin(anim_t * 1.3) * 0.05
		body.rotation.x = sin(anim_t * 1.1 + 1.0) * 0.03 - clampf(sim_speed * 0.004, 0.0, 0.05)
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
	kick_cd -= dt
	block_t += dt
	buff_t -= dt
	rally_cd -= dt
	mount_cd -= dt
	if loaded != null:
		if is_instance_valid(loaded) and not loaded.dead:
			position = loaded.position + Vector3(0, 0.8, 0)
			return
		loaded = null
		visible = true
	if clash_lock:
		_stop()
		return
	if battle.freeze_others and kind != "hero":
		_stop()
		return
	if kind == "villager":
		_villager()
		return
	if kind == "hero" and (owner_id >= 0 or driven):
		_hero()
	else:
		_ai()
	if kind == "hero" and battle.duel_active:
		_duel_clamp()


var driven := false


func _duel_clamp() -> void:
	var off: Vector3 = position - battle.duel_center
	off.y = 0.0
	var lim: float = battle.duel_r - 0.6
	if off.length() > lim:
		var np: Vector3 = battle.duel_center + off.normalized() * lim
		position.x = np.x
		position.z = np.z


# Villager with a job: walk to the building, then build or work there.
func _job() -> void:
	var k = battle.kingdom
	var tw = k.town
	var b = tw.get_b(job)
	if b == null:
		job = -1
		jstate = 0
		return
	if carry > 0:
		carry = 0
		set_carry(false)
	var wp: Vector3 = tw.work_pos(team, b, uid)
	var dd := wp - position
	dd.y = 0.0
	if jstate == 0:
		jwait += get_process_delta_time()
		if jwait > 14.0 and dd.length() >= 9.0:
			position.x = wp.x
			position.z = wp.z
			jwait = 6.1
		if dd.length() < 1.8 or (jwait > 6.0 and dd.length() < 9.0):
			jstate = 1
			_vswing = 0.0
		else:
			var w := _via(wp) - position
			w.y = 0.0
			_move(w, spd())
		return
	_stop()
	if dd.length() > 9.5:
		jstate = 0
		jwait = 0.0
		return
	_face(tw.site_pos(team, b) - position)
	if _vswing <= 0.0:
		_vswing = 0.85
		swing = 1.0
		if float(b.prog) < 1.0 and randf() < 0.35:
			battle.sfx.play("hammer", position, -12.0, randf_range(0.9, 1.2))


# Villager: walk to a fruit tree, pick fruit, carry it to the castle, repeat.
func _villager() -> void:
	var k = battle.kingdom
	if k == null:
		_stop()
		return
	if _vswing > 0.0:
		_vswing -= _dt
	if job >= 0:
		_job()
		return
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
				var wp1 := _via(k.tree_at(team, vtree)) - position
				wp1.y = 0.0
				_move(wp1, spd())
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
				var wp2 := _via(k.depot(team)) - position
				wp2.y = 0.0
				_move(wp2, spd())


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
	var climb := 1.6 if position.y > 0.3 else 1.0
	var np := position + (dir * s * climb + push * (0.6 if position.y > 0.3 else 2.0)) * _dt
	if battle.sea:
		var fl2 := Vector2(np.x, np.z)
		var lim2: float = battle.coast_r - 4.0
		if fl2.length() > lim2:
			fl2 = fl2.normalized() * lim2
			np.x = fl2.x
			np.z = fl2.y
	elif battle.nk > 2:
		var lim: float = battle.ring_r + 50.0 + battle.HINT
		var flat := Vector2(np.x, np.z)
		if flat.length() > lim:
			flat = flat.normalized() * lim
			np.x = flat.x
			np.z = flat.y
	else:
		var zmax: float = 78.0 if battle.kingdom == null else 124.0 + battle.HINT
		np.x = clampf(np.x, -95.0, 95.0)
		np.z = clampf(np.z, -zmax, zmax)
	sim_speed = lerpf(sim_speed, s, clampf(_dt * 6.0, 0.0, 1.0))
	var oldp := position
	position = np
	if battle.kingdom != null:
		battle.kingdom.constrain(self, oldp)
	_face(dir)


# Waypoint towards p that goes through the castle gate when needed (kingdom mode).
func _via(p: Vector3) -> Vector3:
	if battle.kingdom == null:
		return p
	return battle.kingdom.via(team, position, p)


func _stop() -> void:
	sim_speed = lerpf(sim_speed, 0.0, clampf(_dt * 8.0, 0.0, 1.0))


func _goto(p: Vector3, mult := 1.0) -> void:
	var d := p - position
	d.y = 0.0
	if d.length() < 1.2:
		_stop()
		_face(battle.rotv(team, Vector3(0, 0, 1)))
	else:
		var wp := _via(p)
		var dw := wp - position
		dw.y = 0.0
		_move(dw, spd() * mult)


func _hero() -> void:
	if aboard != null:
		if not is_instance_valid(aboard) or aboard.dead:
			aboard = null
		else:
			aboard.pilot_in = move_in
			position = aboard.position + Vector3(0, 1.15, 0)
			rotation.y = lerp_angle(rotation.y, aboard.rotation.y, clampf(_dt * 6.0, 0.0, 1.0))
			sim_speed = 0.0
			return
	var s := spd() * (0.5 if blocking else 1.0)
	var mvl := move_in.length()
	if mvl > 0.08:
		_move(move_in.normalized(), s * minf(mvl, 1.0))
	else:
		_stop()
	var rng: float = KINDS.hero.range + (0.9 if mounted else 0.0)
	var t = battle.nearest_enemy(self, rng + 0.6)
	# FOCUS: lock on to one opponent, keep facing him whatever you do
	if focus_on:
		if focus_tgt == null or not is_instance_valid(focus_tgt) or focus_tgt.dead or focus_tgt.position.distance_to(position) > 22.0:
			focus_tgt = battle.nearest_enemy(self, 20.0)
		if focus_tgt != null:
			var fd: Vector3 = focus_tgt.position - position
			if fd.length() < rng + 0.6:
				t = focus_tgt
			_face(fd)
	else:
		focus_tgt = null
	# KICK: a short leg strike that shoves and staggers
	if kick_req:
		kick_req = false
		if kick_cd <= 0.0 and not blocking and swing <= 0.0:
			kick_cd = 1.1
			kick_t = 1.0
			var kt = focus_tgt if (focus_on and focus_tgt != null) else battle.nearest_enemy(self, 3.0)
			if kt != null and kt.position.distance_to(position) < 3.2:
				rotation.y = atan2(kt.position.x - position.x, kt.position.z - position.z)
				atk_style = 2
				battle.melee_hit(self, kt, 14.0 * rank_mult(), true, false)
				if kt.kind != "hero" or battle.duel_active:
					var kd: Vector3 = kt.position - position
					kd.y = 0.0
					if kd.length() > 0.01:
						kt.position += kd.normalized() * 0.9
			battle.sfx.play("thud", position, -2.0, 0.8)
	if blocking:
		if t != null and mvl < 0.08:
			_face(t.position - position)
		return
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
		var ot: int = battle.duel_other(team)
		var kg = battle.team_king(ot) if ot >= 0 else null
		if kg != null:
			target = kg
			_engage(M_CHARGE)
			return
	if is_ship:
		if kind == "fisher":
			_fish_ai()
		else:
			_ship_ai()
		return
	var okind := "sword" if kind == "hero" else kind
	if kind == "ballista" or kind == "catapult":
		okind = "archer"
	var ord: Dictionary = battle.get_order(owner_id, okind)
	if grp > 0:
		var gord: Dictionary = battle.group_order(owner_id, grp)
		if not gord.is_empty():
			ord = gord
	if battle.kingdom != null and (kind == "archer" or kind == "ballista") and battle.is_garrison(self) \
			and battle.kingdom.castle_alive(team) and strike_foe < 0 and battle.kingdom.has_wall(team):
		_wall_duty()
		return
	if battle.kingdom != null and kind != "hero" and battle.is_garrison(self):
		ord = {"mode": M_HOLD, "pos": battle.kingdom.home_pos(team)}
	if strike_foe >= 0 and kind != "hero" and battle.kingdom != null:
		if battle.kingdom.castle_alive(strike_foe) and battle.hostile(team, strike_foe):
			ord = {"mode": M_ADVANCE, "pos": ord.pos}
		else:
			strike_foe = -1
	if battle.kingdom != null and battle.war and target != null and not ranged and kind != "hero" \
			and battle.kingdom.inside(target.team, target.position) and battle.kingdom.castle_alive(target.team):
		target = null
	var mode: int = ord.mode
	if battle.kingdom != null and battle.war and target == null and kind != "hero" \
			and (mode == M_ADVANCE or mode == M_CHARGE) and battle.kingdom.target_castle(self) >= 0:
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
	if ranged:
		engage_r = maxf(engage_r, KINDS[kind].range)
	if target != null and position.distance_to(target.position) <= engage_r:
		if (mode == M_HOLD or mode == M_FOLLOW) and position.distance_to(anchor) > 26.0 and not ranged:
			_goto(anchor)
		else:
			_engage(mode)
	elif mode == M_ADVANCE or mode == M_CHARGE:
		_goto(battle.enemy_front(self), 1.0)
	else:
		_goto(anchor)


# Garrison archers climb the stairs and shoot from the wall walk.
func _wall_duty() -> void:
	var k = battle.kingdom
	var slot: Vector3 = k.wall_slot(team, uid)
	if target != null and is_instance_valid(target) and not target.dead:
		var d := position.distance_to(target.position)
		if d <= KINDS[kind].range and atk_cd <= 0.0:
			_face(target.position - position)
			_shoot(target)
			if position.y > 3.0:
				_stop()
				return
	var flat := Vector2(slot.x - position.x, slot.z - position.z)
	if flat.length() < 1.0 and position.y > 3.0:
		_stop()
		_face(battle.rotv(team, Vector3(0, 0, -1)) * -1.0 if target == null else target.position - position)
		return
	var wp: Vector3 = k.wall_via(team, position, slot)
	var dv := wp - position
	dv.y = 0.0
	_move(dv, spd())


func _sail_to(p: Vector3, mult := 1.0) -> bool:
	var dd := p - position
	dd.y = 0.0
	if dd.length() < 3.0:
		sim_speed = lerpf(sim_speed, 0.0, clampf(_dt * 3.0, 0.0, 1.0))
		return true
	var np: Vector3 = position + dd.normalized() * spd() * mult * _dt
	np = battle.keep_on_sea(np)
	var dv := np - position
	sim_speed = lerpf(sim_speed, dv.length() / maxf(_dt, 0.0001), clampf(_dt * 4.0, 0.0, 1.0))
	if dv.length() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(dv.x, dv.z), clampf(_dt * 2.5, 0.0, 1.0))
	position = Vector3(np.x, 0.0, np.z)
	return false


# Fishing boat: sail to a fishing ground, cast the net, bring the catch home.
func _fish_ai() -> void:
	var k = battle.kingdom
	if k == null:
		return
	if fish_spot == Vector3.ZERO:
		fish_spot = k.fish_spot(team, uid)
	match vstate:
		0:
			if _sail_to(fish_spot):
				vstate = 1
				vtimer = 9.0
		1:
			_stop()
			vtimer -= _dt
			if fmod(vtimer, 3.0) < _dt:
				swing = 1.0
			if vtimer <= 0.0:
				carry = 16
				vstate = 2
		2:
			if _sail_to(battle.keep_on_sea(k.dock_pos(team) + battle.rotv(team, Vector3(float(uid % 5) * 3.0 - 6.0, 0, 0.0)))):
				k.deposit(team, carry)
				battle.sfx.play("coin", position, -10.0, 1.2)
				carry = 0
				vstate = 0


func _ship_ai() -> void:
	var mv := Vector3.ZERO
	if pilot_in.length() > 0.08:
		mv = pilot_in
		has_dest = false
	elif has_dest:
		var dd := dest - position
		dd.y = 0.0
		if dd.length() < 3.0:
			has_dest = false
		else:
			mv = dd.normalized()
	if mv.length() > 0.05:
		var np: Vector3 = position + mv.normalized() * spd() * minf(mv.length(), 1.0) * _dt
		np = battle.keep_on_sea(np)
		var dv := np - position
		var spd_now := dv.length() / maxf(_dt, 0.0001)
		sim_speed = lerpf(sim_speed, spd_now, clampf(_dt * 4.0, 0.0, 1.0))
		if dv.length() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(dv.x, dv.z), clampf(_dt * 2.5, 0.0, 1.0))
		position = Vector3(np.x, 0.0, np.z)
	else:
		sim_speed = lerpf(sim_speed, 0.0, clampf(_dt * 3.0, 0.0, 1.0))
	# cannons: nearest enemy soldier, else the enemy castle wall
	if atk_cd > 0.0 or kind != "ship":
		return
	var t = battle.nearest_enemy(self, KINDS.ship.range)
	if t != null:
		atk_cd = KINDS.ship.cd
		swing = 1.0
		battle.ship_shot(self, t.position + Vector3(0, 1.0, 0), 1.0, t)
		return
	var k = battle.kingdom
	if k == null:
		return
	for ft in battle.foes_of(team):
		if not k.castle_alive(ft):
			continue
		var l: Vector3 = battle.wl(ft, position)
		var pt: Vector3 = battle.lw(ft, Vector3(clampf(l.x, -34.0, 34.0), 3.0, -121.0))
		if Vector2(pt.x - position.x, pt.z - position.z).length() <= KINDS.ship.range:
			atk_cd = KINDS.ship.cd
			swing = 1.0
			battle.ship_shot(self, pt, 0.0, null)
			k.damage_castle(ft, KINDS.ship.dmg * 0.6, team)
			return


# Attack the enemy castle wall. Returns true while busy with it.
func _siege() -> bool:
	var ft: int = battle.kingdom.target_castle(self)
	if ft < 0:
		return false
	var l: Vector3 = battle.wl(ft, position)
	var reach: float = KINDS[kind].range * 0.7 if ranged else 3.2
	if absf(l.z + 71.5) <= reach and absf(l.x) < 35.0 and l.z < -60.0:
		_stop()
		_face(battle.rotv(ft, Vector3(0, 0, -1)))
		if atk_cd <= 0.0:
			var s: Dictionary = KINDS[kind]
			atk_cd = s.cd
			swing = 1.0
			power = false
			var d: float = s.dmg * (1.35 if buff_t > 0.0 else 1.0) * (battle.kingdom.dmg_mult(team, kind) if battle.kingdom != null else 1.0)
			if kind == "catapult":
				d *= 4.0
			elif kind == "ballista":
				d *= 1.5
			if ranged:
				battle.siege_shot(self, battle.lw(ft, Vector3(clampf(l.x, -30.0, 30.0), 3.0, -72.0)))
			battle.castle_hit(self, d)
		return true
	var off: float = (reach - 1.0) if ranged else 1.4
	_goto(battle.lw(ft, Vector3(clampf(l.x, -30.0, 30.0), 0, -71.5 + off)), 1.0)
	return true


func _engage(mode: int) -> void:
	var tp: Vector3 = target.position
	var to := tp - position
	to.y = 0.0
	var d := to.length()
	var go := _via(tp) - position
	go.y = 0.0
	var s: Dictionary = KINDS["sword" if kind == "hero" else kind]
	if ranged:
		if d < 9.0 and kind == "archer":
			_move(-to, spd())
		elif d > s.range * 0.92:
			_move(go, spd())
		else:
			_stop()
			_face(to)
		if d <= s.range and atk_cd <= 0.0:
			_shoot(target)
	else:
		var r: float = s.range if kind != "hero" else KINDS.hero.range + (0.9 if mounted else 0.0)
		if d > r * 0.85:
			_move(go, spd() * (1.25 if mode == M_CHARGE else 1.0))
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
	if kind == "hero" and not pw:
		atk_style = preload("res://game/rig.gd").HERO_SEQ[combo % preload("res://game/rig.gd").HERO_SEQ.size()]
		combo += 1
		pre_picked = true
	var d: float = s.dmg * mult * (battle.kingdom.dmg_mult(team, kind) if battle.kingdom != null else 1.0)
	if buff_t > 0.0:
		d *= 1.35
	var charge := (kind == "cav" or (kind == "hero" and mounted)) and sim_speed > 6.0
	if charge:
		d *= 1.7
	var to: Vector3 = t.position - position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(to.x, to.z)
	d *= rank_mult()
	gain_xp()
	battle.melee_hit(self, t, d, pw, charge)


func _shoot(t) -> void:
	atk_cd = KINDS[kind].cd * randf_range(0.9, 1.15)
	swing = 1.0
	power = false
	var to: Vector3 = t.position - position
	to.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(to.x, to.z)
	gain_xp()
	battle.fire_arrow(self, t)


func gain_xp() -> void:
	if kind == "hero" or kind == "villager" or is_ship:
		return
	xp += 1
	var r := 0
	if xp >= 60:
		r = 3
	elif xp >= 30:
		r = 2
	elif xp >= 10:
		r = 1
	if r != rank_lv:
		set_rank(r)
		if r > 0:
			max_hp += 8.0
			hp = minf(max_hp, hp + 20.0)


func set_rank(r: int) -> void:
	rank_lv = r
	if r <= 0:
		if rk_lbl != null:
			rk_lbl.visible = false
		return
	if rk_lbl == null:
		rk_lbl = Label3D.new()
		rk_lbl.pixel_size = 0.014
		rk_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rk_lbl.no_depth_test = true
		rk_lbl.modulate = Color(1.0, 0.85, 0.25)
		rk_lbl.outline_size = 8
		rk_lbl.position = Vector3(0, 2.7 if kind != "cav" else 3.3, 0)
		add_child(rk_lbl)
	rk_lbl.visible = true
	rk_lbl.text = "★".repeat(r)


func rank_mult() -> float:
	return 1.0 + 0.1 * float(rank_lv)


func take_damage(a: float) -> void:
	if dead:
		return
	if battle != null and battle.kingdom != null:
		a *= battle.kingdom.armor_mult(team, kind)
	hp -= a
	flash = 1.0
	if hit_from != Vector3.ZERO:
		var dd := hit_from - position
		dd.y = 0.0
		if dd.length() > 0.01:
			var lc := dd.normalized().rotated(Vector3.UP, -rotation.y)
			hit_dir = Vector2(lc.x, lc.z)
		hit_from = Vector3.ZERO
	else:
		hit_dir = Vector2(randf_range(-0.8, 0.8), 0.6)
	if a >= 25.0:
		stagger = 1.0
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
	if is_ship:
		var ts := create_tween()
		ts.tween_property(body, "position:y", -3.5, 4.0)
		ts.parallel().tween_property(body, "rotation:z", 0.6, 4.0)
		get_tree().create_timer(5.0).timeout.connect(func(): battle.remove_unit(self))
		return
	if has_die:
		Models.play(rig, "die", true)
	else:
		var tw := create_tween()
		if rigged:
			death_var = randi() % 3
			death_side = 1.0 if randf() < 0.5 else -1.0
			if kind == "hero":
				death_var = 0
			if killer_style >= 0:
				death_delay = 0.3
				if killer_style == 6:
					death_var = 4
				elif killer_style == 5 or killer_style == 10:
					death_var = 3
			tw.kill()
		else:
			tw.tween_property(body, "rotation:x", -1.5, 0.45)
			tw.parallel().tween_property(body, "position:y", 0.25, 0.45)
	if horse and horse.visible:
		var th := create_tween()
		th.tween_property(horse, "rotation:z", 1.4, 0.5)
		th.parallel().tween_property(horse, "position:y", 0.45, 0.5)
	get_tree().create_timer(7.0).timeout.connect(func(): battle.remove_unit(self))
