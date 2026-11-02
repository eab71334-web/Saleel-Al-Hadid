extends Node
const AttackDlgS := preload("res://game/attackdlg.gd")
const LocS := preload("res://game/loc.gd")
# Fog of war + the war map (top-down map where you place your groups and set the garrison).

var kingdom
var battle
var map: Control
var dim: ColorRect
var is_open := false
var fog_t := 0.0
var pings := []                 # {pos, t}
var last_seen := {}             # uid -> {pos, t, kind}
var sel_mask := 7
var station_mode := false
var gar_pct := 0
var chips := []
var gsel := 0                    # selected groups (bit g-1); 0 = orders go to the kinds
var n_split := 2
var gchips := []
var split_lbl: Button
var _gt := 0.0
const GCOL := [Color(1, 0.45, 0.35), Color(0.4, 0.8, 1), Color(0.5, 1, 0.5), Color(1, 0.85, 0.3), Color(0.85, 0.55, 1), Color(1, 0.6, 0.85)]
var info: Label
var btn_station: Button
var gar_btns := []
var flags := {}                 # kind -> Vector3 (my own station flags, for drawing)
var _dot := 3.0
var zoom := 1.0
var center := Vector2.ZERO      # centre of the view in 'my rotated' world coords (x, z)
var touches := {}
var _touch_mode := false
var _moved := 0.0
var _press_pos := Vector2.ZERO
var _pinch_d := 0.0
var t_anim := 0.0
var atk: Control
var krows := {}
var _u := 1.0
var trails := {}
var _open_tw: Tween

const VIS_SOLDIER := 34.0
const VIS_KING := 42.0
const VIS_VILLAGER := 12.0
const VIS_TOWER := 46.0


# ================================================================== fog of war
func vision_sources() -> Array:
	var out := []
	var t: int = kingdom.vteam()
	for u in battle.units.values():
		if u.team != t or u.dead:
			continue
		var r := VIS_SOLDIER
		if u.kind == "hero":
			r = VIS_KING
		elif u.kind == "villager":
			r = VIS_VILLAGER
		out.append([u.position, r])
	if not kingdom.fallen[t]:
		for sx in [-36.0, 0.0, 36.0]:
			out.append([kingdom.lw(t, Vector3(sx, 0, -73.0)), VIS_TOWER])
		out.append([kingdom.lw(t, Vector3(0, 0, -100.0)), 40.0])
	return out


func can_see(p: Vector3, srcs: Array) -> bool:
	for s in srcs:
		var sp: Vector3 = s[0]
		var r: float = s[1]
		var dx := sp.x - p.x
		var dz := sp.z - p.z
		if dx * dx + dz * dz < r * r:
			return true
	return false


func update_fog() -> void:
	var srcs := vision_sources()
	var t: int = kingdom.vteam()
	for u in battle.units.values():
		if u.team == t or battle.reveal:
			if not u.visible:
				u.visible = true
			continue
		var vis: bool = can_see(u.position, srcs) and not u.dead
		if u.dead:
			vis = can_see(u.position, srcs)
		if u.visible != vis:
			u.visible = vis
		if vis and not u.dead:
			last_seen[u.uid] = {"pos": u.position, "t": battle.game_time, "kind": u.kind, "team": u.team}
	# forget old sightings
	for k in last_seen.keys():
		if battle.game_time - float(last_seen[k].t) > 25.0:
			last_seen.erase(k)


func enemy_sightings() -> Array:
	var out := []
	for k in last_seen.keys():
		var e: Dictionary = last_seen[k]
		if e.kind != "villager":
			out.append(e)
	return out


func _refresh_groups() -> void:
	var have := 0
	var vt: int = kingdom.vteam()
	for u in battle.units.values():
		if u.team == vt and u.grp > 0 and not u.dead:
			have |= 1 << (u.grp - 1)
	for i in gchips.size():
		var on: bool = (have & (1 << i)) != 0
		gchips[i].visible = on
		if not on and (gsel & (1 << i)) != 0:
			gsel &= ~(1 << i)
			gchips[i].set_pressed_no_signal(false)


func add_ping(pos: Vector3) -> void:
	pings.append({"pos": pos, "t": 0.0})
	if pings.size() > 6:
		pings.pop_front()


func _process(dt: float) -> void:
	if kingdom == null or battle == null or not kingdom.vis_ready:
		return
	fog_t -= dt
	if fog_t <= 0.0:
		fog_t = 0.25
		update_fog()
	_gt -= dt
	if _gt <= 0.0:
		_gt = 0.4
		_refresh_groups()
	for p in pings:
		p.t += dt
	while not pings.is_empty() and pings[0].t > 40.0:
		pings.pop_front()
	if is_open and map != null:
		map.queue_redraw()


