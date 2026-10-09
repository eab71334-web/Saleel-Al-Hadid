extends Node3D

# ===================== الملفات (كلها اختيارية) =====================
const GLB_PATH := "res://game/character.glb"
const GLB_YAW := PI
const CHAR_HEIGHT := 1.8
const CHAR_SCALE_MANUAL := 0.0
const CAR_GLB_PATH := "res://game/car.glb"
const CAR_GLB_YAW := PI
const POLICE_GLB_PATH := "res://game/police.glb"
const POLICE_GLB_YAW := PI
const OFFICER_GLB_PATH := "res://game/peds/officer.glb"
const PED_GLB_COUNT := 6
const PED_GLB_YAW := PI
const WEAPON_GLB_DIR := "res://game/weapons/"
const WEAPON_GLB_YAW := 0.0
const BULLET_DIR := "res://game/bullets/"
const BULLET_GLB_YAW := 0.0
const BULLET_GLB_SPEED := 90.0
const BULLET_LEN := 0.35
const PHONE_GLB_PATH := "res://game/phone.glb"
const PHONE_GLB_YAW := 0.0
const PHONE_HAND_POS := Vector3(0.0, 0.07, 0.03)
const PHONE_HAND_ROT := Vector3(0.0, 0.0, 0.0)
const PHONE_X_FRAC := 0.70
const ANIM_DIR := "res://game/anims/"
const SND_DIR := "res://game/sounds/"
const GUN_HAND_POS := Vector3(0.0, 0.08, 0.02)
const GUN_HAND_ROT := Vector3(90.0, 0.0, 0.0)
const WEAPON_ANIM_TAGS := [[], ["pistol", "w1"], ["smg", "w2"], ["shotgun", "w3"], ["rifle", "w4"]]
const ARM_POSE := [[0.0, 0.0, 0.0], [1.5, 0.2, 0.0], [1.45, 1.2, 0.08], [1.3, 1.0, 0.1], [1.55, 1.35, 0.12]]

const CAR_LENGTH := 5.4
const POLICE_LENGTH := 5.2
const CAR_SCALE := 1.25
const WHEEL_R := 0.475

const MAX_SPEED := 8.5
const RUN_SPEED := 4.5
const JUMP_V := 9.0
const GRAVITY := 25.0
const RADIUS := 110.0
const BLOCK := 54.0
const ROAD_MAX := 162.0

const CAR_MAX := 45.0
const CAR_ACCEL := 16.0
const CAR_BRAKE := 32.0
const WHEELBASE := 4.2
const GAUGE_MAX := 220.0
const MAP_HALF := 180.0
const MINI_SIZE := 300.0
const MINI_VIEW := 160.0

const PED_COUNT := 24
const MAX_STARS := 5
const COP_MAX := 31.0
const BULLET_SPEED := 260.0

const WEAPON_FILES := ["", "pistol", "smg", "shotgun", "rifle"]
const WEAPONS := [
	{"name": "FISTS", "dmg": 15.0, "rate": 0.45, "auto": false, "pellets": 1, "spread": 0.0, "range": 2.3, "len": 0.0},
	{"name": "PISTOL", "dmg": 26.0, "rate": 0.28, "auto": false, "pellets": 1, "spread": 0.012, "range": 80.0, "len": 0.3},
	{"name": "SMG", "dmg": 11.0, "rate": 0.075, "auto": true, "pellets": 1, "spread": 0.045, "range": 70.0, "len": 0.5},
	{"name": "SHOTGUN", "dmg": 13.0, "rate": 0.85, "auto": false, "pellets": 8, "spread": 0.09, "range": 35.0, "len": 0.8},
	{"name": "RIFLE", "dmg": 20.0, "rate": 0.11, "auto": true, "pellets": 1, "spread": 0.02, "range": 110.0, "len": 0.9},
]
const MAG_SIZE := [0, 12, 30, 6, 30]
const DEFAULT_RES := [0, 60, 180, 24, 120]
const RECOIL := [0.0, 0.035, 0.012, 0.06, 0.02]
const FLASH_SIZE := [0.0, 0.8, 1.0, 1.5, 1.2]
const TRACER_COL := [Color.WHITE, Color(1.0, 0.85, 0.45), Color(1.0, 0.7, 0.3), Color(1.0, 0.9, 0.6), Color(1.0, 0.95, 0.7)]
const APP_NAMES := ["MAP", "MY CAR", "GUNS", "TAXI", "CAMERA", "PHOTOS", "CLOCK", "STORE", "SETTINGS"]


class ArmIK extends SkeletonModifier3D:
	var ok := false
	var legs_ok := false
	var b_ur := -1
	var b_fr := -1
	var b_hr := -1
	var b_ul := -1
	var b_fl := -1
	var b_hl := -1
	var b_tr := -1
	var b_cr := -1
	var b_pr := -1
	var b_tl := -1
	var b_cl := -1
	var b_pl := -1
	var rmode := 0
	var lmode := 0
	var rw := 0.0
	var lw := 0.0
	var leg_w := 0.0
	var phase := 0.0
	var swing := 0.5
	var aim_dir := Vector3.FORWARD
	var fwd := Vector3.FORWARD
	var side := Vector3.RIGHT

	func _set(is_right: bool, role: String, i: int) -> void:
		if is_right:
			if role == "u" and b_ur < 0: b_ur = i
			elif role == "f" and b_fr < 0: b_fr = i
			elif role == "h" and b_hr < 0: b_hr = i
			elif role == "t" and b_tr < 0: b_tr = i
			elif role == "c" and b_cr < 0: b_cr = i
			elif role == "p" and b_pr < 0: b_pr = i
		else:
			if role == "u" and b_ul < 0: b_ul = i
			elif role == "f" and b_fl < 0: b_fl = i
			elif role == "h" and b_hl < 0: b_hl = i
			elif role == "t" and b_tl < 0: b_tl = i
			elif role == "c" and b_cl < 0: b_cl = i
			elif role == "p" and b_pl < 0: b_pl = i

	func setup(sk: Skeleton3D) -> void:
		var re := RegEx.new()
		re.compile("[_.]\\d{3}$")
		for i in sk.get_bone_count():
			var l := re.sub(sk.get_bone_name(i).to_lower(), "")
			if l.contains("thumb") or l.contains("index") or l.contains("middle") or l.contains("ring") or l.contains("pinky") or l.contains("finger"):
				continue
			if l.contains("twist") or l.contains("roll") or l.contains("helper") or l.contains("shoulder") or l.contains("clav") or l.contains("toe"):
				continue
			var right := l.contains("right") or l.ends_with("_r") or l.ends_with(".r") or l.contains("_r_")
			var left := l.contains("left") or l.ends_with("_l") or l.ends_with(".l") or l.contains("_l_")
			if not right and not left:
				continue
			var role := ""
			if l.contains("forearm") or l.contains("lowerarm") or l.contains("fore_arm"):
				role = "f"
			elif l.contains("hand"):
				role = "h"
			elif l.contains("upleg") or l.contains("thigh") or l.contains("upperleg"):
				role = "t"
			elif l.contains("foot"):
				role = "p"
			elif l.contains("leg") or l.contains("calf") or l.contains("shin"):
				role = "c"
			elif l.contains("arm"):
				role = "u"
			if role == "":
				continue
			_set(right, role, i)
		ok = b_ur >= 0 and b_fr >= 0 and b_hr >= 0
		legs_ok = b_tr >= 0 and b_cr >= 0 and b_pr >= 0 and b_tl >= 0 and b_cl >= 0 and b_pl >= 0

	func _process_modification() -> void:
		_run()

	func _process_modification_with_delta(_delta: float) -> void:
		_run()

	func _run() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		if ok:
			_arm(sk, b_ur, b_fr, b_hr, rmode, rw, false)
			_arm(sk, b_ul, b_fl, b_hl, lmode, lw, true)
		if legs_ok and leg_w > 0.01:
			_leg(sk, b_tr, b_cr, b_pr, phase, leg_w)
			_leg(sk, b_tl, b_cl, b_pl, phase + PI, leg_w)

	func _arm(sk: Skeleton3D, bu: int, bf: int, bh: int, mode: int, w: float, is_left: bool) -> void:
		if w <= 0.01 or mode == 0 or bu < 0 or bf < 0 or bh < 0:
			return
		var inv := sk.global_transform.basis.inverse()
		var du := Vector3.DOWN
		var df := Vector3.DOWN
		if mode == 1:
			du = aim_dir
			df = aim_dir
			if is_left:
				du = (aim_dir + side * 0.18).normalized()
				df = (aim_dir + side * 0.1).normalized()
		elif mode == 2:
			var sd := -0.12 if is_left else 0.12
			du = (Vector3.DOWN + side * sd).normalized()
			df = (Vector3.DOWN + side * sd * 0.5 + fwd * 0.12).normalized()
		elif mode == 4:
			var sgn := -1.0 if is_left else 1.0
			var a := sin(phase + (0.0 if is_left else PI)) * swing * 0.7
			var a2 := a + 0.25 + swing * 0.55
			du = (Vector3.DOWN * cos(a) + fwd * sin(a) + side * sgn * 0.12).normalized()
			df = (Vector3.DOWN * cos(a2) + fwd * sin(a2) + side * sgn * 0.06).normalized()
		else:
			du = (Vector3.DOWN * 0.8 + fwd * 0.5).normalized()
			df = (Vector3.UP * 0.7 + fwd * 0.6 - side * 0.3).normalized()
		_point(sk, bu, bf, (inv * du).normalized(), w)
		_point(sk, bf, bh, (inv * df).normalized(), w)

	func _leg(sk: Skeleton3D, bt: int, bc: int, bp: int, ph: float, w: float) -> void:
		var inv := sk.global_transform.basis.inverse()
		var a := sin(ph) * swing * 0.9
		var bend := maxf(cos(ph), 0.0) * (0.35 + swing * 0.9)
		var b := a - bend
		var du := (Vector3.DOWN * cos(a) + fwd * sin(a)).normalized()
		var df := (Vector3.DOWN * cos(b) + fwd * sin(b)).normalized()
		_point(sk, bt, bc, (inv * du).normalized(), w)
		_point(sk, bc, bp, (inv * df).normalized(), w)

	func _point(sk: Skeleton3D, b: int, child: int, target: Vector3, w: float) -> void:
		var pose: Transform3D = sk.get_bone_global_pose(b)
		var cp: Transform3D = sk.get_bone_global_pose(child)
		var cur := cp.origin - pose.origin
		if cur.length() < 0.0001:
			return
		cur = cur.normalized()
		var q := Quaternion(cur, target)
		var sc := pose.basis.get_scale()
		var ob := pose.basis.orthonormalized()
		var nb := (Basis(q) * ob).orthonormalized()
		var rb := ob.slerp(nb, w)
		pose.basis = Basis(rb.x * sc.x, rb.y * sc.y, rb.z * sc.z)
		sk.set_bone_global_pose(b, pose)


class Ped extends CharacterBody3D:
	var hp := 40.0
	var dead := false
	var dead_t := 0.0
	var a_ix := 0
	var a_iz := 0
	var b_ix := 0
	var b_iz := 0
	var t := 0.0
	var lane := 5.5
	var panic := 0.0
	var walk_t := 0.0
	var leg_l: Node3D
	var leg_r: Node3D
	var arm_l: Node3D
	var arm_r: Node3D
	var anim: AnimationPlayer
	var anims := {}
	var a_walk := ""
	var a_run := ""
	var a_idle := ""
	var a_cur := ""
	var anim_ok := false
	var ckey := ""
	var ik: ArmIK
	var prop: Node3D
	var prop_par: Node3D


class Cop extends CharacterBody3D:
	var hp := 160.0
	var dead := false
	var speed := 0.0
	var path := PackedVector2Array()
	var path_i := 0
	var repath := 0.0
	var stuck_t := 0.0
	var reverse_t := 0.0
	var leave_t := 0.0
	var abandon_t := 0.0
	var crew := 2
	var outs: Array = []
	var siren: AudioStreamPlayer3D
	var mat_a: StandardMaterial3D
	var mat_b: StandardMaterial3D


class Officer extends Ped:
	var home: Cop
	var shoot_cd := 1.0
	var leave_t := 0.0
	var far_t := 0.0
	var fire_t := 0.0
	var aiming := false
	var moving := false


var player: CharacterBody3D
var player_col: CollisionShape3D
var model: Node3D
var char_skeleton: Skeleton3D
var player_ik: ArmIK
var hold_parent: Node3D
var hand_scaled := false
var gun_node: Node3D
var gun_mesh: MeshInstance3D
var gun_visuals: Array[Node3D] = []
var phone_node: Node3D
var cam: Camera3D
var ui: Control
var mini_panel: Panel
var mini: Control
var big: Control
var wheel: Control
var pc: Control

var cam_yaw := 0.0
var cam_pitch := 0.18
var aim_pitch := 0.1
var aim_blend := 0.0
var recoil := 0.0
var stick_id := -1
var look_id := -1
var jump_id := -1
var fire_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var want_jump := false
var speed := 0.0
var anim_t := 0.0
var time := 0.0
var ik_phase := 0.0

var hips: Node3D
var torso: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var anim_player: AnimationPlayer
var a_idle := ""
var a_walk := ""
var a_run := ""
var a_jump := ""
var a_aim := ""
var a_cur := ""
var weapon_anims := {}
var fire_anim_t := 0.0
var raise_t := 0.0
var prev_armed := false
var hand_bone_name := ""
var char_scale_dbg := ""
var anim_files := 0
var anim_total := 0
var anim_kept := 0
var anim_src := {}
var anim_cache := {}
var anim_flags := {}
var anim_stats := {}
var anim_miss := {}
var suffix_re := RegEx.new()

var car: CharacterBody3D
var car_visual: Node3D
var car_wheels: Array[Node3D] = []
var car_speed := 0.0
var car_steer := 0.0
var car_accel_s := 0.0
var in_car := false
var near_car := false

var map_open := false
var wheel_open := false
var phone_open := false
var phone_t := 0.0
var phone_scale := 0.8
var police_called := 0.0
var phone_raise_t := 0.0
var bld_rects: Array[Rect2] = []
var block_rects: Array[Rect2] = []
var dest_set := false
var dest := Vector2.ZERO
var route: Array[Vector2] = []
var route_timer := 0.0
var astar := AStar2D.new()
var dest_marker: MeshInstance3D
var arrived_t := 0.0
var toast_msg := ""
var toast_t := 0.0

var hp := 100.0
var dead := false
var wasted_t := 0.0
var hurt_flash := 0.0

var cur_weapon := 1
var ammo_mag: Array[int] = [0, 12, 30, 6, 30]
var ammo_res: Array[int] = [0, 60, 180, 24, 120]
var fire_cd := 0.0
var fire_queued := false
var reloading := false
var reload_t := 0.0
var aim_t := 0.0
var punch_t := 0.0
var shot_count := 0

var peds: Array[Ped] = []
var cops: Array[Cop] = []
var officers: Array[Officer] = []
var stars := 0
var wanted_cool := 0.0
var evade_t := 0.0
var spawn_t := 0.0
var ped_spawn_t := 0.0

var fx: Array[Dictionary] = []
var tr_mat_c: StandardMaterial3D
var tracer_mats: Array[StandardMaterial3D] = []
var bullet_tmpl: Array[Node3D] = []
var flash_mat: StandardMaterial3D
var spark_mat: StandardMaterial3D
var brass_mat: StandardMaterial3D
var flash_cone: CylinderMesh
var flash_core: SphereMesh
var spark_mesh: SphereMesh
var smoke_mesh: SphereMesh
var casing_mesh: BoxMesh

var sfx := {}
var engine_snd: AudioStreamPlayer
var skid_snd: AudioStreamPlayer
var step_t := 0.0
var scream_cd := 0.0
var crash_cd := 0.0

var ped_torso_mesh: BoxMesh
var ped_head_mesh: SphereMesh
var ped_leg_mesh: BoxMesh
var ped_arm_mesh: BoxMesh
var shirt_mats: Array[StandardMaterial3D] = []
var skin_mats: Array[StandardMaterial3D] = []
var pant_mat: StandardMaterial3D
var off_shirt: StandardMaterial3D
var off_pants: StandardMaterial3D
var ped_glbs: Array[String] = []

var sb_body: StyleBoxFlat
var sb_screen: StyleBoxFlat
var sb_notch: StyleBoxFlat
var sb_apps: Array[StyleBoxFlat] = []
var sb_pill: StyleBoxFlat
var sb_btn: StyleBoxFlat
var sb_map: StyleBoxFlat
var apps = null


func _ready() -> void:
	randomize()
	suffix_re.compile("[_.]\\d{3}$")
	_init_assets()
	_load_anim_sources()
	_build_sounds()
	_build_bullet_templates()
	_build_world()
	_build_city()
	_build_player()
	_build_car()
	_build_ui()
	_build_marker()
	_set_weapon(1, false)
	for i in PED_COUNT:
		_spawn_ped()
	var ikt := "IK: YES" if (player_ik != null and player_ik.ok) else "IK: NO"
	var lgt := "LEGS: YES" if (player_ik != null and player_ik.legs_ok) else "LEGS: NO"
	var lines: Array[String] = []
	lines.append("%s | %s | HAND: %s | %s" % [ikt, lgt, hand_bone_name if hand_bone_name != "" else "NOT FOUND", char_scale_dbg])
	lines.append("ANIM FILES: %d | TRACKS: %d/%d" % [anim_files, anim_kept, anim_total])
	var st: Dictionary = anim_stats.get("player", {})
	for k in ["0_idle", "0_walk", "0_run"]:
		if st.has(k):
			lines.append("%s  %s" % [k, st[k]])
		else:
			lines.append("%s  MISSING" % k)
	var miss: Dictionary = anim_miss.get("player", {})
	if miss.has("0_walk") and not (miss["0_walk"] as Array).is_empty():
		lines.append("WALK MISS: " + ", ".join(PackedStringArray(miss["0_walk"])))
	if char_skeleton != null:
		var names: Array[String] = []
		for i in char_skeleton.get_bone_count():
			var bn := char_skeleton.get_bone_name(i)
			var lw := bn.to_lower()
			if (lw.contains("arm") or lw.contains("leg")) and names.size() < 4:
				names.append(bn)
		lines.append("CHAR BONES: " + ", ".join(PackedStringArray(names)))
	_toast("\n".join(PackedStringArray(lines)), 16.0)
	if ResourceLoader.exists("res://game/apps.gd"):
		var sc = load("res://game/apps.gd")
		if sc != null:
			apps = Node.new()
			apps.set_script(sc)
			apps.set("g", self)
			add_child(apps)


