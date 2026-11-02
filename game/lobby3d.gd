extends Control
# Main-menu world: a night-time castle on a hill (player's customised castle), the player's customised
# king standing on a rock beside a brazier, a marching column on the road, village, forest, mountains,
# moon + stars sky, crows, embers, torch light, drifting camera with touch/mouse parallax and sound ambience.

const CK := preload("res://game/castlekit.gd")
const KL := preload("res://game/kinglook.gd")
const UnitS := preload("res://game/unit.gd")
const RigS := preload("res://game/rig.gd")
const ProfS := preload("res://game/profile.gd")
const Snd := preload("res://game/uisnd.gd")

const SKY_SHADER := """
shader_type sky;
uniform vec3 top : source_color = vec3(0.025, 0.02, 0.09);
uniform vec3 mid : source_color = vec3(0.16, 0.08, 0.22);
uniform vec3 hor : source_color = vec3(0.75, 0.32, 0.30);
float hash(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(hor, mid, smoothstep(0.0, 0.18, h));
	col = mix(col, top, smoothstep(0.12, 0.7, h));
	if (d.y < 0.0) { col = mix(hor * 0.5, vec3(0.03, 0.025, 0.05), clamp(-d.y * 6.0, 0.0, 1.0)); }
	vec3 q = floor(d * 220.0);
	float s = hash(q);
	float tw = 0.6 + 0.4 * sin(TIME * (1.5 + s * 3.0) + s * 40.0);
	col += step(0.9965, s) * smoothstep(0.08, 0.35, h) * tw * vec3(0.9, 0.9, 1.0);
	vec3 md = normalize(vec3(-0.5, 0.36, -0.78));
	float m = dot(d, md);
	col += smoothstep(0.9982, 0.9990, m) * vec3(1.0, 0.96, 0.82) * 1.5;
	col += pow(max(m, 0.0), 80.0) * vec3(0.55, 0.6, 0.9) * 0.3;
	col += pow(max(m, 0.0), 8.0) * vec3(0.2, 0.22, 0.4) * 0.25;
	vec2 uv = d.xz / max(d.y + 0.35, 0.05);
	float c = sin(uv.x * 1.3 + TIME * 0.02) * sin(uv.y * 1.7 - TIME * 0.015) * 0.5 + 0.5;
	col += vec3(0.12, 0.07, 0.16) * smoothstep(0.55, 0.9, c) * smoothstep(0.05, 0.3, h) * 0.6;
	COLOR = col;
}
"""

class Stub extends Node:
	var HORSE_RIDING := false
	var my_id := 1
	var running := false
	var over := false
	var winner_team := -1
	var col := Color(0.72, 0.12, 0.12)
	func team_col(_t: int) -> Color:
		return col

var vp: SubViewport
var pvc: SubViewportContainer
var cam: Camera3D
var world: Node3D
var castle_root: Node3D
var castle_out := {}
var king
var stub := Stub.new()
var t := 0.0
var intro_t := 0.0
var flags: Array = []
var crows: Array = []
var soldiers: Array = []
var road_pts: Array = []
var fire_lights: Array = []
var flames: Array = []
var sig := ""
var par := Vector2.ZERO
var raise := 0.0
var raise_t := 6.0
var hy := 0.0
var bell_t := 9.0
var amb_wind: AudioStreamPlayer
var amb_fire: AudioStreamPlayer
var king_base := Vector3.ZERO
var banner_col := Color(0.72, 0.12, 0.12)
var _ready_done := false


