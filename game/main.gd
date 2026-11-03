extends Node
# Menu, LAN lobby, army setup. Root node must be named "Main".

const BattleS := preload("res://game/battle.gd")
const UpdaterS := preload("res://game/updater.gd")
const Build := preload("res://game/build.gd")
const LocS := preload("res://game/loc.gd")
const CardsS := preload("res://game/menucards.gd")
const SettingsS := preload("res://game/settings.gd")
const UiFxS := preload("res://game/uifx.gd")
const TouchScrollS := preload("res://game/touchscroll.gd")
const IntroS := preload("res://game/intro.gd")
const Lobby3DS := preload("res://game/lobby3d.gd")
const MainMenuS := preload("res://game/mainmenu.gd")
const PlayScreenS := preload("res://game/playscreen.gd")
const SplashS := preload("res://game/splash.gd")
const MusicLibS := preload("res://game/music.gd")
const MenuBgS := preload("res://game/menubg.gd")

var net
var ui: Control
var ui_layer: CanvasLayer
var battle
var cfg := {"sword": 40, "archer": 20, "cav": 10, "mode": "battle", "kingdoms": 2, "map": "plains"}
var _lobby_box: VBoxContainer
var _hosts_box: VBoxContainer
var _ip_edit: LineEdit
var _status: Label
var _mode := ""
var updater
var _upd_label: Label
var _upd_btn: Button
var _start_btn: Button
var _room_lbl: Label
var _loc_t := 0.0
var _ttime := 0.0
var _menu_music: AudioStreamPlayer
var _fps_lbl: Label