# ---------------------------------------------------------------- helpers

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _additive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	return m


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _jump_center() -> Vector2:
	return _vp() - Vector2(170, 170)


func _act_center() -> Vector2:
	return _vp() - Vector2(350, 130)


func _fire_center() -> Vector2:
	return _vp() - Vector2(170, 390)


func _wpn_center() -> Vector2:
	return _vp() - Vector2(370, 310)


func _phone_btn_center() -> Vector2:
	return Vector2(100, 110)


func _mini_rect() -> Rect2:
	var s := _vp()
	return Rect2(s.x - MINI_SIZE - 40.0, 40.0, MINI_SIZE, MINI_SIZE)


func _big_rect() -> Rect2:
	var s := _vp()
	var d := s.y - 48.0
	return Rect2((s.x - d) / 2.0, 24.0, d, d)


func _close_rect() -> Rect2:
	return Rect2(_vp().x - 280.0, 30.0, 240.0, 90.0)


func _clear_rect() -> Rect2:
	return Rect2(_vp().x - 280.0, 140.0, 240.0, 90.0)


func _prect() -> Rect2:
	var s := _vp()
	var sz := Vector2(440.0, 900.0) * phone_scale
	var k := phone_t * phone_t * (3.0 - 2.0 * phone_t)
	var y := lerpf(s.y + 30.0, s.y - sz.y - 20.0, k)
	return Rect2(s.x * PHONE_X_FRAC - sz.x * 0.5, y, sz.x, sz.y)


func _icon_rect(i: int) -> Rect2:
	var col := i % 3
	var row := i / 3
	return Rect2(46.0 + float(col) * 128.0, 190.0 + float(row) * 160.0, 104.0, 104.0)


func _wheel_pos(i: int) -> Vector2:
	var a := -PI * 0.5 + TAU * float(i) / float(WEAPONS.size())
	return _vp() * 0.5 + Vector2(cos(a), sin(a)) * 250.0


func _txt(c: Control, t: String, p: Vector2, size: int, col: Color = Color.WHITE) -> void:
	c.draw_string(ThemeDB.fallback_font, p + Vector2(-150.0, size * 0.35), t, HORIZONTAL_ALIGNMENT_CENTER, 300, size, col)


func _toast(m: String, t: float = 2.5) -> void:
	toast_msg = m
	toast_t = t


