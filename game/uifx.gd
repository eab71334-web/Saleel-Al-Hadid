extends RefCounted
# Procedural ornate UI frames: gold bevelled border, dark gradient body. Generated once, 9-sliced.

static var _cache := {}
static var _warm := false


# generate the shared HUD button textures once, during the splash, so opening a
# panel never has to paint them (that was the lag on phones)
static func prewarm() -> void:
	if _warm:
		return
	_warm = true
	var col := Color(0.80, 0.60, 0.22)
	for pr in [[0.42, col.lightened(0.45), col.darkened(0.2)], [0.62, col.lightened(0.7), col], [0.85, Color.WHITE, col.lightened(0.3)]]:
		var f: float = pr[0]
		frame(Color(col.r * f, col.g * f, col.b * f, 0.94), Color(col.r * f * 0.45, col.g * f * 0.45, col.b * f * 0.45, 0.96), pr[1], pr[2], 16.0, true)
	for st in ["normal", "hover", "pressed"]:
		button(st)
	panel()


static func _sd(px: float, py: float, w: float, h: float, r: float) -> float:
	var qx := absf(px - w * 0.5) - (w * 0.5 - r)
	var qy := absf(py - h * 0.5) - (h * 0.5 - r)
	var ox := maxf(qx, 0.0)
	var oy := maxf(qy, 0.0)
	return sqrt(ox * ox + oy * oy) + minf(maxf(qx, qy), 0.0) - r


static func frame(top: Color, bot: Color, gold_hi: Color, gold_lo: Color, radius := 16.0, studs := false) -> StyleBoxTexture:
	var key := "%s%s%s%s%s%s" % [top, bot, gold_hi, gold_lo, radius, studs]
	if _cache.has(key):
		return _cache[key].duplicate()
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := _sd(x + 0.5, y + 0.5, n, n, radius)
			var f := float(y) / n
			var c := Color(0, 0, 0, 0)
			if d > 0.5:
				# soft outer shadow
				var sh := clampf(1.0 - (d - 0.5) / 2.0, 0.0, 1.0) * 0.0
				c = Color(0, 0, 0, sh)
			elif d > -2.6:
				c = gold_hi.lerp(gold_lo, f)
				if d > -0.4:
					c.a = clampf((0.5 - d) / 0.9, 0.0, 1.0)
			elif d > -4.0:
				c = Color(0.06, 0.03, 0.02, 0.95)
			elif d > -5.4:
				var hl := Color(1, 0.95, 0.75, 0.30 * (1.0 - f))
				c = top.lerp(hl, hl.a)
			else:
				var base := top.lerp(bot, f)
				# faint parchment grain
				var g := 0.025 * sin(x * 1.7 + y * 0.9) * sin(y * 2.3)
				c = Color(base.r + g, base.g + g, base.b + g, base.a)
			img.set_pixel(x, y, c)
	if studs:
		for p in [Vector2(9, 9), Vector2(n - 10, 9), Vector2(9, n - 10), Vector2(n - 10, n - 10)]:
			for yy in range(-2, 3):
				for xx in range(-2, 3):
					if xx * xx + yy * yy <= 5:
						img.set_pixel(int(p.x) + xx, int(p.y) + yy, gold_hi if (xx + yy) <= 0 else gold_lo)
	var st := StyleBoxTexture.new()
	st.texture = ImageTexture.create_from_image(img)
	var m := 22.0
	st.texture_margin_left = m
	st.texture_margin_right = m
	st.texture_margin_top = m
	st.texture_margin_bottom = m
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	_cache[key] = st
	return st.duplicate()


static func button(state: String) -> StyleBoxTexture:
	match state:
		"hover":
			return frame(Color(0.36, 0.2, 0.09), Color(0.2, 0.1, 0.05), Color(1.0, 0.92, 0.55), Color(0.85, 0.6, 0.2), 16.0, true)
		"pressed":
			return frame(Color(0.5, 0.28, 0.08), Color(0.3, 0.15, 0.04), Color(1, 0.95, 0.65), Color(0.95, 0.7, 0.25), 16.0, true)
		"disabled":
			return frame(Color(0.17, 0.17, 0.19), Color(0.1, 0.1, 0.12), Color(0.45, 0.45, 0.48), Color(0.28, 0.28, 0.3), 16.0, false)
	return frame(Color(0.27, 0.15, 0.08), Color(0.12, 0.06, 0.04), Color(0.95, 0.78, 0.35), Color(0.62, 0.42, 0.14), 16.0, true)


