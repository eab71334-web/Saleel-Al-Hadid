extends Node
# Battle mode map: a top-down view of the field where you choose where each group
# of your army stands (swords / archers / cavalry), or send them to attack or fall back.

var battle
var dim: ColorRect
var map: Control
var info: Label
var is_open := false
var sel_mask := 7
var flags := {}
var _dot := 4.0

const EX := Vector2(100.0, 84.0)


func w2m(p: Vector3) -> Vector2:
	var sz := map.size
	var a: Vector3 = Basis(Vector3.UP, -battle.ang(battle.my_team)) * p
	var x := (a.x + EX.x) / (2.0 * EX.x) * sz.x
	var y := (a.z + EX.y) / (2.0 * EX.y) * sz.y
	return Vector2(x, sz.y - y)


func m2w(q: Vector2) -> Vector3:
	var sz := map.size
	var ax := q.x / sz.x * 2.0 * EX.x - EX.x
	var az := (sz.y - q.y) / sz.y * 2.0 * EX.y - EX.y
	return Basis(Vector3.UP, battle.ang(battle.my_team)) * Vector3(ax, 0.0, az)


func build_ui(root: Control, u: float, vs: Vector2) -> void:
	var open_btn := Button.new()
	open_btn.text = "MAP"
	open_btn.position = Vector2(vs.x - 600 * u, 90 * u)
	open_btn.size = Vector2(190, 52) * u
	open_btn.add_theme_font_size_override("font_size", int(20 * u))
	open_btn.pressed.connect(toggle)
	open_btn.position = Vector2(vs.x - 292 * u, 10 * u)
	open_btn.size = Vector2(210, 58) * u
	open_btn.icon = preload("res://game/uifx.gd").icon("map", int(44 * u))
	open_btn.expand_icon = true
	open_btn.add_theme_constant_override("icon_max_width", int(30 * u))
	for stn in ["normal", "hover", "pressed"]:
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0.1, 0.2, 0.38, 0.9) if stn != "pressed" else Color(0.2, 0.4, 0.7, 0.95)
		gs.border_color = Color(0.95, 0.76, 0.33)
		gs.set_border_width_all(int(3 * u))
		gs.set_corner_radius_all(int(16 * u))
		gs.shadow_color = Color(0, 0, 0, 0.5)
		gs.shadow_size = int(5 * u)
		open_btn.add_theme_stylebox_override(stn, gs)
	open_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	root.add_child(open_btn)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 40
	dim.visible = false
	root.add_child(dim)
	var ww := vs.y * 0.84 * EX.x / EX.y
	ww = minf(ww, vs.x * 0.58)
	var hh := ww * EX.y / EX.x
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", int(14 * u))
	holder.position = Vector2(vs.x * 0.5 - (ww + 380 * u) * 0.5, vs.y * 0.08)
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
	title.text = "BATTLE MAP"
	title.add_theme_font_size_override("font_size", int(30 * u))
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Pick groups, then tap the map where they should stand."
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
	var prow := GridContainer.new()
	prow.columns = 2
	prow.add_theme_constant_override("h_separation", int(6 * u))
	prow.add_theme_constant_override("v_separation", int(6 * u))
	col.add_child(prow)
	for pr in [["AT MY WALL", -64.0], ["REAR GUARD", -46.0], ["FRONT LINE", -28.0], ["MIDFIELD", -6.0]]:
		var pb := Button.new()
		pb.text = pr[0]
		pb.custom_minimum_size = Vector2(182, 52) * u
		var lz: float = pr[1]
		pb.pressed.connect(func(): _station(battle.rotv(battle.my_team, Vector3(0, 0, lz))))
		prow.add_child(pb)
	var atk := Button.new()
	atk.text = "ATTACK the enemy!"
	atk.custom_minimum_size = Vector2(370, 60) * u
	atk.pressed.connect(func():
		battle.order_at(1, sel_mask, Vector3.ZERO, -1)
		flags.clear()
		close())
	col.add_child(atk)
	var home := Button.new()
	home.text = "RETREAT to my wall"
	home.custom_minimum_size = Vector2(370, 60) * u
	home.pressed.connect(func():
		battle.order_at(4, sel_mask, Vector3.ZERO, -1)
		flags.clear()
		info.text = "Orders given: fall back.")
	col.add_child(home)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(370 * u, 70 * u)
	info.add_theme_font_size_override("font_size", int(20 * u))
	info.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	col.add_child(info)
	var cl := Button.new()
	cl.text = "CLOSE MAP"
	cl.custom_minimum_size = Vector2(370, 60) * u
	cl.pressed.connect(close)
	col.add_child(cl)
	_dot = 4.0 * u


func _station(w: Vector3) -> void:
	battle.order_at(2, sel_mask, w, -1)
	var ks := ["sword", "archer", "cav"]
	for i in 3:
		if (sel_mask & (1 << i)) != 0:
			flags[ks[i]] = w
	info.text = "Groups are moving to that spot and will hold it."


func _map_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hit := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		hit = true
	elif e is InputEventScreenTouch and e.pressed:
		pos = e.position
		hit = true
	if hit:
		var w := m2w(pos)
		w.x = clampf(w.x, -90.0, 90.0)
		w.z = clampf(w.z, -72.0, 72.0)
		_station(w)


func toggle() -> void:
	if is_open:
		close()
	elif not battle.modal and not battle.over and not battle.intro:
		is_open = true
		dim.visible = true
		battle.modal = true
		info.text = ""
		map.queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	dim.visible = false
	battle.modal = false


func _process(_dt: float) -> void:
	if is_open and map != null:
		map.queue_redraw()


func _draw_map() -> void:
	var sz := map.size
	map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.16, 0.3, 0.12))
	# the two walls
	for t in battle.nk:
		var a := w2m(battle.rotv(t, Vector3(-36, 0, -73.0)))
		var b := w2m(battle.rotv(t, Vector3(36, 0, -73.0)))
		map.draw_line(a, b, battle.team_col(t), 5.0)
	map.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0.65, 0.3), false, 3.0)
	for u in battle.units.values():
		if u.dead:
			continue
		var c: Color = battle.team_col(u.team).lightened(0.3)
		var p := w2m(u.position)
		if u.kind == "hero":
			map.draw_circle(p, _dot * 1.9, Color(1.0, 0.85, 0.3))
			map.draw_circle(p, _dot * 1.2, c)
		elif u.kind == "archer":
			map.draw_rect(Rect2(p - Vector2(_dot, _dot) * 0.8, Vector2(_dot, _dot) * 1.6), c)
		elif u.kind == "cav":
			map.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -_dot * 1.3), p + Vector2(_dot * 1.2, _dot), p + Vector2(-_dot * 1.2, _dot)]), c)
		else:
			map.draw_circle(p, _dot, c)
	var letters := {"sword": "S", "archer": "A", "cav": "C"}
	for kd in flags.keys():
		var fp := w2m(flags[kd])
		map.draw_circle(fp, _dot * 1.4, Color(1.0, 0.9, 0.3, 0.35))
		map.draw_arc(fp, _dot * 2.0, 0, TAU, 20, Color(1.0, 0.9, 0.3), 2.0)
		map.draw_string(ThemeDB.fallback_font, fp + Vector2(-5, 6), letters[kd], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
