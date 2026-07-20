@tool
class_name GameVocalProjectManifest
extends Resource

# Stores the local state of synchronized assets from GameVocal.
# Allows incremental sync instead of full re-download.

@export var project_id: String = ""
@export var last_sync: String = ""
@export var files: Dictionary = {}

const MANIFEST_PATH = "user://gamevocal_project_manifest.tres"

static func load_manifest() -> GameVocalProjectManifest:
	if ResourceLoader.exists(MANIFEST_PATH):
		var res = ResourceLoader.load(MANIFEST_PATH, "Resource") as GameVocalProjectManifest
		if res:
			return res
	return GameVocalProjectManifest.new()

func save_manifest():
	ResourceSaver.save(self, MANIFEST_PATH)
