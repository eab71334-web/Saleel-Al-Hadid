extends RefCounted
# King appearance: palettes, defaults, and the code that builds face / hair / beard / crown / pauldrons.
# The look is a Dictionary of small integers (saved in Profile). Only the local player's king uses the saved
# look; preview screen forces one through `force`.

static var force: Dictionary = {}

const SKIN := [Color(0.95, 0.80, 0.68), Color(0.86, 0.66, 0.52), Color(0.76, 0.56, 0.40), Color(0.62, 0.43, 0.30), Color(0.45, 0.30, 0.21), Color(0.80, 0.72, 0.62)]
const HAIR := [Color(0.10, 0.07, 0.05), Color(0.30, 0.18, 0.09), Color(0.55, 0.32, 0.12), Color(0.85, 0.70, 0.35), Color(0.62, 0.62, 0.64), Color(0.62, 0.15, 0.08)]
const EYE := [Color(0.18, 0.12, 0.08), Color(0.20, 0.40, 0.75), Color(0.25, 0.55, 0.30), Color(0.50, 0.50, 0.55), Color(0.75, 0.55, 0.1)]
const GEM := [Color(0.9, 0.1, 0.15), Color(0.15, 0.45, 1.0), Color(0.15, 0.8, 0.35), Color(0.65, 0.2, 0.9), Color(0.98, 0.95, 0.85)]
# armor: [colour, metallic, roughness]
const ARMOR := [[Color(0.72, 0.74, 0.8), 0.9, 0.3], [Color(0.95, 0.75, 0.25), 1.0, 0.25], [Color(0.14, 0.14, 0.17), 0.8, 0.35], [Color(0.70, 0.45, 0.22), 0.9, 0.35], [Color(0.35, 0.5, 0.75), 0.9, 0.3], [Color(0.93, 0.93, 0.95), 0.7, 0.3]]
const CAPE := [Color(0, 0, 0, 0), Color(0.55, 0.08, 0.10), Color(0.1, 0.2, 0.5), Color(0.1, 0.35, 0.18), Color(0.4, 0.1, 0.5), Color(0.08, 0.08, 0.1), Color(0.9, 0.88, 0.82)]
const BLADE := [Color(0.72, 0.74, 0.8), Color(0.95, 0.75, 0.25), Color(0.9, 0.25, 0.15), Color(0.55, 0.85, 1.0), Color(0.12, 0.12, 0.15)]
const EPITHET := ["", "the Iron", "the Just", "the Lionheart", "the Conqueror", "the Wise", "the Black"]

# id -> [Arabic-able label key, number of options]
const OPTS := {
	"skin": 6, "hair": 5, "haircol": 6, "beard": 4, "eye": 5, "scar": 2, "patch": 2,
	"helm": 3, "crown": 4, "gem": 5, "armor": 6, "cape": 7, "pauld": 3, "emblem": 4, "blade": 5, "epithet": 7,
}
const DEF := {
	"skin": 1, "hair": 1, "haircol": 1, "beard": 1, "eye": 0, "scar": 0, "patch": 0,
	"helm": 1, "crown": 0, "gem": 0, "armor": 0, "cape": 0, "pauld": 0, "emblem": 0, "blade": 0, "epithet": 0,
}


static func merged(saved: Dictionary) -> Dictionary:
	var L: Dictionary = DEF.duplicate()
	for k in saved.keys():
		if OPTS.has(k):
			L[k] = clampi(int(saved[k]), 0, int(OPTS[k]) - 1)
	return L


static func random_look() -> Dictionary:
	var L: Dictionary = {}
	for k in OPTS.keys():
		L[k] = randi() % int(OPTS[k])
	L["scar"] = 1 if randf() < 0.25 else 0
	L["patch"] = 1 if randf() < 0.15 else 0
	return L


static func _p(u, parent: Node3D, sz: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, shadow := false) -> MeshInstance3D:
	return u._add(parent, u._box(sz), mat, pos, rot, shadow)


static func armor_mat(u, L: Dictionary) -> Material:
	var a: Array = ARMOR[int(L.armor)]
	return u._mat(a[0], a[1], a[2])


