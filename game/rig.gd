extends RefCounted
# Articulated blocky soldier: hips, torso, neck+head, shoulders+elbows, hips+knees+feet.
# Everything is posed by code (no model files): walk/run/idle, several attack styles, shield raise,
# hit reactions, three death falls, victory pose, and a heavier royal gait for kings.

const KL := preload("res://game/kinglook.gd")
const ProfL := preload("res://game/profile.gd")

# attack key-frames: [time, shoulder x, shoulder y, elbow, torso yaw, torso pitch, step, shield x, shield elbow]
const ATK := [
	# 0 overhead chop
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.32, -2.7, 0.15, -0.5, 0.15, -0.2, -0.05, -0.9, -1.5], [0.5, -0.5, 0.0, -0.15, -0.15, 0.4, 0.34, -1.1, -1.4], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 1 horizontal slash
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.3, -1.5, 1.25, -0.5, 0.65, 0.0, -0.05, -1.2, -1.5], [0.52, -1.5, -1.1, -0.2, -0.75, 0.1, 0.25, -1.2, -1.5], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 2 thrust
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.3, -0.6, 0.35, -1.9, 0.35, 0.0, -0.12, -1.3, -1.4], [0.5, -1.55, -0.1, -0.1, -0.25, 0.1, 0.5, -1.0, -1.6], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 3 diagonal slash
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.3, -2.3, 0.9, -0.6, 0.5, -0.1, -0.05, -0.8, -1.6], [0.52, -0.5, -0.7, -0.2, -0.55, 0.35, 0.3, -1.2, -1.3], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 4 heavy two-handed smash (power attack / king)
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.45, -3.0, 0.1, -0.4, 0.1, -0.4, -0.08, -2.3, -0.6], [0.62, -0.3, 0.0, -0.1, 0.0, 0.6, 0.5, -1.5, -0.9], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
]
# --- king-only fighting moves (index 5..10)
const HERO_SEQ := [4, 5, 6, 8, 7, 9, 10, 1, 3, 2]
const ATK_HERO := [
	# 5 gut thrust: coil, drive the blade in, hold, wrench it back out
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.22, -0.5, 0.45, -2.0, 0.55, -0.05, -0.12, -1.3, -1.4], [0.42, -1.5, -0.1, -0.1, -0.3, 0.32, 0.7, -1.0, -1.6], [0.62, -1.52, -0.1, -0.08, -0.3, 0.34, 0.74, -1.0, -1.6], [0.82, -0.95, 0.0, -1.3, 0.1, -0.18, 0.12, -1.1, -1.4], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 6 beheading cut: wide backswing, fast flat slash at neck height, flourish
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.3, -1.55, 1.7, -0.3, 1.0, 0.0, -0.1, -1.0, -1.5], [0.5, -1.55, -1.5, -0.1, -1.1, 0.05, 0.3, -1.2, -1.5], [0.7, -2.2, -1.7, -0.5, -1.0, -0.1, 0.2, -1.2, -1.4], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 7 whirlwind: the whole body spins (hip yaw handled in code)
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.2, -1.55, 0.6, -0.1, 0.4, 0.1, -0.05, -1.3, -1.0], [0.55, -1.55, 0.0, -0.05, 0.0, 0.15, 0.1, -1.3, -1.0], [0.8, -1.55, -0.4, -0.05, -0.2, 0.1, 0.0, -1.2, -1.2], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 8 rising cut: from low to high with a small hop
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.28, 0.5, 0.3, -0.35, 0.4, 0.4, 0.2, -0.6, -1.4], [0.52, -2.9, -0.2, -0.2, -0.3, -0.4, 0.45, -1.8, -0.8], [0.75, -2.4, -0.1, -0.5, -0.1, -0.2, 0.2, -1.4, -1.0], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 9 shield bash into a cleave
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.25, -2.0, 0.2, -0.5, -0.45, 0.0, -0.1, -0.5, -1.6], [0.42, -2.0, 0.2, -0.5, -0.5, 0.15, 0.5, -1.6, -0.3], [0.62, -2.9, 0.1, -0.4, 0.2, -0.3, 0.2, -1.2, -0.8], [0.82, -0.3, 0.0, -0.1, 0.0, 0.55, 0.5, -1.2, -1.0], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
	# 10 executioner: sword high, plunge straight down, lean on it, tear it free
	[[0.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0], [0.3, -2.9, 0.0, -0.2, 0.0, -0.3, -0.05, -2.2, -0.6], [0.5, -0.5, 0.0, -0.1, 0.0, 0.75, 0.45, -1.4, -0.9], [0.7, -0.5, 0.0, -0.1, 0.0, 0.8, 0.45, -1.4, -0.9], [0.88, -1.6, 0.0, -0.9, 0.2, -0.2, 0.1, -1.0, -1.2], [1.0, -0.25, 0.0, -0.8, 0.0, 0.0, 0.0, -0.1, -1.0]],
]
# bow shot: shoulder x is the DRAW arm; elbow draws back then releases
const BOW := [[0.0, -1.3, 0.0, -1.0, 0.0, 0.0, 0.0, -1.55, -0.1], [0.55, -1.45, 0.2, -2.1, -0.15, 0.0, -0.05, -1.55, -0.1], [0.62, -1.45, 0.2, -0.9, -0.05, 0.0, 0.0, -1.55, -0.1], [1.0, -0.4, 0.0, -0.9, 0.0, 0.0, 0.0, -0.2, -0.6]]


static func _part(u, parent: Node3D, sz: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, shadow := false) -> MeshInstance3D:
	return u._add(parent, u._box(sz), mat, pos, rot, shadow)


