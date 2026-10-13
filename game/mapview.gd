extends Node
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
var info: Label
var btn_station: Button
var gar_btns := []
var flags := {}                 # kind -> Vector3 (my own station flags, for drawing)
var _dot := 3.0

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
	for p in pings:
		p.t += dt
	while not pings.is_empty() and pings[0].t > 40.0:
		pings.pop_front()
	if is_open and map != null:
		map.queue_redraw()


# ================================================================== map coordinates
func extents() -> Vector2:
	if battle.nk > 2:
		var e: float = battle.ring_r + 55.0
		return Vector2(e, e)
	return Vector2(100.0, 140.0)


func w2m(p: Vector3) -> Vector2:
	var sz := map.size
	var ex := extents()
	var a: Vector3 = Basis(Vector3.UP, -kingdom.ang(kingdom.vteam())) * p
	var x := (a.x + ex.x) / (2.0 * ex.x) * sz.x
	var y := (a.z + ex.y) / (2.0 * ex.y) * sz.y
	return Vector2(x, sz.y - y)


func m2w(q: Vector2) -> Vector3:
	var sz := map.size
	var ex := extents()
	var ax := q.x / sz.x * 2.0 * ex.x - ex.x
	var az := (sz.y - q.y) / sz.y * 2.0 * ex.y - ex.y
	return Basis(Vector3.UP, kingdom.ang(kingdom.vteam())) * Vector3(ax, 0.0, az)


# ================================================================== UI
func build_ui(root: Control, u: float, vs: Vector2) -> void:
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 40
	dim.visible = false
	root.add_child(dim)
	var hh := vs.y * 0.86
	var ex0 := extents()
	var ww := hh * ex0.x / ex0.y
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", int(14 * u))
	holder.position = Vector2(vs.x * 0.5 - (ww + 380 * u) * 0.5, vs.y * 0.07)
	dim.add_child(holder)
	var frame := PanelContainer.new()
	holder.add_child(frame)
	map = Control.new()
	map.custom_minimum_size = Vector2(ww, hh)
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	map.draw.connect(_draw_map)
	map.gui_input.connect(_map_input)
	frame.add_child(map)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380 * u, hh)
	col.add_theme_constant_override("separation", int(8 * u))
	holder.add_child(col)
	var title := Label.new()
	title.text = "WAR MAP"
	title.add_theme_font_size_override("font_size", int(30 * u))
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Fog hides the enemy until your men or towers get close."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(370 * u, 0)
	hint.add_theme_font_size_override("font_size", int(19 * u))
	hint.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * u))
	col.add_child(row)
	var names := ["SWORDS", "ARCHERS", "CAVALRY"]
	for i in 3:
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_pressed = true
		b.custom_minimum_size = Vector2(120, 56) * u
		var bit := 1 << i
		b.toggled.connect(func(on):
			if on:
				sel_mask |= bit
			else:
				sel_mask &= ~bit
			if sel_mask == 0:
				sel_mask = bit
				b.set_pressed_no_signal(true))
		row.add_child(b)
		chips.append(b)
	var prow := GridContainer.new()
	prow.columns = 2
	prow.add_theme_constant_override("h_separation", int(6 * u))
	prow.add_theme_constant_override("v_separation", int(6 * u))
	col.add_child(prow)
	var presets := [["AT THE GATE", -62.0], ["IN FRONT", -40.0], ["MIDFIELD", -8.0], ["ON THE WALLS", -80.0]]
	for pr in presets:
		var pb := Button.new()
		pb.text = pr[0]
		pb.custom_minimum_size = Vector2(182, 52) * u
		var lz: float = pr[1]
		pb.pressed.connect(func(): _station_preset(lz))
		prow.add_child(pb)
	btn_station = Button.new()
	btn_station.text = "STATION: tap the map"
	btn_station.toggle_mode = true
	btn_station.custom_minimum_size = Vector2(370, 62) * u
	btn_station.toggled.connect(func(on): station_mode = on)
	col.add_child(btn_station)
	var atk := Button.new()
	atk.text = "ATTACK the enemy!"
	atk.custom_minimum_size = Vector2(370, 62) * u
	atk.pressed.connect(func():
		battle.order_at(1, sel_mask, Vector3.ZERO, -1)
		info.text = "Orders given: attack."
		close())
	col.add_child(atk)
	var home := Button.new()
	home.text = "RETURN to the castle"
	home.custom_minimum_size = Vector2(370, 62) * u
	home.pressed.connect(func():
		battle.order_at(4, sel_mask, kingdom.home_pos(kingdom.vteam()), -1)
		flags.clear()
		info.text = "Orders given: return home.")
	col.add_child(home)
	var gl := Label.new()
	gl.text = "Garrison (stay to guard the castle):"
	gl.add_theme_font_size_override("font_size", int(20 * u))
	col.add_child(gl)
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", int(6 * u))
	col.add_child(gr)
	for pc in [0, 25, 50, 75]:
		var b2 := Button.new()
		b2.text = "%d%%" % pc
		b2.toggle_mode = true
		b2.custom_minimum_size = Vector2(84, 56) * u
		var v: int = pc
		b2.pressed.connect(func(): set_garrison(v))
		gr.add_child(b2)
		gar_btns.append(b2)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(370 * u, 80 * u)
	info.add_theme_font_size_override("font_size", int(20 * u))
	info.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	col.add_child(info)
	var cl := Button.new()
	cl.text = "CLOSE MAP"
	cl.custom_minimum_size = Vector2(370, 62) * u
	cl.pressed.connect(close)
	col.add_child(cl)
	_dot = 4.0 * u
	set_garrison(0, false)


