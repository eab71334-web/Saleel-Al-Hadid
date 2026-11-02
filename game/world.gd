extends Node3D
# OPEN WORLD (beta): an 8 km x 8 km island world. You choose where your castle stands; it starts at
# level 1 and grows with every upgrade. Walk or ride, gather resources, meet lords. Castles of other
# players (when a world server is reachable) are shown too.

const WG := preload("res://game/worldgen.gd")
const CK := preload("res://game/castlekit.gd")
const KL := preload("res://game/kinglook.gd")
const UnitS := preload("res://game/unit.gd")
const RigS := preload("res://game/rig.gd")
const ProfS := preload("res://game/profile.gd")
const Snd := preload("res://game/uisnd.gd")
const LocS := preload("res://game/loc.gd")
const HudS := preload("res://game/worldhud.gd")

const SAVE := "user://world.cfg"
const Prog := preload("res://game/worldprog.gd")
const LifeS := preload("res://game/worldlife.gd")
const CHUNK_R := 6

class Stub extends Node:
	var HORSE_RIDING := false
	var my_id := 1
	var running := false
	var over := false
	var winner_team := -1
	var sfx := SfxStub.new()
	func team_col(_t: int) -> Color:
		return Color(0.72, 0.12, 0.12)
	func _burst(p: Vector3, col: Color, n: int, spd: float, _up: bool) -> void:
		var w := get_parent()
		if w == null:
			return
		var ps := CPUParticles3D.new()
		ps.position = p
		ps.amount = n
		ps.lifetime = 0.5
		ps.one_shot = true
		ps.explosiveness = 1.0
		ps.direction = Vector3(0, 1, 0)
		ps.spread = 160.0
		ps.initial_velocity_min = spd * 0.5
		ps.initial_velocity_max = spd
		ps.gravity = Vector3(0, -9, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 4
		sm.rings = 2
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = col
		sm.material = mt
		ps.mesh = sm
		w.add_child(ps)
		ps.emitting = true
		get_tree().create_timer(1.2).timeout.connect(ps.queue_free)

class SfxStub extends RefCounted:
	func play(_a = null, _b = null, _c = null, _d = null) -> void:
		pass
	func play_ui(_a = null, _b = null) -> void:
		pass

var main                                   # Main node (back_to_menu)
var stub := Stub.new()
var hud: Control
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var water: MeshInstance3D
var king
var king_pos := Vector3.ZERO
var king_yaw := 0.0
var speed := 0.0
var mounted := false
var cam_yaw := 0.0
var cam_pitch := 0.38
var cam_dist := 10.0
var cam_dist_t := 10.0
var state := "load"            # load / pick / found / play
var found_t := 0.0
var chunks := {}               # Vector2i -> Node3D
var pending: Array = []
var chunk_t := 0.0
var castles: Array = []        # {name,x,z,level,banner,emblem,owner,node,label}
var caches: Array = []         # {pos,type,node,taken}
var guards: Array = []
var tod := 9.0                 # time of day (hours)
var day := 1
var t_all := 0.0
var res := {"gold": 60, "wood": 40, "stone": 20}
var level := 0                 # 0 = no castle yet
var cx := 0.0
var cz := 0.0
var last_unix := 0
var save_t := 0.0
var income_acc := [0.0, 0.0, 0.0]
var home_cd := 0.0
var net_t := 6.0
var online_state := "offline"  # offline / online
var online_count := 0
var move_vec := Vector2.ZERO
var own_castle: Dictionary = {}
var look_sig := ""
var fly_from := Vector3.ZERO
var dust: CPUParticles3D = null
var _noise_ready := false
var beacon: Node3D = null
var ring_node: Node3D = null
var life
var king_dead := false


func _ready() -> void:
	name = "World"
	WG.init_noise()
	add_child(stub)
	ProfS.load_all()
	_load()
	WG.sites.clear()
	for l in WG.gen_lords():
		castles.append(l)
		WG.add_site(float(l.x), float(l.z))
	if level > 0:
		own_castle = {"name": _my_name(), "x": cx, "z": cz, "level": level, "owner": "you"}
		castles.append(own_castle)
		WG.add_site(cx, cz)
	_build_env()
	_build_king()
	hud = HudS.new()
	hud.world = self
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	cl.add_child(hud)
	life = LifeS.new()
	life.world = self
	add_child(life)
	life.load_data()
	if level > 0:
		_offline_income()
		king_pos = _spawn_pos()
		state = "load"
		_start_play()
	else:
		state = "pick"
		hud.show_pick()


func _my_name() -> String:
	return ProfS.king_name if ProfS.king_name != "" else LocS.t("Your King")


# ------------------------------------------------------------------ save / load
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	level = int(cf.get_value("w", "level", 0))
	cx = float(cf.get_value("w", "cx", 0.0))
	cz = float(cf.get_value("w", "cz", 0.0))
	res.gold = int(cf.get_value("w", "gold", 60))
	res.wood = int(cf.get_value("w", "wood", 40))
	res.stone = int(cf.get_value("w", "stone", 20))
	last_unix = int(cf.get_value("w", "last", 0))
	tod = float(cf.get_value("w", "tod", 9.0))
	day = int(cf.get_value("w", "day", 1))


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("w", "level", level)
	cf.set_value("w", "cx", cx)
	cf.set_value("w", "cz", cz)
	cf.set_value("w", "gold", res.gold)
	cf.set_value("w", "wood", res.wood)
	cf.set_value("w", "stone", res.stone)
	cf.set_value("w", "last", int(Time.get_unix_time_from_system()))
	cf.set_value("w", "tod", tod)
	cf.set_value("w", "day", day)
	cf.save(SAVE)
	if life != null:
		life.save()


func _offline_income() -> void:
	if last_unix <= 0 or level <= 0:
		return
	var el := clampf(float(Time.get_unix_time_from_system()) - float(last_unix), 0.0, 8.0 * 3600.0)
	var m := el / 60.0
	var inc: Array = Prog.income(level)
	var g := int(inc[0] * m * 0.5)
	var w := int(inc[1] * m * 0.5)
	var s := int(inc[2] * m * 0.5)
	if g + w + s > 0:
		res.gold += g
		res.wood += w
		res.stone += s
		await get_tree().create_timer(2.5).timeout
		hud.toast(LocS.t("Your castle earned while you were away") + ": +%d / +%d / +%d" % [g, w, s], 5.0)


# ------------------------------------------------------------------ environment
func _build_env() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.18
	sky_mat.sky_energy_multiplier = 0.8
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.3, 0.5, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.12
	wm.metallic = 0.3
	wm.emission_enabled = true
	wm.emission = Color(0.04, 0.12, 0.2)
	water.material_override = wm
	add_child(water)
	cam = Camera3D.new()
	cam.far = 3500.0
	cam.fov = 62.0
	cam.current = true
	add_child(cam)
	_apply_tod()


func _apply_tod() -> void:
	var elev := sin((tod - 6.0) / 12.0 * PI)           # >0 by day
	sun.rotation_degrees = Vector3(-clampf(elev, 0.05, 1.0) * 70.0 - 4.0, (tod - 12.0) * 15.0 + 160.0, 0)
	var day_k := clampf(elev * 3.0, 0.0, 1.0)
	var dusk_k := 1.0 - clampf(absf(elev) * 4.0, 0.0, 1.0)
	sun.light_energy = lerpf(0.1, 0.85, day_k)
	sun.light_color = Color(0.7, 0.75, 1.0).lerp(Color(1.0, 0.95, 0.85), day_k).lerp(Color(1.0, 0.6, 0.35), dusk_k * 0.8)
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.27, 0.5, 0.92), day_k)
	var hor := Color(0.07, 0.07, 0.15).lerp(Color(0.72, 0.82, 0.95), day_k).lerp(Color(0.95, 0.5, 0.3), dusk_k * 0.85)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.4)
	env.fog_light_color = hor.lerp(Color(0.5, 0.55, 0.65), 0.3)
	env.ambient_light_energy = lerpf(0.4, 0.55, day_k)