static func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func build(u, tc: Color, hero: bool) -> void:
	var kind: String = u.kind
	var steel = u._mat(Color(0.72, 0.74, 0.8), 0.9, 0.3)
	var steel_d = u._mat(Color(0.5, 0.52, 0.58), 0.8, 0.4)
	var gold = u._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var skin = u._mat(Color(0.86, 0.66, 0.52), 0.0, 0.9)
	var leather = u._mat(Color(0.33, 0.2, 0.1), 0.0, 0.9)
	var dark = u._mat(Color(0.18, 0.14, 0.12), 0.0, 0.9)
	var cloth = u._mat(tc, 0.0, 0.8)
	var cloth_d = u._mat(tc.darkened(0.42), 0.0, 0.8)
	var glow = u._mat(tc, 0.0, 0.6, 0.6)
	var white = u._mat(Color(0.95, 0.94, 0.9), 0.0, 0.95)
	var green = u._mat(Color(0.22, 0.4, 0.2), 0.0, 0.9)
	var green_d = u._mat(Color(0.14, 0.27, 0.13), 0.0, 0.9)
	var wood = u._mat(Color(0.45, 0.3, 0.15), 0.0, 0.9)
	var archer: bool = kind == "archer"
	var L: Dictionary = {}
	if hero:
		var src: Dictionary = KL.force
		if src.is_empty() and u.battle != null and "my_id" in u.battle and u.owner_id == u.battle.my_id:
			src = ProfL.look
		L = KL.merged(src)
		skin = u._mat(KL.SKIN[int(L.skin)], 0.0, 0.9)
		cloth_d = KL.cape_mat(u, L, tc, true)
	var body: Node3D = u.body
	# ---- hips and legs
	var hips := _pivot(body, Vector3(0, 0.92, 0))
	_part(u, hips, Vector3(0.46, 0.2, 0.27), leather, Vector3(0, 0.02, 0))
	u.rg = {"hips": hips}
	var thighs := []
	var shins := []
	for side in [-1, 1]:
		var th := _pivot(hips, Vector3(0.12 * side, -0.02, 0))
		_part(u, th, Vector3(0.18, 0.46, 0.2), green_d if archer else dark, Vector3(0, -0.23, 0), Vector3.ZERO, true)
		var kn := _pivot(th, Vector3(0, -0.46, 0))
		_part(u, kn, Vector3(0.17, 0.44, 0.19), green_d if archer else steel_d, Vector3(0, -0.22, 0))
		_part(u, kn, Vector3(0.19, 0.11, 0.31), dark, Vector3(0, -0.44, 0.06))
		thighs.append(th)
		shins.append(kn)
		u.legs.append(th)
	u.rg["thighs"] = thighs
	u.rg["shins"] = shins
	# ---- torso
	var torso := _pivot(hips, Vector3(0, 0.12, 0))
	u.rg["torso"] = torso
	var chest_mat = green if archer else steel
	var arm_m = KL.armor_mat(u, L) if hero else steel
	if hero:
		chest_mat = arm_m
	_part(u, torso, Vector3(0.5, 0.6, 0.28), chest_mat, Vector3(0, 0.33, 0), Vector3.ZERO, true)
	if not archer:
		_part(u, torso, Vector3(0.44, 0.62, 0.04), cloth, Vector3(0, 0.3, 0.16))                 # tabard
		_part(u, torso, Vector3(0.09, 0.62, 0.05), gold if hero else white, Vector3(0, 0.3, 0.17))
		if hero:
			KL.chest(u, torso, L)
	_part(u, torso, Vector3(0.52, 0.08, 0.3), leather, Vector3(0, 0.04, 0))                        # belt
	# cape on its own pivot so it can flutter
	var cape := _pivot(torso, Vector3(0, 0.6, -0.15))
	var cl: float = 1.2 if hero else (0.85 if not archer else 0.6)
	_part(u, cape, Vector3(0.5, cl, 0.04), cloth_d if not archer else green_d, Vector3(0, -cl * 0.5, -0.03))
	if hero:
		_part(u, cape, Vector3(0.52, 0.1, 0.05), gold, Vector3(0, -cl + 0.04, -0.03))
	u.cape = cape
	u.rg["cape"] = cape
	# ---- head
	var neck := _pivot(torso, Vector3(0, 0.66, 0))
	var head := _pivot(neck, Vector3(0, 0.04, 0))
	u.rg["head"] = head
	if not hero:
		_part(u, head, Vector3(0.3, 0.3, 0.3), skin, Vector3(0, 0.16, 0), Vector3.ZERO, true)
		_part(u, head, Vector3(0.05, 0.05, 0.03), dark, Vector3(-0.07, 0.18, 0.155))               # eyes
		_part(u, head, Vector3(0.05, 0.05, 0.03), dark, Vector3(0.07, 0.18, 0.155))
	if hero:
		KL.head(u, head, L, steel, steel_d, glow)
	elif archer:
		_part(u, head, Vector3(0.36, 0.2, 0.36), green, Vector3(0, 0.3, -0.02))                # hood
		_part(u, head, Vector3(0.36, 0.34, 0.1), green_d, Vector3(0, 0.15, -0.16))
		_part(u, head, Vector3(0.03, 0.03, 0.34), white, Vector3(0.12, 0.44, -0.05), Vector3(0.5, 0, 0.3))
	else:
		_part(u, head, Vector3(0.35, 0.22, 0.35), steel, Vector3(0, 0.28, -0.01), Vector3.ZERO, true)  # helmet
		_part(u, head, Vector3(0.35, 0.16, 0.1), steel, Vector3(0, 0.1, -0.15))
		_part(u, head, Vector3(0.04, 0.16, 0.04), steel_d, Vector3(0, 0.18, 0.18))             # nasal bar
		_part(u, head, Vector3(0.05, 0.12, 0.34), glow, Vector3(0, 0.44, -0.01))               # crest
	if hero:
		for i in 6:
			var b := float(i) / 6.0 * PI
			_part(u, torso, Vector3(0.14, 0.12, 0.14), white, Vector3(cos(b) * 0.36, 0.64, sin(b) * 0.06 - 0.02))
	# ---- arms: [0] = right (weapon), [1] = left (shield / bow)
	var sh_p := []
	var el_p := []
	for side in [1, -1]:
		var sh := _pivot(torso, Vector3(0.33 * side, 0.58, 0))
		_part(u, sh, Vector3(0.18, 0.18, 0.2), arm_m if hero else (steel if not archer else green), Vector3(0, 0.0, 0), Vector3.ZERO, true)  # pauldron
		if hero:
			KL.pauldron(u, sh, side, L, arm_m, gold)
		_part(u, sh, Vector3(0.14, 0.3, 0.14), steel_d if not archer else green_d, Vector3(0, -0.17, 0))
		var el := _pivot(sh, Vector3(0, -0.32, 0))
		_part(u, el, Vector3(0.12, 0.28, 0.12), leather if archer else steel_d, Vector3(0, -0.14, 0))
		_part(u, el, Vector3(0.13, 0.12, 0.13), skin if archer else dark, Vector3(0, -0.3, 0))
		sh_p.append(sh)
		el_p.append(el)
	u.rg["sh"] = sh_p
	u.rg["el"] = el_p
	# ---- weapon in the right hand (extends along the forearm, tilted forward)
	var hand := _pivot(el_p[0], Vector3(0, -0.32, 0))
	hand.rotation.x = -0.35
	u.arm = hand
	if kind == "cav":
		_part(u, hand, Vector3(0.05, 2.7, 0.05), wood, Vector3(0, -1.0, 0))
		_part(u, hand, Vector3(0.09, 0.4, 0.09), steel, Vector3(0, -2.4, 0))
		_part(u, hand, Vector3(0.34, 0.3, 0.03), glow, Vector3(0, -1.7, 0.1))
	elif archer:
		# the right hand draws the string; the bow sits in the left hand
		_part(u, hand, Vector3(0.03, 0.03, 0.2), wood, Vector3(0, -0.05, 0.05))
		var bow := _pivot(el_p[1], Vector3(0, -0.32, 0))
		_part(u, bow, Vector3(0.05, 1.2, 0.05), wood, Vector3(0, 0, 0.05))
		_part(u, bow, Vector3(0.05, 0.3, 0.05), wood, Vector3(0, 0.55, 0.15), Vector3(0.6, 0, 0))
		_part(u, bow, Vector3(0.05, 0.3, 0.05), wood, Vector3(0, -0.55, 0.15), Vector3(-0.6, 0, 0))
		_part(u, bow, Vector3(0.012, 1.15, 0.012), u._mat(Color(0.9, 0.9, 0.8)), Vector3(0, 0, 0.25))
		_part(u, torso, Vector3(0.14, 0.55, 0.14), wood, Vector3(0.14, 0.4, -0.3), Vector3(0, 0, 0.2))   # quiver
	else:
		var bl: float = 1.25 if hero else 1.0
		_part(u, hand, Vector3(0.07, 0.95 * bl, 0.02), KL.blade_mat(u, L) if hero else steel, Vector3(0, -0.1 - 0.475 * bl, 0.0))        # blade
		_part(u, hand, Vector3(0.3, 0.05, 0.07), gold, Vector3(0, -0.08, 0.0))                           # guard
		_part(u, hand, Vector3(0.05, 0.16, 0.05), dark, Vector3(0, 0.06, 0.0))                           # grip
		if hero:
			_part(u, hand, Vector3(0.09, 0.09, 0.09), u._mat(KL.GEM[int(L.gem)], 0.2, 0.3, 0.9), Vector3(0, 0.16, 0))
	# ---- shield on the left forearm
	if not archer:
		var shd := _pivot(el_p[1], Vector3(0.02, -0.18, 0.12))
		_part(u, shd, Vector3(0.08, 0.62, 0.5), steel, Vector3.ZERO, Vector3.ZERO, true)
		_part(u, shd, Vector3(0.1, 0.5, 0.38), cloth, Vector3(-0.01, 0, 0))
		_part(u, shd, Vector3(0.12, 0.08, 0.4), gold, Vector3(-0.02, 0, 0))
		_part(u, shd, Vector3(0.12, 0.5, 0.08), gold, Vector3(-0.02, 0, 0))
		u.shield_n = shd
	if hero:
		_build_map(u, el_p[1])
	if not archer and kind != "villager":
		_make_trail(u, torso)
	# per-soldier variety so a whole army never moves in lock-step
	u.gait = 0.9 + randf() * 0.24
	u.gphase = randf() * TAU
	var h := 0.95 + randf() * 0.1
	if not hero:
		u.sc *= h
		u.body.scale = Vector3.ONE * u.sc
	u.rigged = true


