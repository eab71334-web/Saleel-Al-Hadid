extends "res://game/mainmenu.gd"
# Open-world HUD: resources, minimap, world map (also the castle-site picker), castle upgrade panel,
# market, virtual joystick, drag-to-look pad, toasts and loading screen.

const WG := preload("res://game/worldgen.gd")
const CK := preload("res://game/castlekit.gd")

const Prog := preload("res://game/worldprog.gd")

var world
var play_root: Control
var pad: Control
var joy: Control
var chip_g: Dictionary
var chip_w: Dictionary
var chip_s: Dictionary
var lbl_level: Label
var lbl_pos: Label
var lbl_near: Label
var lbl_net: Label
var btn_horse: Button
var btn_home: Button
var btn_attack: Button
var btn_ctx: Button
var lbl_hp: Label
var dlg_root: Control
var dlg_body: VBoxContainer
var mini: Control
var toast_l: Label
var toast_t := 0.0
var load_root: Control
var load_bar: ProgressBar
var map_root: Control
var map_canvas: Control
var pick_info: Label
var pick_btn: Button
var pick_xz := Vector2.ZERO
var pick_ok := false
var pick_mode := false
var castle_root: Control
var castle_body: VBoxContainer
var waypoint := Vector2(1e9, 1e9)
var touches := {}
var pinch := 0.0
var look_idx := -99
var map_tex: ImageTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	instant = true
	map_tex = ImageTexture.create_from_image(WG.map_image())
	_build_play()
	_build_loading()
	_build_map()
	_build_castle_panel()
	_build_dialog()
	toast_l = _lbl(self, "", 30, Color(1, 0.95, 0.7))
	toast_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_l.offset_left = -400
	toast_l.offset_right = 400
	toast_l.offset_top = 96
	toast_l.offset_bottom = 150
	toast_l.modulate.a = 0.0
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	play_root.visible = false
	load_root.visible = true


func _is_pointer(e: InputEvent) -> bool:
	if DisplayServer.is_touchscreen_available():
		return e is InputEventScreenTouch or e is InputEventScreenDrag
	return e is InputEventMouseButton or e is InputEventMouseMotion


