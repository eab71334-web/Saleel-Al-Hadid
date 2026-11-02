extends Node
# Life of the open world: quests, horse, throne, folk and tax, soldiers, houses, raiders,
# alliances (lords + online players) and the united army. Owned by world.gd (world.life).

const WG := preload("res://game/worldgen.gd")
const CK := preload("res://game/castlekit.gd")
const Prog := preload("res://game/worldprog.gd")
const ProfS := preload("res://game/profile.gd")
const Snd := preload("res://game/uisnd.gd")
const LocS := preload("res://game/loc.gd")

const SAVE := "user://world_life.cfg"
const PORTRAIT := "user://throne.png"
const MONTH_DAYS := 5
const FOLK_NAMES := ["Ali", "Musa", "Hassan", "Omar", "Ibrahim", "Yunus", "Salem", "Faraj", "Mabrouk", "Younis", "Aisha", "Fatima", "Mariam", "Khadija", "Zainab", "Salma"]

var world
var stats := {}                 # cumulative counters
var base := {}                  # counters at the moment the current level was reached
var ctx := {}                   # current context action for the HUD button
var ctx_t := 0.0
var last_pos := Vector3.ZERO
var t := 0.0

# horse
var horse: Node3D = null
var horse_legs: Array = []
var horse_state := "garden"     # garden / come / stand
var horse_pos := Vector3.ZERO
var horse_yaw := 0.0
var horse_target := Vector3.ZERO
var horse_wait := 0.0
var call_cd := 0.0

# throne
var throne: Node3D = null
var throne_pos := Vector3.ZERO
var sitting := false
var sit_time := 0.0
var portrait_mat: StandardMaterial3D = null

# folk / tax
var folk: Array = []
var payers: Array = []          # people who pay me monthly {id, name, amt, next}
var dues: Array = []            # what I pay online players monthly {to, name, amt, next}

# soldiers
var soldiers: Array = []        # {node, mode, post, hp, max, cd, tgt, ally, ttl}
var muster_cd := 0.0
var ally_help: Dictionary = {}

# houses
var houses: Array = []          # {x,z,yaw,style,prog,node,sid}

# raiders and the king's fight
var raiders: Array = []
var raid_cd := 90.0
var king_hp := 100.0
var king_max := 100.0
var atk_cd := 0.0
var combat_t := 0.0

# diplomacy
var allies: Array = []          # {id,name,kind,level,until}
var trust := {}                 # lord name -> 0..1
var greeted := {}               # lord name -> day
var diplo_cd := {}
var online_players := {}        # pid -> {name,level,x,z,node,label}
var last_day := 1


func _ready() -> void:
	name = "Life"


# ------------------------------------------------------------------ helpers
func sc() -> float:
	return Prog.scale_of(maxi(world.level, 1))


func gh(x: float, z: float) -> float:
	return maxf(WG.h(x, z, WG.near_sites(x, z, 5.0)), 0.2)


func castle_pos() -> Vector3:
	return Vector3(world.cx, gh(world.cx, world.cz), world.cz)


func T(s: String) -> String:
	return LocS.t(s)


func toast(s: String, secs := 2.6) -> void:
	world.hud.toast(s, secs)


func prog(id: String) -> int:
	return int(stats.get(id, 0)) - int(base.get(id, 0))


func add_stat(id: String, n := 1) -> void:
	stats[id] = int(stats.get(id, 0)) + n


func tasks_done() -> bool:
	for tk in Prog.tasks_for(world.level):
		if prog(String(tk.id)) < int(tk.n):
			return false
	return true


func on_level_up() -> void:
	for k in Prog.TASKS.keys():
		base[k] = int(stats.get(k, 0))
	king_max = 100.0 + float(world.level) * 5.0
	king_hp = king_max
	_place_horse_home()
	_ensure_folk()
	save()


func _person(cloth: Color, steel: bool, weapon: int, hat := false) -> Node3D:
	var s := Node3D.new()
	var skin := CK._m(Color(0.8, 0.6, 0.45), 0.9)
	var cl := CK._m(cloth, 0.8)
	var dk := CK._m(cloth.darkened(0.45), 0.9)
	var st := CK._m(Color(0.62, 0.64, 0.72), 0.4, 0.8)
	CK._b(s, Vector3(0.5, 0.78, 0.3), cl, Vector3(0, 1.17, 0))
	if steel:
		CK._b(s, Vector3(0.52, 0.45, 0.32), st, Vector3(0, 1.3, 0))
		CK._b(s, Vector3(0.36, 0.2, 0.36), st, Vector3(0, 1.9, 0))
	elif hat:
		CK._b(s, Vector3(0.42, 0.12, 0.42), dk, Vector3(0, 1.88, 0))
	CK._b(s, Vector3(0.3, 0.3, 0.3), skin, Vector3(0, 1.72, 0))
	var legs: Array = []
	for i in 2:
		var pv := Node3D.new()
		pv.position = Vector3(-0.13 + 0.26 * float(i), 0.78, 0)
		s.add_child(pv)
		CK._b(pv, Vector3(0.18, 0.78, 0.18), dk, Vector3(0, -0.39, 0))
		legs.append(pv)
	var arm := Node3D.new()
	arm.position = Vector3(0.34, 1.5, 0)
	s.add_child(arm)
	CK._b(arm, Vector3(0.14, 0.6, 0.14), cl, Vector3(0, -0.3, 0))
	if weapon == 1:
		CK._b(arm, Vector3(0.06, 2.2, 0.06), CK._m(Color(0.35, 0.22, 0.12), 0.9), Vector3(0, -0.2, 0.25))
		CK._b(arm, Vector3(0.1, 0.3, 0.1), st, Vector3(0, 0.95, 0.25))
	elif weapon == 2:
		CK._b(arm, Vector3(0.08, 0.9, 0.08), CK._m(Color(0.35, 0.22, 0.12), 0.9), Vector3(0, -0.3, 0.3))
		CK._b(arm, Vector3(0.4, 0.3, 0.07), CK._m(Color(0.3, 0.3, 0.33), 0.5, 0.7), Vector3(0.16, 0.1, 0.3))
	var la := Node3D.new()
	la.position = Vector3(-0.34, 1.5, 0)
	s.add_child(la)
	CK._b(la, Vector3(0.14, 0.6, 0.14), cl, Vector3(0, -0.3, 0))
	s.set_meta("legs", legs)
	s.set_meta("arm", arm)
	s.scale = Vector3.ONE * 1.25
	return s


func _bar(parent: Node3D, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.14)
	m.mesh = q
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mt.albedo_color = Color(0.85, 0.1, 0.1)
	mt.no_depth_test = true
	m.material_override = mt
	m.position = Vector3(0, y, 0)
	parent.add_child(m)
	return m


func _walk(n: Node3D, speed: float, tt: float) -> void:
	var legs: Array = n.get_meta("legs")
	var k := clampf(speed / 3.0, 0.0, 1.0)
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(tt * 9.0 + float(i) * PI) * 0.75 * k
	(n.get_meta("arm") as Node3D).rotation.x = -sin(tt * 9.0) * 0.5 * k


func _face(n: Node3D, dir: Vector3, dt: float) -> void:
	if dir.length() > 0.01:
		n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.z), clampf(dt * 9.0, 0.0, 1.0))


func _step_to(pos: Vector3, tgt: Vector3, sp: float, dt: float) -> Vector3:
	var d := Vector3(tgt.x - pos.x, 0, tgt.z - pos.z)
	var l := d.length()
	if l < 0.05:
		return pos
	var np := pos + d / l * minf(sp * dt, l)
	np.y = gh(np.x, np.z)
	return np