# ------------------------------------------------------------------ poses
# four-fold parchment map the king carries in his pocket. A is the base leaf; B folds over A
# (hinge along the long edge), C and D fold over the top. mp scales up as it is unfolded.
static func _build_map(u, forearm: Node3D) -> void:
	var par = u._mat(Color(0.88, 0.78, 0.55), 0.0, 0.95)
	var par2 = u._mat(Color(0.8, 0.68, 0.44), 0.0, 0.95)
	var ink = u._mat(Color(0.25, 0.15, 0.08), 0.0, 0.9)
	var river = u._mat(Color(0.3, 0.5, 0.75), 0.0, 0.9)
	var red = u._mat(Color(0.8, 0.12, 0.1), 0.0, 0.9)
	var gold = u._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var mp := _pivot(forearm, Vector3(0, -0.36, 0.05))
	mp.visible = false
	var w := 0.4
	var l := 0.5
	# A
	var a := _pivot(mp, Vector3.ZERO)
	_part(u, a, Vector3(w, 0.012, l), par, Vector3.ZERO)
	_part(u, a, Vector3(w * 0.9, 0.004, 0.012), ink, Vector3(0, 0.008, 0.1), Vector3(0, 0.3, 0))
	_part(u, a, Vector3(0.05, 0.005, 0.05), red, Vector3(-0.08, 0.009, -0.1), Vector3(0, 0.78, 0))
	# B (right of A), hinge on A's right edge; leaf extends +x
	var b := _pivot(a, Vector3(w * 0.5, 0.0, 0))
	_part(u, b, Vector3(w, 0.012, l), par2, Vector3(w * 0.5, 0, 0))
	_part(u, b, Vector3(0.06, 0.005, l * 0.8), river, Vector3(0.12, 0.009, 0.0), Vector3(0, 0.25, 0))
	_part(u, b, Vector3(0.07, 0.03, 0.07), ink, Vector3(0.28, 0.02, 0.12))
	# C (above A) hinge on A's far edge; leaf extends -z
	var c := _pivot(a, Vector3(0, 0.0, -l * 0.5))
	_part(u, c, Vector3(w, 0.012, l), par2, Vector3(0, 0, -l * 0.5))
	_part(u, c, Vector3(w * 0.8, 0.005, 0.015), ink, Vector3(0, 0.009, -0.2), Vector3(0, -0.2, 0))
	_part(u, c, Vector3(0.06, 0.03, 0.06), ink, Vector3(-0.1, 0.02, -0.3))
	# D (above B) hinge on B's far edge
	var d := _pivot(b, Vector3(w * 0.5, 0.0, -l * 0.5))
	_part(u, d, Vector3(w, 0.012, l), par, Vector3(0, 0, -l * 0.5))
	_part(u, d, Vector3(0.12, 0.006, 0.12), gold, Vector3(0.0, 0.01, -0.25), Vector3(0, 0.78, 0))
	_part(u, d, Vector3(0.06, 0.05, 0.06), red, Vector3(0.0, 0.03, -0.25))
	# gold border strips on A for a finished look
	_part(u, a, Vector3(w, 0.016, 0.015), gold, Vector3(0, 0, l * 0.5))
	_part(u, a, Vector3(w, 0.016, 0.015), gold, Vector3(0, 0, -l * 0.5))
	u.rg["map"] = mp
	u.rg["map_b"] = b
	u.rg["map_c"] = c
	u.rg["map_d"] = d


static func _key(keys: Array, s: float) -> Array:
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if s <= float(b[0]):
			var f: float = clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			var out := []
			for j in range(1, a.size()):
				out.append(lerpf(float(a[j]), float(b[j]), f))
			return out
	var last: Array = keys[keys.size() - 1]
	return last.slice(1)


static func _swoosh_tex() -> Texture2D:
	if _tex != null:
		return _tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (float(x) / n - 0.5) * 2.0
			var dy := (float(y) / n - 0.5) * 2.0
			var rr := sqrt(dx * dx + dy * dy)
			var th := atan2(dy, dx)
			var band := clampf(1.0 - absf(rr - 0.82) / 0.16, 0.0, 1.0)
			var tail := clampf((th + 2.5) / 2.0, 0.0, 1.0)
			var head := clampf((-0.4 - th) / 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, band * band * tail * minf(head, 1.0)))
	_tex = ImageTexture.create_from_image(img)
	return _tex


static var _tex: Texture2D


static func _make_trail(u, torso: Node3D) -> void:
	var tr := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	tr.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _swoosh_tex()
	m.albedo_color = Color(1.0, 0.95, 0.8)
	tr.material_override = m
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tr.visible = false
	torso.add_child(tr)
	u.rg["trail"] = tr


static func _bump(x: float) -> float:
	return sin(PI * clampf(x, 0.0, 1.0))