# ------------------------------------------------------------------ in-game HUD
func _build_play() -> void:
	play_root = Control.new()
	play_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play_root)
	# look pad (everything not covered by other controls)
	pad = Control.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.gui_input.connect(_pad_input)
	play_root.add_child(pad)
	# resources
	var rb := HBoxContainer.new()
	rb.position = Vector2(14, 10)
	rb.add_theme_constant_override("separation", 8)
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(rb)
	chip_g = UiFx.chip("coin", 1.3, 104, Color(1, 0.9, 0.4))
	chip_w = UiFx.chip("wood", 1.3, 104, Color(0.9, 0.7, 0.45))
	chip_s = UiFx.chip("stone", 1.3, 104, Color(0.85, 0.88, 0.95))
	rb.add_child(chip_g.box)
	rb.add_child(chip_w.box)
	rb.add_child(chip_s.box)
	lbl_level = _lbl(play_root, "", 22, Color(1, 0.85, 0.5))
	lbl_level.position = Vector2(16, 58)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_level.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_pos = _lbl(play_root, "", 18, Color(0.9, 0.92, 1.0))
	lbl_pos.position = Vector2(16, 86)
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_pos.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_near = _lbl(play_root, "", 20, Color(0.85, 0.95, 1.0))
	lbl_near.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_near.offset_left = -300
	lbl_near.offset_right = 300
	lbl_near.offset_top = 10
	lbl_near.offset_bottom = 44
	lbl_net = _lbl(play_root, "", 16, Color(0.7, 0.85, 0.7))
	lbl_net.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl_net.offset_left = -300
	lbl_net.offset_right = 300
	lbl_net.offset_top = 44
	lbl_net.offset_bottom = 70
	# minimap + buttons (top right)
	mini = Control.new()
	mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini.offset_left = -196
	mini.offset_right = -14
	mini.offset_top = 12
	mini.offset_bottom = 194
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.draw.connect(_draw_mini)
	mini.gui_input.connect(func(e):
		if _is_pointer(e) and ((e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed):
			open_map())
	play_root.add_child(mini)
	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -196
	side.offset_right = -14
	side.offset_top = 202
	side.add_theme_constant_override("separation", 8)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(side)
	actions = {
		"map": func(): open_map(),
		"castle": func(): open_castle(),
		"exit": func(): world.exit_world(),
		"horse": func(): world.toggle_horse(),
		"home": func(): world.fast_home(),
		"attack": func(): world.life.king_attack(),
		"realm": func(): world.life.open_realm(),
		"ctx": func():
			if not world.life.ctx.is_empty():
				(world.life.ctx.fn as Callable).call(),
	}
	side.add_child(_mbtn("map", "MAP", "map", Vector2(182, 54), 22))
	side.add_child(_mbtn("castle", "CASTLE", "house", Vector2(182, 54), 22, true))
	side.add_child(_mbtn("realm", "REALM", "army", Vector2(182, 54), 22))
	side.add_child(_mbtn("exit", "Exit", "gear", Vector2(182, 46), 20))
	# action buttons (bottom right)
	var ab := VBoxContainer.new()
	ab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ab.offset_left = -200
	ab.offset_right = -16
	ab.offset_top = -256
	ab.offset_bottom = -20
	ab.add_theme_constant_override("separation", 8)
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(ab)
	btn_attack = _mbtn("attack", "ATTACK", "sword", Vector2(184, 70), 22, true)
	btn_horse = _mbtn("horse", "HORSE", "horse", Vector2(184, 70), 22)
	btn_home = _mbtn("home", "HOME", "flag", Vector2(184, 70), 22)
	ab.add_child(btn_attack)
	ab.add_child(btn_horse)
	ab.add_child(btn_home)
	# context action (sit, tax, lord, player ...), appears when something is near
	btn_ctx = _mbtn("ctx", "", "gear", Vector2(300, 80), 28, true)
	btn_ctx.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	btn_ctx.offset_left = -150
	btn_ctx.offset_right = 150
	btn_ctx.offset_top = -190
	btn_ctx.offset_bottom = -110
	btn_ctx.visible = false
	play_root.add_child(btn_ctx)
	lbl_hp = _lbl(play_root, "", 20, Color(1, 0.7, 0.65))
	lbl_hp.position = Vector2(16, 114)
	lbl_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	# joystick
	joy = Control.new()
	joy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joy.offset_left = 20
	joy.offset_right = 290
	joy.offset_top = -290
	joy.offset_bottom = -20
	joy.mouse_filter = Control.MOUSE_FILTER_STOP
	joy.gui_input.connect(_joy_input)
	joy.draw.connect(_draw_joy)
	play_root.add_child(joy)


var joy_idx := -99
var joy_v := Vector2.ZERO


func _joy_input(e: InputEvent) -> void:
	if not _is_pointer(e):
		return
	var c := joy.size * 0.5
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		var pr: bool = e.pressed
		if pr:
			joy_idx = e.index if e is InputEventScreenTouch else -1
			joy_v = ((e.position - c) / 100.0).limit_length(1.0)
		else:
			joy_idx = -99
			joy_v = Vector2.ZERO
	elif e is InputEventMouseMotion or e is InputEventScreenDrag:
		if joy_idx != -99 and (e is InputEventMouseMotion and joy_idx == -1 or e is InputEventScreenDrag and e.index == joy_idx):
			joy_v = ((e.position - c) / 100.0).limit_length(1.0)
	world.move_vec = joy_v
	joy.queue_redraw()


func _draw_joy() -> void:
	var c := joy.size * 0.5
	joy.draw_circle(c, 104.0, Color(0, 0, 0, 0.28))
	joy.draw_arc(c, 104.0, 0, TAU, 48, Color(1, 0.85, 0.45, 0.7), 4.0, true)
	joy.draw_circle(c + joy_v * 70.0, 44.0, Color(1, 0.85, 0.45, 0.55))
	joy.draw_arc(c + joy_v * 70.0, 44.0, 0, TAU, 32, Color(1, 0.95, 0.7, 0.9), 3.0, true)


func _pad_input(e: InputEvent) -> void:
	if world.state != "play" or not _is_pointer(e):
		return
	if e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.zoom_cam(0.9)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom_cam(1.1)
	elif e is InputEventMouseMotion:
		if (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			world.rotate_cam(e.relative.x, e.relative.y)
	elif e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		pinch = 0.0
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		if touches.size() >= 2:
			var ks: Array = touches.keys()
			var d: float = (touches[ks[0]] - touches[ks[1]]).length()
			if pinch > 0.0 and d > 1.0:
				world.zoom_cam(pinch / d)
			pinch = d
		else:
			world.rotate_cam(e.relative.x, e.relative.y)


func _draw_mini() -> void:
	var s := mini.size
	mini.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.04, 0.06, 0.9))
	var win := 1800.0
	var px := win / (WG.HALF * 2.0) * WG.MAP_PX
	var c: Vector2 = WG.w2m(world.king_pos.x, world.king_pos.z)
	var src := Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px))
	# clamp the source inside the texture
	src.position.x = clampf(src.position.x, 0.0, WG.MAP_PX - px)
	src.position.y = clampf(src.position.y, 0.0, WG.MAP_PX - px)
	mini.draw_texture_rect_region(map_tex, Rect2(Vector2(3, 3), s - Vector2(6, 6)), src)
	var k := (s.x - 6.0) / px
	for cs in world.castles:
		var m: Vector2 = WG.w2m(float(cs.x), float(cs.z))
		if src.has_point(m):
			var p: Vector2 = Vector2(3, 3) + (m - src.position) * k
			var col := Color(1, 0.85, 0.3) if cs.owner == "you" else (Color(0.5, 0.8, 1.0) if cs.owner == "online" else Color(1, 1, 1, 0.9))
			mini.draw_circle(p, 5.0 if cs.owner == "you" else 3.5, Color(0, 0, 0, 0.8))
			mini.draw_circle(p, 3.5 if cs.owner == "you" else 2.4, col)
	for mp in world.life.minimap_points():
		var m2: Vector2 = WG.w2m(float(mp[0]), float(mp[1]))
		if src.has_point(m2):
			mini.draw_circle(Vector2(3, 3) + (m2 - src.position) * k, 3.0, mp[2])
	var pp: Vector2 = Vector2(3, 3) + (c - src.position) * k
	var a: float = world.king_yaw
	var dir := Vector2(sin(a), cos(a))
	mini.draw_colored_polygon(PackedVector2Array([pp + dir * 9.0, pp + dir.rotated(2.5) * 6.0, pp + dir.rotated(-2.5) * 6.0]), Color(1, 0.3, 0.25))
	mini.draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.66, 0.28), false, 3.0)