# ------------------------------------------------------------------ save / load
func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	stats = cf.get_value("l", "stats", {})
	base = cf.get_value("l", "base", {})
	trust = cf.get_value("l", "trust", {})
	greeted = cf.get_value("l", "greeted", {})
	payers = cf.get_value("l", "payers", [])
	dues = cf.get_value("l", "dues", [])
	allies = cf.get_value("l", "allies", [])
	houses.clear()
	for h in cf.get_value("l", "houses", []):
		houses.append({"x": float(h[0]), "z": float(h[1]), "yaw": float(h[2]), "style": int(h[3]), "prog": 1.0})
	var sl: Array = cf.get_value("l", "soldiers", [])
	for s in sl:
		_add_soldier(String(s), false)


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("l", "stats", stats)
	cf.set_value("l", "base", base)
	cf.set_value("l", "trust", trust)
	cf.set_value("l", "greeted", greeted)
	cf.set_value("l", "payers", payers)
	cf.set_value("l", "dues", dues)
	cf.set_value("l", "allies", allies)
	var hl: Array = []
	for h in houses:
		hl.append([h.x, h.z, h.yaw, h.style])
	cf.set_value("l", "houses", hl)
	var sl: Array = []
	for s in soldiers:
		if not s.ally:
			sl.append(String(s.mode))
	cf.set_value("l", "soldiers", sl)
	cf.save(SAVE)


func on_play_start() -> void:
	king_max = 100.0 + float(world.level) * 5.0
	king_hp = king_max
	last_pos = world.king_pos
	last_day = world.day
	_place_horse_home()
	_build_all_houses()
	_ensure_folk()
	for s in soldiers:
		if not is_instance_valid(s.node):
			continue
		s.node.position = castle_pos() + Vector3(0, 0, 20.0 * sc())


# ------------------------------------------------------------------ horse
func _build_horse() -> void:
	horse = Node3D.new()
	var coat := CK._m(Color(0.42, 0.26, 0.13), 0.85)
	var dark := CK._m(Color(0.12, 0.08, 0.05), 0.9)
	CK._b(horse, Vector3(0.7, 0.8, 1.7), coat, Vector3(0, 1.25, 0))
	CK._b(horse, Vector3(0.36, 0.9, 0.4), coat, Vector3(0, 1.75, 0.95), Vector3(0.5, 0, 0))
	CK._b(horse, Vector3(0.3, 0.32, 0.6), coat, Vector3(0, 2.15, 1.25))
	CK._b(horse, Vector3(0.12, 0.7, 0.2), dark, Vector3(0, 1.85, 0.75), Vector3(0.5, 0, 0))
	CK._b(horse, Vector3(0.1, 0.12, 0.5), dark, Vector3(0, 1.4, -1.0), Vector3(-0.6, 0, 0))
	CK._b(horse, Vector3(0.66, 0.1, 0.7), CK._m(Color(0.5, 0.12, 0.1), 0.8), Vector3(0, 1.68, -0.05))
	horse_legs.clear()
	var pos := [Vector3(-0.22, 0.95, 0.65), Vector3(0.22, 0.95, 0.65), Vector3(-0.22, 0.95, -0.65), Vector3(0.22, 0.95, -0.65)]
	for p in pos:
		var pv := Node3D.new()
		pv.position = p
		horse.add_child(pv)
		CK._b(pv, Vector3(0.2, 0.95, 0.2), coat, Vector3(0, -0.47, 0))
		CK._b(pv, Vector3(0.22, 0.12, 0.22), dark, Vector3(0, -0.95, 0))
		horse_legs.append(pv)
	world.add_child(horse)


func _place_horse_home() -> void:
	if world.level < 2:
		if horse != null:
			horse.visible = false
		return
	if horse == null:
		_build_horse()
	var cp := castle_pos()
	var home := cp + Vector3(-27.0 * sc(), 0, 23.0 * sc())
	horse_pos = home
	horse_pos.y = gh(home.x, home.z)
	horse_state = "garden"
	horse_target = horse_pos
	horse.visible = not world.mounted


func home_spot() -> Vector3:
	var cp := castle_pos()
	return cp + Vector3(-27.0 * sc(), 0, 23.0 * sc())


func horse_near() -> bool:
	return horse != null and horse.visible and horse_pos.distance_to(world.king_pos) < 4.5


# the HORSE button: mount when it stands next to you, dismount when riding, otherwise whistle for it
func horse_action() -> void:
	if world.level < 2:
		toast(T("Build the stable: castle level 2"))
		return
	if world.mounted:
		dismount()
	elif horse_near():
		mount()
	elif call_cd > 0.0:
		return
	else:
		call_cd = 3.0
		horse_state = "come"
		Snd.play(world, "whoosh", -4.0, 1.5)
		toast(T("You whistle - the horse is coming"))
	world.hud.refresh_buttons()


func mount() -> void:
	if sitting:
		stand_up()
	world.mounted = true
	world.king.set_mounted(true)
	horse.visible = false
	horse_state = "stand"
	Snd.play(world, "click", -4.0, 0.8)


func dismount() -> void:
	world.mounted = false
	world.king.set_mounted(false)
	var side := Vector3(cos(world.king_yaw), 0, -sin(world.king_yaw)) * 2.2
	horse_pos = world.king_pos + side
	horse_pos.y = gh(horse_pos.x, horse_pos.z)
	horse_yaw = world.king_yaw
	horse.visible = true
	horse_state = "stand"
	horse_wait = 0.0


func _tick_horse(dt: float) -> void:
	call_cd = maxf(0.0, call_cd - dt)
	if horse == null or not horse.visible:
		return
	var moving := 0.0
	match horse_state:
		"garden":
			horse_wait -= dt
			if horse_wait <= 0.0:
				horse_wait = randf_range(2.5, 6.0)
				var hs := home_spot()
				horse_target = hs + Vector3(randf_range(-6, 6), 0, randf_range(-5, 5)) * sc() * 0.7
			if horse_pos.distance_to(horse_target) > 0.4:
				var np := _step_to(horse_pos, horse_target, 1.6, dt)
				horse_yaw = lerp_angle(horse_yaw, atan2(np.x - horse_pos.x, np.z - horse_pos.z), clampf(dt * 4.0, 0, 1))
				horse_pos = np
				moving = 1.6
		"come":
			var d := horse_pos.distance_to(world.king_pos)
			if d > 3.0:
				var np2 := _step_to(horse_pos, world.king_pos, 24.0, dt)
				if WG.h(np2.x, np2.z, WG.near_sites(np2.x, np2.z, 5.0)) < -0.5:
					np2 = horse_pos
				horse_yaw = lerp_angle(horse_yaw, atan2(np2.x - horse_pos.x, np2.z - horse_pos.z), clampf(dt * 8.0, 0, 1))
				horse_pos = np2
				moving = 20.0
			else:
				horse_state = "stand"
				toast(T("The horse is here - press MOUNT"))
		"stand":
			pass
	horse.position = horse_pos
	horse.rotation.y = horse_yaw
	for i in horse_legs.size():
		var ph: float = sin(t * (5.0 + moving * 0.35) + float(i) * 1.7 + (PI if i % 2 == 1 else 0.0))
		(horse_legs[i] as Node3D).rotation.x = ph * 0.7 * clampf(moving / 6.0, 0.0, 1.0)
	horse.position.y += absf(sin(t * 9.0)) * 0.04 * clampf(moving / 6.0, 0.0, 1.0)