# Quick station: put the selected groups at a spot on my kingdom's axis (local z measured from the castle centre line).
func _station_preset(lz: float) -> void:
	var vt: int = kingdom.vteam()
	var w: Vector3 = kingdom.lw(vt, Vector3(0, 0, lz))
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
	var n := enemy_sightings().size()
	info.text = "Enemy soldiers in sight: %d" % n if n > 0 else "No enemy in sight."
	map.queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	station_mode = false
	if btn_station != null:
		btn_station.set_pressed_no_signal(false)
	dim.visible = false
	battle.modal = false


func _map_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hit := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		hit = true
	elif e is InputEventScreenTouch and e.pressed:
		pos = e.position
		hit = true
	if not hit:
		return
	var w := m2w(pos)
	if not station_mode:
		info.text = "Tip: press STATION first, then tap where your groups should stand."
		return
	battle.order_at(2, sel_mask, w, -1)
	var ks := ["sword", "archer", "cav"]
	for i in 3:
		if (sel_mask & (1 << i)) != 0:
			flags[ks[i]] = w
	info.text = "Groups are moving to that spot and will hold it."


func _draw_map() -> void:
	var sz := map.size
	var t: int = kingdom.vteam()
	map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.07, 0.09))
	var k := sz.x / (2.0 * extents().x)
	for s in vision_sources():
		map.draw_circle(w2m(s[0]), float(s[1]) * k, Color(0.22, 0.34, 0.18))
	map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0.65, 0.3), false, 3.0)
	# all castles (always known)
	for tt in kingdom.nk:
		var corners := [kingdom.lw(tt, Vector3(-36, 0, -73.0)), kingdom.lw(tt, Vector3(36, 0, -73.0)), kingdom.lw(tt, Vector3(36, 0, -121.0)), kingdom.lw(tt, Vector3(-36, 0, -121.0))]
		var poly := PackedVector2Array()
		for cpt in corners:
			poly.append(w2m(cpt))
		var mine: bool = tt == t
		var base: Color = battle.team_col(tt)
		map.draw_colored_polygon(poly, Color(base.r, base.g, base.b, 0.22 if mine else 0.1))
		var outl := poly.duplicate()
		outl.append(poly[0])
		map.draw_polyline(outl, Color(base.r, base.g, base.b, 0.9 if mine else 0.5), 2.5)
		var g := w2m(kingdom.lw(tt, Vector3(0, 0, -73.0)))
		map.draw_circle(g, 6.0, Color(1.0, 0.85, 0.4))
		if kingdom.fallen[tt]:
			map.draw_line(poly[0], poly[2], Color(1, 0.4, 0.1), 3.0)
			map.draw_line(poly[1], poly[3], Color(1, 0.4, 0.1), 3.0)
	# units
	for u in battle.units.values():
		if u.dead:
			continue
		if u.team != t and not u.visible and not battle.reveal:
			continue
		var c: Color = battle.team_col(u.team).lightened(0.3)
		var p := w2m(u.position)
		if u.kind == "hero":
			map.draw_circle(p, _dot * 1.9, Color(1.0, 0.85, 0.3))
			map.draw_circle(p, _dot * 1.2, c)
		elif u.kind == "villager":
			if u.team == t:
				map.draw_circle(p, _dot * 0.6, Color(0.8, 0.8, 0.6))
		elif u.kind == "archer":
			map.draw_rect(Rect2(p - Vector2(_dot, _dot) * 0.8, Vector2(_dot, _dot) * 1.6), c)
		elif u.kind == "cav":
			map.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -_dot * 1.3), p + Vector2(_dot * 1.2, _dot), p + Vector2(-_dot * 1.2, _dot)]), c)
		else:
			map.draw_circle(p, _dot, c)
	# my station flags
	var letters := {"sword": "S", "archer": "A", "cav": "C"}
	for kd in flags.keys():
		var fp := w2m(flags[kd])
		map.draw_circle(fp, _dot * 1.4, Color(1.0, 0.9, 0.3, 0.35))
		map.draw_arc(fp, _dot * 2.0, 0, TAU, 20, Color(1.0, 0.9, 0.3), 2.0)
		map.draw_string(ThemeDB.fallback_font, fp + Vector2(-5, 6), letters[kd], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
	# pings (enemy sighted)
	for pg in pings:
		var pp := w2m(pg.pos)
		var ph: float = fmod(pg.t, 1.2) / 1.2
		map.draw_arc(pp, 8.0 + ph * 26.0, 0, TAU, 28, Color(1.0, 0.25, 0.2, 1.0 - ph), 3.0)
		map.draw_circle(pp, 4.0, Color(1.0, 0.25, 0.2))
	map.draw_string(ThemeDB.fallback_font, Vector2(8, 22), "YOUR CASTLE" if false else "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 1, Color(0, 0, 0, 0))