# ------------------------------------------------------------------ loading
func _build_loading() -> void:
	load_root = ColorRect.new()
	(load_root as ColorRect).color = Color(0.03, 0.03, 0.06, 0.96)
	load_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(load_root)
	var l := _lbl(load_root, "Loading the world...", 44, Color(1, 0.85, 0.4))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = -60
	l.offset_bottom = 0
	load_bar = ProgressBar.new()
	load_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	load_bar.offset_left = -240
	load_bar.offset_right = 240
	load_bar.offset_top = 20
	load_bar.offset_bottom = 40
	load_bar.show_percentage = false
	load_bar.max_value = 1.0
	load_root.add_child(load_bar)


func show_loading(on: bool) -> void:
	load_root.visible = on
	if on:
		load_bar.value = 0.0


func set_loading(v: float) -> void:
	load_bar.value = v


func show_play() -> void:
	play_root.visible = true
	_refresh_castle_panel()


func toast(text: String, secs := 2.5) -> void:
	toast_l.text = text
	toast_l.modulate.a = 1.0
	toast_t = secs


# ------------------------------------------------------------------ world map + site picker
func _build_map() -> void:
	map_root = ColorRect.new()
	(map_root as ColorRect).color = Color(0.03, 0.03, 0.06, 0.94)
	map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_root.mouse_filter = Control.MOUSE_FILTER_STOP
	map_root.visible = false
	add_child(map_root)
	map_canvas = Control.new()
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.offset_left = 16
	map_canvas.offset_top = 16
	map_canvas.offset_bottom = -16
	map_canvas.offset_right = -470
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_map_input)
	map_root.add_child(map_canvas)
	var pn := PanelContainer.new()
	pn.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	pn.offset_left = -450
	pn.offset_right = -14
	pn.offset_top = 14
	pn.offset_bottom = -14
	pn.add_theme_stylebox_override("panel", UiFx.plate(16.0, 0.9))
	map_root.add_child(pn)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pn.add_child(vb)
	var tl := _lbl(vb, "World Map", 34, Color(1, 0.85, 0.4))
	tl.name = "Title"
	pick_info = _lbl(vb, "", 22, Color(0.9, 0.95, 1.0))
	pick_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick_info.custom_minimum_size = Vector2(0, 90)
	var prog := _lbl(vb, "", 19, Color(0.85, 0.85, 0.9))
	prog.name = "Prog"
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions["pick_ok"] = func(): _confirm_pick()
	actions["map_close"] = func(): map_root.visible = false
	actions["pick_back"] = func(): world.exit_world()
	pick_btn = _mbtn("pick_ok", "BUILD HERE", "house", Vector2(400, 64), 26, true)
	pick_btn.name = "PickBtn"
	vb.add_child(pick_btn)
	var cb := _mbtn("map_close", "Close", "gear", Vector2(400, 52), 22)
	cb.name = "CloseBtn"
	vb.add_child(cb)
	var bb := _mbtn("pick_back", "Back to menu", "flag", Vector2(400, 52), 22)
	bb.name = "BackBtn"
	vb.add_child(bb)