func _ready() -> void:
	name = "Main"
	SettingsS.load_all()
	ProfS.load_all()
	LocS.install(get_tree())
	# the game reached its menu: the boot safety flag can go
	if FileAccess.file_exists("user://boot_try"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://boot_try"))
	updater = UpdaterS.new()
	updater.name = "Updater"
	add_child(updater)
	updater.changed.connect(_refresh_update)
	updater.check()
	net = preload("res://game/net.gd").new()
	net.name = "Net"
	add_child(net)
	if LocS.lang == "ar":
		net.my_name = "فارس%d" % (randi() % 100)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var th := _make_theme()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = th
	ui_layer.add_child(ui)
	net.players_changed.connect(_refresh_lobby)
	net.hosts_changed.connect(_refresh_hosts)
	net.start_requested.connect(_on_start)
	net.join_failed.connect(func(): _set_status("Could not connect. Check: same Wi-Fi, host already started, and allow Local Network for this app (iPhone Settings > this app)."))
	net.joined.connect(func(): _show_lobby(false))
	net.rejected.connect(func(why):
		_show_join()
		_set_status("Room is full." if why == "full" else "The game already started."))
	_fps_lbl = Label.new()
	_fps_lbl.position = Vector2(12, 4)
	_fps_lbl.add_theme_font_size_override("font_size", 22)
	_fps_lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	_fps_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_lbl.add_theme_constant_override("outline_size", 5)
	_fps_lbl.z_index = 100
	var fl := CanvasLayer.new()
	fl.layer = 50
	fl.add_child(_fps_lbl)
	add_child(fl)
	_menu_music = AudioStreamPlayer.new()
	_menu_music.stream = MusicLibS.compose(88.0, 0.45)
	_menu_music.volume_db = -40.0
	add_child(_menu_music)
	_menu_music.play()
	create_tween().tween_property(_menu_music, "volume_db", -8.0, 3.0)
	UiFxS.prewarm()
	if get_node_or_null("Backend") == null:
		add_child(load("res://game/backend.gd").new())
	TouchScrollS.install(get_tree())
	_show_menu()
	if not SplashS.done and OS.get_environment("NOSPLASH") == "":
		SplashS.start(self, func():
			if OS.get_environment("NOINTRO") == "":
				IntroS.start(self, func(): pass))


func _process(dt: float) -> void:
	_ttime += dt
	if _title_lbl != null and is_instance_valid(_title_lbl) and _title_lbl.is_inside_tree():
		var k := 0.5 + 0.5 * sin(_ttime * 2.0)
		_title_lbl.add_theme_color_override("font_color", Color(1, 0.72, 0.25).lerp(Color(1, 0.95, 0.6), k))
		_title_lbl.pivot_offset = _title_lbl.size * 0.5
		_title_lbl.scale = Vector2.ONE * (1.0 + 0.025 * sin(_ttime * 1.6))
	_loc_t -= dt
	if _loc_t <= 0.0:
		_loc_t = 0.5
		if ui_layer.visible:
			LocS.apply_tree(ui)
		_fps_lbl.visible = SettingsS.show_fps
		_fps_lbl.position = Vector2(get_viewport().get_visible_rect().size.x - 120.0, 6.0)
		if SettingsS.show_fps:
			_fps_lbl.text = "FPS %d" % Engine.get_frames_per_second()


func back_to_menu() -> void:
	net.leave()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- ui helpers
const UiFx := preload("res://game/uifx.gd")
const EmblemS := preload("res://game/emblem.gd")
const ProfS := preload("res://game/profile.gd")
const GOLD := Color(1, 0.82, 0.35)
var _footer: HBoxContainer
var _title_lbl: Label


func _sb(bg: Color, border: Color, rad := 14, bw := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 30
	th.set_stylebox("normal", "Button", UiFx.button("normal"))
	th.set_stylebox("hover", "Button", UiFx.button("hover"))
	th.set_stylebox("pressed", "Button", UiFx.button("pressed"))
	th.set_stylebox("disabled", "Button", UiFx.button("disabled"))
	th.set_stylebox("panel", "PanelContainer", UiFx.panel())
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(1, 0.93, 0.75))
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.85))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	th.set_stylebox("normal", "LineEdit", _sb(Color(0.05, 0.05, 0.08, 0.95), Color(0.5, 0.45, 0.3), 10, 2))
	th.set_color("font_color", "LineEdit", Color(1, 1, 1))
	var gs := _sb(Color(0.4, 0.3, 0.12), Color(0.4, 0.3, 0.12), 6, 0)
	gs.content_margin_top = 4
	gs.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", _sb(Color(0.05, 0.05, 0.08), Color(0.5, 0.4, 0.2), 6, 1))
	th.set_stylebox("grabber_area", "HSlider", gs)
	th.set_stylebox("grabber_area_highlight", "HSlider", gs)
	return th


func _clear() -> VBoxContainer:
	for c in ui.get_children():
		ui.remove_child(c)       # gone at once (queue_free alone left ghost text for a frame)
		if c != _lobby:
			c.queue_free()
	var bg := MenuBgS.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	ui.add_child(root)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(720, 0)
	cc.add_child(vb)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 16)
	root.add_child(_footer)
	return vb