static func cape_mat(u, L: Dictionary, tc: Color, dark: bool) -> Material:
	var c: Color = tc
	if int(L.cape) > 0:
		c = CAPE[int(L.cape)]
	return u._mat(c.darkened(0.42) if dark else c, 0.0, 0.8)


static func blade_mat(u, L: Dictionary) -> Material:
	var c: Color = BLADE[int(L.blade)]
	var emis := 0.0
	if int(L.blade) == 2 or int(L.blade) == 3:
		emis = 0.7
	return u._mat(c, 0.9, 0.25, emis)


# face, hair, beard, headgear. `head` pivot: skull box centred at y 0.16, front is +Z.
static func head(u, head: Node3D, L: Dictionary, steel, steel_d, glow) -> void:
	var skin = u._mat(SKIN[int(L.skin)], 0.0, 0.9)
	var skin_d = u._mat(SKIN[int(L.skin)].darkened(0.14), 0.0, 0.9)
	var hairc: Color = HAIR[int(L.haircol)]
	var hair = u._mat(hairc, 0.0, 0.95)
	var dark = u._mat(Color(0.12, 0.09, 0.08), 0.0, 0.9)
	var white = u._mat(Color(0.96, 0.95, 0.92), 0.0, 0.6)
	var iris = u._mat(EYE[int(L.eye)], 0.0, 0.4)
	var gold = u._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var gemc: Color = GEM[int(L.gem)]
	var gem = u._mat(gemc, 0.2, 0.3, 0.8)
	_p(u, head, Vector3(0.3, 0.3, 0.3), skin, Vector3(0, 0.16, 0), Vector3.ZERO, true)
	# cheek/jaw shaping
	_p(u, head, Vector3(0.24, 0.07, 0.26), skin, Vector3(0, 0.0, 0.01))
	# eyes: white, coloured iris, dark pupil
	for s in [-1, 1]:
		_p(u, head, Vector3(0.07, 0.045, 0.02), white, Vector3(0.075 * s, 0.185, 0.152))
		_p(u, head, Vector3(0.035, 0.04, 0.02), iris, Vector3(0.075 * s, 0.185, 0.16))
		_p(u, head, Vector3(0.016, 0.02, 0.02), dark, Vector3(0.075 * s, 0.185, 0.168))
		# brows, slightly angry slant
		_p(u, head, Vector3(0.085, 0.02, 0.03), hair, Vector3(0.075 * s, 0.232, 0.158), Vector3(0, 0, -0.18 * s))
		# ears
		_p(u, head, Vector3(0.03, 0.07, 0.05), skin_d, Vector3(0.165 * s, 0.15, 0.0))
	# nose
	_p(u, head, Vector3(0.05, 0.085, 0.06), skin_d, Vector3(0, 0.13, 0.172))
	_p(u, head, Vector3(0.07, 0.03, 0.04), skin_d, Vector3(0, 0.1, 0.168))
	var beard: int = int(L.beard)
	if beard < 2:
		_p(u, head, Vector3(0.09, 0.016, 0.02), u._mat(Color(0.5, 0.2, 0.18), 0.0, 0.8), Vector3(0, 0.05, 0.153))   # mouth
		_p(u, head, Vector3(0.05, 0.02, 0.02), skin_d, Vector3(0, 0.025, 0.152))                                    # lower lip shade
	if beard == 1:
		var st = u._mat(hairc.lerp(skin.albedo_color, 0.55), 0.0, 1.0)
		_p(u, head, Vector3(0.28, 0.1, 0.02), st, Vector3(0, 0.04, 0.151))
		_p(u, head, Vector3(0.04, 0.1, 0.24), st, Vector3(0.151, 0.08, 0.0))
		_p(u, head, Vector3(0.04, 0.1, 0.24), st, Vector3(-0.151, 0.08, 0.0))
	elif beard >= 2:
		_p(u, head, Vector3(0.33, 0.14, 0.12), hair, Vector3(0, 0.05, 0.1))
		_p(u, head, Vector3(0.04, 0.2, 0.3), hair, Vector3(0.16, 0.1, 0.0))
		_p(u, head, Vector3(0.04, 0.2, 0.3), hair, Vector3(-0.16, 0.1, 0.0))
		_p(u, head, Vector3(0.14, 0.035, 0.05), hair, Vector3(0, 0.1, 0.168))                                       # moustache
		_p(u, head, Vector3(0.09, 0.014, 0.02), dark, Vector3(0, 0.07, 0.172))
		_p(u, head, Vector3(0.22, 0.1, 0.06), hair, Vector3(0, -0.03, 0.15))
	if beard == 3:
		_p(u, head, Vector3(0.14, 0.34, 0.06), hair, Vector3(0, -0.2, 0.15))
		_p(u, head, Vector3(0.17, 0.04, 0.08), gold, Vector3(0, -0.28, 0.15))
		_p(u, head, Vector3(0.1, 0.12, 0.05), hair, Vector3(0, -0.43, 0.15))
	if int(L.scar) == 1:
		var sc = u._mat(Color(0.65, 0.25, 0.25), 0.0, 0.8)
		_p(u, head, Vector3(0.025, 0.2, 0.012), sc, Vector3(-0.06, 0.2, 0.162), Vector3(0, 0, 0.35))
	if int(L.patch) == 1:
		_p(u, head, Vector3(0.095, 0.075, 0.03), dark, Vector3(-0.075, 0.185, 0.168))
		_p(u, head, Vector3(0.32, 0.016, 0.32), dark, Vector3(0, 0.215, 0.0), Vector3(0, 0, 0.12))
	# ---- headgear
	var helm: int = int(L.helm)
	var cy := 0.38
	if helm != 0:
		cy = 0.355
	if helm == 0 or helm == 2:
		_p(u, head, Vector3(0.35, 0.22, 0.35), steel, Vector3(0, 0.28, -0.01), Vector3.ZERO, true)
		_p(u, head, Vector3(0.35, 0.16, 0.1), steel, Vector3(0, 0.1, -0.15))
		_p(u, head, Vector3(0.04, 0.16, 0.04), steel_d, Vector3(0, 0.18, 0.18))
		_p(u, head, Vector3(0.05, 0.12, 0.34), glow, Vector3(0, 0.44, -0.01))
		cy = 0.38
	else:
		var h: int = int(L.hair)
		if h >= 1:
			_p(u, head, Vector3(0.33, 0.07, 0.33), hair, Vector3(0, 0.33, 0))
			_p(u, head, Vector3(0.33, 0.2, 0.07), hair, Vector3(0, 0.22, -0.16))
			_p(u, head, Vector3(0.03, 0.1, 0.1), hair, Vector3(0.16, 0.22, 0.06))
			_p(u, head, Vector3(0.03, 0.1, 0.1), hair, Vector3(-0.16, 0.22, 0.06))
			_p(u, head, Vector3(0.3, 0.05, 0.04), hair, Vector3(0, 0.31, 0.15))     # fringe
		if h == 2:
			_p(u, head, Vector3(0.35, 0.6, 0.08), hair, Vector3(0, -0.02, -0.17))
			_p(u, head, Vector3(0.05, 0.45, 0.2), hair, Vector3(0.17, 0.0, -0.05))
			_p(u, head, Vector3(0.05, 0.45, 0.2), hair, Vector3(-0.17, 0.0, -0.05))
		elif h == 3:
			_p(u, head, Vector3(0.1, 0.12, 0.1), hair, Vector3(0, 0.43, -0.05))
			_p(u, head, Vector3(0.12, 0.03, 0.12), gold, Vector3(0, 0.37, -0.05))
		elif h == 4:
			_p(u, head, Vector3(0.07, 0.15, 0.34), hair, Vector3(0, 0.4, 0))
	if helm != 2:
		_crown(u, head, L, cy, gold, gem)


