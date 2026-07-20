@tool
class_name GameVocalPathUtils
extends RefCounted

# Ensures that all file paths returned from the server are sanitized.
# Protects against directory traversal.

static func sanitize_path(path: String) -> String:
	var safe_path = path.replace("\\", "/")
	
	# Prevent absolute paths or relative traversals
	while safe_path.begins_with("/"):
		safe_path = safe_path.substr(1)
		
	safe_path = safe_path.replace("../", "")
	safe_path = safe_path.replace("..", "")
	
	return safe_path

static func get_import_root() -> String:
	# In the future, this could be configurable in ProjectSettings
	return "res://gamevocal"

static func get_absolute_path(relative_path: String) -> String:
	var safe_rel = sanitize_path(relative_path)
	return get_import_root().path_join(safe_rel)