func _label(p: Control, text: String, size := 34, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(3, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	return l


func _button(p: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(520, 76)
	b.pressed.connect(cb)
	p.add_child(b)
	return b


# pinned bottom button (Back / Start): always visible, never scrolls away
func _fbutton(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	if accent:
		b.add_theme_stylebox_override("normal", _sb(Color(0.5, 0.12, 0.1, 0.97), Color(1, 0.75, 0.3)))
		b.add_theme_stylebox_override("hover", _sb(Color(0.7, 0.18, 0.12, 1), Color(1, 0.9, 0.5)))
	_footer.add_child(b)
	return b


func _title(vb: Control, text: String) -> void:
	var l := _label(vb, text, 54, GOLD)
	l.add_theme_constant_override("outline_size", 10)


func _wrap(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _set_status(t: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = t


# ---------------------------------------------------------------- screens
func _show_menu() -> void:
	net.stop_listening()
	for c in ui.get_children():
		ui.remove_child(c)
		if c != _lobby:
			c.queue_free()
	if _lobby == null:
		_lobby = Lobby3DS.new()
	else:
		_lobby.refresh()
		_lobby.intro()
	ui.add_child(_lobby)
	var mm = MainMenuS.new()
	mm.main = self
	mm.actions = {
		"play": func(): _show_play(),
		"throne": func(): _show_throne(),
		"king": func(): _show_kingedit(),
		"castle": func(): _show_castleedit(),
		"local": func(): _show_local(),
		"settings": func(): _show_settings(),
	}
	ui.add_child(mm)
	_refresh_update()
	_fade_in()


var _lobby: Control = null


func _fade_in() -> void:
	var f := ColorRect.new()
	f.color = Color(0, 0, 0, 1)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _show_castleedit() -> void:
	_clear()
	var ce = load("res://game/castleedit.gd").new()
	ce.back = func(): _show_menu()
	ui.add_child(ce)


# ---------------------------------------------------------------- king creation + throne hall
var _trait_btns := {}
var _diff_btns := {}


func _mark_sel(btns: Dictionary, sel: String) -> void:
	for id in btns.keys():
		var b: Button = btns[id]
		if id == sel:
			b.add_theme_stylebox_override("normal", UiFx.button("pressed"))
			b.add_theme_color_override("font_color", Color(1, 1, 0.85))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")


func _show_king() -> void:
	var vb := _clear()
	_title(vb, "Crown your King")
	var em := EmblemS.new()
	em.custom_minimum_size = Vector2(90, 90)
	vb.add_child(em)
	_label(vb, "Name your realm", 26, Color(0.85, 0.85, 0.9))
	var ne := LineEdit.new()
	ne.text = ProfS.king_name
	ne.placeholder_text = "Kingdom of ..."
	ne.max_length = 22
	ne.custom_minimum_size = Vector2(0, 64)
	ne.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ne)
	_label(vb, "Choose your royal gift", 26, Color(0.85, 0.85, 0.9))
	_trait_btns = {}
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 10)
	tg.add_theme_constant_override("v_separation", 10)
	vb.add_child(tg)
	for id in ProfS.TRAITS.keys():
		var d: Dictionary = ProfS.TRAITS[id]
		var b := Button.new()
		b.text = LocS.t(String(d.name)) + "\n" + LocS.t(String(d.desc))
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tid: String = id
		b.pressed.connect(func():
			ProfS.trait_id = tid
			_mark_sel(_trait_btns, tid))
		tg.add_child(b)
		_trait_btns[id] = b
	_mark_sel(_trait_btns, ProfS.trait_id)
	_label(vb, "Rival kings", 26, Color(0.85, 0.85, 0.9))
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	vb.add_child(dh)
	_diff_btns = {}
	for did in ["easy", "normal", "hard"]:
		var db := Button.new()
		db.text = LocS.t({"easy": "Gentle", "normal": "Cunning", "hard": "Ruthless"}[did])
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.custom_minimum_size = Vector2(0, 60)
		var dd: String = did
		db.pressed.connect(func():
			ProfS.diff = dd
			_mark_sel(_diff_btns, dd))
		dh.add_child(db)
		_diff_btns[did] = db
	_mark_sel(_diff_btns, ProfS.diff)
	_fbutton("CROWN YOUR KING", func():
		ProfS.king_name = ne.text.strip_edges()
		ProfS.save()
		cfg.king = {"name": ProfS.king_name, "trait": ProfS.trait_id, "diff": ProfS.diff}
		_show_lobby(true), true)
	_fbutton("Back", func(): _show_play())


func _show_kingedit() -> void:
	_clear()
	var ke = load("res://game/kingedit.gd").new()
	ke.back = func(): _show_menu()
	ui.add_child(ke)


func _show_throne() -> void:
	var vb := _clear()
	_title(vb, "THRONE HALL")
	var em := EmblemS.new()
	em.custom_minimum_size = Vector2(96, 96)
	vb.add_child(em)
	var rl := _label(vb, LocS.t(ProfS.rank_name()), 46, Color(1.0, 0.85, 0.4))
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var pr: Array = ProfS.rank_progress()
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 26)
	pb.max_value = float(pr[1])
	pb.value = float(pr[0])
	pb.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.72, 0.2)
	fill.set_corner_radius_all(8)
	pb.add_theme_stylebox_override("fill", fill)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.05, 0.04, 0.06, 0.9)
	pbg.border_color = Color(0.6, 0.45, 0.2)
	pbg.set_border_width_all(2)
	pbg.set_corner_radius_all(8)
	pb.add_theme_stylebox_override("background", pbg)
	vb.add_child(pb)
	var nxt := LocS.t("Renown") + ": %d" % ProfS.renown
	if String(pr[2]) != "":
		nxt += "   ->   " + LocS.t(String(pr[2])) + "  (%d)" % (int(pr[1]) - int(pr[0]))
	_label(vb, nxt, 24, Color(0.85, 0.85, 0.9))
	_label(vb, LocS.t("Matches") + ": %d     " % ProfS.games + LocS.t("Victories") + ": %d" % ProfS.wins, 24, Color(0.8, 0.85, 0.95))
	var dc: Dictionary = ProfS.daily_today()
	var dl := _label(vb, LocS.t(String(dc.text)) + ("   [OK]" if ProfS.daily_done else "   +%d" % int(dc.r)), 26, Color(0.5, 1.0, 0.6) if ProfS.daily_done else Color(1.0, 0.9, 0.55))
	_wrap(dl)
	_label(vb, "Achievements", 28, GOLD)
	var gr := GridContainer.new()
	gr.columns = 2
	gr.add_theme_constant_override("h_separation", 10)
	gr.add_theme_constant_override("v_separation", 10)
	vb.add_child(gr)
	for id in ProfS.ACH.keys():
		var a: Dictionary = ProfS.ACH[id]
		var got: bool = ProfS.ach.has(id)
		var b := Button.new()
		b.text = ("★ " if got else "☆ ") + LocS.t(String(a.name)) + "\n" + LocS.t(String(a.desc))
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not got
		if got:
			b.add_theme_color_override("font_disabled_color", Color(1, 0.9, 0.5))
		gr.add_child(b)
	_fbutton("Back", func(): _show_menu())



func _lobby_base() -> void:
	for c in ui.get_children():
		ui.remove_child(c)
		if c != _lobby:
			c.queue_free()
	if _lobby == null:
		_lobby = Lobby3DS.new()
	else:
		_lobby.refresh()
	ui.add_child(_lobby)


func _show_play() -> void:
	_lobby_base()
	var ps = PlayScreenS.new()
	ps.main = self
	ps.on_back = func(): _show_menu()
	ps.on_pick = func(id: String):
		if id == "world":
			_show_world()
			return
		net.start_solo()
		cfg.mode = id
		_mode = "solo"
		if id == "kingdom":
			_show_king()
		else:
			_show_lobby(true)
	ui.add_child(ps)
	_fade_in()


func _show_world() -> void:
	if _menu_music != null:
		_menu_music.stop()
	ui_layer.visible = false
	var w = load("res://game/world.gd").new()
	w.main = self
	add_child(w)


func _show_local() -> void:
	var vb := _clear()
	_title(vb, "LOCAL (Wi-Fi)")
	_label(vb, "Play with friends on the same Wi-Fi", 26, Color(0.8, 0.8, 0.85))
	_button(vb, "Create Room", func():
		if net.host_game():
			_mode = "host"
			_show_lobby(true)
		else:
			_set_status("Could not host. Close the game fully and reopen it, check Wi-Fi is on."))
	_button(vb, "Join Room", func(): _show_join())
	_fbutton("Back", func(): _show_menu())
	_status = _label(vb, "", 26, Color(1, 0.5, 0.4))
	_wrap(_status)


func _refresh_update() -> void:
	if _upd_label == null or not is_instance_valid(_upd_label):
		return
	_upd_label.text = updater.text
	_upd_btn.visible = updater.state == "available"


func _show_join() -> void:
	var vb := _clear()
	_title(vb, "Join LAN Game")
	var mine: Array = net.local_ips()
	_label(vb, "Your IP: %s" % (", ".join(mine) if not mine.is_empty() else "?"), 24, Color(0.7, 0.85, 1))
	_label(vb, "Games found on your Wi-Fi:", 28)
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override("separation", 10)
	vb.add_child(_hosts_box)
	_label(vb, "...or type the host IP:", 28)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.10"
	_ip_edit.custom_minimum_size = Vector2(0, 76)
	vb.add_child(_ip_edit)
	_button(vb, "Connect", func():
		if net.join_game(_ip_edit.text):
			_set_status("Connecting...")
		else:
			_set_status("Invalid address"))
	_fbutton("Back", func(): _show_local())
	_status = _label(vb, "", 26, Color(1, 0.8, 0.4))
	_wrap(_status)
	net.start_listening()
	_refresh_hosts()


func _show_settings() -> void:
	var vb := _clear()
	_title(vb, "Settings")
	_button(vb, "Language: Arabic" if SettingsS.lang == "ar" else "Language: English", func():
		SettingsS.set_lang("en" if SettingsS.lang == "ar" else "ar")
		SettingsS.apply_global()
		_show_settings())
	_label(vb, "Device preset", 26, Color(0.85, 0.85, 0.9))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	vb.add_child(pr)
	for i in SettingsS.PRESETS.size():
		var pb := Button.new()
		pb.text = String(SettingsS.PRESETS[i])
		pb.custom_minimum_size = Vector2(0, 70)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_font_size_override("font_size", 24)
		pb.pressed.connect(func():
			SettingsS.apply_preset(i)
			_show_settings())
		pr.add_child(pb)
	for k in ["view", "scale", "fps", "shadows", "trees", "aa", "fx", "auto", "chars"]:
		_button(vb, "%s: %s" % [String({"fps": "Frame rate", "scale": "Resolution", "view": "View distance", "shadows": "Shadows", "trees": "Trees", "aa": "Smooth edges", "fx": "Effects (glow, haze)", "auto": "Auto quality", "chars": "Characters"}[k]), SettingsS.opt_text(k)], func():
			SettingsS.cycle(k)
			_show_settings())
	_button(vb, "FPS counter: %s" % ("ON" if SettingsS.show_fps else "OFF"), func():
		SettingsS.show_fps = not SettingsS.show_fps
		SettingsS.save()
		_show_settings())
	_button(vb, "Gift code", func(): _show_code())
	_label(vb, "Weak phone? Choose Potato or Low. Auto quality lowers the resolution when the game gets slow.", 22, Color(0.7, 0.7, 0.75))
	_fbutton("Back", func(): _show_menu())
	LocS.apply_tree(ui)


func _show_code() -> void:
	var vb := _clear()
	_title(vb, "Gift code")
	var le := LineEdit.new()
	le.placeholder_text = "ABCD-1234"
	le.custom_minimum_size = Vector2(0, 80)
	le.add_theme_font_size_override("font_size", 34)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(le)
	le.context_menu_enabled = true
	le.shortcut_keys_enabled = true
	le.selecting_enabled = true
	le.virtual_keyboard_enabled = true
	var res := _label(vb, " ", 26, Color(1, 0.9, 0.6))
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 12)
	vb.add_child(cr)
	var pb := _button(cr, "Paste", func():
		le.text = DisplayServer.clipboard_get().strip_edges()
		le.caret_column = le.text.length())
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb2 := _button(cr, "Copy", func():
		DisplayServer.clipboard_set(le.text))
	cb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xb := _button(cr, "Clear", func(): le.text = "")
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(vb, "Redeem", func():
		var bk = get_node_or_null("Backend")
		if bk == null or le.text.strip_edges() == "":
			return
		res.text = LocS.t("Connecting... (the first try can take a minute)")
		bk.redeem(le.text, func(ok: bool, txt: String):
			if not is_instance_valid(res):
				return
			if ok:
				res.text = LocS.t("Reward received! Renown") + " " + txt
			elif txt == "offline":
				res.text = LocS.t("Not connected to the server.")
			else:
				res.text = LocS.t("Code not accepted") + " (" + txt + ")"))
	_fbutton("Back", func(): _show_settings())
	LocS.apply_tree(ui)