static func _crown(u, head: Node3D, L: Dictionary, cy: float, gold, gem) -> void:
	var style: int = int(L.crown)
	match style:
		0:
			_p(u, head, Vector3(0.38, 0.08, 0.38), gold, Vector3(0, cy, 0))
			for i in 5:
				var a := float(i) / 5.0 * TAU
				_p(u, head, Vector3(0.06, 0.15, 0.06), gold, Vector3(sin(a) * 0.17, cy + 0.12, cos(a) * 0.17))
		1:
			_p(u, head, Vector3(0.38, 0.08, 0.38), gold, Vector3(0, cy, 0))
			for i in 4:
				var a := float(i) / 4.0 * TAU + PI / 4.0
				_p(u, head, Vector3(0.05, 0.09, 0.05), gold, Vector3(sin(a) * 0.18, cy + 0.08, cos(a) * 0.18))
			_p(u, head, Vector3(0.04, 0.04, 0.36), gold, Vector3(0, cy + 0.15, 0))
			_p(u, head, Vector3(0.36, 0.04, 0.04), gold, Vector3(0, cy + 0.15, 0))
			_p(u, head, Vector3(0.09, 0.09, 0.09), gem, Vector3(0, cy + 0.22, 0))
		2:
			var leaf = u._mat(Color(0.35, 0.55, 0.2), 0.0, 0.7)
			_p(u, head, Vector3(0.37, 0.03, 0.37), gold, Vector3(0, cy - 0.02, 0))
			for i in 12:
				var a := float(i) / 12.0 * TAU
				_p(u, head, Vector3(0.05, 0.03, 0.11), leaf, Vector3(sin(a) * 0.19, cy + 0.03, cos(a) * 0.19), Vector3(0.4, a, 0))
		3:
			_p(u, head, Vector3(0.38, 0.08, 0.38), gold, Vector3(0, cy, 0))
			for s in [-1, 1]:
				_p(u, head, Vector3(0.06, 0.2, 0.06), gold, Vector3(0.21 * s, cy + 0.12, 0), Vector3(0, 0, -0.4 * s))
				_p(u, head, Vector3(0.05, 0.16, 0.05), gold, Vector3(0.3 * s, cy + 0.27, 0), Vector3(0, 0, -0.9 * s))
	if style != 2:
		_p(u, head, Vector3(0.06, 0.06, 0.04), gem, Vector3(0, cy + 0.02, 0.2))
	else:
		_p(u, head, Vector3(0.06, 0.06, 0.04), gem, Vector3(0, cy - 0.01, 0.2))