func _box(pos: Vector3, size: Vector3, mat: Material, solid: bool) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = size
		cs.shape = bx
		sb.position = pos
		sb.add_child(mi)
		sb.add_child(cs)
		add_child(sb)
	else:
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _spherem(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _limb(parent: Node3D, pivot_pos: Vector3, r: float, h: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	_part(pivot, cm, Vector3(0, -h / 2.0, 0), mat)
	return pivot


func _pivot_mesh(parent: Node3D, pos: Vector3, mesh: Mesh, off_y: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_part(pivot, mesh, Vector3(0, -off_y, 0), mat)
	return pivot


func _nid(ix: int, iz: int) -> int:
	return (ix + 3) * 7 + (iz + 3)


func _node_for(p: Vector2) -> int:
	return _nid(clampi(roundi(p.x / BLOCK), -3, 3), clampi(roundi(p.y / BLOCK), -3, 3))


func _neighbors(ix: int, iz: int) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	if ix > -3:
		r.append(Vector2i(ix - 1, iz))
	if ix < 3:
		r.append(Vector2i(ix + 1, iz))
	if iz > -3:
		r.append(Vector2i(ix, iz - 1))
	if iz < 3:
		r.append(Vector2i(ix, iz + 1))
	return r


func _snap_to_road(w: Vector2) -> Vector2:
	var rx := clampf(roundf(w.x / BLOCK) * BLOCK, -ROAD_MAX, ROAD_MAX)
	var rz := clampf(roundf(w.y / BLOCK) * BLOCK, -ROAD_MAX, ROAD_MAX)
	if absf(w.x - rx) < absf(w.y - rz):
		return Vector2(rx, clampf(w.y, -ROAD_MAX, ROAD_MAX))
	return Vector2(clampf(w.x, -ROAD_MAX, ROAD_MAX), rz)


func _first(list: Array) -> String:
	for s in list:
		if String(s) != "":
			return String(s)
	return ""


func _init_assets() -> void:
	tr_mat_c = _additive(Color(1.0, 0.45, 0.25))
	for i in WEAPONS.size():
		tracer_mats.append(_additive(TRACER_COL[i]))
	flash_mat = _additive(Color(1.0, 0.8, 0.45, 0.95))
	spark_mat = _additive(Color(1.0, 0.8, 0.35))
	brass_mat = _mat(Color(0.85, 0.65, 0.2))
	brass_mat.metallic = 0.9
	brass_mat.roughness = 0.3
	flash_cone = CylinderMesh.new()
	flash_cone.top_radius = 0.0
	flash_cone.bottom_radius = 0.08
	flash_cone.height = 0.3
	flash_core = _spherem(0.07)
	spark_mesh = _spherem(0.022)
	smoke_mesh = _spherem(0.07)
	casing_mesh = _boxm(Vector3(0.016, 0.016, 0.055))

	ped_torso_mesh = _boxm(Vector3(0.42, 0.6, 0.24))
	ped_head_mesh = _spherem(0.13)
	ped_leg_mesh = _boxm(Vector3(0.16, 0.85, 0.18))
	ped_arm_mesh = _boxm(Vector3(0.11, 0.55, 0.13))
	var shirts := [
		Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.8, 0.2), Color(0.3, 0.7, 0.4),
		Color(0.7, 0.4, 0.8), Color(0.9, 0.5, 0.2), Color(0.85, 0.85, 0.85), Color(0.2, 0.2, 0.25)
	]
	for c in shirts:
		shirt_mats.append(_mat(c))
	for c in [Color(0.87, 0.67, 0.52), Color(0.65, 0.45, 0.32), Color(0.45, 0.3, 0.22)]:
		skin_mats.append(_mat(c))
	pant_mat = _mat(Color(0.15, 0.17, 0.25))
	off_shirt = _mat(Color(0.1, 0.18, 0.45))
	off_pants = _mat(Color(0.05, 0.07, 0.15))
	for i in range(1, PED_GLB_COUNT + 1):
		var path := "res://game/peds/ped%d.glb" % i
		if ResourceLoader.exists(path):
			ped_glbs.append(path)

	sb_body = StyleBoxFlat.new()
	sb_body.bg_color = Color(0.03, 0.03, 0.05)
	sb_body.set_corner_radius_all(64)
	sb_body.border_color = Color(0.55, 0.55, 0.62)
	sb_body.set_border_width_all(6)
	sb_screen = StyleBoxFlat.new()
	sb_screen.bg_color = Color(0.07, 0.1, 0.22)
	sb_screen.set_corner_radius_all(46)
	sb_notch = StyleBoxFlat.new()
	sb_notch.bg_color = Color(0.0, 0.0, 0.0)
	sb_notch.set_corner_radius_all(13)
	var icol := [
		Color(0.2, 0.75, 0.45), Color(0.25, 0.5, 0.95), Color(0.95, 0.75, 0.2), Color(0.95, 0.55, 0.15),
		Color(0.55, 0.45, 0.9), Color(0.9, 0.4, 0.6), Color(0.3, 0.3, 0.38), Color(0.2, 0.7, 0.8), Color(0.5, 0.5, 0.55)
	]
	for c in icol:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(28)
		sb_apps.append(sb)
	sb_pill = StyleBoxFlat.new()
	sb_pill.bg_color = Color(0.05, 0.06, 0.08, 0.7)
	sb_pill.set_corner_radius_all(22)
	sb_pill.border_color = Color(1, 1, 1, 0.8)
	sb_pill.set_border_width_all(2)
	sb_btn = StyleBoxFlat.new()
	sb_btn.bg_color = Color(1, 1, 1, 0.12)
	sb_btn.set_corner_radius_all(26)
	sb_btn.border_color = Color(1, 1, 1, 0.9)
	sb_btn.set_border_width_all(3)
	sb_map = StyleBoxFlat.new()
	sb_map.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	sb_map.set_corner_radius_all(28)
	sb_map.border_color = Color(1, 1, 1, 0.9)
	sb_map.set_border_width_all(4)


func _build_bullet_templates() -> void:
	bullet_tmpl.append(null)
	for i in range(1, WEAPONS.size()):
		var path := BULLET_DIR + String(WEAPON_FILES[i]) + ".glb"
		bullet_tmpl.append(_fit_glb(path, BULLET_GLB_YAW, BULLET_LEN, false, false))


# ---------------------------------------------------------------- glb helpers

func _collect_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var a: AABB = t * mi.mesh.get_aabb()
			if acc.is_empty():
				acc.append(a)
			else:
				acc[0] = (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_collect_aabb(c, t, acc)


func _fit_glb(path: String, yaw: float, target: float, by_height: bool, ground: bool) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scn := load(path) as PackedScene
	if scn == null:
		return null
	var inst := scn.instantiate() as Node3D
	if inst == null:
		return null
	var acc: Array = []
	_collect_aabb(inst, Transform3D.IDENTITY, acc)
	var holder := Node3D.new()
	holder.add_child(inst)
	if acc.is_empty():
		return holder
	var bb: AABB = acc[0]
	var base_yaw := 0.0
	var len := bb.size.y
	if not by_height:
		len = bb.size.z
		if bb.size.x > bb.size.z:
			base_yaw = PI * 0.5
			len = bb.size.x
	var s := target / maxf(len, 0.001)
	var py := -bb.position.y
	if not ground:
		py = -(bb.position.y + bb.size.y * 0.5)
	inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5), py, -(bb.position.z + bb.size.z * 0.5))
	holder.scale = Vector3.ONE * s
	holder.rotation.y = base_yaw + yaw
	return holder


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null


func _bone_range(sk: Skeleton3D, holder: Node3D) -> Vector2:
	var xf := Transform3D.IDENTITY
	var n: Node = sk
	var stop := holder.get_parent()
	while n != null and n != stop:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var mn := 1e9
	var mx := -1e9
	for i in sk.get_bone_count():
		var y := (xf * sk.get_bone_global_rest(i).origin).y
		mn = minf(mn, y)
		mx = maxf(mx, y)
	return Vector2(mn, mx)


func _fit_by_bones(holder: Node3D, sk: Skeleton3D, target_h: float) -> void:
	if sk == null:
		return
	var pad := 1.07
	for i in sk.get_bone_count():
		var l := sk.get_bone_name(i).to_lower()
		if l.contains("headtop") or l.contains("head_end") or l.contains("headend"):
			pad = 1.0
	var mm := _bone_range(sk, holder)
	var h := mm.y - mm.x
	if h < 0.0001:
		return
	holder.scale *= target_h / (h * pad)
	var mm2 := _bone_range(sk, holder)
	holder.position.y -= mm2.x


func _find_hand_bone(sk: Skeleton3D) -> String:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		var l := n.to_lower()
		if not l.contains("hand"):
			continue
		if l.contains("thumb") or l.contains("index") or l.contains("middle") or l.contains("ring") or l.contains("pinky") or l.contains("finger"):
			continue
		var right := l.contains("right") or l.ends_with("_r") or l.ends_with(".r") or l.contains("r_hand") or l.contains("hand_r") or l.contains("hand.r")
		if right:
			return n
	return ""


func _find_anim(ap: AnimationPlayer, keys: Array) -> String:
	for n in ap.get_animation_list():
		var l := String(n).to_lower()
		for k in keys:
			if l.contains(k):
				return String(n)
	return ""


func _set_loop(ap: AnimationPlayer, n: String) -> void:
	if n != "":
		ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR


# ---------------------------------------------------------------- animations (FBX / GLB files)

func canon(n: String) -> String:
	var l := n.to_lower()
	if l.contains(":"):
		l = l.get_slice(":", l.get_slice_count(":") - 1)
	for pre in ["mixamorig", "bip001", "bip01", "def-", "def_", "cc_base_", "jnt_"]:
		l = l.replace(pre, "")
	l = suffix_re.sub(l, "")
	var side := ""
	if l.contains("left"):
		side = "l"
		l = l.replace("left", "")
	elif l.contains("right"):
		side = "r"
		l = l.replace("right", "")
	else:
		for suf in ["_l", ".l", "-l"]:
			if l.ends_with(suf):
				side = "l"
				l = l.trim_suffix(suf)
		for suf in ["_r", ".r", "-r"]:
			if l.ends_with(suf):
				side = "r"
				l = l.trim_suffix(suf)
	var o := ""
	for ch in l:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			o += ch
	for pair in [["upperarm", "arm"], ["lowerarm", "forearm"], ["clavicle", "shoulder"], ["pelvis", "hips"], ["thigh", "upleg"], ["upperleg", "upleg"], ["calf", "leg"], ["shin", "leg"], ["lowerleg", "leg"], ["spine01", "spine"], ["spine02", "spine1"], ["spine03", "spine2"], ["neck01", "neck"], ["toes", "toebase"], ["ball", "toebase"]]:
		if o == pair[0]:
			o = pair[1]
	return side + o


func _anim_parse(low: String) -> Array:
	var skip := ["crouch", "offset", "d90", "u90", "root_motion", "bwd", "back", "left", "right", "strafe", "turn"]
	for s in skip:
		if low.contains(s):
			return []
	var widx := 0
	for i in range(1, WEAPONS.size()):
		for tag in WEAPON_ANIM_TAGS[i]:
			if low.contains(String(tag)):
				widx = i
	if low.contains("phone") or low.contains("call") or low.contains("text"):
		widx = 9
	var base := ""
	if low.contains("raise") or low.contains("draw") or low.contains("equip") or low.contains("unholster"):
		base = "raise"
	elif low.contains("fire") or low.contains("shoot"):
		base = "fire"
	elif low.contains("aim"):
		base = "aim"
	elif low.contains("idle"):
		base = "idle"
	elif low.contains("jump") or low.contains("fall"):
		base = "jump"
	elif low.contains("sprint") or low.contains("run") or low.contains("jog"):
		base = "run"
	elif low.contains("walk"):
		base = "walk"
	if base == "" and widx == 9:
		base = "raise"
	if base == "" and widx > 0:
		base = "aim"
	if base == "":
		return []
	return [widx, base]


func _load_anim_sources() -> void:
	var da := DirAccess.open(ANIM_DIR)
	if da == null:
		return
	var seen := {}
	for f in da.get_files():
		var fn := String(f)
		if fn.ends_with(".import"):
			fn = fn.trim_suffix(".import")
		elif fn.ends_with(".remap"):
			fn = fn.trim_suffix(".remap")
		var low := fn.to_lower()
		if not (low.ends_with(".fbx") or low.ends_with(".glb") or low.ends_with(".gltf")):
			continue
		if seen.has(fn):
			continue
		seen[fn] = true
		var parsed := _anim_parse(low)
		if parsed.is_empty():
			continue
		var key := "%d_%s" % [parsed[0], parsed[1]]
		if anim_src.has(key):
			continue
		var scn := load(ANIM_DIR + fn) as PackedScene
		if scn == null:
			continue
		var inst := scn.instantiate()
		var src := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src != null:
			var best: Animation = null
			for n in src.get_animation_list():
				if String(n) == "RESET":
					continue
				var a := src.get_animation(n)
				if best == null or a.length > best.length:
					best = a
			if best != null:
				anim_src[key] = best
				anim_files += 1
		inst.free()


func _retarget(ap: AnimationPlayer, sk: Skeleton3D, ckey: String) -> Dictionary:
	var result := {}
	if sk == null or anim_src.is_empty():
		return result
	if not ap.has_animation_library(""):
		ap.add_animation_library("", AnimationLibrary.new())
	var lib := ap.get_animation_library("")
	if anim_cache.has(ckey):
		var cached: Dictionary = anim_cache[ckey]
		for k in cached.keys():
			lib.add_animation("x_" + String(k), cached[k])
			result[k] = "x_" + String(k)
		return result

	var base := ap.get_node(ap.root_node)
	var sk_path := str(base.get_path_to(sk))
	var bone_map := {}
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		bone_map[canon(bn)] = bn
	var store := {}
	var flags := {}
	var stats := {}
	var misses := {}
	for k in anim_src.keys():
		var anim := (anim_src[k] as Animation).duplicate() as Animation
		var tot := anim.get_track_count()
		var arm_n := 0
		var leg_n := 0
		var miss: Array = []
		for t in range(tot - 1, -1, -1):
			var ttype := anim.track_get_type(t)
			var tp := anim.track_get_path(t)
			if ttype != Animation.TYPE_ROTATION_3D or tp.get_subname_count() == 0:
				anim.remove_track(t)
				continue
			var raw := tp.get_subname(0)
			var nb := canon(raw)
			if not bone_map.has(nb):
				if miss.size() < 4:
					miss.append(raw)
				anim.remove_track(t)
				continue
			if nb in ["rarm", "larm", "rforearm", "lforearm"]:
				arm_n += 1
			elif nb in ["rupleg", "lupleg", "rleg", "lleg"]:
				leg_n += 1
			anim.track_set_path(t, NodePath(sk_path + ":" + String(bone_map[nb])))
		var kept := anim.get_track_count()
		var arms := arm_n >= 2
		var legs := leg_n >= 2
		stats[k] = "%d/%d A:%s L:%s" % [kept, tot, "Y" if arms else "N", "Y" if legs else "N"]
		misses[k] = miss
		if ckey == "player":
			anim_total += tot
			anim_kept += kept
		if kept < 6:
			continue
		var base_name := String(k).get_slice("_", 1)
		var looped := base_name in ["idle", "aim", "walk", "run"]
		anim.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		var aname := "x_" + String(k)
		lib.add_animation(aname, anim)
		store[k] = anim
		flags[aname] = [arms, legs]
		result[k] = aname
	anim_cache[ckey] = store
	anim_flags[ckey] = flags
	anim_stats[ckey] = stats
	anim_miss[ckey] = misses
	return result


func _flags(ckey: String, aname: String) -> Array:
	if aname == "":
		return [false, false]
	var d: Dictionary = anim_flags.get(ckey, {})
	if d.has(aname):
		return d[aname]
	return [true, true]


func _wa(w: int, base: String) -> String:
	return String(weapon_anims.get("%d_%s" % [w, base], ""))


func _any(base: String) -> String:
	for i in range(1, WEAPONS.size()):
		var n := _wa(i, base)
		if n != "":
			return n
	return ""


func _wx(w: int, base: String) -> String:
	return _first([_wa(w, base), _wa(0, base), _any(base)])


func _setup_anim(p: Ped, root: Node3D, ckey: String) -> void:
	p.ckey = ckey
	var sk := _find_skeleton(root)
	_fit_by_bones(root, sk, 1.8)
	p.anim = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if p.anim == null and sk != null:
		p.anim = AnimationPlayer.new()
		root.add_child(p.anim)
	if p.anim == null:
		return
	p.a_walk = _find_anim(p.anim, ["walk"])
	p.a_run = _find_anim(p.anim, ["run", "sprint", "jog"])
	p.a_idle = _find_anim(p.anim, ["idle", "stand"])
	_set_loop(p.anim, p.a_walk)
	_set_loop(p.anim, p.a_run)
	_set_loop(p.anim, p.a_idle)
	var res := _retarget(p.anim, sk, ckey)
	if not res.is_empty():
		p.anims = res
		var g := String(res.get("0_idle", ""))
		if g != "":
			p.a_idle = g
		g = String(res.get("0_walk", ""))
		if g != "":
			p.a_walk = g
		g = String(res.get("0_run", ""))
		if g != "":
			p.a_run = g
	if p.a_run == "":
		p.a_run = p.a_walk
	p.anim_ok = p.a_idle != "" or p.a_walk != ""
	if sk != null:
		var ik := ArmIK.new()
		sk.add_child(ik)
		ik.setup(sk)
		p.ik = ik
		if p is Officer:
			_give_gun(p, sk)


func _give_gun(p: Ped, sk: Skeleton3D) -> void:
	var hb := _find_hand_bone(sk)
	if hb == "":
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = hb
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(90, 0, 0)
	att.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = _boxm(Vector3(0.05, 0.12, 0.22))
	mi.position = Vector3(0, 0, -0.1)
	mi.material_override = _mat(Color(0.07, 0.07, 0.09))
	holder.add_child(mi)
	p.prop = holder
	p.prop_par = att


func _ped_play(p: Ped, want: String) -> void:
	if p.anim == null or want == "" or want == p.a_cur:
		return
	p.a_cur = want
	p.anim.play(want, 0.2)


# ---------------------------------------------------------------- sounds (synth + optional files)

func _wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _synth_shot(dur: float, vol: float, cutoff: float, dscale: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var a := clampf(cutoff / float(rate) * 2.0, 0.02, 0.95)
	for i in n:
		var t := float(i) / rate
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * a
		var env := exp(-t / (dur * dscale))
		var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.8
		var crack := noise * exp(-t * 90.0) * 0.6
		s[i] = (lp * env * 1.3 + thump + crack) * vol
	return _wav(s, rate, false)


func _synth_step() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.13 * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.18
		s[i] = (lp * exp(-t * 38.0) * 0.9 + sin(TAU * 95.0 * t) * exp(-t * 45.0) * 0.5) * 0.7
	return _wav(s, rate, false)


func _synth_crash() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.7 * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.35
		var ring := sin(TAU * 310.0 * t) * 0.25 + sin(TAU * 437.0 * t) * 0.2
		s[i] = (lp * exp(-t * 7.0) * 1.1 + sin(TAU * 52.0 * t) * exp(-t * 9.0) + ring * exp(-t * 6.0)) * 0.8
	return _wav(s, rate, false)


func _synth_scream() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.8
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var f := 620.0 + 380.0 * sin(t * 5.0) + 260.0 * t
		ph += TAU * f / rate
		var env := pow(sin(PI * t / dur), 0.6)
		var v := sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0) + (randf() * 2.0 - 1.0) * 0.12
		s[i] = v * env * 0.3
	return _wav(s, rate, false)


func _synth_siren() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.6
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var f := 760.0 + 420.0 * (0.5 - 0.5 * cos(TAU * t / dur))
		ph += TAU * f / rate
		s[i] = (sin(ph) + 0.35 * sin(ph * 3.0) + 0.15 * sin(ph * 5.0)) * 0.3
	return _wav(s, rate, true)


func _synth_engine() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for k in range(1, 7):
			v += sin(TAU * 55.0 * float(k) * t) / float(k)
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.1
		var am := 0.75 + 0.25 * sin(TAU * 11.0 * t)
		s[i] = (v * 0.28 * am + lp * 0.07)
	return _wav(s, rate, true)


func _synth_skid() -> AudioStreamWAV:
	var rate := 22050
	var n := rate
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var x := randf() * 2.0 - 1.0
		lp += (x - lp) * 0.25
		s[i] = (x - lp) * 0.35
	return _wav(s, rate, true)


func _synth_click(count: int) -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.55 * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	for c in count:
		var start := int(float(c) * 0.28 * rate)
		for i in range(0, int(0.02 * rate)):
			if start + i < n:
				s[start + i] = (randf() * 2.0 - 1.0) * exp(-float(i) / (0.004 * rate)) * 0.8
	return _wav(s, rate, false)


func _synth_radio() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.4 * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		var f := 1250.0 if t < 0.12 else (900.0 if t < 0.24 else 0.0)
		var tone := sin(TAU * f * t) * 0.35 if f > 0.0 else 0.0
		s[i] = tone + (randf() * 2.0 - 1.0) * 0.06 * exp(-t * 4.0)
	return _wav(s, rate, false)


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true


func _load_sound_file(key: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var p := "%s%s.%s" % [SND_DIR, key, ext]
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s != null:
				if key in ["engine", "siren", "skid"]:
					_make_loop(s)
				return s
	return null


func _build_sounds() -> void:
	sfx["pistol"] = _synth_shot(0.28, 0.9, 1800.0, 0.35)
	sfx["smg"] = _synth_shot(0.18, 0.8, 2600.0, 0.5)
	sfx["shotgun"] = _synth_shot(0.55, 1.0, 900.0, 0.2)
	sfx["rifle"] = _synth_shot(0.4, 1.0, 1400.0, 0.25)
	sfx["step"] = _synth_step()
	sfx["crash"] = _synth_crash()
	sfx["scream"] = _synth_scream()
	sfx["siren"] = _synth_siren()
	sfx["engine"] = _synth_engine()
	sfx["skid"] = _synth_skid()
	sfx["reload"] = _synth_click(2)
	sfx["radio"] = _synth_radio()
	for k in sfx.keys():
		var f := _load_sound_file(String(k))
		if f != null:
			sfx[k] = f
	engine_snd = AudioStreamPlayer.new()
	engine_snd.stream = sfx["engine"]
	engine_snd.volume_db = -80.0
	add_child(engine_snd)
	skid_snd = AudioStreamPlayer.new()
	skid_snd.stream = sfx["skid"]
	skid_snd.volume_db = -12.0
	add_child(skid_snd)


func _sfx3d(key: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, maxd: float = 140.0) -> void:
	if not sfx.has(key):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sfx[key]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.max_distance = maxd
	p.unit_size = 12.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _update_car_audio(delta: float, throttle: float, hb: bool, prev_speed: float) -> void:
	crash_cd = maxf(crash_cd - delta, 0.0)
	scream_cd = maxf(scream_cd - delta, 0.0)
	if in_car and engine_snd.stream != null:
		if not engine_snd.playing:
			engine_snd.play()
		var r := clampf(absf(car_speed) / CAR_MAX, 0.0, 1.0)
		engine_snd.pitch_scale = 0.65 + r * 1.9 + absf(throttle) * 0.15
		engine_snd.volume_db = -13.0 + absf(throttle) * 5.0 + r * 3.0
	elif engine_snd.playing:
		engine_snd.stop()
	var want_skid := in_car and hb and absf(car_speed) > 10.0
	if want_skid and not skid_snd.playing and skid_snd.stream != null:
		skid_snd.play()
	elif not want_skid and skid_snd.playing:
		skid_snd.stop()
	if prev_speed - car_speed > 9.0 and absf(prev_speed) > 10.0 and crash_cd <= 0.0:
		crash_cd = 0.8
		_sfx3d("crash", car.position, 2.0, randf_range(0.9, 1.1), 160.0)


# ---------------------------------------------------------------- effects

func _fx_add(n: Node3D, life: float, g: float = 0.0, v: Vector3 = Vector3.ZERO, grav: float = 0.0, mat: StandardMaterial3D = null, a0: float = 1.0, spin: Vector3 = Vector3.ZERO, on_floor: bool = false) -> void:
	fx.append({"n": n, "t": life, "life": maxf(life, 0.001), "g": g, "v": v, "grav": grav, "mat": mat, "a0": a0, "spin": spin, "floor": on_floor})


func _update_fx(delta: float) -> void:
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		var n: Node3D = f["n"]
		if not is_instance_valid(n):
			fx.remove_at(i)
			continue
		f["t"] = float(f["t"]) - delta
		var v: Vector3 = f["v"]
		var grav := float(f["grav"])
		if v != Vector3.ZERO or grav != 0.0:
			v.y -= grav * delta
			f["v"] = v
			n.position += v * delta
		var g := float(f["g"])
		if g > 0.0:
			n.scale += Vector3.ONE * g * delta
		var spin: Vector3 = f["spin"]
		if spin != Vector3.ZERO:
			n.rotation += spin * delta
		var m = f["mat"]
		if m != null:
			var c: Color = (m as StandardMaterial3D).albedo_color
			c.a = float(f["a0"]) * clampf(float(f["t"]) / float(f["life"]), 0.0, 1.0)
			(m as StandardMaterial3D).albedo_color = c
		var dead_fx := float(f["t"]) <= 0.0
		if bool(f["floor"]) and n.position.y < 0.03:
			dead_fx = true
		if dead_fx:
			n.queue_free()
			fx.remove_at(i)


func _tracer(from: Vector3, to: Vector3, widx: int, player_shot: bool) -> void:
	var d := to - from
	var l := d.length()
	if l < 0.05:
		return
	var dir := d / l
	var mi: Node3D
	var spd := BULLET_SPEED
	if player_shot and widx > 0 and bullet_tmpl[widx] != null:
		mi = bullet_tmpl[widx].duplicate() as Node3D
		spd = BULLET_GLB_SPEED
	else:
		var m := MeshInstance3D.new()
		m.mesh = _boxm(Vector3(0.03, 0.03, 1.2 if widx != 3 else 0.7))
		m.material_override = tracer_mats[widx] if player_shot else tr_mat_c
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi = m
	add_child(mi)
	mi.global_position = from
	var up := Vector3.UP
	if absf(dir.y) > 0.98:
		up = Vector3.RIGHT
	mi.look_at(from + dir, up)
	_fx_add(mi, maxf(l / spd, 0.03), 0.0, dir * spd)


func _muzzle_flash(pos: Vector3, dir: Vector3, size: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	var up := Vector3.UP
	if absf(dir.y) > 0.98:
		up = Vector3.RIGHT
	n.look_at(pos + dir, up)
	n.scale = Vector3.ONE * size
	var cone := MeshInstance3D.new()
	cone.mesh = flash_cone
	cone.material_override = flash_mat
	cone.rotation_degrees = Vector3(-90, 0, 0)
	cone.position = Vector3(0, 0, -0.15)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cone)
	var core := MeshInstance3D.new()
	core.mesh = flash_core
	core.material_override = flash_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	_fx_add(n, 0.05)


func _smoke(pos: Vector3, dir: Vector3, size: float, alpha: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.75, 0.78, alpha)
	var mi := MeshInstance3D.new()
	mi.mesh = smoke_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size
	_fx_add(mi, 0.7, size * 3.0, dir * 0.8 + Vector3(0, 0.5, 0), 0.0, m, alpha)


func _eject_casing(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = casing_mesh
	mi.material_override = brass_mat
	add_child(mi)
	mi.global_position = pos
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var v := right * randf_range(1.5, 3.0) + Vector3(0, randf_range(2.0, 3.5), 0)
	_fx_add(mi, 1.5, 0.0, v, 14.0, null, 1.0, Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20)), true)


func _impact(pos: Vector3, normal: Vector3, soft: bool) -> void:
	var count := 2 if soft else 4
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = spark_mesh
		mi.material_override = spark_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos
		var v := normal * randf_range(2.0, 4.0) + Vector3(randf_range(-2, 2), randf_range(0.5, 2.5), randf_range(-2, 2))
		_fx_add(mi, 0.25, 0.0, v, 12.0)
	_smoke(pos + normal * 0.1, normal, 0.05 if soft else 0.09, 0.45)


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.7, 0.8, 0.9)
	e.fog_density = 0.004
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.75
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	var ground := StaticBody3D.new()
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	gm.mesh = pm
	gm.material_override = _mat(Color(0.16, 0.16, 0.18))
	var gc := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 1, 600)
	gc.shape = bs
	gc.position.y = -0.5
	ground.add_child(gm)
	ground.add_child(gc)
	add_child(ground)


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	for x in range(9, 23):
		for y in range(7, 21):
			img.set_pixel(x, y, Color(0.35, 0.45, 0.6))
	var tex := ImageTexture.create_from_image(img)

	var tints := [
		Color(0.55, 0.5, 0.45), Color(0.4, 0.45, 0.5), Color(0.55, 0.38, 0.35),
		Color(0.38, 0.48, 0.42), Color(0.45, 0.45, 0.48), Color(0.6, 0.55, 0.35)
	]
	var mats: Array[StandardMaterial3D] = []
	for t in tints:
		var m := _mat(t)
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
		mats.append(m)

	var walk_mat := _mat(Color(0.5, 0.5, 0.52))
	for i in range(-3, 3):
		for j in range(-3, 3):
			var c := Vector3(i * BLOCK + BLOCK / 2.0, 0, j * BLOCK + BLOCK / 2.0)
			_box(c + Vector3(0, 0.03, 0), Vector3(40, 0.06, 40), walk_mat, false)
			block_rects.append(Rect2(c.x - 20.0, c.z - 20.0, 40.0, 40.0))
			for sx in [-10.0, 10.0]:
				for sz in [-10.0, 10.0]:
					if rng.randf() < 0.12:
						continue
					var h := rng.randf_range(10.0, 45.0)
					if rng.randf() < 0.25:
						h = rng.randf_range(5.0, 10.0)
					var bm: StandardMaterial3D = mats[rng.randi() % mats.size()]
					_box(c + Vector3(sx, h / 2.0, sz), Vector3(17, h, 17), bm, true)
					bld_rects.append(Rect2(c.x + sx - 8.5, c.z + sz - 8.5, 17.0, 17.0))

	var line_mat := _mat(Color(0.95, 0.8, 0.2))
	for k in range(-3, 4):
		_box(Vector3(k * BLOCK, 0.02, 0), Vector3(0.3, 0.02, 340), line_mat, false)
		_box(Vector3(0, 0.02, k * BLOCK), Vector3(340, 0.02, 0.3), line_mat, false)

	for ix in range(-3, 4):
		for iz in range(-3, 4):
			astar.add_point(_nid(ix, iz), Vector2(ix * BLOCK, iz * BLOCK))
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			if ix < 3:
				astar.connect_points(_nid(ix, iz), _nid(ix + 1, iz))
			if iz < 3:
				astar.connect_points(_nid(ix, iz), _nid(ix, iz + 1))


func _build_marker() -> void:
	dest_marker = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 120.0
	dest_marker.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.35, 1.0, 0.35)
	dest_marker.material_override = m
	dest_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dest_marker.visible = false
	add_child(dest_marker)


# ---------------------------------------------------------------- player

func _build_player() -> void:
	player = CharacterBody3D.new()
	player_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	player_col.shape = cap
	player_col.position.y = 0.9
	player.add_child(player_col)
	model = Node3D.new()
	player.add_child(model)
	player.position = Vector3(0, 0.1, 0)
	add_child(player)

	if ResourceLoader.exists(GLB_PATH):
		_build_glb()
	else:
		_build_rig()

	_attach_holdables()

	cam = Camera3D.new()
	cam.far = 600.0
	cam.position = Vector3(0, 3, 6)
	add_child(cam)
	cam.current = true