static func ground_y(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	if r <= 34.0:
		return 0.0
	return -20.0 * clampf((r - 34.0) / 36.0, 0.0, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stub)
	pvc = SubViewportContainer.new()
	pvc.stretch = true
	pvc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pvc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pvc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if OS.has_feature("mobile"):
		vp.scaling_3d_scale = 0.8
	else:
		vp.msaa_3d = Viewport.MSAA_2X
	pvc.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	_env()
	_terrain()
	_road_and_army()
	_village()
	_forest()
	_mountains()
	_crows()
	_fx()
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.far = 700.0
	cam.current = true
	vp.add_child(cam)
	_rebuild()
	_audio()
	_ready_done = true
	intro()


func intro() -> void:
	intro_t = 0.0


# ------------------------------------------------------------------ world
func _mat(c: Color, rough := 0.95, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	return CK._m(c, rough, metal, emis)


func _env() -> void:
	var sh := Shader.new()
	sh.code = SKY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.24, 0.4)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.14, 0.24)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, 150, 0)
	moon.light_color = Color(0.6, 0.68, 1.0)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 100.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	vp.add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 8, 0)
	fill.light_color = Color(1.0, 0.78, 0.62)
	fill.light_energy = 0.5
	vp.add_child(fill)


func _terrain() -> void:
	var grass := _mat(Color(0.1, 0.16, 0.1), 1.0)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	g.mesh = pm
	g.material_override = grass
	g.position.y = -20.0
	world.add_child(g)
	var hill := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 34.0
	cm.bottom_radius = 70.0
	cm.height = 20.0
	cm.radial_segments = 40
	cm.rings = 1
	hill.mesh = cm
	hill.material_override = _mat(Color(0.07, 0.14, 0.07), 1.0)
	hill.position.y = -10.0
	world.add_child(hill)
	# rocky ledge near the castle for visual interest
	var rk := _mat(Color(0.28, 0.27, 0.3), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var a := rng.randf() * TAU
		var r := 36.0 + rng.randf() * 14.0
		var x := sin(a) * r
		var z := cos(a) * r
		if z > 28.0 and absf(x) < 14.0:
			continue
		var s := 0.8 + rng.randf() * 2.2
		var rm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s * 1.6, s, s * 1.3)
		rm.mesh = bm
		rm.material_override = rk
		rm.position = Vector3(x, ground_y(x, z) + s * 0.3, z)
		rm.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		world.add_child(rm)
	castle_root = Node3D.new()
	world.add_child(castle_root)


func _road_and_army() -> void:
	road_pts = []
	for i in 13:
		var z := 21.0 + i * 3.1
		var x := sin(i * 0.55) * 4.2 + 1.0
		road_pts.append(Vector3(x, ground_y(x, z) + 0.06, z))
	var rm := _mat(Color(0.34, 0.27, 0.2), 1.0)
	for i in road_pts.size() - 1:
		var a: Vector3 = road_pts[i]
		var b: Vector3 = road_pts[i + 1]
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.4, 0.12, a.distance_to(b) + 0.6)
		seg.mesh = bm
		seg.material_override = rm
		seg.position = (a + b) * 0.5
		seg.look_at_from_position(seg.position, b, Vector3.UP)
		world.add_child(seg)
	var steel := _mat(Color(0.6, 0.62, 0.7), 0.4, 0.8)
	var cloth := _mat(Color(0.7, 0.12, 0.12), 0.8)
	var skin := _mat(Color(0.8, 0.6, 0.45), 0.9)
	var wood := _mat(Color(0.35, 0.22, 0.12), 0.9)
	var flame := _mat(Color(1.0, 0.6, 0.2), 0.5, 0.0, 5.0)
	for i in 14:
		var s := Node3D.new()
		var side := -0.9 if i % 2 == 0 else 0.9
		s.set_meta("side", side)
		s.set_meta("p", float(i / 2) / 7.0)
		CK._b(s, Vector3(0.5, 0.95, 0.3), cloth, Vector3(0, 1.0, 0))
		CK._b(s, Vector3(0.52, 0.5, 0.32), steel, Vector3(0, 1.25, 0))
		CK._b(s, Vector3(0.3, 0.3, 0.3), skin, Vector3(0, 1.72, 0))
		CK._b(s, Vector3(0.36, 0.2, 0.36), steel, Vector3(0, 1.88, 0))
		CK._b(s, Vector3(0.14, 0.7, 0.14), steel, Vector3(-0.15, 0.35, 0))
		CK._b(s, Vector3(0.14, 0.7, 0.14), steel, Vector3(0.15, 0.35, 0))
		CK._b(s, Vector3(0.06, 2.4, 0.06), wood, Vector3(0.38, 1.4, 0.0))
		CK._b(s, Vector3(0.1, 0.3, 0.1), steel, Vector3(0.38, 2.7, 0.0))
		if i % 4 == 0:
			var f := CK._b(s, Vector3(0.22, 0.3, 0.22), flame, Vector3(-0.38, 2.4, 0))
			CK._b(s, Vector3(0.06, 1.3, 0.06), wood, Vector3(-0.38, 1.7, 0))
			flames.append(f)
		s.scale = Vector3.ONE * 1.25
		world.add_child(s)
		soldiers.append(s)


