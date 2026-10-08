extends Node

const BattleS := preload("res://game/battle.gd")

var net
var ui: Control
var ui_layer: CanvasLayer
var battle
var cfg := {"sword": 40, "archer": 20, "cav": 10}
var _lobby_box: VBoxContainer
var _hosts_box: VBoxContainer
var _ip_edit: LineEdit
var _status: Label
var _mode := ""


func _ready() -> void:
	name = "Main"
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
	net.join_failed.connect(func(): _set_status("Could not connect."))
	net.joined.connect(func(): _show_lobby(false))
	_show_menu()


func back_to_menu() -> void:
	net.leave()
	get_tree().reload_current_scene()


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


func _set_status(t: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = t


func _show_menu() -> void:
	net.stop_listening()
	var vb := _clear()
	_label(vb, "MEDIEVAL WARS", 72, Color(1, 0.82, 0.35))
	_label(vb, "Swords  -  Bows  -  Cavalry", 30, Color(0.8, 0.8, 0.85))
	_label(vb, " ", 20)
	_button(vb, "Solo Battle (vs AI)", func():
		net.start_solo()
		_mode = "solo"
		_show_lobby(true))
	_button(vb, "Host LAN Game", func():
		if net.host_game():
			_mode = "host"
			_show_lobby(true)
		else:
			_set_status("Could not host (port busy?)"))
	_button(vb, "Join LAN Game", func(): _show_join())
	_status = _label(vb, "", 26, Color(1, 0.5, 0.4))


func _show_join() -> void:
	var vb := _clear()
	_label(vb, "Join LAN Game", 56, Color(1, 0.82, 0.35))
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
	_button(vb, "Back", func(): _show_menu())
	_status = _label(vb, "", 26, Color(1, 0.8, 0.4))
	net.start_listening()
	_refresh_hosts()


func _refresh_hosts() -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if net.hosts.is_empty():
		_label(_hosts_box, "(searching...)", 26, Color(0.6, 0.6, 0.65))
	for ip in net.hosts.keys():
		var addr: String = ip
		_button(_hosts_box, "%s  (%s)" % [net.hosts[ip].name, ip], func():
			if net.join_game(addr):
				_set_status("Connecting..."))


func _show_lobby(is_host: bool) -> void:
	var vb := _clear()
	_label(vb, "Army Setup" if _mode == "solo" else "LAN Lobby", 56, Color(1, 0.82, 0.35))
	if _mode == "host":
		var ips: Array = net.local_ips()
		_label(vb, "Your IP: %s" % (", ".join(ips) if not ips.is_empty() else "?"), 26, Color(0.7, 0.85, 1))
	_lobby_box = VBoxContainer.new()
	vb.add_child(_lobby_box)
	if is_host:
		_slider(vb, "Swordsmen", "sword", 0, 80)
		_slider(vb, "Archers", "archer", 0, 50)
		_slider(vb, "Cavalry", "cav", 0, 30)
		_button(vb, "START BATTLE", func(): _start())
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
	for id in net.players.keys():
		var p: Dictionary = net.players[id]
		var team := "BLUE" if int(p.idx) % 2 == 0 else "RED"
		_label(_lobby_box, "%s   [%s]" % [p.name, team], 28, Color(0.5, 0.7, 1) if team == "BLUE" else Color(1, 0.5, 0.45))
	if _mode == "solo":
		_label(_lobby_box, "Enemy AI   [RED]", 28, Color(1, 0.5, 0.45))


func _start() -> void:
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