func show_pick() -> void:
	pick_mode = true
	load_root.visible = false
	map_root.visible = true
	pick_xz = Vector2(1e9, 1e9)
	pick_ok = false
	_map_labels()


func hide_pick() -> void:
	pick_mode = false
	map_root.visible = false


func open_map() -> void:
	pick_mode = false
	map_root.visible = true
	_map_labels()


func _map_labels() -> void:
	var vb := map_root.get_child(1).get_child(0)
	(vb.get_node("Title") as Label).text = LocS.t("Choose your castle site") if pick_mode else LocS.t("World Map")
	vb.get_node("PickBtn").visible = pick_mode
	vb.get_node("PickBtn").disabled = true
	vb.get_node("CloseBtn").visible = not pick_mode
	vb.get_node("BackBtn").visible = pick_mode
	var pr := vb.get_node("Prog") as Label
	if pick_mode:
		pick_info.text = LocS.t("Tap the map where your castle will stand. Green = good land.")
		var t := LocS.t("Your castle starts at level 1 and can grow to level 50. Complete quests to level up:") + "\n"
		for lvk in [1, 2, 3, 5, 6, 10]:
			var us: Array = Prog.UNLOCK[lvk]
			t += "\n" + LocS.t("Level") + " %d:  " % lvk + LocS.t(String(us[0]))
		pr.text = t
	else:
		pick_info.text = LocS.t("Tap the map to place a waypoint. Gold = you, blue = players, white = lords.")
		pr.text = ""
	map_canvas.queue_redraw()


func _map_rect() -> Rect2:
	var s := map_canvas.size
	var side := minf(s.x, s.y)
	return Rect2((s - Vector2(side, side)) * 0.5, Vector2(side, side))