# ================================================================== map coordinates
func extents() -> Vector2:
	if battle.sea:
		var es: float = battle.coast_r + 60.0
		return Vector2(es, es)
	if battle.nk > 2:
		var e: float = battle.ring_r + 55.0 + battle.HINT
		return Vector2(e, e)
	return Vector2(100.0, 140.0 + battle.HINT)


func _k() -> float:
	var ex := extents()
	return minf(map.size.x / (2.0 * ex.x), map.size.y / (2.0 * ex.y)) * zoom


func _rot(p: Vector3) -> Vector2:
	var a: Vector3 = Basis(Vector3.UP, -kingdom.ang(kingdom.vteam())) * p
	return Vector2(a.x, a.z)


func w2m(p: Vector3) -> Vector2:
	var a := _rot(p)
	return map.size * 0.5 + Vector2(a.x - center.x, -(a.y - center.y)) * _k()


func m2w(q: Vector2) -> Vector3:
	var d := (q - map.size * 0.5) / _k()
	var ax := d.x + center.x
	var az := -d.y + center.y
	return Basis(Vector3.UP, kingdom.ang(kingdom.vteam())) * Vector3(ax, 0.0, az)


func _clamp_view() -> void:
	zoom = clampf(zoom, 0.8, 7.0)
	var ex := extents()
	center.x = clampf(center.x, -ex.x, ex.x)
	center.y = clampf(center.y, -ex.y, ex.y)


func focus(p: Vector3, z := -1.0) -> void:
	center = _rot(p)
	if z > 0.0:
		zoom = z
	_clamp_view()


func _zoom_at(factor: float, at: Vector2) -> void:
	var before := m2w(at)
	zoom *= factor
	zoom = clampf(zoom, 0.8, 7.0)
	var after := _rot(before)
	var d := (at - map.size * 0.5) / _k()
	center = Vector2(after.x - d.x, after.y + d.y)
	_clamp_view()