func _build_rig() -> void:
	var skin := _mat(Color(0.87, 0.67, 0.52))
	var shirt := _mat(Color(0.15, 0.35, 0.7))
	var pants := _mat(Color(0.18, 0.18, 0.22))
	var shoe := _mat(Color(0.95, 0.95, 0.95))
	var dark := _mat(Color(0.05, 0.05, 0.05))

	hips = Node3D.new()
	hips.position.y = 0.95
	model.add_child(hips)
	torso = Node3D.new()
	hips.add_child(torso)

	_part(torso, _boxm(Vector3(0.5, 0.6, 0.28)), Vector3(0, 0.3, 0), shirt)
	_part(torso, _spherem(0.14), Vector3(0, 0.78, 0), skin)
	_part(torso, _boxm(Vector3(0.22, 0.05, 0.05)), Vector3(0, 0.8, -0.12), dark)

	arm_l = _limb(torso, Vector3(-0.33, 0.52, 0), 0.07, 0.55, shirt)
	arm_r = _limb(torso, Vector3(0.33, 0.52, 0), 0.07, 0.55, shirt)
	_part(arm_l, _spherem(0.07), Vector3(0, -0.56, 0), skin)
	_part(arm_r, _spherem(0.07), Vector3(0, -0.56, 0), skin)

	leg_l = _limb(hips, Vector3(-0.13, 0, 0), 0.09, 0.9, pants)
	leg_r = _limb(hips, Vector3(0.13, 0, 0), 0.09, 0.9, pants)
	_part(leg_l, _boxm(Vector3(0.16, 0.1, 0.3)), Vector3(0, -0.9, -0.05), shoe)
	_part(leg_r, _boxm(Vector3(0.16, 0.1, 0.3)), Vector3(0, -0.9, -0.05), shoe)


func _build_glb() -> void:
	var holder := _fit_glb(GLB_PATH, GLB_YAW, CHAR_HEIGHT, true, true)
	if holder == null:
		_build_rig()
		return
	model.add_child(holder)
	char_skeleton = _find_skeleton(holder)
	if CHAR_SCALE_MANUAL > 0.0:
		holder.scale = Vector3.ONE * CHAR_SCALE_MANUAL
	else:
		_fit_by_bones(holder, char_skeleton, CHAR_HEIGHT)
	char_scale_dbg = "SCALE %.4f" % holder.scale.x
	if char_skeleton != null:
		player_ik = ArmIK.new()
		char_skeleton.add_child(player_ik)
		player_ik.setup(char_skeleton)
	anim_player = holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null and char_skeleton != null:
		anim_player = AnimationPlayer.new()
		holder.add_child(anim_player)
	if anim_player == null:
		return
	a_idle = _find_anim(anim_player, ["idle"])
	a_walk = _find_anim(anim_player, ["walk"])
	a_run = _find_anim(anim_player, ["run", "sprint", "jog"])
	a_jump = _find_anim(anim_player, ["jump", "fall"])
	a_aim = _find_anim(anim_player, ["aim", "shoot", "fire", "pistol", "rifle", "gun"])
	for n in [a_idle, a_walk, a_run, a_aim]:
		_set_loop(anim_player, n)
	weapon_anims = _retarget(anim_player, char_skeleton, "player")
	var g := _wa(0, "idle")
	if g != "":
		a_idle = g
	g = _wa(0, "walk")
	if g != "":
		a_walk = g
	g = _wa(0, "run")
	if g != "":
		a_run = g
	g = _wa(0, "jump")
	if g != "":
		a_jump = g
	g = _wa(0, "aim")
	if g != "":
		a_aim = g
	if a_run == "":
		a_run = a_walk


func _attach_holdables() -> void:
	var parent: Node3D = model
	var pos := Vector3(0.25, 1.2, -0.3)
	var rot := Vector3.ZERO
	if char_skeleton != null:
		var hb := _find_hand_bone(char_skeleton)
		if hb != "":
			var att := BoneAttachment3D.new()
			char_skeleton.add_child(att)
			att.bone_name = hb
			parent = att
			pos = GUN_HAND_POS
			rot = GUN_HAND_ROT
			hand_scaled = true
			hand_bone_name = hb
	elif arm_r != null:
		parent = arm_r
		pos = Vector3(0, -0.52, 0)
		rot = Vector3(-90, 0, 0)
	hold_parent = parent

	gun_node = Node3D.new()
	gun_node.position = pos
	gun_node.rotation_degrees = rot
	parent.add_child(gun_node)
	gun_mesh = MeshInstance3D.new()
	gun_mesh.mesh = _boxm(Vector3(0.09, 0.14, 0.4))
	gun_mesh.material_override = _mat(Color(0.12, 0.12, 0.14))
	gun_node.add_child(gun_mesh)
	gun_visuals.append(null)
	for i in range(1, WEAPONS.size()):
		var w: Dictionary = WEAPONS[i]
		var l := float(w["len"])
		var path := WEAPON_GLB_DIR + String(WEAPON_FILES[i]) + ".glb"
		var gv := _fit_glb(path, WEAPON_GLB_YAW, l, false, false)
		if gv != null:
			gv.position = Vector3(0, 0, -l * 0.3)
			gv.visible = false
			gun_node.add_child(gv)
		gun_visuals.append(gv)

	phone_node = Node3D.new()
	phone_node.position = PHONE_HAND_POS if hand_scaled else pos
	phone_node.rotation_degrees = PHONE_HAND_ROT if hand_scaled else rot
	phone_node.visible = false
	parent.add_child(phone_node)
	var pv := _fit_glb(PHONE_GLB_PATH, PHONE_GLB_YAW, 0.15, false, false)
	if pv != null:
		phone_node.add_child(pv)
	else:
		var pm := MeshInstance3D.new()
		pm.mesh = _boxm(Vector3(0.075, 0.15, 0.012))
		pm.material_override = _mat(Color(0.05, 0.05, 0.07))
		phone_node.add_child(pm)


func _fix_hold_scale() -> void:
	if not hand_scaled or hold_parent == null:
		return
	var ps := hold_parent.global_transform.basis.get_scale()
	if ps.x > 0.0001 and ps.y > 0.0001 and ps.z > 0.0001:
		var inv := Vector3(1.0 / ps.x, 1.0 / ps.y, 1.0 / ps.z)
		gun_node.scale = inv
		phone_node.scale = inv


func _update_player_ik(delta: float) -> void:
	if player_ik == null:
		return
	var armed := aim_t > 0.0 and cur_weapon > 0 and not in_car and not dead and not phone_open
	var phone_hold := phone_open and not in_car and not dead
	var yaw := model.rotation.y
	player_ik.fwd = Vector3(-sin(yaw), 0.0, -cos(yaw))
	player_ik.side = Vector3(cos(yaw), 0.0, -sin(yaw))
	var fl := _flags("player", a_cur)
	var arms_ok: bool = fl[0]
	var legs_ok: bool = fl[1]
	var moving := speed > 0.5 and not in_car and not dead
	player_ik.swing = clampf(speed / MAX_SPEED, 0.12, 1.0)
	if anim_player != null and a_cur != "" and legs_ok and anim_player.is_playing():
		var ln := anim_player.current_animation_length
		if ln > 0.05:
			ik_phase = anim_player.current_animation_position / ln * TAU
	else:
		ik_phase += delta * TAU * (0.8 + speed * 0.2)
	player_ik.phase = ik_phase

	var tr := 0.0
	var tl := 0.0
	if armed:
		var shoulder := player.position + Vector3(0, 1.4, 0)
		var d := _aim_point(60.0) - shoulder
		if d.length() > 1.0:
			player_ik.aim_dir = player_ik.aim_dir.slerp(d.normalized(), 1.0 - exp(-14.0 * delta))
		player_ik.rmode = 1
		player_ik.lmode = 1 if cur_weapon >= 2 else 2
		tr = 1.0
		tl = 1.0
	elif phone_hold:
		var raising := phone_raise_t > 0.0 and _wa(9, "raise") != ""
		var has_anim := _wa(9, "idle") != "" or _wa(9, "walk") != ""
		if not raising and not has_anim:
			player_ik.rmode = 3
			tr = 1.0
	elif not arms_ok and not in_car and not dead:
		if moving:
			player_ik.rmode = 4
			player_ik.lmode = 4
		else:
			player_ik.rmode = 2
			player_ik.lmode = 2
		tr = 1.0
		tl = 1.0
	player_ik.rw = move_toward(player_ik.rw, tr, delta * 6.0)
	player_ik.lw = move_toward(player_ik.lw, tl, delta * 6.0)
	var tgl := 1.0 if (moving and not legs_ok) else 0.0
	player_ik.leg_w = move_toward(player_ik.leg_w, tgl, delta * 6.0)


func _actors(delta: float) -> void:
	var all: Array = []
	all.append_array(officers)
	all.append_array(peds)
	var ppos := player.position
	for a in all:
		var p := a as Ped
		if p == null or not is_instance_valid(p) or p.ik == null:
			continue
		if p.position.distance_to(ppos) > 80.0:
			continue
		var ik := p.ik
		var off := p as Officer
		var aiming := off != null and off.aiming and not off.dead
		if p.prop != null and p.prop_par != null:
			var ps := p.prop_par.global_transform.basis.get_scale()
			if ps.x > 0.0001 and ps.y > 0.0001 and ps.z > 0.0001:
				p.prop.scale = Vector3(1.0 / ps.x, 1.0 / ps.y, 1.0 / ps.z)
			p.prop.visible = aiming
		if p.dead:
			ik.rw = move_toward(ik.rw, 0.0, delta * 6.0)
			ik.lw = ik.rw
			ik.leg_w = move_toward(ik.leg_w, 0.0, delta * 6.0)
			continue
		var yaw := p.rotation.y
		ik.fwd = Vector3(-sin(yaw), 0.0, -cos(yaw))
		ik.side = Vector3(cos(yaw), 0.0, -sin(yaw))
		var an := ""
		if p.anim != null:
			an = String(p.anim.current_animation)
		var fl := _flags(p.ckey, an)
		var arms_ok: bool = fl[0]
		var legs_ok: bool = fl[1]
		var spd_est := 0.0
		if off != null:
			spd_est = 6.5 if off.moving else 0.0
		else:
			spd_est = 5.8 if p.panic > 0.0 else 1.7
		p.walk_t += delta * TAU * (0.8 + spd_est * 0.2)
		ik.swing = clampf(spd_est / MAX_SPEED, 0.12, 1.0)
		ik.phase = p.walk_t
		var tr := 0.0
		if aiming:
			var tgt := car.position if in_car else player.position
			var chest := p.position + Vector3(0, 1.4, 0)
			ik.aim_dir = (tgt + Vector3(0, 1.1, 0) - chest).normalized()
			ik.rmode = 1
			ik.lmode = 1
			tr = 1.0
		elif not arms_ok:
			ik.rmode = 4 if spd_est > 0.5 else 2
			ik.lmode = ik.rmode
			tr = 1.0
		ik.rw = move_toward(ik.rw, tr, delta * 6.0)
		ik.lw = ik.rw
		var tgl := 1.0 if (spd_est > 0.5 and not legs_ok) else 0.0
		ik.leg_w = move_toward(ik.leg_w, tgl, delta * 6.0)


# ---------------------------------------------------------------- vehicles

func _build_car_procedural(vis: Node3D, paint_col: Color, police: bool, wheels_out: Array[Node3D]) -> Array:
	vis.scale = Vector3.ONE * CAR_SCALE
	var paint := _mat(paint_col)
	paint.metallic = 0.6
	paint.roughness = 0.35
	var glass := _mat(Color(0.08, 0.1, 0.14))
	glass.metallic = 0.8
	glass.roughness = 0.1
	var dark := _mat(Color(0.05, 0.05, 0.05))
	var hl := _mat(Color(1, 1, 0.85))
	hl.emission_enabled = true
	hl.emission = Color(1, 0.95, 0.7)
	hl.emission_energy_multiplier = 2.0
	var tl := _mat(Color(1, 0.1, 0.1))
	tl.emission_enabled = true
	tl.emission = Color(1, 0.05, 0.05)
	tl.emission_energy_multiplier = 1.5

	_part(vis, _boxm(Vector3(1.9, 0.55, 4.3)), Vector3(0, 0.62, 0), paint)
	_part(vis, _boxm(Vector3(1.65, 0.5, 2.1)), Vector3(0, 1.14, 0.35), glass)
	_part(vis, _boxm(Vector3(1.7, 0.06, 1.9)), Vector3(0, 1.42, 0.35), paint)
	_part(vis, _boxm(Vector3(1.95, 0.2, 0.2)), Vector3(0, 0.4, -2.15), dark)
	_part(vis, _boxm(Vector3(1.95, 0.2, 0.2)), Vector3(0, 0.4, 2.15), dark)
	for sx in [-0.65, 0.65]:
		_part(vis, _boxm(Vector3(0.4, 0.15, 0.08)), Vector3(sx, 0.72, -2.16), hl)
		_part(vis, _boxm(Vector3(0.4, 0.15, 0.08)), Vector3(sx, 0.72, 2.16), tl)

	var res: Array = []
	if police:
		_part(vis, _boxm(Vector3(1.92, 0.22, 2.4)), Vector3(0, 0.58, 0.2), dark)
		var ma := _mat(Color(1, 0.1, 0.1))
		ma.emission_enabled = true
		ma.emission = Color(1, 0.1, 0.1)
		ma.emission_energy_multiplier = 4.0
		var mb := _mat(Color(0.1, 0.2, 1))
		mb.emission_enabled = true
		mb.emission = Color(0.1, 0.25, 1)
		mb.emission_energy_multiplier = 0.2
		_part(vis, _boxm(Vector3(0.7, 0.14, 0.3)), Vector3(-0.38, 1.52, 0.35), ma)
		_part(vis, _boxm(Vector3(0.7, 0.14, 0.3)), Vector3(0.38, 1.52, 0.35), mb)
		res.append(ma)
		res.append(mb)

	var wpos := [
		Vector3(-1.0, 0.38, -1.35), Vector3(1.0, 0.38, -1.35),
		Vector3(-1.0, 0.38, 1.35), Vector3(1.0, 0.38, 1.35)
	]
	for wp in wpos:
		var pivot := Node3D.new()
		pivot.position = wp
		vis.add_child(pivot)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.38
		cyl.bottom_radius = 0.38
		cyl.height = 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = dark
		mi.rotation_degrees = Vector3(0, 0, 90)
		pivot.add_child(mi)
		wheels_out.append(pivot)
	return res


func _build_car() -> void:
	car = CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 1.6, CAR_LENGTH - 0.4)
	col.shape = bx
	col.position.y = 0.9
	car.add_child(col)
	car_visual = Node3D.new()
	car.add_child(car_visual)

	var holder := _fit_glb(CAR_GLB_PATH, CAR_GLB_YAW, CAR_LENGTH, false, true)
	if holder != null:
		car_visual.add_child(holder)
	else:
		_build_car_procedural(car_visual, Color(0.8, 0.08, 0.08), false, car_wheels)

	car.position = Vector3(5, 0.1, -9)
	add_child(car)


func _make_cop() -> Cop:
	var c := Cop.new()
	var col := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.3, 1.5, POLICE_LENGTH - 0.5)
	col.shape = bx
	col.position.y = 0.85
	c.add_child(col)
	var vis := Node3D.new()
	c.add_child(vis)
	var holder := _fit_glb(POLICE_GLB_PATH, POLICE_GLB_YAW, POLICE_LENGTH, false, true)
	if holder != null:
		vis.add_child(holder)
	else:
		var tmp: Array[Node3D] = []
		var lights := _build_car_procedural(vis, Color(0.92, 0.92, 0.95), true, tmp)
		if lights.size() >= 2:
			c.mat_a = lights[0]
			c.mat_b = lights[1]
	if sfx.has("siren"):
		c.siren = AudioStreamPlayer3D.new()
		c.siren.stream = sfx["siren"]
		c.siren.max_distance = 220.0
		c.siren.unit_size = 25.0
		c.siren.volume_db = -4.0
		c.add_child(c.siren)
	return c


# ---------------------------------------------------------------- peds

func _build_ped_visual(p: Ped, shirt: Material, skin: Material, pants: Material, gun: bool) -> void:
	_part(p, ped_torso_mesh, Vector3(0, 1.15, 0), shirt)
	_part(p, ped_head_mesh, Vector3(0, 1.62, 0), skin)
	p.leg_l = _pivot_mesh(p, Vector3(-0.1, 0.85, 0), ped_leg_mesh, 0.425, pants)
	p.leg_r = _pivot_mesh(p, Vector3(0.1, 0.85, 0), ped_leg_mesh, 0.425, pants)
	p.arm_l = _pivot_mesh(p, Vector3(-0.28, 1.4, 0), ped_arm_mesh, 0.275, shirt)
	p.arm_r = _pivot_mesh(p, Vector3(0.28, 1.4, 0), ped_arm_mesh, 0.275, shirt)
	if gun:
		_part(p.arm_r, _boxm(Vector3(0.06, 0.1, 0.28)), Vector3(0, -0.55, -0.12), _mat(Color(0.08, 0.08, 0.1)))


func _ped_capsule(p: Ped) -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	p.add_child(col)


func _make_ped() -> Ped:
	var p := Ped.new()
	p.collision_layer = 2
	p.collision_mask = 0
	_ped_capsule(p)
	if not ped_glbs.is_empty():
		var path: String = ped_glbs[randi() % ped_glbs.size()]
		var h := _fit_glb(path, PED_GLB_YAW, 1.8, true, true)
		if h != null:
			p.add_child(h)
			_setup_anim(p, h, "ped:" + path)
			return p
	var shirt: StandardMaterial3D = shirt_mats[randi() % shirt_mats.size()]
	var skin: StandardMaterial3D = skin_mats[randi() % skin_mats.size()]
	_build_ped_visual(p, shirt, skin, pant_mat, false)
	return p