# ------------------------------------------------------------------ throne
func build_throne(root: Node3D, c_scale: float) -> void:
	throne = Node3D.new()
	throne.position = Vector3(0, 0, 8.0)
	throne.scale = Vector3.ONE / c_scale
	root.add_child(throne)
	var stone := CK._m(Color(0.52, 0.5, 0.48), 0.9)
	var gold := CK._m(Color(0.9, 0.7, 0.25), 0.35, 0.85)
	var wood := CK._m(Color(0.28, 0.12, 0.08), 0.7)
	var red := CK._m(Color(0.55, 0.06, 0.08), 0.85)
	CK._b(throne, Vector3(4.6, 0.3, 4.6) * c_scale * 0.0 + Vector3(4.6, 0.3, 4.6), stone, Vector3(0, 0.15, 0))
	CK._b(throne, Vector3(3.4, 0.3, 3.4), stone, Vector3(0, 0.45, 0))
	CK._b(throne, Vector3(2.0, 0.6, 1.5), red, Vector3(0, 0.9, 0.0))
	CK._b(throne, Vector3(2.0, 0.2, 1.6), gold, Vector3(0, 0.55, 0.0))
	CK._b(throne, Vector3(0.22, 1.0, 1.5), wood, Vector3(-1.1, 1.2, 0))
	CK._b(throne, Vector3(0.22, 1.0, 1.5), wood, Vector3(1.1, 1.2, 0))
	CK._b(throne, Vector3(2.4, 4.4, 0.3), wood, Vector3(0, 2.7, -0.75))
	CK._b(throne, Vector3(2.7, 0.3, 0.45), gold, Vector3(0, 4.95, -0.75))
	for i in 2:
		CK._b(throne, Vector3(0.28, 5.2, 0.4), gold, Vector3(-1.25 + 2.5 * float(i), 2.8, -0.75))
	# portrait frame on the high back (visible above the seated king)
	CK._b(throne, Vector3(1.75, 2.1, 0.12), gold, Vector3(0, 3.65, -0.55))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 1.85)
	q.mesh = qm
	portrait_mat = StandardMaterial3D.new()
	portrait_mat.roughness = 0.9
	portrait_mat.emission_enabled = true
	portrait_mat.emission_energy_multiplier = 0.35
	q.material_override = portrait_mat
	q.position = Vector3(0, 3.65, -0.47)
	throne.add_child(q)
	_apply_portrait()
	throne_pos = root.position + Vector3(0, 0.55, 8.0 * c_scale)
	throne_pos.y = root.position.y + 0.2


func _apply_portrait() -> void:
	if portrait_mat == null:
		return
	var tex: Texture2D = null
	if FileAccess.file_exists(PORTRAIT):
		var img := Image.load_from_file(PORTRAIT)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		portrait_mat.albedo_texture = tex
		portrait_mat.albedo_color = Color.WHITE
		portrait_mat.emission_texture = tex
		portrait_mat.emission = Color.WHITE
	else:
		portrait_mat.albedo_texture = null
		portrait_mat.emission_texture = null
		portrait_mat.albedo_color = Color(0.45, 0.07, 0.09)
		portrait_mat.emission = Color(0.3, 0.04, 0.05)


func set_portrait(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		toast(T("Could not open that picture"))
		return false
	var m := maxi(img.get_width(), img.get_height())
	if m > 640:
		var f := 640.0 / float(m)
		img.resize(int(img.get_width() * f), int(img.get_height() * f), Image.INTERPOLATE_BILINEAR)
	img.save_png(PORTRAIT)
	_apply_portrait()
	toast(T("Portrait hung on your throne"), 3.0)
	return true


func clear_portrait() -> void:
	if FileAccess.file_exists(PORTRAIT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PORTRAIT))
	_apply_portrait()


func sit_down() -> void:
	if world.level < 3 or throne == null:
		return
	if world.mounted:
		dismount()
	sitting = true
	sit_time = 0.0
	world.king_pos = throne_pos
	world.king_yaw = 0.0
	world.king.pose_mode = "sit"
	world.king_pos.y = throne_pos.y
	world.speed = 0.0
	Snd.play(world, "confirm", -10.0, 0.7)


func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	world.king.pose_mode = ""
	world.king_pos = throne_pos + Vector3(0, 0, 3.2)
	world.king.hit_fx = 0


# ------------------------------------------------------------------ folk and tax
func _ensure_folk() -> void:
	var want := 0
	if world.level >= 3:
		want = mini(14, 3 + world.level / 3)
	for h in houses:
		want += 1
	want = mini(want, 40)
	while folk.size() < want:
		var i := folk.size()
		var f := {"id": "f%d" % i, "name": FOLK_NAMES[(i * 7 + 3) % FOLK_NAMES.size()], "cool": 0.0, "mood": 0.6, "away": 0.0, "i": i}
		var rng := RandomNumberGenerator.new()
		rng.seed = 555 + i * 31
		f["wealth"] = rng.randf_range(35.0, 160.0)
		var cp := castle_pos()
		var a := rng.randf() * TAU
		var r: float = (34.0 + rng.randf() * 55.0) * sc()
		if i < houses.size():
			cp = Vector3(houses[i].x, 0, houses[i].z)
			r = 8.0
		f["anchor"] = cp + Vector3(sin(a) * r, 0, cos(a) * r)
		var n := _person(Color.from_hsv(rng.randf(), 0.35, 0.55), false, 0, i % 3 == 0)
		world.add_child(n)
		f["node"] = n
		f["pos"] = f.anchor
		f["tgt"] = f.anchor
		folk.append(f)


func _tick_folk(dt: float) -> void:
	var far := 0
	for f in folk:
		var n: Node3D = f.node
		if f.away > 0.0:
			f.away -= dt
			n.visible = false
			continue
		n.visible = true
		f.cool = maxf(0.0, f.cool - dt)
		var p: Vector3 = f.pos
		if Vector2(p.x - world.king_pos.x, p.z - world.king_pos.z).length() > 420.0:
			n.visible = false
			continue
		if p.distance_to(f.tgt) < 0.6:
			var an: Vector3 = f.anchor
			f.tgt = an + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
			f["idle"] = randf_range(1.0, 5.0)
		var idle: float = f.get("idle", 0.0)
		var sp := 0.0
		if idle > 0.0:
			f["idle"] = idle - dt
		else:
			var np := _step_to(p, f.tgt, 1.5, dt)
			_face(n, np - p, dt)
			f.pos = np
			sp = 1.5
			if WG.h(np.x, np.z, WG.near_sites(np.x, np.z, 5.0)) < 0.5:
				f.tgt = f.anchor
		n.position = f.pos
		_walk(n, sp, t + float(f.i))


