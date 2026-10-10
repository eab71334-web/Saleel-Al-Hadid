extends RefCounted
# Optional external 3D models and animations.
#
#   game/models/<kind>.glb   kind = sword | archer | cav | hero | horse | villager   (.glb .gltf .fbx also work)
#   game/anims/<name>.fbx    name = idle | walk | run | attack | die | ride
#   game/anims/<kind>_<name>.fbx  overrides the shared animation for one kind (e.g. hero_attack.fbx)
#
# If a file is missing the game falls back to the built-in procedural model, so
# you can add models one at a time.  Animations are retargeted by bone name
# (best with Mixamo characters + Mixamo animations, "In Place" ticked).

const MODEL_DIR := "res://game/models/"
const ANIM_DIR := "res://game/anims/"
const EXTS := [".glb", ".gltf", ".fbx", ".tscn"]

# Tuning: final height of each model in metres.
const HEIGHTS := {"sword": 1.8, "archer": 1.8, "cav": 1.8, "hero": 2.1, "horse": 1.7, "villager": 1.7}
# How high the rider sits when a custom horse model is used.
const HORSE_RIDE_Y := 0.95

const KEYS := {
	"idle": ["idle", "stand", "breath"],
	"walk": ["walk"],
	"run": ["run", "sprint", "gallop", "trot"],
	"attack": ["attack", "slash", "strike", "swing", "shoot", "punch", "hit"],
	"die": ["die", "death", "dead", "fall"],
	"ride": ["ride", "sit", "horse"],
}
const LOOPED := ["idle", "walk", "run", "ride"]
const FALLBACK := {
	"idle": ["idle"],
	"walk": ["walk", "run", "idle"],
	"run": ["run", "walk", "idle"],
	"ride": ["ride", "idle"],
	"attack": ["attack"],
	"die": ["die"],
}

static var _prep := {}
static var _anim_cache := {}


static func find_file(dir: String, base: String) -> String:
	for e in EXTS:
		var p: String = dir + base + e
		if ResourceLoader.exists(p):
			return p
	return ""


static func available_kinds() -> Array:
	var out := []
	for k in HEIGHTS.keys():
		if find_file(MODEL_DIR, k) != "":
			out.append(k)
	return out


# Returns null (use procedural model) or a rig dictionary:
#   {root: Node3D, player: AnimationPlayer|null, names: {logical: anim name}, cur: String}
static func build(kind: String):
	var path := find_file(MODEL_DIR, kind)
	if path == "":
		return null
	var res = load(path)
	if not (res is PackedScene):
		push_warning("Models: cannot load " + path)
		return null
	var inst = res.instantiate()
	if not (inst is Node3D):
		inst.free()
		return null
	var root := Node3D.new()
	root.add_child(inst)
	_fit(inst, float(HEIGHTS.get(kind, 1.8)))
	var rig := {"root": root, "player": null, "names": {}, "cur": ""}

	var ap: AnimationPlayer = null
	var aps: Array = inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
	var skel: Skeleton3D = null
	var sks: Array = inst.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		skel = sks[0]
	if ap == null and skel != null:
		ap = AnimationPlayer.new()
		inst.add_child(ap)
	if ap != null:
		if not _prep.has(kind):
			_prep[kind] = _prepare(kind, ap, skel)
		var prep: Dictionary = _prep[kind]
		var lib: AnimationLibrary
		if ap.has_animation_library(""):
			lib = ap.get_animation_library("")
		else:
			lib = AnimationLibrary.new()
			ap.add_animation_library("", lib)
		for logical in prep.anims:
			var nm: String = "ext_" + logical
			if not lib.has_animation(nm):
				lib.add_animation(nm, prep.anims[logical])
		rig.names = prep.names.duplicate()
		rig.player = ap
	return rig


# Scale so the model has the wanted height, feet on y=0, centred on x/z.
static func _fit(inst: Node3D, height: float) -> void:
	var bb := _aabb(inst, inst.transform)
	if bb.size.y < 0.0001:
		return
	var s := height / bb.size.y
	var c := bb.position + bb.size * 0.5
	var fix := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-c.x * s, -bb.position.y * s, -c.z * s))
	inst.transform = fix * inst.transform


