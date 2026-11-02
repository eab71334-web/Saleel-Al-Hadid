extends Node
# Build menu and the placement mode (a top-down view where you drag the building to where you want it).

const LocS := preload("res://game/loc.gd")
const ModelsT := preload("res://game/townmodels.gd")

var town
var k
var battle
var root: Control
var menu: PanelContainer
var rows := {}
var overlay: Control
var info: Label
var top_lbl: Label
var cost_lbl: Label
var btn_build: Button
var btn_town: Button
var btn_land: Button
var placing := ""
var active := false
var ghost: Node3D = null
var foot: MeshInstance3D = null
var foot_mat: StandardMaterial3D
var lx := 0.0
var d := 90.0
var zone := 0
var _u := 1.0
var _t := 0.0
var sel_id := -1
var sel_panel: PanelContainer
var sel_lbl: Label


func setup(town_node, ui_root: Control, u: float, vs: Vector2) -> void:
	town = town_node
	k = town.kingdom
	battle = town.battle
	root = ui_root
	_u = u
	# ---- build menu
	menu = PanelContainer.new()
	menu.position = Vector2(vs.x * 0.5 - 340 * u, 20 * u)
	menu.z_index = 35
	menu.visible = false
	root.add_child(menu)
	var psc := ScrollContainer.new()
	psc.custom_minimum_size = Vector2(680 * u, minf(vs.y - 40 * u, 700 * u))
	psc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(psc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	psc.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tl := Label.new()
	tl.text = "BUILD"
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_theme_font_size_override("font_size", int(28 * u))
	tl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	head.add_child(tl)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(60, 50) * u
	x.pressed.connect(close_menu)
	head.add_child(x)
	var hint := Label.new()
	hint.text = "Choose a building, then drag it to the spot you want. The woodcutter, quarry and mine must stand next to a forest, rocks or ore behind the castle."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(650, 0) * u
	hint.add_theme_font_size_override("font_size", int(18 * u))
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8))
	vb.add_child(hint)
	for type in town.ORDER:
		var def: Dictionary = town.DEFS[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(650, 104) * u
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", int(19 * u))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tp: String = type
		b.pressed.connect(func(): begin_place(tp))
		vb.add_child(b)
		rows[type] = b
	# ---- placement overlay
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 34
	overlay.visible = false
	overlay.gui_input.connect(_input_overlay)
	root.add_child(overlay)
	top_lbl = Label.new()
	top_lbl.position = Vector2(20, 10) * u
	top_lbl.visible = false
	top_lbl.add_theme_font_size_override("font_size", int(21 * u))
	top_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	top_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	top_lbl.add_theme_constant_override("outline_size", int(6 * u))
	top_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top_lbl)
	info = Label.new()
	info.position = Vector2(20, vs.y - 190 * u)
	info.size = Vector2(vs.x - 40 * u, 40 * u)
	info.add_theme_font_size_override("font_size", int(22 * u))
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", int(6 * u))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(info)
	cost_lbl = Label.new()
	cost_lbl.position = Vector2(20, vs.y - 150 * u)
	cost_lbl.size = Vector2(vs.x - 40 * u, 40 * u)
	cost_lbl.add_theme_font_size_override("font_size", int(20 * u))
	cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_lbl.add_theme_constant_override("outline_size", int(5 * u))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cost_lbl)
	var bar := HBoxContainer.new()
	bar.position = Vector2(20 * u, vs.y - 100 * u)
	bar.add_theme_constant_override("separation", int(10 * u))
	overlay.add_child(bar)
	var mk := func(text: String, w: float, cb: Callable) -> Button:
		var bb := Button.new()
		bb.text = LocS.t(text)
		bb.custom_minimum_size = Vector2(w, 80) * u
		bb.add_theme_font_size_override("font_size", int(24 * u))
		bb.pressed.connect(cb)
		bar.add_child(bb)
		return bb
	mk.call("MENU", 150, func(): back_to_menu())
	btn_town = mk.call("TOWN", 150, func(): _set_zone(0))
	btn_land = mk.call("FIELDS", 170, func(): _set_zone(1))
	btn_build = mk.call("BUILD HERE", 280, func(): _do_build())
	mk.call("DONE", 150, func(): finish())
	# ---- tap-a-building panel (info + demolish)
	sel_panel = PanelContainer.new()
	sel_panel.position = Vector2(vs.x * 0.5 - 250 * u, vs.y * 0.5 - 100 * u)
	sel_panel.z_index = 36
	sel_panel.visible = false
	root.add_child(sel_panel)
	var sv := VBoxContainer.new()
	sv.custom_minimum_size = Vector2(500, 0) * u
	sv.add_theme_constant_override("separation", int(8 * u))
	sel_panel.add_child(sv)
	sel_lbl = Label.new()
	sel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_lbl.custom_minimum_size = Vector2(480, 0) * u
	sel_lbl.add_theme_font_size_override("font_size", int(21 * u))
	sv.add_child(sel_lbl)
	var sh := HBoxContainer.new()
	sv.add_child(sh)
	var dem := Button.new()
	dem.text = LocS.t("DEMOLISH")
	dem.custom_minimum_size = Vector2(220, 64) * u
	dem.pressed.connect(func():
		k.cmd("demolish", {"id": sel_id})
		sel_panel.visible = false
		battle.modal = false)
	sh.add_child(dem)
	var cl := Button.new()
	cl.text = LocS.t("CLOSE")
	cl.custom_minimum_size = Vector2(200, 64) * u
	cl.pressed.connect(func():
		sel_panel.visible = false
		battle.modal = false)
	sh.add_child(cl)
	foot_mat = StandardMaterial3D.new()
	foot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foot_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.4)