func _refresh_hosts() -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if net.hosts.is_empty():
		_label(_hosts_box, "(searching...)", 26, Color(0.6, 0.6, 0.65))
	for ip in net.hosts.keys():
		var addr: String = ip
		var h: Dictionary = net.hosts[ip]
		var full: bool = int(h.count) >= int(h.max)
		var started: bool = bool(h.started)
		var label := "%s   %d/%d" % [h.name, int(h.count), int(h.max)]
		if started:
			label += "   (started)"
		elif full:
			label += "   (full)"
		var jb := _button(_hosts_box, label, func():
			if net.join_game(addr, int(h.get("port", 24680))):
				_set_status("Connecting..."))
		jb.disabled = full or started


func _show_lobby(is_host: bool) -> void:
	var vb := _clear()
	_title(vb, ("Kingdom" if String(cfg.get("mode", "battle")) == "kingdom" else "Army Setup") if _mode == "solo" else "LAN Lobby")
	if _mode == "host":
		var ips: Array = net.local_ips()
		_label(vb, "Your IP: %s" % (", ".join(ips) if not ips.is_empty() else "?"), 26, Color(0.7, 0.85, 1))
	_lobby_box = VBoxContainer.new()
	vb.add_child(_lobby_box)
	if is_host and _mode == "host":
		var capl := _label(vb, "Room size: %d players" % net.max_players, 28)
		var caps := HSlider.new()
		caps.min_value = 2
		caps.max_value = 6
		caps.step = 1
		caps.value = net.max_players
		caps.custom_minimum_size = Vector2(0, 50)
		caps.value_changed.connect(func(v):
			net.max_players = maxi(int(v), net.players.size())
			caps.set_value_no_signal(net.max_players)
			capl.text = LocS.t("Room size: %d players" % net.max_players) if LocS.lang == "ar" else "Room size: %d players" % net.max_players
			_refresh_lobby())
		vb.add_child(caps)
	if is_host:
		var kingdom: bool = String(cfg.get("mode", "battle")) == "kingdom"
		if _mode == "host":
			_button(vb, "Mode: KINGDOM (tap to change)" if kingdom else "Mode: BATTLE (tap to change)", func():
				cfg.mode = "battle" if kingdom else "kingdom"
				_show_lobby(true))
		if kingdom:
			_label(vb, "Build a city, hire villagers and soldiers,\nsend letters, declare war, duel the king.", 26, Color(0.85, 0.85, 0.9))
			var kl := _label(vb, "Kingdoms: %d" % int(cfg.kingdoms), 30)
			var ks := HSlider.new()
			ks.min_value = 2
			ks.max_value = 6
			ks.step = 1
			ks.value = cfg.kingdoms
			ks.custom_minimum_size = Vector2(0, 50)
			ks.value_changed.connect(func(v):
				cfg.kingdoms = maxi(int(v), maxi(2, net.players.size()))
				ks.set_value_no_signal(cfg.kingdoms)
				kl.text = LocS.t("Kingdoms: %d" % int(cfg.kingdoms)) if LocS.lang == "ar" else "Kingdoms: %d" % int(cfg.kingdoms)
				_refresh_lobby())
			vb.add_child(ks)
			var maps := ["plains", "island", "desert", "snow"]
			var mnames := {"plains": "Map: GREEN PLAINS (tap to change)", "island": "Map: ISLAND with seas and ships (tap to change)", "desert": "Map: DESERT (tap to change)", "snow": "Map: SNOW (tap to change)"}
			_button(vb, mnames[String(cfg.get("map", "plains"))], func():
				cfg.map = maps[(maps.find(String(cfg.get("map", "plains"))) + 1) % maps.size()]
				_show_lobby(true))
			_start_btn = _fbutton("START KINGDOM", func(): _start(), true)
		else:
			_slider(vb, "Swordsmen", "sword", 0, 80)
			_slider(vb, "Archers", "archer", 0, 50)
			_slider(vb, "Cavalry", "cav", 0, 30)
			_start_btn = _fbutton("START BATTLE", func(): _start(), true)
	else:
		_label(vb, "Waiting for the host to start...", 32)
	_fbutton("Back", func():
		net.leave()
		_show_menu())
	_refresh_lobby()