func _village() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var wallm := _mat(Color(0.5, 0.42, 0.34), 1.0)
	var roof := _mat(Color(0.3, 0.14, 0.1), 0.9)
	var win := _mat(Color(1.0, 0.7, 0.3), 0.5, 0.0, 3.5)
	var placed := 0
	var tries := 0
	while placed < 11 and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var r := 38.0 + rng.randf() * 12.0
		var x := sin(a) * r
		var z := cos(a) * r
		if z > 20.0 and absf(x) < 16.0:
			continue          # road + king area
		if z < -8.0:
			continue
		var y := ground_y(x, z)
		var h := Node3D.new()
		h.position = Vector3(x, y, z)
		h.rotation.y = a + PI * 0.5 + rng.randf() * 0.4
		CK._b(h, Vector3(4.6, 2.6, 3.6), wallm, Vector3(0, 1.3, 0))
		var pr := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(5.4, 2.2, 4.4)
		pr.mesh = pm
		pr.material_override = roof
		pr.position = Vector3(0, 3.7, 0)
		h.add_child(pr)
		CK._b(h, Vector3(0.7, 0.8, 0.1), win, Vector3(-1.0, 1.6, 1.82))
		CK._b(h, Vector3(0.7, 0.8, 0.1), win, Vector3(1.0, 1.6, 1.82))
		world.add_child(h)
		if placed % 3 == 0:
			var sm := CPUParticles3D.new()
			sm.position = h.position + Vector3(1.4, 5.0, 0)
			sm.amount = 12
			sm.lifetime = 4.0
			sm.direction = Vector3(0.3, 1, 0)
			sm.spread = 10.0
			sm.initial_velocity_min = 0.8
			sm.initial_velocity_max = 1.4
			sm.gravity = Vector3(0.3, 0.1, 0)
			var q := SphereMesh.new()
			q.radius = 0.45
			q.height = 0.9
			q.radial_segments = 6
			q.rings = 3
			var qm := StandardMaterial3D.new()
			qm.albedo_color = Color(0.35, 0.35, 0.42, 0.28)
			qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			q.material = qm
			sm.mesh = q
			sm.scale_amount_min = 0.5
			sm.scale_amount_max = 1.8
			world.add_child(sm)
		placed += 1


func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 4.6
	cone.radial_segments = 6
	cone.rings = 1
	var cone2 := CylinderMesh.new()
	cone2.top_radius = 0.0
	cone2.bottom_radius = 1.2
	cone2.height = 3.6
	cone2.radial_segments = 6
	cone2.rings = 1
	var a1: Array = []
	var a2: Array = []
	var n := 0
	while n < 170:
		var a := rng.randf() * TAU
		var r := 36.0 + rng.randf() * 130.0
		var x := sin(a) * r
		var z := cos(a) * r
		if z > 14.0 and absf(x - 1.5) < 9.0:
			continue
		if z > 30.0 and x < -2.0 and x > -14.0 and z < 50.0:
			continue
		if (x - 6.0) * (x - 6.0) + (z - 58.0) * (z - 58.0) < 1100.0:
			continue
		var y := ground_y(x, z)
		var s := 0.8 + rng.randf() * 1.0
		a1.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, y + 2.3 * s, z)))
		a2.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, y + 4.6 * s, z)))
		n += 1
	CK._multi(world, cone, _mat(Color(0.07, 0.17, 0.12), 1.0), a1)
	CK._multi(world, cone2, _mat(Color(0.09, 0.21, 0.14), 1.0), a2)


