@tool
class_name GameVocalCharacter
extends Node

# Runtime script to manage a specific character's lip-sync and dialogue state.
# Connects an AudioStreamPlayer to a MeshInstance3D and perfectly syncs AAA blendshapes.

@export var character_id: String = ""
@export var target_mesh: MeshInstance3D
@export var audio_player: Node # Can be AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D

@export_group("Lip-Sync Mapping")
@export var blendshape_mapping: Dictionary = {}
@export var auto_map_blendshapes: bool = false:
	set(value):
		if value:
			_do_auto_mapping()
			
var _lipsync_player: GameVocalLipsyncPlayer
var _is_playing_lipsync: bool = false

func _ready():
	if not Engine.is_editor_hint():
		_lipsync_player = GameVocalLipsyncPlayer.new()
		add_child(_lipsync_player)

# Plays an audio file and its accompanying lip-sync json file
func play_dialogue(audio_path: String, lipsync_path: String):
	if Engine.is_editor_hint(): return
	
	if not audio_player or not target_mesh:
		push_error("[GameVocal] Missing target_mesh or audio_player on GameVocalCharacter: ", name)
		return
		
	if not audio_player.has_method("play"):
		push_error("[GameVocal] Assigned audio_player must be a valid AudioStreamPlayer type.")
		return
		
	# Load the audio stream
	var stream = load(audio_path)
	if stream:
		audio_player.stream = stream
	else:
		push_error("[GameVocal] Failed to load audio stream: ", audio_path)
		return
		
	# Load the lip sync data
	if _lipsync_player.load_lipsync_data(lipsync_path):
		_is_playing_lipsync = true
		audio_player.play()
	else:
		push_error("[GameVocal] Failed to load lip sync data for audio: ", audio_path)

func stop():
	if Engine.is_editor_hint(): return
	_is_playing_lipsync = false
	if audio_player and audio_player.has_method("stop") and audio_player.playing:
		audio_player.stop()

func _process(_delta: float):
	if Engine.is_editor_hint(): return
	
	if _is_playing_lipsync and audio_player and target_mesh:
		if audio_player.playing:
			var current_time = audio_player.get_playback_position()
			var blendshapes = _lipsync_player.get_interpolated_blendshapes(current_time)
			_apply_blendshapes(blendshapes)
		else:
			# Audio finished playing
			_is_playing_lipsync = false
			_reset_blendshapes()

func _apply_blendshapes(blendshapes: Dictionary):
	if not target_mesh or blendshape_mapping.is_empty():
		return
		
	for arkit_name in blendshapes.keys():
		if blendshape_mapping.has(arkit_name):
			var mesh_shape_name = blendshape_mapping[arkit_name]
			if mesh_shape_name and not mesh_shape_name.is_empty():
				var idx = target_mesh.find_blend_shape_by_name(mesh_shape_name)
				if idx != -1:
					target_mesh.set_blend_shape_value(idx, blendshapes[arkit_name])

func _reset_blendshapes():
	if not target_mesh or blendshape_mapping.is_empty():
		return
	for mesh_shape_name in blendshape_mapping.values():
		if mesh_shape_name and not mesh_shape_name.is_empty():
			var idx = target_mesh.find_blend_shape_by_name(mesh_shape_name)
			if idx != -1:
				target_mesh.set_blend_shape_value(idx, 0.0)

# --- Editor Only: Auto Mapping Tool ---

func _do_auto_mapping():
	if not Engine.is_editor_hint(): return
	if not target_mesh:
		printerr("[GameVocal] Please assign a Target Mesh first to auto-map blendshapes.")
		return
		
	var mesh = target_mesh.mesh
	if not mesh:
		printerr("[GameVocal] The Target Mesh has no Mesh resource assigned.")
		return
		
	var num_shapes = mesh.get_blend_shape_count()
	if num_shapes == 0:
		printerr("[GameVocal] The Target Mesh has 0 blendshapes.")
		return
		
	var target_shapes = []
	for i in range(num_shapes):
		target_shapes.append(mesh.get_blend_shape_name(i))
		
	# Standard ARKit 52 Names
	var arkit_names = ["browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight", "cheekPuff", "cheekSquintLeft", "cheekSquintRight", "eyeBlinkLeft", "eyeLookDownLeft", "eyeLookInLeft", "eyeLookOutLeft", "eyeLookUpLeft", "eyeSquintLeft", "eyeWideLeft", "eyeBlinkRight", "eyeLookDownRight", "eyeLookInRight", "eyeLookOutRight", "eyeLookUpRight", "eyeSquintRight", "eyeWideRight", "jawForward", "jawLeft", "jawOpen", "jawRight", "mouthClose", "mouthDimpleLeft", "mouthDimpleRight", "mouthFrownLeft", "mouthFrownRight", "mouthFunnel", "mouthLeft", "mouthLowerDownLeft", "mouthLowerDownRight", "mouthPressLeft", "mouthPressRight", "mouthPucker", "mouthRight", "mouthRollLower", "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper", "mouthSmileLeft", "mouthSmileRight", "mouthStretchLeft", "mouthStretchRight", "mouthUpperUpLeft", "mouthUpperUpRight", "noseSneerLeft", "noseSneerRight", "tongueOut"]
	
	var new_mapping = {}
	var matched = 0
	
	for arkit in arkit_names:
		var best_match = ""
		var best_score = 0
		
		# Simplistic exact or lowercase match first
		for s in target_shapes:
			if s == arkit:
				best_match = s
				best_score = 100
				break
			
			var clean_s = s.to_lower().replace(" ", "").replace("_", "").replace("-", "")
			var clean_arkit = arkit.to_lower()
			
			if clean_s == clean_arkit:
				best_match = s
				best_score = 90
				continue
				
			# Check if target string contains the arkit name as a substring
			if clean_s.contains(clean_arkit):
				if best_score < 50:
					best_match = s
					best_score = 50
					
		if best_match != "":
			new_mapping[arkit] = best_match
			matched += 1
		else:
			new_mapping[arkit] = "" # Leave blank for user to fill
			
	blendshape_mapping = new_mapping
	print("[GameVocal] Auto-mapping complete. Matched ", matched, " out of 52 ARKit blendshapes.")
