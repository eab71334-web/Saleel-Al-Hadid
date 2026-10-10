extends Node
# Checks GitHub for a light update (update.json + update.pck) and downloads it.
# The new files are used the next time the game starts (see boot.gd).

const Config := preload("res://game/config.gd")
const Build := preload("res://game/build.gd")

signal changed

var state := "idle"      # idle, disabled, checking, available, uptodate, downloading, ready, error
var text := ""
var remote_build := 0
var remote_size := 0
var _http: HTTPRequest


func _st(st: String, t: String) -> void:
	state = st
	text = t
	changed.emit()


func check() -> void:
	if Config.UPDATE_URL.contains("YOURNAME"):
		_st("disabled", "Light updates off: set your GitHub name in game/config.gd")
		return
	_st("checking", "Checking for updates...")
	_clean()
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_info)
	if _http.request(Config.UPDATE_URL + "update.json") != OK:
		_st("error", "Update check failed")


func _on_info(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_st("error", "No update info (offline?)")
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if not (d is Dictionary):
		_st("error", "Bad update info")
		return
	remote_build = int(d.get("build", 0))
	remote_size = int(d.get("size", 0))
	if remote_build > int(Build.BUILD):
		_st("available", "Update available: build %d (%d KB)" % [remote_build, maxi(1, remote_size / 1024)])
	else:
		_st("uptodate", "Game is up to date (build %d)" % int(Build.BUILD))


func download() -> void:
	if state != "available":
		return
	_st("downloading", "Downloading update...")
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.download_file = "user://update.pck.part"
	add_child(_http)
	_http.request_completed.connect(_on_pck)
	if _http.request(Config.UPDATE_URL + "update.pck") != OK:
		_st("error", "Download failed")


func _on_pck(result: int, code: int, _h: PackedStringArray, _body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_clean()
		_st("error", "Download failed (code %d)" % code)
		return
	var dir := ProjectSettings.globalize_path("user://")
	DirAccess.rename_absolute(dir + "update.pck.part", dir + "update.pck")
	var f := FileAccess.open("user://update.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"build": remote_build}))
	f.close()
	_st("ready", "Update downloaded! Close the game and open it again.")


func reset() -> void:
	for p in ["user://update.pck", "user://update.json", "user://update.pck.part", "user://boot_try"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_st("idle", "Updates removed. Restart the game to use the built-in version.")


func _clean() -> void:
	var p := "user://update.pck.part"
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