# ------------------------------------------------------------------ king
func _build_king() -> void:
	KL.force = KL.merged(ProfS.look)
	king = UnitS.new()
	add_child(king)
	king.setup("hero", 0, 1, stub)
	KL.force = {}
	king.process_mode = Node.PROCESS_MODE_DISABLED
	if king.bar != null:
		king.bar.visible = false
	look_sig = str(ProfS.look)


func _spawn_pos() -> Vector3:
	var sc: float = Prog.scale_of(level)
	var p := Vector3(cx + 3.0, 0, cz + 26.0 * sc)
	p.y = WG.h(p.x, p.z, WG.near_sites(p.x, p.z, 10.0))
	return p


# ------------------------------------------------------------------ flow
func confirm_site(x: float, z: float) -> void:
	cx = x
	cz = z
	level = 1
	res = {"gold": 60, "wood": 40, "stone": 20}
	WG.add_site(cx, cz)
	own_castle = {"name": _my_name(), "x": cx, "z": cz, "level": 1, "owner": "you"}
	castles.append(own_castle)
	king_pos = _spawn_pos()
	state = "load"
	hud.hide_pick()
	life.on_level_up()
	save()
	_start_play(true)


func _start_play(found := false) -> void:
	hud.show_loading(true)
	king.position = king_pos
	await _preload(king_pos, 3)
	hud.show_loading(false)
	_sync_castles()
	life.on_play_start()
	cam_yaw = 0.0
	king_yaw = PI
	if found:
		state = "found"
		found_t = 0.0
		_rise_castle()
		hud.toast(LocS.t("Your castle is founded!"), 4.0)
		Snd.play(self, "confirm", -4.0)
	else:
		state = "play"
	hud.show_play()
	last_unix = int(Time.get_unix_time_from_system())
	Snd.play(self, "whoosh", -10.0)


func _preload(p: Vector3, rad: int) -> void:
	var c0 := Vector2i(int(floor(p.x / WG.CHUNK)), int(floor(p.z / WG.CHUNK)))
	var list: Array = []
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			list.append(Vector2i(c0.x + dx, c0.y + dz))
	var i := 0
	for c in list:
		_build_chunk(c, c0)
		i += 1
		if i % 3 == 0:
			hud.set_loading(float(i) / list.size())
			await get_tree().process_frame