func _mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var mm := _mat(Color(0.11, 0.1, 0.2), 1.0)
	var snow := _mat(Color(0.7, 0.72, 0.9), 0.9, 0.0, 0.25)
	for i in 16:
		var a := -PI * 0.95 + float(i) / 15.0 * PI * 1.9
		var r := 230.0 + rng.randf() * 80.0
		var x := sin(a) * r * 1.2
		var z := -cos(a) * r
		if z > 40.0:
			continue
		var h := 70.0 + rng.randf() * 70.0
		var w := 50.0 + rng.randf() * 40.0
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = w
		cm.height = h
		cm.radial_segments = 6
		cm.rings = 1
		m.mesh = cm
		m.material_override = mm
		m.position = Vector3(x, -20.0 + h * 0.5, z)
		m.rotation.y = rng.randf() * TAU
		world.add_child(m)
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.0
		cc.bottom_radius = w * 0.3
		cc.height = h * 0.3
		cc.radial_segments = 6
		cc.rings = 1
		cap.mesh = cc
		cap.material_override = snow
		cap.position = Vector3(x, -20.0 + h * 0.85, z)
		cap.rotation.y = m.rotation.y
		world.add_child(cap)


func _crows() -> void:
	var dark := _mat(Color(0.03, 0.03, 0.05), 1.0)
	for i in 7:
		var c := Node3D.new()
		CK._b(c, Vector3(0.5, 0.2, 0.9), dark, Vector3.ZERO)
		var wl := Node3D.new()
		var wr := Node3D.new()
		c.add_child(wl)
		c.add_child(wr)
		CK._b(wl, Vector3(1.3, 0.05, 0.6), dark, Vector3(-0.65, 0, 0))
		CK._b(wr, Vector3(1.3, 0.05, 0.6), dark, Vector3(0.65, 0, 0))
		c.set_meta("wl", wl)
		c.set_meta("wr", wr)
		c.set_meta("ph", float(i) * 0.9)
		c.scale = Vector3.ONE * 1.5
		world.add_child(c)
		crows.append(c)


func _fx() -> void:
	# rising embers across the castle + fireflies around the king
	var em := CPUParticles3D.new()
	em.position = Vector3(0, 2.0, 6.0)
	em.amount = 90
	em.lifetime = 9.0
	em.preprocess = 9.0
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(34, 1.0, 34)
	em.direction = Vector3(0, 1, 0)
	em.spread = 25.0
	em.gravity = Vector3(0.1, 0.3, 0)
	em.initial_velocity_min = 0.6
	em.initial_velocity_max = 1.8
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 5
	sm.rings = 2
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(1.6, 0.9, 0.35)
	sm.material = mt
	em.mesh = sm
	world.add_child(em)
	var ff := CPUParticles3D.new()
	ff.position = Vector3(-4.0, 0.0, 40.0)
	ff.amount = 26
	ff.lifetime = 7.0
	ff.preprocess = 7.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(9, 2.5, 6)
	ff.direction = Vector3(0, 1, 0)
	ff.spread = 180.0
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.1
	ff.initial_velocity_max = 0.45
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.1
	fm.radial_segments = 5
	fm.rings = 2
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(0.7, 1.6, 0.6)
	fm.material = fmat
	ff.mesh = fm
	world.add_child(ff)


# ------------------------------------------------------------------ player-specific parts
func _look_sig() -> String:
	return str(ProfS.look) + "|" + str(ProfS.castle)


func refresh() -> void:
	if _ready_done and sig != _look_sig():
		_rebuild()