func _spawn_ped() -> void:
	var p := _make_ped()
	var ix := randi_range(-3, 3)
	var iz := randi_range(-3, 3)
	var nbs := _neighbors(ix, iz)
	var pick: Vector2i = nbs[randi() % nbs.size()]
	p.a_ix = ix
	p.a_iz = iz
	p.b_ix = pick.x
	p.b_iz = pick.y
	p.t = randf()
	p.lane = 5.5 if randf() < 0.5 else -5.5
	add_child(p)
	peds.append(p)
	_place_ped(p)


func _place_ped(p: Ped) -> void:
	var a := Vector2(p.a_ix * BLOCK, p.a_iz * BLOCK)
	var b := Vector2(p.b_ix * BLOCK, p.b_iz * BLOCK)
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x) * p.lane
	var pos := a.lerp(b, p.t) + perp
	p.position = Vector3(pos.x, 0.1, pos.y)
	p.rotation.y = atan2(-dir.x, -dir.y)


func _update_peds(delta: float) -> void:
	for i in range(peds.size() - 1, -1, -1):
		var p := peds[i]
		if p.dead:
			p.dead_t += delta
			p.rotation.x = lerpf(p.rotation.x, -PI * 0.5, 1.0 - exp(-8.0 * delta))
			if p.dead_t > 8.0:
				p.queue_free()
				peds.remove_at(i)
			continue
		var spd := 5.8 if p.panic > 0.0 else 1.7
		p.panic = maxf(p.panic - delta, 0.0)
		p.t += spd * delta / BLOCK
		while p.t >= 1.0:
			p.t -= 1.0
			var nbs := _neighbors(p.b_ix, p.b_iz)
			var opts: Array[Vector2i] = []
			for n in nbs:
				if not (n.x == p.a_ix and n.y == p.a_iz):
					opts.append(n)
			if opts.is_empty():
				opts = nbs
			var pick: Vector2i = opts[randi() % opts.size()]
			p.a_ix = p.b_ix
			p.a_iz = p.b_iz
			p.b_ix = pick.x
			p.b_iz = pick.y
		_place_ped(p)
		if p.anim != null:
			_ped_play(p, p.a_run if p.panic > 0.0 else p.a_walk)
			p.anim.speed_scale = 1.0 if spd < 3.0 else 1.3
		elif p.leg_l != null:
			p.walk_t += delta * spd * 2.2
			var sw := sin(p.walk_t) * (0.5 if spd < 3.0 else 0.9)
			p.leg_l.rotation.x = sw
			p.leg_r.rotation.x = -sw
			p.arm_l.rotation.x = -sw * 0.8
			p.arm_r.rotation.x = sw * 0.8
	ped_spawn_t -= delta
	if ped_spawn_t <= 0.0 and peds.size() < PED_COUNT:
		ped_spawn_t = 1.5
		_spawn_ped()


func _alarm(pos: Vector3, radius: float) -> void:
	for p in peds:
		if not p.dead and p.position.distance_to(pos) < radius:
			if p.panic <= 0.0 and scream_cd <= 0.0:
				scream_cd = 0.6
				_sfx3d("scream", p.position + Vector3(0, 1.5, 0), -2.0, randf_range(0.8, 1.3), 90.0)
			p.panic = maxf(p.panic, 6.0)


func _damage_ped(p: Ped, dmg: float) -> void:
	if p.dead:
		return
	p.hp -= dmg
	p.panic = 8.0
	if p.hp <= 0.0:
		_kill_ped(p)


func _kill_ped(p: Ped) -> void:
	if p.dead:
		return
	p.dead = true
	p.dead_t = 0.0
	p.collision_layer = 0
	p.collision_mask = 0
	if p.anim != null:
		p.anim.stop()
	_alarm(p.position, 30.0)
	if p is Officer:
		_add_wanted(2)
	else:
		_add_wanted(1)
	if apps != null:
		apps.add_money(60 if p is Officer else 40)


# ---------------------------------------------------------------- officers

func _make_officer() -> Officer:
	var o := Officer.new()
	o.hp = 60.0
	o.collision_layer = 2
	o.collision_mask = 1
	_ped_capsule(o)
	var h := _fit_glb(OFFICER_GLB_PATH, PED_GLB_YAW, 1.8, true, true)
	if h != null:
		o.add_child(h)
		_setup_anim(o, h, "officer")
	else:
		_build_ped_visual(o, off_shirt, skin_mats[0], off_pants, true)
	return o


func _release_crew(c: Cop) -> void:
	var n := c.crew
	c.crew = 0
	var f := -c.global_transform.basis.z
	for i in n:
		var side := -1.0 if i == 0 else 1.0
		var o := _make_officer()
		o.home = c
		add_child(o)
		o.position = c.position + c.global_transform.basis.x * 2.9 * side + f * 0.6 * float(i) + Vector3(0, 0.2, 0)
		o.rotation.y = c.rotation.y
		officers.append(o)
		c.outs.append(o)
	_sfx3d("radio", c.position, -2.0, 1.0, 80.0)


func _officer_gone(o: Officer, enter: bool) -> void:
	if is_instance_valid(o.home):
		o.home.outs.erase(o)
		if enter:
			o.home.crew += 1


func _officer_shoot(o: Officer, tgt3: Vector3) -> void:
	var from := o.position + Vector3(0, 1.4, 0)
	var to := tgt3 + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to + (to - from).normalized() * 1.0, 1)
	q.exclude = [o.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col = hit["collider"]
	if col == player or col == car:
		o.fire_t = 0.3
		o.a_cur = ""
		var muzzle := from + (to - from).normalized() * 0.6
		_tracer(muzzle, hit["position"], 1, false)
		_muzzle_flash(muzzle, (to - from).normalized(), 0.7)
		_sfx3d("pistol", from, -3.0, randf_range(0.9, 1.1), 160.0)
		if randf() < 0.6:
			_hurt_player(randf_range(4.0, 7.0))


func _fleeing() -> bool:
	return in_car and absf(car_speed) > 5.0


func _stopped() -> bool:
	return (not in_car) or absf(car_speed) < 2.5


func _update_officers(delta: float) -> void:
	var tgt3 := car.position if in_car else player.position
	var tp := Vector2(tgt3.x, tgt3.z)
	var chasing := stars > 0 and not dead
	var go_home := (not chasing) or _fleeing()
	for i in range(officers.size() - 1, -1, -1):
		var o := officers[i]
		o.fire_t = maxf(o.fire_t - delta, 0.0)
		if o.dead:
			o.dead_t += delta
			o.rotation.x = lerpf(o.rotation.x, -PI * 0.5, 1.0 - exp(-8.0 * delta))
			if o.dead_t > 6.0:
				_officer_gone(o, false)
				o.queue_free()
				officers.remove_at(i)
			continue

		var op := Vector2(o.position.x, o.position.z)
		var d := op.distance_to(tp)
		var goal := Vector2.ZERO
		var has_goal := false
		var spd := 6.5
		o.aiming = false

		if go_home:
			if is_instance_valid(o.home) and not o.home.dead:
				var hp2 := Vector2(o.home.position.x, o.home.position.z)
				if op.distance_to(hp2) < 3.6:
					_officer_gone(o, true)
					o.queue_free()
					officers.remove_at(i)
					continue
				goal = hp2
				has_goal = true
				spd = 7.5
			elif not chasing:
				o.leave_t += delta
				if o.leave_t > 5.0:
					_officer_gone(o, false)
					o.queue_free()
					officers.remove_at(i)
					continue
			elif d > 11.0:
				goal = tp
				has_goal = true
		else:
			o.leave_t = 0.0
			if d > 11.0:
				goal = tp
				has_goal = true
			o.aiming = d < 36.0
			o.shoot_cd -= delta
			if o.aiming and o.shoot_cd <= 0.0:
				o.shoot_cd = randf_range(0.7, 1.2)
				_officer_shoot(o, tgt3)

		if d > 100.0:
			o.far_t += delta
			if o.far_t > 10.0:
				_officer_gone(o, false)
				o.queue_free()
				officers.remove_at(i)
				continue
		else:
			o.far_t = 0.0

		var vel := Vector3.ZERO
		if has_goal:
			var v2 := (goal - op).normalized()
			vel = Vector3(v2.x, 0, v2.y) * spd
		o.velocity.x = vel.x
		o.velocity.z = vel.z
		if o.is_on_floor():
			o.velocity.y = -1.0
		else:
			o.velocity.y -= GRAVITY * delta
		o.move_and_slide()
		o.moving = has_goal

		var face := vel
		if o.aiming:
			face = Vector3(tp.x - op.x, 0, tp.y - op.y)
		if face.length() > 0.1:
			o.rotation.y = lerp_angle(o.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * delta))
		_animate_officer(o, delta, spd)


func _animate_officer(o: Officer, delta: float, spd: float) -> void:
	if o.anim != null:
		var A := o.anims
		var want := ""
		if o.fire_t > 0.0 and A.has("1_fire"):
			want = String(A["1_fire"])
		elif o.aiming and o.moving:
			want = _first([A.get("1_run", ""), A.get("1_walk", ""), o.a_run, o.a_walk])
		elif o.aiming:
			want = _first([A.get("1_aim", ""), A.get("1_idle", ""), o.a_idle])
		elif o.moving:
			want = _first([o.a_run if spd > 6.0 else o.a_walk, o.a_walk, o.a_run])
		else:
			want = o.a_idle
		_ped_play(o, want)
		return
	if o.leg_l == null:
		return
	var k := 1.0 - exp(-14.0 * delta)
	var sw := 0.0
	if o.moving:
		o.walk_t += delta * spd * 2.0
		sw = sin(o.walk_t) * 0.9
	o.leg_l.rotation.x = lerpf(o.leg_l.rotation.x, sw, k)
	o.leg_r.rotation.x = lerpf(o.leg_r.rotation.x, -sw, k)
	var al := -sw * 0.8
	var ar := sw * 0.8
	if o.aiming:
		ar = 1.5
		al = 1.2
	o.arm_l.rotation.x = lerpf(o.arm_l.rotation.x, al, k)
	o.arm_r.rotation.x = lerpf(o.arm_r.rotation.x, ar, k)


# ---------------------------------------------------------------- wanted / police cars

func _add_wanted(n: int) -> void:
	evade_t = 0.0
	if stars == 0:
		stars = 1
		wanted_cool = 4.0
		spawn_t = 0.5
	elif wanted_cool <= 0.0:
		stars = mini(MAX_STARS, stars + n)
		wanted_cool = 4.0


func _active_cops() -> int:
	var n := 0
	for c in cops:
		if c.crew > 0 or not c.outs.is_empty():
			n += 1
	return n


func _spawn_cop() -> void:
	var p3 := car.position if in_car else player.position
	var pp := Vector2(p3.x, p3.z)
	var pos := Vector2.ZERO
	var found := false
	for tries in 14:
		var ix := randi_range(-3, 3)
		var iz := randi_range(-3, 3)
		pos = Vector2(ix * BLOCK, iz * BLOCK)
		if pos.distance_to(pp) > 95.0:
			found = true
			break
	if not found:
		return
	var c := _make_cop()
	c.position = Vector3(pos.x + 3.5, 0.1, pos.y)
	c.rotation.y = atan2(-(pp.x - pos.x), -(pp.y - pos.y))
	add_child(c)
	cops.append(c)
	_sfx3d("radio", player.position, -4.0, 1.0, 400.0)


func _damage_cop(c: Cop, dmg: float) -> void:
	if c.dead:
		return
	c.hp -= dmg
	if c.hp <= 0.0:
		c.dead = true
		_spark_burst(c.position + Vector3(0, 1.0, 0))
		_sfx3d("crash", c.position, 4.0, 0.7, 200.0)
		_add_wanted(2)
		c.queue_free()
		cops.erase(c)


