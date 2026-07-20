class_name GameVocalLipsyncPlayer
extends Node

# Processes lip-sync data (e.g. ARKit blendshapes) during runtime.

var _lipsync_data: Dictionary = {}
var _is_playing: bool = false
var _current_time: float = 0.0

func load_lipsync_data(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			_lipsync_data = json.data
			print("[GameVocal] Loaded lipsync data from ", path)

func play():
	_is_playing = true
	_current_time = 0.0

func _process(delta: float):
	if _is_playing:
		_current_time += delta
		_apply_blendshapes(_current_time)

func _apply_blendshapes(time: float):
	# Interpolate ARKit52 blendshapes here based on the json format
	pass