func nearest_folk(maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for f in folk:
		if f.away > 0.0 or not (f.node as Node3D).visible:
			continue
		var d: float = (f.pos as Vector3).distance_to(world.king_pos)
		if d < bd:
			bd = d
			best = f
	return best


func tax_amounts() -> Array:
	var k := 1.0 + float(world.level) * 0.12
	return [int(10 * k), int(30 * k), int(80 * k)]


func try_tax(f: Dictionary, mode: String, amount: int) -> void:
	if f.cool > 0.0 and mode == "once":
		_say(f, T("I already paid you today."))
		return
	var wealth: float = f.wealth * (1.0 + float(world.level) * 0.1)
	var ratio: float = float(amount) * (3.0 if mode == "monthly" else 1.0) / wealth
	var loyal: float = clampf(0.4 + float(world.level) * 0.01 + float(houses.size()) * 0.01 + float(f.mood) - 0.6, 0.0, 1.0)
	var p: float = clampf(1.15 - ratio * 1.1 + loyal * 0.25, 0.03, 0.97)
	if randf() < p:
		if mode == "once":
			world.res.gold += amount
			f.cool = 150.0
			_say(f, T("Here is my tax, my lord.") + " +%d" % amount)
		else:
			payers = payers.filter(func(x): return x.id != f.id)
			payers.append({"id": f.id, "name": f.name, "amt": amount, "next": world.day + MONTH_DAYS})
			_say(f, T("I will pay every month, my lord.") + " %d" % amount)
		f.mood = minf(1.0, f.mood + 0.1)
		add_stat("tax")
		Snd.play(world, "confirm", -8.0, 1.4)
	else:
		f.mood = maxf(0.0, f.mood - 0.25)
		if ratio > 1.2:
			_say(f, T("That is far too much! I cannot pay."))
		else:
			_say(f, T("No. I will not pay."))
		if f.mood < 0.1:
			f.away = 180.0
			toast(T("The villager walked away angrily"))
		Snd.play(world, "back", -6.0)


func _say(f: Dictionary, s: String) -> void:
	toast("%s: %s" % [T(String(f.name)), s], 3.4)


func _collect_monthly() -> void:
	for p in payers.duplicate():
		if world.day >= int(p.next):
			var f_ratio: float = float(p.amt) * 3.0 / 120.0
			if f_ratio > 0.55 and randf() < 0.25:
				payers.erase(p)
				toast("%s: %s" % [T(String(p.name)), T("I stop paying tax!")], 3.4)
				continue
			world.res.gold += int(p.amt)
			p.next = world.day + MONTH_DAYS
			toast("%s: +%d %s" % [T(String(p.name)), int(p.amt), T("monthly tax")], 2.4)
	for d in dues.duplicate():
		if world.day >= int(d.next):
			d.next = world.day + MONTH_DAYS
			if world.res.gold >= int(d.amt):
				world.res.gold -= int(d.amt)
				net_send(String(d.to), "pay", {"amount": int(d.amt)})
				toast("%s %d -> %s" % [T("Monthly tax paid"), int(d.amt), String(d.name)], 2.8)
			else:
				toast(T("You could not pay your monthly tax"), 3.0)
	for a in allies.duplicate():
		if int(a.until) > 0 and world.day >= int(a.until):
			allies.erase(a)
			toast("%s - %s" % [String(a.name), T("the treaty has ended")], 4.0)
	# rent from houses
	if houses.size() > 0:
		var rent: int = houses.size() * (3 + world.level / 5)
		world.res.gold += rent
		toast("+%d %s" % [rent, T("rent from your houses")], 2.4)


# ------------------------------------------------------------------ soldiers
func _add_soldier(mode := "garrison", fresh := true, ally_info := {}) -> Dictionary:
	var is_ally := not ally_info.is_empty()
	var col := Color(0.15, 0.3, 0.7) if is_ally else Color(0.72, 0.12, 0.12)
	var n := _person(col, true, 1)
	var mx := 60.0 + float(world.level) * 3.0
	var hpbar := _bar(n, 2.4)
	hpbar.mesh.size = Vector2(0.9, 0.1)
	(hpbar.material_override as StandardMaterial3D).albedo_color = Color(0.2, 0.8, 0.3)
	world.add_child(n)
	var cp := castle_pos()
	n.position = cp + Vector3(randf_range(-4, 4), 0, 18.0 * sc() + randf_range(0, 4))
	if is_ally:
		n.position = world.king_pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	n.position.y = gh(n.position.x, n.position.z)
	var s := {"node": n, "mode": mode, "post": Vector3.ZERO, "hp": mx, "max": mx, "cd": 0.0, "tgt": n.position, "ally": is_ally, "ttl": 360.0, "bar": hpbar, "from": mode, "wait": 0.0}
	soldiers.append(s)
	return s


func soldier_count() -> int:
	var n := 0
	for s in soldiers:
		if not s.ally:
			n += 1
	return n


func recruit() -> void:
	if world.level < 2:
		toast(T("Barracks: castle level 2"))
		return
	if soldier_count() >= Prog.max_soldiers(world.level):
		toast(T("Your barracks are full"))
		return
	if world.res.gold < 40 or world.res.wood < 10:
		toast(T("Not enough resources"))
		return
	world.res.gold -= 40
	world.res.wood -= 10
	_add_soldier("follow")
	add_stat("recruit")
	toast(T("A new soldier joins you"))
	Snd.play(world, "confirm", -8.0)


func set_all_mode(mode: String) -> void:
	for s in soldiers:
		if not s.ally and s.mode != "build":
			s.mode = mode
			s.from = mode


func post_one_here() -> void:
	var best := {}
	var bd := 1e9
	for s in soldiers:
		if s.ally or s.mode == "build":
			continue
		var d: float = (s.node as Node3D).position.distance_to(world.king_pos)
		if d < bd:
			bd = d
			best = s
	if best.is_empty():
		toast(T("You have no soldiers"))
		return
	best.mode = "post"
	best.from = "post"
	best.post = world.king_pos
	toast(T("A soldier stands guard here"))


func _tick_soldiers(dt: float) -> void:
	var idx := 0
	for s in soldiers.duplicate():
		var n: Node3D = s.node
		if s.ally:
			s.ttl -= dt
			if s.ttl <= 0.0:
				n.queue_free()
				soldiers.erase(s)
				continue
		s.cd = maxf(0.0, s.cd - dt)
		var pos: Vector3 = n.position
		var goal := pos
		var sp := 5.0
		# fight when a raider is close
		var foe := {}
		var fd := 16.0 if s.mode != "post" and s.mode != "build" else 6.0
		for r in raiders:
			var d: float = (r.node as Node3D).position.distance_to(pos)
			if d < fd:
				fd = d
				foe = r
		var moved := 0.0
		if not foe.is_empty():
			var fp: Vector3 = (foe.node as Node3D).position
			if fd > 1.9:
				goal = fp
				sp = 7.5
			elif s.cd <= 0.0:
				s.cd = 0.9
				foe.hp -= 8.0 + float(world.level) * 0.6
				n.rotation.x = 0.0
				_hit_fx(fp + Vector3(0, 1.3, 0))
			_face(n, fp - pos, dt)
		else:
			match s.mode:
				"follow":
					var a: float = float(idx) * 0.95 + world.king_yaw
					var ring := 3.2 + float(idx / 7) * 1.8
					var slot: Vector3 = world.king_pos + Vector3(sin(a + PI), 0, cos(a + PI)) * ring
					goal = slot
					sp = clampf(pos.distance_to(slot) * 1.6, 0.0, 15.0 if world.mounted else 9.0)
					if pos.distance_to(world.king_pos) > 90.0:
						n.position = world.king_pos + Vector3(2, 0, 2)
				"post", "build":
					goal = s.post
					sp = 7.0
				_:
					s.wait -= dt
					if s.wait <= 0.0:
						s.wait = randf_range(2.0, 6.0)
						var cp := castle_pos()
						s.tgt = cp + Vector3(randf_range(-11, 11), 0, randf_range(5, 13)) * sc()
					goal = s.tgt
					sp = 2.0
			if pos.distance_to(goal) > 0.8:
				_face(n, goal - pos, dt)
		if pos.distance_to(goal) > 0.8:
			var np := _step_to(pos, goal, sp, dt)
			moved = pos.distance_to(np) / maxf(dt, 0.001)
			n.position = np
		_walk(n, moved, t + float(idx))
		(s.bar as MeshInstance3D).scale.x = clampf(s.hp / s.max, 0.02, 1.0)
		if s.hp <= 0.0:
			toast(T("A soldier has fallen"), 2.4)
			n.queue_free()
			soldiers.erase(s)
		idx += 1


# ------------------------------------------------------------------ houses
func _house_node(h: Dictionary) -> Node3D:
	var r := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h.x * 3.0 + h.z * 7.0)
	var wall: Color = [Color(0.82, 0.74, 0.58), Color(0.7, 0.66, 0.6), Color(0.86, 0.8, 0.7)][int(h.style) % 3]
	var roof: Color = [Color(0.55, 0.18, 0.12), Color(0.3, 0.2, 0.14), Color(0.62, 0.36, 0.14)][(int(h.style) + 1) % 3]
	CK._b(r, Vector3(6.4, 2.6, 5.2), CK._m(Color(0.4, 0.37, 0.34), 0.95), Vector3(0, -0.3, 0))
	CK._b(r, Vector3(6.0, 3.0, 4.8), CK._m(wall, 0.9), Vector3(0, 1.5, 0))
	CK._b(r, Vector3(0.9, 2.0, 0.2), CK._m(Color(0.25, 0.14, 0.08), 0.8), Vector3(0, 1.0, 2.45))
	CK._b(r, Vector3(0.8, 0.8, 0.15), CK._m(Color(0.9, 0.85, 0.5), 0.5, 0.0, 0.7), Vector3(1.8, 1.9, 2.42))
	var rm := PrismMesh.new()
	rm.size = Vector3(7.0, 2.4, 5.6)
	var mi := MeshInstance3D.new()
	mi.mesh = rm
	mi.material_override = CK._m(roof, 0.85)
	mi.position = Vector3(0, 4.2, 0)
	r.add_child(mi)
	CK._b(r, Vector3(0.7, 1.9, 0.7), CK._m(Color(0.45, 0.42, 0.4), 0.95), Vector3(1.9, 5.0, -1.0))
	return r


