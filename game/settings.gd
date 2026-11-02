extends RefCounted
# Player options: language, graphics quality, frame-rate cap. Saved in user://settings.cfg

const LocS := preload("res://game/loc.gd")
const PATH := "user://settings.cfg"

static var quality := 2        # 0 low, 1 medium, 2 high
static var fps := 60
static var show_fps := false
static var lang := "en"
# advanced graphics (values are indexes into OPT lists)
const OPT := {
	"fps": [30, 45, 60, 90, 120],
	"scale": [50, 60, 70, 80, 90, 100],
	"view": [0, 1, 2, 3, 4],          # very short .. very long
	"shadows": [0, 1, 2],             # off / low / high
	"trees": [0, 1, 2, 3],            # none / sparse / normal / dense
	"aa": [0, 1],                     # off / 2x
	"fx": [0, 1],                     # glow, fog, particles
	"auto": [0, 1],                   # adaptive resolution
}
const NAMES := {
	"view": ["Very short", "Short", "Medium", "Long", "Very long"],
	"shadows": ["Off", "Low", "High"],
	"trees": ["None", "Sparse", "Normal", "Dense"],
	"aa": ["Off", "On"],
	"fx": ["Off", "On"],
	"auto": ["Off", "On"],
}
const VIEW_CHUNKS := [2, 3, 4, 6, 8]
const TREE_K := [0.0, 0.35, 1.0, 1.5]
static var s_scale := 100
static var s_view := 3
static var s_shadows := 2
static var s_trees := 2
static var s_aa := 1
static var s_fx := 1
static var s_auto := 0
static var scale_live := 1.0
static var _acc := 0.0
static var _frames := 0


static func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		quality = clampi(int(cf.get_value("g", "quality", 2)), 0, 2)
		fps = int(cf.get_value("g", "fps", 60))
		show_fps = bool(cf.get_value("g", "show_fps", false))
		lang = String(cf.get_value("g", "lang", "en"))
		s_scale = int(cf.get_value("g", "scale", 100))
		s_view = int(cf.get_value("g", "view", 3))
		s_shadows = int(cf.get_value("g", "shadows", 2))
		s_trees = int(cf.get_value("g", "trees", 2))
		s_aa = int(cf.get_value("g", "aa", 1))
		s_fx = int(cf.get_value("g", "fx", 1))
		s_auto = int(cf.get_value("g", "auto", 0))
	else:
		# first start: weaker phones / Arabic phones get sensible defaults
		var loc := OS.get_locale_language()
		lang = "ar" if loc == "ar" else "en"
	if not OPT.fps.has(fps):
		fps = 60
	scale_live = float(s_scale) / 100.0
	LocS.lang = lang
	apply_global()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "quality", quality)
	cf.set_value("g", "fps", fps)
	cf.set_value("g", "show_fps", show_fps)
	cf.set_value("g", "lang", lang)
	cf.set_value("g", "scale", s_scale)
	cf.set_value("g", "view", s_view)
	cf.set_value("g", "shadows", s_shadows)
	cf.set_value("g", "trees", s_trees)
	cf.set_value("g", "aa", s_aa)
	cf.set_value("g", "fx", s_fx)
	cf.set_value("g", "auto", s_auto)
	cf.save(PATH)


static func set_lang(l: String) -> void:
	lang = l
	LocS.lang = l
	save()


static func apply_global() -> void:
	Engine.max_fps = fps
	if LocS.lang == "ar":
		TranslationServer.set_locale("ar")
	else:
		TranslationServer.set_locale("en")


# Applies the quality level to the 3D world below `root` (call after the world is built).
static func apply_scene(root: Node) -> void:
	var vp := root.get_viewport()
	if vp != null:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = [0.6, 0.8, 1.0][quality]
		vp.msaa_3d = Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED
	_walk(root)


static func _walk(n: Node) -> void:
	if n is DirectionalLight3D:
		var d: DirectionalLight3D = n
		d.shadow_enabled = quality >= 1
		d.directional_shadow_max_distance = 75.0 if quality == 2 else 45.0
		d.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	elif n is OmniLight3D:
		var o: OmniLight3D = n
		o.shadow_enabled = false
		if quality == 0 and o.has_meta("e0") == false:
			o.set_meta("e0", o.light_energy)
	elif n is WorldEnvironment:
		var we: WorldEnvironment = n
		if we.environment != null:
			we.environment.glow_enabled = quality == 2
			we.environment.fog_enabled = quality >= 1
			we.environment.adjustment_enabled = quality >= 1
	for c in n.get_children():
		_walk(c)