static func animate(u, dt: float) -> void:
	var rg: Dictionary = u.rg
	if rg.is_empty():
		return
	var kind: String = u.kind
	var hero: bool = kind == "hero"
	var archer: bool = kind == "archer"
	var civ: bool = kind == "villager"
	var v: float = u.sim_speed
	var mv: bool = v > 0.4 and not u.mounted
	var run: float = clampf(v / 6.0, 0.0, 1.0)
	var w: float = (5.5 + 0.9 * v) * u.gait * (0.78 if hero else 1.0) * (0.85 if civ else 1.0)
	var old_ph: float = u.gphase
	u.gphase += dt * w * (1.0 if mv else 0.35)
	var ph: float = u.gphase
	var k: float = clampf(dt * 14.0, 0.0, 1.0)
	var amp: float = (0.62 + 0.3 * run) * (0.85 if hero else 1.0) * (0.8 if civ else 1.0)
	var m: float = 1.0 if mv else 0.0
	var hips: Node3D = rg.hips
	var torso: Node3D = rg.torso
	var head: Node3D = rg.head
	var thighs: Array = rg.thighs
	var shins: Array = rg.shins
	var sh: Array = rg.sh
	var el: Array = rg.el
	# footsteps kick up dust (king only, to spare weaker phones)
	if hero and mv and run > 0.45 and floorf(old_ph / PI) != floorf(ph / PI):
		var fwd := Vector3(sin(u.rotation.y), 0, cos(u.rotation.y))
		u.battle._burst(u.position - fwd * 0.2 + Vector3(0, 0.1, 0), Color(0.72, 0.62, 0.45), 4, 1.6, false)
	# ---- walk cycle values
	var ltx: Array = [0.0, 0.0]
	var lkx: Array = [0.0, 0.0]
	for i in 2:
		var phi: float = ph + (PI if i == 1 else 0.0)
		ltx[i] = sin(phi) * amp * m
		lkx[i] = (maxf(0.0, -cos(phi)) * 1.0 + 0.12) * m
	var bob: float = (0.5 - 0.5 * cos(2.0 * ph)) * (0.09 if hero else 0.06) * m * (0.6 + run)
	var breathe: float = sin(u.anim_t * 1.7 + u.gphase) * 0.012
	var hip_y: float = 0.92 - 0.04 * m + bob + breathe
	var twist: float = sin(ph) * (0.18 if hero else 0.12) * m
	var roll: float = sin(ph) * (0.07 if hero else 0.035) * m
	var pitch: float = -0.14 * run
	var r_sx: float = -0.25 + sin(ph + PI) * 0.55 * amp * m
	var r_sy := 0.0
	var r_el: float = -0.8 - 0.5 * run * m
	var l_sx: float = -0.1 + sin(ph) * 0.5 * amp * m
	var l_el: float = -1.0 - 0.3 * run * m
	var r_sz := 0.12
	var l_sz := -0.1
	var l_sy := 0.0
	var step := 0.0
	var hip_yaw := 0.0
	var sw_alpha := 0.0
	var atk_active: bool = u.swing > 0.0
	var ab: float = 0.0
	if atk_active:
		if u.swing > 0.9 and u.rg_prev_swing <= 0.9:
			u.atk_style = 4 if u.power else randi() % 4
			if hero:
				if u.power:
					u.atk_style = 4
				elif u.pre_picked:
					u.pre_picked = false
				else:
					u.atk_style = HERO_SEQ[u.combo % HERO_SEQ.size()]
					u.combo += 1
				u.hit_fx = 0
			if civ:
				u.atk_style = 0
		var s: float = 1.0 - u.swing
		var pose: Array
		if archer:
			pose = _key(BOW, s)
		else:
			pose = _key(ATK[u.atk_style] if u.atk_style < 5 else ATK_HERO[u.atk_style - 5], s)
		r_sx = pose[0]
		r_sy = pose[1]
		r_el = pose[2]
		twist = pose[3]
		pitch = pose[4]
		step = pose[5]
		l_sx = pose[6]
		l_el = pose[7]
		ab = clampf(minf(s * 6.0, (1.0 - s) * 4.0 + 0.2), 0.0, 1.0)
		if archer:
			l_sx = -1.55
			l_el = -0.1
			twist = -0.3 * minf(s / 0.55, 1.0)
		else:
			# the whole body follows the strike: pelvis counter-rotates, knees bend, weight drops into the blow
			hip_yaw = -twist * 0.5
			hip_y -= (0.08 + 0.1 * maxf(step, 0.0)) * ab
			if hero and u.atk_style == 7:
				var sp: float = clampf((s - 0.2) / 0.6, 0.0, 1.0)
				hip_yaw = TAU * sp * sp * (3.0 - 2.0 * sp) * 0.9 + (-twist * 0.5 if sp <= 0.0 else 0.0)
				hip_y += 0.06 * sin(sp * PI)
			elif hero and u.atk_style == 8:
				hip_y += 0.22 * _bump((s - 0.3) / 0.45)
			if hero:
				var fwv := Vector3(sin(u.rotation.y), 0, cos(u.rotation.y))
				if u.atk_style == 5 or u.atk_style == 10:
					if s > 0.45 and u.hit_fx == 0:
						u.hit_fx = 1
						u.battle._burst(u.position + fwv * 1.5 + Vector3(0, 0.9 if u.atk_style == 5 else 0.3, 0), Color(0.75, 0.08, 0.08), 7, 2.2, false)
					if s > 0.8 and u.hit_fx == 1:
						u.hit_fx = 2
						u.battle._burst(u.position + fwv * 1.4 + Vector3(0, 0.9 if u.atk_style == 5 else 0.3, 0), Color(0.75, 0.08, 0.08), 9, 3.4, false)
				elif u.atk_style == 6 and s > 0.5 and u.hit_fx == 0:
					u.hit_fx = 1
					u.battle._burst(u.position + fwv * 1.3 + Vector3(0, 1.6, 0), Color(1.0, 0.95, 0.8), 8, 4.0, true)
			if u.atk_style == 4 and s > 0.58 and u.rg_prev_swing > 1.0 - 0.58:
				var fw := Vector3(sin(u.rotation.y), 0, cos(u.rotation.y))
				u.battle._burst(u.position + fw * 1.1 + Vector3(0, 0.1, 0), Color(0.72, 0.62, 0.45), 8, 3.0, false)
			if not civ:
				sw_alpha = _bump((s - 0.3) / 0.32)
	u.rg_prev_swing = u.swing
	if atk_active and not archer:
		var lead := step * 1.3
		ltx[0] = lerpf(ltx[0], -lead, ab)
		lkx[0] = lerpf(lkx[0], 0.15 + maxf(step, 0.0) * 0.9, ab)
		ltx[1] = lerpf(ltx[1], maxf(step, 0.0) * 0.9 + 0.15, ab)
		lkx[1] = lerpf(lkx[1], 0.25, ab)
	# KICK: right leg snaps up and forward, body leans back for balance
	if u.kick_t > 0.0 and not atk_active:
		u.kick_t = maxf(0.0, u.kick_t - dt * 2.2)
		var kt2: float = 1.0 - u.kick_t
		var kb: float = _bump((kt2 - 0.08) / 0.6)
		ltx[0] = -1.6 * kb
		lkx[0] = 0.15 + 0.1 * kb
		ltx[1] = 0.12 * kb
		lkx[1] = 0.25 * kb
		pitch = -0.3 * kb
		l_sx = -0.5
		r_sx = -0.7
		hip_y -= 0.05 * kb
	match u.pose_mode:
		"kneel", "bow":
			ltx = [-1.45, -1.45]
			lkx = [1.55, 1.55]
			hip_y = 0.46
		"sit":
			ltx = [-1.5, -1.5]
			lkx = [1.5, 1.5]
			hip_y = 0.62
		"lock":
			ltx = [-0.55, 0.6]
			lkx = [0.55, 0.3]
			hip_y -= 0.12
	for i in 2:
		thighs[i].rotation.x = lerpf(thighs[i].rotation.x, ltx[i], k)
		shins[i].rotation.x = lerpf(shins[i].rotation.x, lkx[i], k)
	# ---- shield rises when struck and during strikes
	var hit: float = maxf(u.flash, u.stagger)
	var guard: float = clampf(u.flash * 1.2 + u.stagger * 0.8, 0.0, 1.0)
	if guard > 0.0 and not archer and not civ:
		l_sx = lerpf(l_sx, -1.25, guard)
		l_el = lerpf(l_el, -1.5, guard)
	# ---- victory / cheer
	var cheer := false
	if u.battle.over and u.battle.winner_team == u.team:
		cheer = true
		r_sx = -2.8 + sin(u.anim_t * 6.0 + u.gphase) * 0.25
		r_sy = 0.1
		r_el = -0.4
		pitch = -0.1
		hip_y = 0.92 + absf(sin(u.anim_t * 4.0 + u.gphase)) * 0.12
		if archer:
			l_sx = -2.4
	if hero and not atk_active and not cheer and not mv:
		r_sx -= 0.1
	# civilians: idle gestures when standing, carrying pose with a load
	if civ and not atk_active and not cheer:
		if u.carry_node != null and u.carry_node.visible:
			l_sx = -0.3
			r_sx = -0.3
			pitch += 0.08
		elif not mv:
			r_sx = -0.2 + sin(u.anim_t * 0.9 + u.gphase) * 0.1
			l_sx = -0.15 + sin(u.anim_t * 1.1 + u.gphase) * 0.08
	# ---- the king's map: pull it from the pocket, unfold it, study it (searching left/right), fold it away
	var head_extra := 0.0
	var head_yaw := 0.0
	if hero and rg.has("map"):
		var want: bool = u.map_want and not atk_active
		if want:
			u.map_t = move_toward(u.map_t, 1.0, dt * 1.3)
			if u.map_t > 0.6:
				u.map_open = move_toward(u.map_open, 1.0, dt * 0.85)
		else:
			u.map_open = move_toward(u.map_open, 0.0, dt * 1.7)
			if u.map_open < 0.3:
				u.map_t = move_toward(u.map_t, 0.0, dt * 1.6)
		var mpv: Node3D = rg.map
		var shd: Node3D = u.shield_n
		if u.map_t > 0.001 and not cheer:
			var b1: float = smoothstep(0.0, 0.45, u.map_t)
			var b2: float = smoothstep(0.35, 1.0, u.map_t)
			# hand dives into the pocket, then both hands raise the map
			r_sx = lerpf(r_sx, 0.35, b1 * (1.0 - b2))
			r_el = lerpf(r_el, -1.35, b1 * (1.0 - b2))
			l_sx = lerpf(l_sx, 0.1, b1 * (1.0 - b2))
			l_sx = lerpf(l_sx, -0.6, b2)
			l_el = lerpf(l_el, -1.0, b2)
			r_sx = lerpf(r_sx, -0.6, b2)
			r_el = lerpf(r_el, -1.0, b2)
			r_sy = lerpf(r_sy, -0.35, b2)
			pitch += 0.12 * b2
			head_extra = 0.55 * b2
			var ob: float = u.map_open
			if ob > 0.8:
				head_yaw = sin(u.anim_t * 0.8) * 0.5
				head_extra += 0.08 * sin(u.anim_t * 1.6)
				r_sy = -0.35 + sin(u.anim_t * 1.1) * 0.2
			if shd != null:
				shd.scale = shd.scale.lerp(Vector3.ONE * (1.0 - b2), 0.3)
			mpv.visible = u.map_t > 0.5
			var fs: float = 0.3 + 0.55 * smoothstep(0.0, 1.0, ob)
			mpv.scale = Vector3.ONE * fs * smoothstep(0.45, 0.7, u.map_t)
			mpv.rotation = u.map_rot
			u.arm.visible = u.map_t < 0.45
			var e1: float = smoothstep(0.0, 0.5, ob)
			var e2: float = smoothstep(0.5, 1.0, ob)
			rg.map_b.rotation.z = -PI * (1.0 - e1) * 0.97
			rg.map_c.rotation.x = PI * (1.0 - e2) * 0.97
			rg.map_d.rotation.x = PI * (1.0 - e2) * 0.97
		else:
			mpv.visible = false
			u.arm.visible = true
			if shd != null:
				shd.scale = shd.scale.lerp(Vector3.ONE, 0.3)
	# ---- BLOCK: shield up, knees bent, sword tucked back
	if u.blocking and not atk_active and not archer and not civ:
		l_sx = -1.35
		l_el = -1.6
		r_sx = -0.7
		r_el = -1.3
		hip_y -= 0.1
		pitch += 0.1
		head_extra -= 0.1
	# ---- scripted poses for the king clash / captive scenes
	if u.pose_mode != "":
		var pm: String = u.pose_mode
		var pp: float = u.pose_push
		if pm == "lock":
			r_sx = -1.45 + 0.08 * sin(u.anim_t * 38.0)
			r_sy = 0.3 * u.pose_side
			r_el = -0.55
			l_sx = -1.3
			l_el = -1.0
			pitch = 0.18 + 0.3 * pp
			twist = 0.12 * u.pose_side
			roll = sin(u.anim_t * 44.0) * 0.035
			head_extra = 0.1
			u.body.position.z = lerpf(u.body.position.z, 0.28 * pp, 0.3)
		elif pm == "sit":
			pitch = -0.05
			head_extra = 0.0
			r_sx = -0.35
			l_sx = -0.35
			r_sz = 0.25
			l_sz = -0.25
			r_el = -1.25
			l_el = -1.25
		elif pm == "kneel" or pm == "bow":
			pitch = 0.45 if pm == "kneel" else 0.85
			head_extra = 0.5 if pm == "kneel" else 0.7
			r_sx = 0.15 if pm == "kneel" else -0.55
			l_sx = 0.15 if pm == "kneel" else -0.55
			r_el = -0.3
			l_el = -0.3
			u.arm.visible = false
			head_yaw = 0.0
		elif pm == "held":
			# marched off by two guards: arms pulled out wide, head bowed
			pitch = 0.3
			head_extra = 0.65
			r_sx = -0.15
			l_sx = -0.15
			r_sz = 1.25
			l_sz = -1.25
			r_el = -0.25
			l_el = -0.25
			u.arm.visible = false
		elif pm == "grip":
			# guard: the arm nearest the prisoner reaches out and grabs his wrist
			var gs: float = u.pose_side
			if gs > 0.0:
				r_sx = -1.0
				r_sy = -0.55
				r_el = -0.6
			else:
				l_sx = -1.0
				l_sy = 0.55
				l_el = -0.6
		elif pm == "sheath":
			# plants the sword point-down in the ground
			r_sx = -0.05
			r_el = -0.05
			pitch = 0.08
			head_extra = 0.1
	# ---- directional hit reaction: recoil away from the blow, head snaps, body shoved back
	var hx: float = u.hit_dir.x
	var hz: float = u.hit_dir.y
	if hit > 0.0:
		pitch += -0.42 * hz * hit
		roll += -0.38 * hx * hit
		twist += 0.25 * hx * hit
		hip_y -= 0.05 * hit
		l_sx = lerpf(l_sx, l_sx - 0.5, hit)
	twist += 0.18 * u.stagger * sin(u.anim_t * 30.0)
	var kk2: float = clampf(dt * 16.0, 0.0, 1.0)
	hips.position.y = lerpf(hips.position.y, hip_y, k)
	hips.rotation.y = lerpf(hips.rotation.y, hip_yaw, kk2)
	torso.rotation.x = lerpf(torso.rotation.x, pitch, kk2)
	torso.rotation.y = lerpf(torso.rotation.y, twist, kk2)
	torso.rotation.z = lerpf(torso.rotation.z, roll, k)
	head.rotation.x = lerpf(head.rotation.x, -pitch * 0.6 + 0.18 * hit * hz + head_extra, k)
	var look: float = sin(u.anim_t * 0.8 + u.gphase) * 0.18 * (1.0 - m)
	head.rotation.y = lerpf(head.rotation.y, -twist * 0.7 + look + head_yaw, clampf(dt * 8.0, 0.0, 1.0))
	var kk: float = clampf(dt * 18.0, 0.0, 1.0)
	sh[0].rotation = sh[0].rotation.lerp(Vector3(r_sx, r_sy, r_sz), kk)
	el[0].rotation.x = lerpf(el[0].rotation.x, r_el, kk)
	sh[1].rotation = sh[1].rotation.lerp(Vector3(l_sx, l_sy, l_sz), kk)
	el[1].rotation.x = lerpf(el[1].rotation.x, l_el, kk)
	# lunge and knock-back of the whole body
	var lz: float = step * (0.0 if archer else 1.0) - hz * 0.22 * u.stagger
	var lx: float = -hx * 0.18 * u.stagger
	var kp: float = clampf(dt * 18.0, 0.0, 1.0)
	u.body.position.z = lerpf(u.body.position.z, lz, kp)
	u.body.position.x = lerpf(u.body.position.x, lx, kp)
	if u.cape != null:
		u.cape.rotation.x = 0.1 + run * 0.6 + sin(u.anim_t * 5.0 + u.gphase) * (0.05 + 0.08 * run) + 0.5 * ab
		u.cape.rotation.z = sin(u.anim_t * 3.3 + u.gphase) * 0.05 * (1.0 + run)
	# sword swoosh
	if rg.has("trail"):
		var tr: MeshInstance3D = rg.trail
		if sw_alpha > 0.01:
			tr.visible = true
			tr.transparency = 1.0 - sw_alpha * 0.85
			match u.atk_style:
				0:
					tr.rotation = Vector3(0, PI * 0.5, 0.9)
					tr.position = Vector3(0.2, 0.7, 1.0)
				1:
					tr.rotation = Vector3(-PI * 0.5, 0, 2.6)
					tr.position = Vector3(0, 0.55, 0.9)
				2:
					tr.rotation = Vector3(0, PI * 0.5, 0.2)
					tr.position = Vector3(0.1, 0.55, 1.1)
				3:
					tr.rotation = Vector3(-0.6, 0.0, 0.6)
					tr.position = Vector3(0.1, 0.7, 1.0)
				6:
					tr.rotation = Vector3(0, PI * 0.5, 0.0)
					tr.position = Vector3(0.0, 0.95, 1.0)
				7:
					tr.rotation = Vector3(0, PI * 0.5, 0.0)
					tr.position = Vector3(0.0, 0.7, 0.9)
				8:
					tr.rotation = Vector3(0, PI * 0.5, 1.2)
					tr.position = Vector3(0.1, 0.6, 1.1)
				5, 10:
					tr.rotation = Vector3(0, PI * 0.5, 0.0)
					tr.position = Vector3(0.0, 0.5, 1.2)
				_:
					tr.rotation = Vector3(0, PI * 0.5, 0.5)
					tr.position = Vector3(0.2, 0.7, 1.2)
			tr.scale = Vector3.ONE * (1.35 if (u.atk_style == 4 or u.atk_style == 7) else 0.9)
		else:
			tr.visible = false
	u.stagger = maxf(0.0, u.stagger - dt * 2.5)