static func panel() -> StyleBoxTexture:
	var s := frame(Color(0.12, 0.09, 0.08, 0.96), Color(0.05, 0.04, 0.05, 0.97), Color(0.9, 0.72, 0.3), Color(0.5, 0.34, 0.12), 20.0, true)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


static func banner_overlay(sz: Vector2, accent: Color) -> Control:
	# thin gold edge for touch buttons drawn over their translucent fill
	var p := Panel.new()
	p.size = sz
	p.position = -sz * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = accent
	s.set_border_width_all(3)
	s.border_width_bottom = 5
	s.set_corner_radius_all(12)
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	s.shadow_size = 6
	p.add_theme_stylebox_override("panel", s)
	return p


# ---------------------------------------------------------------- icons (SVG drawn in code, 64x64 box)
const _ICONS := {
	"coin": '<circle cx="32" cy="32" r="26" fill="#d9a21b" stroke="#7a4e08" stroke-width="4"/><circle cx="32" cy="32" r="17" fill="none" stroke="#fff1a8" stroke-width="3"/><rect x="29" y="20" width="6" height="24" rx="2" fill="#fff1a8"/>',
	"food": '<circle cx="32" cy="36" r="21" fill="#c8302a" stroke="#6a1410" stroke-width="3"/><ellipse cx="25" cy="28" rx="6" ry="9" fill="#ee6a5e" opacity=".7"/><path d="M32 16 Q34 6 42 5 Q42 14 34 17Z" fill="#3f9a3a"/><rect x="30" y="12" width="4" height="9" fill="#4a2a10"/>',
	"wood": '<rect x="6" y="18" width="44" height="28" rx="4" fill="#8a5a2b" stroke="#4a2c10" stroke-width="3"/><ellipse cx="50" cy="32" rx="9" ry="14" fill="#d9a86a" stroke="#4a2c10" stroke-width="3"/><ellipse cx="50" cy="32" rx="4" ry="7" fill="none" stroke="#8a5a2b" stroke-width="2"/><path d="M12 26H40M12 38H40" stroke="#5e3b19" stroke-width="2"/>',
	"stone": '<path d="M8 46 L16 22 L34 12 L52 22 L58 46Z" fill="#9aa0a8" stroke="#3d4249" stroke-width="3" stroke-linejoin="round"/><path d="M16 22 L30 30 L34 12M30 30 L38 46M52 22 L38 30" stroke="#5b616a" stroke-width="2" fill="none"/>',
	"iron": '<path d="M10 40 L18 22 H50 L58 40Z" fill="#6f84a0" stroke="#27323f" stroke-width="3" stroke-linejoin="round"/><path d="M10 40 H58 V48 H10Z" fill="#4a5a70" stroke="#27323f" stroke-width="3"/><path d="M22 27H44" stroke="#b9c8dc" stroke-width="3"/>',
	"grain": '<path d="M32 58 V20" stroke="#8a6a1a" stroke-width="3"/><g fill="#e6b92e" stroke="#8a6a1a" stroke-width="1.5"><ellipse cx="25" cy="22" rx="5" ry="9" transform="rotate(-25 25 22)"/><ellipse cx="39" cy="22" rx="5" ry="9" transform="rotate(25 39 22)"/><ellipse cx="25" cy="36" rx="5" ry="9" transform="rotate(-25 25 36)"/><ellipse cx="39" cy="36" rx="5" ry="9" transform="rotate(25 39 36)"/><ellipse cx="32" cy="10" rx="5" ry="9"/></g>',
	"flour": '<path d="M18 14 H46 L52 54 H12Z" fill="#efe7d2" stroke="#7a6a48" stroke-width="3" stroke-linejoin="round"/><path d="M18 14 Q32 24 46 14" fill="#cfc4a6" stroke="#7a6a48" stroke-width="3"/><circle cx="32" cy="38" r="7" fill="#c9a24a"/>',
	"pop": '<circle cx="22" cy="20" r="9" fill="#e0b58f" stroke="#6b4a2c" stroke-width="3"/><path d="M6 54 Q6 32 22 32 Q38 32 38 54Z" fill="#4a7ac8" stroke="#1d3560" stroke-width="3"/><circle cx="43" cy="24" r="7" fill="#e0b58f" stroke="#6b4a2c" stroke-width="3"/><path d="M34 54 Q36 38 46 38 Q58 38 58 54Z" fill="#c8884a" stroke="#6b4018" stroke-width="3"/>',
	"vill": '<path d="M12 24 H52 L44 12 H20Z" fill="#c9a24a" stroke="#6b4a18" stroke-width="3" stroke-linejoin="round"/><circle cx="32" cy="34" r="10" fill="#e0b58f" stroke="#6b4a2c" stroke-width="3"/><path d="M10 58 Q12 46 32 46 Q52 46 54 58Z" fill="#7a9a4a" stroke="#3a4a1c" stroke-width="3"/>',
	"level": '<path d="M8 50 L12 20 L24 34 L32 12 L40 34 L52 20 L56 50Z" fill="#e6b52a" stroke="#7a4e08" stroke-width="3" stroke-linejoin="round"/><rect x="8" y="50" width="48" height="8" rx="2" fill="#c48f14" stroke="#7a4e08" stroke-width="3"/><circle cx="32" cy="42" r="4" fill="#d02a3a"/>',
	"heart": '<path d="M32 56 C6 38 6 14 20 12 C27 11 31 16 32 20 C33 16 37 11 44 12 C58 14 58 38 32 56Z" fill="#d8283a" stroke="#6a0f1a" stroke-width="3" stroke-linejoin="round"/><ellipse cx="21" cy="22" rx="5" ry="4" fill="#ff8d98" opacity=".7"/>',
	"sword": '<path d="M50 6 L58 6 L58 14 L26 46 L18 38Z" fill="#dfe5ee" stroke="#4a5666" stroke-width="3" stroke-linejoin="round"/><path d="M14 34 L30 50 M10 54 L22 42" stroke="#c8962a" stroke-width="6" stroke-linecap="round"/><circle cx="8" cy="56" r="4" fill="#c8962a"/>',
	"bow": '<path d="M18 6 Q56 32 18 58" fill="none" stroke="#8a5a2b" stroke-width="6" stroke-linecap="round"/><path d="M18 6 V58" stroke="#e8e2d0" stroke-width="2"/><path d="M6 32 H50" stroke="#c8c2b0" stroke-width="3"/><path d="M50 32 L42 26 M50 32 L42 38" stroke="#c8c2b0" stroke-width="3" fill="none"/>',
	"horse": '<path d="M16 58 L20 34 L12 24 L22 6 L30 14 L40 10 L54 28 L50 38 L38 36 L34 46 L38 58Z" fill="#8a5a2b" stroke="#3d240e" stroke-width="3" stroke-linejoin="round"/><circle cx="38" cy="22" r="3" fill="#fff"/><path d="M22 8 L30 30" stroke="#2a180a" stroke-width="5"/>',
	"boot": '<path d="M20 8 H38 V30 L56 40 Q60 46 56 52 H16 Q10 52 12 44Z" fill="#7a4a22" stroke="#33190a" stroke-width="3" stroke-linejoin="round"/><path d="M20 20 H38" stroke="#d9a21b" stroke-width="4"/><path d="M14 52 H58" stroke="#33190a" stroke-width="5"/>',
	"target": '<circle cx="32" cy="32" r="22" fill="none" stroke="#e8453c" stroke-width="5"/><circle cx="32" cy="32" r="11" fill="none" stroke="#e8453c" stroke-width="4"/><circle cx="32" cy="32" r="3.5" fill="#e8453c"/><path d="M32 2 V14 M32 50 V62 M2 32 H14 M50 32 H62" stroke="#f4d98a" stroke-width="4" stroke-linecap="round"/>',
	"shield": '<path d="M32 4 L56 12 V32 Q56 50 32 60 Q8 50 8 32 V12Z" fill="#3f6fb5" stroke="#1d3358" stroke-width="3.5" stroke-linejoin="round"/><path d="M32 8 V56 M10 30 H54" stroke="#e8c35a" stroke-width="5"/>',
	"flag": '<path d="M14 6 V60" stroke="#6b4a2c" stroke-width="5" stroke-linecap="round"/><path d="M16 8 H54 L46 22 L54 36 H16Z" fill="#d02a3a" stroke="#6a0f1a" stroke-width="3" stroke-linejoin="round"/>',
	"gear": '<path d="M28 4 h8 l2 8 l6 3 l7 -4 l6 6 l-4 7 l3 6 l8 2 v8 l-8 2 l-3 6 l4 7 l-6 6 l-7 -4 l-6 3 l-2 8 h-8 l-2 -8 l-6 -3 l-7 4 l-6 -6 l4 -7 l-3 -6 l-8 -2 v-8 l8 -2 l3 -6 l-4 -7 l6 -6 l7 4 l6 -3Z" transform="translate(32 32) scale(.9) translate(-32 -32)" fill="#c8a24a" stroke="#5a3c0c" stroke-width="3" stroke-linejoin="round"/><circle cx="32" cy="32" r="10" fill="#2a1c0c" stroke="#5a3c0c" stroke-width="3"/>',
	"mount": '<path d="M10 54 Q10 30 32 30 Q54 30 54 54Z" fill="#8a5a2b" stroke="#3d240e" stroke-width="3"/><path d="M26 30 L22 10 L40 12 L42 30" fill="#a8743a" stroke="#3d240e" stroke-width="3"/>',
	"army": '<path d="M32 4 L56 12 V32 Q56 50 32 60 Q8 50 8 32 V12Z" fill="#2c5fc8" stroke="#10285c" stroke-width="3" stroke-linejoin="round"/><path d="M32 14 V50 M18 28 H46" stroke="#f1d27a" stroke-width="6" stroke-linecap="round"/>',
	"foe": '<path d="M32 4 L56 12 V32 Q56 50 32 60 Q8 50 8 32 V12Z" fill="#b8282a" stroke="#4a0c0e" stroke-width="3" stroke-linejoin="round"/><path d="M20 20 L44 44 M44 20 L20 44" stroke="#f3e2c0" stroke-width="6" stroke-linecap="round"/>',
	"house": '<path d="M6 32 L32 8 L58 32Z" fill="#b8402a" stroke="#4a140a" stroke-width="3" stroke-linejoin="round"/><rect x="12" y="32" width="40" height="24" fill="#e0c9a0" stroke="#6b4a2c" stroke-width="3"/><rect x="27" y="40" width="10" height="16" fill="#6b4a2c"/>',
	"hammer": '<rect x="28" y="22" width="8" height="38" rx="2" fill="#8a5a2b" stroke="#3d240e" stroke-width="3"/><rect x="10" y="8" width="44" height="18" rx="3" fill="#9aa4b4" stroke="#2f3846" stroke-width="3"/>',
	"map": '<path d="M6 12 L22 6 L42 12 L58 6 V52 L42 58 L22 52 L6 58Z" fill="#e6d3a2" stroke="#6b4a2c" stroke-width="3" stroke-linejoin="round"/><path d="M22 6 V52 M42 12 V58" stroke="#8a6a3a" stroke-width="2"/><path d="M28 30 L36 38 M36 30 L28 38" stroke="#c02a2a" stroke-width="4" stroke-linecap="round"/>',
	"advisor": '<path d="M10 58 Q10 38 32 38 Q54 38 54 58Z" fill="#7a3ab8" stroke="#2c0f52" stroke-width="3"/><circle cx="32" cy="26" r="11" fill="#e0b58f" stroke="#6b4a2c" stroke-width="3"/><path d="M18 20 L32 2 L46 20Z" fill="#5a2a98" stroke="#2c0f52" stroke-width="3" stroke-linejoin="round"/><path d="M24 32 Q32 44 40 32" fill="#e8e8e8" stroke="#8a8a8a" stroke-width="2"/>',
	"talk": '<rect x="6" y="14" width="52" height="36" rx="4" fill="#efe3c0" stroke="#6b4a2c" stroke-width="3"/><path d="M6 16 L32 36 L58 16" fill="none" stroke="#6b4a2c" stroke-width="3"/><circle cx="32" cy="38" r="5" fill="#c02a2a"/>',
	"city": '<rect x="6" y="26" width="14" height="32" fill="#a8a29a" stroke="#3d3a36" stroke-width="3"/><rect x="44" y="26" width="14" height="32" fill="#a8a29a" stroke="#3d3a36" stroke-width="3"/><rect x="18" y="34" width="28" height="24" fill="#c8c2b6" stroke="#3d3a36" stroke-width="3"/><path d="M4 26 L13 8 L22 26Z M42 26 L51 8 L60 26Z" fill="#b8402a" stroke="#4a140a" stroke-width="3" stroke-linejoin="round"/><path d="M26 58 V46 Q32 38 38 46 V58Z" fill="#3a2410"/>',
	"season": '<circle cx="32" cy="32" r="12" fill="#f1c232" stroke="#8a6a08" stroke-width="3"/><path d="M32 6V14M32 50V58M6 32H14M50 32H58M14 14L20 20M44 44L50 50M14 50L20 44M44 20L50 14" stroke="#f1c232" stroke-width="4" stroke-linecap="round"/>',
}