# ------------------------------------------------------------------ menu
func open_menu() -> void:
	if battle.modal and not menu.visible:
		return
	_refresh_menu()
	menu.visible = true
	battle.modal = true
	LocS.apply_tree(menu)


func close_menu() -> void:
	menu.visible = false
	battle.modal = false


func _refresh_menu() -> void:
	var t: int = k.my_team
	for type in town.ORDER:
		var def: Dictionary = town.DEFS[type]
		var b: Button = rows[type]
		var n: int = town.count(t, type, false)
		var lim: int = town.limit_for(t, type)
		var ok: bool = town.afford(t, def.cost) and n < lim and town.missing_for(t, type) == ""
		var extra := ""
		if n >= lim:
			extra = "   [" + LocS.t("maximum reached") + "]"
		else:
			var pre: String = town.missing_for(t, type)
			if pre != "":
				extra = "   [" + LocS.t(pre) + "]"
			elif not town.afford(t, def.cost):
				extra = "   [" + LocS.t("Not enough materials") + "]"
		var where := LocS.t("inside the walls") if int(def.zone) == 0 else (LocS.t("behind the castle") if int(def.zone) == 1 else LocS.t("anywhere"))
		b.text = "%s  (%d/%d)%s\n%s\n%s  -  %s" % [LocS.t(def.name), n, lim, extra, town.cost_text(def), LocS.t(def.desc), where]
		b.disabled = not ok


# ------------------------------------------------------------------ placement
func begin_place(type: String) -> void:
	menu.visible = false
	placing = type
	active = true
	var def: Dictionary = town.DEFS[type]
	zone = 1 if int(def.zone) == 1 else 0
	_set_zone(zone)
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = ModelsT.make(town, k.my_team, type)
	ghost.get_node("site").visible = false
	battle.add_child(ghost)
	foot = MeshInstance3D.new()
	foot.mesh = battle._box(Vector3(float(def.hx) * 2.0, 0.15, float(def.hz) * 2.0))
	foot.material_override = foot_mat
	foot.position = Vector3(0, 0.15, 0)
	ghost.add_child(foot)
	overlay.visible = true
	battle.build_cam = true
	var pose0 := _cam_pose()
	battle.cam.position = pose0[1]
	battle.cam.look_at(pose0[0], Vector3.UP)
	battle.modal = true
	LocS.apply_tree(overlay)
	_update_ghost()


func _set_zone(z: int) -> void:
	zone = z
	if z == 1:
		lx = -4.0
		d = 152.0
	else:
		lx = 20.0
		d = 100.0
		if placing != "" and town.DEFS[placing].zone == 1:
			zone = 1
			lx = -4.0
			d = 152.0