# ------------------------------------------------------------------ death
# variant 0: fall backwards, arms flung out; 1: fall to the side; 2: sink to the knees, then topple forward
static func animate_death(u, dt: float) -> void:
	var rg: Dictionary = u.rg
	if rg.is_empty():
		return
	u.death_t += dt
	var t: float = u.death_t - u.death_delay
	if t < 0.0:
		return   # stand still until the king's blade arrives
	var f: float = clampf(t / 0.55, 0.0, 1.0)
	f = f * f
	var body: Node3D = u.body
	var sh: Array = rg.sh
	var el: Array = rg.el
	var thighs: Array = rg.thighs
	var shins: Array = rg.shins
	var torso: Node3D = rg.torso
	var hips: Node3D = rg.hips
	match u.death_var:
		3:
			# run through the belly: fold over the blade, clutch the wound, drop to the knees, topple
			var k3: float = clampf(t / 0.3, 0.0, 1.0)
			torso.rotation.x = lerpf(torso.rotation.x, 1.15 * k3, 0.4)
			sh[0].rotation = sh[0].rotation.lerp(Vector3(-0.7, 0.4, 0.5), 0.3)
			sh[1].rotation = sh[1].rotation.lerp(Vector3(-0.7, -0.4, -0.5), 0.3)
			el[0].rotation.x = lerpf(el[0].rotation.x, -1.6, 0.3)
			el[1].rotation.x = lerpf(el[1].rotation.x, -1.6, 0.3)
			if t > 0.35:
				var k4: float = clampf((t - 0.35) / 0.35, 0.0, 1.0)
				thighs[0].rotation.x = lerpf(thighs[0].rotation.x, -1.2 * k4, 0.4)
				thighs[1].rotation.x = lerpf(thighs[1].rotation.x, -1.2 * k4, 0.4)
				shins[0].rotation.x = lerpf(shins[0].rotation.x, 1.3 * k4, 0.4)
				shins[1].rotation.x = lerpf(shins[1].rotation.x, 1.3 * k4, 0.4)
				hips.position.y = lerpf(hips.position.y, 0.55 * k4, 0.4)
			if t > 0.8:
				var k5: float = clampf((t - 0.8) / 0.35, 0.0, 1.0)
				body.rotation.x = lerpf(body.rotation.x, 1.5 * k5, 0.4)
				body.position.y = lerpf(body.position.y, 0.3 * k5, 0.4)
		4:
			# beheaded: the head flies off, the body staggers a moment, then falls
			if not u.head_off:
				u.head_off = true
				_pop_head(u)
			var k6: float = clampf(t / 0.45, 0.0, 1.0)
			sh[0].rotation = sh[0].rotation.lerp(Vector3(-1.6 + sin(t * 25.0) * 0.4, 0.5, 0.9), 0.3)
			sh[1].rotation = sh[1].rotation.lerp(Vector3(-1.4 - sin(t * 25.0) * 0.4, -0.5, -0.9), 0.3)
			torso.rotation.z = sin(t * 14.0) * 0.12 * (1.0 - k6)
			if t > 0.45:
				var k7: float = clampf((t - 0.45) / 0.4, 0.0, 1.0)
				body.rotation.x = lerpf(body.rotation.x, -1.5 * k7, 0.4)
				body.position.y = lerpf(body.position.y, 0.2 * k7, 0.4)
				thighs[0].rotation.x = lerpf(thighs[0].rotation.x, -0.4, 0.2)
		0:
			body.rotation.x = lerpf(body.rotation.x, -1.5 * f, 0.5)
			body.position.y = lerpf(body.position.y, 0.2 * f, 0.5)
			sh[0].rotation = sh[0].rotation.lerp(Vector3(-1.2, 0.3, 1.2), 0.25)
			sh[1].rotation = sh[1].rotation.lerp(Vector3(-0.9, 0.0, -1.2), 0.25)
			thighs[0].rotation.x = lerpf(thighs[0].rotation.x, -0.5, 0.2)
			thighs[1].rotation.x = lerpf(thighs[1].rotation.x, 0.3, 0.2)
		1:
			body.rotation.z = lerpf(body.rotation.z, 1.45 * u.death_side * f, 0.5)
			body.rotation.x = lerpf(body.rotation.x, -0.3 * f, 0.3)
			body.position.y = lerpf(body.position.y, 0.28 * f, 0.5)
			sh[0].rotation = sh[0].rotation.lerp(Vector3(-0.4, 0.0, 0.8), 0.25)
			sh[1].rotation = sh[1].rotation.lerp(Vector3(0.4, 0.0, -0.6), 0.25)
			shins[0].rotation.x = lerpf(shins[0].rotation.x, 1.0, 0.2)
		_:
			var k1: float = clampf(t / 0.35, 0.0, 1.0)
			thighs[0].rotation.x = lerpf(thighs[0].rotation.x, -1.3 * k1, 0.4)
			thighs[1].rotation.x = lerpf(thighs[1].rotation.x, -1.3 * k1, 0.4)
			shins[0].rotation.x = lerpf(shins[0].rotation.x, 1.4 * k1, 0.4)
			shins[1].rotation.x = lerpf(shins[1].rotation.x, 1.4 * k1, 0.4)
			hips.position.y = lerpf(hips.position.y, 0.55 * k1, 0.4)
			if t > 0.4:
				var k2: float = clampf((t - 0.4) / 0.4, 0.0, 1.0)
				body.rotation.x = lerpf(body.rotation.x, 1.5 * k2, 0.5)
				body.position.y = lerpf(body.position.y, 0.3 * k2, 0.5)
			sh[0].rotation = sh[0].rotation.lerp(Vector3(0.3, 0.0, 0.5), 0.2)
			sh[1].rotation = sh[1].rotation.lerp(Vector3(0.3, 0.0, -0.5), 0.2)
	torso.rotation.x = lerpf(torso.rotation.x, 0.0, 0.2)
	el[0].rotation.x = lerpf(el[0].rotation.x, -0.2, 0.2)
	el[1].rotation.x = lerpf(el[1].rotation.x, -0.2, 0.2)


