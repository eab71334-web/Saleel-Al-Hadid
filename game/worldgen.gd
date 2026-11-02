extends RefCounted
# Open world: terrain height function, colours, lord castles, overview map image.
# The world is 8 km x 8 km (x, z in -4000 .. 4000), an island continent with lakes, hills and mountains.

const HALF := 4000.0
const CHUNK := 128.0
const MAP_PX := 256
const NAMES := ["Lord Harun", "Lady Mariam", "Baron Idris", "Count Salim", "Duke Tariq", "Lord Fahd", "Lady Noura", "Baron Khalid", "Count Yusuf", "Duke Jabir", "Lord Rashid", "Lady Layla", "Baron Omar", "Count Zaid", "Duke Anwar", "Lord Hamza", "Lady Sara", "Baron Nabil"]

static var _n: FastNoiseLite
static var _d: FastNoiseLite
static var _f: FastNoiseLite
static var sites: Array = []        # {x, z, h, in, out}
static var _map: Image = null


static func init_noise() -> void:
	if _n != null:
		return
	_n = FastNoiseLite.new()
	_n.seed = 4242
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.fractal_type = FastNoiseLite.FRACTAL_FBM
	_n.fractal_octaves = 5
	_n.frequency = 0.00052
	_d = FastNoiseLite.new()
	_d.seed = 99
	_d.frequency = 0.02
	_f = FastNoiseLite.new()
	_f.seed = 7
	_f.frequency = 0.0028
	_f.fractal_octaves = 3


static func h0(x: float, z: float) -> float:
	var n: float = _n.get_noise_2d(x, z)
	var r := sqrt(x * x + z * z)
	var edge := smoothstep(2900.0, 3900.0, r)
	var h: float = 30.0 + n * 85.0 + _d.get_noise_2d(x, z) * 3.0
	h -= edge * 110.0
	return h


static func forest(x: float, z: float) -> float:
	return _f.get_noise_2d(x, z)


static func h(x: float, z: float, local: Array = []) -> float:
	var v := h0(x, z)
	var src: Array = local if not local.is_empty() else sites
	for s in src:
		var dx: float = x - float(s.x)
		var dz: float = z - float(s.z)
		var d2 := dx * dx + dz * dz
		var o: float = s.out
		if d2 < o * o:
			var t := smoothstep(o, float(s.in), sqrt(d2))
			v = lerpf(v, float(s.h), t)
	return v


static func add_site(x: float, z: float) -> void:
	for s in sites:
		if absf(float(s.x) - x) < 1.0 and absf(float(s.z) - z) < 1.0:
			return
	sites.append({"x": x, "z": z, "h": maxf(h0(x, z), 3.0), "in": 75.0, "out": 160.0})


static func near_sites(x: float, z: float, r: float) -> Array:
	var out: Array = []
	for s in sites:
		if absf(float(s.x) - x) < r + 160.0 and absf(float(s.z) - z) < r + 160.0:
			out.append(s)
	return out


static func slope(x: float, z: float) -> float:
	var e := 6.0
	var dx := h0(x + e, z) - h0(x - e, z)
	var dz := h0(x, z + e) - h0(x, z - e)
	return sqrt(dx * dx + dz * dz) / (2.0 * e)


static func ground_col(hv: float, sl: float, x: float, z: float) -> Color:
	var v: float = _d.get_noise_2d(x * 3.0, z * 3.0) * 0.05
	if hv < 1.5:
		return Color(0.74 + v, 0.68 + v, 0.48)
	if sl > 0.62 or hv > 95.0:
		var g := 0.42 + v
		if hv > 110.0:
			return Color(0.92, 0.93, 0.97)
		return Color(g, g * 0.97, g * 0.92)
	var t := clampf((hv - 4.0) / 70.0, 0.0, 1.0)
	var low := Color(0.16 + v, 0.34 + v, 0.11)
	var high := Color(0.27 + v, 0.31 + v, 0.15)
	return low.lerp(high, t)


static func valid_site(x: float, z: float) -> String:
	var hv := h0(x, z)
	if sqrt(x * x + z * z) > 3300.0:
		return "Too close to the sea"
	if hv < 4.0:
		return "Water - choose dry land"
	if hv > 60.0 or slope(x, z) > 0.3:
		return "Too steep - choose flatter ground"
	for s in sites:
		var dx: float = x - float(s.x)
		var dz: float = z - float(s.z)
		if dx * dx + dz * dz < 420.0 * 420.0:
			return "Too close to another castle"
	return ""


static func gen_lords() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out: Array = []
	var tries := 0
	while out.size() < 18 and tries < 900:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 3100.0
		var x := sin(a) * r
		var z := cos(a) * r
		var ok := true
		if h0(x, z) < 5.0 or h0(x, z) > 52.0 or slope(x, z) > 0.28:
			ok = false
		for o in out:
			var dx: float = x - float(o.x)
			var dz: float = z - float(o.z)
			if dx * dx + dz * dz < 520.0 * 520.0:
				ok = false
		if sqrt(x * x + z * z) < 500.0:
			ok = false
		if ok:
			out.append({"name": NAMES[out.size() % NAMES.size()], "x": x, "z": z, "level": 1 + rng.randi() % 5, "banner": rng.randi() % 7, "emblem": rng.randi() % 5, "owner": "ai"})
	return out


# colour overview of the whole world (one pixel = 31 m)
static func map_image() -> Image:
	if _map != null:
		return _map
	init_noise()
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGB8)
	for py in MAP_PX:
		for px in MAP_PX:
			var x := (float(px) / MAP_PX - 0.5) * HALF * 2.0
			var z := (float(py) / MAP_PX - 0.5) * HALF * 2.0
			var hv := h0(x, z)
			var c: Color
			if hv < 0.0:
				c = Color(0.1, 0.26, 0.45).lerp(Color(0.16, 0.38, 0.6), clampf((hv + 40.0) / 40.0, 0.0, 1.0))
			elif hv < 2.0:
				c = Color(0.78, 0.72, 0.5)
			else:
				c = ground_col(hv, slope(x, z) * 0.7, x, z)
				var shade := 0.82 + 0.35 * clampf((h0(x - 31.0, z - 31.0) - hv) / 14.0 + 0.5, 0.0, 1.0) * 0.5
				c = Color(c.r * shade, c.g * shade, c.b * shade)
				if forest(x, z) > 0.08 and hv < 55.0:
					c = c.lerp(Color(0.08, 0.26, 0.1), 0.45)
			img.set_pixel(px, py, c)
	_map = img
	return img


static func w2m(x: float, z: float) -> Vector2:
	return Vector2((x / (HALF * 2.0) + 0.5) * MAP_PX, (z / (HALF * 2.0) + 0.5) * MAP_PX)


static func m2w(p: Vector2) -> Vector2:
	return Vector2((p.x / MAP_PX - 0.5) * HALF * 2.0, (p.y / MAP_PX - 0.5) * HALF * 2.0)