func _draw_map() -> void:
	var r := _map_rect()
	map_canvas.draw_texture_rect(map_tex, r, false)
	map_canvas.draw_rect(r, Color(0.85, 0.66, 0.28), false, 4.0)
	for c in world.castles:
		var m: Vector2 = WG.w2m(float(c.x), float(c.z)) / WG.MAP_PX
		var p: Vector2 = r.position + m * r.size
		var col := Color(1, 0.85, 0.3) if c.owner == "you" else (Color(0.5, 0.8, 1.0) if c.owner == "online" else Color(1, 1, 1, 0.95))
		map_canvas.draw_circle(p, 8.0, Color(0, 0, 0, 0.85))
		map_canvas.draw_circle(p, 5.5, col)
		if c.owner != "ai" or r.size.x > 500:
			map_canvas.draw_string(map_canvas.get_theme_default_font(), p + Vector2(9, 5), "%s Lv%d" % [c.name, int(c.level)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))
	if world.level > 0:
		var pm: Vector2 = WG.w2m(world.king_pos.x, world.king_pos.z) / WG.MAP_PX
		map_canvas.draw_circle(r.position + pm * r.size, 6.0, Color(1, 0.2, 0.2))
	if pick_mode and pick_xz.x < 1e8:
		var m2: Vector2 = WG.w2m(pick_xz.x, pick_xz.y) / WG.MAP_PX
		var p2: Vector2 = r.position + m2 * r.size
		var col2 := Color(0.3, 1.0, 0.4) if pick_ok else Color(1.0, 0.3, 0.3)
		map_canvas.draw_arc(p2, 14.0, 0, TAU, 24, col2, 4.0)
		map_canvas.draw_circle(p2, 5.0, col2)
		map_canvas.draw_arc(p2, 420.0 / (WG.HALF * 2.0) * r.size.x, 0, TAU, 40, Color(col2.r, col2.g, col2.b, 0.6), 2.0)
	if not pick_mode and waypoint.x < 1e8:
		var m3: Vector2 = WG.w2m(waypoint.x, waypoint.y) / WG.MAP_PX
		var p3: Vector2 = r.position + m3 * r.size
		map_canvas.draw_arc(p3, 11.0, 0, TAU, 20, Color(1, 0.9, 0.2), 3.0)


func _map_input(e: InputEvent) -> void:
	var tap := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		tap = true
		pos = e.position
	elif e is InputEventScreenTouch and e.pressed:
		tap = true
		pos = e.position
	if not tap:
		return
	var r := _map_rect()
	var f := (pos - r.position) / r.size
	if f.x < 0.0 or f.y < 0.0 or f.x > 1.0 or f.y > 1.0:
		return
	var w: Vector2 = WG.m2w(f * WG.MAP_PX)
	Snd.play(self, "click", -10.0)
	if pick_mode:
		pick_xz = w
		var why: String = WG.valid_site(w.x, w.y)
		pick_ok = why == ""
		var vb := map_root.get_child(1).get_child(0)
		vb.get_node("PickBtn").disabled = not pick_ok
		pick_info.text = LocS.t("Good land - you can build here.") if pick_ok else LocS.t(why)
		pick_info.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if pick_ok else Color(1, 0.6, 0.5))
	else:
		waypoint = w
		toast(LocS.t("Waypoint set") + " - %d m" % int(Vector2(world.king_pos.x, world.king_pos.z).distance_to(w)), 2.0)
	map_canvas.queue_redraw()


func _confirm_pick() -> void:
	if not pick_ok:
		return
	Snd.play(self, "confirm", -4.0)
	world.confirm_site(pick_xz.x, pick_xz.y)