func _build_all_houses() -> void:
	for h in houses:
		if not h.has("node") or not is_instance_valid(h.node):
			var n := _house_node(h)
			n.position = Vector3(h.x, gh(h.x, h.z), h.z)
			n.rotation.y = h.yaw
			world.add_child(n)
			h["node"] = n


func can_build_here() -> String:
	var p: Vector3 = world.king_pos
	if world.level < 4:
		return T("Houses: castle level 4")
	if houses.size() >= Prog.max_houses(world.level):
		return T("You have built the most houses your castle allows")
	var d := Vector2(p.x - world.cx, p.z - world.cz).length()
	if d < 38.0 * sc():
		return T("Build outside the castle walls")
	if d > 700.0:
		return T("Too far from your castle")
	if WG.h0(p.x, p.z) < 2.5 or WG.slope(p.x, p.z) > 0.32:
		return T("The ground is not suitable here")
	for h in houses:
		if Vector2(p.x - h.x, p.z - h.z).length() < 14.0:
			return T("Too close to another house")
	for c in world.castles:
		if c.owner != "you" and Vector2(p.x - float(c.x), p.z - float(c.z)).length() < 150.0:
			return T("Too close to another castle")
	return ""


func build_house() -> void:
	var e := can_build_here()
	if e != "":
		toast(e)
		return
	# a soldier must be standing at the build spot
	var guard := {}
	var bd := 16.0
	for s in soldiers:
		if s.ally or s.mode == "build":
			continue
		var d: float = (s.node as Node3D).position.distance_to(world.king_pos)
		if d < bd:
			bd = d
			guard = s
	if guard.is_empty():
		toast(T("A soldier must stand guard at the building site: bring one close"), 4.0)
		return
	if world.res.gold < 30 or world.res.wood < 40 or world.res.stone < 20:
		toast(T("Not enough resources") + " (30 / 40 / 20)")
		return
	world.res.gold -= 30
	world.res.wood -= 40
	world.res.stone -= 20
	var h := {"x": world.king_pos.x + sin(world.king_yaw) * 5.0, "z": world.king_pos.z + cos(world.king_yaw) * 5.0, "yaw": world.king_yaw + PI, "style": randi() % 3, "prog": 0.0}
	var n := _house_node(h)
	n.position = Vector3(h.x, gh(h.x, h.z), h.z)
	n.rotation.y = h.yaw
	n.scale = Vector3(1, 0.05, 1)
	world.add_child(n)
	h["node"] = n
	houses.append(h)
	guard.from = guard.mode
	guard.mode = "build"
	guard.post = Vector3(h.x + sin(h.yaw) * 5.0, 0, h.z + cos(h.yaw) * 5.0)
	h["sid"] = guard
	world._dust_at(Vector3(h.x, n.position.y, h.z), 4.0)
	toast(T("Construction started - the soldier guards the site"), 3.5)
	Snd.play(world, "confirm", -6.0)


func _tick_houses(dt: float) -> void:
	for h in houses:
		if h.prog < 1.0 and h.has("node"):
			h.prog = minf(1.0, h.prog + dt / 18.0)
			(h.node as Node3D).scale = Vector3(1, maxf(0.05, h.prog), 1)
			if h.prog >= 1.0:
				add_stat("houses")
				toast(T("Your house is finished - the soldier may go"), 3.5)
				Snd.play(world, "confirm", -4.0, 1.2)
				var g: Dictionary = h.get("sid", {})
				if not g.is_empty():
					g.mode = g.from if g.from != "build" else "follow"
				h.erase("sid")
				_ensure_folk()


# ------------------------------------------------------------------ raiders and the king's fight
func _hit_fx(p: Vector3) -> void:
	world.stub._burst(p, Color(0.8, 0.1, 0.1), 7, 2.5, false)


func _spawn_raiders(center: Vector3, n: int, target_pos: Vector3, tag := "") -> void:
	for i in n:
		var pos := center
		for tries in 8:
			var a := randf() * TAU
			pos = center + Vector3(sin(a), 0, cos(a)) * randf_range(120.0, 170.0)
			if WG.h0(pos.x, pos.z) > 2.0:
				break
		pos.y = gh(pos.x, pos.z)
		var nd := _person(Color(0.15, 0.13, 0.13), true, 2)
		nd.position = pos
		world.add_child(nd)
		var mx := 30.0 + float(world.level) * 2.0
		var hb := _bar(nd, 2.4)
		hb.mesh.size = Vector2(0.9, 0.1)
		raiders.append({"node": nd, "hp": mx, "max": mx, "cd": 0.0, "goal": target_pos, "bar": hb, "tag": tag, "flee": false})


func start_raid() -> void:
	var n := mini(16, 2 + world.level / 5)
	var cp := castle_pos()
	_spawn_raiders(cp, n, cp + Vector3(0, 0, 18.0 * sc()))
	toast(T("Raiders approach your castle! Defend it!"), 4.5)
	Snd.play(world, "whoosh", -2.0, 0.6)


func king_attack() -> void:
	if world.state != "play" or sitting or atk_cd > 0.0 or world.king_dead:
		return
	atk_cd = 0.75
	# turn toward the nearest raider in reach
	var near := {}
	var bd := 7.0
	for r in raiders:
		var d: float = (r.node as Node3D).position.distance_to(world.king_pos)
		if d < bd:
			bd = d
			near = r
	if not near.is_empty():
		var dv: Vector3 = (near.node as Node3D).position - world.king_pos
		world.king_yaw = atan2(dv.x, dv.z)
	world.king.swing = 1.0
	Snd.play(world, "click", -2.0, 0.6)
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(world.king):
		return
	var fw := Vector3(sin(world.king_yaw), 0, cos(world.king_yaw))
	for r in raiders:
		var dv2: Vector3 = (r.node as Node3D).position - world.king_pos
		dv2.y = 0
		if dv2.length() < 3.8 and dv2.normalized().dot(fw) > -0.2:
			r.hp -= 20.0 + float(world.level) * 1.6
			_hit_fx((r.node as Node3D).position + Vector3(0, 1.3, 0))
			Snd.play(world, "hover", -2.0, 0.7)
	combat_t = 6.0