# the loser's sword leaves his hand and clatters to the ground; returns the dropped copy
static func drop_sword(u) -> Node3D:
	var hand: Node3D = u.arm
	var par: Node = u.get_parent()
	if hand == null or par == null:
		return null
	var cp: Node3D = hand.duplicate()
	par.add_child(cp)
	cp.global_transform = hand.global_transform
	hand.visible = false
	var side := Vector3(sin(u.rotation.y + 1.2), 0, cos(u.rotation.y + 1.2))
	var dest: Vector3 = u.position + side * 1.1 + Vector3(0, 0.07, 0)
	var tw := cp.create_tween()
	tw.tween_property(cp, "global_position", dest + Vector3(0, 0.9, 0), 0.18)
	tw.parallel().tween_property(cp, "rotation", Vector3(PI * 0.5, u.rotation.y + 0.6, 0.0), 0.45)
	tw.tween_property(cp, "global_position", dest, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): u.battle.sfx.play("clang", dest, 0.0, 0.8))
	return cp


static func _pop_head(u) -> void:
	var head: Node3D = u.rg.head
	var par: Node = u.get_parent()
	if par == null:
		return
	var h: Node3D = head.duplicate()
	par.add_child(h)
	h.global_transform = head.global_transform
	head.visible = false
	var p0: Vector3 = h.global_position
	var dir := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * randf_range(2.2, 3.4)
	var spin := Vector3(randf_range(-9, 9), randf_range(-5, 5), randf_range(-9, 9))
	var fly := func(x: float):
		if is_instance_valid(h):
			h.global_position = p0 + dir * x + Vector3(0, 4.2 * x * (1.0 - x) - 0.9 * x, 0)
			h.rotation += spin * 0.016
	var tw := h.create_tween()
	tw.tween_method(fly, 0.0, 1.0, 0.7)
	tw.tween_callback(func():
		if is_instance_valid(h):
			h.global_position.y = 0.2)
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		if is_instance_valid(h):
			h.queue_free())
	u.battle._burst(p0, Color(0.75, 0.08, 0.08), 12, 3.5, false)