func _slider(p: Control, title: String, key: String, lo: int, hi: int) -> void:
	var l := _label(p, "%s: %d" % [title, cfg[key]], 30)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = cfg[key]
	s.custom_minimum_size = Vector2(0, 50)
	s.value_changed.connect(func(v):
		cfg[key] = int(v)
		l.text = "%s: %d" % [title, int(v)])
	p.add_child(s)


func _refresh_lobby() -> void:
	if _lobby_box == null or not is_instance_valid(_lobby_box):
		return
	for c in _lobby_box.get_children():
		c.queue_free()
	var kmode: bool = String(cfg.get("mode", "battle")) == "kingdom"
	var nkk: int = maxi(int(cfg.get("kingdoms", 2)), net.players.size()) if kmode else 2
	var taken := {}
	for id in net.players.keys():
		var p: Dictionary = net.players[id]
		var ti: int = int(p.idx) % nkk
		taken[ti] = true
		_label(_lobby_box, "%s   [%s]" % [p.name, LocS.t(BattleS.TEAM_NAMES[ti].to_upper())], 28, BattleS.TEAM_COLS[ti].lightened(0.3))
	if _mode == "solo":
		taken[0] = true
	for ti2 in nkk:
		if not taken.has(ti2) and (_mode == "solo" or _mode == "host" or net.online):
			_label(_lobby_box, "%s   [%s]" % [LocS.t("AI kingdom") if kmode else LocS.t("Enemy AI"), LocS.t(BattleS.TEAM_NAMES[ti2].to_upper())], 26, BattleS.TEAM_COLS[ti2].lightened(0.3))
	if _mode == "host" or (_mode == "" and net.online):
		_label(_lobby_box, "Players in room: %d/%d" % [net.players.size(), net.max_players], 26, Color(0.7, 0.9, 0.7))
		if net.players.size() >= net.max_players:
			_label(_lobby_box, "Room is full - nobody else can join.", 24, Color(1, 0.8, 0.4))
	if _start_btn != null and is_instance_valid(_start_btn) and _mode == "host":
		_start_btn.disabled = net.players.size() < 2


func _start() -> void:
	if net.online and net.players.size() < 2:
		return
	cfg.kingdoms = clampi(maxi(int(cfg.get("kingdoms", 2)), net.players.size()), 2, 6)
	if net.online:
		net.start_game.rpc(cfg)
	else:
		net.start_requested.emit(cfg)


func _on_start(c: Dictionary) -> void:
	if battle != null:
		return
	cfg = c
	if _menu_music != null:
		_menu_music.stop()
	ui_layer.visible = false
	battle = BattleS.new()
	battle.name = "Battle"
	battle.cfg = c
	add_child(battle)
	SettingsS.apply_scene(battle)