# ================================================================== UI
func _sbx(c: Color, b: Color, r := 10.0, bw := 2.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = b
	sb.set_border_width_all(int(bw * _u))
	sb.set_corner_radius_all(int(r * _u))
	sb.content_margin_left = 10 * _u
	sb.content_margin_right = 10 * _u
	sb.content_margin_top = 4 * _u
	sb.content_margin_bottom = 4 * _u
	return sb


func _btn(parent: Control, text: String, w: float, cb: Callable, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(w, 54) * _u
	if toggle:
		b.toggled.connect(cb)
	else:
		b.pressed.connect(cb)
	b.add_theme_font_size_override("font_size", int(20 * _u))
	kingdom.style_btn(b, Color.WHITE, _u)
	parent.add_child(b)
	return b


func build_ui(root: Control, u: float, vs: Vector2) -> void:
	_u = u
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 40
	dim.visible = false
	root.add_child(dim)
	var mr := 6.0 * u
	var bar_h := 128.0 * u
	map = Control.new()
	map.position = Vector2(mr, mr)
	map.size = Vector2(vs.x - 2 * mr, vs.y - 2 * mr - bar_h - 6 * u)
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	map.draw.connect(_draw_map)
	map.gui_input.connect(_map_input)
	dim.add_child(map)
	# top-right tools
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", int(8 * u))
	tools.position = Vector2(map.size.x - 66 * u, 10 * u)
	map.add_child(tools)
	var tb := func(text: String, cb: Callable):
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(58, 58) * u
		b.pressed.connect(cb)
		kingdom.style_btn(b, Color.WHITE, u)
		tools.add_child(b)
	tb.call("X", close)
	tb.call("+", func(): _zoom_at(1.4, map.size * 0.5))
	tb.call("-", func(): _zoom_at(1.0 / 1.4, map.size * 0.5))
	tb.call("O", func():
		focus(kingdom.home_pos(kingdom.vteam()) if not kingdom.fallen[kingdom.vteam()] else Vector3.ZERO, 1.4))
	# kingdoms list (tap = fly to it / attack)
	var kl := VBoxContainer.new()
	kl.position = Vector2(10, 10) * u
	kl.add_theme_constant_override("separation", int(5 * u))
	map.add_child(kl)
	for i in battle.nk:
		var kb := Button.new()
		kb.custom_minimum_size = Vector2(250, 48) * u
		kb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tt: int = i
		kb.pressed.connect(func():
			focus(kingdom.lw(tt, Vector3(0, 0, -95.0)), 2.2))
		kingdom.style_btn(kb, Color.WHITE, u)
		kb.add_theme_font_size_override("font_size", int(18 * u))
		kl.add_child(kb)
		krows[i] = kb
	info = Label.new()
	info.position = Vector2(map.size.x * 0.5 - 300 * u, 8 * u)
	info.custom_minimum_size = Vector2(600, 40) * u
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", int(20 * u))
	info.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", int(6 * u))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(info)
	# bottom bar: category tabs + ONE row of buttons at a time (fits any phone width)
	var tabs_h := 50.0 * u
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", preload("res://game/uifx.gd").plate(14.0, 0.92))
	bar.position = Vector2(mr, vs.y - mr - bar_h)
	bar.size = Vector2(vs.x - 2 * mr, bar_h)
	dim.add_child(bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(4 * u))
	bar.add_child(col)
	var tabrow := HBoxContainer.new()
	tabrow.add_theme_constant_override("separation", int(6 * u))
	col.add_child(tabrow)
	var rows := []
	var tabs := []
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 58 * u)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var tab_names := ["TROOPS", "GROUPS", "FORMATION", "POSITION", "GUARD"]
	for ti in tab_names.size():
		var rw := HBoxContainer.new()
		rw.add_theme_constant_override("separation", int(8 * u))
		rw.visible = ti == 0
		rows.append(rw)
		sc.add_child(rw)
		var tbtn := _btn(tabrow, tab_names[ti], 150, func(): pass, false)
		tbtn.custom_minimum_size = Vector2(150, 42) * u
		tbtn.toggle_mode = true
		tbtn.button_pressed = ti == 0
		tabs.append(tbtn)
		var tix: int = ti
		tbtn.pressed.connect(func():
			for j in rows.size():
				rows[j].visible = j == tix
				tabs[j].set_pressed_no_signal(j == tix)
			sc.scroll_horizontal = 0)
	var row: HBoxContainer = rows[0]
	var names := ["SWORDS", "ARCHERS", "CAVALRY"]
	for i in 3:
		var bit := 1 << i
		var b := _btn(row, names[i], 130, func(on):
			if on:
				sel_mask |= bit
			else:
				sel_mask &= ~bit
			if sel_mask == 0:
				sel_mask = bit
				chips[i].set_pressed_no_signal(true), true)
		b.button_pressed = true
		chips.append(b)
	row = rows[1]
	# --- groups: split the chosen kinds into N groups, then command groups one by one
	_btn(row, "-", 54, func():
		n_split = maxi(2, n_split - 1)
		split_lbl.text = "Groups: %d" % n_split)
	split_lbl = _btn(row, "Groups: 2", 130, func(): pass)
	_btn(row, "+", 54, func():
		n_split = mini(6, n_split + 1)
		split_lbl.text = "Groups: %d" % n_split)
	_btn(row, "SPLIT", 120, func():
		battle.split_groups(sel_mask, n_split)
		gsel = 0
		flags.clear()
		info.text = "Soldiers split into %d groups. Tap G1, G2... to command each group." % n_split)
	_btn(row, "MERGE", 120, func():
		battle.split_groups(sel_mask, 1)
		gsel = 0
		for kk in flags.keys().duplicate():
			if String(kk).begins_with("G"):
				flags.erase(kk)
		info.text = "Groups merged back.")
	for gi in 6:
		var gb := _btn(row, "G%d" % (gi + 1), 84, func(on):
			if on:
				gsel |= 1 << gi
			else:
				gsel &= ~(1 << gi), true)
		gb.add_theme_color_override("font_color", GCOL[gi])
		gb.add_theme_color_override("font_pressed_color", GCOL[gi])
		gb.visible = false
		gchips.append(gb)
	row = rows[2]
	var fnames := ["LINE", "COLUMN", "WEDGE", "RING"]
	for fi in 4:
		var fm: int = fi + 1
		_btn(row, fnames[fi], 120, func():
			battle.set_form(gsel, sel_mask if gsel == 0 else 0, fm)
			info.text = "Formation ordered. They hold it where they stand or at the spot you pick.")
	_btn(row, "FREE", 100, func():
		battle.set_form(gsel, sel_mask if gsel == 0 else 0, 0)
		info.text = "Formation released.")
	if battle.sea:
		_btn(row, "LOAD TROOPS", 190, func():
			battle.load_cmd()
			info.text = "Soldiers near your troop ships board them.")
		_btn(row, "LAND TROOPS", 190, func():
			battle.unload_cmd()
			info.text = "Troop ships land the soldiers on the nearest shore.")
	row = rows[3]
	var presets := [["AT THE GATE", -62.0], ["IN FRONT", -40.0], ["MIDFIELD", -8.0], ["ON THE WALLS", -80.0]]
	for pr in presets:
		var lz: float = pr[1]
		_btn(row, pr[0], 170, func(): _station_preset(lz))
	btn_station = _btn(row, "STATION: tap the map", 230, func(on): station_mode = on, true)
	_btn(row, "RETURN to the castle", 230, func():
		battle.strike(-2, 0, 0, 0)
		battle.order_at(4, sel_mask, kingdom.home_pos(kingdom.vteam()), -1)
		if gsel != 0:
			battle.order_group(gsel, 4, kingdom.home_pos(kingdom.vteam()), -1)
		flags.clear()
		info.text = "Orders given: return home.")
	row = rows[4]
	for pc in [0, 25, 50, 75]:
		var v: int = pc
		var b2 := _btn(row, "Guard %d%%" % pc, 130, func(): set_garrison(v))
		b2.toggle_mode = true
		gar_btns.append(b2)
	atk = null
	var dlg := AttackDlgS.new()
	dlg.kingdom = kingdom
	dlg.battle = battle
	dlg.mapv = self
	root.add_child(dlg)
	dlg.build(u, vs)
	dlg.z_index = 70
	atk = dlg
	_dot = 4.0 * u
	set_garrison(0, false)


func _station_preset(lz: float) -> void:
	var vt: int = kingdom.vteam()
	_station_at(kingdom.lw(vt, Vector3(0, 0, lz)))


func _station_at(w: Vector3) -> void:
	if gsel != 0:
		battle.order_group(gsel, 2, w, -1)
		for g in 6:
			if (gsel & (1 << g)) != 0:
				flags["G%d" % (g + 1)] = w
	else:
		battle.order_at(2, sel_mask, w, -1)
		var ks := ["sword", "archer", "cav"]
		for i in 3:
			if (sel_mask & (1 << i)) != 0:
				flags[ks[i]] = w
	info.text = "Groups are moving to that spot and will hold it."


func set_garrison(pc: int, send := true) -> void:
	gar_pct = pc
	for i in gar_btns.size():
		gar_btns[i].set_pressed_no_signal([0, 25, 50, 75][i] == pc)
	if send:
		battle.order_at(2, 0, Vector3.ZERO, pc)
		info.text = "%d%% of your soldiers will stay and guard the castle." % pc


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if battle.modal and not is_open:
		return
	is_open = true
	dim.visible = true
	battle.modal = true
	# the king takes the folded map from his pocket and unfolds it; the chart fades in over his hands
	var kh = battle.heroes.get(battle.my_id)
	dim.modulate.a = 1.0
	if kh != null and kh.rigged and not kh.dead and battle.kingdom != null and not kh.mounted:
		kh.map_want = true
		dim.modulate.a = 0.0
		if _open_tw != null and _open_tw.is_valid():
			_open_tw.kill()
		_open_tw = dim.create_tween()
		_open_tw.tween_interval(1.9)
		_open_tw.tween_property(dim, "modulate:a", 1.0, 0.45)
	zoom = 1.0
	center = Vector2.ZERO
	var n := enemy_sightings().size()
	info.text = ("Tap an enemy castle to attack, or tap the sea to sail your ships. Pinch to zoom." if battle.sea else "Tap an enemy castle to plan an attack. Pinch to zoom.") if n == 0 else "Enemy soldiers in sight: %d" % n
	map.queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	var kh = battle.heroes.get(battle.my_id)
	if kh != null:
		kh.map_want = false
	if _open_tw != null and _open_tw.is_valid():
		_open_tw.kill()
	dim.modulate.a = 1.0
	station_mode = false
	touches.clear()
	if btn_station != null:
		btn_station.set_pressed_no_signal(false)
	if atk != null:
		atk.visible = false
	dim.visible = false
	battle.modal = false


# ---------------------------------------------------------------- input: drag, pinch, wheel, tap
func _map_input(e: InputEvent) -> void:
	if atk != null and atk.visible:
		return
	if e is InputEventScreenTouch:
		_touch_mode = true
		if e.pressed:
			touches[e.index] = e.position
			if touches.size() == 1:
				_moved = 0.0
				_press_pos = e.position
			elif touches.size() == 2:
				var ks := touches.keys()
				_pinch_d = (touches[ks[0]] - touches[ks[1]]).length()
		else:
			touches.erase(e.index)
			if touches.is_empty() and _moved < 14.0 * _u:
				_tap(e.position)
		return
	if e is InputEventScreenDrag:
		_touch_mode = true
		touches[e.index] = e.position
		if touches.size() >= 2:
			var ks2 := touches.keys()
			var a: Vector2 = touches[ks2[0]]
			var b: Vector2 = touches[ks2[1]]
			var d := (a - b).length()
			if _pinch_d > 8.0 and d > 8.0:
				_zoom_at(d / _pinch_d, (a + b) * 0.5)
			_pinch_d = d
			_moved += 100.0
		else:
			_moved += e.relative.length()
			if _moved > 14.0 * _u:
				center -= Vector2(e.relative.x, -e.relative.y) / _k()
				_clamp_view()
		return
	if _touch_mode:
		return        # ignore the mouse events Godot emulates from touches
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_at(1.18, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_at(1.0 / 1.18, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				touches[0] = e.position
				_moved = 0.0
				_press_pos = e.position
			else:
				touches.erase(0)
				if _moved < 10.0 * _u:
					_tap(e.position)
	elif e is InputEventMouseMotion and touches.has(0):
		_moved += e.relative.length()
		if _moved > 10.0 * _u:
			center -= Vector2(e.relative.x, -e.relative.y) / _k()
			_clamp_view()


func _castle_at(q: Vector2) -> int:
	for tt in kingdom.nk:
		var p0 := w2m(kingdom.lw(tt, Vector3(-36, 0, -73.0)))
		var p1 := w2m(kingdom.lw(tt, Vector3(36, 0, -121.0)))
		var c := w2m(kingdom.lw(tt, Vector3(0, 0, -97.0)))
		var rad := maxf(40.0 * _u, (p0 - p1).length() * 0.35)
		if q.distance_to(c) < rad:
			return tt
	return -1


func _tap(pos: Vector2) -> void:
	var vt: int = kingdom.vteam()
	var ct := _castle_at(pos)
	if ct >= 0 and ct != vt and not kingdom.fallen[ct] and not station_mode:
		atk.open(ct)
		return
	if battle.sea and not station_mode:
		var wsea := m2w(pos)
		if Vector2(wsea.x, wsea.z).length() > battle.coast_r:
			battle.ship_go(wsea)
			info.text = "Your ships sail to that spot."
			return
	if not station_mode:
		info.text = "Tap an enemy castle to plan an attack. Pinch to zoom."
		return
	_station_at(m2w(pos))


static var _bg: ImageTexture = null


static func _bg_tex() -> ImageTexture:
	if _bg != null:
		return _bg
	var n := 112
	var nz := FastNoiseLite.new()
	nz.frequency = 0.045
	nz.fractal_octaves = 4
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v := 0.5 + 0.5 * nz.get_noise_2d(x, y)
			var c := Color(0.22, 0.17, 0.12).lerp(Color(0.40, 0.31, 0.2), v)
			img.set_pixel(x, y, c)
	_bg = ImageTexture.create_from_image(img)
	return _bg


func _draw_map() -> void:
	t_anim += get_process_delta_time()
	var sz := map.size
	var t: int = kingdom.vteam()
	var k := _k()
	var f := ThemeDB.fallback_font
	# unexplored fog = dark aged leather, explored ground = warm parchment
	map.draw_texture_rect(_bg_tex(), Rect2(Vector2.ZERO, sz), false, Color(0.55, 0.62, 0.78) if battle.sea else Color(0.5, 0.45, 0.42))
	if battle.sea:
		map.draw_circle(w2m(Vector3.ZERO), float(battle.coast_r) * k, Color(0.2, 0.26, 0.15))
		map.draw_arc(w2m(Vector3.ZERO), float(battle.coast_r) * k, 0, TAU, 96, Color(0.86, 0.76, 0.5, 0.75), 3.0)
	# fine survey lines (like an old war chart)
	var ex := extents()
	var step := 20.0
	var gx := -ex.x
	while gx <= ex.x:
		var pa := map.size * 0.5 + Vector2(gx - center.x, -(-ex.y - center.y)) * k
		var pb := map.size * 0.5 + Vector2(gx - center.x, -(ex.y - center.y)) * k
		map.draw_line(pa, pb, Color(0.9, 0.75, 0.4, 0.05), 1.0)
		gx += step
	var gz := -ex.y
	while gz <= ex.y:
		var pa2 := map.size * 0.5 + Vector2(-ex.x - center.x, -(gz - center.y)) * k
		var pb2 := map.size * 0.5 + Vector2(ex.x - center.x, -(gz - center.y)) * k
		map.draw_line(pa2, pb2, Color(0.9, 0.75, 0.4, 0.05), 1.0)
		gz += step
	# lit ground where my people can see (soft edge)
	var srcs := vision_sources()
	if battle.reveal:
		map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.62, 0.52, 0.3, 0.9))
	for s in srcs:
		var cp := w2m(s[0])
		var r: float = float(s[1]) * k
		for ring in 4:
			var rr := r * (1.0 - ring * 0.1)
			map.draw_circle(cp, rr, Color(0.78, 0.66, 0.4, 0.2))
	# vignette + ornate frame
	for vi in 5:
		map.draw_rect(Rect2(Vector2.ONE * (vi * 5.0 + 3.0), sz - Vector2.ONE * (vi * 10.0 + 6.0)), Color(0, 0, 0, 0.16 - vi * 0.03), false, 10.0)
	map.draw_rect(Rect2(Vector2.ONE * 2.0, sz - Vector2.ONE * 4.0), Color(0.86, 0.68, 0.28), false, 3.0)
	map.draw_rect(Rect2(Vector2.ONE * 9.0, sz - Vector2.ONE * 18.0), Color(0.5, 0.36, 0.14, 0.8), false, 1.5)
	for cn in [Vector2(9, 9), Vector2(sz.x - 9, 9), Vector2(9, sz.y - 9), Vector2(sz.x - 9, sz.y - 9)]:
		var dm := PackedVector2Array([cn + Vector2(0, -9), cn + Vector2(9, 0), cn + Vector2(0, 9), cn + Vector2(-9, 0)])
		map.draw_colored_polygon(dm, Color(0.95, 0.78, 0.35))
		map.draw_polyline(PackedVector2Array([dm[0], dm[1], dm[2], dm[3], dm[0]]), Color(0.25, 0.14, 0.05), 1.5)
	# folded-paper creases (the king's four-fold chart)
	map.draw_line(Vector2(sz.x * 0.5, 4), Vector2(sz.x * 0.5, sz.y - 4), Color(0, 0, 0, 0.16), 3.0)
	map.draw_line(Vector2(sz.x * 0.5 + 2, 4), Vector2(sz.x * 0.5 + 2, sz.y - 4), Color(1, 0.9, 0.6, 0.07), 2.0)
	map.draw_line(Vector2(4, sz.y * 0.5), Vector2(sz.x - 4, sz.y * 0.5), Color(0, 0, 0, 0.14), 3.0)
	map.draw_line(Vector2(4, sz.y * 0.5 + 2), Vector2(sz.x - 4, sz.y * 0.5 + 2), Color(1, 0.9, 0.6, 0.06), 2.0)
	# compass rose
	var cr := Vector2(sz.x - 70 * _u, sz.y - 70 * _u)
	map.draw_arc(cr, 30 * _u, 0, TAU, 40, Color(0.9, 0.72, 0.35, 0.8), 2.0)
	for ci in 4:
		var ang := ci * PI * 0.5 - PI * 0.5
		var tip := cr + Vector2(cos(ang), sin(ang)) * 42 * _u
		var sdv := Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5)) * 7 * _u
		map.draw_colored_polygon(PackedVector2Array([tip, cr + sdv, cr - sdv]), Color(0.95, 0.8, 0.4, 0.9 if ci == 0 else 0.55))
	map.draw_string(ThemeDB.fallback_font, cr + Vector2(-5, -46 * _u), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _u), Color(1, 0.9, 0.6))
	# campaign arrows (my soldiers sent against a kingdom)
	var camp := {}
	for u in battle.units.values():
		if u.team == t and not u.dead and u.strike_foe >= 0:
			if not camp.has(u.strike_foe):
				camp[u.strike_foe] = [0, Vector3.ZERO]
			camp[u.strike_foe][0] += 1
			camp[u.strike_foe][1] += u.position
	for ft in camp.keys():
		var n: int = camp[ft][0]
		var cen: Vector3 = camp[ft][1] / float(n)
		var a2 := w2m(cen)
		var b2 := w2m(kingdom.gate_out(ft))
		var dirv := (b2 - a2)
		var ln := dirv.length()
		if ln > 4.0:
			var dn := dirv / ln
			var off := fmod(t_anim * 40.0, 24.0)
			var dd := off
			while dd < ln:
				map.draw_circle(a2 + dn * dd, 2.5 * _u + minf(n * 0.12, 3.0), Color(1.0, 0.45, 0.2, 0.9))
				dd += 24.0
			map.draw_string(f, (a2 + b2) * 0.5 + Vector2(6, -6), "%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * _u), Color(1, 0.8, 0.5))
	# castles
	for tt in kingdom.nk:
		var corners := [kingdom.lw(tt, Vector3(-36, 0, -73.0)), kingdom.lw(tt, Vector3(36, 0, -73.0)), kingdom.lw(tt, Vector3(36, 0, -121.0)), kingdom.lw(tt, Vector3(-36, 0, -121.0))]
		var poly := PackedVector2Array()
		for cpt in corners:
			poly.append(w2m(cpt))
		var mine: bool = tt == t
		var base: Color = battle.team_col(tt)
		var war: bool = kingdom.at_war(t, tt)
		var stone := Color(0.55, 0.5, 0.44)
		var dk := Color(0.12, 0.08, 0.05)
		# courtyard + walls
		map.draw_colored_polygon(poly, Color(base.r * 0.5 + 0.2, base.g * 0.5 + 0.18, base.b * 0.5 + 0.12, 0.55 if mine else 0.42))
		var outl := poly.duplicate()
		outl.append(poly[0])
		map.draw_polyline(outl, dk, 9.0 * _u)
		map.draw_polyline(outl, stone, 6.0 * _u)
		# battlements along every wall
		for ei in 4:
			var pa3: Vector2 = poly[ei]
			var pb3: Vector2 = poly[(ei + 1) % 4]
			var ln3 := pa3.distance_to(pb3)
			var nm3 := int(ln3 / (13.0 * _u))
			for mi in range(1, nm3):
				var mp: Vector2 = pa3.lerp(pb3, float(mi) / nm3)
				map.draw_rect(Rect2(mp - Vector2(2.5, 2.5) * _u, Vector2(5, 5) * _u), stone.lightened(0.25))
		# round corner towers with team-coloured roofs
		for cp2 in poly:
			map.draw_circle(cp2, 10.0 * _u, dk)
			map.draw_circle(cp2, 8.0 * _u, stone)
			map.draw_circle(cp2, 5.0 * _u, Color(base.r, base.g, base.b).lightened(0.1))
			map.draw_circle(cp2 + Vector2(-1.5, -1.5) * _u, 1.8 * _u, Color(1, 1, 1, 0.45))
		var cc := w2m(kingdom.lw(tt, Vector3(0, 0, -97.0)))
		var g := w2m(kingdom.lw(tt, Vector3(0, 0, -73.0)))
		# gatehouse with an arched door
		map.draw_rect(Rect2(g - Vector2(9, 7) * _u, Vector2(18, 14) * _u), dk)
		map.draw_rect(Rect2(g - Vector2(7, 5) * _u, Vector2(14, 10) * _u), stone.lightened(0.1))
		map.draw_circle(g + Vector2(0, -1) * _u, 3.6 * _u, Color(0.08, 0.05, 0.03))
		map.draw_rect(Rect2(g + Vector2(-3.6, -1) * _u, Vector2(7.2, 6) * _u), Color(0.08, 0.05, 0.03))
		# keep: stone block, tall tower, banner
		map.draw_rect(Rect2(cc - Vector2(13, 11) * _u, Vector2(26, 22) * _u), dk)
		map.draw_rect(Rect2(cc - Vector2(11, 9) * _u, Vector2(22, 18) * _u), stone.lightened(0.15))
		for bi in 4:
			map.draw_rect(Rect2(cc + Vector2(-11 + bi * 6.0, -13) * _u, Vector2(4, 4) * _u), stone.lightened(0.3))
		map.draw_circle(cc, 7.0 * _u, dk)
		map.draw_circle(cc, 5.5 * _u, Color(base.r, base.g, base.b).lightened(0.35))
		map.draw_line(cc, cc + Vector2(0, -24) * _u, dk, 2.5 * _u)
		var fw := 0.0 if kingdom.fallen[tt] else 2.5 * sin(t_anim * 3.0 + tt)
		map.draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -24) * _u, cc + Vector2(15 + fw, -20) * _u, cc + Vector2(0, -15) * _u]), Color(base.r, base.g, base.b).lightened(0.15))
		if kingdom.fallen[tt]:
			map.draw_line(poly[0], poly[2], Color(1, 0.4, 0.1), 3.0)
			map.draw_line(poly[1], poly[3], Color(1, 0.4, 0.1), 3.0)
		else:
			var hpf: float = clampf(kingdom.castle_hp[tt] / float(kingdom.CASTLE_HP[kingdom.level[tt] - 1]), 0.0, 1.0)
			var bw := 90.0 * _u
			var bp := cc + Vector2(-bw * 0.5, 22 * _u)
			map.draw_rect(Rect2(bp, Vector2(bw, 9 * _u)), Color(0, 0, 0, 0.7))
			map.draw_rect(Rect2(bp, Vector2(bw * hpf, 9 * _u)), Color(0.3, 0.85, 0.3).lerp(Color(0.95, 0.2, 0.15), 1.0 - hpf))
			var nm: String = String(battle.team_name(tt))
			if LocS.lang == "ar":
				nm = LocS.t(nm)
			var label := "%s  %d" % [nm, int(kingdom.soldier_n[tt])]
			var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _u)).x
			var plq := Rect2(cc + Vector2(-tw * 0.5 - 8 * _u, 34 * _u), Vector2(tw + 16 * _u, 26 * _u))
			map.draw_rect(plq, Color(0.08, 0.05, 0.03, 0.85))
			map.draw_rect(plq, Color(0.86, 0.68, 0.28), false, 1.5)
			map.draw_string(f, plq.position + Vector2(8 * _u, 19 * _u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _u), Color(1, 0.95, 0.8))
			if not mine:
				var pulse := 0.5 + 0.5 * sin(t_anim * 4.0)
				map.draw_arc(cc, (32.0 + pulse * 6.0) * _u, 0, TAU, 32, Color(1.0, 0.25, 0.2, 0.9 if war else 0.4), 3.0)
	# my radar sweep around the king
	var king = battle.team_king(t)
	if king != null:
		var kp := w2m(king.position)
		var sw := fmod(t_anim * 1.6, TAU)
		map.draw_arc(kp, 70.0 * k * 0.5, sw, sw + 0.7, 8, Color(0.5, 1, 0.5, 0.6), 3.0)
		map.draw_arc(kp, 70.0 * k * 0.5, 0, TAU, 40, Color(0.5, 1, 0.5, 0.18), 1.5)
	# fights glow
	for u in battle.units.values():
		if u.dead or u.team != t or u.kind == "villager":
			continue
		if u.target != null and is_instance_valid(u.target) and u.position.distance_to(u.target.position) < 7.0:
			map.draw_circle(w2m(u.position), (8.0 + 3.0 * sin(t_anim * 9.0)) * _u, Color(1, 0.3, 0.1, 0.22))
	# units
	var show_n := 0
	for u in battle.units.values():
		if u.dead:
			continue
		if u.team != t and not u.visible and not battle.reveal:
			continue
		var c: Color = battle.team_col(u.team).lightened(0.3)
		var p := w2m(u.position)
		if p.x < -20 or p.y < -20 or p.x > sz.x + 20 or p.y > sz.y + 20:
			continue
		var ds := _dot * clampf(0.6 + zoom * 0.25, 0.7, 2.0)
		if u.kind == "hero":
			map.draw_circle(p, ds * 1.9, Color(1.0, 0.85, 0.3))
			map.draw_circle(p, ds * 1.2, c)
		elif u.kind == "villager":
			if u.team == t and zoom > 1.5:
				map.draw_circle(p, ds * 0.6, Color(0.8, 0.8, 0.6))
		elif u.is_ship:
			if u.kind == "fisher":
				ds *= 0.6
			var hd := Vector2(sin(u.rotation.y), -cos(u.rotation.y))
			var sd := Vector2(-hd.y, hd.x)
			map.draw_colored_polygon(PackedVector2Array([p + hd * ds * 3.2, p + sd * ds * 1.4 - hd * ds * 2.2, p - sd * ds * 1.4 - hd * ds * 2.2]), c)
			map.draw_arc(p, ds * 3.6, 0, TAU, 16, Color(1, 1, 1, 0.8), 2.0)
		elif u.kind == "ballista" or u.kind == "catapult":
			map.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -ds * 1.6), p + Vector2(ds * 1.6, 0), p + Vector2(0, ds * 1.6), p + Vector2(-ds * 1.6, 0)]), c)
		elif u.kind == "archer":
			map.draw_rect(Rect2(p - Vector2(ds, ds) * 0.8, Vector2(ds, ds) * 1.6), c)
		elif u.kind == "cav":
			map.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -ds * 1.3), p + Vector2(ds * 1.2, ds), p + Vector2(-ds * 1.2, ds)]), c)
		else:
			map.draw_circle(p, ds, c)
	# group rings + labels
	var gc := {}
	for u in battle.units.values():
		if u.dead or u.team != t or u.grp <= 0 or not u.visible:
			continue
		var gp := w2m(u.position)
		var gcol: Color = GCOL[(u.grp - 1) % 6]
		map.draw_arc(gp, _dot * 1.5, 0, TAU, 10, gcol, 2.0)
		var e: Array = gc.get(u.grp, [Vector2.ZERO, 0])
		e[0] += gp
		e[1] += 1
		gc[u.grp] = e
	for gk in gc.keys():
		var e2: Array = gc[gk]
		var cp: Vector2 = e2[0] / float(e2[1])
		map.draw_string(f, cp + Vector2(-12, -14 * _u), "G%d (%d)" % [gk, e2[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _u), GCOL[(int(gk) - 1) % 6])
	# station flags
	var letters := {"sword": "S", "archer": "A", "cav": "C"}
	for kd in flags.keys():
		var fp := w2m(flags[kd])
		map.draw_circle(fp, _dot * 1.4, Color(1.0, 0.9, 0.3, 0.35))
		map.draw_arc(fp, _dot * 2.0, 0, TAU, 20, Color(1.0, 0.9, 0.3), 2.0)
		map.draw_string(f, fp + Vector2(-5, 6), String(letters.get(kd, kd)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
	# pings (enemy sighted)
	for pg in pings:
		var pp := w2m(pg.pos)
		var ph: float = fmod(pg.t, 1.2) / 1.2
		map.draw_arc(pp, 8.0 + ph * 26.0, 0, TAU, 28, Color(1.0, 0.25, 0.2, 1.0 - ph), 3.0)
		map.draw_circle(pp, 4.0, Color(1.0, 0.25, 0.2))
	# last-seen enemies (fade out)
	for e in enemy_sightings():
		var age: float = battle.game_time - float(e.t)
		var ep := w2m(e.pos)
		map.draw_arc(ep, 7.0 * _u, 0, TAU, 12, Color(1, 0.3, 0.25, clampf(1.0 - age / 25.0, 0.0, 1.0) * 0.8), 2.0)
	# compass
	map.draw_string(f, Vector2(sz.x - 120 * _u, sz.y - 14 * _u), "x%.1f" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * _u), Color(0.8, 0.8, 0.85))
	# kingdom list texts
	for i in krows.keys():
		var kb: Button = krows[i]
		var nm2: String = String(battle.team_name(i))
		if LocS.lang == "ar":
			nm2 = LocS.t(nm2)
		var tag := ""
		if i == t:
			tag = " *"
		elif kingdom.fallen[i]:
			tag = " x"
		elif kingdom.at_war(t, i):
			tag = " !"
		kb.text = "%s  %d%s" % [nm2, int(kingdom.soldier_n[i]) if (i == t or battle.reveal or kingdom.at_war(t, i)) else 0, tag]
		kb.add_theme_color_override("font_color", battle.team_col(i).lightened(0.4))
