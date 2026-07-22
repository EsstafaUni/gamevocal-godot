@tool
class_name GameVocalLipsyncPlayer
extends Node

# Processes lip-sync data (e.g. ARKit blendshapes) and provides interpolated values.
# To ensure perfect audio sync, the character should query this using the audio playback position.

var _blendshape_names: Array = []
var _frames: Array = [] # Array of dictionaries: {"time": float, "blendshapes": Array}
var _duration: float = 0.0

func load_lipsync_data(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY and data.has("blendshape_names") and data.has("frames"):
				_blendshape_names = data["blendshape_names"]
				_frames = data["frames"]
				_duration = data.get("duration", 0.0)
				print("[GameVocal] Loaded lipsync data from ", path)
				return true
			else:
				print("[GameVocal] Invalid lipsync JSON format: ", path)
		else:
			print("[GameVocal] Failed to parse lipsync JSON: ", path)
	else:
		print("[GameVocal] Failed to open lipsync file: ", path)
	return false

func get_duration() -> float:
	return _duration

func get_interpolated_blendshapes(time: float) -> Dictionary:
	var interpolated_values = {}
	if _frames.is_empty():
		return interpolated_values
		
	# Binary search or simple loop to find the current frame
	# For AAA performance, a binary search or caching the last frame index is better
	# but for typical clips, a simple optimized loop works fine.
	var frame_idx = 0
	for i in range(_frames.size()):
		if _frames[i]["time"] > time:
			break
		frame_idx = i
		
	var current_frame = _frames[frame_idx]
	
	if frame_idx < _frames.size() - 1:
		var next_frame = _frames[frame_idx + 1]
		var t0 = current_frame["time"]
		var t1 = next_frame["time"]
		var ratio = (time - t0) / (t1 - t0) if t1 > t0 else 0.0
		
		# Clamp ratio to prevent extrapolation if time goes wonky
		ratio = clamp(ratio, 0.0, 1.0)
		
		var current_shapes = current_frame["blendshapes"]
		var next_shapes = next_frame["blendshapes"]
		var num_shapes = _blendshape_names.size()
		
		for i in range(num_shapes):
			var name = _blendshape_names[i]
			var v0 = current_shapes[i] if i < current_shapes.size() else 0.0
			var v1 = next_shapes[i] if i < next_shapes.size() else 0.0
			interpolated_values[name] = lerpf(v0, v1, ratio)
	else:
		var current_shapes = current_frame["blendshapes"]
		var num_shapes = _blendshape_names.size()
		for i in range(num_shapes):
			var name = _blendshape_names[i]
			interpolated_values[name] = current_shapes[i] if i < current_shapes.size() else 0.0
			
	return interpolated_values
