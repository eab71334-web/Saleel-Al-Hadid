extends Node
# Tiny starter scene. If a downloaded update exists (user://update.pck) it is mounted
# BEFORE the real game loads, so new scripts/scenes/models replace the ones inside the app.
# Safety: if the previous launch never reached the menu, the update is thrown away.

const PCK := "user://update.pck"
const INFO := "user://update.json"
const TRY := "user://boot_try"
const GAME := "res://game/main.tscn"


func _ready() -> void:
	var base_build := 0
	var bs = load("res://game/build.gd")
	if bs != null:
		base_build = int(bs.BUILD)
	if FileAccess.file_exists(TRY):
		print("Boot: last start failed, dropping update")
		_reset()
	elif FileAccess.file_exists(PCK) and FileAccess.file_exists(INFO):
		var ub := 0
		var d = JSON.parse_string(FileAccess.get_file_as_string(INFO))
		if d is Dictionary:
			ub = int(d.get("build", 0))
		if ub > base_build:
			var f := FileAccess.open(TRY, FileAccess.WRITE)
			if f != null:
				f.store_string("1")
				f.close()
			var ok := ProjectSettings.load_resource_pack(PCK, true)
			print("Boot: update build ", ub, " mounted=", ok)
			if not ok:
				_reset()
		else:
			print("Boot: update ", ub, " is not newer than app ", base_build, ", removing")
			_reset()
	get_tree().change_scene_to_file.call_deferred(GAME)


func _reset() -> void:
	for p in [PCK, INFO, TRY, PCK + ".part"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