static func _aabb(n: Node3D, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		out = xf * mi.get_aabb()
		have = true
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 == null:
			continue
		var a := _aabb(c3, xf * c3.transform)
		if a.size == Vector3.ZERO:
			continue
		if have:
			out = out.merge(a)
		else:
			out = a
			have = true
	return out


static func _prepare(kind: String, ap: AnimationPlayer, skel: Skeleton3D) -> Dictionary:
	var names := {}
	var anims := {}
	# 1) animations that ship inside the model file
	var list: PackedStringArray = ap.get_animation_list()
	for logical in KEYS:
		for nm in list:
			var low := String(nm).to_lower()
			if low == "reset":
				continue
			var hit := false
			for k in KEYS[logical]:
				if low.contains(k):
					hit = true
					break
			if hit:
				names[logical] = String(nm)
				break
	for logical in LOOPED:
		if names.has(logical):
			var a := ap.get_animation(names[logical])
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
	# 2) external animation files, retargeted onto this skeleton
	if skel != null:
		var root: Node = ap.get_node(ap.root_node)
		var skel_path: NodePath = root.get_path_to(skel)
		var bone_map := {}
		for i in skel.get_bone_count():
			bone_map[_norm(skel.get_bone_name(i))] = i
		for logical in KEYS:
			var src := _ext_anim(kind, logical)
			if src == null:
				continue
			var a := _retarget(src, skel, skel_path, bone_map)
			if a == null:
				continue
			a.loop_mode = Animation.LOOP_LINEAR if logical in LOOPED else Animation.LOOP_NONE
			anims[logical] = a
			names[logical] = "ext_" + logical
	return {"names": names, "anims": anims}


static func _ext_anim(kind: String, logical: String) -> Animation:
	for base in [kind + "_" + logical, logical]:
		var p := find_file(ANIM_DIR, base)
		if p != "":
			return _load_anim(p)
	return null


static func _load_anim(p: String) -> Animation:
	if _anim_cache.has(p):
		return _anim_cache[p]
	var best: Animation = null
	var res = load(p)
	if res is PackedScene:
		var n: Node = res.instantiate()
		for pl in n.find_children("*", "AnimationPlayer", true, false):
			for nm in pl.get_animation_list():
				if String(nm).to_lower() == "reset":
					continue
				var a: Animation = pl.get_animation(nm)
				if a != null and (best == null or a.length > best.length):
					best = a
		n.free()
	elif res is Animation:
		best = res
	if best == null:
		push_warning("Models: no animation found in " + p)
	_anim_cache[p] = best
	return best


static func _norm(s: String) -> String:
	return s.to_lower().replace("mixamorig", "").replace(":", "").replace("_", "").replace(" ", "").replace(".", "")


static func _retarget(src: Animation, skel: Skeleton3D, skel_path: NodePath, bone_map: Dictionary) -> Animation:
	var a: Animation = src.duplicate(true)
	var kept := 0
	var i := a.get_track_count() - 1
	while i >= 0:
		var tt := a.track_get_type(i)
		var sub := String(a.track_get_path(i).get_concatenated_subnames())
		var ok := false
		if sub != "" and (tt == Animation.TYPE_ROTATION_3D or tt == Animation.TYPE_POSITION_3D):
			var key := _norm(sub)
			if bone_map.has(key):
				var bi: int = bone_map[key]
				var is_root: bool = skel.get_bone_parent(bi) == -1 or key == "hips"
				if tt == Animation.TYPE_ROTATION_3D or is_root:
					a.track_set_path(i, NodePath(str(skel_path) + ":" + skel.get_bone_name(bi)))
					ok = true
					if tt == Animation.TYPE_POSITION_3D:
						_scale_pos_track(a, i, skel.get_bone_rest(bi).origin)
		if ok:
			kept += 1
		else:
			a.remove_track(i)
		i -= 1
	if kept == 0:
		push_warning("Models: animation bones do not match the model skeleton")
		return null
	return a


static func _scale_pos_track(a: Animation, ti: int, rest_origin: Vector3) -> void:
	var n := a.track_get_key_count(ti)
	if n == 0:
		return
	var first: Vector3 = a.track_get_key_value(ti, 0)
	var ratio := 1.0
	if absf(first.y) > 0.0001 and absf(rest_origin.y) > 0.0001:
		ratio = rest_origin.y / first.y
	for k in n:
		var v: Vector3 = a.track_get_key_value(ti, k)
		a.track_set_key_value(ti, k, v * ratio)


# ---------------------------------------------------------------- playback
static func has_anim(rig: Dictionary, logical: String) -> bool:
	return rig.player != null and rig.names.has(logical)


static func busy(rig: Dictionary) -> bool:
	return rig.cur == "attack" and rig.player != null and rig.player.is_playing()


# Plays `logical` (with fallbacks) and returns the logical name actually used ("" if none).
static func play(rig: Dictionary, logical: String, restart := false) -> String:
	var ap: AnimationPlayer = rig.player
	if ap == null:
		return ""
	for cand in FALLBACK.get(logical, [logical]):
		if rig.names.has(cand):
			if rig.cur != cand or restart:
				rig.cur = cand
				ap.play(rig.names[cand], 0.15)
				ap.speed_scale = 1.0
			return cand
	return ""