static func icon(name: String, px := 48) -> Texture2D:
	var key := "ic_%s_%d" % [name, px]
	if _cache.has(key):
		return _cache[key]
	if not _ICONS.has(name):
		return null
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">%s</svg>' % _ICONS[name]
	var img := Image.new()
	var sc := float(px) / 64.0
	if img.load_svg_from_string(svg, sc) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# dark glass plate with a thin gold edge, for resource chips and status pills
static func plate(radius := 12.0, alpha := 0.78) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.05, 0.05, alpha)
	s.border_color = Color(0.85, 0.66, 0.28, 0.95)
	s.set_border_width_all(2)
	s.border_width_bottom = 3
	s.set_corner_radius_all(int(radius))
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 5
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# a chip: [icon] [value]; returns {"box": Control, "lbl": Label}
static func chip(icon_name: String, u: float, w: float, tint := Color(1, 0.95, 0.8)) -> Dictionary:
	var pc := PanelContainer.new()
	var st := plate(10.0 * u, 0.72)
	st.content_margin_left = 6 * u
	st.content_margin_right = 8 * u
	st.content_margin_top = 2 * u
	st.content_margin_bottom = 2 * u
	pc.add_theme_stylebox_override("panel", st)
	pc.custom_minimum_size = Vector2(w * u, 30 * u)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(5 * u))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var tr := TextureRect.new()
	tr.texture = icon(icon_name, int(40 * u))
	tr.custom_minimum_size = Vector2(24, 24) * u
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tr)
	var lb := Label.new()
	lb.text = "0"
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lb.add_theme_font_size_override("font_size", int(19 * u))
	lb.add_theme_color_override("font_color", tint)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("outline_size", int(4 * u))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)
	return {"box": pc, "lbl": lb, "icon": tr}