# ------------------------------------------------------------------ castle panel
func _build_castle_panel() -> void:
	castle_root = ColorRect.new()
	(castle_root as ColorRect).color = Color(0.02, 0.02, 0.05, 0.85)
	castle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	castle_root.mouse_filter = Control.MOUSE_FILTER_STOP
	castle_root.visible = false
	add_child(castle_root)
	var pn := PanelContainer.new()
	pn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pn.offset_left = -520
	pn.offset_right = 520
	pn.offset_top = -330
	pn.offset_bottom = 330
	pn.add_theme_stylebox_override("panel", UiFx.plate(18.0, 0.94))
	castle_root.add_child(pn)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pn.add_child(sc)
	castle_body = VBoxContainer.new()
	castle_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_body.add_theme_constant_override("separation", 8)
	sc.add_child(castle_body)
	actions["up"] = func():
		world.upgrade()
		_refresh_castle_panel()
	actions["castle_close"] = func(): castle_root.visible = false
	actions["sell_wood"] = func(): _trade("wood", -50, 30)
	actions["sell_stone"] = func(): _trade("stone", -50, 40)
	actions["buy_wood"] = func(): _trade("wood", 50, -45)
	actions["buy_stone"] = func(): _trade("stone", 50, -70)


func _trade(k: String, dq: int, dg: int) -> void:
	if world.res[k] + dq < 0 or world.res.gold + dg < 0:
		toast(LocS.t("Not enough resources"), 2.0)
		return
	world.res[k] += dq
	world.res.gold += dg
	_refresh_castle_panel()


func open_castle() -> void:
	if world.level <= 0:
		return
	castle_root.visible = true
	_refresh_castle_panel()


func _refresh_castle_panel() -> void:
	if castle_body == null:
		return
	for c in castle_body.get_children():
		castle_body.remove_child(c)
		c.queue_free()
	var lv: int = world.level
	if lv <= 0:
		return
	_lbl(castle_body, LocS.t("Your Castle") + " - " + LocS.t("Level") + " %d / %d" % [lv, Prog.MAXL], 38, Color(1, 0.85, 0.4))
	var inc: Array = Prog.income(lv)
	_lbl(castle_body, LocS.t("Income per minute") + ":  %d %s   %d %s   %d %s" % [inc[0], LocS.t("Gold"), inc[1], LocS.t("Wood"), inc[2], LocS.t("Stone")], 20, Color(0.85, 0.95, 0.85))
	# unlocked so far / coming next
	var here: Array = Prog.UNLOCK.get(lv, [])
	if not here.is_empty():
		var tx := ""
		for u in here:
			tx += "+ " + LocS.t(u) + "    "
		var ul := _lbl(castle_body, LocS.t("This level") + ":  " + tx, 18, Color(0.92, 0.92, 0.95))
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if lv < Prog.MAXL:
		var nu: Array = Prog.next_unlock(lv)
		if not nu.is_empty():
			var tx2 := ""
			for u in nu[1]:
				tx2 += "- " + LocS.t(u) + "    "
			var nl := _lbl(castle_body, LocS.t("Next unlock at level") + " %d:  " % nu[0] + tx2, 18, Color(0.7, 0.75, 0.9))
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_lbl(castle_body, LocS.t("Quests to reach level") + " %d" % (lv + 1), 28, Color(1, 0.85, 0.4))
		var all_done := true
		for tk in Prog.tasks_for(lv):
			var have: int = mini(world.life.prog(String(tk.id)), int(tk.n))
			var done: bool = have >= int(tk.n)
			if not done:
				all_done = false
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", UiFx.plate(10.0, 0.6))
			castle_body.add_child(row)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 14)
			row.add_child(hb)
			var tl := _lbl(hb, ("+ " if done else "- ") + LocS.t(String(Prog.TASKS[tk.id][0])), 21, Color(0.6, 1, 0.65) if done else Color(1, 0.95, 0.85))
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pb := ProgressBar.new()
			pb.min_value = 0
			pb.max_value = int(tk.n)
			pb.value = have
			pb.show_percentage = false
			pb.custom_minimum_size = Vector2(220, 24)
			var bgs := StyleBoxFlat.new()
			bgs.bg_color = Color(0.12, 0.1, 0.08)
			bgs.set_corner_radius_all(8)
			bgs.border_color = Color(0.5, 0.4, 0.2)
			bgs.set_border_width_all(2)
			var fls := StyleBoxFlat.new()
			fls.bg_color = Color(0.3, 0.8, 0.35) if done else Color(0.95, 0.72, 0.2)
			fls.set_corner_radius_all(8)
			pb.add_theme_stylebox_override("background", bgs)
			pb.add_theme_stylebox_override("fill", fls)
			hb.add_child(pb)
			var cl := _lbl(hb, "%d / %d" % [have, int(tk.n)], 21, Color(1, 0.9, 0.5))
			cl.custom_minimum_size = Vector2(120, 0)
		var c: Array = Prog.cost(lv)
		var ok: bool = world.res.gold >= c[0] and world.res.wood >= c[1] and world.res.stone >= c[2]
		_lbl(castle_body, LocS.t("Upgrade cost") + ":  %d %s   %d %s   %d %s" % [c[0], LocS.t("Gold"), c[1], LocS.t("Wood"), c[2], LocS.t("Stone")], 22, Color(0.7, 1, 0.7) if ok else Color(1, 0.7, 0.6))
		var can: bool = ok and all_done
		var ub := _mbtn("up", "UPGRADE CASTLE", "hammer", Vector2(420, 66), 26, true)
		ub.disabled = not can
		ub.modulate = Color.WHITE if can else Color(0.7, 0.7, 0.7)
		castle_body.add_child(ub)
		ub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not all_done:
			_lbl(castle_body, LocS.t("Finish all quests to upgrade"), 18, Color(1, 0.75, 0.6))
	else:
		_lbl(castle_body, LocS.t("Your castle is at its greatest."), 24, Color(1, 0.9, 0.5))
	if lv >= 3:
		_lbl(castle_body, LocS.t("Market"), 26, Color(1, 0.85, 0.4))
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		castle_body.add_child(g)
		g.add_child(_mbtn("sell_wood", "Sell 50 wood: +30", "wood", Vector2(240, 52), 17))
		g.add_child(_mbtn("sell_stone", "Sell 50 stone: +40", "stone", Vector2(240, 52), 17))
		g.add_child(_mbtn("buy_wood", "Buy 50 wood: -45", "wood", Vector2(240, 52), 17))
		g.add_child(_mbtn("buy_stone", "Buy 50 stone: -70", "stone", Vector2(240, 52), 17))
	var cb := _mbtn("castle_close", "Close", "gear", Vector2(300, 52), 22)
	castle_body.add_child(cb)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ------------------------------------------------------------------ generic dialog (tax, diplomacy, realm ...)