# ------------------------------------------------------------------ civilians: villagers, messenger, advisor, steward
static func build_civ(u, tc: Color, role: String) -> void:
	var skin_c := [Color(0.86, 0.66, 0.52), Color(0.78, 0.58, 0.42), Color(0.93, 0.76, 0.62), Color(0.62, 0.44, 0.32)]
	var skin = u._mat(skin_c[randi() % 4], 0.0, 0.9)
	var leather = u._mat(Color(0.33, 0.2, 0.1), 0.0, 0.9)
	var dark = u._mat(Color(0.22, 0.16, 0.11), 0.0, 0.9)
	var gold = u._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var steel = u._mat(Color(0.7, 0.72, 0.78), 0.9, 0.3)
	var white = u._mat(Color(0.93, 0.92, 0.88), 0.0, 0.95)
	var wood = u._mat(Color(0.45, 0.3, 0.15), 0.0, 0.9)
	var straw = u._mat(Color(0.85, 0.72, 0.35), 0.0, 0.95)
	var sash = u._mat(tc, 0.0, 0.8)
	var variant: int = randi() % 4
	var tunic_c: Color = [Color(0.52, 0.4, 0.26), Color(0.4, 0.5, 0.3), Color(0.55, 0.32, 0.25), Color(0.38, 0.42, 0.55)][variant]
	var legs_c: Color = Color(0.25, 0.18, 0.12)
	var robe := false
	match role:
		"messenger":
			tunic_c = Color(0.2, 0.35, 0.62)
			legs_c = Color(0.9, 0.88, 0.8)
		"advisor":
			tunic_c = Color(0.45, 0.12, 0.52)
			robe = true
		"steward":
			tunic_c = Color(0.15, 0.34, 0.2)
			legs_c = Color(0.15, 0.12, 0.1)
	var tunic = u._mat(tunic_c, 0.0, 0.85)
	var tunic_d = u._mat(tunic_c.darkened(0.35), 0.0, 0.85)
	var pants = u._mat(legs_c, 0.0, 0.9)
	var body: Node3D = u.body
	var hips := _pivot(body, Vector3(0, 0.88, 0))
	_part(u, hips, Vector3(0.4, 0.18, 0.24), leather, Vector3(0, 0.02, 0))
	u.rg = {"hips": hips}
	var thighs := []
	var shins := []
	for side in [-1, 1]:
		var th := _pivot(hips, Vector3(0.1 * side, -0.02, 0))
		_part(u, th, Vector3(0.15, 0.44, 0.17), pants, Vector3(0, -0.22, 0), Vector3.ZERO, true)
		var kn := _pivot(th, Vector3(0, -0.44, 0))
		_part(u, kn, Vector3(0.14, 0.42, 0.16), pants, Vector3(0, -0.21, 0))
		_part(u, kn, Vector3(0.16, 0.1, 0.27), dark, Vector3(0, -0.42, 0.05))
		thighs.append(th)
		shins.append(kn)
		u.legs.append(th)
	u.rg["thighs"] = thighs
	u.rg["shins"] = shins
	var woman: bool = role == "villager" and variant == 1
	if robe or woman:
		# long garment hanging from the hips, swings slightly with the stride
		var sk := _pivot(hips, Vector3(0, 0.0, 0))
		_part(u, sk, Vector3(0.5, 0.6, 0.3), tunic if robe else tunic_d, Vector3(0, -0.3, 0), Vector3.ZERO, true)
		_part(u, sk, Vector3(0.54, 0.08, 0.34), gold if robe else sash, Vector3(0, -0.6, 0))
	var torso := _pivot(hips, Vector3(0, 0.1, 0))
	u.rg["torso"] = torso
	_part(u, torso, Vector3(0.46, 0.56, 0.26), tunic, Vector3(0, 0.31, 0), Vector3.ZERO, true)
	_part(u, torso, Vector3(0.48, 0.08, 0.28), sash if role != "advisor" else gold, Vector3(0, 0.05, 0))
	var cape_node: Node3D = null
	match role:
		"villager":
			if variant == 2:
				_part(u, torso, Vector3(0.4, 0.5, 0.04), leather, Vector3(0, 0.25, 0.15))     # apron
			elif variant == 3:
				_part(u, torso, Vector3(0.5, 0.1, 0.3), white, Vector3(0, 0.56, 0))            # collar
		"messenger":
			_part(u, torso, Vector3(0.07, 0.62, 0.3), leather, Vector3(0.0, 0.3, 0.0), Vector3(0, 0, 0.7))   # satchel strap
			_part(u, torso, Vector3(0.3, 0.26, 0.12), leather, Vector3(-0.2, 0.0, 0.0))        # satchel
			_part(u, torso, Vector3(0.3, 0.07, 0.14), gold, Vector3(-0.2, 0.1, 0.0))
		"advisor":
			_part(u, torso, Vector3(0.58, 0.14, 0.34), tunic_d, Vector3(0, 0.56, 0))           # mantle
			for i in 6:
				_part(u, torso, Vector3(0.06, 0.06, 0.04), gold, Vector3(-0.2 + i * 0.08, 0.28 - sin(float(i) / 5.0 * PI) * -0.08, 0.15))  # gold chain
			cape_node = _pivot(torso, Vector3(0, 0.58, -0.14))
			_part(u, cape_node, Vector3(0.52, 1.0, 0.04), tunic_d, Vector3(0, -0.5, -0.03))
		"steward":
			for i in 3:
				_part(u, torso, Vector3(0.05, 0.05, 0.03), gold, Vector3(0.0, 0.18 + i * 0.14, 0.14))   # buttons
			_part(u, torso, Vector3(0.1, 0.14, 0.06), gold, Vector3(0.2, 0.0, 0.14))                    # key ring
			cape_node = _pivot(torso, Vector3(0, 0.58, -0.14))
			_part(u, cape_node, Vector3(0.46, 0.55, 0.04), tunic_d, Vector3(0, -0.28, -0.03))
	if cape_node != null:
		u.cape = cape_node
		u.rg["cape"] = cape_node
	# head
	var neck := _pivot(torso, Vector3(0, 0.62, 0))
	var head := _pivot(neck, Vector3(0, 0.04, 0))
	u.rg["head"] = head
	_part(u, head, Vector3(0.28, 0.28, 0.28), skin, Vector3(0, 0.15, 0), Vector3.ZERO, true)
	_part(u, head, Vector3(0.05, 0.05, 0.03), dark, Vector3(-0.07, 0.17, 0.145))
	_part(u, head, Vector3(0.05, 0.05, 0.03), dark, Vector3(0.07, 0.17, 0.145))
	var hair = u._mat([Color(0.2, 0.12, 0.06), Color(0.5, 0.3, 0.12), Color(0.1, 0.08, 0.07), Color(0.85, 0.85, 0.85)][variant], 0.0, 0.95)
	match role:
		"villager":
			match variant:
				0:
					_part(u, head, Vector3(0.5, 0.04, 0.5), straw, Vector3(0, 0.3, 0))
					_part(u, head, Vector3(0.28, 0.14, 0.28), straw, Vector3(0, 0.38, 0))
					_part(u, head, Vector3(0.3, 0.05, 0.3), sash, Vector3(0, 0.33, 0))
				1:
					_part(u, head, Vector3(0.32, 0.12, 0.32), white, Vector3(0, 0.3, -0.01))           # head cloth
					_part(u, head, Vector3(0.1, 0.34, 0.1), hair, Vector3(0, 0.1, -0.18))             # braid
					_part(u, head, Vector3(0.32, 0.3, 0.06), white, Vector3(0, 0.16, -0.15))
				2:
					_part(u, head, Vector3(0.32, 0.2, 0.32), tunic_d, Vector3(0, 0.27, -0.02))        # hood
					_part(u, head, Vector3(0.32, 0.3, 0.08), tunic_d, Vector3(0, 0.14, -0.16))
				_:
					_part(u, head, Vector3(0.3, 0.1, 0.3), hair, Vector3(0, 0.3, -0.02))
					_part(u, head, Vector3(0.2, 0.2, 0.06), hair, Vector3(0, 0.06, 0.15))             # white beard
		"messenger":
			_part(u, head, Vector3(0.34, 0.14, 0.34), u._mat(Color(0.8, 0.15, 0.15)), Vector3(0, 0.31, 0))
			_part(u, head, Vector3(0.34, 0.05, 0.12), u._mat(Color(0.8, 0.15, 0.15)), Vector3(0, 0.26, 0.2))
			_part(u, head, Vector3(0.03, 0.03, 0.32), white, Vector3(0.14, 0.42, -0.08), Vector3(0.5, 0, 0.2))
		"advisor":
			_part(u, head, Vector3(0.5, 0.05, 0.5), u._mat(Color(0.35, 0.08, 0.4)), Vector3(0, 0.3, 0))
			_part(u, head, Vector3(0.34, 0.18, 0.34), u._mat(Color(0.4, 0.1, 0.46)), Vector3(0, 0.4, 0))
			_part(u, head, Vector3(0.24, 0.18, 0.24), u._mat(Color(0.42, 0.1, 0.48)), Vector3(0, 0.56, 0))
			_part(u, head, Vector3(0.14, 0.18, 0.14), u._mat(Color(0.44, 0.1, 0.5)), Vector3(0, 0.72, 0))
			_part(u, head, Vector3(0.36, 0.05, 0.36), gold, Vector3(0, 0.34, 0))
			_part(u, head, Vector3(0.1, 0.1, 0.04), u._mat(Color(0.3, 0.9, 1.0), 0.2, 0.2, 1.0), Vector3(0, 0.4, 0.18))
			_part(u, head, Vector3(0.22, 0.26, 0.06), white, Vector3(0, -0.02, 0.15))                  # long beard
			_part(u, head, Vector3(0.14, 0.2, 0.05), white, Vector3(0, -0.2, 0.15))
		"steward":
			_part(u, head, Vector3(0.34, 0.08, 0.34), u._mat(Color(0.12, 0.26, 0.16)), Vector3(0, 0.3, 0))
			_part(u, head, Vector3(0.34, 0.04, 0.14), u._mat(Color(0.12, 0.26, 0.16)), Vector3(0, 0.27, 0.22))
			_part(u, head, Vector3(0.06, 0.06, 0.04), gold, Vector3(0, 0.3, 0.19))
			_part(u, head, Vector3(0.14, 0.06, 0.05), dark, Vector3(0, 0.08, 0.15))                     # moustache
	# arms
	var sh_p := []
	var el_p := []
	for side in [1, -1]:
		var s := _pivot(torso, Vector3(0.3 * side, 0.54, 0))
		_part(u, s, Vector3(0.14, 0.3, 0.14), tunic, Vector3(0, -0.14, 0), Vector3.ZERO, true)
		var e := _pivot(s, Vector3(0, -0.3, 0))
		_part(u, e, Vector3(0.12, 0.26, 0.12), tunic_d, Vector3(0, -0.13, 0))
		_part(u, e, Vector3(0.12, 0.11, 0.12), skin, Vector3(0, -0.29, 0))
		sh_p.append(s)
		el_p.append(e)
	u.rg["sh"] = sh_p
	u.rg["el"] = el_p
	var hand := _pivot(el_p[0], Vector3(0, -0.32, 0))
	hand.rotation.x = -0.3
	u.arm = hand
	match role:
		"villager":
			_part(u, hand, Vector3(0.05, 0.7, 0.05), wood, Vector3(0, -0.2, 0.0))
			if variant == 2 or variant == 3:
				_part(u, hand, Vector3(0.2, 0.12, 0.12), steel, Vector3(0, -0.52, 0.0))                 # hammer / pick head
		"messenger":
			_part(u, hand, Vector3(0.1, 0.34, 0.1), white, Vector3(0, -0.1, 0.0))
			_part(u, hand, Vector3(0.12, 0.05, 0.12), u._mat(Color(0.8, 0.15, 0.15)), Vector3(0, -0.12, 0.0))
		"advisor":
			_part(u, hand, Vector3(0.05, 1.7, 0.05), wood, Vector3(0, -0.3, 0))
			_part(u, hand, Vector3(0.13, 0.13, 0.13), u._mat(Color(0.3, 0.9, 1.0), 0.2, 0.2, 1.4), Vector3(0, 0.62, 0))
			_part(u, hand, Vector3(0.2, 0.05, 0.2), gold, Vector3(0, 0.52, 0))
		"steward":
			_part(u, hand, Vector3(0.26, 0.34, 0.05), leather, Vector3(0, -0.12, 0.08))                # ledger
			_part(u, hand, Vector3(0.22, 0.3, 0.02), white, Vector3(0, -0.12, 0.11))
	u.gait = 0.9 + randf() * 0.24
	u.gphase = randf() * TAU
	u.civ_role = role
	u.rigged = true