func _spark_burst(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _spherem(1.0)
	mi.material_override = _additive(Color(1.0, 0.5, 0.1, 0.8))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	_fx_add(mi, 0.5, 7.0)
	_smoke(pos + Vector3(0, 1, 0), Vector3.UP, 0.8, 0.7)


func _update_cops(delta: float) -> void:
	for i in range(cops.size() - 1, -1, -1):
		var c := cops[i]
		_update_cop(c, delta)
		var remove := false
		if stars == 0 and c.leave_t > 6.0 and c.outs.is_empty():
			remove = true
		if c.crew == 0 and c.outs.is_empty():
			c.abandon_t += delta
			if c.abandon_t > 25.0:
				remove = true
		if remove:
			c.queue_free()
			cops.remove_at(i)


func _los(from: Vector3, to: Vector3, rid: RID) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [rid, car.get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _ray_dist(origin: Vector3, dir: Vector3, length: float, rid: RID) -> float:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * length, 1)
	q.exclude = [rid, car.get_rid(), player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return origin.distance_to(hit["position"])


func _update_cop(c: Cop, delta: float) -> void:
	var tgt3 := car.position if in_car else player.position
	var tp := Vector2(tgt3.x, tgt3.z)
	var cp := Vector2(c.position.x, c.position.z)
	var d := cp.distance_to(tp)
	var chasing := stars > 0 and not dead

	if c.mat_a != null and c.mat_b != null:
		var on := int(time * 6.0) % 2 == 0
		c.mat_a.emission_energy_multiplier = 4.0 if on else 0.2
		c.mat_b.emission_energy_multiplier = 0.2 if on else 4.0
	if c.siren != null and c.siren.stream != null:
		if chasing and not c.siren.playing:
			c.siren.play()
		elif not chasing and c.siren.playing:
			c.siren.stop()

	if chasing and c.crew > 0 and _stopped() and d < 30.0 and absf(c.speed) < 3.0:
		_release_crew(c)

	var drive := chasing and c.crew > 0 and not (_stopped() and d < 30.0)
	var target_speed := 0.0
	if not chasing:
		c.leave_t += delta
	if drive:
		var eye := c.position + Vector3(0, 1.0, 0)
		var aim := tp
		var direct := d < 70.0 and _los(eye, tgt3 + Vector3(0, 1.0, 0), c.get_rid())
		if not direct:
			c.repath -= delta
			if c.repath <= 0.0:
				c.repath = 1.0
				c.path = astar.get_point_path(_node_for(cp), _node_for(tp))
				c.path_i = 0
			while c.path_i < c.path.size() and cp.distance_to(c.path[c.path_i]) < 10.0:
				c.path_i += 1
			if c.path_i < c.path.size():
				aim = c.path[c.path_i]
		var vec := aim - cp
		var desired := atan2(-vec.x, -vec.y)
		var diff := wrapf(desired - c.rotation.y, -PI, PI)
		var fwd := -c.global_transform.basis.z
		var org := c.position + Vector3(0, 0.8, 0)
		var dc := _ray_dist(org, fwd, 14.0, c.get_rid())
		var dl := _ray_dist(org, fwd.rotated(Vector3.UP, 0.55), 10.0, c.get_rid())
		var dr := _ray_dist(org, fwd.rotated(Vector3.UP, -0.55), 10.0, c.get_rid())
		var w := clampf(1.0 - dc / 14.0, 0.0, 1.0)
		var avoid := clampf((dl - dr) / 10.0, -1.0, 1.0)
		if c.reverse_t > 0.0:
			c.reverse_t -= delta
			target_speed = -9.0
			c.rotation.y -= clampf(diff, -1.0, 1.0) * 1.5 * delta
		else:
			var turn := clampf(diff, -2.6 * delta, 2.6 * delta) * (1.0 - w) + avoid * 2.4 * delta * w
			c.rotation.y += turn
			target_speed = COP_MAX * clampf(dc / 14.0, 0.25, 1.0)
			if absf(diff) > 0.8:
				target_speed = minf(target_speed, 12.0)
			if d < 8.0:
				target_speed = 4.0

	c.speed = move_toward(c.speed, target_speed, 16.0 * delta)
	var f := -c.global_transform.basis.z
	c.velocity.x = f.x * c.speed
	c.velocity.z = f.z * c.speed
	if c.is_on_floor():
		c.velocity.y = -1.0
	else:
		c.velocity.y -= GRAVITY * delta
	c.move_and_slide()
	var actual := c.velocity.dot(f)

	if drive and c.reverse_t <= 0.0 and target_speed > 8.0 and absf(actual) < 2.5:
		c.stuck_t += delta
		if c.stuck_t > 1.2:
			c.reverse_t = 1.0
			c.stuck_t = 0.0
	else:
		c.stuck_t = 0.0
	c.speed = actual

	if drive and d < 3.4 and absf(c.speed) > 5.0:
		_hurt_player(30.0 * delta)


func _update_wanted(delta: float) -> void:
	wanted_cool = maxf(wanted_cool - delta, 0.0)
	if stars <= 0:
		evade_t = 0.0
		return
	spawn_t -= delta
	if _active_cops() < stars and spawn_t <= 0.0:
		_spawn_cop()
		spawn_t = 2.5
	var p3 := car.position if in_car else player.position
	var pp := Vector2(p3.x, p3.z)
	var near := false
	for c in cops:
		if Vector2(c.position.x, c.position.z).distance_to(pp) < 60.0:
			near = true
	for o in officers:
		if not o.dead and Vector2(o.position.x, o.position.z).distance_to(pp) < 60.0:
			near = true
	if near:
		evade_t = 0.0
	else:
		evade_t += delta
		if evade_t > 18.0:
			stars = maxi(stars - 1, 0)
			evade_t = 0.0
			for c in cops:
				c.leave_t = 0.0


# ---------------------------------------------------------------- health

func _hurt_player(amount: float) -> void:
	if dead:
		return
	hp -= amount
	hurt_flash = 0.3
	if hp <= 0.0:
		hp = 0.0
		dead = true
		wasted_t = 3.0
		_clear_touch_ids()
		_set_phone(false)


func _respawn() -> void:
	if apps != null:
		apps.add_money(-500)
	dead = false
	hp = 100.0
	stars = 0
	evade_t = 0.0
	for c in cops:
		c.queue_free()
	cops.clear()
	for o in officers:
		o.queue_free()
	officers.clear()
	if in_car:
		in_car = false
		player.visible = true
		player_col.set_deferred("disabled", false)
	player.position = Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	cam_pitch = 0.18
	for i in ammo_res.size():
		ammo_res[i] = maxi(ammo_res[i], DEFAULT_RES[i])
	_set_weapon(cur_weapon, false)


# ---------------------------------------------------------------- weapons

func _set_weapon(i: int, show: bool = true) -> void:
	if show and phone_open:
		_set_phone(false)
	cur_weapon = i
	reloading = false
	reload_t = 0.0
	fire_cd = 0.2
	gun_mesh.visible = false
	for v in gun_visuals:
		if v != null:
			v.visible = false
	if i > 0:
		var w: Dictionary = WEAPONS[i]
		var l := float(w["len"])
		if gun_visuals[i] != null:
			gun_visuals[i].visible = true
		else:
			(gun_mesh.mesh as BoxMesh).size = Vector3(0.09, 0.14, l)
			gun_mesh.position = Vector3(0, 0, -l * 0.3)
			gun_mesh.visible = true
		if show:
			aim_t = 3.0
			prev_armed = false


func _aim_point(rng: float) -> Vector3:
	var c := _vp() * 0.5
	var ro := cam.project_ray_origin(c)
	var rd := cam.project_ray_normal(c)
	var far := ro + rd * (rng + 12.0)
	var q := PhysicsRayQueryParameters3D.create(ro, far, 3)
	q.exclude = [player.get_rid(), car.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return far
	return hit["position"]


func _assist_target(origin: Vector3, dir: Vector3, maxd: float, cone: float) -> Node3D:
	var best: Node3D = null
	var best_a := cone
	var all: Array = []
	all.append_array(peds)
	all.append_array(officers)
	all.append_array(cops)
	for n in all:
		if "dead" in n and bool(n.dead):
			continue
		var v: Vector3 = (n as Node3D).position + Vector3(0, 1.1, 0) - origin
		var dd := v.length()
		if dd > maxd or dd < 0.5:
			continue
		var ang := dir.angle_to(v / dd)
		if ang < best_a:
			best_a = ang
			best = n
	return best


func _try_fire(delta: float) -> void:
	fire_cd -= delta
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			var need := int(MAG_SIZE[cur_weapon]) - ammo_mag[cur_weapon]
			var n := mini(need, ammo_res[cur_weapon])
			ammo_mag[cur_weapon] += n
			ammo_res[cur_weapon] -= n
	if in_car or dead or map_open or wheel_open:
		fire_queued = false
		return

	var w: Dictionary = WEAPONS[cur_weapon]
	var go := false
	if fire_cd <= 0.0 and not reloading:
		if bool(w["auto"]) and fire_id != -1:
			go = true
		elif fire_queued:
			go = true
	fire_queued = false
	if not go:
		return

	if cur_weapon > 0 and ammo_mag[cur_weapon] <= 0:
		if ammo_res[cur_weapon] > 0:
			reloading = true
			reload_t = 1.3
			_sfx3d("reload", player.position, -4.0)
		fire_cd = 0.3
		return

	fire_cd = float(w["rate"])
	var origin := player.position + Vector3(0, 1.35, 0)
	var rng := float(w["range"])
	var dir := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	if cur_weapon > 0:
		var to_aim := _aim_point(rng) - origin
		if to_aim.length() > 2.0:
			dir = to_aim.normalized()
		var assist := _assist_target(origin, dir, rng, 0.1)
		if assist != null:
			dir = (assist.position + Vector3(0, 1.15, 0) - origin).normalized()
	model.rotation.y = atan2(-dir.x, -dir.z)
	aim_t = 3.0

	if cur_weapon == 0:
		punch_t = 0.2
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		for p in peds:
			if p.dead:
				continue
			var to := p.position - player.position
			to.y = 0.0
			if to.length() < rng and flat.angle_to(to.normalized()) < 1.0:
				_damage_ped(p, float(w["dmg"]))
		for o in officers:
			if o.dead:
				continue
			var to2 := o.position - player.position
			to2.y = 0.0
			if to2.length() < rng and flat.angle_to(to2.normalized()) < 1.0:
				_damage_ped(o, float(w["dmg"]))
		return

	fire_anim_t = 0.3
	if _wx(cur_weapon, "fire") != "":
		a_cur = ""
	ammo_mag[cur_weapon] -= 1
	shot_count += 1
	recoil += float(RECOIL[cur_weapon])
	_alarm(player.position, 30.0)

	var muzzle := gun_node.global_transform * Vector3(0, 0, -float(w["len"]) * 0.7)
	_muzzle_flash(muzzle, dir, float(FLASH_SIZE[cur_weapon]))
	_sfx3d(String(WEAPON_FILES[cur_weapon]), muzzle, 0.0, randf_range(0.95, 1.05), 200.0)
	if cur_weapon != 2 or shot_count % 2 == 0:
		_eject_casing(muzzle)
	if cur_weapon != 2 or shot_count % 3 == 0:
		_smoke(muzzle, dir, 0.05, 0.35)

	for i in int(w["pellets"]):
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1) * 0.5, randf_range(-1, 1)) * float(w["spread"])
		_bullet(origin + dir * 0.6, (dir + jitter).normalized(), rng, float(w["dmg"]), muzzle)
	if ammo_mag[cur_weapon] <= 0 and ammo_res[cur_weapon] > 0:
		reloading = true
		reload_t = 1.3
		_sfx3d("reload", player.position, -4.0)


func _bullet(from: Vector3, dir: Vector3, rng: float, dmg: float, vis_from: Vector3) -> void:
	var to := from + dir * rng
	var q := PhysicsRayQueryParameters3D.create(from, to, 3)
	q.exclude = [player.get_rid(), car.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit["position"]
		var normal: Vector3 = hit["normal"]
		var col = hit["collider"]
		if col is Ped:
			_damage_ped(col as Ped, dmg)
			_impact(end, normal, true)
		elif col is Cop:
			_damage_cop(col as Cop, dmg)
			_impact(end, normal, false)
		else:
			_impact(end, normal, false)
	_tracer(vis_from, end, cur_weapon, true)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)

	mini_panel = Panel.new()
	mini_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbm := StyleBoxFlat.new()
	sbm.bg_color = Color(0.07, 0.08, 0.1)
	sbm.set_corner_radius_all(int(MINI_SIZE * 0.5))
	mini_panel.add_theme_stylebox_override("panel", sbm)
	mini_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	layer.add_child(mini_panel)
	mini = Control.new()
	mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.draw.connect(_draw_mini)
	mini_panel.add_child(mini)

	pc = Control.new()
	pc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.draw.connect(_draw_phone)
	pc.visible = false
	layer.add_child(pc)

	big = Control.new()
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.draw.connect(_draw_big)
	big.visible = false
	layer.add_child(big)

	wheel = Control.new()
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.draw.connect(_draw_wheel)
	wheel.visible = false
	layer.add_child(wheel)

	add_child(layer)


func _process(delta: float) -> void:
	var r := _mini_rect()
	mini_panel.position = r.position
	mini_panel.size = r.size
	mini.queue_redraw()
	ui.queue_redraw()
	if map_open:
		big.queue_redraw()
	if wheel_open:
		wheel.queue_redraw()
	phone_t = move_toward(phone_t, 1.0 if phone_open else 0.0, delta * 3.6)
	pc.visible = phone_t > 0.001
	if pc.visible:
		pc.queue_redraw()
	if arrived_t > 0.0:
		arrived_t -= delta
	if toast_t > 0.0:
		toast_t -= delta
	_update_fx(delta)


func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	return pts


func _icon(c: Control, kind: String, p: Vector2, u: float) -> void:
	var w := Color(1, 1, 1, 0.95)
	if kind == "fire":
		c.draw_arc(p, u * 0.85, 0.0, TAU, 32, w, 3.0, true)
		c.draw_line(p + Vector2(-u * 1.2, 0), p + Vector2(-u * 0.55, 0), w, 3.0)
		c.draw_line(p + Vector2(u * 1.2, 0), p + Vector2(u * 0.55, 0), w, 3.0)
		c.draw_line(p + Vector2(0, -u * 1.2), p + Vector2(0, -u * 0.55), w, 3.0)
		c.draw_line(p + Vector2(0, u * 1.2), p + Vector2(0, u * 0.55), w, 3.0)
		c.draw_circle(p, u * 0.14, w)
	elif kind == "punch":
		c.draw_rect(Rect2(p + Vector2(-0.7, -0.35) * u, Vector2(1.4, 0.95) * u), w)
		for i in 4:
			c.draw_circle(p + Vector2(-0.52 + 0.35 * float(i), -0.45) * u, u * 0.2, w)
		c.draw_rect(Rect2(p + Vector2(-0.95, 0.0) * u, Vector2(0.3, 0.5) * u), w)
	elif kind == "jump":
		c.draw_polyline(PackedVector2Array([p + Vector2(-0.8, 0.05) * u, p + Vector2(0, -0.6) * u, p + Vector2(0.8, 0.05) * u]), w, 5.0, true)
		c.draw_polyline(PackedVector2Array([p + Vector2(-0.8, 0.65) * u, p + Vector2(0, 0.0) * u, p + Vector2(0.8, 0.65) * u]), w, 5.0, true)
	elif kind == "brake":
		c.draw_arc(p, u * 0.8, 0.0, TAU, 32, w, 3.0, true)
		_txt(c, "P", p, int(u * 1.2), w)
	elif kind == "guns":
		var q := p + Vector2(0, -u * 0.3)
		c.draw_rect(Rect2(q + Vector2(-1.0, -0.4) * u, Vector2(2.0, 0.55) * u), w)
		c.draw_colored_polygon(PackedVector2Array([q + Vector2(-0.45, 0.15) * u, q + Vector2(0.15, 0.15) * u, q + Vector2(-0.05, 1.05) * u, q + Vector2(-0.6, 1.05) * u]), w)
	elif kind == "car":
		c.draw_rect(Rect2(p + Vector2(-1.1, -0.05) * u, Vector2(2.2, 0.6) * u), w)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.65, -0.05) * u, p + Vector2(-0.35, -0.55) * u, p + Vector2(0.4, -0.55) * u, p + Vector2(0.75, -0.05) * u]), w)
		for sx in [-0.65, 0.65]:
			c.draw_circle(p + Vector2(sx, 0.58) * u, u * 0.26, w)
			c.draw_circle(p + Vector2(sx, 0.58) * u, u * 0.12, Color(0.1, 0.1, 0.12))
	elif kind == "phone":
		c.draw_rect(Rect2(p + Vector2(-0.45, -0.8) * u, Vector2(0.9, 1.6) * u), w, false, 3.0)
		c.draw_line(p + Vector2(-0.15, -0.6) * u, p + Vector2(0.15, -0.6) * u, w, 3.0)
		c.draw_circle(p + Vector2(0, 0.6) * u, u * 0.1, w)


func _btn(c: Control, center: Vector2, r: float, pressed: bool, kind: String, caption: String) -> void:
	c.draw_circle(center, r, Color(1, 1, 1, 0.32 if pressed else 0.12))
	c.draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0, true)
	var shift := -r * 0.12 if caption != "" else 0.0
	_icon(c, kind, center + Vector2(0, shift), r * 0.42)
	if caption != "":
		_txt(c, caption, center + Vector2(0, r * 0.62), 17, Color(1, 1, 1, 0.9))


func _mini_rot() -> float:
	var yaw := car.rotation.y if in_car else model.rotation.y
	var hd := Vector2(-sin(yaw), -cos(yaw))
	return -PI * 0.5 - hd.angle()


func _draw_ui() -> void:
	var s := _vp()
	if hurt_flash > 0.0:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0, 0, hurt_flash * 0.45))

	if stick_id != -1 and not map_open:
		ui.draw_circle(stick_origin, RADIUS, Color(1, 1, 1, 0.06))
		ui.draw_arc(stick_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.5, true)
		var kp := stick_origin + stick_vec * RADIUS
		ui.draw_circle(kp, 46.0, Color(1, 1, 1, 0.4))
		ui.draw_arc(kp, 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0, true)

	_btn(ui, _jump_center(), 70.0, jump_id != -1, "brake" if in_car else "jump", "BRAKE" if in_car else "JUMP")
	if in_car or near_car:
		_btn(ui, _act_center(), 70.0, false, "car", "EXIT" if in_car else "ENTER")
	if not in_car:
		_btn(ui, _fire_center(), 90.0, fire_id != -1, "punch" if cur_weapon == 0 else "fire", "")
		_btn(ui, _wpn_center(), 62.0, false, "guns", "")
	_btn(ui, _phone_btn_center(), 52.0, phone_open, "phone", "")

	if in_car:
		_draw_gauge()

	var mr := _mini_rect()
	var mc := mr.position + mr.size * 0.5
	var mrad := mr.size.x * 0.5
	ui.draw_arc(mc, mrad, 0.0, TAU, 80, Color(1, 1, 1, 0.92), 5.0, true)
	var rot := _mini_rot()
	var np := mc + Vector2(0, -1).rotated(rot) * (mrad - 22.0)
	ui.draw_circle(np, 16.0, Color(0.05, 0.06, 0.08, 0.9))
	_txt(ui, "N", np, 20)
	var ec := mc + Vector2(0.7071, 0.7071) * mrad
	ui.draw_circle(ec, 24.0, Color(0.05, 0.06, 0.08, 0.95))
	ui.draw_arc(ec, 24.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.5, true)
	ui.draw_line(ec + Vector2(-9, 0), ec + Vector2(9, 0), Color.WHITE, 3.0)
	ui.draw_line(ec + Vector2(0, -9), ec + Vector2(0, 9), Color.WHITE, 3.0)

	var hb := Rect2(mr.position.x, mr.end.y + 18.0, mr.size.x, 22.0)
	ui.draw_rect(hb, Color(0.03, 0.03, 0.05, 0.75))
	var hf := clampf(hp / 100.0, 0.0, 1.0)
	var hcol := Color(0.9, 0.12, 0.18).lerp(Color(1.0, 0.3, 0.3), hf)
	ui.draw_rect(Rect2(hb.position + Vector2(3, 3), Vector2((hb.size.x - 6.0) * hf, hb.size.y - 6.0)), hcol)
	ui.draw_rect(hb, Color(1, 1, 1, 0.9), false, 2.0)
	_txt(ui, "%d" % int(hp), hb.position + hb.size * 0.5, 16)

	var w: Dictionary = WEAPONS[cur_weapon]
	var pill := Rect2(mr.position.x, mr.end.y + 52.0, mr.size.x, 46.0)
	ui.draw_style_box(sb_pill, pill)
	ui.draw_string(ThemeDB.fallback_font, pill.position + Vector2(18, 32), String(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	if cur_weapon > 0:
		var am := "%d | %d" % [ammo_mag[cur_weapon], ammo_res[cur_weapon]]
		if reloading:
			am = "RELOAD"
		ui.draw_string(ThemeDB.fallback_font, pill.position + Vector2(pill.size.x - 150.0, 32), am, HORIZONTAL_ALIGNMENT_RIGHT, 132, 26, Color(1, 1, 1, 0.95))

	var blink := evade_t > 0.0 and (int(time * 4.0) % 2 == 0)
	for i in MAX_STARS:
		var cpos := Vector2(s.x * 0.5 + (float(i) - 2.0) * 72.0, 60.0)
		var pts := _star_pts(cpos, 30.0)
		if i < stars and not blink:
			ui.draw_colored_polygon(pts, Color(1, 0.95, 0.75))
		else:
			var cl := PackedVector2Array(pts)
			cl.append(pts[0])
			ui.draw_polyline(cl, Color(1, 1, 1, 0.4), 3.0, true)

	if cur_weapon > 0 and not in_car and not dead and aim_blend > 0.2:
		var cc := s * 0.5
		var ca := Color(1, 1, 1, 0.9 * aim_blend)
		ui.draw_circle(cc, 3.0, ca)
		ui.draw_line(cc + Vector2(-24, 0), cc + Vector2(-9, 0), ca, 3.0)
		ui.draw_line(cc + Vector2(24, 0), cc + Vector2(9, 0), ca, 3.0)
		ui.draw_line(cc + Vector2(0, -24), cc + Vector2(0, -9), ca, 3.0)
		ui.draw_line(cc + Vector2(0, 24), cc + Vector2(0, 9), ca, 3.0)

	if dest_set:
		_txt(ui, "%d m" % int(_route_len()), Vector2(mr.position.x + mr.size.x * 0.5, mr.end.y + 128.0), 30, Color(0.85, 0.5, 1.0))
	if arrived_t > 0.0:
		_txt(ui, "ARRIVED", Vector2(s.x * 0.5, 150.0), 60, Color(1, 1, 1))
	if toast_t > 0.0:
		var lines := toast_msg.split("\n")
		for i in lines.size():
			ui.draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.5 - 600.0, 250.0 + float(i) * 40.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 1200, 30, Color(1, 1, 1, clampf(toast_t, 0.0, 1.0)))

	if apps != null:
		apps.draw_hud(ui)
	if dead:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.4, 0, 0, 0.5))
		_txt(ui, "WASTED", s * 0.5, 130, Color(0.9, 0.1, 0.1))