static func quality_name() -> String:
	return ["Low", "Medium", "High"][quality]


# ---- presets and option helpers used by every settings screen
const PRESETS := ["Potato", "Low", "Medium", "High", "Ultra"]
#                  fps scale view shadows trees aa fx auto
const PRESET_V := [[30, 50, 0, 0, 0, 0, 0, 1], [30, 60, 1, 0, 1, 0, 0, 1], [45, 80, 2, 1, 2, 0, 1, 1], [60, 100, 3, 2, 2, 1, 1, 0], [90, 100, 4, 2, 3, 1, 1, 0]]


static func apply_preset(i: int) -> void:
	var v: Array = PRESET_V[i]
	fps = v[0]
	s_scale = v[1]
	s_view = v[2]
	s_shadows = v[3]
	s_trees = v[4]
	s_aa = v[5]
	s_fx = v[6]
	s_auto = v[7]
	quality = clampi(i - 1, 0, 2)
	scale_live = float(s_scale) / 100.0
	save()
	apply_global()


static func cycle(key: String, dir := 1) -> void:
	var lst: Array = OPT[key]
	var cur: int = get_opt(key)
	var i: int = lst.find(cur)
	i = posmod(i + dir, lst.size())
	set_opt(key, lst[i])
	save()
	apply_global()


static func get_opt(key: String) -> int:
	match key:
		"fps": return fps
		"scale": return s_scale
		"view": return s_view
		"shadows": return s_shadows
		"trees": return s_trees
		"aa": return s_aa
		"fx": return s_fx
		"auto": return s_auto
	return 0


static func set_opt(key: String, v: int) -> void:
	match key:
		"fps": fps = v
		"scale":
			s_scale = v
			scale_live = float(v) / 100.0
		"view": s_view = v
		"shadows": s_shadows = v
		"trees": s_trees = v
		"aa": s_aa = v
		"fx": s_fx = v
		"auto": s_auto = v


static func opt_text(key: String) -> String:
	var v: int = get_opt(key)
	match key:
		"fps": return "%d" % v
		"scale": return "%d%%" % v
		_: return String(NAMES[key][clampi(v, 0, NAMES[key].size() - 1)])


static func chunk_r() -> int:
	return VIEW_CHUNKS[clampi(s_view, 0, 4)]


# adaptive resolution: call every frame from the 3D scene; returns true when the scale changed
static func auto_tick(dt: float, vp: Viewport) -> void:
	if s_auto == 0:
		return
	_acc += dt
	_frames += 1
	if _acc < 3.0:
		return
	var f := float(_frames) / _acc
	_acc = 0.0
	_frames = 0
	var tgt := float(fps) * 0.82
	if f < tgt and scale_live > 0.5:
		scale_live = maxf(0.5, scale_live - 0.1)
	elif f > float(fps) * 0.97 and scale_live < float(s_scale) / 100.0:
		scale_live = minf(float(s_scale) / 100.0, scale_live + 0.05)
	if vp != null:
		vp.scaling_3d_scale = scale_live


# graphics for the open world
static func apply_world(w) -> void:
	var vp: Viewport = w.get_viewport()
	if vp != null:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = scale_live
		vp.msaa_3d = Viewport.MSAA_2X if s_aa == 1 else Viewport.MSAA_DISABLED
	if w.sun != null:
		w.sun.shadow_enabled = s_shadows > 0
		w.sun.directional_shadow_max_distance = 140.0 if s_shadows == 2 else 70.0
		w.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if s_shadows == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	if w.env != null:
		w.env.glow_enabled = s_fx == 1
		w.env.fog_enabled = true
		w.env.adjustment_enabled = s_fx == 1
		var reach := float(chunk_r()) * 128.0
		w.env.fog_density = clampf(2.6 / maxf(reach, 200.0), 0.0011, 0.012)
	if w.cam != null:
		w.cam.far = float(chunk_r()) * 128.0 + 260.0
