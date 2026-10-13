extends Node
# Menu, LAN lobby, army setup. Root node must be named "Main".

const BattleS := preload("res://game/battle.gd")
const UpdaterS := preload("res://game/updater.gd")
const Build := preload("res://game/build.gd")
const LocS := preload("res://game/loc.gd")
const CardsS := preload("res://game/menucards.gd")
const SettingsS := preload("res://game/settings.gd")

var net
var ui: Control
var ui_layer: CanvasLayer
var battle
var cfg := {"sword": 40, "archer": 20, "cav": 10, "mode": "battle", "kingdoms": 2}
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
var _fps_lbl: Label


func _ready() -> void:
	name = "Main"
	SettingsS.load_all()
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
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var th := Theme.new()
	th.default_font_size = 34
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
	_show_menu()


func _process(dt: float) -> void:
	_loc_t -= dt
	if _loc_t <= 0.0:
		_loc_t = 0.3
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
func _clear() -> VBoxContainer:
	for c in ui.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.06, 0.1)
	ui.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	cc.add_child(vb)
	return vb


func _label(p: Control, text: String, size := 34, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return l


func _button(p: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 84)
	b.pressed.connect(cb)
	p.add_child(b)
	return b


func _wrap(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)


func _set_status(t: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = t


# ---------------------------------------------------------------- screens
func _show_menu() -> void:
	net.stop_listening()
	var vb := _clear()
	_label(vb, "MEDIEVAL WARS", 72, Color(1, 0.82, 0.35))
	_label(vb, "Swords  -  Bows  -  Kingdoms", 30, Color(0.8, 0.8, 0.85))
	_label(vb, " ", 20)
	_button(vb, "PLAY", func(): _show_play())
	_button(vb, "LOCAL (Wi-Fi)", func(): _show_local())
	_button(vb, "Settings", func(): _show_settings())
	_status = _label(vb, "", 26, Color(1, 0.5, 0.4))
	_wrap(_status)
	_upd_label = _label(vb, "", 22, Color(0.7, 0.8, 0.9))
	_upd_btn = _button(vb, "Download update", func(): updater.download())
	_upd_btn.custom_minimum_size = Vector2(560, 64)
	_upd_btn.visible = false
	_label(vb, "build %d" % int(Build.BUILD), 18, Color(0.5, 0.5, 0.55))
	_refresh_update()


func _show_play() -> void:
	var vb := _clear()
	_label(vb, "Choose your game", 52, Color(1, 0.82, 0.35))
	var cards := CardsS.new()
	cards.custom_minimum_size = Vector2(1000, 430)
	cards.cards = [
		{"id": "battle", "title": "Solo Battle", "desc": "Command your army against the enemy", "art": "battle"},
		{"id": "kingdom", "title": "Solo Kingdom", "desc": "Build a castle city, then rule or conquer", "art": "kingdom"},
	]
	cards.chosen.connect(func(id):
		net.start_solo()
		cfg.mode = String(id)
		_mode = "solo"
		_show_lobby(true))
	vb.add_child(cards)
	_button(vb, "Back", func(): _show_menu())


func _show_local() -> void:
	var vb := _clear()
	_label(vb, "LOCAL (Wi-Fi)", 56, Color(1, 0.82, 0.35))
	_label(vb, "Play with friends on the same Wi-Fi", 26, Color(0.8, 0.8, 0.85))
	_button(vb, "Create Room", func():
		if net.host_game():
			_mode = "host"
			_show_lobby(true)
		else:
			_set_status("Could not host (port busy?)"))
	_button(vb, "Join Room", func(): _show_join())
	_button(vb, "Back", func(): _show_menu())
	_status = _label(vb, "", 26, Color(1, 0.5, 0.4))
	_wrap(_status)


func _refresh_update() -> void:
	if _upd_label == null or not is_instance_valid(_upd_label):
		return
	_upd_label.text = updater.text
	_upd_btn.visible = updater.state == "available"


func _show_join() -> void:
	var vb := _clear()
	_label(vb, "Join LAN Game", 56, Color(1, 0.82, 0.35))
	var mine: Array = net.local_ips()
	_label(vb, "Your IP: %s  (the host must be on the same Wi-Fi)" % (", ".join(mine) if not mine.is_empty() else "?"), 22, Color(0.7, 0.85, 1))
	_label(vb, "Games found on your Wi-Fi:", 28)
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override("separation", 10)
	vb.add_child(_hosts_box)
	_label(vb, "...or type the host IP:", 28)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.10"
	_ip_edit.custom_minimum_size = Vector2(560, 76)
	vb.add_child(_ip_edit)
	_button(vb, "Connect", func():
		if net.join_game(_ip_edit.text):
			_set_status("Connecting...")
		else:
			_set_status("Invalid address"))
	_button(vb, "Back", func(): _show_local())
	_status = _label(vb, "", 26, Color(1, 0.8, 0.4))
	_wrap(_status)
	net.start_listening()
	_refresh_hosts()


func _show_settings() -> void:
	var vb := _clear()
	_label(vb, "Settings", 56, Color(1, 0.82, 0.35))
	_button(vb, "Language: Arabic" if SettingsS.lang == "ar" else "Language: English", func():
		SettingsS.set_lang("en" if SettingsS.lang == "ar" else "ar")
		SettingsS.apply_global()
		_show_settings())
	_button(vb, "Quality: %s" % SettingsS.quality_name(), func():
		SettingsS.quality = (SettingsS.quality + 1) % 3
		SettingsS.save()
		_show_settings())
	_button(vb, "Frame rate: %d" % SettingsS.fps, func():
		SettingsS.fps = {30: 60, 60: 120, 120: 30}[SettingsS.fps]
		SettingsS.save()
		SettingsS.apply_global()
		_show_settings())
	_button(vb, "FPS counter: %s" % ("ON" if SettingsS.show_fps else "OFF"), func():
		SettingsS.show_fps = not SettingsS.show_fps
		SettingsS.save()
		_show_settings())
	_label(vb, "Low = fastest. Use it if the game is slow or the phone gets hot.", 22, Color(0.7, 0.7, 0.75))
	_button(vb, "Back", func(): _show_menu())
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
			if net.join_game(addr):
				_set_status("Connecting..."))
		jb.disabled = full or started


func _show_lobby(is_host: bool) -> void:
	var vb := _clear()
	_label(vb, ("Kingdom" if String(cfg.get("mode", "battle")) == "kingdom" else "Army Setup") if _mode == "solo" else "LAN Lobby", 56, Color(1, 0.82, 0.35))
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
		caps.custom_minimum_size = Vector2(560, 50)
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
			ks.custom_minimum_size = Vector2(560, 50)
			ks.value_changed.connect(func(v):
				cfg.kingdoms = maxi(int(v), maxi(2, net.players.size()))
				ks.set_value_no_signal(cfg.kingdoms)
				kl.text = LocS.t("Kingdoms: %d" % int(cfg.kingdoms)) if LocS.lang == "ar" else "Kingdoms: %d" % int(cfg.kingdoms)
				_refresh_lobby())
			vb.add_child(ks)
			_start_btn = _button(vb, "START KINGDOM", func(): _start())
		else:
			_slider(vb, "Swordsmen", "sword", 0, 80)
			_slider(vb, "Archers", "archer", 0, 50)
			_slider(vb, "Cavalry", "cav", 0, 30)
			_start_btn = _button(vb, "START BATTLE", func(): _start())
	else:
		_label(vb, "Waiting for the host to start...", 32)
	_button(vb, "Back", func():
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
	s.custom_minimum_size = Vector2(560, 50)
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
	ui_layer.visible = false
	battle = BattleS.new()
	battle.name = "Battle"
	battle.cfg = c
	add_child(battle)
	SettingsS.apply_scene(battle)