func _rebuild() -> void:
	sig = _look_sig()
	for c in castle_root.get_children():
		castle_root.remove_child(c)
		c.queue_free()
	if king != null and is_instance_valid(king):
		king.get_parent().remove_child(king)
		king.free()
		king = null
	var C: Dictionary = CK.merged(ProfS.castle)
	banner_col = CK.BANNER[int(C.banner)] if int(C.banner) > 0 else Color(0.72, 0.12, 0.12)
	stub.col = banner_col
	castle_out = CK.build(castle_root, C, banner_col)
	flags = castle_out.flags.duplicate()
	for l in fire_lights:
		if is_instance_valid(l):
			l.queue_free()
	fire_lights.clear()
	# king platform with a brazier and a banner
	var kx := -0.5
	var kz := 39.0
	var ky := ground_y(kx, kz)
	var plat := Node3D.new()
	plat.position = Vector3(kx, ky, kz)
	castle_root.add_child(plat)
	var rock := _mat(Color(0.3, 0.29, 0.32), 0.95)
	var rc := CK._cyl(plat, 2.7, 3.4, 2.4, rock, Vector3(0, 0.9, 0), 7)
	rc.rotation.y = 0.4
	CK._cyl(plat, 1.1, 1.6, 1.0, rock, Vector3(2.9, 0.1, 0.8), 6)
	CK._cyl(plat, 0.9, 1.3, 0.8, rock, Vector3(-2.6, 0.0, 1.4), 6)
	# brazier
	var gold := CK._m(Color(1.0, 0.78, 0.25), 0.3, 0.9, 0.2)
	var bp := Vector3(3.6, 0.0, 0.2)
	CK._b(plat, Vector3(0.14, 1.5, 0.14), _mat(Color(0.12, 0.1, 0.1), 0.5, 0.8), bp + Vector3(0, 0.75, 0))
	CK._cyl(plat, 0.7, 0.4, 0.45, _mat(Color(0.12, 0.1, 0.1), 0.5, 0.8), bp + Vector3(0, 1.6, 0), 8)
	var fl := CK._b(plat, Vector3(0.6, 0.7, 0.6), _mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, 5.0), bp + Vector3(0, 2.0, 0))
	castle_out.flames.append(fl)
	var ol := OmniLight3D.new()
	ol.position = bp + Vector3(0, 2.4, 0.4)
	ol.light_color = Color(1.0, 0.6, 0.28)
	ol.light_energy = 2.4
	ol.omni_range = 16.0
	plat.add_child(ol)
	castle_out.lights.append(ol)
	var ps := CPUParticles3D.new()
	ps.position = bp + Vector3(0, 2.1, 0)
	ps.amount = 16
	ps.lifetime = 1.1
	ps.direction = Vector3(0, 1, 0)
	ps.spread = 14.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 1.8
	ps.gravity = Vector3(0, 0.8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 5
	sm.rings = 2
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.8, 0.8, 0.25)
	sm.material = pm
	ps.mesh = sm
	plat.add_child(ps)
	# banner pole behind-left of the king
	var cloth := _mat(banner_col, 0.8, 0.0, 0.35)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	CK._flag(plat, Vector3(-2.2, 1.9, -1.0), 2.6, 3.6, cloth, gold, castle_out, int(C.emblem))
	flags = castle_out.flags.duplicate()
	# the king himself
	KL.force = KL.merged(ProfS.look)
	king = UnitS.new()
	world.add_child(king)
	king.setup("hero", 0, 1, stub)
	KL.force = {}
	king.process_mode = Node.PROCESS_MODE_DISABLED
	if king.bar != null:
		king.bar.visible = false
	king_base = Vector3(kx, ky + 2.1, kz)
	king.position = king_base
	king.rotation.y = 0.5
	king.scale = Vector3.ONE * 1.5


# ------------------------------------------------------------------ audio
func _audio() -> void:
	amb_wind = AudioStreamPlayer.new()
	amb_wind.stream = Snd.get_stream("wind")
	amb_wind.volume_db = -24.0
	add_child(amb_wind)
	amb_fire = AudioStreamPlayer.new()
	amb_fire.stream = Snd.get_stream("crackle")
	amb_fire.volume_db = -26.0
	add_child(amb_fire)
	if is_inside_tree():
		amb_wind.play()
		amb_fire.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and amb_wind != null:
		amb_wind.play()
		amb_fire.play()
	elif what == NOTIFICATION_EXIT_TREE and amb_wind != null:
		amb_wind.stop()
		amb_fire.stop()