static func pauldron(u, sh: Node3D, side: int, L: Dictionary, steel_mat, gold) -> void:
	var style: int = int(L.pauld)
	if style == 1:
		for i in 3:
			_p(u, sh, Vector3(0.04, 0.15 - i * 0.02, 0.04), steel_mat, Vector3(0.05 * side + (i - 1) * 0.01, 0.15, (i - 1) * 0.07), Vector3(0, 0, -0.3 * side))
	elif style == 2:
		var fur = u._mat(Color(0.92, 0.9, 0.84), 0.0, 1.0)
		_p(u, sh, Vector3(0.26, 0.1, 0.28), fur, Vector3(0, 0.1, 0))
		_p(u, sh, Vector3(0.2, 0.06, 0.22), fur, Vector3(0.0, 0.17, 0))


static func chest(u, torso: Node3D, L: Dictionary) -> void:
	var e: int = int(L.emblem)
	if e == 0:
		return
	var gold = u._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	var red = u._mat(Color(0.8, 0.12, 0.1), 0.0, 0.7)
	match e:
		1:
			_p(u, torso, Vector3(0.05, 0.3, 0.03), gold, Vector3(0, 0.35, 0.2))
			_p(u, torso, Vector3(0.22, 0.05, 0.03), gold, Vector3(0, 0.4, 0.2))
		2:
			_p(u, torso, Vector3(0.14, 0.14, 0.03), gold, Vector3(0, 0.38, 0.2), Vector3(0, 0, PI / 4.0))
			_p(u, torso, Vector3(0.07, 0.07, 0.035), red, Vector3(0, 0.38, 0.205), Vector3(0, 0, PI / 4.0))
		3:
			for i in 5:
				var a := float(i) / 5.0 * TAU
				_p(u, torso, Vector3(0.04, 0.12, 0.03), gold, Vector3(sin(a) * 0.07, 0.38 + cos(a) * 0.07, 0.2), Vector3(0, 0, -a))
			_p(u, torso, Vector3(0.06, 0.06, 0.035), red, Vector3(0, 0.38, 0.205))