func _tick_raiders(dt: float) -> void:
	atk_cd = maxf(0.0, atk_cd - dt)
	combat_t = maxf(0.0, combat_t - dt)
	if world.king.swing > 0.0:
		world.king.swing = maxf(0.0, world.king.swing - dt * 1.9)
	var cp := castle_pos()
	# schedule
	if world.level >= 5 and raiders.is_empty() and ally_help.is_empty():
		raid_cd -= dt
		if raid_cd <= 0.0:
			raid_cd = randf_range(130.0, 210.0)
			start_raid()
	for r in raiders.duplicate():
		var n: Node3D = r.node
		r.cd = maxf(0.0, r.cd - dt)
		var pos: Vector3 = n.position
		var goal: Vector3 = r.goal
		var sp := 4.6
		var kd := pos.distance_to(world.king_pos)
		var target_king: bool = not r.flee and kd < 24.0 and not world.king_dead
		var foe_sol := {}
		var sd := 14.0
		if not r.flee:
			for s in soldiers:
				var d: float = (s.node as Node3D).position.distance_to(pos)
				if d < sd:
					sd = d
					foe_sol = s
		if r.flee:
			goal = pos + (pos - cp).normalized() * 60.0
			sp = 6.5
		elif target_king:
			goal = world.king_pos
		elif not foe_sol.is_empty():
			goal = (foe_sol.node as Node3D).position
		var gd := pos.distance_to(goal)
		if gd > 1.7:
			var np := _step_to(pos, goal, sp, dt)
			_face(n, np - pos, dt)
			n.position = np
			_walk(n, sp, t + float(raiders.find(r)))
		elif r.cd <= 0.0 and not r.flee:
			r.cd = 1.2
			var dmg := 4.0 + float(world.level) * 0.35
			if target_king:
				world.damage_king(dmg)
			elif not foe_sol.is_empty():
				foe_sol.hp -= dmg
			else:
				# reached the gate: steal and run
				var loot := mini(int(world.res.gold), 20 + int(world.res.gold * 0.05))
				if String(r.tag) == "":
					world.res.gold -= loot
					toast(T("Raiders stole gold from your treasury") + " -%d" % loot, 3.0)
				r.flee = true
		(r.bar as MeshInstance3D).scale.x = clampf(r.hp / r.max, 0.02, 1.0)
		if r.hp <= 0.0 or (r.flee and pos.distance_to(cp) > 200.0):
			if r.hp <= 0.0:
				add_stat("kills")
				var rw: int = 6 + world.level
				world.res.gold += rw
				toast("+%d %s" % [rw, T("Gold")], 1.6)
			n.queue_free()
			raiders.erase(r)
	if raiders.is_empty() and combat_t <= 0.0 and king_hp < king_max:
		king_hp = minf(king_max, king_hp + dt * 3.0)


# ------------------------------------------------------------------ diplomacy
func is_ally(name_: String) -> bool:
	for a in allies:
		if String(a.name) == name_:
			return true
	return false