func _build_dialog() -> void:
	dlg_root = ColorRect.new()
	(dlg_root as ColorRect).color = Color(0.02, 0.02, 0.05, 0.8)
	dlg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dlg_root.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg_root.visible = false
	add_child(dlg_root)
	var pn := PanelContainer.new()
	pn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pn.offset_left = -470
	pn.offset_right = 470
	pn.offset_top = -40
	pn.offset_bottom = 40
	pn.grow_vertical = Control.GROW_DIRECTION_BOTH
	pn.add_theme_stylebox_override("panel", UiFx.plate(18.0, 0.95))
	dlg_root.add_child(pn)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(900, 540)
	
	pn.add_child(sc)
	dlg_body = VBoxContainer.new()
	dlg_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_body.add_theme_constant_override("separation", 10)
	sc.add_child(dlg_body)


# buttons: [[text, icon, Callable, keep_open?], ...]; keep_open buttons call `reopen` afterwards
func dialog(title: String, lines: Array, buttons: Array, cols := 2, reopen := Callable()) -> void:
	for c in dlg_body.get_children():
		dlg_body.remove_child(c)
		c.queue_free()
	_lbl(dlg_body, title, 38, Color(1, 0.85, 0.4))
	for l in lines:
		var ll := _lbl(dlg_body, String(l), 20, Color(0.92, 0.94, 1.0))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(860, 0)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	dlg_body.add_child(g)
	var w := (880.0 - 10.0 * float(cols - 1)) / float(cols)
	for i in buttons.size():
		var b: Array = buttons[i]
		var id := "dlg%d" % i
		var keep: bool = b.size() > 3 and bool(b[3])
		actions[id] = func():
			dlg_root.visible = false
			(b[2] as Callable).call()
			if keep and reopen.is_valid():
				reopen.call()
		g.add_child(_mbtn(id, String(b[0]), String(b[1]), Vector2(w, 58), 19))
	dlg_root.visible = true


