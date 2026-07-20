@tool
class_name GameVocalImportManager
extends RefCounted

# Interfaces with Godot's EditorFileSystem to trigger asset imports
# after new files have been downloaded to res://.

static func scan_and_import():
	if not Engine.is_editor_hint():
		return
	
	print("[GameVocal] Scanning filesystem for new imports...")
	var efs = EditorInterface.get_resource_filesystem()
	if efs:
		efs.scan()