# ------------------------------------------------------------------ per frame
func _process(dt: float) -> void:
	if not _ready_done:
		return
	t += dt
	intro_t += dt
	# camera: intro push-in, slow drift, pointer parallax
	var e := smoothstep(0.0, 1.0, clampf(intro_t / 3.2, 0.0, 1.0))
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var want := Vector2(clampf(mp.x / maxf(vs.x, 1.0) * 2.0 - 1.0, -1.0, 1.0), clampf(mp.y / maxf(vs.y, 1.0) * 2.0 - 1.0, -1.0, 1.0))
	par = par.lerp(want, clampf(dt * 2.5, 0.0, 1.0))
	var base := Vector3(9.0, 4.2, 58.0)
	var start := Vector3(14.0, -0.5, 82.0)
	var pos := start.lerp(base, e)
	pos += Vector3(sin(t * 0.21) * 1.7 + par.x * 2.6, sin(t * 0.33) * 0.45 - par.y * 0.7, sin(t * 0.17) * 1.3)
	cam.position = pos
	var tgt := Vector3(11.0, 7.0 - par.y * 1.6, 0.0)
	cam.look_at(tgt, Vector3.UP)
	cam.fov = lerpf(62.0, 52.0, e)
	# castle life
	CK.sway(flags, t)
	CK.flicker(castle_out, t)
	# soldiers march up the road
	for s in soldiers:
		var p: float = fmod(float(s.get_meta("p")) + t * 0.018, 1.0)
		var idx := (1.0 - p) * float(road_pts.size() - 1)
		var i0 := clampi(int(idx), 0, road_pts.size() - 2)
		var a: Vector3 = road_pts[i0]
		var b: Vector3 = road_pts[i0 + 1]
		var f := idx - float(i0)
		var pt: Vector3 = a.lerp(b, f)
		var dir := (a - b).normalized()
		var side: float = s.get_meta("side")
		pt += Vector3(dir.z, 0, -dir.x) * side
		pt.y += absf(sin(t * 6.0 + p * 40.0)) * 0.08
		s.position = pt
		s.rotation.y = atan2(dir.x, dir.z)
		s.visible = p > 0.03 and p < 0.97
	for i in crows.size():
		var c: Node3D = crows[i]
		var ph: float = c.get_meta("ph")
		var a := t * (0.18 + 0.02 * i) + ph
		var r := 26.0 + i * 2.4
		c.position = Vector3(sin(a) * r, 30.0 + sin(a * 2.3) * 3.0 + i, cos(a) * r * 0.8)
		c.rotation.y = a + PI * 0.5
		var fl := sin(t * 9.0 + ph * 3.0) * 0.6
		(c.get_meta("wl") as Node3D).rotation.z = fl
		(c.get_meta("wr") as Node3D).rotation.z = -fl
	# the king: breathing rig, head scanning castle -> camera, now and then raises his sword
	if king != null and is_instance_valid(king):
		RigS.animate(king, dt)
		raise_t -= dt
		if raise_t <= 0.0:
			raise_t = 16.0
			var tw := create_tween()
			tw.tween_property(self, "raise", 1.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.8)
			tw.tween_property(self, "raise", 0.0, 0.9)
		var rg: Dictionary = king.rg
		var want_h := sin(t * 0.33) * 0.55 - 0.15
		hy = lerpf(hy, want_h, clampf(dt * 2.5, 0.0, 1.0))
		if rg.has("head"):
			rg.head.rotation.y = hy
			rg.head.rotation.x = -0.06 + sin(t * 0.5) * 0.03
		if rg.has("torso"):
			rg.torso.rotation.y = hy * 0.3
		if raise > 0.001 and rg.has("sh"):
			var sh: Node3D = rg.sh[0]
			sh.rotation.x = lerpf(sh.rotation.x, -2.75, raise)
			sh.rotation.z = lerpf(sh.rotation.z, 0.0, raise)
			if rg.has("el"):
				var el: Node3D = rg.el[0]
				el.rotation.x = lerpf(el.rotation.x, -0.3, raise)
		king.rotation.y = 0.5 + sin(t * 0.25) * 0.08
	# distant bell
	bell_t -= dt
	if bell_t <= 0.0:
		bell_t = 26.0
		Snd.play(self, "bell", -20.0)