static func style_btn(b: Button, u: float, icon_name := "") -> void:
	# ONE house style for every HUD button (the old per-button colours looked messy
	# and each new colour re-generated 3 textures = lag on phones)
	var col := Color(0.80, 0.60, 0.22)
	var fm := func(f: float, hi: Color, lo: Color) -> StyleBoxTexture:
		var s: StyleBoxTexture = frame(Color(col.r * f, col.g * f, col.b * f, 0.94), Color(col.r * f * 0.45, col.g * f * 0.45, col.b * f * 0.45, 0.96), hi, lo, 16.0, true)
		s.content_margin_left = 10 * u
		s.content_margin_right = 10 * u
		s.content_margin_top = 6 * u
		s.content_margin_bottom = 6 * u
		return s
	b.add_theme_stylebox_override("normal", fm.call(0.42, col.lightened(0.45), col.darkened(0.2)))
	b.add_theme_stylebox_override("hover", fm.call(0.62, col.lightened(0.7), col))
	b.add_theme_stylebox_override("pressed", fm.call(0.85, Color.WHITE, col.lightened(0.3)))
	b.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", int(4 * u))
	b.add_theme_font_size_override("font_size", int(22 * u))
	if icon_name != "":
		b.icon = icon(icon_name, int(48 * u))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(28 * u))
		b.add_theme_constant_override("h_separation", int(6 * u))
