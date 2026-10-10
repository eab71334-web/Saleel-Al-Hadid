extends Node
# LAN networking: ENet host/join + UDP broadcast discovery

signal players_changed
signal hosts_changed
signal start_requested(cfg)
signal join_failed
signal joined

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


func _ready() -> void:
	my_name = "Knight%d" % (randi() % 100)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): join_failed.emit())
	multiplayer.server_disconnected.connect(func(): leave(); get_tree().reload_current_scene())


func start_solo() -> void:
	online = false
	is_host = true
	players = {1: {"name": my_name, "idx": 0}}


func host_game() -> bool:
	var p := ENetMultiplayerPeer.new()
	if p.create_server(PORT, 8) != OK:
		return false
	multiplayer.multiplayer_peer = p
	is_host = true
	online = true
	players = {1: {"name": my_name, "idx": 0}}
	_bcast = PacketPeerUDP.new()
	_bcast.set_broadcast_enabled(true)
	_bcast.set_dest_address("255.255.255.255", DISC)
	players_changed.emit()
	return true


func join_game(ip: String) -> bool:
	var p := ENetMultiplayerPeer.new()
	if p.create_client(ip.strip_edges(), PORT) != OK:
		return false
	multiplayer.multiplayer_peer = p
	is_host = false
	online = true
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
	_bcast = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	players.clear()


func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out


func _process(dt: float) -> void:
	_t += dt
	if _bcast and is_host and _t > 1.0:
		_t = 0.0
		_bcast.put_packet(("MW|" + my_name).to_utf8_buffer())
	if _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var s: String = _listen.get_packet().get_string_from_utf8()
			var ip: String = _listen.get_packet_ip()
			if s.begins_with("MW|"):
				hosts[ip] = {"name": s.substr(3), "t": Time.get_ticks_msec()}
				changed = true
		if changed:
			hosts_changed.emit()


func _on_connected() -> void:
	joined.emit()
	register.rpc_id(1, my_name)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		sync_players.rpc(players)
		players_changed.emit()


@rpc("any_peer", "reliable")
func register(nm: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": nm, "idx": players.size()}
	sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable")
func sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func start_game(cfg: Dictionary) -> void:
	_bcast = null
	start_requested.emit(cfg)