func _glyph(i: int, c: Vector2) -> void:
	var w := Color(1, 1, 1, 0.95)
	if i == 0:
		pc.draw_circle(c + Vector2(0, -8), 18.0, w)
		pc.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 2), c + Vector2(13, 2), c + Vector2(0, 28)]), w)
		pc.draw_circle(c + Vector2(0, -8), 7.0, Color(0.2, 0.75, 0.45))
	elif i == 1 or i == 3:
		_icon(pc, "car", c, 22.0)
	elif i == 2:
		_icon(pc, "guns", c, 22.0)
	elif i == 4:
		pc.draw_rect(Rect2(c + Vector2(-26, -16), Vector2(52, 36)), w, false, 4.0)
		pc.draw_arc(c + Vector2(0, 2), 11.0, 0.0, TAU, 24, w, 4.0, true)
	elif i == 5:
		pc.draw_rect(Rect2(c + Vector2(-26, -22), Vector2(52, 44)), w, false, 4.0)
		pc.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 18), c + Vector2(-6, -2), c + Vector2(6, 10), c + Vector2(14, 2), c + Vector2(22, 18)]), w)
	elif i == 6:
		pc.draw_arc(c, 26.0, 0.0, TAU, 32, w, 4.0, true)
		pc.draw_line(c, c + Vector2(0, -16), w, 4.0)
		pc.draw_line(c, c + Vector2(12, 6), w, 4.0)
	elif i == 7:
		pc.draw_rect(Rect2(c + Vector2(-22, -8), Vector2(44, 32)), w, false, 4.0)
		pc.draw_arc(c + Vector2(0, -8), 12.0, PI, TAU, 16, w, 4.0, true)
	else:
		pc.draw_arc(c, 17.0, 0.0, TAU, 24, w, 4.0, true)
		for k in 8:
			var a := float(k) * TAU / 8.0
			pc.draw_line(c + Vector2(cos(a), sin(a)) * 19.0, c + Vector2(cos(a), sin(a)) * 27.0, w, 5.0)


func _draw_phone() -> void:
	var r := _prect()
	var vs := _vp()
	if r.position.y > vs.y:
		return
	pc.draw_set_transform(r.position, 0.0, Vector2(phone_scale, phone_scale))
	pc.draw_style_box(sb_body, Rect2(0, 0, 440, 900))
	pc.draw_style_box(sb_screen, Rect2(20, 20, 400, 860))
	if apps != null:
		apps.draw_bg(pc)
	pc.draw_style_box(sb_notch, Rect2(165, 30, 110, 26))
	var t := Time.get_time_dict_from_system()
	pc.draw_string(ThemeDB.fallback_font, Vector2(52, 90), "%02d:%02d" % [t["hour"], t["minute"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	pc.draw_string(ThemeDB.fallback_font, Vector2(290, 90), "5G", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.8))
	pc.draw_rect(Rect2(342, 70, 40, 20), Color(1, 1, 1, 0.9), false, 2.0)
	pc.draw_rect(Rect2(345, 73, 28, 14), Color(0.4, 0.9, 0.5))
	if apps != null:
		if apps.app_open():
			apps.draw(pc)
		else:
			apps.draw_home(pc)
	var hc := Vector2(220, 845)
	pc.draw_circle(hc, 30.0, Color(1, 1, 1, 0.2))
	pc.draw_arc(hc, 30.0, 0.0, TAU, 28, Color(1, 1, 1, 0.85), 3.0, true)
	pc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	pc.draw_set_transform(r.position, 0.0, Vector2(phone_scale, phone_scale))
	pc.draw_style_box(sb_body, Rect2(0, 0, 440, 900))
	pc.draw_style_box(sb_screen, Rect2(20, 20, 400, 860))
	if apps != null:
		apps.draw_bg(pc)
	else:
		pc.draw_circle(Vector2(320, 270), 120.0, Color(0.35, 0.25, 0.8, 0.16))
		pc.draw_circle(Vector2(130, 650), 140.0, Color(0.1, 0.55, 0.9, 0.12))
	pc.draw_style_box(sb_notch, Rect2(165, 30, 110, 26))
	var t := Time.get_time_dict_from_system()
	pc.draw_string(ThemeDB.fallback_font, Vector2(52, 90), "%02d:%02d" % [t["hour"], t["minute"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	pc.draw_string(ThemeDB.fallback_font, Vector2(290, 90), "5G", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.8))
	pc.draw_rect(Rect2(342, 70, 40, 20), Color(1, 1, 1, 0.9), false, 2.0)
	pc.draw_rect(Rect2(345, 73, 28, 14), Color(0.4, 0.9, 0.5))
	if apps != null and apps.app_open():
		apps.draw(pc)
	else:
		_txt(pc, "LOS CITY", Vector2(140, 135), 34, Color(1, 1, 1, 0.9))
		for sgn in [0, 1]:
			var cc := Vector2(330 + sgn * 50, 130)
			pc.draw_circle(cc, 22.0, Color(1, 1, 1, 0.14))
			pc.draw_arc(cc, 22.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0, true)
			_txt(pc, "+" if sgn == 1 else "-", cc, 30)
		for i in 9:
			var ir := _icon_rect(i)
			pc.draw_style_box(sb_apps[i], ir)
			_glyph(i, ir.position + ir.size * 0.5 + Vector2(0, -2))
			_txt(pc, String(APP_NAMES[i]), ir.position + Vector2(52, 124), 19, Color(1, 1, 1, 0.95))
	var hc := Vector2(220, 845)
	pc.draw_circle(hc, 30.0, Color(1, 1, 1, 0.2))
	pc.draw_arc(hc, 30.0, 0.0, TAU, 28, Color(1, 1, 1, 0.85), 3.0, true)
	pc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wheel() -> void:
	var s := _vp()
	wheel.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.65))
	for i in WEAPONS.size():
		var pos := _wheel_pos(i)
		var sel := i == cur_weapon
		wheel.draw_circle(pos, 92.0, Color(1, 1, 1, 0.3) if sel else Color(0.14, 0.16, 0.2, 0.9))
		wheel.draw_arc(pos, 92.0, 0.0, TAU, 40, Color(1, 1, 1, 0.9 if sel else 0.35), 4.0, true)
		var w: Dictionary = WEAPONS[i]
		_txt(wheel, String(w["name"]), pos + Vector2(0, -12), 26)
		if i > 0:
			_txt(wheel, "%d / %d" % [ammo_mag[i], ammo_res[i]], pos + Vector2(0, 26), 22, Color(1, 1, 1, 0.75))
	_txt(wheel, "WEAPONS", s * 0.5, 40)


func _draw_gauge() -> void:
	var s := _vp()
	var c := Vector2(s.x * 0.5, s.y - 160.0)
	var r := 130.0
	var kmh := absf(car_speed) * 3.6
	var ratio := clampf(kmh / GAUGE_MAX, 0.0, 1.0)
	var a0 := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)

	ui.draw_circle(c, r + 16.0, Color(0.03, 0.04, 0.06, 0.75))
	ui.draw_arc(c, r, a0, a0 + sweep, 64, Color(1, 1, 1, 0.18), 10.0, true)
	ui.draw_arc(c, r, a0 + sweep * 0.82, a0 + sweep, 24, Color(0.9, 0.15, 0.15, 0.55), 10.0, true)
	var col := Color(0.2, 0.85, 1.0).lerp(Color(1.0, 0.25, 0.2), clampf((ratio - 0.55) / 0.45, 0.0, 1.0))
	if ratio > 0.005:
		ui.draw_arc(c, r, a0, a0 + sweep * ratio, 64, col, 10.0, true)

	for i in range(0, 12):
		var f := float(i) / 11.0
		var ang := a0 + sweep * f
		var dir := Vector2(cos(ang), sin(ang))
		ui.draw_line(c + dir * (r - 28.0), c + dir * (r - 8.0), Color(1, 1, 1, 0.9), 3.0, true)
		if i % 2 == 0:
			_txt(ui, str(i * 20), c + dir * (r - 50.0), 20, Color(1, 1, 1, 0.85))
		if i < 11:
			var ang2 := a0 + sweep * ((float(i) + 0.5) / 11.0)
			var d2 := Vector2(cos(ang2), sin(ang2))
			ui.draw_line(c + d2 * (r - 18.0), c + d2 * (r - 8.0), Color(1, 1, 1, 0.5), 2.0, true)

	var na := a0 + sweep * ratio
	var nd := Vector2(cos(na), sin(na))
	ui.draw_line(c - nd * 14.0, c + nd * (r - 20.0), Color(1, 0.3, 0.2), 5.0, true)
	ui.draw_circle(c, 14.0, Color(0.15, 0.15, 0.18))
	ui.draw_circle(c, 7.0, Color(1, 0.3, 0.2))

	var g := "N"
	var gc := Color(1, 1, 1, 0.6)
	if car_speed > 0.8:
		g = "D"
		gc = Color(0.3, 1, 0.5)
	elif car_speed < -0.8:
		g = "R"
		gc = Color(1, 0.6, 0.2)
	_txt(ui, g, c + Vector2(0, -48), 36, gc)
	_txt(ui, str(int(kmh)), c + Vector2(0, 56), 58)
	_txt(ui, "KM/H", c + Vector2(0, 96), 20, Color(1, 1, 1, 0.6))


func _mp(w: Vector2, origin: Vector2, w_off: Vector2, sc: float, rot: float) -> Vector2:
	return origin + ((w + w_off) * sc).rotated(rot)


func _wrect(c: Control, r: Rect2, o: Vector2, wo: Vector2, sc: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array([
		_mp(r.position, o, wo, sc, rot),
		_mp(r.position + Vector2(r.size.x, 0), o, wo, sc, rot),
		_mp(r.end, o, wo, sc, rot),
		_mp(r.position + Vector2(0, r.size.y), o, wo, sc, rot)
	])
	c.draw_colored_polygon(pts, col)


func _clamp_blip(p: Vector2, origin: Vector2, circle_r: float, bounds: Rect2) -> Vector2:
	if circle_r > 0.0:
		return origin + (p - origin).limit_length(circle_r)
	return Vector2(clampf(p.x, bounds.position.x + 12.0, bounds.end.x - 12.0), clampf(p.y, bounds.position.y + 12.0, bounds.end.y - 12.0))


func _draw_map_content(c: Control, o: Vector2, wo: Vector2, sc: float, k: float, rot: float, circle_r: float, bounds: Rect2, cull: float) -> void:
	var pc2 := -wo
	for r in block_rects:
		if cull > 0.0 and (r.get_center() - pc2).length() > cull:
			continue
		_wrect(c, r, o, wo, sc, rot, Color(0.17, 0.19, 0.23))
	for r in bld_rects:
		if cull > 0.0 and (r.get_center() - pc2).length() > cull:
			continue
		_wrect(c, r, o, wo, sc, rot, Color(0.31, 0.34, 0.41))
	var lc := Color(0.6, 0.55, 0.2, 0.45)
	for i in range(-3, 4):
		var a := float(i) * BLOCK
		c.draw_line(_mp(Vector2(a, -ROAD_MAX), o, wo, sc, rot), _mp(Vector2(a, ROAD_MAX), o, wo, sc, rot), lc, 1.5 * k)
		c.draw_line(_mp(Vector2(-ROAD_MAX, a), o, wo, sc, rot), _mp(Vector2(ROAD_MAX, a), o, wo, sc, rot), lc, 1.5 * k)

	if route.size() >= 2:
		var pts := PackedVector2Array()
		for v in route:
			pts.append(_mp(v, o, wo, sc, rot))
		c.draw_polyline(pts, Color(0.78, 0.35, 1.0), 5.0 * k, true)

	if dest_set:
		var dp := _clamp_blip(_mp(dest, o, wo, sc, rot), o, circle_r, bounds)
		c.draw_circle(dp, 11.0 * k, Color(0.78, 0.35, 1.0))
		c.draw_circle(dp, 4.5 * k, Color.WHITE)

	var flash := int(time * 4.0) % 2 == 0
	var pol := Color(0.2, 0.45, 1.0) if flash else Color(1.0, 0.18, 0.18)
	for cop in cops:
		var cpp := _clamp_blip(_mp(Vector2(cop.position.x, cop.position.z), o, wo, sc, rot), o, circle_r, bounds)
		c.draw_circle(cpp, 9.0 * k, Color.WHITE)
		c.draw_circle(cpp, 6.5 * k, pol)
	for off in officers:
		if not off.dead:
			var opp := _clamp_blip(_mp(Vector2(off.position.x, off.position.z), o, wo, sc, rot), o, circle_r, bounds)
			c.draw_circle(opp, 5.5 * k, pol)

	if not in_car:
		var cp := _clamp_blip(_mp(Vector2(car.position.x, car.position.z), o, wo, sc, rot), o, circle_r, bounds)
		c.draw_rect(Rect2(cp - Vector2(6, 6) * k, Vector2(12, 12) * k), Color.WHITE)
		c.draw_rect(Rect2(cp - Vector2(4, 4) * k, Vector2(8, 8) * k), Color(0.3, 0.7, 1.0))

	var p3 := car.position if in_car else player.position
	var pp := _mp(Vector2(p3.x, p3.z), o, wo, sc, rot)
	var yaw := car.rotation.y if in_car else model.rotation.y
	var d := Vector2(-sin(yaw), -cos(yaw)).rotated(rot)
	var perp := Vector2(-d.y, d.x)
	var tri_o := PackedVector2Array([
		pp + d * 20.0 * k,
		pp - d * 12.0 * k + perp * 13.0 * k,
		pp - d * 12.0 * k - perp * 13.0 * k
	])
	c.draw_colored_polygon(tri_o, Color(0.02, 0.02, 0.03))
	var tri := PackedVector2Array([
		pp + d * 16.0 * k,
		pp - d * 9.0 * k + perp * 9.5 * k,
		pp - d * 9.0 * k - perp * 9.5 * k
	])
	c.draw_colored_polygon(tri, Color.WHITE)


func _draw_mini() -> void:
	var sz := mini.size
	var ctr := sz * 0.5
	var p3 := car.position if in_car else player.position
	var ppos := Vector2(p3.x, p3.z)
	var sc := sz.x / MINI_VIEW
	mini.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.07, 0.08, 0.1))
	_draw_map_content(mini, ctr, -ppos, sc, 1.0, _mini_rot(), sz.x * 0.5 - 16.0, Rect2(Vector2.ZERO, sz), MINI_VIEW * 0.5 + 40.0)


func _draw_big() -> void:
	var s := _vp()
	var br := _big_rect()
	var sc := br.size.x / (MAP_HALF * 2.0)
	big.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.82))
	big.draw_style_box(sb_map, br.grow(10.0))
	big.draw_rect(br, Color(0.07, 0.08, 0.1))
	_draw_map_content(big, br.position, Vector2(MAP_HALF, MAP_HALF), sc, 1.7, 0.0, -1.0, br, -1.0)

	var cr := _close_rect()
	big.draw_style_box(sb_btn, cr)
	_txt(big, "CLOSE", cr.position + cr.size * 0.5, 36)
	var kr := _clear_rect()
	big.draw_style_box(sb_btn, kr)
	_txt(big, "CLEAR", kr.position + kr.size * 0.5, 36)

	var lx := br.position.x * 0.5
	_txt(big, "TAP THE MAP", Vector2(lx, 200.0), 40)
	_txt(big, "TO SET A WAYPOINT", Vector2(lx, 250.0), 28, Color(1, 1, 1, 0.7))
	if dest_set:
		_txt(big, "%d m" % int(_route_len()), Vector2(lx, 340.0), 64, Color(0.85, 0.5, 1.0))


# ---------------------------------------------------------------- map / phone logic

func _clear_touch_ids() -> void:
	stick_id = -1
	stick_vec = Vector2.ZERO
	look_id = -1
	jump_id = -1
	fire_id = -1


func _set_map(open: bool) -> void:
	map_open = open
	big.visible = open
	if open:
		_clear_touch_ids()


func _set_wheel(open: bool) -> void:
	wheel_open = open
	wheel.visible = open
	if open:
		_clear_touch_ids()


func _set_phone(open: bool) -> void:
	if open == phone_open:
		return
	phone_open = open
	a_cur = ""
	if open:
		aim_t = 0.0
		phone_raise_t = 0.0
		var rn := _wa(9, "raise")
		if rn != "" and anim_player != null and not in_car:
			phone_raise_t = clampf(anim_player.get_animation(rn).length, 0.3, 2.5)


func _phone_touch(p: Vector2) -> void:
	var r := _prect()
	var lp := (p - r.position) / phone_scale
	if apps != null and apps.app_open():
		apps.touch(lp)
		return
	if lp.distance_to(Vector2(330, 130)) < 30.0:
		phone_scale = maxf(0.4, phone_scale - 0.08)
		return
	if lp.distance_to(Vector2(380, 130)) < 30.0:
		phone_scale = minf(1.1, phone_scale + 0.08)
		return
	if lp.distance_to(Vector2(220, 845)) < 40.0:
		_set_phone(false)
		return
	for i in 9:
		if _icon_rect(i).has_point(lp):
			_phone_app(i)
			return


