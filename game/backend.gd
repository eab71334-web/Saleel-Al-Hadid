extends Node
# Link to the company "Sabak Admin" app. The game talks to the Sabak backend (Render):
# registers the player, fetches events, redeems gift codes, sends error reports.
# Needs NO secret key. If DEFAULT_URL is empty the game simply runs offline.

const DEFAULT_URL := "https://sabak-backend.onrender.com"          # e.g. "https://your-service.onrender.com" (no slash at the end)
const GAME := "saleelalhadid"
const VERSION := "1.0"
const CFG := "user://backend.cfg"

var base_url := DEFAULT_URL
var player_id := ""
var events: Array = []
var config: Dictionary = {}
var online := false


func _ready() -> void:
	name = "Backend"
	_load_id()
	if base_url == "":
		return
	hello()
	_http_get("/api/config?game=%s" % GAME, func(code, d): if code == 200 and d is Dictionary: config = d)
	refresh_events()


func _load_id() -> void:
	var c := ConfigFile.new()
	c.load(CFG)
	player_id = String(c.get_value("p", "id", ""))
	if player_id == "":
		player_id = "p%d%04d" % [Time.get_unix_time_from_system(), randi() % 10000]
		c.set_value("p", "id", player_id)
		c.save(CFG)


func _pname() -> String:
	var P := preload("res://game/profile.gd")
	P.load_all()
	return P.king_name if P.king_name != "" else "King"


func hello() -> void:
	_http_post("/api/player/hello", {"player_id": player_id, "name": _pname(), "game": GAME, "platform": OS.get_name(), "version": VERSION}, func(code, _d): online = code == 200)


func refresh_events() -> void:
	_http_get("/api/events?game=%s&player_id=%s" % [GAME, player_id], func(code, d):
		if code == 200:
			if d is Array:
				events = d
			elif d is Dictionary and d.has("events"):
				events = d["events"])


# gift code typed by the player. cb(ok: bool, text: String)
func redeem(code: String, cb: Callable) -> void:
	if base_url == "":
		cb.call(false, "offline")
		return
	_http_post("/api/redeem", {"player_id": player_id, "code": code.strip_edges().to_upper(), "game": GAME}, func(http, d):
		if d is Dictionary and d.get("ok", false):
			var P := preload("res://game/profile.gd")
			P.load_all()
			P.renown += int(d.get("coins", 0)) + int(d.get("gems", 0)) * 5
			P.save()
			cb.call(true, "+%d" % (int(d.get("coins", 0)) + int(d.get("gems", 0)) * 5))
		else:
			cb.call(false, String(d.get("error", "error")) if d is Dictionary else "error"))


func claim_event(event_id, cb: Callable) -> void:
	_http_post("/api/event/claim", {"player_id": player_id, "event_id": event_id}, cb)


func report(kind: String, message: String, stack := "") -> void:
	if base_url == "":
		return
	_http_post("/api/report", {"game": GAME, "version": VERSION, "player_id": player_id, "kind": kind, "message": message, "stack": stack, "platform": OS.get_name()}, func(_c, _d): pass)


func _http_get(path: String, cb: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = 70.0   # a sleeping free Render server needs ~50 s to wake up
	add_child(h)
	h.request_completed.connect(func(_r, code, _hd, body):
		var txt: String = body.get_string_from_utf8()
		cb.call(code, JSON.parse_string(txt) if txt.strip_edges() != "" else null)
		h.queue_free())
	if h.request(base_url + path) != OK:
		h.queue_free()


func _http_post(path: String, data: Dictionary, cb: Callable) -> void:
	var h := HTTPRequest.new()
	h.timeout = 70.0
	add_child(h)
	h.request_completed.connect(func(_r, code, _hd, body):
		var txt: String = body.get_string_from_utf8()
		cb.call(code, JSON.parse_string(txt) if txt.strip_edges() != "" else null)
		h.queue_free())
	if h.request(base_url + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data)) != OK:
		h.queue_free()