func back_to_menu() -> void:
	_stop_place()
	open_menu()


func finish() -> void:
	_stop_place()
	battle.modal = false


func _stop_place() -> void:
	active = false
	placing = ""
	overlay.visible = false
	battle.build_cam = false
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func _cam_pose() -> Array:
	var t: int = k.my_team
	if zone == 1:
		return [town.world(t, -4.0, 153.0), k.lw(t, Vector3(0, 72.0, -146.0))]
	return [town.world(t, 0.0, 99.5), k.lw(t, Vector3(0, 66.0, -92.0))]


func _process(dt: float) -> void:
	if not active:
		return
	var pose := _cam_pose()
	var cam: Camera3D = battle.cam
	cam.position = cam.position.lerp(pose[1], clampf(dt * 5.0, 0.0, 1.0) if dt < 0.1 else 0.6)
	cam.look_at(pose[0], Vector3.UP)
	_update_ghost()
	var t: int = k.my_team
	top_lbl.text = LocS.t("WOOD %d  STONE %d  IRON %d  GRAIN %d  FLOUR %d  GOLD %d") % [int(k.wood[t]), int(k.stone[t]), int(k.iron[t]), int(k.grain[t]), int(k.flour[t]), int(k.gold[t])]


func _ground_point(sp: Vector2) -> Variant:
	var cam: Camera3D = battle.cam
	var o: Vector3 = cam.project_ray_origin(sp)
	var n: Vector3 = cam.project_ray_normal(sp)
	if absf(n.y) < 0.001:
		return null
	var tt: float = -o.y / n.y
	if tt < 0.0:
		return null
	return o + n * tt


func _input_overlay(e: InputEvent) -> void:
	var pos := Vector2.ZERO
	var go := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		go = true
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = e.position
		go = true
	if not go:
		return
	var p = _ground_point(pos)
	if p == null:
		return
	var l: Vector3 = k.wl(k.my_team, p)
	lx = roundf(l.x)
	d = roundf(-l.z)


func _status() -> String:
	if placing == "":
		return ""
	var t: int = k.my_team
	var def: Dictionary = town.DEFS[placing]
	if town.count(t, placing, false) >= town.limit_for(t, placing):
		return "You already have the maximum of these"
	var pre: String = town.missing_for(t, placing)
	if pre != "":
		return pre
	var why: String = town.check(t, placing, lx, d)
	if why != "":
		return why
	if not town.afford(t, def.cost):
		return "Not enough materials"
	return ""


func _update_ghost() -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	var t: int = k.my_team
	ghost.position = town.world(t, lx, d)
	ghost.rotation.y = k.ang(t)
	var why := _status()
	var ok := why == ""
	foot_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.45)
	btn_build.disabled = not ok
	var def: Dictionary = town.DEFS[placing]
	info.text = LocS.t(def.name) + ":  " + (LocS.t("Good spot. Press BUILD HERE.") if ok else LocS.t(why))
	info.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.55, 0.45))
	cost_lbl.text = LocS.t("Cost") + ":  " + town.cost_text(def)
	btn_town.disabled = int(def.zone) == 1
	btn_land.disabled = int(def.zone) == 0


func _do_build() -> void:
	if _status() != "":
		return
	k.cmd("build", {"type": placing, "lx": lx, "d": d})
	battle.sfx.play_ui("coin", -6.0)


# ------------------------------------------------------------------ select a finished building (tap in the world)
func show_building(b: Dictionary) -> void:
	sel_id = int(b.id)
	var def: Dictionary = town.DEFS[b.type]
	var s := LocS.t(def.name)
	if float(b.prog) < 1.0:
		s += "\n" + LocS.t("Under construction") + ": %d%%" % int(float(b.prog) * 100.0)
	elif int(def.workers) > 0:
		s += "\n" + LocS.t("Workers") + ": %d / %d" % [int(b.present), int(def.workers)]
		if bool(b.idle):
			s += "\n" + LocS.t("Not working: no material or no storage room")
	s += "\n" + LocS.t(def.desc)
	sel_lbl.text = s
	sel_panel.visible = true
	battle.modal = true