func pick_image(cb: Callable) -> void:
	OS.request_permissions()
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.title = LocS.t("Choose a picture")
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	if OS.get_name() == "Android":
		fd.current_dir = "/storage/emulated/0/DCIM"
	fd.file_selected.connect(func(p: String):
		cb.call(p)
		fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered_ratio(0.92)


func _btn_set(b: Button, text: String, icon: String) -> void:
	for n in b.find_children("*", "Label", true, false):
		(n as Label).text = text
		break
	if icon != "":
		for n in b.find_children("*", "TextureRect", true, false):
			(n as TextureRect).texture = UiFx.icon(icon, int((n as TextureRect).custom_minimum_size.x))
			break


func refresh_buttons() -> void:
	var lf = world.life
	var lv: int = world.level
	if world.mounted:
		_btn_set(btn_horse, LocS.t("DISMOUNT"), "horse")
	elif lf.horse_near():
		_btn_set(btn_horse, LocS.t("MOUNT"), "horse")
	else:
		_btn_set(btn_horse, LocS.t("CALL"), "horse")
	btn_horse.modulate = Color.WHITE if lv >= 2 else Color(0.5, 0.5, 0.5)
	btn_attack.visible = lv >= 5 or lf.raiders.size() > 0
	if lf.ctx.is_empty() or dlg_root.visible or castle_root.visible:
		btn_ctx.visible = false
	else:
		btn_ctx.visible = true
		_btn_set(btn_ctx, String(lf.ctx.text), String(lf.ctx.icon))


# ------------------------------------------------------------------ per frame
var _ref_t := 0.0


func tick(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		if toast_t < 0.6:
			toast_l.modulate.a = maxf(toast_t / 0.6, 0.0)
	_ref_t -= dt
	if _ref_t > 0.0:
		return
	_ref_t = 0.15
	(chip_g.lbl as Label).text = str(int(world.res.gold))
	(chip_w.lbl as Label).text = str(int(world.res.wood))
	(chip_s.lbl as Label).text = str(int(world.res.stone))
	var hh := int(world.tod)
	var mm := int((world.tod - hh) * 60.0)
	lbl_level.text = "%s %d   -   %s %d  %02d:%02d   -   %s %d" % [LocS.t("Castle Lv"), world.level, LocS.t("Day"), world.day, hh, mm, LocS.t("Soldiers"), world.life.soldier_count()]
	lbl_pos.text = "X %d   Z %d" % [int(world.king_pos.x), int(world.king_pos.z)]
	var nc: Dictionary = world.nearest_castle(world.king_pos)
	if not nc.is_empty():
		lbl_near.text = "%s - %d m" % [String(nc.name), int(nc.dist)] if nc.dist < 900.0 else ""
	lbl_net.text = (LocS.t("Online world") + " - %d " % world.online_count + LocS.t("other players")) if world.online_state == "online" else LocS.t("Offline world - lords only")
	lbl_net.add_theme_color_override("font_color", Color(0.6, 1, 0.7) if world.online_state == "online" else Color(0.85, 0.8, 0.6))
	refresh_buttons()
	var lf2 = world.life
	if lf2.raiders.size() > 0 or lf2.king_hp < lf2.king_max - 0.5:
		lbl_hp.text = "%s %d / %d" % [LocS.t("Health"), int(lf2.king_hp), int(lf2.king_max)] + (("   -   %d %s" % [lf2.raiders.size(), LocS.t("raiders")]) if lf2.raiders.size() > 0 else "")
	else:
		lbl_hp.text = ""
	btn_home.modulate = Color.WHITE if world.home_cd <= 0.0 else Color(0.5, 0.5, 0.5)
	mini.queue_redraw()