func lord_near(maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for c in world.castles:
		if c.owner != "ai":
			continue
		var d := Vector2(world.king_pos.x - float(c.x), world.king_pos.z - float(c.z)).length() - 20.0 * Prog.scale_of(int(c.level))
		if d < bd:
			bd = d
			best = c
	return best


func greet(c: Dictionary) -> void:
	var nm: String = c.name
	if int(greeted.get(nm, -9)) == world.day:
		toast(T("You already greeted this lord today"))
		return
	greeted[nm] = world.day
	trust[nm] = minf(1.0, float(trust.get(nm, 0.0)) + 0.06)
	add_stat("visit")
	toast("%s %s" % [T("You greet"), nm], 2.6)


func gift(c: Dictionary, gold: int) -> void:
	if world.res.gold < gold:
		toast(T("Not enough resources"))
		return
	world.res.gold -= gold
	trust[c.name] = minf(1.0, float(trust.get(c.name, 0.0)) + float(gold) / 600.0)
	toast("%s %s +%d" % [nm_of(c), T("is pleased with your gift"), gold], 3.0)


func nm_of(c: Dictionary) -> String:
	return String(c.name)


func propose_ai(c: Dictionary, days: int) -> void:
	var nm: String = c.name
	if float(diplo_cd.get(nm, 0.0)) > t:
		toast(T("Wait before asking again"))
		return
	diplo_cd[nm] = t + 60.0
	var p: float = 0.3 + 0.035 * float(world.level - int(c.level)) + float(trust.get(nm, 0.0)) * 0.6
	if days == 0:
		p *= 0.6
	p = clampf(p, 0.05, 0.95)
	if randf() < p:
		allies = allies.filter(func(a): return String(a.name) != nm)
		allies.append({"id": nm, "name": nm, "kind": "ai", "level": int(c.level), "until": 0 if days == 0 else world.day + days})
		add_stat("ally")
		toast("%s %s" % [nm, T("accepts the alliance!")], 4.0)
		Snd.play(world, "confirm", -2.0, 1.2)
	else:
		toast("%s %s" % [nm, T("refuses your offer")], 3.4)
		Snd.play(world, "back", -6.0)


func break_ally(a: Dictionary) -> void:
	allies.erase(a)
	if String(a.kind) == "online":
		net_send(String(a.id), "break", {})
	toast("%s: %s" % [String(a.name), T("alliance broken")])


func muster() -> void:
	if world.level < 8:
		toast(T("Muster allies: castle level 8"))
		return
	if allies.is_empty():
		toast(T("You have no allies"))
		return
	if muster_cd > 0.0:
		toast("%s %d s" % [T("The army needs time to gather"), int(muster_cd)])
		return
	muster_cd = 240.0
	var total := 0
	for a in allies:
		var n := Prog.muster_n(int(a.level))
		for i in n:
			_add_soldier("follow", true, a)
			total += 1
		if String(a.kind) == "online":
			net_send(String(a.id), "muster", {"x": world.king_pos.x, "z": world.king_pos.z})
	toast("%s: %d" % [T("Your allies send soldiers"), total], 4.0)
	Snd.play(world, "whoosh", -2.0, 0.8)


func _ally_event_tick(dt: float) -> void:
	if world.level < 10:
		return
	if ally_help.is_empty():
		var ai: Array = allies.filter(func(a): return String(a.kind) == "ai")
		if ai.is_empty():
			return
		if randf() < dt / 420.0:
			var a: Dictionary = ai[randi() % ai.size()]
			for c in world.castles:
				if c.owner == "ai" and String(c.name) == String(a.name):
					ally_help = {"name": a.name, "x": float(c.x), "z": float(c.z), "t": 300.0, "spawned": false, "level": int(c.level)}
					world.hud.waypoint = Vector2(float(c.x), float(c.z))
					toast("%s %s!" % [String(a.name), T("is under attack - go and help")], 6.0)
					Snd.play(world, "whoosh", -2.0, 0.6)
		return
	ally_help.t -= dt
	var cpos := Vector3(ally_help.x, 0, ally_help.z)
	if not ally_help.spawned and Vector2(world.king_pos.x - ally_help.x, world.king_pos.z - ally_help.z).length() < 260.0:
		ally_help.spawned = true
		var scl := Prog.scale_of(int(ally_help.level))
		_spawn_raiders(cpos, 3 + int(ally_help.level) / 4, cpos + Vector3(0, 0, 18.0 * scl), "ally")
	if ally_help.spawned and raiders.is_empty():
		var rw := 120 + int(ally_help.level) * 15
		world.res.gold += rw
		trust[ally_help.name] = minf(1.0, float(trust.get(ally_help.name, 0.0)) + 0.25)
		toast("%s %s +%d" % [String(ally_help.name), T("thanks you for defending the castle"), rw], 5.0)
		ally_help = {}
		world.hud.waypoint = Vector2(1e9, 1e9)
	elif ally_help.t <= 0.0:
		toast("%s %s" % [String(ally_help.name), T("was raided - you came too late")], 5.0)
		for r in raiders:
			if String(r.tag) == "ally":
				(r.node as Node3D).queue_free()
		raiders = raiders.filter(func(r): return String(r.tag) != "ally")
		trust[ally_help.name] = maxf(0.0, float(trust.get(ally_help.name, 0.0)) - 0.15)
		ally_help = {}
		world.hud.waypoint = Vector2(1e9, 1e9)


# ------------------------------------------------------------------ online players (mailbox)
func bk():
	return world._backend()


func net_send(to: String, type: String, data: Dictionary) -> void:
	var b = bk()
	if b == null or b.base_url == "":
		return
	b._http_post("/api/world/send", {"from": b.player_id, "to": to, "type": type, "data": data}, func(_c, _d): pass)


func update_online(e: Dictionary) -> void:
	var pid := String(e.player_id)
	var o: Dictionary = online_players.get(pid, {})
	var px: float = float(e.get("px", e.get("x", 0.0)))
	var pz: float = float(e.get("pz", e.get("z", 0.0)))
	if o.is_empty():
		var n := _person(Color(0.15, 0.4, 0.75), true, 1)
		var lb := Label3D.new()
		lb.font_size = 40
		lb.outline_size = 10
		lb.pixel_size = 0.01
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.modulate = Color(0.6, 0.85, 1.0)
		lb.position = Vector3(0, 2.9, 0)
		n.add_child(lb)
		n.position = Vector3(px, gh(px, pz), pz)
		world.add_child(n)
		o = {"node": n, "label": lb, "x": px, "z": pz, "name": "", "level": 1, "pid": pid}
		online_players[pid] = o
	o.x = px
	o.z = pz
	o.name = String(e.get("name", "Player"))
	o.level = int(e.get("level", 1))
	(o.label as Label3D).text = "%s  Lv %d" % [o.name, o.level]
	for a in allies:
		if String(a.id) == pid:
			a.level = o.level


func prune_online(seen: Dictionary) -> void:
	for pid in online_players.keys():
		if not seen.has(pid):
			(online_players[pid].node as Node3D).queue_free()
			online_players.erase(pid)


func player_near(maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for pid in online_players.keys():
		var o: Dictionary = online_players[pid]
		var d := Vector2(world.king_pos.x - float(o.x), world.king_pos.z - float(o.z)).length()
		if d < bd:
			bd = d
			best = o
	return best


func offer_tax_player(o: Dictionary, mode: String, amount: int) -> void:
	net_send(String(o.pid), "tax_offer", {"mode": mode, "amount": amount})
	toast("%s %s" % [T("Offer sent to"), String(o.name)], 3.0)


func offer_ally_player(o: Dictionary, days: int) -> void:
	net_send(String(o.pid), "ally_offer", {"days": days, "level": world.level})
	toast("%s %s" % [T("Offer sent to"), String(o.name)], 3.0)


func on_msgs(msgs: Array) -> void:
	for m in msgs:
		if not (m is Dictionary):
			continue
		var from := String(m.get("from", ""))
		var fname := String(m.get("from_name", "Player"))
		var d: Dictionary = m.get("data", {}) if m.get("data") is Dictionary else {}
		match String(m.get("type", "")):
			"tax_offer":
				_incoming_tax(from, fname, String(d.get("mode", "once")), int(d.get("amount", 0)))
			"ally_offer":
				_incoming_ally(from, fname, int(d.get("days", 0)), int(d.get("level", 1)))
			"pay":
				var amt := int(d.get("amount", 0))
				world.res.gold += amt
				toast("%s: +%d %s" % [fname, amt, T("monthly tax")], 3.0)
			"reply":
				_incoming_reply(from, fname, d)
			"break":
				allies = allies.filter(func(a): return String(a.id) != from)
				toast("%s: %s" % [fname, T("alliance broken")], 3.5)
			"muster":
				world.hud.waypoint = Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
				toast("%s %s" % [fname, T("calls the allied army - see the map")], 6.0)


func _incoming_tax(from: String, fname: String, mode: String, amount: int) -> void:
	var lines: Array = ["%s %s %d %s" % [fname, T("asks you to pay"), amount, T("Gold")], T("Monthly (every 5 days)") if mode == "monthly" else T("One-time payment")]
	world.hud.dialog(T("Tax offer"), lines, [
		[T("Pay"), "coin", func():
			if world.res.gold < amount:
				toast(T("Not enough resources"))
				net_send(from, "reply", {"kind": "tax", "ok": false, "mode": mode, "amount": amount})
				return
			if mode == "once":
				world.res.gold -= amount
				net_send(from, "pay", {"amount": amount})
			else:
				dues.append({"to": from, "name": fname, "amt": amount, "next": world.day + MONTH_DAYS})
			net_send(from, "reply", {"kind": "tax", "ok": true, "mode": mode, "amount": amount})
			toast(T("You agreed to pay"), 2.5)],
		[T("Refuse"), "shield", func():
			net_send(from, "reply", {"kind": "tax", "ok": false, "mode": mode, "amount": amount})],
	], 2)


func _incoming_ally(from: String, fname: String, days: int, lvl: int) -> void:
	var lines: Array = ["%s (%s %d) %s" % [fname, T("Level"), lvl, T("proposes an alliance")], T("Permanent pact") if days == 0 else "%d %s" % [days, T("days")]]
	world.hud.dialog(T("Alliance offer"), lines, [
		[T("Accept"), "flag", func():
			allies = allies.filter(func(a): return String(a.id) != from)
			allies.append({"id": from, "name": fname, "kind": "online", "level": lvl, "until": 0 if days == 0 else world.day + days})
			add_stat("ally")
			net_send(from, "reply", {"kind": "ally", "ok": true, "days": days, "level": world.level})
			toast("%s: %s" % [fname, T("alliance sealed")], 3.5)],
		[T("Refuse"), "shield", func():
			net_send(from, "reply", {"kind": "ally", "ok": false, "days": days})],
	], 2)


func _incoming_reply(from: String, fname: String, d: Dictionary) -> void:
	var ok := bool(d.get("ok", false))
	match String(d.get("kind", "")):
		"tax":
			if ok:
				add_stat("tax")
				if String(d.get("mode", "once")) == "monthly":
					toast("%s %s" % [fname, T("agreed to pay you every month")], 4.0)
				else:
					toast("%s %s" % [fname, T("paid your tax")], 3.0)
			else:
				toast("%s %s" % [fname, T("refused to pay")], 3.0)
		"ally":
			if ok:
				var days := int(d.get("days", 0))
				allies = allies.filter(func(a): return String(a.id) != from)
				allies.append({"id": from, "name": fname, "kind": "online", "level": int(d.get("level", 1)), "until": 0 if days == 0 else world.day + days})
				add_stat("ally")
				toast("%s: %s" % [fname, T("alliance sealed")], 4.0)
				Snd.play(world, "confirm", -2.0, 1.2)
			else:
				toast("%s %s" % [fname, T("refused your alliance")], 3.5)


# ------------------------------------------------------------------ context button and per-frame
func _compute_ctx() -> void:
	ctx = {}
	if world.state != "play" or world.king_dead:
		return
	if sitting:
		ctx = {"text": T("STAND"), "icon": "level", "fn": func(): stand_up()}
		return
	if world.level >= 3 and throne != null and world.king_pos.distance_to(throne_pos) < 7.0:
		ctx = {"text": T("SIT"), "icon": "city", "fn": func(): sit_down()}
		return
	var pl := player_near(110.0) if world.level >= 3 else {}
	if not pl.is_empty():
		ctx = {"text": "%s" % String(pl.name), "icon": "talk", "fn": func(): open_player(pl)}
		return
	var f := nearest_folk(5.5) if world.level >= 3 else {}
	if not f.is_empty():
		ctx = {"text": T("TAX"), "icon": "coin", "fn": func(): open_tax(f)}
		return
	var lord := lord_near(60.0) if world.level >= 6 else {}
	if not lord.is_empty():
		ctx = {"text": T("LORD"), "icon": "advisor", "fn": func(): open_lord(lord)}
		return


func tick(dt: float) -> void:
	t += dt
	# distance walked / ridden
	var mv := Vector2(world.king_pos.x - last_pos.x, world.king_pos.z - last_pos.z).length()
	last_pos = world.king_pos
	if mv < 30.0 and not sitting:
		stats["_walkacc"] = float(stats.get("_walkacc", 0.0)) + mv
		var whole := int(stats["_walkacc"])
		if whole > 0:
			stats["_walkacc"] = float(stats["_walkacc"]) - whole
			add_stat("ride" if world.mounted else "walk", whole)
	if sitting:
		sit_time += dt
		if sit_time > 3.0 and int(stats.get("_sat", 0)) != world.day:
			stats["_sat"] = world.day
			add_stat("sit")
			toast(T("You rule from your throne"), 2.4)
		if world.move_vec.length() > 0.4:
			stand_up()
	muster_cd = maxf(0.0, muster_cd - dt)
	_tick_horse(dt)
	_tick_folk(dt)
	_tick_soldiers(dt)
	_tick_houses(dt)
	_tick_raiders(dt)
	_ally_event_tick(dt)
	if world.day != last_day:
		last_day = world.day
		_collect_monthly()
	for pid in online_players.keys():
		var o: Dictionary = online_players[pid]
		var n: Node3D = o.node
		var tp := Vector3(float(o.x), 0, float(o.z))
		var np := _step_to(n.position, tp, maxf(6.0, n.position.distance_to(tp) * 1.2), dt)
		_face(n, np - n.position, dt)
		var sp: float = n.position.distance_to(np) / maxf(dt, 0.001)
		n.position = np
		_walk(n, sp, t)
	ctx_t -= dt
	if ctx_t <= 0.0:
		ctx_t = 0.2
		_compute_ctx()
	# the HUD may be rebuilt: refresh minimap list lazily
	if world.king_dead:
		pass


func minimap_points() -> Array:
	var out: Array = []
	for r in raiders:
		out.append([(r.node as Node3D).position.x, (r.node as Node3D).position.z, Color(1, 0.15, 0.15)])
	for pid in online_players.keys():
		out.append([float(online_players[pid].x), float(online_players[pid].z), Color(0.4, 0.8, 1.0)])
	if not horse == null and horse.visible and horse_state != "garden":
		out.append([horse_pos.x, horse_pos.z, Color(0.8, 0.55, 0.25)])
	return out


# ------------------------------------------------------------------ dialogs
func open_tax(f: Dictionary) -> void:
	var a := tax_amounts()
	var lines: Array = ["%s: %s" % [T("Villager"), T(String(f.name))], T("Offer a tax. He decides whether to pay or refuse.")]
	var already := false
	for p in payers:
		if p.id == f.id:
			already = true
			lines.append("%s %d %s" % [T("He already pays"), int(p.amt), T("monthly")])
	var btns: Array = []
	for amt in a:
		btns.append(["%s %d" % [T("Once"), amt], "coin", func(): try_tax(f, "once", amt), true])
	for amt in a:
		btns.append(["%s %d" % [T("Monthly"), int(amt / 2)], "coin", func(): try_tax(f, "monthly", int(amt / 2)), true])
	btns.append([T("Close"), "gear", func(): pass])
	world.hud.dialog(T("Collect tax"), lines, btns, 3, func(): if f.away <= 0.0: open_tax(f))


func open_lord(c: Dictionary) -> void:
	var nm: String = c.name
	var al := is_ally(nm)
	var lines: Array = ["%s - %s %d" % [nm, T("Level"), int(c.level)], "%s: %d%%" % [T("Trust"), int(float(trust.get(nm, 0.0)) * 100.0)]]
	if al:
		lines.append(T("He is your ally."))
	var btns: Array = []
	btns.append([T("Greet the lord"), "advisor", func(): greet(c), true])
	btns.append(["%s 100" % T("Gift"), "coin", func(): gift(c, 100), true])
	if not al:
		btns.append(["5 %s" % T("days"), "flag", func(): propose_ai(c, 5), true])
		btns.append(["20 %s" % T("days"), "flag", func(): propose_ai(c, 20), true])
		btns.append([T("Permanent pact"), "flag", func(): propose_ai(c, 0), true])
	else:
		for a in allies:
			if String(a.name) == nm:
				btns.append([T("Break alliance"), "foe", func(): break_ally(a)])
	btns.append([T("Close"), "gear", func(): pass])
	world.hud.dialog(T("Diplomacy"), lines, btns, 3, func(): open_lord(c))


func open_player(o: Dictionary) -> void:
	var a := tax_amounts()
	var lines: Array = ["%s - %s %d" % [String(o.name), T("Level"), int(o.level)], T("A real player is nearby. Offers are sent to him and he chooses to accept or refuse.")]
	var btns: Array = []
	for amt in a:
		btns.append(["%s %d" % [T("Once"), amt], "coin", func(): offer_tax_player(o, "once", amt)])
	for amt in a:
		btns.append(["%s %d" % [T("Monthly"), int(amt / 2)], "coin", func(): offer_tax_player(o, "monthly", int(amt / 2))])
	if world.level >= 6:
		btns.append(["5 %s" % T("days"), "flag", func(): offer_ally_player(o, 5)])
		btns.append(["20 %s" % T("days"), "flag", func(): offer_ally_player(o, 20)])
		btns.append([T("Permanent pact"), "flag", func(): offer_ally_player(o, 0)])
	btns.append([T("Close"), "gear", func(): pass])
	world.hud.dialog(T("Player"), lines, btns, 3)


func open_realm() -> void:
	var lv: int = world.level
	var lines: Array = []
	lines.append("%s %d / %d   -   %s %d / %d   -   %s %d" % [T("Soldiers"), soldier_count(), Prog.max_soldiers(lv), T("Houses"), houses.size(), Prog.max_houses(lv), T("Allies"), allies.size()])
	for a in allies:
		lines.append("   %s (%s %d) - %s" % [String(a.name), T("Level"), int(a.level), T("Permanent pact") if int(a.until) == 0 else "%s %d" % [T("until day"), int(a.until)]])
	var income := payers.size()
	lines.append("%s: %d    %s: %d" % [T("Monthly payers"), income, T("Raiders now"), raiders.size()])
	var btns: Array = []
	btns.append([T("Quests and upgrade"), "level", func(): world.hud.open_castle()])
	btns.append([T("Recruit soldier") + " (40/10)", "army", func(): recruit(), true])
	btns.append([T("Soldiers follow me"), "boot", func(): set_all_mode("follow"); toast(T("Soldiers follow you")), true])
	btns.append([T("Soldiers hold the castle"), "shield", func(): set_all_mode("garrison"); toast(T("Soldiers hold the castle")), true])
	btns.append([T("Post a soldier here"), "flag", func(): post_one_here(), true])
	btns.append([T("Build a house here") + " (30/40/20)", "hammer", func(): build_house(), true])
	btns.append([T("Muster allies"), "army", func(): muster(), true])
	btns.append([T("Hang a portrait on the throne"), "heart", func(): pick_portrait()])
	if FileAccess.file_exists(PORTRAIT):
		btns.append([T("Remove portrait"), "foe", func(): clear_portrait(), true])
	btns.append([T("Close"), "gear", func(): pass])
	world.hud.dialog(T("Your Realm"), lines, btns, 2, func(): open_realm())


func pick_portrait() -> void:
	if world.level < 3:
		toast(T("Your throne: castle level 3"))
		return
	world.hud.pick_image(func(path): set_portrait(path))
