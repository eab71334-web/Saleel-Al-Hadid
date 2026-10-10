extends RefCounted
# Player options: language, graphics quality, frame-rate cap. Saved in user://settings.cfg

const LocS := preload("res://game/loc.gd")
const PATH := "user://settings.cfg"

static var quality := 2        # 0 low, 1 medium, 2 high
static var fps := 60
static var show_fps := false
static var lang := "en"


static func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		quality = clampi(int(cf.get_value("g", "quality", 2)), 0, 2)
		fps = int(cf.get_value("g", "fps", 60))
		show_fps = bool(cf.get_value("g", "show_fps", false))
		lang = String(cf.get_value("g", "lang", "en"))
	else:
		# first start: weaker phones / Arabic phones get sensible defaults
		var loc := OS.get_locale_language()
		lang = "ar" if loc == "ar" else "en"
	if not [30, 60, 120].has(fps):
		fps = 60
	LocS.lang = lang
	apply_global()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "quality", quality)
	cf.set_value("g", "fps", fps)
	cf.set_value("g", "show_fps", show_fps)
	cf.set_value("g", "lang", lang)
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