func _phone_app(i: int) -> void:
	if i == 0:
		_set_phone(false)
		_set_map(true)
	elif i == 1:
		if in_car:
			_toast("YOU ARE IN THE CAR")
			return
		var f := Vector2(-sin(cam_yaw), -cos(cam_yaw))
		var tgt := _snap_to_road(Vector2(player.position.x, player.position.z) + f * 10.0)
		car.position = Vector3(tgt.x, 0.3, tgt.y)
		car.velocity = Vector3.ZERO
		car_speed = 0.0
		car.rotation.y = snappedf(cam_yaw, PI * 0.5)
		_toast("YOUR CAR IS HERE")
		_set_phone(false)
	elif i == 2:
		_set_phone(false)
		_set_wheel(true)
	elif i == 3:
		if not dest_set:
			_toast("SET A WAYPOINT ON THE MAP")
			return
		var tgt2 := _snap_to_road(dest)
		var np := Vector3(tgt2.x, 0.3, tgt2.y)
		if in_car:
			car.position = np
			car.velocity = Vector3.ZERO
			car_speed = 0.0
			player.position = np
		else:
			player.position = np
			player.velocity = Vector3.ZERO
		cam.position = np + Vector3(0, 3, 6)
		_clear_route()
		arrived_t = 3.0
		_set_phone(false)
	elif apps != null:
		apps.open_app(i)
	else:
		_toast("COMING SOON")


func _set_dest(w: Vector2) -> void:
	dest = Vector2(clampf(w.x, -MAP_HALF, MAP_HALF), clampf(w.y, -MAP_HALF, MAP_HALF))
	dest_set = true
	dest_marker.position = Vector3(dest.x, 60.0, dest.y)
	dest_marker.visible = true
	_update_route()


func _clear_route() -> void:
	dest_set = false
	route.clear()
	dest_marker.visible = false


func _update_route() -> void:
	if not dest_set:
		return
	var p3 := car.position if in_car else player.position
	var p := Vector2(p3.x, p3.z)
	var path := astar.get_point_path(_node_for(p), _node_for(dest))
	route.clear()
	route.append(p)
	var start_i := 0
	if path.size() >= 2:
		var seg := path[1] - path[0]
		var t := (p - path[0]).dot(seg) / seg.length_squared()
		if t > 0.0 and t < 1.0 and (path[0] + seg * t).distance_to(p) < 9.0:
			start_i = 1
	for i in range(start_i, path.size()):
		route.append(path[i])
	route.append(dest)


func _route_len() -> float:
	var total := 0.0
	for i in range(route.size() - 1):
		total += route[i].distance_to(route[i + 1])
	return total


# ---------------------------------------------------------------- input

func _toggle_car() -> void:
	fire_id = -1
	if in_car:
		in_car = false
		player.position = car.position + car.global_transform.basis.x * 3.2 + Vector3(0, 0.3, 0)
		player.velocity = Vector3.ZERO
		player.visible = true
		player_col.set_deferred("disabled", false)
		model.rotation.y = car.rotation.y
	else:
		in_car = true
		player.visible = false
		player_col.set_deferred("disabled", true)
		cam_yaw = car.rotation.y
	cam_pitch = 0.2
	_set_weapon(cur_weapon, false)


func _input(event: InputEvent) -> void:
	var half := _vp().x * 0.5
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if map_open:
				if _close_rect().has_point(p):
					_set_map(false)
				elif _clear_rect().has_point(p):
					_clear_route()
				elif _big_rect().has_point(p):
					var sc := _big_rect().size.x / (MAP_HALF * 2.0)
					_set_dest((p - _big_rect().position) / sc - Vector2(MAP_HALF, MAP_HALF))
				return
			if wheel_open:
				for i in WEAPONS.size():
					if p.distance_to(_wheel_pos(i)) < 92.0:
						_set_weapon(i)
						break
				_set_wheel(false)
				return
			if phone_t > 0.35 and _prect().has_point(p):
				func _phone_touch(p: Vector2) -> void:
	var r := _prect()
	var lp := (p - r.position) / phone_scale
	if apps != null:
		apps.touch(lp)
		return
	if lp.distance_to(Vector2(220, 845)) < 40.0:
		_set_phone(false)
			if p.distance_to(_phone_btn_center()) < 70.0:
				_set_phone(not phone_open)
				return
			if (in_car or near_car) and p.distance_to(_act_center()) < 95.0:
				_toggle_car()
				return
			if not in_car:
				if p.distance_to(_fire_center()) < 115.0:
					if phone_open:
						_set_phone(false)
					fire_id = event.index
					fire_queued = true
					return
				if p.distance_to(_wpn_center()) < 85.0:
					_set_wheel(true)
					return
			if p.distance_to(_jump_center()) < 100.0:
				jump_id = event.index
				if not in_car:
					want_jump = true
				return
			if p.x < half and stick_id == -1:
				stick_id = event.index
				stick_origin = p
				stick_vec = Vector2.ZERO
			elif p.x >= half and look_id == -1:
				look_id = event.index
		else:
			if event.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
			elif event.index == look_id:
				look_id = -1
			elif event.index == jump_id:
				jump_id = -1
			elif event.index == fire_id:
				fire_id = -1
	elif event is InputEventScreenDrag:
		if map_open or wheel_open:
			return
		if event.index == stick_id:
			stick_vec = (event.position - stick_origin).limit_length(RADIUS) / RADIUS
		elif event.index == look_id:
			cam_yaw -= event.relative.x * 0.005
			if aim_t > 0.0 and cur_weapon > 0 and not in_car:
				aim_pitch = clampf(aim_pitch + event.relative.y * 0.004, -0.2, 0.7)
			else:
				cam_pitch = clampf(cam_pitch + event.relative.y * 0.004, -0.1, 0.8)


# ---------------------------------------------------------------- physics

func _physics_process(delta: float) -> void:
	time += delta
	aim_t = maxf(aim_t - delta, 0.0)
	punch_t = maxf(punch_t - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	fire_anim_t = maxf(fire_anim_t - delta, 0.0)
	raise_t = maxf(raise_t - delta, 0.0)
	phone_raise_t = maxf(phone_raise_t - delta, 0.0)
	recoil = move_toward(recoil, 0.0, 0.6 * delta)
	police_called = maxf(police_called - delta, 0.0)

	var armed_now := aim_t > 0.0 and cur_weapon > 0 and not in_car and not phone_open
	if armed_now and not prev_armed:
		raise_t = 0.5
		a_cur = ""
	prev_armed = armed_now

	var input := stick_vec
	if input == Vector2.ZERO:
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dead:
		input = Vector2.ZERO

	near_car = (not in_car) and (not dead) and player.position.distance_to(car.position) < 6.0

	if not in_car and look_id == -1 and not armed_now and not dead:
		cam_yaw -= input.x * 1.3 * clampf(-input.y, 0.0, 1.0) * delta

	if in_car:
		_drive(delta, input, not dead, jump_id != -1)
		player.position = car.position
	else:
		_drive(delta, Vector2.ZERO, false, true)
		_walk(delta, input)

	_update_player_ik(delta)
	_actors(delta)
	_fix_hold_scale()
	gun_node.visible = cur_weapon > 0 and not in_car and aim_t > 0.0 and not phone_open
	phone_node.visible = phone_open and not in_car and phone_t > 0.3

	_try_fire(delta)
	_update_peds(delta)
	var hostile := stars > 0 and not dead
	var chasing := (stars > 0 or police_called > 0.0) and not dead
	_update_officers(delta)
	_update_wanted(delta)
	_update_camera(delta)

	if in_car and absf(car_speed) > 7.0 and not dead:
		for p in peds:
			if not p.dead and p.position.distance_to(car.position) < 2.8:
				_kill_ped(p)

	if dead:
		wasted_t -= delta
		if wasted_t <= 0.0:
			_respawn()
	elif stars == 0 and hp < 100.0:
		hp = minf(hp + 2.0 * delta, 100.0)

	route_timer += delta
	if dest_set and route_timer > 0.4:
		route_timer = 0.0
		_update_route()
		var p3 := car.position if in_car else player.position
		if Vector2(p3.x, p3.z).distance_to(dest) < 10.0:
			_clear_route()
			arrived_t = 3.0


func _walk(delta: float, input: Vector2) -> void:
	var mag := minf(input.length(), 1.0)
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)

	var target := Vector3.ZERO
	if mag > 0.05:
		target = dir.normalized() * (MAX_SPEED * mag * mag)

	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	hv = hv.move_toward(target, 45.0 * delta)
	player.velocity.x = hv.x
	player.velocity.z = hv.z

	if player.is_on_floor():
		player.velocity.y = -1.0
		if want_jump or Input.is_action_just_pressed("ui_accept"):
			player.velocity.y = JUMP_V
	else:
		player.velocity.y -= GRAVITY * delta
	want_jump = false
	player.move_and_slide()

	speed = hv.length()
	if speed > 0.8 and player.is_on_floor():
		step_t -= delta * clampf(speed, 0.0, 8.0) / 1.8
		if step_t <= 0.0:
			step_t = 1.0
			_sfx3d("step", player.position, -9.0 + clampf(speed, 0.0, 8.0) * 0.5, randf_range(0.85, 1.15), 40.0)
	if aim_t > 0.0 and cur_weapon > 0:
		model.rotation.y = lerp_angle(model.rotation.y, cam_yaw, 1.0 - exp(-12.0 * delta))
	elif target.length() > 0.1:
		var want_yaw := atan2(-target.x, -target.z)
		model.rotation.y = lerp_angle(model.rotation.y, want_yaw, 1.0 - exp(-14.0 * delta))

	_animate(delta, player.is_on_floor())


func _drive(delta: float, input: Vector2, driven: bool, handbrake: bool) -> void:
	var prev_speed := car_speed
	var ratio := clampf(absf(car_speed) / CAR_MAX, 0.0, 1.0)
	var throttle := -input.y if driven else 0.0
	var steer_in := input.x if driven else 0.0
	steer_in = steer_in * 0.6 + steer_in * absf(steer_in) * 0.4

	if throttle > 0.05:
		if car_speed < -0.5:
			car_speed = move_toward(car_speed, 0.0, CAR_BRAKE * delta)
		else:
			car_speed += CAR_ACCEL * throttle * (1.0 - ratio * ratio) * delta
	elif throttle < -0.05:
		if car_speed > 0.5:
			car_speed = move_toward(car_speed, 0.0, CAR_BRAKE * (-throttle) * delta)
		else:
			car_speed = move_toward(car_speed, -12.0 * (-throttle), 8.0 * delta)
	else:
		car_speed = move_toward(car_speed, 0.0, 5.0 * delta)

	if handbrake:
		car_speed = move_toward(car_speed, 0.0, (28.0 if driven else 14.0) * delta)
	car_speed = clampf(car_speed, -14.0, CAR_MAX)

	var max_steer := lerpf(0.55, 0.09, pow(ratio, 0.6))
	car_steer = lerpf(car_steer, steer_in * max_steer, 1.0 - exp(-10.0 * delta))
	var rot_rate := car_speed / WHEELBASE * tan(car_steer)
	if handbrake and driven and absf(car_speed) > 8.0:
		rot_rate *= 1.6
	car.rotation.y -= rot_rate * delta

	var f := -car.global_transform.basis.z
	car.velocity.x = f.x * car_speed
	car.velocity.z = f.z * car_speed
	if car.is_on_floor():
		car.velocity.y = -1.0
	else:
		car.velocity.y -= GRAVITY * delta
	car.move_and_slide()
	car_speed = car.velocity.dot(f)

	var accel := (car_speed - prev_speed) / maxf(delta, 0.0001)
	car_accel_s = lerpf(car_accel_s, clampf(accel, -30.0, 30.0), 1.0 - exp(-6.0 * delta))
	car_visual.rotation.x = car_accel_s * 0.0035
	car_visual.rotation.z = lerpf(car_visual.rotation.z, car_steer * ratio * 0.25, 1.0 - exp(-8.0 * delta))

	for i in car_wheels.size():
		var w := car_wheels[i]
		w.rotation.x = fmod(w.rotation.x - car_speed * delta / WHEEL_R, TAU)
		if i < 2:
			w.rotation.y = -car_steer

	_update_car_audio(delta, throttle, handbrake and driven, prev_speed)


func _update_camera(delta: float) -> void:
	var cratio := clampf(absf(car_speed) / CAR_MAX, 0.0, 1.0)
	var run_f := clampf(speed / MAX_SPEED, 0.0, 1.0)
	var base := car.position if in_car else player.position
	var aiming := aim_t > 0.0 and cur_weapon > 0 and not in_car and not dead and not phone_open
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, 4.0 * delta)

	var dist := 3.6
	var h := 1.55
	var shoulder := 0.55
	var follow := 14.0
	var pitch := cam_pitch
	if in_car:
		dist = 7.5 + cratio * 2.5
		h = 1.9
		shoulder = 0.0
		follow = 16.0
		if look_id == -1:
			cam_yaw = lerp_angle(cam_yaw, car.rotation.y, 1.0 - exp(-2.5 * delta))
	else:
		dist = lerpf(3.6 + run_f * 0.9, 2.3, aim_blend)
		h = lerpf(1.55, 1.6, aim_blend)
		shoulder = lerpf(0.55, 0.85, aim_blend)
		pitch = lerpf(cam_pitch, aim_pitch, aim_blend)
	pitch += recoil

	var tgt := base + Vector3(0, h, 0)
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	tgt += right * shoulder
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, cam_yaw)
	var desired := tgt + off

	var q := PhysicsRayQueryParameters3D.create(tgt, desired, 1)
	q.exclude = [player.get_rid(), car.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var kf := follow
	if not hit.is_empty():
		desired = hit["position"] + (tgt - desired).normalized() * 0.35
		kf = 30.0
	cam.position = cam.position.lerp(desired, 1.0 - exp(-kf * delta))
	cam.look_at(tgt)

	var fov_t := 68.0 + run_f * 10.0 - 14.0 * aim_blend
	if in_car:
		fov_t = 66.0 + cratio * 26.0
	cam.fov = lerpf(cam.fov, fov_t, 1.0 - exp(-4.0 * delta))


# ---------------------------------------------------------------- animation

func _animate(delta: float, on_floor: bool) -> void:
	if anim_player != null:
		_animate_glb(on_floor)
		return
	if hips == null:
		return

	var k := 1.0 - exp(-18.0 * delta)
	var ka := 1.0 - exp(-9.0 * delta)

	if not on_floor:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.9, k)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.4, k)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 2.3, k)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 2.3, k)
		torso.rotation.x = lerpf(torso.rotation.x, -0.1, k)
		hips.position.y = lerpf(hips.position.y, 0.95, k)
		return

	var ratio := clampf(speed / MAX_SPEED, 0.0, 1.0)
	var swing := 0.0
	var lean := 0.0
	var twist := 0.0
	var sway := sin(time * 1.8) * 0.04
	if speed > 0.4:
		anim_t += delta * (5.0 + speed * 1.3)
		var amp := 0.35 + ratio * 0.7
		swing = sin(anim_t) * amp
		lean = ratio * 0.3
		twist = sin(anim_t) * 0.12 * ratio
		sway = 0.0

	var arm_l_t := -swing * 1.1 + sway
	var arm_r_t := swing * 1.1 - sway
	if aim_t > 0.0 and cur_weapon > 0:
		var pose: Array = ARM_POSE[cur_weapon]
		arm_r_t = float(pose[0]) + fire_anim_t * 0.5
		arm_l_t = float(pose[1]) + fire_anim_t * 0.3
		lean = maxf(lean, float(pose[2]))
	if phone_open:
		arm_r_t = 1.2
	if punch_t > 0.0:
		arm_r_t = 1.6

	leg_l.rotation.x = lerpf(leg_l.rotation.x, swing, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -swing, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, arm_l_t, ka)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_r_t, ka)
	torso.rotation.x = lerpf(torso.rotation.x, -lean, k)
	torso.rotation.y = lerpf(torso.rotation.y, twist, k)
	hips.position.y = 0.95 * cos(leg_l.rotation.x)


func _animate_glb(on_floor: bool) -> void:
	var w := cur_weapon
	var holding_phone := phone_open and not in_car
	var armed := aim_t > 0.0 and w > 0 and not phone_open
	var run := speed > RUN_SPEED
	var walk := speed > 0.5
	var want := ""

	if holding_phone:
		if phone_raise_t > 0.0:
			want = _wa(9, "raise")
		if want == "":
			if run:
				want = _first([_wa(9, "run"), _wa(9, "walk"), a_run, a_walk])
			elif walk:
				want = _first([_wa(9, "walk"), _wa(9, "run"), a_walk, a_run])
			else:
				want = _first([_wa(9, "idle"), a_idle])
	elif armed:
		if raise_t > 0.0:
			want = _wx(w, "raise")
		if want == "" and fire_anim_t > 0.0:
			want = _wx(w, "fire")
		if want == "":
			if run:
				want = _first([_wx(w, "run"), _wx(w, "walk"), a_run, a_walk])
			elif walk:
				want = _first([_wx(w, "walk"), _wx(w, "run"), a_walk, a_run])
			else:
				want = _first([_wx(w, "aim"), _wx(w, "idle"), a_aim, a_idle])

	if want == "":
		if not on_floor and a_jump != "":
			want = a_jump
		elif run:
			want = _first([a_run, a_walk, _any("run"), _any("walk")])
		elif walk:
			want = _first([a_walk, a_run, _any("walk"), _any("run")])
		else:
			want = _first([a_idle, _any("idle"), _any("aim")])

	var frozen := false
	if want == "":
		want = _first([a_walk, a_run, _any("walk"), _any("run")])
		frozen = want != "" and not walk

	if want != "" and want != a_cur:
		a_cur = want
		anim_player.play(want, 0.15)
		if frozen:
			anim_player.seek(0.0, true)

	if frozen:
		anim_player.speed_scale = 0.0
	elif a_cur != "" and (a_cur == a_walk or a_cur == _wx(w, "walk") or a_cur == _wa(9, "walk")):
		anim_player.speed_scale = clampf(speed / 2.2, 0.6, 1.8)
	elif a_cur != "" and (a_cur == a_run or a_cur == _wx(w, "run") or a_cur == _wa(9, "run")):
		anim_player.speed_scale = clampf(speed / 6.5, 0.8, 1.5)
	else:
		anim_player.speed_scale = 1.0