func _rise_castle() -> void:
	for c in castles:
		if c.owner == "you" and c.has("node") and is_instance_valid(c.node):
			var n: Node3D = c.node
			var target: float = n.scale.x
			n.scale = Vector3.ONE * 0.02
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * target * 1.08, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "scale", Vector3.ONE * target, 0.4)
			_dust_at(Vector3(cx, WG.h(cx, cz, WG.near_sites(cx, cz, 5.0)), cz), 3.0)


func _dust_at(p: Vector3, secs: float) -> void:
	var ps := CPUParticles3D.new()
	ps.position = p + Vector3(0, 1.0, 0)
	ps.amount = 80
	ps.lifetime = 3.0
	ps.one_shot = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 14.0
	ps.direction = Vector3(0, 1, 0)
	ps.spread = 40.0
	ps.initial_velocity_min = 2.0
	ps.initial_velocity_max = 6.0
	ps.gravity = Vector3(0, -1.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	sm.radial_segments = 6
	sm.rings = 3
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.7, 0.62, 0.5, 0.3)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mt
	ps.mesh = sm
	add_child(ps)
	get_tree().create_timer(secs).timeout.connect(func():
		ps.emitting = false
		get_tree().create_timer(3.5).timeout.connect(ps.queue_free))


func upgrade() -> bool:
	if level <= 0 or level >= Prog.MAXL:
		return false
	if not life.tasks_done():
		hud.toast(LocS.t("Finish the quests first"), 2.5)
		Snd.play(self, "back", -6.0)
		return false
	var c: Array = Prog.cost(level)
	if res.gold < c[0] or res.wood < c[1] or res.stone < c[2]:
		hud.toast(LocS.t("Not enough resources"), 2.5)
		Snd.play(self, "back", -6.0)
		return false
	res.gold -= c[0]
	res.wood -= c[1]
	res.stone -= c[2]
	level += 1
	own_castle.level = level
	_rebuild_castle(own_castle)
	_rise_castle()
	king_pos = _spawn_pos()
	if life.sitting:
		life.stand_up()
	life.on_level_up()
	Snd.play(self, "confirm", -2.0)
	hud.toast(LocS.t("Castle upgraded to level") + " %d" % level, 4.0)
	save()
	_sync_castles(true)
	return true


func fast_home() -> void:
	if level <= 0 or home_cd > 0.0:
		return
	home_cd = 25.0
	if life.sitting:
		life.stand_up()
	king_pos = _spawn_pos()
	_request_chunks(king_pos)
	Snd.play(self, "whoosh", -6.0)
	hud.toast(LocS.t("Back at your castle"), 2.0)


func toggle_horse() -> void:
	life.horse_action()


func exit_world() -> void:
	save()
	main.back_to_menu()


# ------------------------------------------------------------------ chunks
func _request_chunks(p: Vector3) -> void:
	var c0 := Vector2i(int(floor(p.x / WG.CHUNK)), int(floor(p.z / WG.CHUNK)))
	var want := {}
	for dx in range(-CHUNK_R, CHUNK_R + 1):
		for dz in range(-CHUNK_R, CHUNK_R + 1):
			var c := Vector2i(c0.x + dx, c0.y + dz)
			if absi(c.x * 128) > 4200 or absi(c.y * 128) > 4200:
				continue
			want[c] = true
	for c in chunks.keys():
		var d := maxi(absi(c.x - c0.x), absi(c.y - c0.y))
		if d > CHUNK_R + 1:
			(chunks[c] as Node3D).queue_free()
			chunks.erase(c)
	pending.clear()
	for c in want.keys():
		if not chunks.has(c):
			pending.append(c)
	pending.sort_custom(func(a, b): return (a.x - c0.x) * (a.x - c0.x) + (a.y - c0.y) * (a.y - c0.y) < (b.x - c0.x) * (b.x - c0.x) + (b.y - c0.y) * (b.y - c0.y))


