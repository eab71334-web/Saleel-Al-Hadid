extends Node
# LAN networking: ENet host/join + UDP broadcast discovery

signal players_changed
signal hosts_changed
signal start_requested(cfg)
signal join_failed
signal joined
signal rejected(reason)

const PORT := 24680
const DISC := 24681

var players := {}      # peer_id -> {name, idx}
var hosts := {}        # ip -> {name, t}
var is_host := false
var online := false
var my_name := "Knight"
var _bcast: PacketPeerUDP
var _listen: PacketPeerUDP
var _t := 0.0
var _join_t := -1.0
var last_error := ""
var max_players := 4
var started := false
var room_name := ""
var port := PORT


func _ready() -> void:
	my_name = "Knight%d" % (randi() % 100)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func():
		_join_t = -1.0
		join_failed.emit())
	multiplayer.server_disconnected.connect(func(): leave(); get_tree().reload_current_scene())


func start_solo() -> void:
	online = false
	is_host = true
	players = {1: {"name": my_name, "idx": 0}}


func _close_peer() -> void:
	var old := multiplayer.multiplayer_peer
	if old != null and not (old is OfflineMultiplayerPeer):
		old.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func host_game() -> bool:
	# free anything left over from an earlier room (this was the "port busy" bug)
	_close_peer()
	if _bcast:
		_bcast.close()
		_bcast = null
	stop_listening()
	var p: ENetMultiplayerPeer = null
	var ok := false
	for i in 8:   # if the port is really taken by someone else, try the next ones
		p = ENetMultiplayerPeer.new()
		if p.create_server(PORT + i * 2, 8) == OK:
			port = PORT + i * 2
			ok = true
			break
	if not ok:
		last_error = "port"
		return false
	multiplayer.multiplayer_peer = p
	is_host = true
	online = true
	players = {1: {"name": my_name, "idx": 0}}
	started = false
	_bcast = PacketPeerUDP.new()
	_bcast.set_broadcast_enabled(true)
	players_changed.emit()
	return true


func join_game(ip: String, prt := PORT) -> bool:
	var addr := ip.strip_edges()
	_close_peer()
	last_error = ""
	if not addr.is_valid_ip_address():
		last_error = "bad_ip"
		return false
	var p := ENetMultiplayerPeer.new()
	if p.create_client(addr, prt) != OK:
		last_error = "bad_ip"
		return false
	multiplayer.multiplayer_peer = p
	is_host = false
	online = true
	_join_t = 8.0
	stop_listening()
	return true


func start_listening() -> void:
	stop_listening()
	hosts.clear()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISC) != OK:
		_listen = null


func stop_listening() -> void:
	if _listen:
		_listen.close()
		_listen = null


func leave() -> void:
	stop_listening()
	if _bcast:
		_bcast.close()
	_bcast = null
	_close_peer()
	online = false
	is_host = false
	players.clear()
	started = false


func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out


# broadcast addresses to try: global one + the /24 of every local address
func _bcast_targets() -> Array:
	var out := ["255.255.255.255"]
	for a in local_ips():
		var parts: PackedStringArray = String(a).split(".")
		if parts.size() == 4:
			var b := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not out.has(b):
				out.append(b)
	return out


func _process(dt: float) -> void:
	_t += dt
	if _join_t > 0.0:
		_join_t -= dt
		if _join_t <= 0.0:
			_join_t = -1.0
			if not online or is_host:
				pass
			elif multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
				multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
				online = false
				join_failed.emit()
	if _bcast and is_host and _t > 1.0:
		_t = 0.0
		for target in _bcast_targets():
			_bcast.set_dest_address(target, DISC)
			_bcast.put_packet(("MW|%s|%d|%d|%d|%d" % [my_name, players.size(), max_players, 1 if started else 0, port]).to_utf8_buffer())
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var s: String = _listen.get_packet().get_string_from_utf8()
			var ip: String = _listen.get_packet_ip()
			if s.begins_with("MW|"):
				var parts: PackedStringArray = s.split("|")
				var cnt := 1
				var mx := 4
				var st := false
				var hp := PORT
				if parts.size() >= 6:
					hp = int(parts[5])
				if parts.size() >= 5:
					cnt = int(parts[2])
					mx = int(parts[3])
					st = parts[4] == "1"
				hosts[ip] = {"name": parts[1] if parts.size() > 1 else "?", "count": cnt, "max": mx, "started": st, "port": hp, "t": Time.get_ticks_msec()}
				changed = true
		# forget rooms that stopped announcing
		var now := Time.get_ticks_msec()
		for k in hosts.keys():
			if now - int(hosts[k].t) > 4500:
				hosts.erase(k)
				changed = true
		if changed:
			hosts_changed.emit()


func _on_connected() -> void:
	_join_t = -1.0
	joined.emit()
	register.rpc_id(1, my_name)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		sync_players.rpc(players, max_players)
		players_changed.emit()


@rpc("any_peer", "reliable")
func register(nm: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if started or players.size() >= max_players:
		var why := "started" if started else "full"
		rejected_msg.rpc_id(id, why)
		var tmr := get_tree().create_timer(0.4)
		tmr.timeout.connect(func():
			if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	# lowest free slot index
	var used := []
	for k in players.keys():
		used.append(int(players[k].idx))
	var idx := 0
	while used.has(idx):
		idx += 1
	players[id] = {"name": nm, "idx": idx}
	sync_players.rpc(players, max_players)
	players_changed.emit()


@rpc("authority", "reliable")
func rejected_msg(reason: String) -> void:
	leave()
	rejected.emit(reason)


@rpc("authority", "reliable")
func sync_players(p: Dictionary, mx := 4) -> void:
	players = p
	max_players = mx
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func start_game(cfg: Dictionary) -> void:
	started = true
	_bcast = null
	start_requested.emit(cfg)