func _build_chunk(c: Vector2i, c0: Vector2i) -> void:
	if chunks.has(c):
		return
	var d := maxi(absi(c.x - c0.x), absi(c.y - c0.y))
	var seg := 28 if d <= 1 else (16 if d <= 3 else 8)
	var ox: float = c.x * WG.CHUNK
	var oz: float = c.y * WG.CHUNK
	var local := WG.near_sites(ox + WG.CHUNK * 0.5, oz + WG.CHUNK * 0.5, WG.CHUNK)
	var step: float = WG.CHUNK / seg
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	var n1 := seg + 1
	var hs := PackedFloat32Array()
	hs.resize((n1 + 2) * (n1 + 2))
	for j in n1 + 2:
		for i in n1 + 2:
			hs[j * (n1 + 2) + i] = WG.h(ox + (i - 1) * step, oz + (j - 1) * step, local)
	for j in n1:
		for i in n1:
			var x := ox + i * step
			var z := oz + j * step
			var k := (j + 1) * (n1 + 2) + (i + 1)
			var hv: float = hs[k]
			var nx: float = hs[k - 1] - hs[k + 1]
			var nz: float = hs[k - (n1 + 2)] - hs[k + (n1 + 2)]
			var nrm := Vector3(nx, 2.0 * step, nz).normalized()
			vs.append(Vector3(x, hv, z))
			ns.append(nrm)
			cs.append(WG.ground_col(hv, sqrt(maxf(0.0, 1.0 - nrm.y * nrm.y)) / maxf(nrm.y, 0.1), x, z))
	for j in seg:
		for i in seg:
			var a := j * n1 + i
			idx.append_array([a, a + 1, a + n1, a + 1, a + n1 + 1, a + n1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_mat()
	var root := Node3D.new()
	root.add_child(mi)
	add_child(root)
	chunks[c] = root
	if d <= 3:
		_trees(root, c, ox, oz, local)
	_cache_for(root, c, ox, oz, local)


static var _tmat: StandardMaterial3D = null


func _terrain_mat() -> StandardMaterial3D:
	if _tmat == null:
		_tmat = StandardMaterial3D.new()
		_tmat.vertex_color_use_as_albedo = true
		_tmat.roughness = 1.0
	return _tmat


static var _tree_meshes: Array = []


func _trees(root: Node3D, c: Vector2i, ox: float, oz: float, local: Array) -> void:
	if _tree_meshes.is_empty():
		var tr := CylinderMesh.new()
		tr.top_radius = 0.25
		tr.bottom_radius = 0.4
		tr.height = 2.4
		tr.radial_segments = 5
		tr.rings = 1
		var fo := CylinderMesh.new()
		fo.top_radius = 0.0
		fo.bottom_radius = 2.2
		fo.height = 7.0
		fo.radial_segments = 6
		fo.rings = 1
		_tree_meshes = [tr, fo, CK._m(Color(0.3, 0.2, 0.1), 1.0), CK._m(Color(0.1, 0.3, 0.14), 1.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = (c.x * 73856093) ^ (c.y * 19349663)
	var t1: Array = []
	var t2: Array = []
	for i in 46:
		var x := ox + rng.randf() * WG.CHUNK
		var z := oz + rng.randf() * WG.CHUNK
		if WG.forest(x, z) < 0.02 - (0.0 if rng.randf() < 0.9 else 0.3):
			continue
		var hv := WG.h(x, z, local)
		if hv < 3.0 or hv > 62.0:
			continue
		var near_castle := false
		for s in local:
			var dx: float = x - float(s.x)
			var dz: float = z - float(s.z)
			if dx * dx + dz * dz < 150.0 * 150.0:
				near_castle = true
		if near_castle:
			continue
		var sc := 0.8 + rng.randf() * 1.1
		var b := Basis().scaled(Vector3(sc, sc, sc)).rotated(Vector3.UP, rng.randf() * TAU)
		t1.append(Transform3D(b, Vector3(x, hv + 1.2 * sc, z)))
		t2.append(Transform3D(b, Vector3(x, hv + 5.0 * sc, z)))
	CK._multi(root, _tree_meshes[0], _tree_meshes[2], t1)
	CK._multi(root, _tree_meshes[1], _tree_meshes[3], t2)


func _cache_for(root: Node3D, c: Vector2i, ox: float, oz: float, local: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (c.x * 1299709) ^ (c.y * 15485863) ^ 55
	if rng.randf() > 0.22:
		return
	var x := ox + 16.0 + rng.randf() * (WG.CHUNK - 32.0)
	var z := oz + 16.0 + rng.randf() * (WG.CHUNK - 32.0)
	var hv := WG.h(x, z, local)
	if hv < 2.0 or hv > 70.0:
		return
	var key := "%d_%d" % [c.x, c.y]
	for cc in caches:
		if cc.key == key:
			if cc.taken > 0.0:
				return
			break
	var ty := rng.randi() % 3
	var col: Color = [Color(1.0, 0.8, 0.2), Color(0.6, 0.38, 0.16), Color(0.72, 0.74, 0.8)][ty]
	var n := Node3D.new()
	n.position = Vector3(x, hv, z)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 26.0
	cm.radial_segments = 6
	cm.rings = 1
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(col.r, col.g, col.b, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.position.y = 13.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	CK._b(n, Vector3(1.4, 0.9, 1.0), CK._m(col, 0.4, 0.6, 0.6), Vector3(0, 0.45, 0))
	CK._b(n, Vector3(1.5, 0.25, 1.1), CK._m(Color(0.2, 0.12, 0.06), 0.9), Vector3(0, 0.95, 0))
	root.add_child(n)
	caches.append({"key": key, "pos": n.position, "type": ty, "node": n, "taken": 0.0})


# ------------------------------------------------------------------ castles
func _castle_cfg(c: Dictionary) -> Dictionary:
	var lv: int = int(c.level)
	var C: Dictionary
	if c.owner == "you":
		C = CK.merged(ProfS.castle)
	else:
		C = CK.merged({"wall": int(c.get("banner", 0)) % 6, "roof": (int(c.get("banner", 0)) + int(c.get("emblem", 0))) % 6, "banner": int(c.get("banner", 0)), "emblem": int(c.get("emblem", 0))})
	C.keep = 0 if lv < 3 else (1 if lv < 14 else 2)
	C.tcount = 0 if lv < 3 else (1 if lv < 10 else 2)
	C.torch = 1 if lv >= 5 else 0
	C.moat = 1 if lv >= 22 else 0
	return C


func _rebuild_castle(c: Dictionary) -> void:
	if c.has("node") and is_instance_valid(c.node):
		(c.node as Node3D).queue_free()
	var C := _castle_cfg(c)
	var root := Node3D.new()
	var y := WG.h(float(c.x), float(c.z), WG.near_sites(float(c.x), float(c.z), 5.0))
	root.position = Vector3(float(c.x), y, float(c.z))
	var sc: float = Prog.scale_of(int(c.level))
	root.scale = Vector3.ONE * sc
	add_child(root)
	var tc: Color = CK.BANNER[int(C.banner)] if int(C.banner) > 0 else Color(0.72, 0.12, 0.12)
	var out := CK.build(root, C, tc, c.owner == "you")
	c["node"] = root
	c["out"] = out
	# name plate
	var lb := Label3D.new()
	lb.text = "%s  Lv %d" % [String(c.name), int(c.level)]
	lb.font_size = 56
	lb.outline_size = 14
	lb.pixel_size = 0.012
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.modulate = Color(1.0, 0.88, 0.5) if c.owner == "you" else (Color(0.6, 0.85, 1.0) if c.owner == "online" else Color(0.95, 0.9, 0.85))
	lb.position = Vector3(0, 34.0, 0)
	root.add_child(lb)
	if c.owner == "you":
		_castle_extras(root, c, sc)


func _castle_extras(root: Node3D, c: Dictionary, sc: float) -> void:
	for g in guards:
		if is_instance_valid(g):
			g.queue_free()
	guards.clear()
	var n: int = Prog.guards(int(c.level))
	var steel := CK._m(Color(0.62, 0.64, 0.72), 0.4, 0.8)
	var cloth := CK._m(Color(0.7, 0.12, 0.12), 0.8)
	var skin := CK._m(Color(0.8, 0.6, 0.45), 0.9)
	for i in n:
		var s := Node3D.new()
		CK._b(s, Vector3(0.5, 0.95, 0.3), cloth, Vector3(0, 1.0, 0))
		CK._b(s, Vector3(0.52, 0.5, 0.32), steel, Vector3(0, 1.25, 0))
		CK._b(s, Vector3(0.3, 0.3, 0.3), skin, Vector3(0, 1.72, 0))
		CK._b(s, Vector3(0.36, 0.2, 0.36), steel, Vector3(0, 1.88, 0))
		CK._b(s, Vector3(0.14, 0.7, 0.14), steel, Vector3(-0.15, 0.35, 0))
		CK._b(s, Vector3(0.14, 0.7, 0.14), steel, Vector3(0.15, 0.35, 0))
		CK._b(s, Vector3(0.06, 2.4, 0.06), CK._m(Color(0.35, 0.22, 0.12), 0.9), Vector3(0.38, 1.4, 0))
		CK._b(s, Vector3(0.1, 0.3, 0.1), steel, Vector3(0.38, 2.7, 0))
		s.scale = Vector3.ONE * 1.25 / sc
		s.set_meta("a", float(i) / maxf(n, 1.0) * TAU)
		s.set_meta("r", (21.0 + float(i % 3) * 3.4) * sc)
		root.add_child(s)
		guards.append(s)
	_estate(root, int(c.level), sc)
	# beacon fire and territory ring
	if beacon != null and is_instance_valid(beacon):
		beacon.queue_free()
	if ring_node != null and is_instance_valid(ring_node):
		ring_node.queue_free()
	if int(c.level) >= 16:
		beacon = Node3D.new()
		beacon.position = Vector3(-16.0 * sc, 0, 22.0 * sc)
		root.add_child(beacon)
		CK._b(beacon, Vector3(0.6, 9.0, 0.6), CK._m(Color(0.3, 0.2, 0.1), 0.9), Vector3(0, 4.5, 0))
		CK._b(beacon, Vector3(2.0, 1.6, 2.0), CK._m(Color(1.0, 0.55, 0.15), 0.5, 0.0, 6.0), Vector3(0, 9.8, 0))
		var ol := OmniLight3D.new()
		ol.position = Vector3(0, 11.0, 0)
		ol.light_color = Color(1.0, 0.6, 0.25)
		ol.light_energy = 3.0
		ol.omni_range = 60.0
		beacon.add_child(ol)
	if int(c.level) >= 30:
		ring_node = Node3D.new()
		root.add_child(ring_node)
		var gm := CK._m(Color(1.0, 0.8, 0.3), 0.3, 0.8, 1.0)
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var p := Vector3(sin(a) * 52.0 * sc, 0, cos(a) * 52.0 * sc)
			CK._b(ring_node, Vector3(0.3, 6.0, 0.3), CK._m(Color(0.3, 0.2, 0.1), 0.9), p + Vector3(0, 3.0, 0))
			CK._b(ring_node, Vector3(0.2, 1.8, 1.4), gm, p + Vector3(0, 5.0, 0.8))


# horse paddock and stable, throne, and market stalls that multiply with the castle level
func _estate(root: Node3D, lv: int, sc: float) -> void:
	var wood := CK._m(Color(0.36, 0.22, 0.12), 0.9)
	if lv >= 2:
		var pad := Node3D.new()
		pad.position = Vector3(-27.0, 0, 23.0)
		root.add_child(pad)
		var hx := 8.0
		var hz := 6.5
		CK._b(pad, Vector3(hx * 2.0, 0.05, hz * 2.0), CK._m(Color(0.2, 0.42, 0.14), 1.0), Vector3(0, 0.03, 0))
		for i in 9:
			var f := -hx + float(i) * hx * 2.0 / 8.0
			for zz in [-hz, hz]:
				CK._b(pad, Vector3(0.22, 1.5, 0.22), wood, Vector3(f, 0.75, zz))
			CK._b(pad, Vector3(hx * 2.0 / 8.0, 0.14, 0.12), wood, Vector3(f + hx / 8.0, 1.1, -hz))
			CK._b(pad, Vector3(hx * 2.0 / 8.0, 0.14, 0.12), wood, Vector3(f + hx / 8.0, 1.1, hz))
		for i in 7:
			var f2 := -hz + float(i) * hz * 2.0 / 6.0
			for xx in [-hx, hx]:
				CK._b(pad, Vector3(0.22, 1.5, 0.22), wood, Vector3(xx, 0.75, f2))
			CK._b(pad, Vector3(0.12, 0.14, hz * 2.0 / 6.0), wood, Vector3(-hx, 1.1, f2 + hz / 6.0))
			CK._b(pad, Vector3(0.12, 0.14, hz * 2.0 / 6.0), wood, Vector3(hx, 1.1, f2 + hz / 6.0))
		CK._b(pad, Vector3(4.4, 2.6, 3.0), wood, Vector3(-hx + 2.6, 1.3, -hz + 2.0))
		CK._b(pad, Vector3(5.0, 0.4, 3.6), CK._m(Color(0.5, 0.18, 0.1), 0.85), Vector3(-hx + 2.6, 2.8, -hz + 2.0))
		CK._b(pad, Vector3(1.4, 0.7, 0.5), CK._m(Color(0.7, 0.6, 0.2), 0.9), Vector3(0, 0.4, hz - 0.4))
	if lv >= 3:
		life.build_throne(root, sc)
	var stalls := mini(10, lv / 4)
	for i in stalls:
		var a := PI * (0.2 + 0.6 * float(i) / maxf(float(stalls - 1), 1.0))
		var p := Vector3(cos(a) * 26.0 - 13.0, 0, 28.0 + sin(a) * 6.0)
		var col: Color = [Color(0.75, 0.15, 0.12), Color(0.15, 0.4, 0.7), Color(0.8, 0.65, 0.15), Color(0.2, 0.55, 0.3)][i % 4]
		CK._b(root, Vector3(2.6, 1.0, 1.5), wood, p + Vector3(0, 0.5, 0))
		CK._b(root, Vector3(3.0, 0.15, 2.0), CK._m(col, 0.85), p + Vector3(0, 2.2, 0), Vector3(0.2, 0, 0))
		for sx in [-1.2, 1.2]:
			CK._b(root, Vector3(0.12, 2.2, 0.12), wood, p + Vector3(sx, 1.1, 0.7))


# castles are built when the player gets within reach and freed far away
func _sync_castles(force := false) -> void:
	for c in castles:
		var d := Vector2(king_pos.x - float(c.x), king_pos.z - float(c.z)).length()
		var have: bool = c.has("node") and is_instance_valid(c.node)
		if d < 700.0 and (not have or (force and c.owner == "you")):
			_rebuild_castle(c)
		elif d > 1100.0 and have and c.owner != "you":
			(c.node as Node3D).queue_free()
			c.erase("node")
		elif c.owner == "you" and not have and level > 0:
			_rebuild_castle(c)


func nearest_castle(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for c in castles:
		var d := Vector2(p.x - float(c.x), p.z - float(c.z)).length()
		if d < bd:
			bd = d
			best = c
	if not best.is_empty():
		best = best.duplicate()
		best["dist"] = bd
	return best


# ------------------------------------------------------------------ online presence (optional world server)
func _backend():
	return main.get_node_or_null("Backend") if main != null else null


func _net_tick() -> void:
	var bk = _backend()
	if bk == null or bk.base_url == "":
		return
	if level > 0:
		var C := CK.merged(ProfS.castle)
		bk._http_post("/api/world/castle", {"player_id": bk.player_id, "name": _my_name(), "x": cx, "z": cz, "level": level, "banner": int(C.banner), "emblem": int(C.emblem), "px": king_pos.x, "pz": king_pos.z, "game": "saleelalhadid"}, func(_code, _d): pass)
		bk._http_get("/api/world/inbox?player_id=" + String(bk.player_id).uri_encode(), func(code, d):
			if code == 200 and d is Dictionary and d.has("msgs"):
				life.on_msgs(d["msgs"]))
	bk._http_get("/api/world/castles?game=saleelalhadid", func(code, d):
		if code != 200:
			online_state = "offline"
			return
		var arr: Array = []
		if d is Array:
			arr = d
		elif d is Dictionary and d.has("castles"):
			arr = d["castles"]
		else:
			online_state = "offline"
			return
		online_state = "online"
		online_count = 0
		var seen := {}
		for e in arr:
			if not (e is Dictionary) or String(e.get("player_id", "")) == bk.player_id:
				continue
			online_count += 1
			seen[String(e.player_id)] = true
			if level > 0 and Time.get_unix_time_from_system() - float(e.get("updated", 0)) / 1000.0 < 90.0:
				life.update_online(e)
			var found := false
			for c in castles:
				if c.owner == "online" and String(c.get("pid", "")) == String(e.player_id):
					found = true
					c.level = int(e.get("level", 1))
					c.name = String(e.get("name", "Player"))
			if not found:
				var nc := {"name": String(e.get("name", "Player")), "x": float(e.get("x", 0)), "z": float(e.get("z", 0)), "level": clampi(int(e.get("level", 1)), 1, 50), "banner": int(e.get("banner", 0)), "emblem": int(e.get("emblem", 0)), "owner": "online", "pid": String(e.player_id)}
				castles.append(nc)
				WG.add_site(nc.x, nc.z)
		life.prune_online(seen))


# ------------------------------------------------------------------ per frame
func _process(dt: float) -> void:
	t_all += dt
	if state == "pick" or state == "load":
		return
	tod += dt / 20.0
	if tod >= 24.0:
		tod -= 24.0
		day += 1
	_apply_tod()
	home_cd = maxf(0.0, home_cd - dt)
	# chunk streaming
	chunk_t -= dt
	if chunk_t <= 0.0:
		chunk_t = 0.35
		_request_chunks(king_pos)
		_sync_castles()
	if not pending.is_empty():
		var c0 := Vector2i(int(floor(king_pos.x / WG.CHUNK)), int(floor(king_pos.z / WG.CHUNK)))
		var c: Vector2i = pending.pop_front()
		_build_chunk(c, c0)
	# income
	if level > 0:
		var inc_now: Array = Prog.income(level)
		for i in 3:
			income_acc[i] += float(inc_now[i]) * dt / 60.0
		var keys := ["gold", "wood", "stone"]
		for i in 3:
			if income_acc[i] >= 1.0:
				var add := int(income_acc[i])
				res[keys[i]] += add
				income_acc[i] -= add
		save_t -= dt
		if save_t <= 0.0:
			save_t = 12.0
			save()
	net_t -= dt
	if net_t <= 0.0:
		net_t = 6.0
		_net_tick()
	if state == "found":
		found_t += dt
		var e := clampf(found_t / 6.0, 0.0, 1.0)
		var sc: float = Prog.scale_of(level)
		var focus := Vector3(cx, king_pos.y + 14.0 * sc, cz)
		var a := lerpf(0.0, 1.0, e)
		var ang := lerpf(2.6, 0.0, smoothstep(0.0, 1.0, e))
		var dd := lerpf(260.0, 60.0 * sc, smoothstep(0.0, 1.0, e))
		var hh := lerpf(180.0, 22.0, smoothstep(0.0, 1.0, e))
		cam.position = focus + Vector3(sin(ang) * dd, hh, cos(ang) * dd)
		cam.look_at(focus, Vector3.UP)
		_animate_king(dt, 0.0)
		_animate_guards(dt)
		if found_t > 6.5:
			state = "play"
		return
	if state == "play":
		if king_dead:
			_animate_king(dt, 0.0)
		else:
			_move(dt)
		_camera(dt)
		_pickups(dt)
		_animate_guards(dt)
		life.tick(dt)
	hud.tick(dt)


func _move(dt: float) -> void:
	if life.sitting:
		king_pos = life.throne_pos
		king_yaw = 0.0
		speed = 0.0
		_animate_king(dt, 0.0)
		return
	var v := move_vec
	if v.length() < 0.05:
		v = Vector2.ZERO
		var kx := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		var kz := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		v = Vector2(kx, kz)
	var sp := 0.0
	if v.length() > 0.05:
		v = v.limit_length(1.0)
		var dir := Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam_yaw)
		var top: float = (26.0 if mounted else 9.5)
		if Input.is_key_pressed(KEY_SHIFT):
			top *= 1.6
		var np := king_pos + dir * top * v.length() * dt
		if not _blocked(np):
			king_pos.x = np.x
			king_pos.z = np.z
		elif not _blocked(Vector3(np.x, 0, king_pos.z)):
			king_pos.x = np.x
		elif not _blocked(Vector3(king_pos.x, 0, np.z)):
			king_pos.z = np.z
		king_yaw = lerp_angle(king_yaw, atan2(dir.x, dir.z), clampf(dt * 10.0, 0.0, 1.0))
		sp = top * v.length()
	king_pos.x = clampf(king_pos.x, -3900.0, 3900.0)
	king_pos.z = clampf(king_pos.z, -3900.0, 3900.0)
	king_pos.y = WG.h(king_pos.x, king_pos.z, WG.near_sites(king_pos.x, king_pos.z, 5.0))
	if king_pos.y < 0.2:
		king_pos.y = 0.2
	speed = lerpf(speed, sp, clampf(dt * 8.0, 0.0, 1.0))
	_animate_king(dt, speed)


func _blocked(p: Vector3) -> bool:
	if WG.h(p.x, p.z, WG.near_sites(p.x, p.z, 5.0)) < -0.8:
		return true
	for c in castles:
		var dx: float = p.x - float(c.x)
		var dz: float = p.z - float(c.z)
		var sc: float = Prog.scale_of(int(c.level))
		if absf(dx) > 25.0 * sc or absf(dz) > 25.0 * sc:
			continue
		var lx := dx / sc
		var lz := dz / sc
		# wall ring (half size 16, thickness 2.4) with the gate gap on the +Z side
		var ax := absf(lx)
		var az := absf(lz)
		var in_outer := ax < 17.4 and az < 17.4
		var in_inner := ax < 14.8 and az < 14.8
		if in_outer and not in_inner:
			if lz > 0.0 and ax < 3.9 and az > 14.8:
				continue
			return true
		# keep block
		if lx > -6.2 and lx < 6.2 and lz > -9.2 and lz < 3.2:
			return true
	return false


func _animate_king(dt: float, sp: float) -> void:
	king.position = king_pos + Vector3(0, 0.0, 0)
	king.rotation.y = king_yaw
	king.sim_speed = sp
	RigS.animate(king, dt)
	if mounted:
		king.position.y += 0.0
		for i in king.hlegs.size():
			king.hlegs[i].rotation.x = sin(t_all * (4.0 + sp * 0.5) + float(i) * 1.6) * 0.7 * clampf(sp / 8.0, 0.0, 1.0)
	if str(ProfS.look) != look_sig:
		pass


func _camera(dt: float) -> void:
	cam_dist = lerpf(cam_dist, cam_dist_t, clampf(dt * 6.0, 0.0, 1.0))
	var tg := king_pos + Vector3(0, 3.2 if not mounted else 4.0, 0)
	var c := cos(cam_pitch)
	var off := Vector3(sin(cam_yaw) * c, sin(cam_pitch), cos(cam_yaw) * c) * cam_dist
	var p := tg + off
	var gh := WG.h(p.x, p.z, WG.near_sites(p.x, p.z, 5.0))
	p.y = maxf(p.y, gh + 1.5)
	cam.position = cam.position.lerp(p, clampf(dt * 14.0, 0.0, 1.0)) if cam.position.distance_to(p) < 30.0 else p
	cam.look_at(tg, Vector3.UP)


func _pickups(dt: float) -> void:
	for c in caches:
		if c.taken > 0.0:
			c.taken -= dt
			if c.taken <= 0.0:
				c.taken = 0.0
			continue
		var p: Vector3 = c.pos
		if (p.x - king_pos.x) * (p.x - king_pos.x) + (p.z - king_pos.z) * (p.z - king_pos.z) < 16.0:
			c.taken = 600.0
			if is_instance_valid(c.node):
				(c.node as Node3D).queue_free()
			var amt := 20 + randi() % 40
			var names := ["gold", "wood", "stone"]
			var ty: int = c.type
			res[names[ty]] += amt
			hud.toast("+%d %s" % [amt, LocS.t(String(["Gold", "Wood", "Stone"][ty]))], 2.0)
			Snd.play(self, "click", -4.0, 1.3)


func _animate_guards(dt: float) -> void:
	for g in guards:
		if not is_instance_valid(g):
			continue
		var a: float = float(g.get_meta("a")) + dt * 0.12
		g.set_meta("a", a)
		var r: float = g.get_meta("r")
		g.position = Vector3(sin(a) * r, 0.0, cos(a) * r)
		g.rotation.y = a + PI * 0.5
		g.position.y = absf(sin(t_all * 5.0 + a * 9.0)) * 0.05


# camera input from the HUD drag pad
func damage_king(d: float) -> void:
	if king_dead:
		return
	life.king_hp -= d
	life.combat_t = 6.0
	king.flash = 0.6
	if life.king_hp <= 0.0:
		king_dead = true
		hud.toast(LocS.t("You have fallen! Your people carry you home..."), 3.0)
		Snd.play(self, "back", -2.0, 0.5)
		await get_tree().create_timer(3.0).timeout
		king_dead = false
		if mounted:
			life.dismount()
		var lost := int(res.gold * 0.08)
		res.gold -= lost
		life.king_hp = life.king_max
		king_pos = _spawn_pos()
		_request_chunks(king_pos)
		hud.toast(LocS.t("You wake in your castle") + "  -%d" % lost, 3.0)


func rotate_cam(dx: float, dy: float) -> void:
	cam_yaw -= dx * 0.006
	cam_pitch = clampf(cam_pitch + dy * 0.004, 0.08, 1.2)


func zoom_cam(f: float) -> void:
	cam_dist_t = clampf(cam_dist_t * f, 4.0, 40.0)
